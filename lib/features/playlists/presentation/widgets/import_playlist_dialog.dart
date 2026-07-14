import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../../l10n/app_localizations.dart';

/// Resultado do diálogo de importação de playlist (UC-07).
class ImportPlaylistDialogResult {
  const ImportPlaylistDialogResult({
    required this.sharePdfs,
    required this.shareName,
    this.shareAudios = '',
  });

  /// Valor bruto do param `sharepdfs` (CSV).
  final String sharePdfs;

  /// Valor bruto do param `shareaudios` (CSV), opcional.
  final String shareAudios;

  /// Nome da playlist conforme param `sharename`.
  final String shareName;
}

/// Diálogo para colar URL de playlist compartilhada (UC-07, Fase 4.4).
Future<ImportPlaylistDialogResult?> showImportPlaylistDialog(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();

  return showDialog<ImportPlaylistDialogResult>(
    context: context,
    builder: (dialogContext) {
      var invalidInput = false;

      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final params = extractShareParamsFromUserInput(controller.text);
            if (params == null) {
              setState(() => invalidInput = true);
              return;
            }
            Navigator.of(dialogContext).pop(
              ImportPlaylistDialogResult(
                sharePdfs: params.sharePdfs,
                shareAudios: params.shareAudios,
                shareName: params.shareName,
              ),
            );
          }

          Future<void> pasteFromClipboard() async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text?.trim();
            if (text == null || text.isEmpty) return;
            controller.text = text;
            setState(() => invalidInput = false);
          }

          return AlertDialog(
            title: Text(l10n.playlistImportTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.playlistImportUrlLabel,
                    errorText: invalidInput
                        ? l10n.playlistImportInvalidUrl
                        : null,
                  ),
                  onChanged: (_) {
                    if (invalidInput) {
                      setState(() => invalidInput = false);
                    }
                  },
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: pasteFromClipboard,
                    icon: const Icon(Icons.content_paste),
                    label: Text(l10n.playlistImportPaste),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.playlistSaveCancel),
              ),
              TextButton(
                onPressed: submit,
                child: Text(l10n.playlistImportConfirm),
              ),
            ],
          );
        },
      );
    },
  );
}
