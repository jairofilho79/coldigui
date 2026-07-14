import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Placeholder visual para audio flags (fora do escopo desta entrega).
class AudioFlagPlaceholder extends StatelessWidget {
  const AudioFlagPlaceholder({
    required this.tooltip,
    this.onLightBackground = false,
    this.compact = false,
    super.key,
  });

  final String tooltip;

  /// Fundo creme/card → [AppColors.title]; fundo escuro → [AppColors.textLight].
  final bool onLightBackground;

  /// Só o marcador na linha (sem IconButton inferior).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = onLightBackground
        ? AppColors.title.withValues(alpha: 0.35)
        : AppColors.textLight.withValues(alpha: 0.35);
    final track = onLightBackground
        ? AppColors.title.withValues(alpha: 0.2)
        : AppColors.textLight.withValues(alpha: 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: compact ? 14 : 18,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(height: 2, color: track),
              ),
              // ponytail: só ícone desabilitado até feature de flags existir
              Align(
                alignment: const Alignment(0.2, 0),
                child: Tooltip(
                  message: tooltip,
                  child: Icon(
                    Icons.flag_outlined,
                    size: compact ? 12 : 16,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          IconButton(
            tooltip: tooltip,
            onPressed: null,
            icon: Icon(Icons.flag, color: muted),
          ),
        ],
      ],
    );
  }
}
