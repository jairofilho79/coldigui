import '../../../../core/utils/louvor_search_tokens.dart';
import 'louvor_numero_normalizer.dart';

/// Geração de [Louvor.groupId] — espelha `scripts/assign_louvor_group_ids.py`.
///
/// [compute] usa [LouvorNumeroNormalizer] (pad-left 3) no prefixo numérico.
abstract final class LouvorGroupId {
  /// Retorna `groupId` do D1/manifest ou calcula `f(numeroPad3, nomeNormalizado)`.
  static String effective(
      {required String groupId, required String numero, required String nome}) {
    final trimmed = groupId.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return compute(numero: numero, nome: nome);
  }

  /// `{numeroPad3}:slug(nomeNorm)` ou `avulso:slug(nomeNorm)` quando sem número.
  ///
  /// Ex.: `"3"` + `"Clamo a ti"` → `"003:clamo-a-ti"`.
  static String compute({required String numero, required String nome}) {
    final nomeNorm = LouvorSearchTokens.normalize(nome.trim());
    final num = LouvorNumeroNormalizer.normalize(numero);
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
