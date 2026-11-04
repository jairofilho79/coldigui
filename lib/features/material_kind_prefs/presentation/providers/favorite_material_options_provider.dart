import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/entities/material_favorite_policy.dart';

class FavoriteMaterialOption {
  const FavoriteMaterialOption({
    required this.id,
    required this.name,
    required this.types,
  });

  final String id;
  final String name;
  final List<String> types;
}

/// Usa o dump local completo, não os caches parciais nem N pedidos por kind.
final favoriteMaterialOptionsProvider =
    FutureProvider<List<FavoriteMaterialOption>>((ref) async {
      final memoryRows = ref.watch(coldigomInMemoryCatalogProvider);
      await ref.watch(coldigomCatalogHydrationProvider.future);
      final local = ref.read(coldigomCatalogLocalDatasourceProvider);
      final rows = local.isAvailable ? local.findAllSync() : memoryRows;
      if (rows.isEmpty) {
        throw StateError('favorite_material_catalog_unavailable');
      }
      return favoriteMaterialOptionsFromCatalog(rows);
    });

List<FavoriteMaterialOption> favoriteMaterialOptionsFromCatalog(
  Iterable<ColdigomPraiseCache> rows,
) {
  final names = <String, String>{};
  final types = <String, Set<String>>{};
  for (final row in rows) {
    if (row.lyrics.trim().isNotEmpty) {
      names[kLyricsFavoriteKindId] = 'lyrics';
      types.putIfAbsent(kLyricsFavoriteKindId, () => {}).add('lyrics');
    }
    for (final material in ColdigomPraiseCacheMapper.decodeMaterials(row)) {
      final type = material.type.toLowerCase();
      if (!isFavoriteMaterialType(type)) continue;
      final id = type == 'lyrics'
          ? kLyricsFavoriteKindId
          : material.kindId ?? 'type:$type';
      names[id] = material.kindName.trim().isEmpty ? type : material.kindName;
      types.putIfAbsent(id, () => {}).add(type);
    }
  }
  final options = [
    for (final entry in types.entries)
      FavoriteMaterialOption(
        id: entry.key,
        name: names[entry.key]!,
        types: List.unmodifiable(
          entry.value.toList()..sort((a, b) {
            final byType = favoriteMaterialTypeOrder(a)
                .compareTo(favoriteMaterialTypeOrder(b));
            return byType != 0 ? byType : a.compareTo(b);
          }),
        ),
      ),
  ];
  options.sort(
    (a, b) =>
        LouvorSearchTokens.normalize(a.name)
            .compareTo(LouvorSearchTokens.normalize(b.name)),
  );
  return List.unmodifiable(options);
}
