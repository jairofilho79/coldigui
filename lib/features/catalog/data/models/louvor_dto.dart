import '../../domain/entities/louvor.dart';

/// DTO de serialização do manifest remoto → entidade [Louvor].
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
  final String groupId;

  /// Parse do JSON do `louvores-manifest.json`.
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
