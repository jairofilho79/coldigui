import '../../../../core/utils/louvor_search_tokens.dart';
import '../utils/louvor_group_id.dart';
import '../utils/louvor_numero_normalizer.dart';

/// Entidade de domínio — louvor do manifest PLPCG.
///
/// Campos espelham o JSON de `louvores-manifest.json`.
/// [searchTitleNorm], [searchContentTokens] e [searchCompactContent] são
/// pré-computados na criação via [Louvor.fromManifest] para busca UC-01.
/// [groupId] agrupa materiais do mesmo louvor (ver [LouvorGroup]).
class Louvor {
  const Louvor({
    required this.nome,
    required this.numero,
    required this.categoria,
    required this.classificacao,
    required this.pdf,
    required this.pdfId,
    required this.groupId,
    required this.searchTitleNorm,
    required this.searchContentTokens,
    required this.searchCompactContent,
  });

  /// Título do louvor (manifest `nome`).
  final String nome;

  /// Número do louvor; usado para match exato na busca UC-01.
  final String numero;

  /// Material: Partitura, Cifra, Gestos em Gravura, etc.
  final String categoria;

  /// Classificação normalizada (ex.: ColAdultos).
  final String classificacao;

  /// Nome do arquivo PDF no manifest.
  final String pdf;

  /// Identificador único — Base64 UTF-8 URL-safe do caminho relativo.
  final String pdfId;

  /// Agrupamento lógico do louvor (D1 ou manifest); vazio → [LouvorGroupId.effective].
  final String groupId;

  /// Título normalizado ([LouvorSearchTokens.normalize]) para busca.
  final String searchTitleNorm;

  /// Tokens de título + número pré-computados para filtro UC-01.
  final List<String> searchContentTokens;

  /// Título compacto (sem separadores) para match de queries como "buscarmeeis".
  final String searchCompactContent;

  /// `groupId` efetivo (manifest ou calculado).
  String get effectiveGroupId => LouvorGroupId.effective(
        groupId: groupId,
        numero: numero,
        nome: nome,
      );

  /// Cria [Louvor] a partir do manifest com campos de busca pré-computados.
  ///
  /// [numero] é normalizado via [LouvorNumeroNormalizer] (pad-left 3 dígitos).
  factory Louvor.fromManifest({
    required String nome,
    required String numero,
    required String categoria,
    required String classificacao,
    required String pdf,
    required String pdfId,
    String groupId = '',
  }) {
    final normalizedNumero = LouvorNumeroNormalizer.normalize(numero);
    final searchTitleNorm = LouvorSearchTokens.normalize(nome);
    final titleTokens = LouvorSearchTokens.tokenize(nome);
    final searchCompactContent = LouvorSearchTokens.compact(nome);
    final numeroToken = LouvorSearchTokens.normalize(normalizedNumero);
    final tokens = <String>{...titleTokens};
    if (numeroToken.isNotEmpty) {
      tokens.add(numeroToken);
    }

    return Louvor(
      nome: nome,
      numero: normalizedNumero,
      categoria: categoria,
      classificacao: classificacao,
      pdf: pdf,
      pdfId: pdfId,
      groupId: groupId,
      searchTitleNorm: searchTitleNorm,
      searchContentTokens: tokens.toList(),
      searchCompactContent: searchCompactContent,
    );
  }
}
