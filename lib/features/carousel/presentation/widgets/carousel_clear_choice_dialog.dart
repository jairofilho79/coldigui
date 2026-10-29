import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Escolha ao limpar a seleção do carousel.
enum CarouselClearChoice { newList, deleteList }

/// Diálogo: Cancelar | Nova Lista | Apagar lista? (slot direito só se [canDelete]).
///
/// Retorna `null` ao cancelar ou fechar. [canDelete] false mantém slot direito
/// vazio para «Nova Lista» ficar no meio (memória muscular).
Future<CarouselClearChoice?> showCarouselClearChoiceDialog(
  BuildContext context, {
  required bool canDelete,
}) {
  final l10n = AppLocalizations.of(context)!;

  return showDialog<CarouselClearChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.carouselClearConfirmTitle),
      content: Text(l10n.carouselClearConfirmMessage),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.carouselClearCancel),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(CarouselClearChoice.newList),
                child: Text(l10n.carouselClearNewList),
              ),
            ),
            Expanded(
              child: canDelete
                  ? TextButton(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(CarouselClearChoice.deleteList),
                      child: Text(l10n.carouselClearDeleteList),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    ),
  );
}
