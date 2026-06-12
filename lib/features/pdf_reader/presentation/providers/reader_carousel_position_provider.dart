import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../carousel/presentation/providers/carousel_louvores_provider.dart';
import '../../domain/entities/carousel_reader_position.dart';

/// Posição do louvor atual no carousel do leitor (Fase 4.7).
///
/// Derivada de [carouselLouvoresProvider] (estado em memória) para evitar
/// flicker/loading do antigo [FutureProvider] e manter setas/modal habilitados.
///
/// Se [currentPdfId] não estiver na seleção, usa o índice focado do shell como
/// fallback para permitir navegação entre itens do carousel.
final readerCarouselPositionProvider =
    Provider.family<CarouselReaderPosition?, String>((ref, currentPdfId) {
  final items = ref.watch(carouselLouvoresProvider);
  if (items.isEmpty) return null;

  var index = items.indexWhere((item) => item.pdfId == currentPdfId);
  if (index < 0) {
    index = ref.watch(carouselFocusedIndexProvider).clamp(0, items.length - 1);
  }

  return CarouselReaderPosition(
    currentIndex: index + 1,
    total: items.length,
    previousPdfId: index > 0 ? items[index - 1].pdfId : null,
    nextPdfId: index < items.length - 1 ? items[index + 1].pdfId : null,
  );
});
