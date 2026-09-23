import 'package:flutter/foundation.dart';

import '../../domain/utils/praise_short_id.dart';

/// Material de um louvor (PDF, áudio, YouTube, etc.).
class MaterialDto {
  const MaterialDto({
    required this.id,
    required this.type,
    this.r2Key,
    this.url,
    this.materialKindName,
    this.materialKindId,
  });

  final String id;
  final String type;
  final String? r2Key;

  /// URL externa (ex.: YouTube). Pode ser null na maioria dos registros.
  final String? url;
  final String? materialKindName;

  /// Id do `material_kind` Coldigom (UUID) — chave dos favoritos do usuário.
  /// Null no placeholder de letra e em respostas antigas.
  final String? materialKindId;

  factory MaterialDto.fromJson(Map<String, dynamic> json) {
    return MaterialDto(
      // API PLPCG envia id null no placeholder de letra.
      id: json['id'] as String? ?? '',
      // `type` ausente ou de tipo inesperado não deve derrubar o material —
      // vira 'unknown' em vez de lançar (C.8).
      type: json['type'] is String ? json['type'] as String : 'unknown',
      r2Key: json['r2_key'] as String?,
      url: json['url'] as String?,
      materialKindName: json['material_kind_name'] as String?,
      materialKindId: json['material_kind'] is String
          ? json['material_kind'] as String
          : null,
    );
  }
}

/// Resumo de louvor retornado por `GET /api/praises`.
class PraiseSummaryDto {
  const PraiseSummaryDto({
    required this.id,
    required this.name,
    required this.number,
    this.rhythm = '',
    this.tonality = '',
    this.category = '',
    this.author = '',
    this.tagIds = const [],
    this.tagNames = const [],
    this.shortId,
  });

  final String id;
  final String name;
  final String number;
  final String rhythm;
  final String tonality;
  final String category;
  final String author;
  final List<String> tagIds;
  final List<String> tagNames;

  /// `short_id` do praise ([normalizePraiseShortId]); `null` se ausente.
  final String? shortId;

  factory PraiseSummaryDto.fromJson(Map<String, dynamic> json) {
    return PraiseSummaryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String? ?? '',
      rhythm: json['rhythm'] as String? ?? '',
      tonality: json['tonality'] as String? ?? '',
      category: json['category'] as String? ?? '',
      author: json['author'] as String? ?? '',
      tagIds: splitColdigomCsv(json['tag_ids']),
      tagNames: splitColdigomCsv(json['tag_names']),
      shortId: normalizePraiseShortId(json['short_id']),
    );
  }
}

/// CSV de facets Coldigom (`tag_ids`, `tag_names`).
List<String> splitColdigomCsv(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

/// Detalhe completo de louvor — `GET /api/praises/:id`.
class PraiseDetailDto {
  const PraiseDetailDto({
    required this.id,
    required this.name,
    required this.number,
    required this.rhythm,
    required this.materials,
    this.tonality = '',
    this.category = '',
    this.author = '',
    this.tagNames = const [],
    this.lyricsExcerpt,
    this.shortId,
  });

  final String id;
  final String name;
  final String number;
  final String rhythm;
  final String tonality;
  final String category;
  final String author;
  final List<String> tagNames;
  final List<MaterialDto> materials;

  /// Trecho de uma linha da letra ao redor do match da busca — só quando a
  /// busca bateu na letra; `null` no browse comum ou match só no título.
  final String? lyricsExcerpt;

  /// `short_id` do praise ([normalizePraiseShortId]); `null` se ausente.
  final String? shortId;

  factory PraiseDetailDto.fromJson(Map<String, dynamic> json) {
    final materialsJson = json['materials'] as List<dynamic>? ?? const [];
    return PraiseDetailDto(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String? ?? '',
      rhythm: json['rhythm'] as String? ?? '',
      tonality: json['tonality'] as String? ?? '',
      category: json['category'] as String? ?? '',
      author: json['author'] as String? ?? '',
      tagNames: splitColdigomCsv(json['tag_names']),
      lyricsExcerpt: json['lyrics_excerpt'] as String?,
      shortId: normalizePraiseShortId(json['short_id']),
      materials: _parseMaterials(materialsJson),
    );
  }

  /// Descarta, individualmente, materiais cujo `fromJson` lance — um item
  /// corrompido não pode derrubar o louvor inteiro (C.8).
  static List<MaterialDto> _parseMaterials(List<dynamic> materialsJson) {
    final materials = <MaterialDto>[];
    for (final item in materialsJson) {
      try {
        materials.add(MaterialDto.fromJson(item as Map<String, dynamic>));
      } on Object catch (error) {
        debugPrint('[coldigom] material descartado: $error');
      }
    }
    return materials;
  }
}

/// Paginação de `GET /api/praises`.
class PraisesPaginationDto {
  const PraisesPaginationDto({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory PraisesPaginationDto.fromJson(Map<String, dynamic> json) {
    return PraisesPaginationDto(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Página de resultados de `GET /api/praises`.
class PraisesPageDto {
  const PraisesPageDto({required this.data, required this.pagination});

  final List<PraiseSummaryDto> data;
  final PraisesPaginationDto pagination;

  factory PraisesPageDto.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? const [];
    final paginationJson =
        json['pagination'] as Map<String, dynamic>? ?? const {};
    return PraisesPageDto(
      data: [
        for (final item in list)
          PraiseSummaryDto.fromJson(item as Map<String, dynamic>),
      ],
      pagination: PraisesPaginationDto.fromJson(paginationJson),
    );
  }
}

/// Página de `GET /api/plpcg/praises` (praise + materials slim embutidos).
class PlpcgPraisesPageDto {
  const PlpcgPraisesPageDto({required this.data, required this.pagination});

  final List<PraiseDetailDto> data;
  final PraisesPaginationDto pagination;

  factory PlpcgPraisesPageDto.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? const [];
    final paginationJson =
        json['pagination'] as Map<String, dynamic>? ?? const {};
    return PlpcgPraisesPageDto(
      data: [
        for (final item in list)
          PraiseDetailDto.fromJson(item as Map<String, dynamic>),
      ],
      pagination: PraisesPaginationDto.fromJson(paginationJson),
    );
  }
}

/// Resposta de `GET /api/praises/:id`.
class PraiseDetailResponseDto {
  const PraiseDetailResponseDto({required this.data});

  final PraiseDetailDto data;

  factory PraiseDetailResponseDto.fromJson(Map<String, dynamic> json) {
    return PraiseDetailResponseDto(
      data: PraiseDetailDto.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

/// Kind de material (`GET /api/materials/kinds`).
class ColdigomMaterialKindDto {
  const ColdigomMaterialKindDto({required this.id, required this.name});

  final String id;
  final String name;

  factory ColdigomMaterialKindDto.fromJson(Map<String, dynamic> json) {
    return ColdigomMaterialKindDto(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
