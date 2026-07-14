import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_flag_placeholder.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_seek_bar.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_transport_controls.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Página de reprodução de áudio Coldigom — metadados + seeker + controles.
class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({this.queryParams = const {}, super.key});

  final Map<String, String> queryParams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(audioPlayerSessionProvider);
    final track = session.currentTrack;
    final title = track?.nome ?? queryParams['titulo'] ?? l10n.audioPlayerTitle;
    final subtitleParts = <String>[
      if ((track?.numero ?? queryParams['subtitulo'] ?? '').isNotEmpty)
        track?.numero ?? queryParams['subtitulo']!,
      if (track != null && track.categoria.isNotEmpty) track.categoria,
      if (track != null && track.author.isNotEmpty) track.author,
    ];

    return ColoredBox(
      color: AppColors.pdfArea,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (kIsWeb) ...[
                _WebBackgroundBanner(message: l10n.audioWebBackgroundNotice),
                const SizedBox(height: 12),
              ],
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
                          color: AppColors.textLight.withValues(alpha: 0.75),
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
              AudioFlagPlaceholder(tooltip: l10n.audioFlagComingSoon),
              const SizedBox(height: 16),
              AudioSeekBar(
                position: session.position,
                duration: session.duration,
                onSeek: (value) {
                  ref.read(audioPlayerSessionProvider.notifier).seek(value);
                },
              ),
              const SizedBox(height: 8),
              AudioTransportControls(
                playing: session.playing,
                buffering: session.buffering,
                hasPrevious:
                    session.hasPrevious || session.position > Duration.zero,
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
                  ref.read(audioPlayerSessionProvider.notifier).skipToNext();
                },
                playTooltip: l10n.audioPlay,
                pauseTooltip: l10n.audioPause,
                previousTooltip: l10n.audioPrevious,
                nextTooltip: l10n.audioNext,
              ),
              if (session.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.audioPlaybackError,
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.offlineMissing,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WebBackgroundBanner extends StatelessWidget {
  const _WebBackgroundBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.btnBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textLight.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textLight.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
