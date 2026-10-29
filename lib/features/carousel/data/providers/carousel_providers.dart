import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../datasources/carousel_local_datasource.dart';

/// DI — leitura/limpeza da coleção `CarouselEntry` para a migração única (D3).
///
/// Não existe mais repositório de carousel: a seleção vive em
/// `SavedPlaylist.entries` da lista ativa.
final carouselLocalDatasourceProvider = Provider<CarouselLocalDatasource>((
  ref,
) {
  final isar = ref.watch(optionalIsarProvider);
  if (isar == null) return const CarouselLocalDatasource.unavailable();
  return CarouselLocalDatasource(isar);
});
