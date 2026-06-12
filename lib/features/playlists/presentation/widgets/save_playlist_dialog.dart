import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/utils/playlist_defaults.dart';

/// Diálogo para salvar ou renomear playlist (UC-06).
Future<String?> showSavePlaylistDialog(
  BuildContext context, {
  String? initialName,
  String? title,
  String? confirmLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(
    text: initialName ?? defaultPlaylistName(),
  );

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title ?? l10n.playlistSaveTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.playlistSaveNameLabel,
        ),
        onSubmitted: (_) {
          final nome = controller.text.trim();
          if (nome.isNotEmpty) {
            Navigator.of(dialogContext).pop(nome);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.playlistSaveCancel),
        ),
        TextButton(
          onPressed: () {
            final nome = controller.text.trim();
            if (nome.isEmpty) return;
            Navigator.of(dialogContext).pop(nome);
          },
          child: Text(confirmLabel ?? l10n.playlistSaveConfirm),
        ),
      ],
    ),
  );
}
