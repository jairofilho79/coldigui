import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../coldigom/data/sources/coldigom_catalog_source.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvor_data_source.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/entities/manifest_material_aliases.dart';
import '../../domain/ports/catalog_source.dart';
import '../../domain/ports/search_cancellation.dart';
import 'plpcg_catalog_source.dart';

/// [CatalogSource] único — manifest + caches Coldigom fundidos **por praise**.
///
/// Um louvor lógico é um praise do coldigom. Quando o praise está no manifest
/// ([aliases]), o grupo sai daqui com os PDFs legados do manifest (ids e
/// `shortId` originais) mais o que os caches Coldigom têm além deles
/// (PDFs não cobertos, áudio, cifra, gestos, letra, YouTube, meta). Praises
/// fora do manifest continuam a vir só do cache Coldigom; antes do primeiro
/// sync pós-migração ([aliases] vazio) tudo se comporta como no modo dual.
///
/// Os métodos síncronos existem para quem decide durante o build (barra do
/// carrossel) — os caches e o manifest já estão em memória.
class CompositeCatalogSource implements CatalogSource {
  const CompositeCatalogSource({
    required this.plpcg,
    required this.coldigom,
    this.aliases = ManifestMaterialAliases.empty,
  });

  final PlpcgCatalogSource plpcg;
  final ColdigomCatalogSource coldigom;
  final ManifestMaterialAliases aliases;

  /// Entrada do manifest para [materialId] — id legado direto ou id Coldigom
  /// de material coberto (alias). `null` para cifra/áudio/gesto/letra e para
  /// PDFs fora do manifest.
  Louvor? _manifestLouvorFor(String materialId) {
    final legacyId = aliases.legacyPdfIdByColdigomPdfId[materialId] ?? materialId;
    final material = plpcg.findMaterialById(legacyId);
    return material is PdfMaterial ? material.louvor : null;
  }

  /// Grupo do praise [praiseId] do manifest, fundido com os caches Coldigom.
  LouvorGroup? _fusedGroup(String praiseId) {
    final manifestPdfs = plpcg.louvoresOfGroup(praiseId);
    final parts = coldigom.partsOfGroup(praiseId);
    final extraPdfs = [
      for (final louvor in parts.pdfs)
        if (!aliases.coversColdigomPdf(louvor.pdfId)) louvor,
    ];
    if (manifestPdfs.isEmpty && parts.isEmpty) return null;
    final groups = LouvorGroup.fromLouvores(
      [...manifestPdfs, ...extraPdfs],
      audioTracks: parts.audioTracks,
      chordMaterials: parts.chords,
      gestureMaterials: parts.gestures,
      youtubeMaterials: parts.youtube,
      lyricsByGroupId: parts.lyrics == null ? null : {praiseId: parts.lyrics!},
      coldigomMetaByGroupId: parts.meta == null ? null : {praiseId: parts.meta!},
    );
    return groups.isEmpty ? null : groups.first;
  }

  /// Grupo remoto [group] (página de busca) refeito com os PDFs do manifest.
  ///
  /// Não lê o cache Coldigom: a página acabou de gravar nele e esta instância
  /// ainda tem os mapas antigos — os extras vêm do próprio grupo remoto.
  LouvorGroup _fuseRemoteGroup(LouvorGroup group) {
    final praiseId = group.groupId;
    final remotePdfs = [
      for (final section in group.sections)
        for (final entry in section.materials)
          if (!aliases.coversColdigomPdf(entry.pdfId)) entry.louvor,
    ];
    final pdfs = [...plpcg.louvoresOfGroup(praiseId), ...remotePdfs];
    // Sem PDF nenhum (praise só de áudio/cifra cujo manifest ainda não tem a
    // entrada) não há de onde tirar número/nome: o grupo remoto fica como está.
    final groups = LouvorGroup.fromLouvores(pdfs);
    if (groups.isEmpty) return group;
    final base = groups.first;
    return LouvorGroup(
      groupId: praiseId,
      numero: base.numero,
      nome: base.nome,
      sections: base.sections,
      extras: group.extras,
      coldigomMeta: group.coldigomMeta,
    );
  }

