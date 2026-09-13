import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/domain/utils/louvor_material_icons.dart';
import '../providers/material_types_for_kind_provider.dart';
import 'material_kind_card.dart';

/// Ícone do material type (pdf/chord/...) favorito de um material kind, ao
/// lado do nome do kind no card de favoritos.
///
/// Um material kind pode ter mais de um material type (ex.: cifra em PDF ou
/// em chords) — [kindId] decide, sob demanda ([materialTypesForKindProvider]),
/// quais types de fato existem. Só os tipos disponíveis aparecem:
/// - nenhum type: nada é renderizado;
/// - um único type: ícone estático, sem toque;
/// - dois ou mais: ícone tocável do preferido, que abre um menu ordenável
///   (arrastar define o preferido — o do topo) só com os types disponíveis.
///
/// [onChanged] é chamado com o novo type do topo a cada reordenação; quem usa
/// este widget decide como persistir (ver `setPreferredType` do provider de
/// prefs) — mantém o controle testável sem depender de auth/SharedPreferences.
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
    final types = ref.watch(materialTypesForKindProvider(kindId)).value;
    if (types == null || types.isEmpty) return const SizedBox.shrink();

    final effective = (preferredType != null && types.contains(preferredType))
        ? preferredType!
        : types.first;

    if (types.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          _iconFor(effective),
          size: 20,
          color: AppColors.textLight.withValues(alpha: 0.7),
        ),
      );
    }

    return IconButton(
      icon: Icon(_iconFor(effective)),
      tooltip: AppLocalizations.of(context)!
          .favoriteMaterialKindsTypePreferenceTooltip,
      color: AppColors.textLight,
      onPressed: () => _openSheet(context, types, effective),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    List<String> types,
    String effective,
  ) {
    // O preferido vai para o topo; o resto mantém a ordem que o Worker
    // devolveu — não há uma ordem "certa" além dessa para o restante.
    final ordered = [effective, ...types.where((t) => t != effective)];
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TypePreferenceSheetBody(
        kindName: kindName,
        initialOrder: ordered,
        onChanged: onChanged,
      ),
    );
  }

  static IconData _iconFor(String type) =>
      LouvorMaterialIcons.forKind(materialKindOfRawType(type));

  static String labelFor(AppLocalizations l10n, String type) {
    return switch (materialKindOfRawType(type)) {
      MaterialKind.pdf => l10n.pdfMaterialSection,
      MaterialKind.chord => l10n.chordMaterialSection,
      MaterialKind.gesture => l10n.gesturesMaterialSection,
      MaterialKind.audio => l10n.audioMaterialSection,
      MaterialKind.youtube => l10n.youtubeMaterialSection,
      MaterialKind.unknown => type,
    };
  }
}

class _TypePreferenceSheetBody extends StatefulWidget {
  const _TypePreferenceSheetBody({
    required this.kindName,
    required this.initialOrder,
    required this.onChanged,
  });

  final String kindName;
  final List<String> initialOrder;
  final ValueChanged<String> onChanged;

  @override
  State<_TypePreferenceSheetBody> createState() =>
      _TypePreferenceSheetBodyState();
}

class _TypePreferenceSheetBodyState extends State<_TypePreferenceSheetBody> {
  final List<String> _order = [];

  @override
  void initState() {
    super.initState();
    _order.addAll(widget.initialOrder);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      final moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
    });
    widget.onChanged(_order.first);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.favoriteMaterialKindsTypePreferenceTitle(widget.kindName),
              style: AppTypography.headline.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.favoriteMaterialKindsTypePreferenceHelp,
              style: AppTypography.body.copyWith(
                color: AppColors.textLight.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: _handleReorder,
              itemCount: _order.length,
              itemBuilder: (context, index) {
                final type = _order[index];
                return ReorderableDragStartListener(
                  key: ValueKey('type-pref-$type'),
                  index: index,
                  child: MaterialKindCard(
                    leading: Icon(
                      MaterialTypePreferenceControl._iconFor(type),
                      color: AppColors.gold,
                    ),
                    title: MaterialTypePreferenceControl.labelFor(l10n, type),
                    trailing: Icon(
                      Icons.drag_handle,
                      color: AppColors.textLight.withValues(alpha: 0.7),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
