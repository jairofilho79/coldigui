import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/entities/catalog_filter_options.dart';

export '../../domain/entities/catalog_filter_options.dart';

/// Opções dos chips de filtro (página inicial e /biblioteca), derivadas do
/// índice local — recalculadas só quando o índice muda (hidratação/sync).
final catalogFilterOptionsProvider = Provider<CatalogFilterOptions>((ref) {
  final index = ref.watch(coldigomSearchIndexProvider);
  if (index.isEmpty) return CatalogFilterOptions.empty;
  return CatalogFilterOptions.fromGroups(index.groups);
});
