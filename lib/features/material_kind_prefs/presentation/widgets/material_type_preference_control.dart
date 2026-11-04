import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/domain/utils/louvor_material_icons.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/entities/material_favorite_policy.dart';
import '../providers/favorite_material_options_provider.dart';
import '../providers/material_types_for_kind_provider.dart';

/// Escolha única, explícita e inline do formato preferido de uma categoria.
class MaterialTypePreferenceControl extends ConsumerWidget {
  const MaterialTypePreferenceControl({
    required this.kindId,
    required this.kindName,
    required this.onChanged,
    super.key,
    this.preferredType,
  });

  final String kindId;
  final String kindName;
  final String? preferredType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final typesAsync = ref.watch(materialTypesForKindProvider(kindId));
    final types = [
      for (final type in typesAsync.value ?? const <String>[])
        if (isFavoriteMaterialType(type)) type,
    ];
    if (typesAsync.isLoading && !typesAsync.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(color: AppColors.gold),
      );
    }
    if (typesAsync.hasError && !typesAsync.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.favoriteMaterialKindsFormatsLoadError, style: _secondary),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.goldLight),
            onPressed: () {
              ref.invalidate(coldigomCatalogHydrationProvider);
              ref.invalidate(favoriteMaterialOptionsProvider);
              ref.invalidate(materialTypesForKindProvider(kindId));
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n.favoriteMaterialKindsRetry),
          ),
        ],
      );
    }
    if (types.isEmpty) {
      return Text(l10n.favoriteMaterialKindsNoFormats, style: _secondary);
    }
    final effective = types.contains(preferredType)
        ? preferredType
        : types.first;
    if (types.length == 1) {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(_iconFor(types.first), size: 18, color: AppColors.textLight),
          Text(labelFor(l10n, types.first), style: _secondary),
          Text(l10n.favoriteMaterialKindsSingleFormat, style: _secondary),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.favoriteMaterialKindsPreferredFormat, style: _secondary),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final type in types)
              ChoiceChip(
                key: ValueKey('type-$kindId-$type'),
                label: Text(labelFor(l10n, type)),
                tooltip: l10n.favoriteMaterialKindsTypePreferenceTitle(
                  kindName,
                ),
                avatar: effective == type
                    ? null
                    : Icon(
                        _iconFor(type),
                        size: 18,
                        color: AppColors.textLight,
                      ),
                selected: effective == type,
                onSelected: (selected) {
                  if (selected && type != effective) onChanged(type);
                },
                showCheckmark: true,
                checkmarkColor: AppColors.title,
                selectedColor: AppColors.card,
                backgroundColor: AppColors.btnBackground,
                labelStyle: AppTypography.label.copyWith(
                  color: effective == type
                      ? AppColors.title
                      : AppColors.textLight,
                  fontWeight: effective == type
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
                side: const BorderSide(color: AppColors.gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
      ],
    );
  }

  static TextStyle get _secondary => AppTypography.label.copyWith(
    color: AppColors.textLight.withValues(alpha: 0.85),
  );

  static IconData _iconFor(String type) =>
      LouvorMaterialIcons.forKind(materialKindOfRawType(type));

  static String labelFor(AppLocalizations l10n, String type) {
    return switch (materialKindOfRawType(type)) {
      MaterialKind.pdf => l10n.favoriteMaterialKindsPdfFormat,
      MaterialKind.chord => l10n.favoriteMaterialKindsChordFormat,
      MaterialKind.gesture => l10n.gesturesMaterialSection,
      MaterialKind.score => l10n.scoreMaterialLabel,
      MaterialKind.audio => l10n.audioMaterialSection,
      MaterialKind.youtube => l10n.youtubeMaterialSection,
      MaterialKind.lyrics => l10n.lyricsTab,
      MaterialKind.unknown => type,
    };
  }
}
