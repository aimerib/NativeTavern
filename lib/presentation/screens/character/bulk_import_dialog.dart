import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/bulk_import_providers.dart';

/// Dialog that imports a SillyTavern library zip (see tools/st_export.py)
class BulkImportDialog extends ConsumerStatefulWidget {
  const BulkImportDialog({super.key});

  @override
  ConsumerState<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends ConsumerState<BulkImportDialog> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(bulkImportProvider.notifier).reset());
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    await ref.read(bulkImportProvider.notifier).run(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(bulkImportProvider);

    return PopScope(
      canPop: !state.isRunning,
      child: AlertDialog(
        title: Text(l10n.bulkImportTitle),
        content: SizedBox(
          width: 400,
          child: _buildContent(context, l10n, state),
        ),
        actions: [
          if (!state.isRunning)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          if (!state.isRunning && state.result == null && state.error == null)
            FilledButton(
              onPressed: _pickAndImport,
              child: Text(l10n.bulkImportChooseZip),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, BulkImportState state) {
    if (state.error != null) {
      return Text('${l10n.error}: ${state.error}');
    }

    if (state.isRunning) {
      final progress = state.progress;
      final total = progress?.total ?? 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: total > 0 ? (progress!.processed / total) : null,
          ),
          const SizedBox(height: 12),
          Text(l10n.bulkImportProgressLabel(progress?.processed ?? 0, total)),
          const SizedBox(height: 4),
          Text(
            l10n.bulkImportSummary(
              progress?.imported ?? 0,
              progress?.skipped ?? 0,
              progress?.failed ?? 0,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    final result = state.result;
    if (result != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bulkImportSummary(result.imported, result.skipped, result.failures.length)),
          if (result.failures.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.bulkImportFailedFiles,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: result.failures.length,
                itemBuilder: (context, index) {
                  final failure = result.failures[index];
                  return Text(
                    '${failure.file} - ${failure.reason}',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

    return Text(l10n.bulkImportDescription);
  }
}
