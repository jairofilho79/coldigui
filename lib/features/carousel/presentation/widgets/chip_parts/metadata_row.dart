import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/offline_availability_badge.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:flutter/material.dart';

import '../carousel_louvor_chip.dart'
    show carouselChipMetadataCompactWidth, carouselChipMetadataMediumWidth;
import 'material_kinds_row.dart';

const _compactWidth = carouselChipMetadataCompactWidth;
const _mediumWidth = carouselChipMetadataMediumWidth;

/// Linha de metadados do chip (classificação + categoria), responsiva à
/// largura disponível — ver doc de [CarouselLouvorChip].
///
/// Extraído de `carousel_louvor_chip.dart` (E4) — sem mudança de
/// comportamento.
class ChipMetadataRow extends StatelessWidget {
  const ChipMetadataRow({
    required this.width,
    required this.classificationLabel,
    required this.categoria,
    required this.categoryIcon,
    this.numero,
    this.summary,
    this.materialKindsGroup,
    this.onMaterialKindTap,
    this.offlineAvailability = PdfOfflineAvailability.notAvailable,
    super.key,
  });

  final double width;
  final String? numero;
  final String? summary;

  /// Variante de card (C5): quando presente, substitui classificação +
  /// categoria por [MaterialKindsRow] — ignorado se [summary] também vier
  /// (ex.: progresso de download).
  final LouvorGroup? materialKindsGroup;

  /// Toque num ícone de [MaterialKindsRow] — repassado direto.
  final void Function(MaterialKind kind)? onMaterialKindTap;
  final String classificationLabel;
  final String categoria;
  final IconData categoryIcon;
  final PdfOfflineAvailability offlineAvailability;

  Widget _offlineBadge() {
    if (offlineAvailability == PdfOfflineAvailability.notAvailable) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: OfflineAvailabilityBadge(availability: offlineAvailability),
    );
  }

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
      height: 1.1,
      color: AppColors.textLight.withValues(alpha: 0.9),
      fontWeight: FontWeight.w500,
    );
    final numeroWidget = _numeroLeading(metaStyle);

    if (summary != null) {
      return Row(
        children: [
          if (numeroWidget != null) ...[numeroWidget, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              summary!,
              style: metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _offlineBadge(),
        ],
      );
    }

    if (materialKindsGroup != null) {
      return Row(
        children: [
          if (numeroWidget != null) ...[numeroWidget, const SizedBox(width: 6)],
          Flexible(
            child: MaterialKindsRow(
              group: materialKindsGroup!,
              onTap: onMaterialKindTap,
            ),
          ),
          _offlineBadge(),
        ],
      );
    }

    if (width < _compactWidth) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
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
            _offlineBadge(),
          ],
        ),
      );
    }

    if (width < _mediumWidth) {
      return Row(
        children: [
          if (numeroWidget != null) ...[numeroWidget, const SizedBox(width: 6)],
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
          _offlineBadge(),
        ],
      );
    }

    return Row(
      children: [
        if (numeroWidget != null) ...[numeroWidget, const SizedBox(width: 6)],
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
        _offlineBadge(),
      ],
    );
  }
}
