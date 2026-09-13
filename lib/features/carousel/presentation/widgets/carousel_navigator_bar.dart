import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Barra da lista ativa: chip-carrossel + grupo «louvor» + grupo «lista»
/// (spec 2026-09-12).
///
/// ```
/// [‹ chip ›]  ┃ Abrir  Material ┃ Lista  Compartilhar  Limpar
///               (louvor)          (lista)
/// ```
///
/// Embutida em `CarouselBarShell` no shell (`CarouselChips`), em toda rota.
///
/// [onChipTap] / [onOpen] — abrir o item focado (leitor ou player); ausentes
/// no leitor, onde o chip já representa o material aberto.
///
/// [swapMaterial] — `CarouselSwapMaterialButton`, omitido quando o louvor não
/// tem alternativa. Sem [onOpen] e sem [swapMaterial], o grupo «louvor» não
/// é desenhado.
///
/// [trailingActions] — `CarouselBarTrailingActions` (compartilhar + limpar),
/// desenhadas dentro do grupo «lista», depois de «Lista».
///
/// [showLabels] — legendas sob os ícones (barra ≥ `carouselBarLabelsMinWidth`).
class CarouselNavigatorBar extends StatelessWidget {
  const CarouselNavigatorBar({
    required this.item,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onOpenSelection,
    this.showLabels = true,
    this.chipVariant = CarouselLouvorChipVariant.topBar,
    this.onPrevious,
    this.onNext,
    this.onChipTap,
    this.onOpen,
    this.swapMaterial,
    this.loading = false,
    this.trailingActions = const [],
    super.key,
  });

  final CarouselItem item;
  final CarouselLouvorChipVariant chipVariant;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool showLabels;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Propagado para [CarouselLouvorChip.onTap] quando não [loading].
  final VoidCallback? onChipTap;

  /// Ação «Abrir» do item focado — omitida (`null`) quando indisponível.
  ///
  /// No shell abre `/leitor`; ausente no leitor (sem alternativa útil ali).
  final VoidCallback? onOpen;

  /// Botão «Material» (trocar material). Omitido se o louvor não tem
  /// alternativa.
  final Widget? swapMaterial;

  /// Abre modal com louvores da seleção atual.
  final VoidCallback onOpenSelection;

  /// Desabilita setas/chip/abrir; «Lista» permanece habilitado.
  final bool loading;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasLouvorGroup = onOpen != null || swapMaterial != null;
    // A barra é filha solta de um `Column` (sem `Expanded`, D2) — ambiente
    // de altura infinita. O chip com setas usa `crossAxisAlignment.stretch`
    // (D5) e precisa de uma altura finita vinda de fora para não quebrar.
    final chipHeight = chipVariant == CarouselLouvorChipVariant.topBar
        ? carouselChipTopBarHeight
        : carouselChipBarHeight;

    return Row(
      children: [
        Flexible(
          child: SizedBox(
            height: chipHeight,
            child: CarouselLouvorChip(
              item: item,
              variant: chipVariant,
              showNavArrows: true,
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              onPrevious: loading ? null : onPrevious,
              onNext: loading ? null : onNext,
              onTap: loading ? null : onChipTap,
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (hasLouvorGroup) ...[
          CarouselBarActionGroup(
            tint: CarouselBarActionGroup.louvorTint,
            children: [
              if (onOpen != null)
                CarouselBarActionButton(
                  icon: Icons.file_open_outlined,
                  label: l10n?.carouselOpen ?? 'Abrir',
                  showLabel: showLabels,
                  onPressed: loading ? null : onOpen,
                ),
              ?swapMaterial,
            ],
          ),
          const CarouselBarGroupDivider(),
        ],
        CarouselBarActionGroup(
          tint: CarouselBarActionGroup.listaTint,
          children: [
            CarouselBarActionButton(
              icon: Icons.queue_music,
              label: l10n?.carouselList ?? 'Lista',
              showLabel: showLabels,
              onPressed: onOpenSelection,
            ),
            ...trailingActions,
          ],
        ),
      ],
    );
  }
}
