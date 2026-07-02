import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/tag_repository.dart';
import 'package:native_tavern/domain/services/import_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Thrown when the picked zip is not a valid SillyTavern library export
class BulkImportException implements Exception {
  final String message;

  BulkImportException(this.message);

  @override
  String toString() => message;
}

/// Progress snapshot reported while a bulk import is running
class BulkImportProgress {
  final int total;
  final int processed;
  final int imported;
  final int skipped;
  final int failed;

  const BulkImportProgress({
    required this.total,
    required this.processed,
    required this.imported,
    required this.skipped,
    required this.failed,
  });
}

/// A card that could not be imported
class BulkImportFailure {
  final String file;
  final String reason;

  const BulkImportFailure(this.file, this.reason);
}

/// Final outcome of a bulk import run
class BulkImportResult {
  final int total;
  final int imported;
  final int skipped;
  final List<BulkImportFailure> failures;

  const BulkImportResult({
    required this.total,
    required this.imported,
    required this.skipped,
    required this.failures,
  });
}

/// Imports a SillyTavern library zip produced by tools/st_export.py:
/// manifest.json at the root, card files under cards/.
///
/// The zip is never extracted to disk. Libraries can be many gigabytes, so
/// worker isolates read card entries straight out of the archive one at a
/// time (the zip central directory supports random access, including zip64),
/// keeping memory bounded to roughly one card per worker and avoiding a
/// full-size temp copy.
class BulkImportService {
  static const int _parseConcurrency = 6;
  static const int _batchSize = 100;
  static const _uuid = Uuid();

  final CharacterRepository _characterRepository;
  final TagRepository _tagRepository;
  final String _dataPath;

  BulkImportService(this._characterRepository, this._tagRepository, this._dataPath);

  Future<BulkImportResult> importFromZip(
    String zipPath, {
    void Function(BulkImportProgress progress)? onProgress,
  }) async {
    _ZipInventory inventory;
    try {
      inventory = await _readInventoryInIsolate(zipPath);
    } catch (e) {
      throw BulkImportException('Could not read zip: $e');
    }

    final manifest = _parseManifest(inventory.manifestJson);
    final tagIdMap = await _upsertTags(manifest.tags);
    return _importCards(
        zipPath, inventory.entryNames, manifest.cards, tagIdMap, onProgress);
  }

