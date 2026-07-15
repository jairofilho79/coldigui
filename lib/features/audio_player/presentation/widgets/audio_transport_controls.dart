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
    final playSize = compact ? 26.0 : 40.0;
    final playMin = compact ? const Size(36, 36) : const Size(64, 64);
    final skipConstraints = compact
        ? const BoxConstraints(minWidth: 32, minHeight: 32)
        : null;

    final previous = IconButton(
      tooltip: previousTooltip,
      onPressed: hasPrevious ? onPrevious : null,
      iconSize: skipSize,
      visualDensity: compact ? VisualDensity.compact : null,
      constraints: skipConstraints,
      padding: compact ? EdgeInsets.zero : null,
      color: fg,
      disabledColor: fg.withValues(alpha: 0.3),
      icon: const Icon(Icons.skip_previous),
    );
    final playPause = Semantics(
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
          padding: compact ? EdgeInsets.zero : null,
        ),
        icon: buffering
            ? SizedBox(
                width: compact ? 16 : 28,
                height: compact ? 16 : 28,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(playing ? Icons.pause : Icons.play_arrow),
      ),
    );
    final next = IconButton(
      tooltip: nextTooltip,
      onPressed: hasNext ? onNext : null,
      iconSize: skipSize,
      visualDensity: compact ? VisualDensity.compact : null,
      constraints: skipConstraints,
      padding: compact ? EdgeInsets.zero : null,
      color: fg,
      disabledColor: fg.withValues(alpha: 0.3),
      icon: const Icon(Icons.skip_next),
    );

    // Compacto: ocupa 95% da largura (margens 2.5% cada lado).
    if (compact) {
      return FractionallySizedBox(
        widthFactor: 0.95,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [previous, playPause, next],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        previous,
        const SizedBox(width: 12),
        playPause,
        const SizedBox(width: 12),
        next,
      ],
    );
  }
}
