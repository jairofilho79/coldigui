import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../chords/presentation/providers/available_chords_provider.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../../material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart';
import '../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../../offline/presentation/providers/material_availability_map_provider.dart';
import '../../../pdf_opening/domain/entities/pdf_offline_availability.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/entities/material_kind_taxonomy.dart';
import '../../domain/entities/youtube_material.dart';
import '../../domain/usecases/build_material_sheet_sections.dart';
import '../../domain/utils/louvor_material_icons.dart';
import '../providers/catalog_material_lookup_provider.dart';
import '../providers/open_material_provider.dart';
import 'material_sheet_actions.dart';

/// Abre o material escolhido.
typedef PraiseMaterialOpener = Future<void> Function(CatalogMaterial material);

/// Exibição dos materiais do louvor (PDFs, Cifras, Gestos, Áudios, YouTube e Letra).
///
/// Compartilhado entre o `MaterialSheet` e a `PraiseScreen`.
class PraiseMaterialsView extends ConsumerStatefulWidget {
  const PraiseMaterialsView({
    required this.group,
    this.canAddToPlaylist = true,
    this.onMaterialSelected,
    this.initialKind,
    this.currentMaterialId,
    this.shrinkWrap = false,
    this.physics,
    super.key,
  });

  final LouvorGroup group;
  final bool canAddToPlaylist;
  final PraiseMaterialOpener? onMaterialSelected;
  final MaterialKind? initialKind;
  final String? currentMaterialId;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  ConsumerState<PraiseMaterialsView> createState() =>
      _PraiseMaterialsViewState();
}

