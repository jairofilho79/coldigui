import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../chords/presentation/providers/available_chords_provider.dart';
import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../../coldigom/data/sources/coldigom_catalog_source.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../../material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart';
import '../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../../offline/presentation/providers/material_availability_map_provider.dart';
import '../../../pdf_opening/domain/entities/pdf_offline_availability.dart';
import '../../../playlists/domain/entities/playlist_entry.dart';
import '../../../playlists/domain/exceptions/playlist_not_found_exception.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/entities/material_kind_taxonomy.dart';
import '../../domain/entities/youtube_material.dart';
import '../../domain/usecases/build_material_sheet_sections.dart';
import '../../domain/utils/louvor_material_icons.dart';
import '../providers/catalog_material_lookup_provider.dart';
import '../providers/open_material_provider.dart';
import '../utils/preferred_material_for_group.dart';
import 'material_sheet_actions.dart';

enum _MaterialTab { pdf, extracted, audio, youtube }

_MaterialTab? _tabForKind(MaterialKind? kind) => switch (kind) {
  null || MaterialKind.unknown => null,
  MaterialKind.pdf => _MaterialTab.pdf,
  MaterialKind.chord ||
  MaterialKind.gesture ||
  MaterialKind.lyrics => _MaterialTab.extracted,
  MaterialKind.audio => _MaterialTab.audio,
  MaterialKind.youtube => _MaterialTab.youtube,
};

/// Abre o material escolhido.
typedef PraiseMaterialOpener = Future<void> Function(CatalogMaterial material);

