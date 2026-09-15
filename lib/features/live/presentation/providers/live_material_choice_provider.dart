import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/catalog_material.dart';
import '../../../catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../catalog/presentation/utils/preferred_material_for_group.dart';
import '../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../../playlists/domain/entities/playlist_entry.dart';
import '../../domain/live_material_projection.dart';

/// Escolhas **manuais** de material de quem segue uma lista ao vivo, por
/// chave do gestor (sheet «Material» da barra → `replaceByKey`).
///
/// Vive só na sessão: o `LiveSessionController` limpa ao sair/encerrar,
/// junto com a projeção. Nada disto toca a lista local nem o Isar.
class LiveMaterialOverridesNotifier
    extends Notifier<Map<String, PlaylistEntry>> {
  @override
  Map<String, PlaylistEntry> build() => const {};

  void set(String leaderKey, PlaylistEntry entry) =>
      state = {...state, leaderKey: entry};

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

final liveMaterialOverridesProvider =
    NotifierProvider<LiveMaterialOverridesNotifier, Map<String, PlaylistEntry>>(
      LiveMaterialOverridesNotifier.new,
    );

/// Escolha **automática** pelos favoritos da conta (`material_kinds`):
/// para uma partitura do gestor, a partitura do mesmo louvor cujo
/// `materialKindId` está melhor no rank; sem favorito presente, ou para
/// áudio (a voz que o gestor pôs fica — troca só manual), devolve `null`.
///
/// Depende do lookup (caches Coldigom) e do rank — quando o warmup do
/// louvor termina, a projeção recalcula sozinha.
final liveAutoMaterialResolverProvider = Provider<LiveMaterialResolver>((ref) {
  final rank = ref.watch(favoriteMaterialKindRankProvider);
  final lookup = ref.watch(catalogMaterialLookupProvider);
  if (rank.isEmpty) return (_) => null;
  return (leader) {
    if (leader.isAudio) return null;
    final group = findSwapMaterialGroup(
      pdfId: leader.id,
      coldigomCache: lookup.coldigomLouvoresByPdfId,
      audioCache: lookup.audioTracksById,
      chordCache: lookup.chordsById,
      gestureCache: lookup.gesturesById,
    );
    if (group == null) return null;
    final best = bestFavoriteMaterialForGroup(
      group,
      rank,
      where: (material) => material is PdfMaterial,
    );
    if (best == null || best.id == leader.id) return null;
    return PlaylistEntry(id: best.id, kind: best.kind);
  };
});
