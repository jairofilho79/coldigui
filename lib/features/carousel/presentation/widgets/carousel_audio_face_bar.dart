import 'dart:async';

import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/domain/utils/find_material_for_group.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_position_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/audio_flags/domain/entities/saved_audio_flag.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flag_sync_provider.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flags_for_track_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_seek_bar.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_transport_controls.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/utils/play_group_audio.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_selection_sheet.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Face de áudio compacta na barra do shell (sem lista completa de faixas).
class CarouselAudioFaceBar extends ConsumerWidget {
  const CarouselAudioFaceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(audioFlagSyncProvider);
    // Campos individuais (não a sessão inteira): esta barra é montada em toda
    // rota do shell e não pode reconstruir a cada troca de posição — que
    // agora mora num provider separado (A7).
    final currentTrack = ref.watch(
      audioPlayerSessionProvider.select((s) => s.currentTrack),
    );
    final errorMessage = ref.watch(
      audioPlayerSessionProvider.select((s) => s.errorMessage),
    );
    final playing = ref.watch(
      audioPlayerSessionProvider.select((s) => s.playing),
    );
    final buffering = ref.watch(
      audioPlayerSessionProvider.select((s) => s.buffering),
    );
    final hasPrevious = ref.watch(
      audioPlayerSessionProvider.select((s) => s.hasPrevious),
    );
    final hasNext = ref.watch(
      audioPlayerSessionProvider.select((s) => s.hasNext),
    );
    final positionState = ref.watch(audioPlayerPositionProvider);
    final audioItems = ref.watch(audioFaceItemsProvider);
    final track = _resolveTrack(ref, currentTrack, audioItems);
    final flags = track == null
        ? const <SavedAudioFlag>[]
        : (ref.watch(audioFlagsForTrackProvider(track.audioId)).asData?.value ??
              const []);
    final pdfItems = ref.watch(carouselItemsProvider);
    final focusedItem = ref.watch(focusedCarouselItemProvider);

    // Ponte D1: o material do louvor **tocando**, não o chip focado — o
    // carousel pode estar em outro louvor enquanto a faixa toca.
    final trackMaterialId = resolveMaterialForGroup(ref, track?.groupId);
    final followingAudio = ref.watch(audioFollowReaderProvider);

    // Setas de louvor (D5 — spec A.1 emendada, fix round 1): a posição atual
    // é a faixa **tocando** (a sessão), nunca o foco da face PDF — chaves de
    // áudio nunca existem em `carouselItemsProvider`, então
    // `CarouselFocusedIndexNotifier.focusKey` seria sempre um no-op ali.
    // Sem faixa tocando, ou tocando algo fora desta face, cai no índice 0.
    final playingIndex = currentTrack == null
        ? -1
        : audioItems.indexWhere(
            (item) => item.materialId == currentTrack.audioId,
          );
    final currentAudioIndex = playingIndex < 0 ? 0 : playingIndex;
    final canGoPreviousLouvor = currentAudioIndex > 0;
    final canGoNextLouvor = currentAudioIndex < audioItems.length - 1;

