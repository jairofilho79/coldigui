import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorite_material_options_provider.dart';

/// Formatos elegíveis reais, calculados em bloco sobre o catálogo local.
final materialTypesForKindProvider =
    FutureProvider.family<List<String>, String>((ref, kindId) async {
      final options = await ref.watch(favoriteMaterialOptionsProvider.future);
      return options
              .where((option) => option.id == kindId)
              .firstOrNull
              ?.types ??
          const [];
    });
