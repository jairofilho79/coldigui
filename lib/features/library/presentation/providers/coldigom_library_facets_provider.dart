import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/models/praise_dto.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';

/// Facets Coldigom para chips da biblioteca.
class ColdigomLibraryFacets {
  const ColdigomLibraryFacets({
    required this.options,
    required this.materialKinds,
  });

  final ColdigomFilterOptionsDto options;
  final List<ColdigomMaterialKindDto> materialKinds;
}

/// Carrega facets ao observar (modo Coldigom).
final coldigomLibraryFacetsProvider =
    FutureProvider.autoDispose<ColdigomLibraryFacets>((ref) async {
      final remote = ref.watch(coldigomRemoteDatasourceProvider);
      final options = await remote.fetchFilterOptions();
      final materialKinds = await remote.fetchMaterialKinds();
      return ColdigomLibraryFacets(
        options: options,
        materialKinds: materialKinds,
      );
    });
