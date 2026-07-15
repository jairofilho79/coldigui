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

  /// Marcador sobre o seek (sem trilha própria nem IconButton).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = onLightBackground
        ? AppColors.title.withValues(alpha: 0.35)
        : AppColors.textLight.withValues(alpha: 0.35);
    final track = onLightBackground
        ? AppColors.title.withValues(alpha: 0.2)
        : AppColors.textLight.withValues(alpha: 0.2);

    // Compacto: só a bandeira (empilha no seek via Stack; sem 2ª trilha).
    if (compact) {
      return SizedBox(
        height: 12,
        child: Align(
          alignment: const Alignment(0.2, 0),
          child: Tooltip(
            message: tooltip,
            child: Icon(Icons.flag_outlined, size: 10, color: muted),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(height: 2, color: track),
              ),
              Align(
                alignment: const Alignment(0.2, 0),
                child: Tooltip(
                  message: tooltip,
                  child: Icon(Icons.flag_outlined, size: 16, color: muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        IconButton(
          tooltip: tooltip,
          onPressed: null,
          icon: Icon(Icons.flag, color: muted),
        ),
      ],
    );
  }
}
