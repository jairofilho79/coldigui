import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:flutter/material.dart';

/// Ordem de exibição — PDF · cifra · gestos · áudio · YouTube · letra (B.2),
/// mesma ordem das abas do sheet de materiais.
const _kindOrder = [
  MaterialKind.pdf,
  MaterialKind.chord,
  MaterialKind.gesture,
  MaterialKind.audio,
  MaterialKind.youtube,
  MaterialKind.lyrics,
];

/// Linha de ícones por tipo de material presente no [group] (C5).
///
/// Substitui o resumo textual (`louvorGroupMetadataSummary`) na variante de
/// card da Home/Biblioteca: um ícone por [MaterialKind] presente, na ordem de
/// [_kindOrder], com contagem quando há mais de um material do mesmo tipo.
/// Toque num ícone chama [onTap] com o [MaterialKind] tocado — quem usa este
/// widget decide o que fazer (ex.: abrir o [MaterialSheet] do grupo).
class MaterialKindsRow extends StatelessWidget {
  const MaterialKindsRow({required this.group, this.onTap, super.key});

  final LouvorGroup group;
  final void Function(MaterialKind kind)? onTap;

  /// Conta materiais por tipo: PDFs de seção classificados pela `categoria`
  /// (heurística de [LouvorMaterialIcons.kindForCategory] — o manifest só dá
  /// texto livre) e [LouvorGroup.extras] pelo `kind` confiável de cada um.
  Map<MaterialKind, int> _counts() {
    final counts = <MaterialKind, int>{};
    for (final section in group.sections) {
      for (final entry in section.materials) {
        final kind = LouvorMaterialIcons.kindForCategory(entry.categoria);
        counts[kind] = (counts[kind] ?? 0) + 1;
      }
    }
    for (final material in group.extras) {
      counts[material.kind] = (counts[material.kind] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts();
    final kinds = [
      for (final kind in _kindOrder)
        if ((counts[kind] ?? 0) > 0) kind,
    ];
    if (kinds.isEmpty) return const SizedBox.shrink();

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < kinds.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _MaterialKindIcon(
              kind: kinds[i],
              count: counts[kinds[i]]!,
              onTap: onTap == null ? null : () => onTap!(kinds[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialKindIcon extends StatelessWidget {
  const _MaterialKindIcon({
    required this.kind,
    required this.count,
    this.onTap,
  });

  final MaterialKind kind;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.textLight.withValues(alpha: 0.9);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LouvorMaterialIcons.forKind(kind), size: 14, color: iconColor),
        if (count > 1) ...[
          const SizedBox(width: 2),
          Text(
            '$count',
            style: AppTypography.body.copyWith(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(2), child: content),
    );
  }
}
