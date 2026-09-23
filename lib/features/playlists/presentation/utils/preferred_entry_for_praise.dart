import '../../../catalog/presentation/utils/preferred_material_for_group.dart';
import '../../../coldigom/domain/search/coldigom_search_index.dart';
import '../../domain/entities/playlist_entry.dart';

/// Entrada que o import de um link por praise grava para [praiseShortId]
/// (spec fim-fonte-plpcg §4.3). O material vem de [preferredMaterialForGroup]
/// com o [rank] de favoritos — a mesma escolha do «+» do card. `null` quando
/// o token não está no [index] ou o praise não tem nada adicionável (ex.: só
/// cifra ou só YouTube).
PlaylistEntry? preferredEntryForPraise(
  ColdigomSearchIndex index,
  String praiseShortId, {
  Map<String, int> rank = const {},
}) {
  final group = index.groupByShortId(praiseShortId);
  if (group == null) return null;
  final material = preferredMaterialForGroup(group, rank: rank);
  if (material == null) return null;
  return PlaylistEntry(id: material.id, kind: material.kind);
}
