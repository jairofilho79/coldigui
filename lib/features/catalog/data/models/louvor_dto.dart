import '../../domain/entities/louvor.dart';

/// DTO de serialização do catálogo remoto → entidade [Louvor].
///
/// Shape idêntico ao JSON de `/api/plpcg/manifest` (coldigom) —
/// `praiseId`/`materialId` presentes; o JSON legado do Worker
/// `plpcg-catalog` os omitia.
class LouvorDto {
  const LouvorDto({
    required this.nome,
    required this.numero,
    required this.categoria,
    required this.classificacao,
    required this.pdf,
    required this.pdfId,
    this.groupId = '',
    this.shortId,
    this.praiseId,
    this.materialId,
  });

  final String nome;
  final String numero;
  final String categoria;
  final String classificacao;
  final String pdf;
  final String pdfId;

  /// Agrupamento lógico do louvor; vem do D1 ou do manifest agrupado.
  final String groupId;

  /// Id curto de share (hex minúsculo, **string** — `"0000"` é válido).
  /// `null` no catálogo antigo ou no material ainda não atribuído.
  final String? shortId;

  /// Id do praise coldigom; `null` no catálogo antigo.
  final String? praiseId;

  /// Id do material coldigom; `null` no catálogo antigo.
  final String? materialId;

  /// Parse do JSON do catálogo (`/api/catalog/louvores` ou manifest legado).
  factory LouvorDto.fromJson(Map<String, dynamic> json) => LouvorDto(
        nome: json['nome'] as String,
        numero: json['numero'] as String,
        categoria: json['categoria'] as String,
        classificacao: json['classificacao'] as String,
        pdf: json['pdf'] as String,
        pdfId: json['pdfId'] as String,
        groupId: json['groupId'] as String? ?? '',
        shortId: json['shortId'] is String ? json['shortId'] as String : null,
        praiseId: _nonEmptyString(json['praiseId']),
        materialId: _nonEmptyString(json['materialId']),
      );

  /// Converte para entidade de domínio com tokens de busca pré-computados.
  Louvor toEntity() => Louvor.fromManifest(
        nome: nome,
        numero: numero,
        categoria: categoria,
        classificacao: classificacao,
        pdf: pdf,
        pdfId: pdfId,
        groupId: groupId,
        shortId: shortId,
        praiseId: praiseId,
        materialId: materialId,
      );
}

/// `String` não vazia (após `trim`) ou `null` — o manifest só deve mandar
/// string, mas o parser não quebra com outro tipo.
String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
