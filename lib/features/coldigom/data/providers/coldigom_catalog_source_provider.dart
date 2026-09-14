import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/coldigom_catalog_providers.dart';
import '../sources/coldigom_catalog_source.dart';
import 'coldigom_providers.dart';

/// Fonte Coldigom sobre os seis caches em memória.
///
/// Recompõe a cada merge — é o preço de ler cache como valor —, mas o custo
/// fica contido aqui: a fonte PLPCG (e seu índice) vive em
/// `plpcgCatalogSourceProvider` e não é arrastada junto.
final coldigomCatalogSourceProvider = Provider<ColdigomCatalogSource>((ref) {
  return ColdigomCatalogSource(
    louvores: ref.watch(coldigomLouvoresCacheProvider),
    audioTracks: ref.watch(coldigomAudioTracksCacheProvider),
    chords: ref.watch(coldigomChordMaterialsCacheProvider),
    gestures: ref.watch(coldigomGestureMaterialsCacheProvider),
    praiseMeta: ref.watch(coldigomPraiseMetaCacheProvider),
    youtube: ref.watch(coldigomYoutubeCacheProvider),
    lyrics: ref.watch(coldigomLyricsCacheProvider),
    searchRepository: ref.watch(coldigomSearchRepositoryProvider),
    index: ref.watch(coldigomSearchIndexProvider),
  );
});
