import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../domain/ports/catalog_source.dart';
import '../../presentation/providers/manifest_material_aliases_provider.dart';
import '../sources/composite_catalog_source.dart';
import 'plpcg_catalog_source_provider.dart';

/// Composite concreto — para quem precisa dos métodos **síncronos**
/// (`findGroupById`, `findGroupForMaterial`) durante o build.
///
/// Compõe as fontes em vez de construí-las: uma página de busca Coldigom
/// recompõe só a fonte Coldigom, e o índice PLPCG (caro) e os aliases do
/// manifest sobrevivem.
final compositeCatalogSourceProvider = Provider<CompositeCatalogSource>((ref) {
  return CompositeCatalogSource(
    plpcg: ref.watch(plpcgCatalogSourceProvider),
    coldigom: ref.watch(coldigomCatalogSourceProvider),
    aliases: ref.watch(manifestMaterialAliasesProvider),
  );
});

/// Porta única de leitura e busca do catálogo — o que os use cases observam.
final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return ref.watch(compositeCatalogSourceProvider);
});
