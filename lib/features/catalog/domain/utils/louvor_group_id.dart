import '../../../../core/utils/louvor_search_tokens.dart';

/// Geração de [Louvor.groupId] — espelha `scripts/assign_louvor_group_ids.py`.
abstract final class LouvorGroupId {
  /// Retorna `groupId` do manifest ou calcula `f(numero, nomeNormalizado)`.
  static String effective(
      {required String groupId, required String numero, required String nome}) {
    final trimmed = groupId.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return compute(numero: numero, nome: nome);
  }

  /// `numero:slug(nomeNorm)` ou `avulso:slug(nomeNorm)` quando sem número.
  static String compute({required String numero, required String nome}) {
    final nomeNorm = LouvorSearchTokens.normalize(nome.trim());
    final num = numero.trim();
    if (num.isNotEmpty) {
      return '$num:${_slug(nomeNorm)}';
    }
    return 'avulso:${_slug(nomeNorm)}';
  }

  static String _slug(String normalized) {
    final slug = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'sem-titulo' : slug;
  }
}
