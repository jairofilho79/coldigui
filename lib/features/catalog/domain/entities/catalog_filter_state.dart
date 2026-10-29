import '../utils/legacy_category_tags.dart';

/// Filtros do catálogo — um conjunto só para a página inicial e a
/// /biblioteca (spec fim-fonte §2.2, C5).
///
/// OU dentro de cada conjunto, E entre conjuntos; conjunto vazio não
/// restringe (`matchesCatalogFilters`). [tags] guarda **nomes** de tag;
/// [materialKindIds], ids de `material_kind`. Os getters `*UrlValue` dão o
/// CSV ordenado de cada conjunto (`null` quando vazio) para a URL (§2.5).
///
/// Não há filtro de categoria: a seção da Coletânea é a subtag
/// `Coletânea · <seção>` (spec seções-coletânea §4). Links e prefs antigos
/// com categoria são convertidos em tags na leitura ([legacyCategoryToTags]).
class CatalogFilterState {
  const CatalogFilterState({
    this.tonalities = const {},
    this.rhythms = const {},
    this.tags = const {},
    this.materialKindIds = const {},
  });

  /// Sem filtro nenhum.
  static const empty = CatalogFilterState();

  /// Estado a partir dos params da URL (CSV de cada filtro).
  ///
  /// [category] é o param legado `?category=`: cada valor vira a subtag de
  /// `Coletânea` e soma-se a [tags]; valores sem seção (Avulsos…) são
  /// descartados (spec seções-coletânea §4.2).
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
      tags: {...parseCsv(tags), ...legacyCategoryToTags(parseCsv(category))},
      materialKindIds: parseCsv(materialKinds),
    );
  }

  final Set<String> tonalities;
  final Set<String> rhythms;

  /// Nomes de tag; `PES` também apanha `PES · 9.2026`.
  final Set<String> tags;

  /// Ids de `material_kind`.
  final Set<String> materialKindIds;

  bool get isEmpty =>
      tonalities.isEmpty &&
      rhythms.isEmpty &&
      tags.isEmpty &&
      materialKindIds.isEmpty;

  /// Quantos valores estão escolhidos, somando todos os filtros — a
  /// contagem do cabeçalho do painel (`filtersActiveCount`).
  int get activeCount =>
      tonalities.length + rhythms.length + tags.length + materialKindIds.length;

  CatalogFilterState copyWith({
    Set<String>? tonalities,
    Set<String>? rhythms,
    Set<String>? tags,
    Set<String>? materialKindIds,
  }) {
    return CatalogFilterState(
      tonalities: tonalities ?? this.tonalities,
      rhythms: rhythms ?? this.rhythms,
      tags: tags ?? this.tags,
      materialKindIds: materialKindIds ?? this.materialKindIds,
    );
  }

  String? get tonalityUrlValue => _csvOrNull(tonalities);
  String? get rhythmUrlValue => _csvOrNull(rhythms);
  String? get tagsUrlValue => _csvOrNull(tags);
  String? get materialKindsUrlValue => _csvOrNull(materialKindIds);

  /// Versão do JSON gravado em `StorageKeys.catalogFilters`. A v3 não tem
  /// `categories`; a v2 (com `categories`) continua a ser lida
  /// ([_readableVersions]) e convertida em tags.
  static const persistedVersion = 3;

  static const _readableVersions = {2, persistedVersion};

  Map<String, Object> toPersistedJson() => {
    'v': persistedVersion,
    'tonalities': _sorted(tonalities),
    'rhythms': _sorted(rhythms),
    'tags': _sorted(tags),
    'materialKinds': _sorted(materialKindIds),
  };

  /// `null` quando [json] não é uma versão legível — inclusive o antigo
  /// `{materials, arranjos}`, que é descartado (spec fim-fonte §2.2). A chave
  /// `categories` (v2) vira subtags de `Coletânea` somadas a [tags] (spec
  /// seções-coletânea §4.2).
  static CatalogFilterState? fromPersistedJson(Object? json) {
    if (json is! Map || !_readableVersions.contains(json['v'])) return null;
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
      tags: {...read('tags'), ...legacyCategoryToTags(read('categories'))},
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
          _sameSet(tags, other.tags) &&
          _sameSet(materialKindIds, other.materialKindIds);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(tonalities),
    Object.hashAllUnordered(rhythms),
    Object.hashAllUnordered(tags),
    Object.hashAllUnordered(materialKindIds),
  );

  @override
  String toString() =>
      'CatalogFilterState(tom: $tonalities, ritmo: $rhythms, '
      'tags: $tags, tipos: $materialKindIds)';
}
