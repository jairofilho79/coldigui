import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/coldigom_search_repository.dart';
import '../datasources/coldigom_remote_datasource.dart';
import '../repositories/coldigom_search_repository_impl.dart';
import 'coldigom_dio_provider.dart';
import 'coldigom_providers.dart' show coldigomCacheWriterProvider;

/// DI da **rede** Coldigom — o que a presentation pode observar.
///
/// Separado de `coldigom_providers.dart` (os caches em memória e o seu
/// escritor) para que Biblioteca e Home dependam do datasource/repositório
/// sem enxergar os notifiers de cache — quem lê material solto passa pelo
/// `catalogMaterialLookupProvider` (C.3).
final coldigomRemoteDatasourceProvider = Provider<ColdigomRemoteDatasource>((
  ref,
) {
  return ColdigomRemoteDatasource(ref.watch(coldigomDioProvider));
});

/// Busca/browse Coldigom; funde o que veio nos caches pelo escritor (C.3).
final coldigomSearchRepositoryProvider = Provider<ColdigomSearchRepository>((
  ref,
) {
  return ColdigomSearchRepositoryImpl(
    ref.watch(coldigomRemoteDatasourceProvider),
    cache: ref.watch(coldigomCacheWriterProvider),
  );
});
