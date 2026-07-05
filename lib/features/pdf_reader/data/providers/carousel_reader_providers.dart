import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/data/providers/carousel_providers.dart';
import '../../domain/usecases/navigate_carousel_in_reader.dart';

/// Navegação carousel no leitor — sem dependência de pdfrx (Fase F split).
final navigateCarouselInReaderProvider = Provider<NavigateCarouselInReader>((
  ref,
) {
  return NavigateCarouselInReader(ref.watch(carouselRepositoryProvider));
});
