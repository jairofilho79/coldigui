import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../domain/ports/catalog_source.dart';

/// Porta única de leitura e busca do catálogo — o catálogo coldigom
/// (spec 2026-09-23 §2.1). Quem precisa dos métodos síncronos
/// (`findGroupById`/`findGroupForMaterial`) lê `coldigomCatalogSourceProvider`.
final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return ref.watch(coldigomCatalogSourceProvider);
});