  _Manifest _parseManifest(String? manifestJson) {
    if (manifestJson == null) {
      throw BulkImportException('manifest.json not found in zip');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(manifestJson);
    } catch (e) {
      throw BulkImportException('manifest.json is not valid JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw BulkImportException('manifest.json has an unexpected structure');
    }

    final version = decoded['version'];
    if (version != 1) {
      throw BulkImportException('Unsupported manifest version: $version');
    }
    final cards = decoded['cards'];
    if (cards is! List) {
      throw BulkImportException('manifest.json is missing the cards list');
    }
    final tags = decoded['tags'];
    return _Manifest(tags is List ? tags : const [], cards);
  }

  /// Insert manifest tags that don't exist locally yet (matched by name,
  /// case-insensitively). Returns SillyTavern tag id -> local tag id.
  Future<Map<String, String>> _upsertTags(List<dynamic> manifestTags) async {
    final existing = await _tagRepository.getAllTags();
    final localIdByName = {
      for (final tag in existing) tag.name.toLowerCase(): tag.id,
    };

    final tagIdMap = <String, String>{};
    for (final entry in manifestTags) {
      if (entry is! Map) continue;
      final stId = entry['id']?.toString();
      final name = entry['name']?.toString();
      if (stId == null || name == null || name.isEmpty) continue;

      var localId = localIdByName[name.toLowerCase()];
      if (localId == null) {
        final color = entry['color']?.toString();
        final created = await _tagRepository.createTag(
          name: name,
          color: (color == null || color.isEmpty) ? null : color,
        );
        localId = created.id;
        localIdByName[name.toLowerCase()] = localId;
      }
      tagIdMap[stId] = localId;
    }
    return tagIdMap;
  }

  Future<BulkImportResult> _importCards(
    String zipPath,
    Set<String> entryNames,
    List<dynamic> manifestCards,
    Map<String, String> tagIdMap,
    void Function(BulkImportProgress progress)? onProgress,
  ) async {
    final total = manifestCards.length;
    final failures = <BulkImportFailure>[];
    var skipped = 0;
    var imported = 0;
    var processed = 0;

    // Hashes already in the database plus those claimed during this run,
    // so re-running an interrupted import resumes where it left off.
    final seenHashes = await _characterRepository.getAllContentHashes();

    final work = <_CardWorkItem>[];
    for (final entry in manifestCards) {
      final file = entry is Map ? entry['file'] : null;
      if (file is! String || file.isEmpty) {
        failures.add(const BulkImportFailure('?', 'Invalid manifest card entry'));
        processed++;
        continue;
      }
      if (!entryNames.contains('cards/$file')) {
        failures.add(BulkImportFailure(file, 'File missing from zip'));
        processed++;
        continue;
      }
      final manifestSha = entry['sha256'] is String ? entry['sha256'] as String : null;
      if (manifestSha != null && !seenHashes.add(manifestSha)) {
        skipped++;
        processed++;
        continue;
      }
      final tagIds = <String>[];
      if (entry['tag_ids'] is List) {
        for (final stId in entry['tag_ids'] as List) {
          final localId = tagIdMap[stId?.toString()];
          if (localId != null) tagIds.add(localId);
        }
      }
      work.add(_CardWorkItem(file, manifestSha, tagIds));
    }

    final pending = <Character>[];
    final sha256ById = <String, String>{};
    final tagIdsById = <String, List<String>>{};
    final fileById = <String, String>{};

    Future<void> flush() async {
      if (pending.isEmpty) return;
      final batch = List.of(pending);
      pending.clear();
      final failedIds = await _characterRepository.createCharactersBatch(
        batch,
        sha256ById: sha256ById,
        tagIdsById: tagIdsById,
      );
      imported += batch.length - failedIds.length;
      for (final id in failedIds) {
        failures.add(BulkImportFailure(fileById[id] ?? id, 'Database insert failed'));
      }
    }

    void reportProgress() {
      onProgress?.call(BulkImportProgress(
        total: total,
        processed: processed,
        // Count queued-but-unflushed cards so the bar doesn't stall between batches.
        imported: imported + pending.length,
        skipped: skipped,
        failed: failures.length,
      ));
    }

    reportProgress();

    var nextIndex = 0;

    // Each worker is a long-lived isolate that opens the zip once, reads the
    // central directory once, then decompresses one requested card at a time.
    Future<void> runWorker() async {
      final fromWorker = ReceivePort();
      final isolate = await Isolate.spawn(
        _cardWorkerMain,
        _WorkerInit(zipPath: zipPath, dataPath: _dataPath, replyTo: fromWorker.sendPort),
        onError: fromWorker.sendPort,
      );
      final events = StreamIterator<dynamic>(fromWorker);
      try {
        if (!await events.moveNext() || events.current is! SendPort) {
          throw BulkImportException('Import worker failed to start');
        }
        final toWorker = events.current as SendPort;

        while (nextIndex < work.length) {
          final item = work[nextIndex++];
          toWorker.send(_WorkItemMsg(file: item.file, characterId: _uuid.v4()));

          if (!await events.moveNext()) break;
          final message = events.current;
          if (message is! _CardOutcomeMsg) {
            // Uncaught error forwarded via onError: the isolate is dead.
            failures.add(BulkImportFailure(item.file, 'Import worker crashed: $message'));
            processed++;
            reportProgress();
            return;
          }

          if (message.error != null) {
            failures.add(BulkImportFailure(item.file, message.error!));
          } else {
            final character = message.character!;
            final sha256 = message.sha256!;
            // The real hash can differ from a stale manifest hash; re-check it.
            if (sha256 != item.manifestSha && !seenHashes.add(sha256)) {
              skipped++;
              await _deleteAvatarIfAny(character);
            } else {
              pending.add(character);
              sha256ById[character.id] = sha256;
              tagIdsById[character.id] = item.tagIds;
              fileById[character.id] = item.file;
              if (pending.length >= _batchSize) {
                await flush();
              }
            }
          }
          processed++;
          reportProgress();
        }
        toWorker.send(null);
      } finally {
        await events.cancel();
        isolate.kill(priority: Isolate.beforeNextEvent);
      }
    }

    await Future.wait(
      List.generate(min(_parseConcurrency, work.length), (_) => runWorker()),
    );
    await flush();
    reportProgress();

    return BulkImportResult(
      total: total,
      imported: imported,
      skipped: skipped,
      failures: failures,
    );
  }

  /// Reads the zip central directory plus manifest.json without extracting
  /// anything. Static so the Isolate.run closure cannot capture `this` (and
  /// with it the repositories' unsendable native sqlite handles).
  static Future<_ZipInventory> _readInventoryInIsolate(String zipPath) {
    return Isolate.run(() async {
      final input = InputFileStream(zipPath);
      try {
        final archive = ZipDecoder().decodeBuffer(input);
        String? manifestJson;
        final entryNames = <String>{};
        for (final file in archive.files) {
          entryNames.add(file.name);
          if (file.name == 'manifest.json') {
            final raw = file.content as List<int>;
            file.clear();
            manifestJson = utf8.decode(raw);
          }
        }
        return _ZipInventory(manifestJson, entryNames);
      } finally {
        await input.close();
      }
    });
  }

  Future<void> _deleteAvatarIfAny(Character character) async {
    final relativePath = character.assets?.avatarPath;
    if (relativePath == null) return;
    try {
      await File(p.join(_dataPath, relativePath)).delete();
    } catch (_) {
      // Ignore - a leftover avatar file is harmless.
    }
  }
}

class _ZipInventory {
  final String? manifestJson;
  final Set<String> entryNames;

