import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Aviso de que a lista não sobe ao vivo por ter material fora do Coldigom
/// (`nonColdigomEntries` não vazio). Só informa — nada é ativado.
Future<void> showLiveColdigomOnlyDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.liveColdigomOnlyTitle),
      content: Text(l10n.liveColdigomOnlyBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.liveOk),
        ),
      ],
    ),
  );
}
