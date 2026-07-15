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
    // Compacto: skip = IconButton padrão (como Salvar); play capped — filled+padding
    // com minimumSize 48 estoura a barra além da PDF.
    final skipSize = compact ? 24.0 : 36.0;
    final playSize = compact ? 22.0 : 40.0;
    final playBox = compact ? const Size(36, 36) : const Size(64, 64);

    final previous = IconButton(
      tooltip: previousTooltip,
      onPressed: hasPrevious ? onPrevious : null,
      iconSize: skipSize,
      style: IconButton.styleFrom(
        foregroundColor: fg,
        disabledForegroundColor: fg.withValues(alpha: 0.3),
      ),
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
          minimumSize: playBox,
          maximumSize: compact ? playBox : null,
          fixedSize: compact ? playBox : null,
          padding: compact ? EdgeInsets.zero : null,
          tapTargetSize: compact
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
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
      style: IconButton.styleFrom(
        foregroundColor: fg,
        disabledForegroundColor: fg.withValues(alpha: 0.3),
      ),
      icon: const Icon(Icons.skip_next),
    );

    // Compacto: IconButtons colados como Salvar/Compartilhar (sem SizedBox).
    // Tela cheia: gap explícito entre botões maiores.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        previous,
        if (!compact) const SizedBox(width: 12),
        playPause,
        if (!compact) const SizedBox(width: 12),
        next,
      ],
    );
  }
}
