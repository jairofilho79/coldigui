import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart';
import '../entities/material_kind_taxonomy.dart';

/// Seção de materiais agrupados por classe no sheet de materiais.
class MaterialSheetClassSection<T> {
  const MaterialSheetClassSection({
    required this.classId,
    required this.label,
    required this.items,
  });

  /// `null` = «Outros» (kind sem classe ou fora das classes conhecidas).
  final String? classId;

  /// Rótulo da seção (ex.: "Metais", "Regência e geral", "Outros").
  final String? label;

  /// Materiais pertencentes a esta classe, com favoritos na frente.
  final List<T> items;
}

/// Agrupa [items] por classe da taxonomia ([MaterialKindTaxonomy]) para o sheet
/// de materiais.
///
/// - Devolve vazio (`[]`) quando `taxonomy.classes.isEmpty`, quando `items.isEmpty`,
///   ou quando nenhum item tem classe conhecida na taxonomia (o chamador mantém
///   o fallback para seções legadas ou lista corrida).
/// - Classes na ordem de `taxonomy.classes`, com «Outros» por último.
/// - Dentro de cada classe: ordem de grade taxonômica (`order`), desempate por
///   rótulo (`labelOf`), e favoritos sobem na frente na ordem de [rank]
///   (via `orderByFavoriteKinds`).
List<MaterialSheetClassSection<T>> buildMaterialSheetSections<T>({
  required List<T> items,
  required String? Function(T item) kindIdOf,
  required MaterialKindTaxonomy taxonomy,
  Map<String, int> rank = const {},
  String? otherLabel,
  String Function(T item)? labelOf,
}) {
  if (items.isEmpty || taxonomy.classes.isEmpty) return const [];

  final knownClasses = {for (final c in taxonomy.classes) c.id: c.label};

  // Mapeia cada item para sua classe taxonômica
  final byClass = <String?, List<T>>{};
  var hasAnyKnownClass = false;

  for (final item in items) {
    final kindId = kindIdOf(item);
    String? classId;
    if (kindId != null) {
      final taxon = taxonomy.kinds[kindId];
      final parentId = taxonomy.parentOf(kindId);
      classId = taxon?.classId ??
          (parentId != null ? taxonomy.kinds[parentId]?.classId : null);
    }
    if (classId != null && knownClasses.containsKey(classId)) {
      hasAnyKnownClass = true;
      byClass.putIfAbsent(classId, () => []).add(item);
    } else {
      byClass.putIfAbsent(null, () => []).add(item);
    }
  }

  // Se nenhum item do louvor tem classe conhecida, devolve vazio para que o
  // chamador faça fallback para as seções originais (ex.: acervo antigo).
  if (!hasAnyKnownClass) return const [];

  int compareItems(T a, T b) {
    final kindA = kindIdOf(a);
    final kindB = kindIdOf(b);
    final taxonA = kindA != null ? taxonomy.kinds[kindA] : null;
    final taxonB = kindB != null ? taxonomy.kinds[kindB] : null;
    final parentA = kindA != null ? taxonomy.parentOf(kindA) : null;
    final parentB = kindB != null ? taxonomy.parentOf(kindB) : null;

    final orderA = taxonA?.order ??
        (parentA != null ? taxonomy.kinds[parentA]?.order : null) ??
        (1 << 30);
    final orderB = taxonB?.order ??
        (parentB != null ? taxonomy.kinds[parentB]?.order : null) ??
        (1 << 30);

    final byOrder = orderA.compareTo(orderB);
    if (byOrder != 0) return byOrder;

    if (labelOf != null) {
      final nameA = labelOf(a);
      final nameB = labelOf(b);
      final byNormalized = LouvorSearchTokens.normalize(nameA)
          .compareTo(LouvorSearchTokens.normalize(nameB));
      if (byNormalized != 0) return byNormalized;
      return nameA.compareTo(nameB);
    }
    return 0;
  }

  final sections = <MaterialSheetClassSection<T>>[];

  for (final c in taxonomy.classes) {
    final classItems = byClass[c.id];
    if (classItems != null && classItems.isNotEmpty) {
      classItems.sort(compareItems);
      final ordered = orderByFavoriteKinds(
        classItems,
        rank,
        kindIdOf: kindIdOf,
      );
      sections.add(
        MaterialSheetClassSection(
          classId: c.id,
          label: c.label,
          items: ordered,
        ),
      );
    }
  }

  final otherItems = byClass[null];
  if (otherItems != null && otherItems.isNotEmpty) {
    otherItems.sort(compareItems);
    final ordered = orderByFavoriteKinds(
      otherItems,
      rank,
      kindIdOf: kindIdOf,
    );
    sections.add(
      MaterialSheetClassSection(
        classId: null,
        label: otherLabel ?? 'Outros',
        items: ordered,
      ),
    );
  }

  return sections;
}
