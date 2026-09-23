import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../coldigom/presentation/providers/await_coldigom_search_index.dart';
import '../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../domain/ports/praise_entry_resolver.dart';
import '../utils/preferred_entry_for_praise.dart';

final _log = AppLogger.of('playlists');

/// Import de link por praise (spec fim-fonte-plpcg §4.3): espera o índice
/// ([awaitColdigomSearchIndex], prazo [sharedPlaylistCatalogTimeout]) e os
/// favoritos ([awaitFavoriteMaterialKindRank]) em paralelo, e resolve cada
/// token por [preferredEntryForPraise]. Token sem entrada vira log.
///
/// Sem `watch` de propósito: o `ref` fica estável durante a espera.
final praiseEntryResolverLoaderProvider = Provider<PraiseEntryResolverLoader>((
  ref,
) {
  return () async {
    final (index, rank) = await (
      awaitColdigomSearchIndex(ref),
      awaitFavoriteMaterialKindRank(ref),
    ).wait;
    return (praiseShortId) {
      final entry = preferredEntryForPraise(index, praiseShortId, rank: rank);
      if (entry == null) {
        _log.warn('praise $praiseShortId sem entrada no catálogo — ignorado');
      }
      return entry;
    };
  };
});
