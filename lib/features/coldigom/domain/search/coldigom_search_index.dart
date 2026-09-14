import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/utils/louvor_numero_normalizer.dart';

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
final class ColdigomSearchIndex {
  const ColdigomSearchIndex._(this.entries, this.praiseIds);

  /// Índice vazio — antes da hidratação e em modo degradado.
  static const empty = ColdigomSearchIndex._(
    <ColdigomIndexedPraise>[],
    <String>{},
  );

  factory ColdigomSearchIndex.build(List<ColdigomIndexedPraise> entries) {
    if (entries.isEmpty) return empty;
    return ColdigomSearchIndex._(
      List<ColdigomIndexedPraise>.unmodifiable(entries),
      Set<String>.unmodifiable({for (final e in entries) e.praiseId}),
    );
  }

  final List<ColdigomIndexedPraise> entries;

  /// Ids conhecidos localmente — é contra isto que a pesquisa remota (plano
  /// 3) decide o que é «novo».
  final Set<String> praiseIds;

  bool get isEmpty => entries.isEmpty;

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
