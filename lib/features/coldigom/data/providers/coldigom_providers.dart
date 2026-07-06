import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor.dart';
import '../datasources/coldigom_remote_datasource.dart';
import '../providers/coldigom_dio_provider.dart';
import '../repositories/coldigom_search_repository_impl.dart';
import '../../domain/repositories/coldigom_search_repository.dart';

/// Cache em memória de louvores coldigom indexados por `pdfId`.
class ColdigomLouvoresCacheNotifier extends Notifier<Map<String, Louvor>> {
  @override
  Map<String, Louvor> build() => const {};

  void mergeLouvores(Iterable<Louvor> louvores) {
    if (louvores.isEmpty) return;
    final next = Map<String, Louvor>.from(state);
    for (final louvor in louvores) {
      next[louvor.pdfId] = louvor;
    }
    state = next;
  }

  Louvor? findByPdfId(String pdfId) => state[pdfId];
}

final coldigomLouvoresCacheProvider =
    NotifierProvider<ColdigomLouvoresCacheNotifier, Map<String, Louvor>>(
      ColdigomLouvoresCacheNotifier.new,
    );

final coldigomRemoteDatasourceProvider = Provider<ColdigomRemoteDatasource>((
  ref,
) {
  return ColdigomRemoteDatasource(ref.watch(coldigomDioProvider));
});

final coldigomSearchRepositoryProvider = Provider<ColdigomSearchRepository>((
  ref,
) {
  return ColdigomSearchRepositoryImpl(
    ref.watch(coldigomRemoteDatasourceProvider),
  );
});
