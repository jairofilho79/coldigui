/// Material de um louvor (PDF, áudio, YouTube, etc.).
class MaterialDto {
  const MaterialDto({
    required this.id,
    required this.type,
    this.r2Key,
    this.url,
    this.materialKindName,
  });

  final String id;
  final String type;
  final String? r2Key;

  /// URL externa (ex.: YouTube). Pode ser null na maioria dos registros.
  final String? url;
  final String? materialKindName;

  factory MaterialDto.fromJson(Map<String, dynamic> json) {
    return MaterialDto(
      id: json['id'] as String,
      type: json['type'] as String,
      r2Key: json['r2_key'] as String?,
      url: json['url'] as String?,
      materialKindName: json['material_kind_name'] as String?,
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

  factory PraiseSummaryDto.fromJson(Map<String, dynamic> json) {
    return PraiseSummaryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String? ?? '',
      rhythm: json['rhythm'] as String? ?? '',
      tonality: json['tonality'] as String? ?? '',
      category: json['category'] as String? ?? '',
      author: json['author'] as String? ?? '',
      tagIds: _splitCsv(json['tag_ids']),
      tagNames: _splitCsv(json['tag_names']),
    );
  }

  static List<String> _splitCsv(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
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
  });

  final String id;
  final String name;
  final String number;
  final String rhythm;
  final String tonality;
  final String category;
  final String author;
  final List<MaterialDto> materials;

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
      materials: [
        for (final item in materialsJson)
          MaterialDto.fromJson(item as Map<String, dynamic>),
      ],
    );
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

/// Facet de tag em `/api/praises/filters`.
class ColdigomTagFacetDto {
  const ColdigomTagFacetDto({
    required this.id,
    required this.name,
    this.count = 0,
  });

  final String id;
  final String name;
  final int count;

  factory ColdigomTagFacetDto.fromJson(Map<String, dynamic> json) {
    return ColdigomTagFacetDto(
      id: json['id'] as String,
      name: json['name'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Opções de filtro de `GET /api/praises/filters`.
class ColdigomFilterOptionsDto {
  const ColdigomFilterOptionsDto({
    required this.rhythms,
    required this.tonalities,
    required this.categories,
    required this.tags,
  });

  final List<String> rhythms;
  final List<String> tonalities;
  final List<String> categories;
  final List<ColdigomTagFacetDto> tags;

  factory ColdigomFilterOptionsDto.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'] as List<dynamic>? ?? const [];
    return ColdigomFilterOptionsDto(
      rhythms: _stringList(json['rhythms']),
      tonalities: _stringList(json['tonalities']),
      categories: _stringList(json['categories']),
      tags: [
        for (final item in tagsJson)
          ColdigomTagFacetDto.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String && item.isNotEmpty) item,
    ];
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
