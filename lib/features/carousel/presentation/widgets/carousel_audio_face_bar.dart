import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_flag_placeholder.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_seek_bar.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_transport_controls.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Face de áudio compacta na barra do shell (sem lista completa de faixas).
class CarouselAudioFaceBar extends ConsumerWidget {
  const CarouselAudioFaceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(audioPlayerSessionProvider);
    final track = _resolveTrack(ref, session.currentTrack);

    return CarouselBarShell(
      applySafeArea: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      LouvorMaterialIcons.audio,
                      color: AppColors.title,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        track == null
                            ? l10n.playlistAudioEmpty
                            : '${track.numero.isNotEmpty ? '${track.numero} — ' : ''}${track.nome}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (track != null) ...[
                  AudioFlagPlaceholder(tooltip: l10n.audioFlagComingSoon),
                  AudioSeekBar(
                    position: session.position,
                    duration: session.duration,
                    onSeek: (value) {
                      ref.read(audioPlayerSessionProvider.notifier).seek(value);
                    },
                  ),
                  AudioTransportControls(
                    playing: session.playing,
                    buffering: session.buffering,
                    hasPrevious: session.hasPrevious,
                    hasNext: session.hasNext,
                    onPrevious: () {
                      ref
                          .read(audioPlayerSessionProvider.notifier)
                          .skipToPrevious();
                    },
                    onPlayPause: () {
                      ref.read(audioPlayerSessionProvider.notifier).playPause();
                    },
                    onNext: () {
                      ref
                          .read(audioPlayerSessionProvider.notifier)
                          .skipToNext();
                    },
                    playTooltip: l10n.audioPlay,
                    pauseTooltip: l10n.audioPause,
                    previousTooltip: l10n.audioPrevious,
                    nextTooltip: l10n.audioNext,
                  ),
                ],
              ],
            ),
          ),
          const CarouselBarTrailingActions(),
        ],
      ),
    );
  }

  AudioTrack? _resolveTrack(WidgetRef ref, AudioTrack? current) {
    if (current != null) return current;

    final activeId = ref.watch(activePlaylistIdProvider);
    if (activeId == null) return null;

    final playlists = ref.watch(playlistsProvider);
    List<String>? audioIds;
    for (final item in playlists) {
      if (item.playlist.playlistId == activeId) {
        audioIds = item.playlist.audioIds;
        break;
      }
    }
    if (audioIds == null || audioIds.isEmpty) return null;

    final cache = ref.watch(coldigomAudioTracksCacheProvider);
    for (final id in audioIds) {
      final track = cache[id];
      if (track != null) return track;
    }
    return null;
  }
}
