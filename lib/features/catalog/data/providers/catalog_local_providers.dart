import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../datasources/catalog_local_datasource.dart';

/// Persistência local Isar do catálogo.
final catalogLocalDatasourceProvider = Provider<CatalogLocalDatasource>((ref) {
  final isar = ref.watch(optionalIsarProvider);
  if (isar == null) return const CatalogLocalDatasource.unavailable();
  return CatalogLocalDatasource(isar);
});
