import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../coldigom/data/sources/coldigom_catalog_source.dart';
import '../../data/sources/composite_catalog_source.dart';
import '../../data/sources/plpcg_catalog_source.dart';
import '../../domain/ports/catalog_source.dart';
import 'louvores_manifest_provider.dart';

/// Porta única de leitura do catálogo por id (PLPCG + Coldigom).
///
/// Recompõe as fontes a cada mudança de manifest/cache — as duas são objetos
/// de valor baratos sobre as coleções que já existem, sem estado próprio.
final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return CompositeCatalogSource(
    plpcg: PlpcgCatalogSource(
      catalog: ref.watch(louvoresManifestProvider).value?.louvores,
    ),
    coldigom: ColdigomCatalogSource(
      louvores: ref.watch(coldigomLouvoresCacheProvider),
      audioTracks: ref.watch(coldigomAudioTracksCacheProvider),
      chords: ref.watch(coldigomChordMaterialsCacheProvider),
      praiseMeta: ref.watch(coldigomPraiseMetaCacheProvider),
    ),
  );
});
