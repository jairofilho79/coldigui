import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/coldigom_catalog_providers.dart';
import '../sources/coldigom_catalog_source.dart';
import 'coldigom_providers.dart';

/// Fonte Coldigom sobre os sete caches em memória.
///
/// Recompõe a cada merge — é o preço de ler cache como valor.
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
