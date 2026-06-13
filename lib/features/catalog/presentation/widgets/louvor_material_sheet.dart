import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Callback de compartilhamento de um material no sheet (UC-04).
typedef LouvorMaterialShareCallback = Future<void> Function(
  Louvor louvor,
  Rect sharePositionOrigin,
);

/// Bottom sheet — escolha de material por classificação → categoria.
///
/// Exibido quando [LouvorGroup.totalMaterials] > 1. Seções ordenadas por
/// [LouvorMaterialSection.displayLabel]; materiais por [LouvorCategoryOrder].
/// Compartilhar ([onMaterialShare]) fica no trailing de cada linha — não no card.
Future<void> showLouvorMaterialSheet({
  required BuildContext context,
  required LouvorGroup group,
  required ValueChanged<Louvor> onMaterialSelected,
  LouvorMaterialShareCallback? onMaterialShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return _LouvorMaterialSheetBody(
        group: group,
        onMaterialSelected: onMaterialSelected,
        onMaterialShare: onMaterialShare,
      );
    },
  );
}

class _LouvorMaterialSheetBody extends StatefulWidget {
  const _LouvorMaterialSheetBody({
    required this.group,
    required this.onMaterialSelected,
    this.onMaterialShare,
  });

  final LouvorGroup group;
  final ValueChanged<Louvor> onMaterialSelected;
  final LouvorMaterialShareCallback? onMaterialShare;

  @override
  State<_LouvorMaterialSheetBody> createState() =>
      _LouvorMaterialSheetBodyState();
}

class _LouvorMaterialSheetBodyState extends State<_LouvorMaterialSheetBody> {
  String? _sharingPdfId;

  Future<void> _handleShare(Louvor louvor, BuildContext buttonContext) async {
    final onShare = widget.onMaterialShare;
    if (onShare == null || _sharingPdfId != null) return;

    setState(() => _sharingPdfId = louvor.pdfId);
    try {
      await onShare(
        louvor,
        sharePositionOriginFromContextOrFallback(buttonContext),
      );
    } finally {
      if (mounted) setState(() => _sharingPdfId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = widget.group;
    final onMaterialShare = widget.onMaterialShare;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    group.numero.isNotEmpty
                        ? '${group.numero} — ${group.nome}'
                        : group.nome,
                    style: AppTypography.headline.copyWith(
                      color: AppColors.title,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.carouselListClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.title),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.gold, height: 1, thickness: 1.5),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final section in group.sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                      child: Text(
                        section.displayLabel,
                        style: AppTypography.label.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final material in section.materials)
                      ListTile(
                        leading: Icon(
                          LouvorMaterialIcons.forCategory(material.categoria),
                          color: AppColors.title,
                        ),
                        title: Text(
                          material.categoria,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: onMaterialShare == null
                            ? null
                            : Builder(
                                builder: (buttonContext) {
                                  final sharing =
                                      _sharingPdfId == material.pdfId;
                                  return IconButton(
                                    tooltip: l10n.sharePdf,
                                    onPressed: sharing
                                        ? null
                                        : () => _handleShare(
                                              material.louvor,
                                              buttonContext,
                                            ),
                                    icon: sharing
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.title,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.share_outlined,
                                            color: AppColors.title,
                                          ),
                                  );
                                },
                              ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onMaterialSelected(material.louvor);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