  /// Versão síncrona de [groupById]: praise do manifest → fundido; senão
  /// cache Coldigom; senão (pré-sync) manifest pelo `groupId` legado.
  LouvorGroup? findGroupById(String groupId) {
    if (aliases.coversPraise(groupId)) return _fusedGroup(groupId);
    return coldigom.findGroupById(groupId) ?? plpcg.findGroupById(groupId);
  }

  /// Versão síncrona de [groupForMaterial], **sem** a regra "material único
  /// → `null`" (quem quer esconder o grupo sem alternativa aplica o corte).
  LouvorGroup? findGroupForMaterial(String materialId) {
    final manifestLouvor = _manifestLouvorFor(materialId);
    if (manifestLouvor != null) {
      return findGroupById(manifestLouvor.effectiveGroupId);
    }
    final isColdigomId =
        louvorDataSourceFromPdfId(materialId) == LouvorDataSource.coldigom ||
        materialIdKindOf(materialId) == MaterialKind.lyrics;
    if (!isColdigomId) return plpcg.findGroupForMaterial(materialId);
    final group = coldigom.findGroupForMaterial(materialId);
    if (group == null) return null;
    return aliases.coversPraise(group.groupId) ? _fusedGroup(group.groupId) : group;
  }

  /// Versão síncrona de [materialById]: legado → manifest; Coldigom → cache,
  /// e sem cache o alias devolve o [PdfMaterial] do manifest (sem rede).
  CatalogMaterial? findMaterialById(String materialId) {
    if (louvorDataSourceFromPdfId(materialId) != LouvorDataSource.coldigom) {
      return plpcg.findMaterialById(materialId);
    }
    final cached = coldigom.findMaterialById(materialId);
    if (cached != null) return cached;
    final aliased = _manifestLouvorFor(materialId);
    return aliased == null ? null : PdfMaterial(aliased);
  }

  @override
  Future<LouvorGroup?> groupById(String groupId) async => findGroupById(groupId);

  @override
  Future<CatalogMaterial?> materialById(String materialId) async =>
      findMaterialById(materialId);

  @override
  Future<LouvorGroup?> groupForMaterial(String materialId) async =>
      findGroupForMaterial(materialId);

  /// PLPCG primeiro (ranking UC-01 intacto), Coldigom depois sem os praises
  /// que o manifest já cobre (O16 + spec D5). Não funde: custo por tecla.
  @override
  List<LouvorGroup> searchLocal(CatalogQuery query) => mergeLocalSearchResults(
    plpcg: plpcg.searchLocal(query),
    coldigom: coldigom.searchLocal(query),
    manifestPraiseIds: aliases.praiseIds,
  );

  /// Página Coldigom; cada grupo cujo praise está no manifest sai fundido —
  /// é assim que a página remota **valida** a lista local em vez de anexar
  /// uma cópia (spec §5.4).
  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) async {
    final page = await coldigom.search(query, cancellation: cancellation);
    if (aliases.isEmpty || page.groups.isEmpty) return page;
    return CatalogSearchPage(
      groups: [
        for (final group in page.groups)
          aliases.coversPraise(group.groupId) ? _fuseRemoteGroup(group) : group,
      ],
      page: page.page,
      hasNextPage: page.hasNextPage,
    );
  }
}

/// Lista local da Home: [plpcg] na ordem do ranking, depois os grupos
/// [coldigom] cujo praise **não** está em [manifestPraiseIds].
///
/// Partilhada por `CompositeCatalogSource.searchLocal` e
/// `homeLocalSearchProvider` (que compõe as fontes por conta própria para o
/// índice PLPCG não ser arrastado pelos merges Coldigom).
List<LouvorGroup> mergeLocalSearchResults({
  required List<LouvorGroup> plpcg,
  required List<LouvorGroup> coldigom,
  required Set<String> manifestPraiseIds,
}) => [
  ...plpcg,
  for (final group in coldigom)
    if (!manifestPraiseIds.contains(group.groupId)) group,
];
