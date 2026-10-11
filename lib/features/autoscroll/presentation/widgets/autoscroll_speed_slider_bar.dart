import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/autoscroll_speed_config.dart';

/// Barra expansível com o slider de velocidade magnético do autoscroll.
///
/// Características principais:
/// - Valores discretos magnéticos de 1 a 15 ([AutoscrollSpeedConfig.divisions] divisões).
/// - Por padrão fica no meio (8).
/// - À esquerda: ícone e rótulo "Lento".
/// - À direita: ícone e rótulo "Rápido".
/// - Não exibe multiplicadores numéricos textuais ("1x", "2x") conforme especificação.
class AutoscrollSpeedSliderBar extends StatelessWidget {
  const AutoscrollSpeedSliderBar({
    required this.speed,
    required this.onSpeedChanged,
    this.onClose,
    this.backgroundColor,
    this.foregroundColor,
    this.activeColor,
    this.inactiveColor,
    this.dividerColor,
    super.key,
  });

  /// Velocidade atual (1 a 15).
  final int speed;

  /// Callback acionado quando o usuário seleciona um novo valor discreto.
  final ValueChanged<int> onSpeedChanged;

  /// Callback opcional de fechamento manual da barra.
  final VoidCallback? onClose;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = foregroundColor ?? AppColors.textDark;
    final bg = backgroundColor ?? AppColors.card;
    final active = activeColor ?? AppColors.gold;
    final inactive = inactiveColor ?? fg.withValues(alpha: 0.25);
    final divider = dividerColor ?? AppColors.gold.withValues(alpha: 0.3);

    final clampedSpeed = AutoscrollSpeedConfig.clamp(speed).toDouble();

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(color: divider, width: 1),
          ),
        ),
        child: Row(
        children: [
          Icon(Icons.slow_motion_video, size: 18, color: fg),
          const SizedBox(width: 4),
          Text(
            l10n.autoscrollSlow,
            style: AppTypography.label.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: active,
                inactiveTrackColor: inactive,
                thumbColor: active,
                overlayColor: active.withValues(alpha: 0.15),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
              ),
              child: Slider(
                value: clampedSpeed,
                min: AutoscrollSpeedConfig.min.toDouble(),
                max: AutoscrollSpeedConfig.max.toDouble(),
                divisions: AutoscrollSpeedConfig.divisions,
                onChanged: (value) => onSpeedChanged(value.round()),
              ),
            ),
          ),
          Text(
            l10n.autoscrollFast,
            style: AppTypography.label.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.fast_forward, size: 18, color: fg),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: fg,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l10n.autoscrollClose,
              onPressed: onClose,
            ),
          ],
        ],
      ),
    ),
  );
}
}
