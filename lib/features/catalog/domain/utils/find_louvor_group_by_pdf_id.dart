import '../../../coldigom/data/sources/coldigom_catalog_source.dart';
import '../../data/sources/plpcg_catalog_source.dart';
import '../entities/louvor.dart';
import '../entities/louvor_group.dart';

/// Grupo lógico PLPCG do louvor com [pdfId], ou `null` se órfão ou único.
///
/// A variante que também olhava o cache Coldigom virou
/// `CompositeCatalogSource.groupForMaterial`: o despacho entre os dois acervos
/// vive na porta, não aqui.
LouvorGroup? findLouvorGroupByPdfId(List<Louvor>? catalog, String pdfId) {
  final group = PlpcgCatalogSource(
    catalog: catalog,
  ).findGroupForMaterial(pdfId);
  if (group == null || group.totalMaterials <= 1) return null;
  return group;
}

/// Grupo para o botão layers da barra: inclui áudios/cifras do cache e aceita
/// 1 PDF se [LouvorGroup.totalMaterials] > 1.
///
/// Precedência quando os dois ids chegam (face de áudio): manda a faixa
/// tocando ([audioId]) se o [pdfId] for de **outro** louvor — o chip focado no
/// carousel não tem relação com o que está tocando. Com os dois no mesmo
/// grupo o [pdfId] segue mandando.
///
/// Síncrono (a UI decide se mostra o botão durante o build): usa os métodos
/// síncronos da fonte coldigom, que só lê memória.
LouvorGroup? findSwapMaterialGroup({
  String? pdfId,
  String? audioId,
  required ColdigomCatalogSource source,
}) {
  final playingTrack = (audioId == null || audioId.isEmpty)
      ? null
      : source.audioTracks[audioId];
  final playingGroupId =
      (playingTrack == null || playingTrack.groupId.isEmpty)
      ? null
      : playingTrack.groupId;

  final materialGroup = (pdfId == null || pdfId.isEmpty)
      ? null
      : source.findGroupForMaterial(pdfId);

  if (playingGroupId != null && playingGroupId != materialGroup?.groupId) {
    return _multipleOnly(source.findGroupById(playingGroupId));
  }
  if (materialGroup != null) return _multipleOnly(materialGroup);
  if (playingGroupId != null) {
    return _multipleOnly(source.findGroupById(playingGroupId));
  }
  return null;
}

/// Descarta o grupo que sobrou com um material só — não há o que trocar.
LouvorGroup? _multipleOnly(LouvorGroup? group) {
  if (group == null || group.totalMaterials <= 1) return null;
  return group;
}
