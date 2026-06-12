import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/carousel_item.dart';
import 'carousel_louvores_provider.dart';

/// Debounce da lista exibida na barra do carousel — evita flicker quando a
/// ordem muda em rajada (reorder no modal).
const carouselLouvoresDisplayDebounce = Duration(milliseconds: 100);

bool _samePdfIdSet(List<CarouselItem> a, List<CarouselItem> b) {
  if (a.length != b.length) return false;
  final idsA = a.map((item) => item.pdfId).toSet();
  final idsB = b.map((item) => item.pdfId).toSet();
  return idsA.length == idsB.length && idsA.containsAll(idsB);
}

bool _samePdfIdOrder(List<CarouselItem> a, List<CarouselItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].pdfId != b[i].pdfId) return false;
  }
  return true;
}

/// Lista debounced para renderização na [CarouselNavigatorBar].
///
/// Add/remove/clear refletem imediatamente; apenas reordenações (mesmo
/// conjunto de [CarouselItem.pdfId], ordem diferente) aguardam
/// [carouselLouvoresDisplayDebounce] para coalescer renders.
class CarouselLouvoresDisplayNotifier extends Notifier<List<CarouselItem>> {
  Timer? _debounceTimer;

  @override
  List<CarouselItem> build() {
    ref.listen<List<CarouselItem>>(carouselLouvoresProvider, (previous, next) {
      _onSourceChanged(previous, next);
    }, fireImmediately: true);

    ref.onDispose(() => _debounceTimer?.cancel());
    return ref.read(carouselLouvoresProvider);
  }

  void _onSourceChanged(List<CarouselItem>? previous, List<CarouselItem> next) {
    if (previous == null) return;

    _debounceTimer?.cancel();

    final reorderOnly =
        _samePdfIdSet(previous, next) && !_samePdfIdOrder(previous, next);

    if (!reorderOnly) {
      state = next;
      return;
    }

    _debounceTimer = Timer(carouselLouvoresDisplayDebounce, () {
      state = ref.read(carouselLouvoresProvider);
    });
  }
}

/// Provider da lista exibida na barra [CarouselChips] — derivado de
/// [carouselLouvoresProvider] com debounce em reordenações.
///
/// Consumidores: [CarouselChips] (`watch`); navegação/setas continuam em
/// [carouselLouvoresProvider] + [carouselFocusedIndexProvider].
final carouselLouvoresDisplayProvider =
    NotifierProvider<CarouselLouvoresDisplayNotifier, List<CarouselItem>>(
  CarouselLouvoresDisplayNotifier.new,
);
