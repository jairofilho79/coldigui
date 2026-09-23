import 'package:flutter/foundation.dart';

import '../../domain/utils/praise_short_id.dart';

/// Extensão do objeto no R2 por `type` do Worker — a outra metade da regra
/// O2: o dump só manda `{id, kind, type}` e o app reconstrói o `r2_key`.
///
/// `null` para tipos que não vivem no R2 (`youtube`, `lyrics`) ou
/// desconhecidos. Mantenha em sincronia com `CATALOG_EXT_BY_TYPE` do patch
/// `patches/coldigom-api-plpcg-catalog.patch`.
String? coldigomCatalogExtensionForType(String type) {
  return switch (type.toLowerCase()) {
    'pdf' => 'pdf',
    'mp3' || 'audio' => 'mp3',
    'chord' => 'chord',
    'gestures' => 'gestures',
    _ => null,
  };
}

/// Material de um praise no dump `GET /api/plpcg/catalog`.
class ColdigomCatalogMaterialDto {
  const ColdigomCatalogMaterialDto({
    required this.id,
    required this.type,
    required this.r2Key,
    this.kindId,
    this.size,
    this.url,
  });

  final String id;

  /// Id do `material_kind`; `null` em YouTube.
  final String? kindId;

  /// `pdf`/`mp3`/`audio`/`chord`/`gestures`/`youtube`.
  final String type;

  /// Tamanho em bytes quando o Worker o conhece (O13); senão `null` e o app
  /// estima por tipo.
  final int? size;

  /// URL externa (YouTube).
  final String? url;

  /// `r2` explícito do dump quando presente, senão o derivado por [type];
  /// `null` quando o material não vive no R2.
  final String? r2Key;

  /// [praiseId] entra aqui (e não no JSON) porque o `r2_key` é derivado.
  factory ColdigomCatalogMaterialDto.fromJson(
    Map<String, dynamic> json, {
    required String praiseId,
  }) {
    final id = json['id'] as String? ?? '';
    final type = json['type'] is String ? json['type'] as String : 'unknown';
    final explicit = json['r2'] is String ? (json['r2'] as String).trim() : '';
    final ext = coldigomCatalogExtensionForType(type);
    final String? r2Key;
    if (explicit.isNotEmpty) {
      r2Key = explicit;
    } else if (ext != null && id.isNotEmpty) {
      r2Key = 'assets/praises/$praiseId/$id.$ext';
    } else {
      r2Key = null;
    }
    return ColdigomCatalogMaterialDto(
      id: id,
      kindId: json['kind'] is String ? json['kind'] as String : null,
      type: type,
      // `size` de tipo errado não derruba o material — só vira null (mesma
      // tolerância de kindId/type acima).
      size: json['size'] is num ? (json['size'] as num).toInt() : null,
      url: json['url'] is String ? json['url'] as String : null,
      r2Key: r2Key,
    );
  }
}

/// Um louvor no dump — metadados, tags, letra e materiais.
class ColdigomCatalogPraiseDto {
  const ColdigomCatalogPraiseDto({
    required this.id,
    required this.number,
    required this.name,
    required this.author,
    required this.rhythm,
    required this.tonality,
    required this.category,
    required this.tags,
    required this.lyrics,
    required this.materials,
    this.shortId,
  });

  final String id;
  final String number;
  final String name;
  final String author;
  final String rhythm;
  final String tonality;
  final String category;
  final List<String> tags;

  /// `''` quando o dump omite (letra vazia).
  final String lyrics;
  final List<ColdigomCatalogMaterialDto> materials;

  /// `shortId` do praise ([normalizePraiseShortId]); `null` quando o dump
  /// não o traz (praise sem `short_id` no coldigom) ou é inválido.
  final String? shortId;

  factory ColdigomCatalogPraiseDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return ColdigomCatalogPraiseDto(
      id: id,
      shortId: normalizePraiseShortId(json['shortId']),
      number: json['number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      rhythm: json['rhythm'] as String? ?? '',
      tonality: json['tonality'] as String? ?? '',
      category: json['category'] as String? ?? '',
      tags: [
        for (final tag in json['tags'] as List<dynamic>? ?? const [])
          if (tag is String && tag.trim().isNotEmpty) tag.trim(),
      ],
      lyrics: json['lyrics'] as String? ?? '',
      materials: _parseMaterials(
        json['materials'] as List<dynamic>? ?? const [],
        praiseId: id,
      ),
    );
  }

  /// Um material corrompido não derruba o louvor (mesma regra C.8 de
  /// `PraiseDetailDto._parseMaterials`).
  static List<ColdigomCatalogMaterialDto> _parseMaterials(
    List<dynamic> raw, {
    required String praiseId,
  }) {
    final materials = <ColdigomCatalogMaterialDto>[];
    for (final item in raw) {
      try {
        materials.add(
          ColdigomCatalogMaterialDto.fromJson(
            item as Map<String, dynamic>,
            praiseId: praiseId,
          ),
        );
      } on Object catch (error) {
        debugPrint('[coldigom] material do catálogo descartado: $error');
      }
    }
    return materials;
  }
}

/// Corpo de `GET /api/plpcg/catalog`.
class ColdigomCatalogDto {
  const ColdigomCatalogDto({
    required this.generatedAt,
    required this.kindNames,
    required this.praises,
  });

  final String generatedAt;

  /// `kindId → nome` — o rótulo das tiles do sheet (`materialKindName`).
  final Map<String, String> kindNames;
  final List<ColdigomCatalogPraiseDto> praises;

  factory ColdigomCatalogDto.fromJson(Map<String, dynamic> json) {
    final kinds = <String, String>{};
    // `kinds`/`praises` de tipo errado (não-lista) não derruba o catálogo —
    // mesma tolerância C.8 já aplicada item a item abaixo.
    final rawKinds = json['kinds'];
    for (final item in rawKinds is List<dynamic> ? rawKinds : const []) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final name = item['name'];
      if (id is String && name is String) kinds[id] = name;
    }
    final praises = <ColdigomCatalogPraiseDto>[];
    final rawPraises = json['praises'];
    for (final item in rawPraises is List<dynamic> ? rawPraises : const []) {
      try {
        praises.add(
          ColdigomCatalogPraiseDto.fromJson(item as Map<String, dynamic>),
        );
      } on Object catch (error) {
        debugPrint('[coldigom] praise do catálogo descartado: $error');
      }
    }
    return ColdigomCatalogDto(
      generatedAt: json['generatedAt'] as String? ?? '',
      kindNames: Map.unmodifiable(kinds),
      praises: List.unmodifiable(praises),
    );
  }
}
