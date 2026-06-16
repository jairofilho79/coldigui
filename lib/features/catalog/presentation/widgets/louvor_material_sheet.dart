import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callback de adição de um material ao carousel no sheet.
typedef LouvorMaterialAddCallback = Future<void> Function(Louvor louvor);

/// Bottom sheet — escolha de material por classificação → categoria.
///
/// Exibido quando [LouvorGroup.totalMaterials] > 1. Seções ordenadas por
/// [LouvorMaterialSection.displayLabel]; materiais por [LouvorCategoryOrder].
/// Adicionar ([onMaterialAdd]) fica no trailing de cada linha — não no card.
Future<void> showLouvorMaterialSheet({
  required BuildContext context,
  required LouvorGroup group,
  required ValueChanged<Louvor> onMaterialSelected,
  LouvorMaterialAddCallback? onMaterialAdd,
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
        onMaterialAdd: onMaterialAdd,
      );
    },
  );
}

class _LouvorMaterialSheetBody extends ConsumerStatefulWidget {
  const _LouvorMaterialSheetBody({
    required this.group,
    required this.onMaterialSelected,
    this.onMaterialAdd,
  });

  final LouvorGroup group;
  final ValueChanged<Louvor> onMaterialSelected;
  final LouvorMaterialAddCallback? onMaterialAdd;

  @override
  ConsumerState<_LouvorMaterialSheetBody> createState() =>
      _LouvorMaterialSheetBodyState();
}

class _LouvorMaterialSheetBodyState
    extends ConsumerState<_LouvorMaterialSheetBody> {
  String? _addingPdfId;

  Future<void> _handleAdd(Louvor louvor) async {
    final onAdd = widget.onMaterialAdd;
    if (onAdd == null || _addingPdfId != null) return;

    setState(() => _addingPdfId = louvor.pdfId);
    try {
      await onAdd(louvor);
    } finally {
      if (mounted) setState(() => _addingPdfId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = widget.group;
    final onMaterialAdd = widget.onMaterialAdd;
    final carouselPdfIds = ref.watch(carouselPdfIdsProvider);

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
                        trailing: onMaterialAdd == null
                            ? null
                            : _MaterialAddTrailing(
                                isAdded:
                                    carouselPdfIds.contains(material.pdfId),
                                isAdding: _addingPdfId == material.pdfId,
                                onAdd: () => _handleAdd(material.louvor),
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

class _MaterialAddTrailing extends StatelessWidget {
  const _MaterialAddTrailing({
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
  });

  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (isAdding) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.title,
        ),
      );
    }
    if (isAdded) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.title, width: 1.5),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            Icons.check,
            size: 16,
            color: AppColors.title,
          ),
        ),
      );
    }
    return CarouselLouvorAddButton(onPressed: onAdd);
  }
}
