import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_flag_placeholder.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_seek_bar.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_transport_controls.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Face de áudio da playlist: metadados, seeker, controles e flag placeholder.
class PlaylistAudioFacePanel extends ConsumerWidget {
  const PlaylistAudioFacePanel({required this.playlist, super.key});

  final SavedPlaylist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cache = ref.watch(coldigomAudioTracksCacheProvider);
    final tracks = [
      for (final id in playlist.audioIds)
        if (cache[id] != null) cache[id]!,
    ];
    final session = ref.watch(audioPlayerSessionProvider);
    final currentInPlaylist =
        session.currentTrack != null &&
        playlist.audioIds.contains(session.currentTrack!.audioId);
    final active = currentInPlaylist
        ? session.currentTrack
        : (tracks.isEmpty ? null : tracks.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb) ...[
            Text(
              l10n.audioWebBackgroundNotice,
              style: AppTypography.label.copyWith(
                color: AppColors.title.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (tracks.isEmpty)
            Text(
              l10n.playlistAudioEmpty,
              style: AppTypography.body.copyWith(color: AppColors.title),
            )
          else ...[
            Row(
              children: [
                const Icon(LouvorMaterialIcons.audio, color: AppColors.title),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    active == null
                        ? l10n.playlistAudioCount(tracks.length)
                        : '${active.numero.isNotEmpty ? '${active.numero} — ' : ''}${active.nome}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.title,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _playQueue(ref, context, tracks, 0),
                  style: TextButton.styleFrom(foregroundColor: AppColors.title),
                  child: Text(l10n.playlistOpenInAudioPlayer),
                ),
              ],
            ),
            if (active != null && active.categoria.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                active.categoria,
                style: AppTypography.label.copyWith(
                  color: AppColors.title.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 8),
            AudioFlagPlaceholder(
              tooltip: l10n.audioFlagComingSoon,
              onLightBackground: true,
            ),
            AudioSeekBar(
              position: currentInPlaylist ? session.position : Duration.zero,
              duration: currentInPlaylist ? session.duration : Duration.zero,
              onLightBackground: true,
              onSeek: (value) {
                if (!currentInPlaylist) return;
                ref.read(audioPlayerSessionProvider.notifier).seek(value);
              },
            ),
            AudioTransportControls(
              playing: currentInPlaylist && session.playing,
              buffering: currentInPlaylist && session.buffering,
              hasPrevious: true,
              hasNext: tracks.length > 1,
              onLightBackground: true,
              onPrevious: () {
                if (currentInPlaylist) {
                  ref
                      .read(audioPlayerSessionProvider.notifier)
                      .skipToPrevious();
                } else if (tracks.isNotEmpty) {
                  _playQueue(ref, context, tracks, 0);
                }
              },
              onPlayPause: () {
                if (currentInPlaylist) {
                  ref.read(audioPlayerSessionProvider.notifier).playPause();
                } else if (tracks.isNotEmpty) {
                  _playQueue(ref, context, tracks, 0);
                }
              },
              onNext: () {
                if (currentInPlaylist) {
                  ref.read(audioPlayerSessionProvider.notifier).skipToNext();
                } else if (tracks.length > 1) {
                  _playQueue(ref, context, tracks, 1);
                }
              },
              playTooltip: l10n.audioPlay,
              pauseTooltip: l10n.audioPause,
              previousTooltip: l10n.audioPrevious,
              nextTooltip: l10n.audioNext,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < tracks.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  LouvorMaterialIcons.audio,
                  color: AppColors.title.withValues(alpha: 0.85),
                ),
                title: Text(
                  tracks[i].nome,
                  style: AppTypography.body.copyWith(color: AppColors.title),
                ),
                subtitle: Text(
                  tracks[i].categoria,
                  style: AppTypography.label.copyWith(
                    color: AppColors.title.withValues(alpha: 0.7),
                  ),
                ),
                trailing: IconButton(
                  tooltip: l10n.carouselRemoveTooltip,
                  onPressed: () {
                    ref
                        .read(playlistsProvider.notifier)
                        .removeAudio(
                          playlistId: playlist.playlistId,
                          audioId: tracks[i].audioId,
                        );
                  },
                  icon: const Icon(Icons.close, color: AppColors.title),
                ),
                onTap: () => _playQueue(ref, context, tracks, i),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _playQueue(
    WidgetRef ref,
    BuildContext context,
    List<AudioTrack> tracks,
    int index,
  ) async {
    if (tracks.isEmpty) return;
    await openAudioInPlayer(
      ref: ref,
      context: context,
      track: tracks[index],
      queue: tracks,
      startIndex: index,
    );
  }
}
