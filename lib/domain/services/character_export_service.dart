import 'dart:io';

import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/domain/services/import_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Supported character card export formats
enum CharacterExportFormat { png, charx, json }

/// Service for exporting character cards to shareable files
class CharacterExportService {
  final ImportService _importService;

  CharacterExportService(this._importService);

  /// Export the character in the given format and open the OS share sheet
  Future<void> exportAndShare(
    Character character,
    CharacterExportFormat format,
  ) async {
    final fileName = '${_sanitizeFileName(character.name)}.${format.extension}';
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');

    switch (format) {
      case CharacterExportFormat.png:
        await file.writeAsBytes(await _importService.exportToPng(character, null));
        break;
      case CharacterExportFormat.charx:
        await file.writeAsBytes(await _importService.exportToCharX(character, null));
        break;
      case CharacterExportFormat.json:
        await file.writeAsString(_importService.exportToJson(character));
        break;
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: character.name,
    );
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    return sanitized.isEmpty ? 'character' : sanitized;
  }
}

extension CharacterExportFormatExtension on CharacterExportFormat {
  String get extension {
    switch (this) {
      case CharacterExportFormat.png:
        return 'png';
      case CharacterExportFormat.charx:
        return 'charx';
      case CharacterExportFormat.json:
        return 'json';
    }
  }
}
