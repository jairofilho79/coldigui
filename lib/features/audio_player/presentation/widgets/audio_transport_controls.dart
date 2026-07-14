import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Controles anterior / play-pause / próximo.
class AudioTransportControls extends StatelessWidget {
  const AudioTransportControls({
    required this.playing,
    required this.buffering,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.playTooltip,
    required this.pauseTooltip,
    required this.previousTooltip,
    required this.nextTooltip,
    super.key,
  });

  final bool playing;
  final bool buffering;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final String playTooltip;
  final String pauseTooltip;
  final String previousTooltip;
  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: previousTooltip,
          onPressed: hasPrevious ? onPrevious : null,
          iconSize: 36,
          color: AppColors.textLight,
          disabledColor: AppColors.textLight.withValues(alpha: 0.3),
          icon: const Icon(Icons.skip_previous),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: playing ? pauseTooltip : playTooltip,
          child: IconButton.filled(
            tooltip: playing ? pauseTooltip : playTooltip,
            onPressed: buffering ? null : onPlayPause,
            iconSize: 40,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.title,
              disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
              minimumSize: const Size(64, 64),
            ),
            icon: buffering
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: nextTooltip,
          onPressed: hasNext ? onNext : null,
          iconSize: 36,
          color: AppColors.textLight,
          disabledColor: AppColors.textLight.withValues(alpha: 0.3),
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }
}