/// Exibição dos materiais do louvor (PDFs, Extraídos, Áudio e YouTube).
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
  _MaterialTab? _selectedTab;

  @override
  void initState() {
    super.initState();
    final initialKind = widget.initialKind;
    _selectedTab = _tabForKind(initialKind);
  }

  void _handleTap(CatalogMaterial material) {
    final open =
        widget.onMaterialSelected ??
        (CatalogMaterial m) => ref
            .read(openMaterialProvider)
            .open(context, ref, m, audioQueue: widget.group.audioTracks);

    unawaited(open(material));
  }

  ActiveEntry? _entryForGroup(
    List<ActiveEntry> entries,
    ColdigomCatalogSource source,
  ) {
    final materialIds = {for (final m in widget.group.materials) m.id};
    return entries
        .where(
          (entry) =>
              materialIds.contains(entry.id) ||
              source.findGroupForMaterial(entry.id)?.groupId ==
                  widget.group.groupId,
        )
        .firstOrNull;
  }

  Future<void> _handleAddOrReplace(CatalogMaterial material) async {
    if (_addingId != null) return;
    setState(() => _addingId = material.id);
    try {
      final entry = _entryForGroup(
        ref.read(activeEntriesProvider),
        ref.read(coldigomCatalogSourceProvider),
      );
      if (entry == null) {
        await addMaterialToActivePlaylist(
          context: context,
          ref: ref,
          material: material,
        );
      } else {
        final replaced = await ref
            .read(activePlaylistEditorProvider.notifier)
            .replaceByKey(
              entry.key,
              PlaylistEntry(id: material.id, kind: material.kind),
            );
        if (!replaced && mounted) {
          showAppSnackbar(
            context,
            AppLocalizations.of(context)!.failureNotFound,
          );
        }
      }
    } on StorageUnavailableException catch (error) {
      AppLogger.of('playlists').warn('sem storage ao trocar material', error);
      if (mounted) {
        showAppSnackbar(
          context,
          AppLocalizations.of(context)!.playlistStorageUnavailable,
        );
      }
    } on PlaylistNotFoundException catch (error) {
      AppLogger.of('playlists').warn('lista ausente ao trocar material', error);
      if (mounted) {
        showAppSnackbar(context, AppLocalizations.of(context)!.failureNotFound);
      }
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
    required bool hasActiveGroupEntry,
    required AppLocalizations l10n,
    IconData? icon,
    String? subtitle,
    bool enabled = true,
    bool shaded = false,
    bool targetAdd = false,
  }) {
    final showAdd =
        widget.canAddToPlaylist && canAddMaterialToPlaylist(material);
    final isAdded = activeMaterialIds.contains(material.id);
    final trailingButton = showAdd
        ? MaterialAddTrailing(
            isAdded: isAdded,
            isAdding: _addingId == material.id,
            removeTooltip: l10n.materialRemoveTooltip,
            onAdd: () => _handleAddOrReplace(material),
            onReplace: hasActiveGroupEntry
                ? () => _handleAddOrReplace(material)
                : null,
            onRemove: () => _handleRemove(material),
          )
        : null;

    final effectiveTrailing = trailingButton == null
        ? null
        : (targetAdd
              ? SpotlightGuideTarget(
                  id: 'material-sheet-add-playlist',
                  child: trailingButton,
                )
              : trailingButton);

    return ListTile(
      enabled: enabled,
      tileColor: shaded ? const Color(0x0A6A2F2F) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(
        icon ?? LouvorMaterialIcons.forMaterial(material),
        color: iconColor,
      ),
      title: PraiseMaterialTitle(
        categoria: material.categoria,
        notes: material.notes,
      ),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: AppTypography.label.copyWith(
                color: AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
      trailing: effectiveTrailing,
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
    final activeEntries = ref.watch(activeEntriesProvider);
    final activeMaterialIds = {for (final entry in activeEntries) entry.id};
    final activeGroupEntry = _entryForGroup(
      activeEntries,
      ref.watch(coldigomCatalogSourceProvider),
    );
    final rank = ref.watch(favoriteMaterialKindRankProvider);
    final preferredTypes = ref.watch(favoriteMaterialTypePreferencesProvider);
    final taxonomy = ref.watch(coldigomKindTaxonomyProvider);
    final online = ref.watch(connectivityStreamProvider).value ?? true;
    final availability = ref.watch(materialAvailabilityMapProvider);

    var tileIndex = 0;
    var hasTargetedAdd = false;
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
      final showAdd =
          widget.canAddToPlaylist && canAddMaterialToPlaylist(material);
      final isFirstAdd = showAdd && !hasTargetedAdd;
      if (isFirstAdd) {
        hasTargetedAdd = true;
      }
      return _materialTile(
        material: material,
        icon: icon,
        iconColor: iconColor,
        activeMaterialIds: activeMaterialIds,
        hasActiveGroupEntry: activeGroupEntry != null,
        l10n: l10n,
        enabled: state.enabled,
        subtitle: state.subtitle ?? subtitle,
        shaded: isShaded,
        targetAdd: isFirstAdd,
      );
    }

    final chordsAsync = group.chordMaterials.isEmpty
        ? const AsyncData<List<ChordMaterial>>(<ChordMaterial>[])
        : ref.watch(availableChordsProvider(group.groupId));
    final availableChords = chordsAsync.value ?? const <ChordMaterial>[];

    final gestureMaterials = group.gestureMaterials;
    final lyrics = group.lyrics;
    final audioTracks = group.audioTracks;
    final youtubeMaterials = group.youtubeMaterials.isNotEmpty
        ? group.youtubeMaterials
        : ref.watch(catalogMaterialLookupProvider).youtube(group.groupId);

    final hasChordItems = availableChords.isNotEmpty || chordsAsync.hasError;
    final hasChordTab = hasChordItems || chordsAsync.isLoading;
    final kinds = <MaterialKind>[
      if (group.totalPdfs > 0) MaterialKind.pdf,
      if (hasChordTab) MaterialKind.chord,
      if (gestureMaterials.isNotEmpty) MaterialKind.gesture,
      if (lyrics != null) MaterialKind.lyrics,
      if (audioTracks.isNotEmpty) MaterialKind.audio,
      if (youtubeMaterials.isNotEmpty) MaterialKind.youtube,
    ];
    final showExtractedSectionHeaders =
        (hasChordTab ? 1 : 0) +
            (gestureMaterials.isNotEmpty ? 1 : 0) +
            (lyrics != null ? 1 : 0) >
        1;

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

    final tabs = <_MaterialTab>[];
    for (final kind in kinds) {
      final tab = _tabForKind(kind);
      if (tab != null && !tabs.contains(tab)) tabs.add(tab);
    }

    List<CatalogMaterial> materialsForTab(_MaterialTab tab) {
      return switch (tab) {
        _MaterialTab.pdf => [
          for (final section in group.sections)
            for (final entry in section.materials) PdfMaterial(entry.louvor),
        ],
        _MaterialTab.extracted => [
          for (final chord in availableChords) ChordMaterialRef(chord),
          for (final gesture in gestureMaterials) GestureMaterialRef(gesture),
          ?lyrics,
        ],
        _MaterialTab.audio => [
          for (final track in audioTracks) AudioMaterial(track),
        ],
        _MaterialTab.youtube => [
          for (final y in youtubeMaterials) YoutubeMaterialRef(y),
        ],
      };
    }

    final showSegments = tabs.length > 1;
    final preferred = bestFavoriteMaterialForGroup(
      group,
      rank,
      preferredTypes: preferredTypes,
      where: (material) => kinds.contains(material.kind),
    );
    final requestedTab =
        _selectedTab ??
        _tabForKind(preferred?.kind) ??
        _tabForKind(kinds.first)!;
    final selectedTab = tabs.contains(requestedTab) ? requestedTab : tabs.first;

    final content = ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      children: switch (selectedTab) {
        _MaterialTab.pdf => _pdfTiles(group, taxonomy, l10n, rank, tileFor),
        _MaterialTab.extracted => [
          if (chordsAsync.isLoading && availableChords.isEmpty)
            ListTile(title: Text(l10n.chordMaterialsLoading)),
          if (hasChordItems) ...[
            if (showExtractedSectionHeaders)
              _sectionLabel(l10n.chordMaterialSection),
            ..._chordTiles(
              group,
              availableChords,
              chordsAsync.hasError,
              taxonomy,
              l10n,
              rank,
              tileFor,
            ),
          ],
          if (gestureMaterials.isNotEmpty) ...[
            if (showExtractedSectionHeaders)
              _sectionLabel(l10n.gesturesMaterialSection),
            ..._gestureTiles(gestureMaterials, taxonomy, l10n, rank, tileFor),
          ],
          if (lyrics != null) ...[
            if (showExtractedSectionHeaders) _sectionLabel(l10n.lyricsTab),
            tileFor(lyrics, iconColor: AppColors.title),
          ],
        ],
        _MaterialTab.audio => _audioTiles(
          audioTracks,
          taxonomy,
          l10n,
          const {},
          tileFor,
        ),
        _MaterialTab.youtube => _youtubeTiles(
          youtubeMaterials,
          taxonomy,
          l10n,
          const {},
          tileFor,
        ),
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
          SpotlightGuideTarget(
            id: 'material-sheet-tabs',
            child: _KindSegmentBar(
              labels: [for (final tab in tabs) _tabLabel(l10n, tab)],
              selectedIndex: tabs.indexOf(selectedTab),
              onSelected: (index) {
                final tappedTab = tabs[index];
                final materials = materialsForTab(tappedTab);
                // Com entrada ativa, a aba unitária precisa expor a troca.
                final showPlaylistActions =
                    widget.canAddToPlaylist &&
                    (activeGroupEntry != null ||
                        tappedTab == _MaterialTab.extracted) &&
                    materials.any(canAddMaterialToPlaylist);
                if (materials.length == 1 && !showPlaylistActions) {
                  _selectedTab = tappedTab;
                  _handleTap(materials.first);
                } else {
                  setState(() => _selectedTab = tappedTab);
                }
              },
            ),
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
            _ClassHeader(label: section.label!, count: section.items.length),
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
            _ClassHeader(label: section.label!, count: section.items.length),
          for (final gesture in section.items)
            tileFor(GestureMaterialRef(gesture), iconColor: AppColors.title),
        ],
      ];
    }

    return [
      for (final gesture in orderByFavoriteKinds(
        gestures,
        rank,
        kindIdOf: (g) => g.materialKindId,
      ))
        tileFor(GestureMaterialRef(gesture), iconColor: AppColors.title),
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
            _ClassHeader(label: section.label!, count: section.items.length),
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
            _ClassHeader(label: section.label!, count: section.items.length),
          for (final item in section.items)
            tileFor(YoutubeMaterialRef(item), iconColor: AppColors.youtube),
        ],
      ];
    }

    return [
      for (final item in orderByFavoriteKinds(
        youtubeMaterials,
        rank,
        kindIdOf: (y) => y.materialKindId,
      ))
        tileFor(YoutubeMaterialRef(item), iconColor: AppColors.youtube),
    ];
  }

  static String _tabLabel(AppLocalizations l10n, _MaterialTab tab) {
    return switch (tab) {
      _MaterialTab.pdf => l10n.pdfMaterialSection,
      _MaterialTab.extracted => l10n.extractedMaterialSection,
      _MaterialTab.audio => l10n.audioMaterialSection,
      _MaterialTab.youtube => l10n.youtubeMaterialSection,
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

/// Título do material com nota opcional (ex: "I", "II", "Cifrado").
///
/// Responsivo:
/// - Em telas maiores (largura >= 600px): posiciona a nota ao lado do nome em linha (Row).
/// - Em telas menores (largura < 600px): posiciona a nota embaixo do nome em coluna (Column).
class PraiseMaterialTitle extends StatelessWidget {
  const PraiseMaterialTitle({
    required this.categoria,
    required this.notes,
    super.key,
  });

  final String categoria;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes != null && notes!.trim().isNotEmpty;
    if (!hasNotes) {
      return Text(
        categoria,
        style: AppTypography.body.copyWith(color: AppColors.textDark),
      );
    }

    final trimmedNotes = notes!.trim();
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        trimmedNotes,
        style: AppTypography.label.copyWith(
          color: AppColors.textDark.withValues(alpha: 0.85),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (isWide) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              categoria,
              style: AppTypography.body.copyWith(color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 8),
          badge,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          categoria,
          style: AppTypography.body.copyWith(color: AppColors.textDark),
        ),
        const SizedBox(height: 3),
        badge,
      ],
    );
  }
}
