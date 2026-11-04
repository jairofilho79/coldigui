import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';

import '../../../material_kind_prefs/domain/entities/material_favorite_policy.dart';
import '../../../../core/utils/material_id_kind.dart';

/// Material preferido para o "+" sempre visível do card (C5).
///
/// Com [rank] não vazio (favoritos da conta — D9/D-extra), devolve o
/// material adicionável do grupo cujo `materialKindId` tem a melhor posição
/// no rank (favorito nº 1 antes do nº 2, etc.), desempatando pelo formato
/// em [preferredTypes]. Letra usa `type:lyrics`; áudio e YouTube não
/// participam dos favoritos. Sem favorito presente no grupo (ou `rank` vazio,
/// ex.: deslogado), cai no fallback fixo: PDF principal
/// ([LouvorGroup.primaryLouvor]) se existir; senão o único áudio do grupo;
/// senão o primeiro extra que [canAddMaterialToPlaylist] aceita (incluindo
/// cifras, gestos e letras). `null` quando nada do
/// grupo é adicionável — ex.: só YouTube.
CatalogMaterial? preferredMaterialForGroup(
  LouvorGroup group, {
  Map<String, int> rank = const {},
  Map<String, String> preferredTypes = const {},
}) {
  if (rank.isNotEmpty) {
    final favorite = bestFavoriteMaterialForGroup(
      group,
      rank,
      preferredTypes: preferredTypes,
      where: canAddMaterialToPlaylist,
    );
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

/// Material do grupo que passa em [where] com a melhor posição em [rank]
/// (favorito nº 1 antes do nº 2…), ou `null` se nenhum deles é favorito.
///
/// É o núcleo de [preferredMaterialForGroup] e do material próprio de quem
/// segue uma lista ao vivo (que só troca partitura por partitura).
/// Formato preferido ausente mantém o primeiro material elegível do kind.
CatalogMaterial? bestFavoriteMaterialForGroup(
  LouvorGroup group,
  Map<String, int> rank, {
  required bool Function(CatalogMaterial material) where,
  Map<String, String> preferredTypes = const {},
}) {
  CatalogMaterial? best;
  var bestPosition = 1 << 30;
  var bestMatchesType = false;
  for (final material in group.materials) {
    if (!where(material)) continue;
    final kindId = favoriteMaterialKindId(
      material.kind,
      material.materialKindId,
    );
    final position = kindId == null ? null : rank[kindId];
    if (position == null) continue;
    final preferred = preferredTypes[kindId];
    final matchesType =
        preferred != null && materialKindOfRawType(preferred) == material.kind;
    if (position > bestPosition ||
        (position == bestPosition && (bestMatchesType || !matchesType))) {
      continue;
    }
    bestPosition = position;
    bestMatchesType = matchesType;
    best = material;
  }
  return best;
}
