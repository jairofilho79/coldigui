import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/live_room_link.dart';

/// Diálogo para colar o link (ou só o código) de uma sala ao vivo — o par do
/// «Importar lista» para quem recebeu o link fora do app. Devolve o código
/// da sala, ou `null` se cancelou.
Future<String?> showJoinLiveRoomDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      var invalidInput = false;

      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final code = parseLiveRoomCodeFromUserInput(controller.text);
            if (code == null) {
              setState(() => invalidInput = true);
              return;
            }
            Navigator.of(dialogContext).pop(code);
          }

          Future<void> pasteFromClipboard() async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text?.trim();
            if (text == null || text.isEmpty) return;
            controller.text = text;
            setState(() => invalidInput = false);
          }

          return AlertDialog(
            title: Text(l10n.liveJoinRoomTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.liveJoinRoomInputLabel,
                    errorText: invalidInput ? l10n.liveJoinRoomInvalid : null,
                  ),
                  onChanged: (_) {
                    if (invalidInput) setState(() => invalidInput = false);
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
                child: Text(l10n.liveJoinRoomConfirm),
              ),
            ],
          );
        },
      );
    },
  );
}
