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
    this.onLightBackground = false,
    this.compact = false,
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

  /// Fundo creme/card → [AppColors.title]; fundo escuro → [AppColors.textLight].
  final bool onLightBackground;

  /// Controles menores (barra do shell).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = onLightBackground ? AppColors.title : AppColors.textLight;
    final skipSize = compact ? 22.0 : 36.0;
    final playSize = compact ? 28.0 : 40.0;
    final playMin = compact ? const Size(40, 40) : const Size(64, 64);
    final gap = compact ? 4.0 : 12.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: previousTooltip,
          onPressed: hasPrevious ? onPrevious : null,
          iconSize: skipSize,
          visualDensity: compact ? VisualDensity.compact : null,
          constraints: compact
              ? const BoxConstraints(minWidth: 36, minHeight: 36)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          color: fg,
          disabledColor: fg.withValues(alpha: 0.3),
          icon: const Icon(Icons.skip_previous),
        ),
        SizedBox(width: gap),
        Semantics(
          button: true,
          label: playing ? pauseTooltip : playTooltip,
          child: IconButton.filled(
            tooltip: playing ? pauseTooltip : playTooltip,
            onPressed: buffering ? null : onPlayPause,
            iconSize: playSize,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.title,
              disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
              minimumSize: playMin,
              tapTargetSize: compact
                  ? MaterialTapTargetSize.shrinkWrap
                  : MaterialTapTargetSize.padded,
            ),
            icon: buffering
                ? SizedBox(
                    width: compact ? 18 : 28,
                    height: compact ? 18 : 28,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
        ),
        SizedBox(width: gap),
        IconButton(
          tooltip: nextTooltip,
          onPressed: hasNext ? onNext : null,
          iconSize: skipSize,
          visualDensity: compact ? VisualDensity.compact : null,
          constraints: compact
              ? const BoxConstraints(minWidth: 36, minHeight: 36)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          color: fg,
          disabledColor: fg.withValues(alpha: 0.3),
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }
}
