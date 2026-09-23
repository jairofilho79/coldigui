import '../../../catalog/presentation/utils/preferred_material_for_group.dart';
import '../../../coldigom/domain/search/coldigom_search_index.dart';
import '../../domain/entities/playlist_entry.dart';

/// Entrada que o import de um link por praise grava para [praiseShortId]
/// (spec fim-fonte-plpcg §4.3). O material vem de [preferredMaterialForGroup]
/// com o [rank] de favoritos — a mesma escolha do «+» do card. Sem nada que
/// o «+» adicione, cai na primeira cifra do praise e depois no primeiro
/// documento de gestos — as listas guardam os dois (`kind` `chord`/`gesture`,
/// como `openChordInReader`/`openGestureInReader` os gravam). `null` quando o
/// token não está no [index] ou o praise não tem nada adicionável (ex.: só
/// letra ou só YouTube).
PlaylistEntry? preferredEntryForPraise(
  ColdigomSearchIndex index,
  String praiseShortId, {
  Map<String, int> rank = const {},
}) {
  final group = index.groupByShortId(praiseShortId);
  if (group == null) return null;
  final material = preferredMaterialForGroup(group, rank: rank);
  if (material != null) {
    return PlaylistEntry(id: material.id, kind: material.kind);
  }
  final chords = group.chordMaterials;
  if (chords.isNotEmpty) {
    return PlaylistEntry(id: chords.first.chordId, kind: MaterialKind.chord);
  }
  final gestures = group.gestureMaterials;
  if (gestures.isNotEmpty) {
    return PlaylistEntry(
      id: gestures.first.gestureId,
      kind: MaterialKind.gesture,
    );
  }
  return null;
}
