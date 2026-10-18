import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Diálogo de confirmação — retorna `true` se confirmado, `false` se cancelado.
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
}) {
  final l10n = AppLocalizations.of(context);
  final effectiveCancel = cancelLabel ?? l10n?.cancel ?? 'Cancelar';
  final effectiveConfirm = confirmLabel ?? l10n?.confirm ?? 'Confirmar';

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(effectiveCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(effectiveConfirm),
        ),
      ],
    ),
  );
}
