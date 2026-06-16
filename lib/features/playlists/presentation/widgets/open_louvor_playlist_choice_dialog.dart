import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Escolha do usuário ao abrir louvor fora da lista ativa.
enum OpenLouvorPlaylistChoice {
  addToCurrent,
  createNew,
}

/// Pergunta se o louvor entra na lista atual ou em uma nova (UC-04 + UC-06).
///
/// Retorna `null` quando o usuário fecha o modal (X ou toque fora).
Future<OpenLouvorPlaylistChoice?> showOpenLouvorPlaylistChoiceDialog(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context)!;

  return showDialog<OpenLouvorPlaylistChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.playlistOpenLouvorChoiceTitle),
      content: Text(l10n.playlistOpenLouvorChoiceMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(
            OpenLouvorPlaylistChoice.addToCurrent,
          ),
          child: Text(l10n.playlistOpenLouvorChoiceAddToCurrent),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(
            OpenLouvorPlaylistChoice.createNew,
          ),
          child: Text(l10n.playlistOpenLouvorChoiceCreateNew),
        ),
      ],
    ),
  );
}
