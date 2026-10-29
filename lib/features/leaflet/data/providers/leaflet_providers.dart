import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../domain/usecases/generate_leaflet_from_entries.dart';

/// UC-08 — folheto a partir das entradas de uma lista (playlist salva ou
/// seleção ativa), com áudio (D8).
final generateLeafletFromEntriesProvider = Provider<GenerateLeafletFromEntries>(
  (ref) {
    return GenerateLeafletFromEntries(
      lookup: () => ref.read(catalogMaterialLookupProvider),
    );
  },
);