    // Sem flags: sobe o bloco para o seek alinhar aos IconButtons.
    // Com flags: sem translate — o eixo do seek já fica no centro.
    return CarouselBarShell(
      applySafeArea: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            style: carouselBarIconButtonStyle,
            tooltip: l10n.audioFacePreviousLouvor,
            icon: const Icon(Icons.chevron_left),
            onPressed: canGoPreviousLouvor
                ? () => unawaited(
                    _playAudioFaceItem(ref, audioItems[currentAudioIndex - 1]),
                  )
                : null,
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset(0, flags.isEmpty ? -6 : 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LouvorMaterialIcons.audio,
                        color: AppColors.title,
                        size: 14,
                      ),
                      const SizedBox(width: carouselBarHorizontalGap),
                      Expanded(
                        child: Text(
                          track == null
                              ? l10n.playlistAudioEmpty
                              : _trackTitle(track),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: AppColors.title,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Erro ocupa a linha do seek: em 360 px não cabe uma
                  // terceira linha e o seek não serve para nada parado.
                  // Sem faixa não há o que retentar — `retryCurrent` é no-op
                  // com a fila vazia, então nem mostra o botão.
                  if (errorMessage != null && track != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.audioPlaybackError,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              color: AppColors.offlineMissing,
                              fontSize: 10,
                              height: 1.0,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => ref
                              .read(audioPlayerSessionProvider.notifier)
                              .retryCurrent(),
                          icon: const Icon(Icons.refresh, size: 13),
                          label: Text(l10n.retry),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.title,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            textStyle: AppTypography.label.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (track != null)
                    AudioSeekBar(
                      position: positionState.position,
                      duration: positionState.duration,
                      onLightBackground: true,
                      compact: true,
                      flags: flags,
                      onFlagTap: (flag) {
                        ref
                            .read(audioPlayerSessionProvider.notifier)
                            .seek(flag.position);
                      },
                      onSeek: (value) {
                        ref
                            .read(audioPlayerSessionProvider.notifier)
                            .seek(value);
                      },
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            style: carouselBarIconButtonStyle,
            tooltip: l10n.audioFaceNextLouvor,
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoNextLouvor
                ? () => unawaited(
                    _playAudioFaceItem(ref, audioItems[currentAudioIndex + 1]),
                  )
                : null,
          ),
          if (track != null)
            AudioTransportControls(
              playing: playing,
              buffering: buffering,
              hasPrevious: hasPrevious,
              hasNext: hasNext,
              onLightBackground: true,
              compact: true,
              onPrevious: () {
                ref.read(audioPlayerSessionProvider.notifier).skipToPrevious();
              },
              onPlayPause: () {
                ref.read(audioPlayerSessionProvider.notifier).playPause();
              },
              onNext: () {
                ref.read(audioPlayerSessionProvider.notifier).skipToNext();
              },
              playTooltip: l10n.audioPlay,
              pauseTooltip: l10n.audioPause,
              previousTooltip: l10n.audioPrevious,
              nextTooltip: l10n.audioNext,
            ),
          if (track != null)
            IconButton(
              style: carouselBarIconButtonStyle,
              tooltip: l10n.audioOpenPlayer,
              icon: const Icon(Icons.open_in_full),
              onPressed: () => pushAudioPlayerRoute(context, track),
            ),
          if (track != null && trackMaterialId != null)
            IconButton(
              style: carouselBarIconButtonStyle,
              tooltip: l10n.audioOpenSheetMusic,
              icon: const Icon(Icons.menu_book),
              onPressed: () => openMaterialForGroupInReader(
                ref: ref,
                context: context,
                groupId: track.groupId,
              ),
            ),
          // Preferência global: aparece sempre, mesmo quando a faixa tocando
          // não tem material para abrir no leitor.
          IconButton(
            style: carouselBarIconButtonStyle,
            tooltip: l10n.audioFollowReader,
            icon: Icon(followingAudio ? Icons.link : Icons.link_off),
            onPressed: () => toggleAudioFollowReader(ref),
          ),
          if (pdfItems.isNotEmpty)
            IconButton(
              style: carouselBarIconButtonStyle,
              tooltip: l10n.carouselOpenList,
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => showCarouselSelectionSheet(
                context,
                onItemTap: (item) => openCarouselPdfInReader(
                  ref: ref,
                  context: context,
                  materialId: item.materialId,
                  navigate: (location) async {
                    context.push(location);
                  },
                ),
              ),
            ),
          // Layers segue a faixa tocando: `materialId` do próprio grupo (troca
          // o material no lugar) e, sem material, só o `audioId` — nunca o chip
          // focado, que pode ser outro louvor. Sem faixa nenhuma o botão cai no
          // item focado da face de partituras, cuja chave é conhecida.
          CarouselSwapMaterialButton(
            materialId: track == null
                ? focusedItem?.materialId
                : trackMaterialId,
            entryKey: track == null ? focusedItem?.key : null,
            audioId: track?.audioId,
          ),
          const CarouselBarTrailingActions(),
        ],
      ),
    );
  }

  /// Mesmo rótulo do sheet (`track.categoria` = material kind Coldigom).
  static String _trackTitle(AudioTrack track) {
    final head =
        '${track.numero.isNotEmpty ? '${track.numero} — ' : ''}${track.nome}';
    if (track.categoria.isEmpty) return head;
    return '$head | ${track.categoria}';
  }

  /// Faixa corrente: a da sessão ou, sem sessão, a **primeira entrada de
  /// áudio** da lista ativa resolvida no cache (B.2 — sem varrer
  /// `playlistsProvider`).
  AudioTrack? _resolveTrack(
    WidgetRef ref,
    AudioTrack? current,
    List<CarouselItem> audioItems,
  ) {
    if (current != null) return current;
    if (audioItems.isEmpty) return null;

    final lookup = ref.watch(catalogMaterialLookupProvider);
    for (final item in audioItems) {
      final found = lookup.audioTrack(item.materialId);
      if (found != null) return found;
    }
    return null;
  }

  /// Toca a faixa preferida do grupo de [item] (D5 — setas de louvor da
  /// face de áudio). Não mexe no foco da face PDF: uma chave de áudio nunca
  /// existe em `carouselItemsProvider`, e `focusKey` seria sempre um no-op
  /// ali (spec A.1 emendada, fix round 1).
  Future<void> _playAudioFaceItem(WidgetRef ref, CarouselItem item) async {
    final lookup = ref.read(catalogMaterialLookupProvider);
    final track = lookup.audioTrack(item.materialId);
    if (track == null) return;

    final groupTracks = tracksForGroup(
      track.groupId,
      lookup.audioTracksById.values.toList(),
    );
    await playGroupAudio(ref, groupTracks);
  }
}
