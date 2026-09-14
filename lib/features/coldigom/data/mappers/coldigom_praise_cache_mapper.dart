import 'dart:convert';

import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../catalog/domain/utils/louvor_numero_normalizer.dart';
import '../models/coldigom_catalog_dto.dart';
import '../models/praise_dto.dart';

/// Um item de [ColdigomPraiseCache.materialsJson], já decodificado.
///
/// É o que o download (plano 2) enumera: `type` decide se é baixável,
/// [kindId] filtra pelos kinds escolhidos, [r2Key] é o que se busca.
class ColdigomCatalogMaterialEntry {
  const ColdigomCatalogMaterialEntry({
    required this.id,
    required this.kindId,
    required this.kindName,
    required this.type,
    required this.r2Key,
    this.size,
    this.url,
  });

  final String id;
  final String? kindId;

  /// Rótulo do kind (`Grade`, `Playback`…); `''` quando não há kind.
  final String kindName;
  final String type;
  final String? r2Key;
  final int? size;
  final String? url;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kindId,
    'kindName': kindName,
    'type': type,
    'r2': r2Key,
    if (size != null) 'size': size,
    if (url != null) 'url': url,
  };

  static ColdigomCatalogMaterialEntry fromJson(Map<String, dynamic> json) {
    return ColdigomCatalogMaterialEntry(
      id: json['id'] as String? ?? '',
      kindId: json['kind'] as String?,
      kindName: json['kindName'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      r2Key: json['r2'] as String?,
      size: (json['size'] as num?)?.toInt(),
      url: json['url'] as String?,
    );
  }
}

/// Conversões entre o dump do Worker, a linha Isar e o [PraiseDetailDto] que
/// o `ColdigomLouvorAdapter` já sabe transformar em entidades.
///
/// Guardar `kindName` no JSON da linha (o dump manda só `kind`) evita uma
/// segunda tabela: é o rótulo das tiles do sheet, e o sync tem o mapa
/// `kinds` à mão nesse momento.
abstract final class ColdigomPraiseCacheMapper {
  /// Linha Isar a partir de um praise do dump.
  static ColdigomPraiseCache fromCatalogPraise(
    ColdigomCatalogPraiseDto praise, {
    required Map<String, String> kindNames,
  }) {
    return _row(
      praiseId: praise.id,
      number: praise.number,
      name: praise.name,
      author: praise.author,
      rhythm: praise.rhythm,
      tonality: praise.tonality,
      category: praise.category,
      tags: praise.tags,
      lyrics: praise.lyrics,
      materials: [
        for (final m in praise.materials)
          ColdigomCatalogMaterialEntry(
            id: m.id,
            kindId: m.kindId,
            kindName: kindNames[m.kindId] ?? '',
            type: m.type,
            r2Key: m.r2Key,
            size: m.size,
            url: m.url,
          ),
      ],
    );
  }

  /// Linha Isar a partir de um praise de `/api/plpcg/praises` (os «novos»
  /// da pesquisa, §6). A página não traz a letra; [lyrics] só vem
  /// preenchida quando quem chama a tem.
  static ColdigomPraiseCache fromPraiseDetail(
    PraiseDetailDto praise, {
    required Map<String, String> kindNames,
    String lyrics = '',
  }) {
    return _row(
      praiseId: praise.id,
      number: praise.number,
      name: praise.name,
      author: praise.author,
      rhythm: praise.rhythm,
      tonality: praise.tonality,
      category: praise.category,
      tags: praise.tagNames,
      lyrics: lyrics,
      materials: [
        for (final m in praise.materials)
          // A página já traz o material sintético de letra; a linha guarda
          // a letra no campo próprio, não como material.
          if (m.type.toLowerCase() != 'lyrics')
            ColdigomCatalogMaterialEntry(
              id: m.id,
              kindId: m.materialKindId,
              kindName: m.materialKindName ?? kindNames[m.materialKindId] ?? '',
              type: m.type,
              r2Key: m.r2Key,
              url: m.url,
            ),
      ],
    );
  }

  static ColdigomPraiseCache _row({
    required String praiseId,
    required String number,
    required String name,
    required String author,
    required String rhythm,
    required String tonality,
    required String category,
    required List<String> tags,
    required String lyrics,
    required List<ColdigomCatalogMaterialEntry> materials,
  }) {
    return ColdigomPraiseCache()
      ..praiseId = praiseId
      ..number = number
      ..name = name
      ..author = author
      ..rhythm = rhythm
      ..tonality = tonality
      ..category = category
      ..tags = List<String>.from(tags)
      ..lyrics = lyrics
      ..materialsJson = jsonEncode([for (final m in materials) m.toJson()])
      ..searchTokens = buildSearchTokens(
        name: name,
        number: number,
        author: author,
        tags: tags,
      );
  }

  /// Tokens de busca — mesma normalização de `Louvor.fromManifest`
  /// ([LouvorSearchTokens.tokenize] + número normalizado), mais tags e autor
  /// (a letra fica de fora nesta entrega, §9).
  static String buildSearchTokens({
    required String name,
    required String number,
    required String author,
    required List<String> tags,
  }) {
    final tokens = <String>{
      ...LouvorSearchTokens.tokenize(name),
      ...LouvorSearchTokens.tokenize(author),
      for (final tag in tags) ...LouvorSearchTokens.tokenize(tag),
    };
    final numeroNorm = LouvorNumeroNormalizer.normalize(number);
    if (numeroNorm.isNotEmpty) tokens.add(numeroNorm);
    if (number.trim().isNotEmpty) {
      tokens.add(LouvorSearchTokens.normalize(number.trim()));
    }
    return tokens.where((t) => t.isNotEmpty).join(' ');
  }

  /// Materiais da linha, decodificados. JSON corrompido → lista vazia (a
  /// linha é regravada no próximo sync).
  static List<ColdigomCatalogMaterialEntry> decodeMaterials(
    ColdigomPraiseCache row,
  ) {
    try {
      final raw = jsonDecode(row.materialsJson);
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>)
            ColdigomCatalogMaterialEntry.fromJson(item),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// [PraiseDetailDto] equivalente à linha — o formato que
  /// `ColdigomLouvorAdapter` e `ColdigomCacheWriter` já consomem. A letra
  /// entra como material sintético `lyrics:<praiseId>` (id do Worker, O6).
  ///
  /// Materiais sem `r2Key` que não sejam `youtube` (tipo desconhecido, sem
  /// `r2` explícito) não são endereçáveis — nem baixáveis nem reproduzíveis
  /// — e ficam de fora do detalhe.
  static PraiseDetailDto toPraiseDetail(ColdigomPraiseCache row) {
    final materials = [
      for (final m in decodeMaterials(row))
        if (m.r2Key != null || m.type.toLowerCase() == 'youtube')
          MaterialDto(
            id: m.id,
            type: m.type,
            r2Key: m.r2Key,
            url: m.url,
            materialKindName: m.kindName.isEmpty ? null : m.kindName,
            materialKindId: m.kindId,
          ),
      if (row.lyrics.trim().isNotEmpty)
        MaterialDto(id: 'lyrics:${row.praiseId}', type: 'lyrics'),
    ];
    return PraiseDetailDto(
      id: row.praiseId,
      name: row.name,
      number: row.number,
      rhythm: row.rhythm,
      tonality: row.tonality,
      category: row.category,
      author: row.author,
      tagNames: List<String>.from(row.tags),
      materials: materials,
    );
  }
}
