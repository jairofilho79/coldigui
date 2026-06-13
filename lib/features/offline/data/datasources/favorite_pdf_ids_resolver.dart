import 'package:flutter/foundation.dart';

import '../../../playlists/data/datasources/playlist_local_datasource.dart';

/// PDFs referenciados em playlists favoritas — protegidos da eviction LRU.
class FavoritePdfIdsResolver {
  FavoritePdfIdsResolver(this._playlistLocal, {Set<String>? testingPdfIds})
      : _testingPdfIds = testingPdfIds;

  /// Retorna [testingPdfIds] fixo — útil em testes unitários sem Isar de playlists.
  @visibleForTesting
  FavoritePdfIdsResolver.testing([Set<String> testingPdfIds = const {}])
      : _playlistLocal = null,
        _testingPdfIds = testingPdfIds;

  final PlaylistLocalDatasource? _playlistLocal;
  final Set<String>? _testingPdfIds;

  Future<Set<String>> resolve() async {
    final testingPdfIds = _testingPdfIds;
    if (testingPdfIds != null) return testingPdfIds;

    final favorites = await _playlistLocal!.findFavorites();
    return favorites.expand((playlist) => playlist.pdfIds).toSet();
  }
}