class _PraiseMaterialsViewState extends ConsumerState<PraiseMaterialsView> {
  String? _addingId;
  MaterialKind? _selectedKind;

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialKind;
  }

  void _handleTap(CatalogMaterial material) {
    final open = widget.onMaterialSelected ??
        (CatalogMaterial m) => ref
            .read(openMaterialProvider)
            .open(context, ref, m, audioQueue: widget.group.audioTracks);

    unawaited(open(material));
  }

  Future<void> _handleAdd(CatalogMaterial material) async {
    if (_addingId != null) return;
    setState(() => _addingId = material.id);
    try {
      await addMaterialToActivePlaylist(
        context: context,
        ref: ref,
        material: material,
      );
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  Future<void> _handleRemove(CatalogMaterial material) async {
    if (_addingId != null) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.materialRemoveConfirmTitle,
      message: l10n.materialRemoveConfirmMessage(material.categoria),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _addingId = material.id);
    try {
      await ref
          .read(activePlaylistEditorProvider.notifier)
          .removeById(material.id);
      if (mounted) showAppSnackbar(context, l10n.materialRemoved);
    } on StorageUnavailableException {
      if (mounted) showAppSnackbar(context, l10n.playlistStorageUnavailable);
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.title,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _materialTile({
    required CatalogMaterial material,
    required Color iconColor,
    required Set<String> activeMaterialIds,
    required AppLocalizations l10n,
    IconData? icon,
    String? subtitle,
    bool enabled = true,
    bool shaded = false,
  }) {
    final showAdd =
        widget.canAddToPlaylist && canAddMaterialToPlaylist(material);
    final isAdded = activeMaterialIds.contains(material.id);
    return ListTile(
      enabled: enabled,
      tileColor: shaded ? const Color(0x0A6A2F2F) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      leading: Icon(
        icon ?? LouvorMaterialIcons.forMaterial(material),
        color: iconColor,
      ),
      title: Text(
        material.categoria,
        style: AppTypography.body.copyWith(color: AppColors.textDark),
      ),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: AppTypography.label.copyWith(
                color: AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
      trailing: showAdd
          ? MaterialAddTrailing(
              isAdded: isAdded,
              isAdding: _addingId == material.id,
              removeTooltip: l10n.materialRemoveTooltip,
              onAdd: () => _handleAdd(material),
              onRemove: () => _handleRemove(material),
            )
          : null,
      onTap: () => _handleTap(material),
    );
  }

  ({bool enabled, String? subtitle}) _availabilityFor(
    CatalogMaterial material, {
    required bool online,
    required Map<String, PdfOfflineAvailability> availability,
    required AppLocalizations l10n,
  }) {
    if (online) return (enabled: true, subtitle: null);
    return switch (material) {
      LyricsMaterial() => (enabled: true, subtitle: null),
      YoutubeMaterialRef() => (
        enabled: false,
        subtitle: l10n.materialNeedsConnection,
      ),
      PdfMaterial() ||
      ChordMaterialRef() ||
      GestureMaterialRef() ||
      AudioMaterial() =>
        availability.containsKey(material.id)
            ? (enabled: true, subtitle: null)
            : (enabled: false, subtitle: l10n.materialNotDownloadedOffline),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final group = widget.group;
    final activeMaterialIds = ref.watch(activeMaterialIdsProvider);
    final rank = ref.watch(favoriteMaterialKindRankProvider);
    final taxonomy = ref.watch(coldigomKindTaxonomyProvider);
    final online = ref.watch(connectivityStreamProvider).value ?? true;
    final availability = ref.watch(materialAvailabilityMapProvider);

    var tileIndex = 0;
    Widget tileFor(
      CatalogMaterial material, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    }) {
      final state = _availabilityFor(
        material,
        online: online,
        availability: availability,
        l10n: l10n,
      );
      final isShaded = (tileIndex++).isOdd;
      return _materialTile(
        material: material,
        icon: icon,
        iconColor: iconColor,
        activeMaterialIds: activeMaterialIds,
        l10n: l10n,
        enabled: state.enabled,
        subtitle: state.subtitle ?? subtitle,
        shaded: isShaded,
      );
    }

    final chordsAsync = group.chordMaterials.isEmpty
        ? const AsyncData<List<ChordMaterial>>(<ChordMaterial>[])
        : ref.watch(availableChordsProvider(group.groupId));
    final availableChords = chordsAsync.value ?? const <ChordMaterial>[];

    final gestureMaterials = group.gestureMaterials;
    final audioTracks = group.audioTracks;
    final youtubeMaterials = group.youtubeMaterials.isNotEmpty
        ? group.youtubeMaterials
        : ref.watch(catalogMaterialLookupProvider).youtube(group.groupId);

    final kinds = <MaterialKind>[
      if (group.totalPdfs > 0) MaterialKind.pdf,
      if (availableChords.isNotEmpty || chordsAsync.hasError)
        MaterialKind.chord,
      if (gestureMaterials.isNotEmpty) MaterialKind.gesture,
      if (audioTracks.isNotEmpty) MaterialKind.audio,
      if (youtubeMaterials.isNotEmpty) MaterialKind.youtube,
    ];

    if (kinds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            l10n.praiseNotFound,
            style: AppTypography.body.copyWith(
              color: AppColors.textDark.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    List<CatalogMaterial> materialsForKind(MaterialKind kind) {
      return switch (kind) {
        MaterialKind.pdf => [
          for (final section in group.sections)
            for (final entry in section.materials)
              PdfMaterial(entry.louvor),
        ],
        MaterialKind.chord => [
          for (final chord in availableChords)
            ChordMaterialRef(chord),
        ],
        MaterialKind.gesture => [
          for (final gesture in gestureMaterials)
            GestureMaterialRef(gesture),
        ],
        MaterialKind.audio => [
          for (final track in audioTracks)
            AudioMaterial(track),
        ],
        MaterialKind.youtube => [
          for (final y in youtubeMaterials)
            YoutubeMaterialRef(y),
        ],
        MaterialKind.lyrics || MaterialKind.unknown => const <CatalogMaterial>[],
      };
    }

    final showSegments = kinds.length > 1;
    final selectedIndex = kinds.indexOf(_selectedKind ?? kinds.first);
    final selectedKind = kinds[selectedIndex < 0 ? 0 : selectedIndex];

    final content = ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      children: switch (selectedKind) {
        MaterialKind.pdf => _pdfTiles(
          group,
          taxonomy,
          l10n,
          rank,
          tileFor,
        ),
        MaterialKind.chord => _chordTiles(
          group,
          availableChords,
          chordsAsync.hasError,
          taxonomy,
          l10n,
          rank,
          tileFor,
        ),
        MaterialKind.gesture => _gestureTiles(
          gestureMaterials,
          taxonomy,
          l10n,
          rank,
          tileFor,
        ),
        MaterialKind.audio => _audioTiles(
          audioTracks,
          taxonomy,
          l10n,
          rank,
          tileFor,
        ),
        MaterialKind.youtube => _youtubeTiles(
          youtubeMaterials,
          taxonomy,
          l10n,
          rank,
          tileFor,
        ),
        MaterialKind.lyrics || MaterialKind.unknown => const <Widget>[],
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!online) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: AppColors.title.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.materialSheetOfflineBanner,
                    style: AppTypography.label.copyWith(
                      color: AppColors.title.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showSegments) ...[
          _KindSegmentBar(
            labels: [for (final kind in kinds) _kindLabel(l10n, kind)],
            selectedIndex: kinds.indexOf(selectedKind),
            onSelected: (index) {
              final tappedKind = kinds[index];
              final materials = materialsForKind(tappedKind);
              if (materials.length == 1) {
                _selectedKind = tappedKind;
                _handleTap(materials.first);
              } else {
                setState(() => _selectedKind = tappedKind);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        if (widget.shrinkWrap) content else Expanded(child: content),
      ],
    );
  }

  List<Widget> _pdfTiles(
    LouvorGroup group,
    MaterialKindTaxonomy taxonomy,
    AppLocalizations l10n,
    Map<String, int> rank,
    Widget Function(
      CatalogMaterial, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    })
    tileFor,
  ) {
    final allEntries = [
      for (final section in group.sections) ...section.materials,
    ];
    final taxonomySections = buildMaterialSheetSections<LouvorMaterialEntry>(
      items: allEntries,
      kindIdOf: (e) => e.louvor.materialKindId,
      taxonomy: taxonomy,
      rank: rank,
      otherLabel: l10n.materialKindOtherClass,
      labelOf: (e) => e.categoria,
    );

    if (taxonomySections.isNotEmpty) {
      final showHeaders = taxonomySections.length > 1;
      return [
        for (final section in taxonomySections) ...[
          if (showHeaders && section.label != null)
            _ClassHeader(
              label: section.label!,
              count: section.items.length,
            ),
          for (final entry in section.items)
            tileFor(
              PdfMaterial(entry.louvor),
              icon: LouvorMaterialIcons.forEntry(entry),
              iconColor: AppColors.title,
            ),
        ],
      ];
    }

    final showSectionLabels = group.sections.length > 1;
    return [
      for (final section in group.sections) ...[
        if (showSectionLabels)
          _sectionLabel(
            section.displayLabel.trim().isEmpty
                ? l10n.pdfMaterialSection
                : section.displayLabel,
          ),
        for (final entry in orderByFavoriteKinds(
          section.materials,
          rank,
          kindIdOf: (e) => e.louvor.materialKindId,
        ))
          tileFor(
            PdfMaterial(entry.louvor),
            icon: LouvorMaterialIcons.forEntry(entry),
            iconColor: AppColors.title,
          ),
      ],
    ];
  }

  List<Widget> _chordTiles(
    LouvorGroup group,
    List<ChordMaterial> availableChords,
    bool hasError,
    MaterialKindTaxonomy taxonomy,
    AppLocalizations l10n,
    Map<String, int> rank,
    Widget Function(
      CatalogMaterial, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    })
    tileFor,
  ) {
    final taxonomySections = buildMaterialSheetSections<ChordMaterial>(
      items: availableChords,
      kindIdOf: (c) => c.materialKindId,
      taxonomy: taxonomy,
      rank: rank,
      otherLabel: l10n.materialKindOtherClass,
      labelOf: (c) => c.categoria,
    );

    final showHeaders = taxonomySections.length > 1;
    final tiles = taxonomySections.isNotEmpty
        ? [
            for (final section in taxonomySections) ...[
              if (showHeaders && section.label != null)
                _ClassHeader(
                  label: section.label!,
                  count: section.items.length,
                ),
              for (final chord in section.items)
                tileFor(ChordMaterialRef(chord), iconColor: AppColors.title),
            ],
          ]
        : [
            for (final chord in orderByFavoriteKinds(
              availableChords,
              rank,
              kindIdOf: (c) => c.materialKindId,
            ))
              tileFor(ChordMaterialRef(chord), iconColor: AppColors.title),
          ];

    return [
      ...tiles,
      if (hasError)
        ListTile(
          leading: const Icon(Icons.refresh, color: AppColors.title),
          title: Text(
            l10n.chordUnavailableRetry,
            style: AppTypography.body.copyWith(color: AppColors.textDark),
          ),
          onTap: () => ref.invalidate(availableChordsProvider(group.groupId)),
        ),
    ];
  }

  List<Widget> _gestureTiles(
    List<GestureMaterial> gestures,
    MaterialKindTaxonomy taxonomy,
    AppLocalizations l10n,
    Map<String, int> rank,
    Widget Function(
      CatalogMaterial, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    })
    tileFor,
  ) {
    final taxonomySections = buildMaterialSheetSections<GestureMaterial>(
      items: gestures,
      kindIdOf: (g) => g.materialKindId,
      taxonomy: taxonomy,
      rank: rank,
      otherLabel: l10n.materialKindOtherClass,
      labelOf: (g) => g.categoria,
    );

    final showHeaders = taxonomySections.length > 1;
    if (taxonomySections.isNotEmpty) {
      return [
        for (final section in taxonomySections) ...[
          if (showHeaders && section.label != null)
            _ClassHeader(
              label: section.label!,
              count: section.items.length,
            ),
          for (final gesture in section.items)
            tileFor(
              GestureMaterialRef(gesture),
              iconColor: AppColors.title,
            ),
        ],
      ];
    }

    return [
      for (final gesture in orderByFavoriteKinds(
        gestures,
        rank,
        kindIdOf: (g) => g.materialKindId,
      ))
        tileFor(
          GestureMaterialRef(gesture),
          iconColor: AppColors.title,
        ),
    ];
  }

  List<Widget> _audioTiles(
    List<AudioTrack> audioTracks,
    MaterialKindTaxonomy taxonomy,
    AppLocalizations l10n,
    Map<String, int> rank,
    Widget Function(
      CatalogMaterial, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    })
    tileFor,
  ) {
    final taxonomySections = buildMaterialSheetSections<AudioTrack>(
      items: audioTracks,
      kindIdOf: (t) => t.materialKindId,
      taxonomy: taxonomy,
      rank: rank,
      otherLabel: l10n.materialKindOtherClass,
      labelOf: (t) => t.categoria,
    );

    final showHeaders = taxonomySections.length > 1;
    if (taxonomySections.isNotEmpty) {
      return [
        for (final section in taxonomySections) ...[
          if (showHeaders && section.label != null)
            _ClassHeader(
              label: section.label!,
              count: section.items.length,
            ),
          for (final track in section.items)
            tileFor(
              AudioMaterial(track),
              iconColor: AppColors.title,
              subtitle: track.author,
            ),
        ],
      ];
    }

    return [
      for (final track in orderByFavoriteKinds(
        audioTracks,
        rank,
        kindIdOf: (t) => t.materialKindId,
      ))
        tileFor(
          AudioMaterial(track),
          iconColor: AppColors.title,
          subtitle: track.author,
        ),
    ];
  }

  List<Widget> _youtubeTiles(
    List<YoutubeMaterial> youtubeMaterials,
    MaterialKindTaxonomy taxonomy,
    AppLocalizations l10n,
    Map<String, int> rank,
    Widget Function(
      CatalogMaterial, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    })
    tileFor,
  ) {
    final taxonomySections = buildMaterialSheetSections<YoutubeMaterial>(
      items: youtubeMaterials,
      kindIdOf: (y) => y.materialKindId,
      taxonomy: taxonomy,
      rank: rank,
      otherLabel: l10n.materialKindOtherClass,
      labelOf: (y) => y.categoria,
    );

    final showHeaders = taxonomySections.length > 1;
    if (taxonomySections.isNotEmpty) {
      return [
        for (final section in taxonomySections) ...[
          if (showHeaders && section.label != null)
            _ClassHeader(
              label: section.label!,
              count: section.items.length,
            ),
          for (final item in section.items)
            tileFor(
              YoutubeMaterialRef(item),
              iconColor: AppColors.youtube,
            ),
        ],
      ];
    }

    return [
      for (final item in orderByFavoriteKinds(
        youtubeMaterials,
        rank,
        kindIdOf: (y) => y.materialKindId,
      ))
        tileFor(
          YoutubeMaterialRef(item),
          iconColor: AppColors.youtube,
        ),
    ];
  }

  static String _kindLabel(AppLocalizations l10n, MaterialKind kind) {
    return switch (kind) {
      MaterialKind.pdf => l10n.pdfMaterialSection,
      MaterialKind.chord => l10n.chordMaterialSection,
      MaterialKind.gesture => l10n.gesturesMaterialSection,
      MaterialKind.audio => l10n.audioMaterialSection,
      MaterialKind.youtube => l10n.youtubeMaterialSection,
      MaterialKind.lyrics => l10n.lyricsTab,
      MaterialKind.unknown => throw StateError('kind sem aba: $kind'),
    };
  }
}

class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label.copyWith(
      fontSize: 11.5,
      letterSpacing: 1,
      color: AppColors.title.withValues(alpha: 0.7),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          const SizedBox(width: 6),
          Text('$count', style: style.copyWith(fontWeight: FontWeight.w400)),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.title.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
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
