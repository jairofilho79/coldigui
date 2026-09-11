import 'package:coldigui/core/platform/platform_capabilities_provider.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flag_sync_provider.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flags_for_track_provider.dart';
import 'package:coldigui/features/audio_flags/presentation/widgets/add_audio_flag_dialog.dart';
import 'package:coldigui/features/audio_flags/presentation/widgets/audio_flag_list.dart';
import 'package:coldigui/features/audio_flags/presentation/widgets/audio_flag_sync_error_row.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_position_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/data/web_audio_environment.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_seek_bar.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_transport_controls.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_web_platform_hint.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Página de reprodução de áudio Coldigom — metadados + seeker + controles.
class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({this.queryParams = const {}, super.key});

  final Map<String, String> queryParams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(audioFlagSyncProvider);
    final session = ref.watch(audioPlayerSessionProvider);
    // A posição mora num provider à parte (A7): a sessão não muda mais de
    // identidade a cada tick do `positionStream`.
    final positionState = ref.watch(audioPlayerPositionProvider);
    final track = session.currentTrack;
    final audioId = track?.audioId ?? '';
    final flagsAsync = ref.watch(audioFlagsForTrackProvider(audioId));
    final flags = flagsAsync.asData?.value ?? const [];
    final title = track != null && track.categoria.isNotEmpty
        ? track.categoria
        : (track?.nome ?? queryParams['titulo'] ?? l10n.audioPlayerTitle);
    final subtitleParts = <String>[
      if ((track?.numero ?? queryParams['subtitulo'] ?? '').isNotEmpty)
        track?.numero ?? queryParams['subtitulo']!,
      if (track != null && track.nome.isNotEmpty && track.nome != title)
        track.nome,
      if (track != null && track.author.isNotEmpty) track.author,
    ];
    final canAddFlag = track != null && !session.playing;
    // Ponte D1: partitura/cifra do louvor da faixa e toggle "seguir o áudio".
    final materialPdfId = resolveMaterialForGroup(ref, track?.groupId);
    final followingAudio = ref.watch(audioFollowReaderProvider);

    return ColoredBox(
      color: AppColors.pdfArea,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LouvorMaterialIcons.audio,
                          size: 96,
                          color: AppColors.textLight.withValues(alpha: 0.85),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTypography.headline.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitleParts.join(' · '),
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textLight.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                        ],
                        if (track?.classificacao.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            track!.classificacao,
                            textAlign: TextAlign.center,
                            style: AppTypography.label.copyWith(
                              color: AppColors.goldLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (track != null && materialPdfId != null)
                        IconButton(
                          tooltip: l10n.audioOpenSheetMusic,
                          onPressed: () => openMaterialForGroupInReader(
                            ref: ref,
                            context: context,
                            groupId: track.groupId,
                          ),
                          icon: const Icon(
                            Icons.menu_book,
                            color: AppColors.textLight,
                          ),
                        ),
                      IconButton(
                        tooltip: canAddFlag
                            ? l10n.audioFlagAdd
                            : l10n.audioFlagPauseToAdd,
                        onPressed: !canAddFlag
                            ? null
                            : () => _addFlag(
                                context,
                                ref,
                                audioId,
                                positionState.position,
                              ),
                        icon: Icon(
                          Icons.flag,
                          color: canAddFlag
                              ? AppColors.textLight
                              : AppColors.textLight.withValues(alpha: 0.35),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.audioFollowReader,
                        onPressed: () => toggleAudioFollowReader(ref),
                        icon: Icon(
                          followingAudio ? Icons.link : Icons.link_off,
                          color: followingAudio
                              ? AppColors.goldLight
                              : AppColors.textLight.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AudioSeekBar(
                    position: positionState.position,
                    duration: positionState.duration,
                    flags: flags,
                    onFlagTap: (flag) {
                      ref
                          .read(audioPlayerSessionProvider.notifier)
                          .seek(flag.position);
                    },
                    onSeek: (value) {
                      ref.read(audioPlayerSessionProvider.notifier).seek(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  AudioTransportControls(
                    playing: session.playing,
                    buffering: session.buffering,
                    hasPrevious:
                        session.hasPrevious ||
                        positionState.position > Duration.zero,
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
                  const AudioFlagSyncErrorRow(),
                  if (track != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.audioFlagListTitle,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textLight.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: AudioFlagList(
                          flags: flags,
                          onSeek: (flag) {
                            ref
                                .read(audioPlayerSessionProvider.notifier)
                                .seek(flag.position);
                          },
                          onDelete: (flag) {
                            ref
                                .read(audioFlagActionsProvider)
                                .remove(audioId: audioId, flagId: flag.flagId);
                          },
                        ),
                      ),
                    ),
                  ],
                  if (session.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.audioPlaybackError,
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(
                        color: AppColors.offlineMissing,
                      ),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => ref
                            .read(audioPlayerSessionProvider.notifier)
                            .retryCurrent(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.retry),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.goldLight,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (ref.watch(platformCapabilitiesProvider).isWeb)
                AudioWebPlatformHint(
                  message: isIosWebStandalonePwa
                      ? l10n.audioWebIosPwaNotice
                      : l10n.audioWebBackgroundNotice,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFlag(
    BuildContext context,
    WidgetRef ref,
    String audioId,
    Duration position,
  ) async {
    final label = await showAddAudioFlagDialog(context);
    if (label == null || !context.mounted) return;
    await ref
        .read(audioFlagActionsProvider)
        .add(
          audioId: audioId,
          positionMs: position.inMilliseconds,
          label: label,
        );
  }
}
