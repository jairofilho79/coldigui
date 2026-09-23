import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/utils/louvor_numero_normalizer.dart';
import '../utils/praise_short_id.dart';

/// Um praise no índice: os campos de busca pré-computados e o grupo pronto
/// para a Home — construído **uma vez por hidratação**, não por tecla.
final class ColdigomIndexedPraise {
  const ColdigomIndexedPraise._({
    required this.praiseId,
    required this.numero,
    required this.numeroNorm,
    required this.titleNorm,
    required this.titleCompact,
    required this.contentTokens,
    required this.compactContent,
    required this.group,
  });

  /// [searchTokens] é a coluna `ColdigomPraiseCache.searchTokens` (nome +
  /// número + tags + autor, já normalizados) — ver
  /// `ColdigomPraiseCacheMapper.buildSearchTokens`.
  factory ColdigomIndexedPraise.build({
    required String praiseId,
    required String numero,
    required String nome,
    required String searchTokens,
    required LouvorGroup group,
  }) {
    final tokens = searchTokens
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    final titleCompact = LouvorSearchTokens.compact(nome);
    return ColdigomIndexedPraise._(
      praiseId: praiseId,
      numero: numero.trim(),
      numeroNorm: LouvorNumeroNormalizer.normalize(numero),
      titleNorm: LouvorSearchTokens.normalize(nome),
      titleCompact: titleCompact,
      contentTokens: tokens,
      // Compacto só do título — igual a `Louvor.searchCompactContent` no
      // PLPCG (sempre `compact(nome)`, com stop words mantidas). Não é o
      // compacto de `tokens` (nome+autor+tags+número): isso criaria pontes
      // falsas entre campos, ex. praise "São João" de "Autor Dois" casaria
      // a query compacta "joaoau", que não existe em nenhum campo isolado.
      compactContent: titleCompact,
      group: group,
    );
  }

  final String praiseId;
  final String numero;
  final String numeroNorm;
  final String titleNorm;
  final String titleCompact;
  final List<String> contentTokens;

  /// Igual a [titleCompact] — duplicado só para bater a assinatura genérica
  /// de [LouvorSearchTokens.matchesText] (que no PLPCG recebe
  /// `searchCompactContent`, também compacto só do título).
  final String compactContent;
  final LouvorGroup group;
}

/// Índice de busca do acervo Coldigom — espelho de `PlpcgSearchIndex`.
///
/// Mesmo ranking de `SearchLouvorByNumberOrText.callIndexed` (número exato →
/// título exato → parcial), sobre praises em vez de `Louvor`: no Coldigom a
/// unidade da Home é o grupo, e ele já sai montado daqui.
///
/// Também é **o** catálogo do app (spec fim-fonte §2.1): [groups] alimenta a
/// /biblioteca e as opções de filtro, e os mapas de [groupByShortId] (link
/// por louvor) e [groupForMaterialId] (entrada de playlist → louvor) são
/// montados uma vez por hidratação.
final class ColdigomSearchIndex {
  const ColdigomSearchIndex._(
    this.entries,
    this.groups,
    this.praiseIds,
    this.catalogIds,
    this._groupByShortId,
    this._groupByMaterialId,
  );

  /// Índice vazio — antes da hidratação e em modo degradado.
  static const empty = ColdigomSearchIndex._(
    <ColdigomIndexedPraise>[],
    <LouvorGroup>[],
    <String>{},
    <String>{},
    <String, LouvorGroup>{},
    <String, LouvorGroup>{},
  );

  /// [catalogIds] é o Isar inteiro (inclui praises sem material endereçável,
  /// ex. só YouTube, que ficam fora de [entries]/[praiseIds]) — quando
  /// omitido cai para os ids das [entries]. Ver [catalogIds].
  factory ColdigomSearchIndex.build(
    List<ColdigomIndexedPraise> entries, {
    Set<String>? catalogIds,
  }) {
    if (entries.isEmpty && (catalogIds == null || catalogIds.isEmpty)) {
      return empty;
    }
    final praiseIds = Set<String>.unmodifiable({
      for (final e in entries) e.praiseId,
    });
    final byShortId = <String, LouvorGroup>{};
    final byMaterialId = <String, LouvorGroup>{};
    for (final entry in entries) {
      final shortId = normalizePraiseShortId(entry.group.coldigomMeta?.shortId);
      if (shortId != null) byShortId.putIfAbsent(shortId, () => entry.group);
      for (final material in entry.group.materials) {
        byMaterialId.putIfAbsent(material.id, () => entry.group);
      }
    }
    return ColdigomSearchIndex._(
      List<ColdigomIndexedPraise>.unmodifiable(entries),
      List<LouvorGroup>.unmodifiable([for (final e in entries) e.group]),
      praiseIds,
      catalogIds == null ? praiseIds : Set<String>.unmodifiable(catalogIds),
      Map<String, LouvorGroup>.unmodifiable(byShortId),
      Map<String, LouvorGroup>.unmodifiable(byMaterialId),
    );
  }

