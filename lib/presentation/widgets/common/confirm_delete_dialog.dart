import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';

/// Ask the user to confirm a destructive action.
///
/// Respects the "confirm before delete" app setting: when it is disabled the
/// dialog is skipped and this returns true immediately.
Future<bool> confirmDelete(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  String? confirmLabel,
}) async {
  if (!ref.read(appSettingsProvider).confirmBeforeDelete) {
    return true;
  }

  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(confirmLabel ?? l10n.delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}
