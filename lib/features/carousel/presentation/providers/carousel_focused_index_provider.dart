import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/carousel_item.dart';
import 'carousel_louvores_provider.dart';

/// Índice do louvor visível na barra do carousel (shell).
///
/// Persiste o [pdfId] focado entre mutações da lista (remove/reorder/reload)
/// e recua o índice quando o item focado deixa de existir. Sincroniza com
/// [carouselLouvoresProvider] (fonte de verdade); [CarouselChips] resolve o
/// chip exibido pelo `pdfId` na lista debounced
/// ([carouselLouvoresDisplayProvider]).
class CarouselFocusedIndexNotifier extends Notifier<int> {
  String? _focusedPdfId;
  int _currentIndex = 0;

  @override
  int build() {
    final synced = _syncIndex(ref.watch(carouselLouvoresProvider));
    _currentIndex = synced;
    return synced;
  }

  int _syncIndex(List<CarouselItem> items) {
    if (items.isEmpty) {
      _focusedPdfId = null;
      _currentIndex = 0;
      return 0;
    }

    if (_focusedPdfId != null) {
      final index = items.indexWhere((item) => item.pdfId == _focusedPdfId);
      if (index >= 0) {
        _currentIndex = index;
        return index;
      }
    }

    final clamped = _currentIndex.clamp(0, items.length - 1);
    _currentIndex = clamped;
    _focusedPdfId = items[clamped].pdfId;
    return clamped;
  }

  void goPrevious() {
    final items = ref.read(carouselLouvoresProvider);
    if (items.isEmpty || _currentIndex <= 0) return;
    _currentIndex = _currentIndex - 1;
    state = _currentIndex;
    _focusedPdfId = items[_currentIndex].pdfId;
  }

  void goNext() {
    final items = ref.read(carouselLouvoresProvider);
    if (items.isEmpty || _currentIndex >= items.length - 1) return;
    _currentIndex = _currentIndex + 1;
    state = _currentIndex;
    _focusedPdfId = items[_currentIndex].pdfId;
  }

  /// Foca o item com [pdfId] — usado ao selecionar louvor no modal do carousel.
  void focusPdfId(String pdfId) {
    if (_focusedPdfId == pdfId) return;
    final items = ref.read(carouselLouvoresProvider);
    final index = items.indexWhere((item) => item.pdfId == pdfId);
    if (index < 0) return;
    _currentIndex = index;
    state = index;
    _focusedPdfId = pdfId;
  }

  /// Volta ao primeiro item — usado ao carregar playlist no carousel.
  void reset() {
    final items = ref.read(carouselLouvoresProvider);
    _currentIndex = 0;
    state = 0;
    _focusedPdfId = items.isEmpty ? null : items.first.pdfId;
  }
}

/// Índice 0-based do louvor exibido na [CarouselNavigatorBar] do shell.
final carouselFocusedIndexProvider =
    NotifierProvider<CarouselFocusedIndexNotifier, int>(
  CarouselFocusedIndexNotifier.new,
);
