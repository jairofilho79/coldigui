/// Filtros do catálogo — um conjunto só para a página inicial e a
/// /biblioteca (spec fim-fonte §2.2, C5).
///
/// OU dentro de cada conjunto, E entre conjuntos; conjunto vazio não
/// restringe (`matchesCatalogFilters`). [tags] guarda **nomes** de tag;
/// [materialKindIds], ids de `material_kind`. Os getters `*UrlValue` dão o
/// CSV ordenado de cada conjunto (`null` quando vazio) para a URL (§2.5).
class CatalogFilterState {
  const CatalogFilterState({
    this.tonalities = const {},
    this.rhythms = const {},
    this.categories = const {},
    this.tags = const {},
    this.materialKindIds = const {},
  });

  /// Sem filtro nenhum.
  static const empty = CatalogFilterState();

  /// Estado a partir dos params da URL (CSV de cada filtro).
  factory CatalogFilterState.fromUrl({
    String? tonality,
    String? rhythm,
    String? category,
    String? tags,
    String? materialKinds,
  }) {
    return CatalogFilterState(
      tonalities: parseCsv(tonality),
      rhythms: parseCsv(rhythm),
      categories: parseCsv(category),
      tags: parseCsv(tags),
      materialKindIds: parseCsv(materialKinds),
    );
  }

  final Set<String> tonalities;
  final Set<String> rhythms;
  final Set<String> categories;

  /// Nomes de tag; `PES` também apanha `PES · 9.2026`.
  final Set<String> tags;

  /// Ids de `material_kind`.
  final Set<String> materialKindIds;

  bool get isEmpty =>
      tonalities.isEmpty &&
      rhythms.isEmpty &&
      categories.isEmpty &&
      tags.isEmpty &&
      materialKindIds.isEmpty;

  /// Quantos valores estão escolhidos, somando todos os filtros — a
  /// contagem do cabeçalho do painel (`filtersActiveCount`).
  int get activeCount =>
      tonalities.length +
      rhythms.length +
      categories.length +
      tags.length +
      materialKindIds.length;

  CatalogFilterState copyWith({
    Set<String>? tonalities,
    Set<String>? rhythms,
    Set<String>? categories,
    Set<String>? tags,
    Set<String>? materialKindIds,
  }) {
    return CatalogFilterState(
      tonalities: tonalities ?? this.tonalities,
      rhythms: rhythms ?? this.rhythms,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      materialKindIds: materialKindIds ?? this.materialKindIds,
    );
  }

  String? get tonalityUrlValue => _csvOrNull(tonalities);
  String? get rhythmUrlValue => _csvOrNull(rhythms);
  String? get categoryUrlValue => _csvOrNull(categories);
  String? get tagsUrlValue => _csvOrNull(tags);
  String? get materialKindsUrlValue => _csvOrNull(materialKindIds);

  /// Versão do JSON gravado em `StorageKeys.catalogFilters`.
  static const persistedVersion = 2;

  Map<String, Object> toPersistedJson() => {
    'v': persistedVersion,
    'tonalities': _sorted(tonalities),
    'rhythms': _sorted(rhythms),
    'categories': _sorted(categories),
    'tags': _sorted(tags),
    'materialKinds': _sorted(materialKindIds),
  };

  /// `null` quando [json] não é o formato [persistedVersion] — inclusive o
  /// antigo `{materials, arranjos}`, que é descartado (spec §2.2).
  static CatalogFilterState? fromPersistedJson(Object? json) {
    if (json is! Map || json['v'] != persistedVersion) return null;
    Set<String> read(String key) {
      final raw = json[key];
      if (raw is! List) return <String>{};
      return {
        for (final value in raw)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      };
    }

    return CatalogFilterState(
      tonalities: read('tonalities'),
      rhythms: read('rhythms'),
      categories: read('categories'),
      tags: read('tags'),
      materialKindIds: read('materialKinds'),
    );
  }

  /// CSV da URL → conjunto (trim, sem vazios).
  static Set<String> parseCsv(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static String? _csvOrNull(Set<String> values) =>
      values.isEmpty ? null : _sorted(values).join(',');

  static List<String> _sorted(Set<String> values) => values.toList()..sort();

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogFilterState &&
          _sameSet(tonalities, other.tonalities) &&
          _sameSet(rhythms, other.rhythms) &&
          _sameSet(categories, other.categories) &&
          _sameSet(tags, other.tags) &&
          _sameSet(materialKindIds, other.materialKindIds);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(tonalities),
    Object.hashAllUnordered(rhythms),
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(tags),
    Object.hashAllUnordered(materialKindIds),
  );

  @override
  String toString() =>
      'CatalogFilterState(tom: $tonalities, ritmo: $rhythms, '
      'categoria: $categories, tags: $tags, tipos: $materialKindIds)';
}
