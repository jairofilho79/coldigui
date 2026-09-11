import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'chip_parts/chip_body.dart';
import 'chip_parts/chip_buttons.dart';
import 'chip_parts/metadata_row.dart';
import 'chip_parts/share_overflow_button.dart';

export 'chip_parts/chip_buttons.dart' show CarouselLouvorAddButton;

/// Altura do chip na barra do leitor (variante modal/pill).
const carouselChipBarHeight = 58.0;

/// Altura do chip na barra superior do shell (variante retangular).
const carouselChipTopBarHeight = 52.0;

/// Largura de referência do chip na barra (compacto).
const carouselChipMaxWidth = 168.0;

/// Largura abaixo da qual a linha de metadados exibe apenas ícones (com
/// [Tooltip]).
const carouselChipMetadataCompactWidth = 180.0;

/// Largura abaixo da qual classificação e categoria usam ícone + texto
/// truncável; acima disso, classificação fica só texto e categoria ícone +
/// texto.
const carouselChipMetadataMediumWidth = 280.0;

const _modalChipRadius = 24.0;
const _topBarChipRadius = 8.0;
const _compactWidth = carouselChipMetadataCompactWidth;

/// Layout do chip — barra superior do shell vs modal/leitor.
enum CarouselLouvorChipVariant {
  /// Pill (`borderRadius` 24); `#numero — nome` na linha do título.
  modal,

  /// Retangular (`borderRadius` 8); só `nome` no título; `#numero` à esquerda
  /// da linha de metadados — usado em [CarouselChips].
  topBar,
}

/// Chip temático PLPCG — fundo vermelho, borda dourada, duas linhas de info.
///
/// Usado na [CarouselNavigatorBar] (variante [CarouselLouvorChipVariant.topBar]),
/// no modal de seleção (variante [CarouselLouvorChipVariant.modal]),
/// em [PlaylistListTile] (`onRemove`) e em [LouvorCard] — pesquisa/biblioteca
/// (`onAdd`, `isAdded`, `loading`, `onShare`, `shareLoading`).
///
/// A linha de metadados (classificação + categoria) é responsiva à largura do
/// chip ([LayoutBuilder]) — ver [ChipMetadataRow]:
///
/// - &lt; [carouselChipMetadataCompactWidth]: só ícones com [Tooltip].
/// - [carouselChipMetadataCompactWidth]–[carouselChipMetadataMediumWidth]:
///   ícone + texto truncável para classificação **e** categoria.
/// - ≥ [carouselChipMetadataMediumWidth]: classificação só texto; categoria
///   ícone + texto.
///
/// **Trailing (prioridade):** [loading] → spinner; senão [onRemove] → botão X;
/// senão [isAdded] → check; senão [onAdd] → botão +; depois menu ⋮ se
/// [onShare] (UC-04).
///
/// [onTap] abre o louvor no leitor (UC-04/05) — toque no corpo do chip, sem
/// interferir no trailing nem no drag handle do modal.
///
/// Corpo, botões, linha de metadados e menu de compartilhar (E4) vivem em
/// `chip_parts/` ([ChipBody], [ChipRemoveButton]/[ChipAddButton]/
/// [ChipAddedIndicator]/[CircleActionButton], [ChipMetadataRow]
/// (com `MaterialKindsRow` na variante de card, C5), [ShareOverflowButton]).
class CarouselLouvorChip extends StatelessWidget {
  const CarouselLouvorChip({
    required this.item,
    this.variant = CarouselLouvorChipVariant.modal,
    this.metadataSummary,
    this.materialKindsGroup,
    this.onMaterialKindTap,
    this.showDragHandle = false,
    this.onTap,
    this.onRemove,
    this.onAdd,
    this.onShare,
    this.isAdded = false,
    this.loading = false,
    this.shareLoading = false,
    this.offlineAvailability = PdfOfflineAvailability.notAvailable,
    super.key,
  });

  /// Louvor enriquecido com metadados do manifest (`numero`, `nome`, etc.).
  final CarouselItem item;

  /// `topBar` na barra do shell; `modal` (pill) em listas, modal e leitor.
  final CarouselLouvorChipVariant variant;

