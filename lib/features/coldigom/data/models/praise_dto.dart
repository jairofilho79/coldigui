/// Material de um louvor (PDF, áudio, etc.).
class MaterialDto {
  const MaterialDto({
    required this.id,
    required this.type,
    this.r2Key,
    this.materialKindName,
  });

  final String id;
  final String type;
  final String? r2Key;
  final String? materialKindName;

  factory MaterialDto.fromJson(Map<String, dynamic> json) {
    return MaterialDto(
      id: json['id'] as String,
      type: json['type'] as String,
      r2Key: json['r2_key'] as String?,
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
  });

  final String id;
  final String name;
  final String number;

  factory PraiseSummaryDto.fromJson(Map<String, dynamic> json) {
    return PraiseSummaryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String? ?? '',
    );
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
  });

  final String id;
  final String name;
  final String number;
  final String rhythm;
  final List<MaterialDto> materials;

  factory PraiseDetailDto.fromJson(Map<String, dynamic> json) {
    final materialsJson = json['materials'] as List<dynamic>? ?? const [];
    return PraiseDetailDto(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String? ?? '',
      rhythm: json['rhythm'] as String? ?? '',
      materials: [
        for (final item in materialsJson)
          MaterialDto.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

/// Resposta paginada de `GET /api/praises`.
class PraisesSearchResponseDto {
  const PraisesSearchResponseDto({required this.data});

  final List<PraiseSummaryDto> data;

  factory PraisesSearchResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? const [];
    return PraisesSearchResponseDto(
      data: [
        for (final item in list)
          PraiseSummaryDto.fromJson(item as Map<String, dynamic>),
      ],
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
