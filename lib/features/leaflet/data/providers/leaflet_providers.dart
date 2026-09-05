import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../domain/usecases/generate_leaflet_from_pdf_ids.dart';
import '../../domain/usecases/generate_leaflet_from_selection.dart';

/// UC-08 — DI [GenerateLeafletFromSelection] sobre a face de partituras da
/// lista ativa ([carouselItemsProvider]).
final generateLeafletFromSelectionProvider =
    Provider<GenerateLeafletFromSelection>((ref) {
      return GenerateLeafletFromSelection(
        () async => ref
            .read(carouselItemsProvider)
            .map((item) => item.materialId)
            .toList(growable: false),
      );
    });

/// UC-08 — folheto a partir de [pdfIds] de playlist salva.
final generateLeafletFromPdfIdsProvider = Provider<GenerateLeafletFromPdfIds>(
  (ref) => const GenerateLeafletFromPdfIds(),
);
