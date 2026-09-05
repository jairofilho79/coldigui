import '../../../../core/utils/material_id_kind.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvor_data_source.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/ports/catalog_source.dart';
import '../../domain/ports/search_cancellation.dart';
import '../../domain/search/plpcg_search_index.dart';
import '../../domain/utils/find_louvor_by_pdf_id.dart';

/// [CatalogSource] do acervo PLPCG — o manifest já carregado, só PDFs.
///
/// O manifest não tem cifra, áudio nem YouTube: [materialById] só resolve ids
/// de PDF, e os outros tipos caem para a fonte Coldigom no
/// `CompositeCatalogSource`.
///
/// É a fonte **local**: [searchLocal] responde do [index] no mesmo frame e
/// [search] nunca toca a rede.
class PlpcgCatalogSource implements CatalogSource {
  const PlpcgCatalogSource({this.catalog, this.index = PlpcgSearchIndex.empty});

  /// Louvores do manifest; `null` enquanto o manifest não chegou.
  final List<Louvor>? catalog;

  /// Índice de busca do mesmo manifest — construído uma vez pelo provider.
  final PlpcgSearchIndex index;

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

  @override
  List<LouvorGroup> searchLocal(CatalogQuery query) =>
      runPlpcgSearchPipeline(index, query);

  /// O manifest é local: não existe página remota a buscar.
  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) async => CatalogSearchPage.empty;
}
