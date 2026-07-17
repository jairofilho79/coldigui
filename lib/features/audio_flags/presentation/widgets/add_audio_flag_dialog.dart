import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Dialog para rótulo opcional ao criar marcador.
Future<String?> showAddAudioFlagDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          l10n.audioFlagAddTitle,
          style: const TextStyle(color: AppColors.title),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.title),
          decoration: InputDecoration(
            hintText: l10n.audioFlagLabelHint,
            hintStyle: TextStyle(color: AppColors.title.withValues(alpha: 0.5)),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.title),
            child: Text(l10n.audioFlagCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: TextButton.styleFrom(foregroundColor: AppColors.title),
            child: Text(l10n.audioFlagSave),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
