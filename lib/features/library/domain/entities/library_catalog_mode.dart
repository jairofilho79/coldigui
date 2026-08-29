/// Fonte de dados da Biblioteca — exclusiva (PLPCG ou Coldigom).
///
/// Neste build a UI fixa [coldigom]; [plpcg] permanece no enum para código legado.
enum LibraryCatalogMode {
  plpcg,
  coldigom;

  static const urlValueColdigom = 'coldigom';

  /// Serializa para query `fonte=`; sempre coldigom neste build.
  String? get urlValue => urlValueColdigom;

  /// Default e ausência de `fonte` → coldigom.
  static LibraryCatalogMode fromUrl(String? raw) {
    if (raw == null || raw.isEmpty || raw == urlValueColdigom) {
      return LibraryCatalogMode.coldigom;
    }
    // ponytail: ignore fonte=plpcg — UI só Coldigom
    return LibraryCatalogMode.coldigom;
  }
}
