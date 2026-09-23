import '../entities/louvor.dart';

/// Classificação/arranjo do manifesto (`ColAdultos (Especial)`) → rótulos.
///
/// Serve à exibição — o nome das secções de material ([materialSectionLabel])
/// e o chip do carrossel — e ao manifesto ([collectAvailableArranjos]). Os
/// filtros do catálogo já não usam classificação nem arranjo: são tom, ritmo,
/// categoria, tags e tipo de material, do índice Coldigom (spec fim-fonte
/// §2.2).
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

  /// Rótulo da seção na sublista de materiais ([LouvorMaterialSection]).
  ///
  /// Arranjo especial entre parênteses → só o texto do arranjo; senão
  /// [displayLabel] ou a classificação completa (ex.: casamentos avulsos).
  static String materialSectionLabel(String classificacao) {
    final special = specialArrangement(classificacao);
    if (special != specialArrangementPadrao) return special;
    final base = classificacao.trim();
    if (base.startsWith('Coletânea ')) return base;
    return displayLabel(classificacao);
  }

  /// Classificações base únicas de [louvores] — alimenta
  /// `LouvoresManifest.availableArranjos`.
  static Set<String> collectAvailableArranjos(Iterable<Louvor> louvores) {
    return louvores.map((l) => baseClassification(l.classificacao)).toSet();
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
}
