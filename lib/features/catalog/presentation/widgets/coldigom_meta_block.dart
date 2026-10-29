import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/domain/entities/coldigom_praise_metadata.dart';

/// Bloco de metadados do praise Coldigom (tom, ritmo, autor, tags) e prévia da letra.
class ColdigomMetaBlock extends StatefulWidget {
  const ColdigomMetaBlock({
    required this.l10n,
    this.title,
    this.number,
    this.meta,
    this.lyricsText,
    this.onOpenLyrics,
    this.showLyricsPreview = true,
    this.collapsibleDetails = false,
    this.initiallyExpanded = false,
    super.key,
  });

  final String? title;
  final String? number;
  final ColdigomPraiseMetadata? meta;
  final String? lyricsText;
  final VoidCallback? onOpenLyrics;
  final AppLocalizations l10n;
  final bool showLyricsPreview;
  final bool collapsibleDetails;
  final bool initiallyExpanded;

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
  State<ColdigomMetaBlock> createState() => _ColdigomMetaBlockState();
}

class _ColdigomMetaBlockState extends State<ColdigomMetaBlock> {
  late bool _detailsExpanded;

  @override
  void initState() {
    super.initState();
    _detailsExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = widget.title != null && widget.title!.trim().isNotEmpty;
    final meta = widget.meta;
    final hasMetadata = meta != null && meta.hasAnyField;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final maxLines = isWide ? 5 : 2;
        final previewLines =
            (widget.lyricsText != null && widget.showLyricsPreview)
                ? ColdigomMetaBlock.extractPreviewLines(
                    widget.lyricsText!,
                    maxLines: maxLines,
                  )
                : const <String>[];
        final hasLyrics = previewLines.isNotEmpty;

        if (!hasTitle && !hasMetadata && !hasLyrics) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTitle) ...[
                  _buildTitleSection(),
                  if (hasMetadata || hasLyrics) ...[
                    const SizedBox(height: 10),
                    Divider(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      height: 1,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                if (isWide && hasMetadata && hasLyrics)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildMetadataContent(context, isWide: isWide),
                        ),
                        const SizedBox(width: 14),
                        VerticalDivider(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          width: 1,
                          thickness: 1,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 5,
                          child: _buildLyricsPreview(
                            context,
                            previewLines,
                            maxLines: maxLines,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (hasMetadata)
                    _buildMetadataContent(context, isWide: isWide),
                  if (hasMetadata && hasLyrics) ...[
                    const SizedBox(height: 10),
                    Divider(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      height: 1,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (hasLyrics)
                    _buildLyricsPreview(
                      context,
                      previewLines,
                      maxLines: maxLines,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleSection() {
    final number = widget.number?.trim() ?? '';
    final title = widget.title?.trim() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (number.isNotEmpty) ...[
          Text(
            number,
            style: AppTypography.headline.copyWith(
              color: AppColors.title,
              fontSize: 20,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: AppTypography.headline.copyWith(
              color: AppColors.title,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataContent(BuildContext context, {required bool isWide}) {
    final m = widget.meta;
    final tonality = m?.tonality.trim() ?? '';
    final rhythm = m?.rhythm.trim() ?? '';
    final author = m?.author.trim() ?? '';
    final biblical = m?.biblicalSummary?.trim() ?? '';
    final hasPair = tonality.isNotEmpty || rhythm.isNotEmpty;
    final tagNames = m?.tagNames ?? const <String>[];
    final hasCollapsible = author.isNotEmpty || biblical.isNotEmpty;
    final showExpanded = !widget.collapsibleDetails || isWide || _detailsExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPair)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: tonality.isNotEmpty
                    ? _metaField(widget.l10n.coldigomMetaTonality, tonality)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: rhythm.isNotEmpty
                    ? _metaField(widget.l10n.coldigomMetaRhythm, rhythm)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        if (tagNames.isNotEmpty) ...[
          if (hasPair) const SizedBox(height: 10),
          Text(
            widget.l10n.coldigomMetaTags.toUpperCase(),
            style: AppTypography.tagLabel.copyWith(
              color: AppColors.title.withValues(alpha: 0.7),
              letterSpacing: 1.1,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tagNames)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.label.copyWith(
                      color: AppColors.title,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (widget.collapsibleDetails && !isWide && hasCollapsible) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _detailsExpanded
                        ? widget.l10n.coldigomMetaLessDetails
                        : widget.l10n.coldigomMetaMoreDetails,
                    style: AppTypography.label.copyWith(
                      color: AppColors.title.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _detailsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.title.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (showExpanded) ...[
          if (author.isNotEmpty) ...[
            const SizedBox(height: 8),
            _metaField(widget.l10n.coldigomMetaAuthor, author),
          ],
          if (biblical.isNotEmpty) ...[
            const SizedBox(height: 8),
            _metaField(
              widget.l10n.coldigomMetaBiblical,
              biblical,
              singleLine: true,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildLyricsPreview(
    BuildContext context,
    List<String> previewLines, {
    required int maxLines,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpenLyrics,
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
                    widget.l10n.lyricsTab.toUpperCase(),
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
                maxLines: maxLines,
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

  Widget _metaField(String label, String value, {bool singleLine = false}) {
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
          maxLines: singleLine ? 1 : null,
          overflow: singleLine ? TextOverflow.ellipsis : null,
          style: AppTypography.body.copyWith(
            color: AppColors.title,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
