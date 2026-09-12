import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Barra compartilhada: chip único, setas, abrir, olho, layers e ações extras.
///
/// Embutida em [CarouselBarShell] no shell ([CarouselChips]) e na barra 2 do
/// leitor PDF ([PdfReaderScreen]).
///
/// Ícones usam [carouselBarIconButtonStyle] — vinho PLPCG ([AppColors.title]).
///
/// [onChipTap] — no shell, abre o louvor focado em `/leitor`; omitido no
/// leitor (chip já representa o PDF em exibição).
///
/// [trailingActions] — [CarouselBarTrailingActions] (overflow + limpar).
class CarouselNavigatorBar extends StatelessWidget {
  const CarouselNavigatorBar({
    required this.item,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onOpenSelection,
    this.chipVariant = CarouselLouvorChipVariant.modal,
    this.onPrevious,
    this.onNext,
    this.onChipTap,
    this.onOpenPlayer,
    this.swapMaterial,
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

  /// Ação principal do item focado — omitida (`null`) quando indisponível.
  ///
  /// No shell abre `/leitor`; ausente no leitor (sem alternativa útil ali).
  final VoidCallback? onOpenPlayer;

  /// Botão layers (trocar material). Omitido se o louvor não tem alternativa.
  final Widget? swapMaterial;

  /// Abre modal com louvores da seleção atual.
  final VoidCallback onOpenSelection;

  /// Desabilita setas/chip/abrir; olho permanece habilitado.
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
        if (onOpenPlayer != null)
          IconButton(
            style: carouselBarIconButtonStyle,
            tooltip: l10n?.playlistOpenInReader ?? 'Abrir no leitor',
            onPressed: loading ? null : onOpenPlayer,
            icon: const Icon(Icons.open_in_full),
          ),
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n?.carouselOpenList ?? 'Ver seleção',
          onPressed: onOpenSelection,
          icon: const Icon(Icons.visibility_outlined),
        ),
        ?swapMaterial,
        ...trailingActions,
      ],
    );
  }
}
