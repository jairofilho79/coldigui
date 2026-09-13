import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_player/presentation/utils/active_list_audio_queue.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

LouvorGroup? resolveCarouselSwapMaterialGroup(
  WidgetRef ref, {
  String? materialId,
  String? audioId,
}) {
  final lookup = ref.watch(catalogMaterialLookupProvider);
  return findSwapMaterialGroup(
    pdfId: materialId,
    audioId: audioId,
    plpcgCatalog: ref.watch(louvoresManifestProvider).value?.louvores,
    coldigomCache: lookup.coldigomLouvoresByPdfId,
    audioCache: lookup.audioTracksById,
    chordCache: lookup.chordsById,
    gestureCache: lookup.gesturesById,
  );
}

/// «Material» na barra de playlist — oculto se o louvor não tem material
/// alternativo.
///
/// [entryKey] é a chave da **ocorrência** cuja entrada será trocada
/// ([ActivePlaylistEditor.replaceByKey]). Quem já tem o item focado na mão (a
/// barra do shell) passa a chave dele; a face de áudio passa só o
/// [materialId] da faixa tocando, e a chave é resolvida na face de partituras.
class CarouselSwapMaterialButton extends ConsumerWidget {
  const CarouselSwapMaterialButton({
    this.materialId,
    this.entryKey,
    this.audioId,
    this.showLabel = true,
    super.key,
  });

  final String? materialId;
  final String? entryKey;
  final String? audioId;

  /// Legenda sob o ícone (barra larga) — repassado a [CarouselBarActionButton].
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = resolveCarouselSwapMaterialGroup(
      ref,
      materialId: materialId,
      audioId: audioId,
    );
    if (group == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return CarouselBarActionButton(
      icon: Icons.change_circle_outlined,
      label: l10n.carouselMaterial,
      tooltip: l10n.readerSwitchMaterial,
      showLabel: showLabel,
      onPressed: () => showCarouselSwapMaterialSheet(
        context: context,
        ref: ref,
        group: group,
        currentMaterialId: materialId,
        currentEntryKey: entryKey,
      ),
    );
  }
}

Future<void> showCarouselSwapMaterialSheet({
  required BuildContext context,
  required WidgetRef ref,
  required LouvorGroup group,
  String? currentMaterialId,
  String? currentEntryKey,
}) async {
  final resolved = ref
      .read(catalogMaterialLookupProvider)
      .withPraiseMeta(group);

  await showMaterialSheet(
    context,
    ref,
    resolved,
    // O louvor já está na lista: o `+` de cada material não faz sentido aqui.
    canAddToPlaylist: false,
    // PDF aqui **troca** a entrada da lista ativa em vez de empilhar uma rota
    // nova; áudio toca sem tirar o usuário da partitura (ouvir enquanto lê); o
    // resto segue pelo opener único.
    onMaterialSelected: (material) async {
      switch (material) {
        case PdfMaterial(:final louvor):
          await _onPdfMaterialSelected(
            ref: ref,
            context: context,
            currentMaterialId: currentMaterialId,
            currentEntryKey: currentEntryKey,
            selected: material,
            selectedLouvor: louvor,
          );
        case AudioMaterial(:final track):
          await playAudioInSession(
            ref: ref,
            track: track,
            queue: queueForTrack(
              track: track,
              groupTracks: resolved.audioTracks,
              activeQueue: activeListAudioQueue(ref),
            ),
          );
        case ChordMaterialRef() || GestureMaterialRef() || YoutubeMaterialRef():
          await ref.read(openMaterialProvider).open(context, ref, material);
      }
    },
  );
}

/// Chave da primeira ocorrência de [materialId] na face de partituras.
String? _keyForMaterialId(WidgetRef ref, String materialId) {
  for (final item in ref.read(carouselItemsProvider)) {
    if (item.materialId == materialId) return item.key;
  }
  return null;
}

Future<void> _onPdfMaterialSelected({
  required WidgetRef ref,
  required BuildContext context,
  required String? currentMaterialId,
  required String? currentEntryKey,
  required CatalogMaterial selected,
  required Louvor selectedLouvor,
}) async {
  if (!context.mounted) return;
  final path = GoRouterState.of(context).uri.path;
  final onReader =
      path == RoutePaths.reader ||
      path == RoutePaths.chords ||
      path == RoutePaths.gestos;

  if (currentMaterialId != null &&
      currentMaterialId.isNotEmpty &&
      selected.id != currentMaterialId) {
    final key = currentEntryKey ?? _keyForMaterialId(ref, currentMaterialId);
    if (key != null) {
      // O `kind` vem do material escolhido (B.4), não da extensão do id.
      await ref
          .read(activePlaylistEditorProvider.notifier)
          .replaceByKey(
            key,
            PlaylistEntry(id: selected.id, kind: selected.kind),
          );
    }
  }

  if (!context.mounted) return;
  if (currentMaterialId == null || currentMaterialId.isEmpty) {
    await openLouvorInReader(
      ref: ref,
      context: context,
      louvor: selectedLouvor,
    );
    return;
  }

  if (selected.id == currentMaterialId && onReader) return;

  await openCarouselPdfInReader(
    ref: ref,
    context: context,
    materialId: selected.id,
    navigate: (location) async {
      if (onReader) {
        context.replace(location);
      } else {
        context.push(location);
      }
    },
  );
  if (!context.mounted) return;
  final focusedKey = _keyForMaterialId(ref, selected.id);
  if (focusedKey != null) {
    ref.read(carouselFocusedIndexProvider.notifier).focusKey(focusedKey);
  }
}
