import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../domain/repositories/carousel_repository.dart';
import '../../domain/usecases/add_louvor_to_carousel.dart';
import '../../domain/usecases/clear_carousel.dart';
import '../../domain/usecases/remove_louvor_from_carousel.dart';
import '../../domain/usecases/reorder_carousel.dart';
import '../datasources/carousel_local_datasource.dart';
import '../repositories/carousel_repository_impl.dart';

/// DI — CRUD Isar [CarouselEntry] via [isarProvider].
final carouselLocalDatasourceProvider =
    Provider<CarouselLocalDatasource>((ref) {
  return CarouselLocalDatasource(ref.watch(isarProvider));
});

/// DI — [CarouselRepositoryImpl]; ponto de entrada para use cases UC-05.
final carouselRepositoryProvider = Provider<CarouselRepository>((ref) {
  return CarouselRepositoryImpl(ref.watch(carouselLocalDatasourceProvider));
});

/// UC-05 — adicionar louvor ao carousel.
final addLouvorToCarouselProvider = Provider<AddLouvorToCarousel>((ref) {
  return AddLouvorToCarousel(ref.watch(carouselRepositoryProvider));
});

/// UC-05 — remover louvor do carousel.
final removeLouvorFromCarouselProvider =
    Provider<RemoveLouvorFromCarousel>((ref) {
  return RemoveLouvorFromCarousel(ref.watch(carouselRepositoryProvider));
});

/// UC-05 — reordenar carousel.
final reorderCarouselProvider = Provider<ReorderCarousel>((ref) {
  return ReorderCarousel(ref.watch(carouselRepositoryProvider));
});

/// UC-05 — limpar carousel.
final clearCarouselProvider = Provider<ClearCarousel>((ref) {
  return ClearCarousel(ref.watch(carouselRepositoryProvider));
});
