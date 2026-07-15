import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Seeker + tempos decorrido/restante da sessão de áudio.
class AudioSeekBar extends StatelessWidget {
  const AudioSeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onLightBackground = false,
    this.compact = false,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  /// Fundo creme/card → [AppColors.title]; fundo escuro → [AppColors.textLight].
  final bool onLightBackground;

  /// Slider e labels mais baixos (barra do shell).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final max = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final value = position.inMilliseconds
        .clamp(0, totalMs > 0 ? totalMs : 1)
        .toDouble();
    final muted = onLightBackground
        ? AppColors.title.withValues(alpha: 0.7)
        : AppColors.textLight.withValues(alpha: 0.8);
    final inactiveTrack = onLightBackground
        ? AppColors.title.withValues(alpha: 0.2)
        : AppColors.textLight.withValues(alpha: 0.25);

    final timeStyle = AppTypography.label.copyWith(
      color: muted,
      fontSize: compact ? 11 : null,
    );

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: inactiveTrack,
        thumbColor: AppColors.goldLight,
        overlayColor: AppColors.gold.withValues(alpha: 0.2),
        trackHeight: compact ? 2 : 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 5 : 10),
        overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 8 : 16),
        padding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Semantics(
        slider: true,
        value: _format(position),
        child: Slider(
          min: 0,
          max: max,
          value: value,
          onChanged: totalMs <= 0
              ? null
              : (v) => onSeek(Duration(milliseconds: v.round())),
        ),
      ),
    );

    // Compacto: tempos nas laterais; slider com altura limitada (= linha do chip PDF).
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_format(position), style: timeStyle),
          Expanded(child: SizedBox(height: 20, child: slider)),
          Text(_format(duration), style: timeStyle),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(position), style: timeStyle),
              Text(_format(duration), style: timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  static String _format(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
