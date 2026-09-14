import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Aviso do gate Coldigom (débito técnico até o acervo PLPCG sair do
/// coldigui): listas com material fora do acervo PLPCG não geram link nem QR.
///
/// [offerLeafletOnly] = `true` (opção Folheto) mostra «Cancelar» / «Só o
/// folheto»; `false` (opção Só o link) mostra apenas «Entendi».
/// Retorna `true` somente quando o usuário escolhe «Só o folheto».
Future<bool> showColdigomShareDialog(
  BuildContext context, {
  required bool offerLeafletOnly,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.playlistShareColdigomTitle),
      content: Text(
        offerLeafletOnly
            ? l10n.playlistShareColdigomBodyLeaflet
            : l10n.playlistShareColdigomBodyLink,
      ),
      actions: [
        if (offerLeafletOnly) ...[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.playlistShareColdigomCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.playlistShareColdigomLeafletOnly),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.playlistShareColdigomDismiss),
          ),
      ],
    ),
  );
  return result ?? false;
}
