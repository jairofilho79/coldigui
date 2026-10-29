import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';

/// Material preferido para o "+" sempre visível do card (C5).
///
/// Com [rank] não vazio (favoritos da conta — D9/D-extra), devolve o
/// material adicionável do grupo cujo `materialKindId` tem a melhor posição
/// no rank (favorito nº 1 antes do nº 2, etc.) — o "primeiro favorito
/// disponível" no louvor. Sem favorito presente no grupo (ou `rank` vazio,
/// ex.: deslogado), cai no fallback fixo: PDF principal
/// ([LouvorGroup.primaryLouvor]) se existir; senão o único áudio do grupo;
/// senão o primeiro extra que [canAddMaterialToPlaylist] aceita (cifra/
/// YouTube não têm entrada própria na lista ativa). `null` quando nada do
/// grupo é adicionável — ex.: só YouTube.
CatalogMaterial? preferredMaterialForGroup(
  LouvorGroup group, {
  Map<String, int> rank = const {},
}) {
  if (rank.isNotEmpty) {
    final favorite = _bestFavoriteMaterial(group, rank);
    if (favorite != null) return favorite;
  }

  final primary = group.primaryLouvor;
  if (primary != null) return PdfMaterial(primary);

  final audioTracks = group.audioTracks;
  if (audioTracks.length == 1) return AudioMaterial(audioTracks.first);

  for (final material in group.extras) {
    if (canAddMaterialToPlaylist(material)) return material;
  }
  return null;
}

/// Material adicionável do grupo com a melhor posição em [rank], ou `null`
/// quando nenhum dos materiais adicionáveis (PDF/áudio) do grupo é favorito.
CatalogMaterial? _bestFavoriteMaterial(
  LouvorGroup group,
  Map<String, int> rank,
) => bestFavoriteMaterialForGroup(group, rank, where: canAddMaterialToPlaylist);

/// Material do grupo que passa em [where] com a melhor posição em [rank]
/// (favorito nº 1 antes do nº 2…), ou `null` se nenhum deles é favorito.
///
/// É o núcleo de [preferredMaterialForGroup] e do material próprio de quem
/// segue uma lista ao vivo (que só troca partitura por partitura).
CatalogMaterial? bestFavoriteMaterialForGroup(
  LouvorGroup group,
  Map<String, int> rank, {
  required bool Function(CatalogMaterial material) where,
}) {
  CatalogMaterial? best;
  var bestPosition = 1 << 30;
  for (final material in group.materials) {
    if (!where(material)) continue;
    final kindId = material.materialKindId;
    final position = kindId == null ? null : rank[kindId];
    if (position == null || position >= bestPosition) continue;
    bestPosition = position;
    best = material;
  }
  return best;
}
