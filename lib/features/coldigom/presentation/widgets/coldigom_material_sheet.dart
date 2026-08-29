import 'dart:async';

import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_material_sheet.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet Coldigom — metadados + abas por kind (PDF / áudio / YouTube).
///
/// Sem seções de ritmo. Abas só quando há ≥1 material daquele kind.
Future<void> showColdigomMaterialSheet({
  required BuildContext context,
  required LouvorGroup group,
  required ValueChanged<Louvor> onMaterialSelected,
  ValueChanged<AudioTrack>? onAudioSelected,
  ValueChanged<YoutubeMaterial>? onYoutubeSelected,
  LouvorMaterialAddCallback? onMaterialAdd,
  LouvorAudioAddCallback? onAudioAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return _ColdigomMaterialSheetBody(
        group: group,
        onMaterialSelected: onMaterialSelected,
        onAudioSelected: onAudioSelected,
        onYoutubeSelected: onYoutubeSelected,
        onMaterialAdd: onMaterialAdd,
        onAudioAdd: onAudioAdd,
      );
    },
  );
}

enum _ColdigomMaterialKind { pdf, audio, youtube }

class _ColdigomMaterialSheetBody extends ConsumerStatefulWidget {
  const _ColdigomMaterialSheetBody({
    required this.group,
    required this.onMaterialSelected,
    this.onAudioSelected,
    this.onYoutubeSelected,
    this.onMaterialAdd,
    this.onAudioAdd,
  });

  final LouvorGroup group;
  final ValueChanged<Louvor> onMaterialSelected;
  final ValueChanged<AudioTrack>? onAudioSelected;
  final ValueChanged<YoutubeMaterial>? onYoutubeSelected;
  final LouvorMaterialAddCallback? onMaterialAdd;
  final LouvorAudioAddCallback? onAudioAdd;

  @override
  ConsumerState<_ColdigomMaterialSheetBody> createState() =>
      _ColdigomMaterialSheetBodyState();
}