  /// Substitui categoria/classificação — ex.: progresso de download. Tem
  /// prioridade sobre [materialKindsGroup].
  final String? metadataSummary;

  /// Variante de card da Home/Biblioteca (C5): quando presente, a linha de
  /// metadados vira [MaterialKindsRow] — ícones por tipo de material do
  /// grupo — no lugar de classificação/categoria.
  final LouvorGroup? materialKindsGroup;

  /// Toque num ícone de [materialKindsGroup] — ex.: abrir o `MaterialSheet`.
  final void Function(MaterialKind kind)? onMaterialKindTap;

  /// Exibe ícone de drag à esquerda — usado no [ReorderableListView] do modal.
  final bool showDragHandle;

  /// Toque no corpo do chip — tipicamente [openCarouselPdfInReader].
  final VoidCallback? onTap;

  /// Botão "X" no trailing — usado no modal de seleção e em [PlaylistListTile].
  final VoidCallback? onRemove;

  /// Botão "+" — usado em [LouvorCard] (catálogo/biblioteca).
  final VoidCallback? onAdd;

  /// Menu overflow (⋮) com **Compartilhar** — UC-04, paridade com o leitor.
  final void Function(Rect sharePositionOrigin)? onShare;

  /// Indica que o louvor já está na seleção (exibe check no trailing).
  final bool isAdded;

  /// Spinner no trailing enquanto uma ação assíncrona está em curso.
  final bool loading;

  /// Spinner no menu ⋮ enquanto o share está em curso.
  final bool shareLoading;

  /// Badge de disponibilidade offline no catálogo (permanente vs LRU).
  final PdfOfflineAvailability offlineAvailability;

  bool get _isTopBar => variant == CarouselLouvorChipVariant.topBar;

  Widget? get _trailingAction {
    if (loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
      );
    }
    if (onRemove != null) return ChipRemoveButton(onPressed: onRemove!);
    if (isAdded) return const ChipAddedIndicator();
    if (onAdd != null) return ChipAddButton(onPressed: onAdd!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final classificationLabel = LouvorClassification.displayLabel(
      item.classificacao,
    );
    final categoryIcon = LouvorMaterialIcons.forKind(
      LouvorMaterialIcons.kindForCategory(item.categoria),
    );
    final chipRadius = _isTopBar ? _topBarChipRadius : _modalChipRadius;
    final padding = _isTopBar
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    final backgroundColor = item.source == LouvorDataSource.coldigom
        ? AppColors.chipColdigom
        : AppColors.title;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(chipRadius),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: AppColors.shadowMd,
      ),
      padding: padding,
      child: Row(
        children: [
          if (showDragHandle) ...[
            Icon(
              Icons.drag_indicator,
              color: AppColors.textLight.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: ChipBody(
              borderRadius: BorderRadius.circular(chipRadius),
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _titleLine(item, _isTopBar),
                        style: AppTypography.headline.copyWith(
                          fontSize: width < _compactWidth ? 12 : 14,
                          height: 1.1,
                          color: AppColors.textLight,
                          shadows: const [],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      ChipMetadataRow(
                        width: width,
                        numero: _isTopBar ? item.numero : null,
                        summary: metadataSummary,
                        materialKindsGroup: materialKindsGroup,
                        onMaterialKindTap: onMaterialKindTap,
                        classificationLabel: classificationLabel,
                        categoria: item.categoria,
                        categoryIcon: categoryIcon,
                        offlineAvailability: offlineAvailability,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_trailingAction != null) ...[
            const SizedBox(width: 4),
            _trailingAction!,
          ],
          if (onShare != null) ...[
            const SizedBox(width: 2),
            ShareOverflowButton(
              onShare: onShare!,
              shareLabel:
                  AppLocalizations.of(context)?.sharePdf ?? 'Compartilhar',
              loading: shareLoading,
            ),
          ],
        ],
      ),
    );
  }

  static String _titleLine(CarouselItem item, bool topBar) {
    if (topBar || item.numero.isEmpty) return item.nome;
    return '#${item.numero} — ${item.nome}';
  }
}
