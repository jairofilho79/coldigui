import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/manifest_material_aliases.dart';
import 'louvores_manifest_provider.dart';

/// [ManifestMaterialAliases] do manifest corrente (construído uma vez por
/// manifest). [ManifestMaterialAliases.empty] enquanto o manifest não carregou
/// ou não traz `praiseId`.
final manifestMaterialAliasesProvider = Provider<ManifestMaterialAliases>((ref) {
  final louvores = ref.watch(
    louvoresManifestProvider.select((manifest) => manifest.value?.louvores),
  );
  if (louvores == null) return ManifestMaterialAliases.empty;
  return ManifestMaterialAliases.fromLouvores(louvores);
});
