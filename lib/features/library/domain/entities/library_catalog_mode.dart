/// Fonte de dados da Biblioteca — exclusiva (PLPCG ou Coldigom).
enum LibraryCatalogMode {
  plpcg,
  coldigom;

  static const urlValueColdigom = 'coldigom';

  /// Serializa para query `fonte=`; [plpcg] omite (default).
  String? get urlValue =>
      this == LibraryCatalogMode.coldigom ? urlValueColdigom : null;

  static LibraryCatalogMode fromUrl(String? raw) {
    if (raw == urlValueColdigom) return LibraryCatalogMode.coldigom;
    return LibraryCatalogMode.plpcg;
  }
}
