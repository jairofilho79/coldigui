import '../../../catalog/domain/constants/catalog_materials.dart';

/// Mapeia [Louvor.categoria] para chips de material da UI offline (UC-10).
abstract final class OfflineMaterialResolver {
  /// Retorna o material de UI (`Partitura`, `Cifra`, `Gestos em Gravura`) ou `null`.
  static String? toUiMaterial(String categoria) {
    if (categoria == CatalogMaterials.partitura) {
      return CatalogMaterials.partitura;
    }
    if (categoria == CatalogMaterials.gestosEmGravura) {
      return CatalogMaterials.gestosEmGravura;
    }
    if (categoria == CatalogMaterials.cifra ||
        categoria == CatalogMaterials.cifraNivelI ||
        categoria == CatalogMaterials.cifraNivelII) {
      return CatalogMaterials.cifra;
    }
    return null;
  }
}
