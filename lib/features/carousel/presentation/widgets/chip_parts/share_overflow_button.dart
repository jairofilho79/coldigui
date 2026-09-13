import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:flutter/material.dart';

enum _LouvorChipMenuAction { share }

/// Menu overflow (⋮) do chip com a opção **Compartilhar** (UC-04).
///
/// Extraído de `carousel_louvor_chip.dart` (E4) — sem mudança de
/// comportamento.
class ShareOverflowButton extends StatelessWidget {
  const ShareOverflowButton({
    required this.onShare,
    required this.shareLabel,
    this.loading = false,
    super.key,
  });

  final void Function(Rect sharePositionOrigin) onShare;
  final String shareLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LouvorChipMenuAction>(
      padding: EdgeInsets.zero,
      iconSize: 20,
      splashRadius: 18,
      tooltip: shareLabel,
      icon: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.gold,
              ),
            )
          : Icon(
              Icons.more_vert,
              size: 20,
              color: AppColors.textLight.withValues(alpha: 0.9),
            ),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      onSelected: (_) {
        onShare(sharePositionOriginFromContextOrFallback(context));
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _LouvorChipMenuAction.share,
          enabled: !loading,
          child: Text(shareLabel),
        ),
      ],
    );
  }
}