class _ColdigomMaterialSheetBodyState
    extends ConsumerState<_ColdigomMaterialSheetBody> {
  String? _addingId;
  late final List<_ColdigomMaterialKind> _kinds;
  int _selectedKindIndex = 0;

  @override
  void initState() {
    super.initState();
    _kinds = _visibleKinds(widget.group);
  }

  static List<_ColdigomMaterialKind> _visibleKinds(LouvorGroup group) {
    return [
      if (group.totalPdfs > 0) _ColdigomMaterialKind.pdf,
      if (group.audioTracks.isNotEmpty) _ColdigomMaterialKind.audio,
      if (group.youtubeMaterials.isNotEmpty) _ColdigomMaterialKind.youtube,
    ];
  }

  Future<void> _handleAddPdf(Louvor louvor) async {
    final onAdd = widget.onMaterialAdd;
    if (onAdd == null || _addingId != null) return;

    setState(() => _addingId = louvor.pdfId);
    try {
      await onAdd(louvor);
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  Future<void> _handleAddAudio(AudioTrack track) async {
    final onAdd = widget.onAudioAdd;
    if (onAdd == null || _addingId != null) return;

    setState(() => _addingId = track.audioId);
    try {
      await onAdd(track);
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  String _kindLabel(AppLocalizations l10n, _ColdigomMaterialKind kind) {
    return switch (kind) {
      _ColdigomMaterialKind.pdf => l10n.pdfMaterialSection,
      _ColdigomMaterialKind.audio => l10n.audioMaterialSection,
      _ColdigomMaterialKind.youtube => l10n.youtubeMaterialSection,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = widget.group;
    final meta = group.coldigomMeta;
    final carouselPdfIds = ref.watch(carouselPdfIdsProvider);
    final showSegments = _kinds.length > 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: group.numero.isNotEmpty
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              group.numero,
                              style: AppTypography.headline.copyWith(
                                color: AppColors.title,
                                fontSize: 22,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                group.nome,
                                style: AppTypography.headline.copyWith(
                                  color: AppColors.title,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          group.nome,
                          style: AppTypography.headline.copyWith(
                            color: AppColors.title,
                          ),
                        ),
                ),
                IconButton(
                  tooltip: l10n.carouselListClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.title),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (meta != null && meta.hasAnyField) ...[
              const SizedBox(height: 16),
              _ColdigomMetaBlock(meta: meta, l10n: l10n),
            ],
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Divider(color: AppColors.gold, height: 1, thickness: 1),
            ),
            if (showSegments) ...[
              const SizedBox(height: 12),
              _KindSegmentBar(
                labels: [for (final kind in _kinds) _kindLabel(l10n, kind)],
                selectedIndex: _selectedKindIndex,
                onSelected: (index) {
                  setState(() => _selectedKindIndex = index);
                },
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _kinds.isEmpty
                  ? const SizedBox.shrink()
                  : showSegments
                  ? IndexedStack(
                      index: _selectedKindIndex,
                      sizing: StackFit.expand,
                      children: [
                        for (final kind in _kinds)
                          _buildKindList(
                            kind: kind,
                            group: group,
                            carouselPdfIds: carouselPdfIds,
                          ),
                      ],
                    )
                  : _buildKindList(
                      kind: _kinds.first,
                      group: group,
                      carouselPdfIds: carouselPdfIds,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindList({
    required _ColdigomMaterialKind kind,
    required LouvorGroup group,
    required Set<String> carouselPdfIds,
  }) {
    final onMaterialAdd = widget.onMaterialAdd;
    final onAudioAdd = widget.onAudioAdd;

    return switch (kind) {
      _ColdigomMaterialKind.pdf => ListView.separated(
        itemCount: group.flatPdfMaterials.length,
        separatorBuilder: (_, _) => const _MaterialHairline(),
        itemBuilder: (context, index) {
          final material = group.flatPdfMaterials[index];
          return _MaterialRow(
            icon: LouvorMaterialIcons.forCategory(material.categoria),
            iconColor: AppColors.title,
            title: material.categoria,
            trailing: onMaterialAdd == null
                ? null
                : _MaterialAddTrailing(
                    isAdded: carouselPdfIds.contains(material.pdfId),
                    isAdding: _addingId == material.pdfId,
                    onAdd: () => _handleAddPdf(material.louvor),
                  ),
            onTap: () {
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onMaterialSelected(material.louvor);
              });
            },
          );
        },
      ),
      _ColdigomMaterialKind.audio => ListView.separated(
        itemCount: group.audioTracks.length,
        separatorBuilder: (_, _) => const _MaterialHairline(),
        itemBuilder: (context, index) {
          final track = group.audioTracks[index];
          return _MaterialRow(
            icon: LouvorMaterialIcons.audio,
            iconColor: AppColors.title,
            title: track.categoria,
            subtitle: track.author.isEmpty ? null : track.author,
            trailing: onAudioAdd == null
                ? null
                : _MaterialAddTrailing(
                    isAdded: false,
                    isAdding: _addingId == track.audioId,
                    onAdd: () => _handleAddAudio(track),
                  ),
            onTap: () {
              unawaited(
                playAudioInSession(
                  ref: ref,
                  track: track,
                  queue: group.audioTracks,
                ),
              );
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onAudioSelected?.call(track);
              });
            },
          );
        },
      ),
      _ColdigomMaterialKind.youtube => ListView.separated(
        itemCount: group.youtubeMaterials.length,
        separatorBuilder: (_, _) => const _MaterialHairline(),
        itemBuilder: (context, index) {
          final item = group.youtubeMaterials[index];
          return _MaterialRow(
            icon: LouvorMaterialIcons.youtube,
            iconColor: AppColors.youtube,
            title: item.categoria,
            onTap: () {
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onYoutubeSelected?.call(item);
              });
            },
          );
        },
      ),
    };
  }
}

class _KindSegmentBar extends StatelessWidget {
  const _KindSegmentBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.title.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _KindSegmentChip(
                  label: labels[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KindSegmentChip extends StatelessWidget {
  const _KindSegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.25)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppColors.gold, width: 1.5)
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected
                  ? AppColors.title
                  : AppColors.title.withValues(alpha: 0.55),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialHairline extends StatelessWidget {
  const _MaterialHairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.title.withValues(alpha: 0.12),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.title.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.label.copyWith(
                          color: AppColors.title.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColdigomMetaBlock extends StatelessWidget {
  const _ColdigomMetaBlock({required this.meta, required this.l10n});

  final ColdigomPraiseMetadata meta;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tonality = meta.tonality.trim();
    final rhythm = meta.rhythm.trim();
    final author = meta.author.trim();
    final category = meta.category.trim();
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
            if (category.isNotEmpty) ...[
              if (hasPair || author.isNotEmpty) const SizedBox(height: 10),
              _metaField(l10n.coldigomMetaCategory, category),
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

class _MaterialAddTrailing extends StatelessWidget {
  const _MaterialAddTrailing({
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
  });

  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (isAdding) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.title,
        ),
      );
    }
    if (isAdded) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.title, width: 1.5),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: Icon(Icons.check, size: 16, color: AppColors.title),
        ),
      );
    }
    return CarouselLouvorAddButton(onPressed: onAdd);
  }
}
