import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'manifest_material_aliases_provider.dart';

/// Praises que o app já conhece localmente: o Isar Coldigom hidratado
/// ([ColdigomSearchIndex.catalogIds]) **e** os praises do manifest.
///
/// É contra isto que a Home decide o chip «novo» e a adoção dos «novos» da
/// pesquisa remota (spec §5.4): um praise do manifest nunca é novidade e
/// nunca entra no Isar Coldigom.
final knownPraiseIdsProvider = Provider<Set<String>>((ref) {
  final index = ref.watch(coldigomSearchIndexProvider).catalogIds;
  final manifest = ref.watch(manifestMaterialAliasesProvider).praiseIds;
  if (manifest.isEmpty) return index;
  if (index.isEmpty) return manifest;
  return Set.unmodifiable({...index, ...manifest});
});
