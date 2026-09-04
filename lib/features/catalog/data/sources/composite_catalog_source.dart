import '../../../../core/utils/pdf_id_codec.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor_data_source.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/ports/catalog_source.dart';

/// [CatalogSource] dos dois acervos — despacha por id.
///
/// PLPCG e Coldigom compartilham o espaço de ids (Base64 do path do asset), e
/// só o prefixo `assets/praises/` separa os dois — é o que
/// [louvorDataSourceFromPdfId] decide, sem tocar em cache nem em rede.
class CompositeCatalogSource implements CatalogSource {
  const CompositeCatalogSource({required this.plpcg, required this.coldigom});

  final CatalogSource plpcg;
  final CatalogSource coldigom;

  /// Fonte responsável por [materialId].
  CatalogSource sourceForMaterial(String materialId) {
    return louvorDataSourceFromPdfId(materialId) == LouvorDataSource.coldigom
        ? coldigom
        : plpcg;
  }

  @override
  Future<CatalogMaterial?> materialById(String materialId) =>
      sourceForMaterial(materialId).materialById(materialId);

  @override
  Future<LouvorGroup?> groupForMaterial(String materialId) =>
      sourceForMaterial(materialId).groupForMaterial(materialId);

  /// O `groupId` não carrega a fonte (praise id no Coldigom, hash
  /// `numero+nome` no PLPCG), então tenta o manifest e cai no cache Coldigom.
  @override
  Future<LouvorGroup?> groupById(String groupId) async {
    return await plpcg.groupById(groupId) ?? await coldigom.groupById(groupId);
  }
}
