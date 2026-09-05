import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/carousel_item.dart';
import 'carousel_items_provider.dart';

/// Apelido de [carouselItemsProvider] (some na Tarefa 12).
///
/// O debounce que este provider mantinha para não piscar durante uma
/// reordenação virou o override otimista do `ActivePlaylistEditor`: a barra já
/// recebe a ordem nova na hora e nunca vê a antiga entre a escrita e o reload.
final carouselLouvoresDisplayProvider = Provider<List<CarouselItem>>((ref) {
  return ref.watch(carouselItemsProvider);
});
