import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

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
const _mediumWidth = carouselChipMetadataMediumWidth;

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
/// chip ([LayoutBuilder]):
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
class CarouselLouvorChip extends StatelessWidget {
  const CarouselLouvorChip({
    required this.item,
    this.variant = CarouselLouvorChipVariant.modal,
    this.metadataSummary,
    this.showDragHandle = false,
    this.onTap,
    this.onRemove,
    this.onAdd,
    this.onShare,
    this.isAdded = false,
    this.loading = false,
    this.shareLoading = false,
    super.key,
  });

  /// Louvor enriquecido com metadados do manifest (`numero`, `nome`, etc.).
  final CarouselItem item;

  /// `topBar` na barra do shell; `modal` (pill) em listas, modal e leitor.
  final CarouselLouvorChipVariant variant;

  /// Substitui categoria/classificação — ex.: "2 entradas com 1 arranjo".
  final String? metadataSummary;

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

  bool get _isTopBar => variant == CarouselLouvorChipVariant.topBar;

  Widget? get _trailingAction {
    if (loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.gold,
        ),
      );
    }
    if (onRemove != null) return _RemoveButton(onPressed: onRemove!);
    if (isAdded) return const _AddedIndicator();
    if (onAdd != null) return _AddButton(onPressed: onAdd!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final classificationLabel =
        LouvorClassification.displayLabel(item.classificacao);
    final categoryIcon = LouvorMaterialIcons.forCategory(item.categoria);
    final chipRadius = _isTopBar ? _topBarChipRadius : _modalChipRadius;
    final padding = _isTopBar
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 6);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.title,
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
            child: _ChipBody(
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
                          color: AppColors.textLight,
                          shadows: const [],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _MetadataRow(
                        width: width,
                        numero: _isTopBar ? item.numero : null,
                        summary: metadataSummary,
                        classificationLabel: classificationLabel,
                        categoria: item.categoria,
                        categoryIcon: categoryIcon,
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
            _ShareOverflowButton(
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

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.width,
    required this.classificationLabel,
    required this.categoria,
    required this.categoryIcon,
    this.numero,
    this.summary,
  });

  final double width;
  final String? numero;
  final String? summary;
  final String classificationLabel;
  final String categoria;
  final IconData categoryIcon;

  Widget? _numeroLeading(TextStyle metaStyle) {
    if (numero == null || numero!.isEmpty) return null;
    return Text(
      '#$numero',
      style: metaStyle.copyWith(fontWeight: FontWeight.w700),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metaStyle = AppTypography.body.copyWith(
      fontSize: width < _compactWidth ? 10 : 11,
      color: AppColors.textLight.withValues(alpha: 0.9),
      fontWeight: FontWeight.w500,
    );
    final numeroWidget = _numeroLeading(metaStyle);

    if (summary != null) {
      return Row(
        children: [
          if (numeroWidget != null) ...[
            numeroWidget,
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              summary!,
              style: metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (width < _compactWidth) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (numeroWidget != null) ...[
            numeroWidget,
            const SizedBox(width: 6),
          ],
          if (classificationLabel.isNotEmpty)
            Tooltip(
              message: classificationLabel,
              child: Icon(
                Icons.collections_bookmark_outlined,
                size: 14,
                color: AppColors.textLight.withValues(alpha: 0.9),
              ),
            ),
          if (classificationLabel.isNotEmpty && categoria.isNotEmpty)
            const SizedBox(width: 6),
          if (categoria.isNotEmpty)
            Tooltip(
              message: categoria,
              child: Icon(
                categoryIcon,
                size: 14,
                color: AppColors.textLight.withValues(alpha: 0.9),
              ),
            ),
        ],
      );
    }

    if (width < _mediumWidth) {
      return Row(
        children: [
          if (numeroWidget != null) ...[
            numeroWidget,
            const SizedBox(width: 6),
          ],
          if (classificationLabel.isNotEmpty) ...[
            Tooltip(
              message: classificationLabel,
              child: Icon(
                Icons.collections_bookmark_outlined,
                size: 14,
                color: AppColors.textLight.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                classificationLabel,
                style: metaStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (classificationLabel.isNotEmpty && categoria.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('·', style: metaStyle),
            ),
          if (categoria.isNotEmpty) ...[
            Tooltip(
              message: categoria,
              child: Icon(
                categoryIcon,
                size: 14,
                color: AppColors.textLight.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                categoria,
                style: metaStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        if (numeroWidget != null) ...[
          numeroWidget,
          const SizedBox(width: 6),
        ],
        if (classificationLabel.isNotEmpty)
          Flexible(
            child: Text(
              classificationLabel,
              style: metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (classificationLabel.isNotEmpty && categoria.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('·', style: metaStyle),
          ),
        if (categoria.isNotEmpty) ...[
          Icon(
            categoryIcon,
            size: 14,
            color: AppColors.textLight.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              categoria,
              style: metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChipBody extends StatelessWidget {
  const _ChipBody({
    required this.borderRadius,
    required this.child,
    this.onTap,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CircleActionButton(
      icon: Icons.close,
      onPressed: onPressed,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CircleActionButton(
      icon: Icons.add,
      onPressed: onPressed,
    );
  }
}

class _AddedIndicator extends StatelessWidget {
  const _AddedIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.textLight.withValues(alpha: 0.85),
          width: 1.5,
        ),
      ),
      child: const SizedBox(
        width: 24,
        height: 24,
        child: Icon(
          Icons.check,
          size: 16,
          color: AppColors.textLight,
        ),
      ),
    );
  }
}

enum _LouvorChipMenuAction { share }

class _ShareOverflowButton extends StatelessWidget {
  const _ShareOverflowButton({
    required this.onShare,
    required this.shareLabel,
    this.loading = false,
  });

  final void Function(Rect sharePositionOrigin) onShare;
  final String shareLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LouvorChipMenuAction>(
      padding: EdgeInsets.zero,
      iconSize: 20,
      splashRadius: 18,
      tooltip: shareLabel,
      icon: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.gold,
              ),
            )
          : Icon(
              Icons.more_vert,
              size: 20,
              color: AppColors.textLight.withValues(alpha: 0.9),
            ),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      onSelected: (_) {
        onShare(sharePositionOriginFromContextOrFallback(context));
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _LouvorChipMenuAction.share,
          enabled: !loading,
          child: Text(shareLabel),
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textLight,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            icon,
            size: 16,
            color: AppColors.title,
          ),
        ),
      ),
    );
  }
}
