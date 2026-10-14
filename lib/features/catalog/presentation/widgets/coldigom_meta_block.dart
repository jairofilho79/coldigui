import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/domain/entities/coldigom_praise_metadata.dart';

/// Bloco de metadados do praise Coldigom (tom, ritmo, autor, tags).
class ColdigomMetaBlock extends StatelessWidget {
  const ColdigomMetaBlock({
    required this.meta,
    required this.l10n,
    super.key,
  });

  final ColdigomPraiseMetadata meta;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tonality = meta.tonality.trim();
    final rhythm = meta.rhythm.trim();
    final author = meta.author.trim();
    final hasPair = tonality.isNotEmpty || rhythm.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPair)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: tonality.isNotEmpty
                        ? _metaField(l10n.coldigomMetaTonality, tonality)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: rhythm.isNotEmpty
                        ? _metaField(l10n.coldigomMetaRhythm, rhythm)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            if (author.isNotEmpty) ...[
              if (hasPair) const SizedBox(height: 10),
              _metaField(l10n.coldigomMetaAuthor, author),
            ],
            if (meta.tagNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.coldigomMetaTags.toUpperCase(),
                style: AppTypography.tagLabel.copyWith(
                  color: AppColors.title.withValues(alpha: 0.7),
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final tag in meta.tagNames)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.gold, width: 1.5),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.label.copyWith(
                          color: AppColors.title,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.title.withValues(alpha: 0.75),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: AppColors.title,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
