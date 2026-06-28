import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/data/providers/carousel_providers.dart';
import '../../domain/usecases/generate_leaflet_from_pdf_ids.dart';
import '../../domain/usecases/generate_leaflet_from_selection.dart';

/// UC-08 — DI [GenerateLeafletFromSelection] via [carouselRepositoryProvider].
final generateLeafletFromSelectionProvider =
    Provider<GenerateLeafletFromSelection>((ref) {
  return GenerateLeafletFromSelection(ref.watch(carouselRepositoryProvider));
});

/// UC-08 — folheto a partir de [pdfIds] de playlist salva.
final generateLeafletFromPdfIdsProvider = Provider<GenerateLeafletFromPdfIds>(
  (ref) => const GenerateLeafletFromPdfIds(),
);
