import '../../../../core/utils/material_id_kind.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvor_data_source.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/ports/catalog_source.dart';
import '../../domain/utils/find_louvor_by_pdf_id.dart';

/// [CatalogSource] do acervo PLPCG — o manifest já carregado, só PDFs.
///
/// O manifest não tem cifra, áudio nem YouTube: [materialById] só resolve ids
/// de PDF, e os outros tipos caem para a fonte Coldigom no
/// `CompositeCatalogSource`.
class PlpcgCatalogSource implements CatalogSource {
  const PlpcgCatalogSource({this.catalog});

  /// Louvores do manifest; `null` enquanto o manifest não chegou.
  final List<Louvor>? catalog;

  /// PDFs PLPCG de [groupId], na ordem do manifest.
  List<Louvor> louvoresOfGroup(String groupId) {
    if (groupId.isEmpty) return const [];
    return [
      for (final louvor in catalog ?? const <Louvor>[])
        if (louvor.source == LouvorDataSource.plpcg &&
            louvor.effectiveGroupId == groupId)
          louvor,
    ];
  }

  /// Versão síncrona de [groupById] — o manifest já está em memória.
  LouvorGroup? findGroupById(String groupId) {
    final items = louvoresOfGroup(groupId);
    if (items.isEmpty) return null;
    return LouvorGroup.fromLouvores(items).first;
  }

  /// Versão síncrona de [materialById].
  CatalogMaterial? findMaterialById(String materialId) {
    if (materialIdKindOf(materialId) != MaterialKind.pdf) return null;
    final louvor = findLouvorByPdfId(catalog, materialId);
    return louvor == null ? null : PdfMaterial(louvor);
  }

  /// Versão síncrona de [groupForMaterial].
  LouvorGroup? findGroupForMaterial(String materialId) {
    final louvor = findLouvorByPdfId(catalog, materialId);
    if (louvor == null) return null;
    return findGroupById(louvor.effectiveGroupId);
  }

  @override
  Future<LouvorGroup?> groupById(String groupId) async =>
      findGroupById(groupId);

  @override
  Future<CatalogMaterial?> materialById(String materialId) async =>
      findMaterialById(materialId);

  @override
  Future<LouvorGroup?> groupForMaterial(String materialId) async =>
      findGroupForMaterial(materialId);
}