  final List<ColdigomIndexedPraise> entries;

  /// Um grupo por entry, na ordem das [entries] — o catálogo inteiro que a
  /// /biblioteca filtra e ordena.
  final List<LouvorGroup> groups;

  /// Ids no índice de busca (com material endereçável) — é contra isto que
  /// a busca textual local decide match; ver [ColdigomIndexedPraise.build].
  final Set<String> praiseIds;

  /// Todo o Isar, [praiseIds] incluído — é contra isto que a pesquisa remota
  /// (plano 3, §6.2) decide o que é «novo» (`HomeSearchState.knownIds`): um
  /// praise já adotado no Isar (mesmo sem entrar no índice de busca, ex.
  /// só-YouTube) não deve continuar a levar o chip «novo» pra sempre.
  final Set<String> catalogIds;

  final Map<String, LouvorGroup> _groupByShortId;
  final Map<String, LouvorGroup> _groupByMaterialId;

  bool get isEmpty => entries.isEmpty;

  /// Grupo do praise com [shortId] (link `?p=`, spec §4.3); a entrada é
  /// normalizada (`0A1` → `0a1`). `null` para inválido ou desconhecido.
  LouvorGroup? groupByShortId(String shortId) {
    final normalized = normalizePraiseShortId(shortId);
    return normalized == null ? null : _groupByShortId[normalized];
  }

  /// Grupo ao qual pertence a entrada de playlist [entryId] — qualquer id de
  /// `LouvorGroup.materials` (pdfId, audioId, chordId, gestureId,
  /// `lyrics:<praiseId>`, id do material YouTube). Usa o material do
  /// catálogo, não o path do id: 64 materiais movidos têm o path na pasta
  /// de outro praise (desvio 2 do spec de 18/09).
  LouvorGroup? groupForMaterialId(String entryId) =>
      _groupByMaterialId[entryId];

  /// Grupos que casam com [query], ranqueados; vazio para query em branco.
  List<LouvorGroup> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || entries.isEmpty) return const [];

    final numeroQuery = LouvorNumeroNormalizer.normalize(trimmed);
    bool matchesNumero(ColdigomIndexedPraise entry) =>
        entry.numero == trimmed ||
        (numeroQuery.isNotEmpty && entry.numeroNorm == numeroQuery);

    final queryTokens = LouvorSearchTokens.tokenize(trimmed);
    // Sem tokens de título (query só com stop words/pontuação) — igual a
    // `SearchLouvorByNumberOrText._rankByTitle`: só sobra o número exato.
    if (queryTokens.isEmpty) {
      return [
        for (final entry in entries)
          if (matchesNumero(entry)) entry.group,
      ];
    }

    final queryNorm = LouvorSearchTokens.normalize(trimmed);
    final queryCompact = LouvorSearchTokens.compact(trimmed);

    final exactNumber = <LouvorGroup>[];
    final exactTitle = <LouvorGroup>[];
    final partial = <LouvorGroup>[];

    for (final entry in entries) {
      if (matchesNumero(entry)) {
        exactNumber.add(entry.group);
        continue;
      }
      if (entry.titleNorm == queryNorm ||
          (queryCompact.length >= 3 && entry.titleCompact == queryCompact)) {
        exactTitle.add(entry.group);
        continue;
      }
      final matches = LouvorSearchTokens.matchesText(
        contentTokens: entry.contentTokens,
        compactContent: entry.compactContent,
        query: trimmed,
        queryTokens: queryTokens,
      );
      if (matches) partial.add(entry.group);
    }

    return [...exactNumber, ...exactTitle, ...partial];
  }
}
