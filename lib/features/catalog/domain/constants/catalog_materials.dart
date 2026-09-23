/// Materiais da secção PLPCG do /offline (categorias do manifesto) — sai com
/// ela no plano 3.
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

  /// Chips da secção PLPCG do /offline.
  static const List<String> uiMaterials = [
    partitura,
    cifra,
    gestosEmGravura,
  ];

  /// Seleção padrão — todos os materiais.
  static const Set<String> defaultSelected = {
    partitura,
    cifra,
    gestosEmGravura,
  };
}
