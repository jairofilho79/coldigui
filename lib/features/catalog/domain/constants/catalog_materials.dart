/// Materiais de filtro UC-02 — espelha `filters.js` do PWA.
///
/// Contrato URL: param [UrlSyncParams.materiais] (CSV). Valor omitido quando
/// [defaultSelected] está ativo. "Cifra" na UI expande para
/// [cifraNivelI] e [cifraNivelII] em [Louvor.categoria].
abstract final class CatalogMaterials {
  /// Material partitura.
  static const String partitura = 'Partitura';

  /// Chip UI "Cifra" — expande para níveis I e II.
  static const String cifra = 'Cifra';

  /// Valor de [Louvor.categoria] para cifra nível I.
  static const String cifraNivelI = 'Cifra nível I';

  /// Valor de [Louvor.categoria] para cifra nível II.
  static const String cifraNivelII = 'Cifra nível II';

  /// Material gestos em gravura.
  static const String gestosEmGravura = 'Gestos em Gravura';

  /// Chips exibidos na UI ([CategoryFilters]).
  static const List<String> uiMaterials = [
    partitura,
    cifra,
    gestosEmGravura,
  ];

  /// Seleção padrão — todos os materiais (omitido da URL).
  static const Set<String> defaultSelected = {
    partitura,
    cifra,
    gestosEmGravura,
  };

  /// "Cifra" expande para incluir níveis I e II (MAPEAMENTO §4.1).
  static Set<String> expandMaterial(String material) {
    if (material == cifra) {
      return {cifra, cifraNivelI, cifraNivelII};
    }
    return {material};
  }

  /// Expande todos os materiais selecionados para valores de `Louvor.categoria`.
  static Set<String> expandMaterials(Iterable<String> materials) {
    return materials.expand(expandMaterial).toSet();
  }

  /// `true` quando a seleção equivale ao padrão (todos os materiais).
  static bool isDefaultSelection(Set<String> selected) {
    return selected.length == defaultSelected.length &&
        defaultSelected.every(selected.contains);
  }

  /// Parse CSV da URL `materiais=`; vazio → padrão.
  static Set<String> parseFromUrl(String? csv) {
    if (csv == null || csv.trim().isEmpty) {
      return Set<String>.from(defaultSelected);
    }
    final parsed = csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => uiMaterials.contains(s))
        .toSet();
    return parsed.isEmpty ? Set<String>.from(defaultSelected) : parsed;
  }

  /// Serializa para URL; retorna `null` se seleção padrão (omitir param).
  static String? serializeForUrl(Set<String> selected) {
    if (isDefaultSelection(selected)) return null;
    return uiMaterials.where(selected.contains).join(',');
  }
}
