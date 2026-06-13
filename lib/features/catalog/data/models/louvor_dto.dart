import '../../domain/entities/louvor.dart';

/// DTO de serialização do catálogo remoto → entidade [Louvor].
///
/// Shape idêntico ao JSON de `/api/catalog/louvores` (Worker D1) e
/// `louvores-manifest.json` legado. [groupId] é obrigatório no D1;
/// omitido no JSON antigo → `''` (fallback via [LouvorGroupId.effective]).
class LouvorDto {
  const LouvorDto({
    required this.nome,
    required this.numero,
    required this.categoria,
    required this.classificacao,
    required this.pdf,
    required this.pdfId,
    this.groupId = '',
  });

  final String nome;
  final String numero;
  final String categoria;
  final String classificacao;
  final String pdf;
  final String pdfId;

  /// Agrupamento lógico do louvor; vem do D1 ou do manifest agrupado.
  final String groupId;

  /// Parse do JSON do catálogo (`/api/catalog/louvores` ou manifest legado).
  factory LouvorDto.fromJson(Map<String, dynamic> json) => LouvorDto(
        nome: json['nome'] as String,
        numero: json['numero'] as String,
        categoria: json['categoria'] as String,
        classificacao: json['classificacao'] as String,
        pdf: json['pdf'] as String,
        pdfId: json['pdfId'] as String,
        groupId: json['groupId'] as String? ?? '',
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
      );
}
