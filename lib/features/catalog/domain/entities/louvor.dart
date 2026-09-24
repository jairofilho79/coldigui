import '../../../../core/utils/louvor_search_tokens.dart';
import 'louvor_data_source.dart';
import '../utils/louvor_group_id.dart';
import '../utils/louvor_numero_normalizer.dart';

/// Entidade de domínio — um PDF do catálogo coldigom. [praiseId] agrupa
/// materiais do mesmo louvor (ver [LouvorGroup]). [searchTitleNorm],
/// [searchContentTokens] e [searchCompactContent] são pré-computados em
/// [Louvor.fromManifest] para a busca UC-01.
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
    this.source = LouvorDataSource.plpcg,
    this.materialKindId,
    this.praiseId,
    this.materialId,
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

  /// Origem dos metadados — PLPCG ou coldigom.
  final LouvorDataSource source;

  /// Id do `material_kind` Coldigom; `null` no acervo PLPCG.
  final String? materialKindId;

  /// Id do praise no coldigom — identidade do louvor lógico.
  final String? praiseId;

  /// Id do material no coldigom (nome do ficheiro sem extensão em
  /// `assets/praises/<praiseId>/<materialId>.pdf`). `null` como [praiseId].
  final String? materialId;

  /// Identidade do louvor lógico: [praiseId] quando existe (um card por
  /// praise, spec D3); senão o `groupId` do manifest; senão calculado.
  String get effectiveGroupId =>
      praiseId ??
      LouvorGroupId.effective(groupId: groupId, numero: numero, nome: nome);

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
    LouvorDataSource source = LouvorDataSource.plpcg,
    String? materialKindId,
    String? praiseId,
    String? materialId,
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
      source: source,
      materialKindId: materialKindId,
      praiseId: praiseId,
      materialId: materialId,
    );
  }
}
