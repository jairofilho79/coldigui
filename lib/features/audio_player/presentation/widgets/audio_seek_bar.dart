import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_flags/domain/entities/saved_audio_flag.dart';
import 'package:coldigui/features/audio_flags/presentation/utils/audio_flag_time_format.dart';
import 'package:flutter/material.dart';

/// Seeker + tempos decorrido/restante da sessão de áudio.
class AudioSeekBar extends StatelessWidget {
  const AudioSeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.flags = const [],
    this.onFlagTap,
    this.onLightBackground = false,
    this.compact = false,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final List<SavedAudioFlag> flags;
  final ValueChanged<SavedAudioFlag>? onFlagTap;

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
    final flagColor = onLightBackground
        ? AppColors.title.withValues(alpha: 0.85)
        : AppColors.goldLight;

    final timeStyle = AppTypography.label.copyWith(
      color: muted,
      fontSize: compact ? 10 : null,
      height: compact ? 1.0 : null,
    );

    // Compact: ~14px no vão abaixo do track (barra 60px); full: um pouco maior.
    final flagSize = compact ? 14.0 : 16.0;
    const flagVerticalMargin = 2.0;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: inactiveTrack,
        thumbColor: AppColors.goldLight,
        overlayColor: AppColors.gold.withValues(alpha: 0.2),
        trackHeight: compact ? 2 : 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 4 : 10),
        overlayShape: compact
            ? SliderComponentShape.noOverlay
            : const RoundSliderOverlayShape(overlayRadius: 16),
        padding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Semantics(
        slider: true,
        value: formatAudioFlagTime(position),
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

    final flagRow = _FlagMarkersRow(
      totalMs: totalMs,
      flags: flags,
      onFlagTap: onFlagTap,
      flagColor: flagColor,
      flagSize: flagSize,
      verticalMargin: flagVerticalMargin,
      horizontalInset: compact ? 0 : 8,
    );

    if (compact) {
      const gap = 8.0;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(formatAudioFlagTime(position), style: timeStyle),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 14, child: slider),
                flagRow,
              ],
            ),
          ),
          const SizedBox(width: gap),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(formatAudioFlagTime(duration), style: timeStyle),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slider,
        flagRow,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatAudioFlagTime(position), style: timeStyle),
              Text(formatAudioFlagTime(duration), style: timeStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// Marcadores alinhados à track, na faixa abaixo do slider.
class _FlagMarkersRow extends StatelessWidget {
  const _FlagMarkersRow({
    required this.totalMs,
    required this.flags,
    required this.onFlagTap,
    required this.flagColor,
    required this.flagSize,
    required this.verticalMargin,
    required this.horizontalInset,
  });

  final int totalMs;
  final List<SavedAudioFlag> flags;
  final ValueChanged<SavedAudioFlag>? onFlagTap;
  final Color flagColor;
  final double flagSize;
  final double verticalMargin;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty || totalMs <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: flagSize + verticalMargin * 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = (constraints.maxWidth - horizontalInset * 2).clamp(
            0.0,
            double.infinity,
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final flag in flags)
                Positioned(
                  left:
                      horizontalInset +
                      (flag.positionMs.clamp(0, totalMs) / totalMs) *
                          trackWidth -
                      flagSize / 2,
                  top: verticalMargin,
                  child: Tooltip(
                    message: audioFlagTooltipLabel(flag.label, flag.position),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onFlagTap == null ? null : () => onFlagTap!(flag),
                      child: SizedBox(
                        width: flagSize,
                        height: flagSize,
                        child: Icon(
                          Icons.flag,
                          size: flagSize,
                          color: flagColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
