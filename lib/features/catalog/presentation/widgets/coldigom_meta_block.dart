import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/domain/entities/coldigom_praise_metadata.dart';

/// Bloco de metadados do praise Coldigom (tom, ritmo, autor, tags) e prévia da letra.
class ColdigomMetaBlock extends StatelessWidget {
  const ColdigomMetaBlock({
    required this.l10n,
    this.meta,
    this.lyricsText,
    this.onOpenLyrics,
    this.showLyricsPreview = true,
    super.key,
  });

  final ColdigomPraiseMetadata? meta;
  final String? lyricsText;
  final VoidCallback? onOpenLyrics;
  final AppLocalizations l10n;
  final bool showLyricsPreview;

  /// Extrai as primeiras [maxLines] linhas não vazias da letra para exibição de prévia.
  static List<String> extractPreviewLines(String text, {int maxLines = 5}) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(maxLines)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasMetadata = meta != null && meta!.hasAnyField;
    final previewLines = (lyricsText != null && showLyricsPreview)
        ? extractPreviewLines(lyricsText!)
        : const <String>[];
    final hasLyrics = previewLines.isNotEmpty;

    if (!hasMetadata && !hasLyrics) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            if (isWide && hasMetadata && hasLyrics) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _buildMetadataContent(context)),
                    const SizedBox(width: 14),
                    VerticalDivider(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      width: 1,
                      thickness: 1,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: _buildLyricsPreview(context, previewLines),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasMetadata) _buildMetadataContent(context),
                if (hasMetadata && hasLyrics) ...[
                  const SizedBox(height: 10),
                  Divider(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    height: 1,
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasLyrics) _buildLyricsPreview(context, previewLines),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetadataContent(BuildContext context) {
    final m = meta;
    final tonality = m?.tonality.trim() ?? '';
    final rhythm = m?.rhythm.trim() ?? '';
    final author = m?.author.trim() ?? '';
    final hasPair = tonality.isNotEmpty || rhythm.isNotEmpty;
    final tagNames = m?.tagNames ?? const <String>[];

    return Column(
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
        if (tagNames.isNotEmpty) ...[
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
              for (final tag in tagNames)
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
    );
  }

  Widget _buildLyricsPreview(
    BuildContext context,
    List<String> previewLines,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenLyrics,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lyrics_outlined,
                    size: 16,
                    color: AppColors.title,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.lyricsTab.toUpperCase(),
                    style: AppTypography.tagLabel.copyWith(
                      color: AppColors.title.withValues(alpha: 0.8),
                      letterSpacing: 1.1,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.title.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                previewLines.join('\n'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  color: AppColors.textDark,
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
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
