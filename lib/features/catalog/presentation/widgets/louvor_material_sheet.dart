import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:flutter/material.dart';

/// Bottom sheet — escolha de material por classificação → categoria.
///
/// Exibido quando [LouvorGroup.totalMaterials] > 1. Seções ordenadas por
/// [LouvorMaterialSection.displayLabel]; materiais por [LouvorCategoryOrder].
Future<void> showLouvorMaterialSheet({
  required BuildContext context,
  required LouvorGroup group,
  required ValueChanged<Louvor> onMaterialSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
              Text(
                group.numero.isNotEmpty
                    ? '${group.numero} — ${group.nome}'
                    : group.nome,
                style: AppTypography.headline.copyWith(color: AppColors.title),
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
                          onTap: () {
                            Navigator.of(context).pop();
                            onMaterialSelected(material.louvor);
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
    },
  );
}
