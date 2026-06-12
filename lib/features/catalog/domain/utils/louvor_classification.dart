/// Utilitários de classificação/arranjo para filtros UC-02 e UC-03.
///
/// Contrato URL: param [UrlSyncParams.arranjo] (CSV de classificações base);
/// [UrlSyncParams.arranjoEspecial] (CSV de arranjos especiais).
/// Valor omitido quando nenhum filtro está selecionado.
abstract final class LouvorClassification {
  /// Rótulo quando [classificacao] não contém parênteses (UC-03).
  static const String specialArrangementPadrao = 'Padrão';

  /// Rótulo amigável para exibição em chips e UI.
  ///
  /// Ex.: `ColCIAs` → `Coletânea CIAs`; `ColAdultos (Especial)` → `Coletânea Adultos`.
  static String displayLabel(String classificacao) {
    final base = baseClassification(classificacao);
    // Código manifest (`ColAdultos`), não o rótulo já expandido (`Coletânea …`).
    if (RegExp(r'^Col[A-Z]').hasMatch(base)) {
      return 'Coletânea ${base.substring(3)}';
    }
    return base;
  }

  /// Extrai classificação base antes de parênteses.
  ///
  /// Ex.: `ColAdultos (Arranjo X)` → `ColAdultos`.
  static String baseClassification(String classificacao) {
    final trimmed = classificacao.trim();
    final parenIndex = trimmed.indexOf('(');
    if (parenIndex == -1) return trimmed;
    return trimmed.substring(0, parenIndex).trim();
  }

  /// Parse CSV da URL `arranjo=`; vazio → sem filtro (todos).
  static Set<String> parseArranjosFromUrl(String? csv) {
    if (csv == null || csv.trim().isEmpty) return {};
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  /// Serializa arranjos selecionados; vazio → omitir param.
  static String? serializeArranjosForUrl(Set<String> selected) {
    if (selected.isEmpty) return null;
    return selected.join(',');
  }

  /// Extrai arranjo especial — texto entre `(` e `)`.
  ///
  /// Ex.: `ColAdultos (Especial)` → `Especial`. Sem parênteses → [specialArrangementPadrao].
  static String specialArrangement(String classificacao) {
    final trimmed = classificacao.trim();
    final openIndex = trimmed.indexOf('(');
    if (openIndex == -1) return specialArrangementPadrao;

    final closeIndex = trimmed.indexOf(')', openIndex + 1);
    if (closeIndex == -1) return specialArrangementPadrao;

    final special = trimmed.substring(openIndex + 1, closeIndex).trim();
    return special.isEmpty ? specialArrangementPadrao : special;
  }

  /// Parse CSV da URL `arranjoEspecial=`; vazio → sem filtro (todos).
  static Set<String> parseSpecialArrangementsFromUrl(String? csv) {
    if (csv == null || csv.trim().isEmpty) return {};
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  /// Serializa arranjos especiais selecionados; vazio → omitir param.
  static String? serializeSpecialArrangementsForUrl(Set<String> selected) {
    if (selected.isEmpty) return null;
    return selected.join(',');
  }
}
