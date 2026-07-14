import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Placeholder visual para audio flags (fora do escopo desta entrega).
class AudioFlagPlaceholder extends StatelessWidget {
  const AudioFlagPlaceholder({required this.tooltip, super.key});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 2,
                  color: AppColors.textLight.withValues(alpha: 0.2),
                ),
              ),
              // ponytail: só ícone desabilitado até feature de flags existir
              Align(
                alignment: const Alignment(0.2, 0),
                child: Tooltip(
                  message: tooltip,
                  child: Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: AppColors.textLight.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        IconButton(
          tooltip: tooltip,
          onPressed: null,
          icon: Icon(
            Icons.flag,
            color: AppColors.textLight.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}
