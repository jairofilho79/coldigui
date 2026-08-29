import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Ícone no canto superior direito do player. Toque revela o aviso de Web.
///
/// Filho direto de [Stack]. Não vai na playlist: o caveat é do ambiente do
/// player, não da lista da reunião.
class AudioWebPlatformHint extends StatefulWidget {
  const AudioWebPlatformHint({required this.message, super.key});

  final String message;

  @override
  State<AudioWebPlatformHint> createState() => _AudioWebPlatformHintState();
}

class _AudioWebPlatformHintState extends State<AudioWebPlatformHint> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final button = IconButton(
      tooltip: l10n.audioWebPlatformHintTooltip,
      isSelected: _expanded,
      onPressed: () => setState(() => _expanded = !_expanded),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textLight,
        minimumSize: const Size(48, 48),
      ),
      icon: const Icon(Icons.info_outline),
      selectedIcon: const Icon(Icons.info),
    );

    return Positioned.directional(
      textDirection: Directionality.of(context),
      top: 0,
      end: 0,
      start: _expanded ? 0 : null,
      child: _expanded
          ? Semantics(
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.btnBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            widget.message,
                            style: AppTypography.label.copyWith(
                              color: AppColors.textLight.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      button,
                    ],
                  ),
                ),
              ),
            )
          : button,
    );
  }
}
