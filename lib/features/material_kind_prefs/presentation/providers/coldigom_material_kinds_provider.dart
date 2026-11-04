import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/models/praise_dto.dart';
import 'favorite_material_options_provider.dart';

/// Categorias com algum formato elegível no catálogo local, incluindo Letra.
final coldigomMaterialKindsProvider =
    FutureProvider<List<ColdigomMaterialKindDto>>((ref) async {
      final options = await ref.watch(favoriteMaterialOptionsProvider.future);
      return [
        for (final option in options)
          ColdigomMaterialKindDto(id: option.id, name: option.name),
      ];
    });