  const _ZipInventory(this.manifestJson, this.entryNames);
}

class _Manifest {
  final List<dynamic> tags;
  final List<dynamic> cards;

  const _Manifest(this.tags, this.cards);
}

class _CardWorkItem {
  final String file;
  final String? manifestSha;
  final List<String> tagIds;

  const _CardWorkItem(this.file, this.manifestSha, this.tagIds);
}

class _WorkerInit {
  final String zipPath;
  final String dataPath;
  final SendPort replyTo;

  const _WorkerInit({
    required this.zipPath,
    required this.dataPath,
    required this.replyTo,
  });
}

class _WorkItemMsg {
  final String file;
  final String characterId;

  const _WorkItemMsg({required this.file, required this.characterId});
}

class _CardOutcomeMsg {
  final String file;
  final Character? character;
  final String? sha256;
  final String? error;

  const _CardOutcomeMsg({
    required this.file,
    this.character,
    this.sha256,
    this.error,
  });
}

/// Entry point of a worker isolate. Opens the zip once, then serves one card
/// per request: decompress the entry, hash it, parse it via the shared
/// ImportService parsers, write the avatar under dataPath, and reply with the
/// parsed character. Frees each entry's bytes immediately after use so memory
/// stays bounded regardless of archive size. Must not touch platform channels.
Future<void> _cardWorkerMain(_WorkerInit init) async {
  final commands = ReceivePort();
  init.replyTo.send(commands.sendPort);

  InputFileStream? input;
  Map<String, ArchiveFile>? entriesByName;

  await for (final message in commands) {
    if (message == null) break;
    final item = message as _WorkItemMsg;
    try {
      if (entriesByName == null) {
        input = InputFileStream(init.zipPath);
        final archive = ZipDecoder().decodeBuffer(input);
        entriesByName = {for (final file in archive.files) file.name: file};
      }
      final entry = entriesByName['cards/${item.file}'];
      if (entry == null) {
        throw Exception('File missing from zip');
      }
      final raw = entry.content as List<int>;
      entry.clear();
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);

      final response =
          _parseCardBytes(bytes, item.file, init.dataPath, item.characterId);
      init.replyTo.send(_CardOutcomeMsg(
        file: item.file,
        character: response.character,
        sha256: response.sha256,
      ));
    } catch (e) {
      init.replyTo.send(_CardOutcomeMsg(file: item.file, error: e.toString()));
    }
  }
  commands.close();
  await input?.close();
}

class _CardParseResponse {
  final Character character;
  final String sha256;

  const _CardParseResponse(this.character, this.sha256);
}

_CardParseResponse _parseCardBytes(
    Uint8List bytes, String file, String dataPath, String characterId) {
  final sha256 = crypto.sha256.convert(bytes).toString();

  Character character;
  Uint8List? avatarBytes;
  if (file.toLowerCase().endsWith('.charx')) {
    final parsed = ImportService.parseCharXCard(bytes);
    character = parsed.character;
    avatarBytes = parsed.avatarBytes;
  } else {
    character = ImportService.parsePngCard(bytes);
    avatarBytes = bytes;
  }

  // Parsed ids are timestamp-based and collide under concurrency; use a UUID.
  character = character.copyWith(id: characterId);

  if (avatarBytes != null) {
    final avatarDir = Directory(p.join(dataPath, 'avatars'));
    avatarDir.createSync(recursive: true);
    File(p.join(avatarDir.path, '$characterId.png')).writeAsBytesSync(avatarBytes);
    character = character.copyWith(
      assets: CharacterAssets(avatarPath: p.join('avatars', '$characterId.png')),
    );
  }

  return _CardParseResponse(character, sha256);
}
