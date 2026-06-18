import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Barra compartilhada: chip único, setas condicionais, lista e ações extras.
///
/// Embutida em [CarouselBarShell] no shell ([CarouselChips]) e na barra 2 do
/// leitor PDF ([PdfReaderScreen]).
///
/// Ícones (setas, lista) usam [carouselBarIconButtonStyle] — vinho PLPCG
/// ([AppColors.title]), inclusive no estado desabilitado durante [loading].
///
/// [onChipTap] — no shell, abre o louvor focado em `/leitor`; omitido no
/// leitor (chip já representa o PDF em exibição).
///
/// [trailingActions] — tipicamente [CarouselBarTrailingActions] (salvar
/// playlist, folheto, limpar) no shell e no leitor.
class CarouselNavigatorBar extends StatelessWidget {
  const CarouselNavigatorBar({
    required this.item,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onOpenList,
    this.chipVariant = CarouselLouvorChipVariant.modal,
    this.onPrevious,
    this.onNext,
    this.onChipTap,
    this.loading = false,
    this.trailingActions = const [],
    super.key,
  });

  final CarouselItem item;
  final CarouselLouvorChipVariant chipVariant;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Propagado para [CarouselLouvorChip.onTap] quando não [loading].
  final VoidCallback? onChipTap;
  final VoidCallback onOpenList;

  /// Desabilita setas/chip; o botão de lista permanece habilitado.
  final bool loading;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        if (canGoPrevious)
          IconButton(
            style: carouselBarIconButtonStyle,
            tooltip: l10n?.readerCarouselPrevious ?? 'Louvor anterior',
            onPressed: loading ? null : onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
        Flexible(
          child: CarouselLouvorChip(
            item: item,
            variant: chipVariant,
            onTap: loading ? null : onChipTap,
          ),
        ),
        if (canGoNext)
          IconButton(
            style: carouselBarIconButtonStyle,
            tooltip: l10n?.readerCarouselNext ?? 'Próximo louvor',
            onPressed: loading ? null : onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n?.carouselOpenList ?? 'Ver seleção',
          onPressed: onOpenList,
          icon: const Icon(Icons.view_list),
        ),
        ...trailingActions,
      ],
    );
  }
}
