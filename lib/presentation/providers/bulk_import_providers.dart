import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/bulk_import_service.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/tag_providers.dart';

/// Provider for the bulk import service
final bulkImportServiceProvider = Provider<BulkImportService>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// State of a bulk import run
class BulkImportState {
  final bool isRunning;
  final BulkImportProgress? progress;
  final BulkImportResult? result;
  final String? error;

  const BulkImportState({
    this.isRunning = false,
    this.progress,
    this.result,
    this.error,
  });
}

/// Drives a bulk import run and exposes its progress to the UI
class BulkImportNotifier extends StateNotifier<BulkImportState> {
  final Ref _ref;

  BulkImportNotifier(this._ref) : super(const BulkImportState());

  Future<void> run(String zipPath) async {
    if (state.isRunning) return;
    state = const BulkImportState(isRunning: true);
    try {
      final service = _ref.read(bulkImportServiceProvider);
      final result = await service.importFromZip(
        zipPath,
        onProgress: (progress) {
          if (mounted) {
            state = BulkImportState(isRunning: true, progress: progress);
          }
        },
      );
      if (mounted) {
        state = BulkImportState(result: result);
      }
      await _ref.read(characterListProvider.notifier).refresh();
      _ref.invalidate(allTagsProvider);
    } catch (e) {
      if (mounted) {
        state = BulkImportState(error: e.toString());
      }
    }
  }

  void reset() {
    if (!state.isRunning) {
      state = const BulkImportState();
    }
  }
}

final bulkImportProvider =
    StateNotifierProvider<BulkImportNotifier, BulkImportState>((ref) {
  return BulkImportNotifier(ref);
});
