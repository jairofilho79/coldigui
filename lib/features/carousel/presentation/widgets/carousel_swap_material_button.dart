import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/presentation/utils/group_with_coldigom_meta.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

LouvorGroup? resolveCarouselSwapMaterialGroup(
  WidgetRef ref, {
  String? pdfId,
  String? audioId,
}) {
  return findSwapMaterialGroup(
    pdfId: pdfId,
    audioId: audioId,
    plpcgCatalog: ref.watch(louvoresManifestProvider).value?.louvores,
    coldigomCache: ref.watch(coldigomLouvoresCacheProvider),
    audioCache: ref.watch(coldigomAudioTracksCacheProvider),
    chordCache: ref.watch(coldigomChordMaterialsCacheProvider),
  );
}

/// Layers na barra de playlist — oculto se o louvor não tem material alternativo.
class CarouselSwapMaterialButton extends ConsumerWidget {
  const CarouselSwapMaterialButton({this.pdfId, this.audioId, super.key});

  final String? pdfId;
  final String? audioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = resolveCarouselSwapMaterialGroup(
      ref,
      pdfId: pdfId,
      audioId: audioId,
    );
    if (group == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      style: carouselBarIconButtonStyle,
      tooltip: l10n.readerSwitchMaterial,
      icon: const Icon(Icons.layers_outlined),
      onPressed: () => showCarouselSwapMaterialSheet(
        context: context,
        ref: ref,
        group: group,
        currentPdfId: pdfId,
      ),
    );
  }
}

Future<void> showCarouselSwapMaterialSheet({
  required BuildContext context,
  required WidgetRef ref,
  required LouvorGroup group,
  String? currentPdfId,
}) async {
  final resolved = await groupWithColdigomMeta(ref, group);
  if (!context.mounted) return;

  await showMaterialSheet(
    context,
    ref,
    resolved,
    // O louvor já está na lista: o `+` de cada material não faz sentido aqui.
    canAddToPlaylist: false,
    // PDF aqui **troca** o material da entrada do carousel em vez de empilhar
    // uma rota nova; áudio toca sem tirar o usuário da partitura (ouvir
    // enquanto lê); o resto segue pelo opener único.
    onMaterialSelected: (material) async {
      switch (material) {
        case PdfMaterial(:final louvor):
          await _onPdfMaterialSelected(
            ref: ref,
            context: context,
            currentPdfId: currentPdfId,
            selected: louvor,
          );
        case AudioMaterial(:final track):
          await playAudioInSession(
            ref: ref,
            track: track,
            queue: resolved.audioTracks,
          );
        case ChordMaterialRef() || GestureMaterialRef() || YoutubeMaterialRef():
          await ref.read(openMaterialProvider).open(context, ref, material);
      }
    },
  );
}

Future<void> _onPdfMaterialSelected({
  required WidgetRef ref,
  required BuildContext context,
  required String? currentPdfId,
  required Louvor selected,
}) async {
  if (!context.mounted) return;
  final path = GoRouterState.of(context).uri.path;
  final onReader = path == RoutePaths.reader || path == RoutePaths.chords;

  if (currentPdfId != null &&
      currentPdfId.isNotEmpty &&
      selected.pdfId != currentPdfId) {
    await ref
        .read(carouselLouvoresProvider.notifier)
        .replacePdfId(currentPdfId, selected.pdfId);
  }

  if (!context.mounted) return;
  if (currentPdfId == null || currentPdfId.isEmpty) {
    await openLouvorInReader(ref: ref, context: context, louvor: selected);
    return;
  }

  if (selected.pdfId == currentPdfId && onReader) return;

  await openCarouselPdfInReader(
    ref: ref,
    context: context,
    pdfId: selected.pdfId,
    navigate: (location) async {
      if (onReader) {
        context.replace(location);
      } else {
        context.push(location);
      }
    },
  );
  if (!context.mounted) return;
  ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(selected.pdfId);
}
