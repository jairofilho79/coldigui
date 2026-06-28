import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Diálogo entre o share do folheto e o share do link (modo WhatsApp).
Future<bool> showPlaylistShareWhatsAppStepDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.playlistShareWhatsAppStepTitle),
      content: Text(l10n.playlistShareWhatsAppStepMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.playlistShareWhatsAppStepCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.playlistShareWhatsAppStepContinue),
        ),
      ],
    ),
  );
  return result ?? false;
}
