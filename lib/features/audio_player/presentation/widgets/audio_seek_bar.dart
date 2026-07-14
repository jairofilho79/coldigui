import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Seeker + tempos decorrido/restante da sessão de áudio.
class AudioSeekBar extends StatelessWidget {
  const AudioSeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final max = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final value = position.inMilliseconds
        .clamp(0, totalMs > 0 ? totalMs : 1)
        .toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.gold,
            inactiveTrackColor: AppColors.textLight.withValues(alpha: 0.25),
            thumbColor: AppColors.goldLight,
            overlayColor: AppColors.gold.withValues(alpha: 0.2),
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(position),
                style: AppTypography.label.copyWith(
                  color: AppColors.textLight.withValues(alpha: 0.8),
                ),
              ),
              Text(
                _format(duration),
                style: AppTypography.label.copyWith(
                  color: AppColors.textLight.withValues(alpha: 0.8),
                ),
              ),
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
