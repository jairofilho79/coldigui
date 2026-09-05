import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../domain/ports/catalog_source.dart';
import '../sources/composite_catalog_source.dart';
import 'plpcg_catalog_source_provider.dart';

/// Porta única de leitura e busca do catálogo (PLPCG + Coldigom).
///
/// Compõe as duas fontes em vez de construí-las: assim uma página de busca
/// Coldigom recompõe só a fonte Coldigom, e o índice PLPCG (caro) sobrevive.
final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return CompositeCatalogSource(
    plpcg: ref.watch(plpcgCatalogSourceProvider),
    coldigom: ref.watch(coldigomCatalogSourceProvider),
  );
});
