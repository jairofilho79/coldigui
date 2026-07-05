import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../carousel/data/providers/carousel_providers.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/usecases/create_playlist_from_carousel.dart';
import '../../domain/usecases/delete_all_unsaved_playlists.dart';
import '../../domain/usecases/delete_playlist.dart';
import '../../domain/usecases/ensure_playlist_for_louvor.dart';
import '../../domain/usecases/favorite_playlist.dart';
import '../../domain/usecases/generate_playlist_share_url.dart';
import '../../domain/usecases/import_shared_playlist_from_url.dart';
import '../../domain/usecases/load_playlist_into_carousel.dart';
import '../../domain/usecases/save_playlist.dart';
import '../../domain/usecases/toggle_playlist_favorite.dart';
import '../../domain/usecases/unfavorite_playlist.dart';
import '../../domain/usecases/update_playlist.dart';
import '../datasources/playlist_local_datasource.dart';
import '../repositories/playlist_repository_impl.dart';

/// DI — CRUD Isar [Playlist] via [isarProvider].
final playlistLocalDatasourceProvider = Provider<PlaylistLocalDatasource>((
  ref,
) {
  final isar = ref.watch(optionalIsarProvider);
  if (isar == null) return const PlaylistLocalDatasource.unavailable();
  return PlaylistLocalDatasource(isar);
});

/// DI — [PlaylistRepositoryImpl]; ponto de entrada para use cases UC-06.
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepositoryImpl(ref.watch(playlistLocalDatasourceProvider));
});

/// UC-06 — criar playlist a partir do carousel.
final createPlaylistFromCarouselProvider = Provider<CreatePlaylistFromCarousel>(
  (ref) {
    return CreatePlaylistFromCarousel(
      ref.watch(carouselRepositoryProvider),
      ref.watch(playlistRepositoryProvider),
    );
  },
);

/// UC-06 — atualizar playlist.
final updatePlaylistProvider = Provider<UpdatePlaylist>((ref) {
  return UpdatePlaylist(ref.watch(playlistRepositoryProvider));
});

/// UC-06 — excluir playlist.
final deletePlaylistProvider = Provider<DeletePlaylist>((ref) {
  return DeletePlaylist(ref.watch(playlistRepositoryProvider));
});

/// UC-06 — alternar favorito (legado; preferir favorite/unfavorite).
final togglePlaylistFavoriteProvider = Provider<TogglePlaylistFavorite>((ref) {
  return TogglePlaylistFavorite(ref.watch(playlistRepositoryProvider));
});

/// UC-06 — marcar playlist como salva (`salva` + `savedAt`).
final savePlaylistProvider = Provider<SavePlaylist>((ref) {
  return SavePlaylist(ref.watch(playlistRepositoryProvider));
});

/// UC-06 — favoritar playlist salva.
final favoritePlaylistProvider = Provider<FavoritePlaylist>((ref) {
  return FavoritePlaylist(ref.watch(playlistRepositoryProvider));
});

/// UC-06 — desfavoritar playlist.
final unfavoritePlaylistProvider = Provider<UnfavoritePlaylist>((ref) {
  return UnfavoritePlaylist(ref.watch(playlistRepositoryProvider));
});

/// UC-06 — apagar todas as listas não salvas.
final deleteAllUnsavedPlaylistsProvider = Provider<DeleteAllUnsavedPlaylists>((
  ref,
) {
  return DeleteAllUnsavedPlaylists(ref.watch(playlistRepositoryProvider));
});

/// UC-06 — garantir playlist ativa ao abrir louvor no leitor (Fase 4.8).
final ensurePlaylistForLouvorProvider = Provider<EnsurePlaylistForLouvor>((
  ref,
) {
  return EnsurePlaylistForLouvor(
    ref.watch(playlistRepositoryProvider),
    ref.watch(loadPlaylistIntoCarouselProvider),
  );
});

/// UC-06 — carregar playlist no carousel (Fase 4.3).
final loadPlaylistIntoCarouselProvider = Provider<LoadPlaylistIntoCarousel>((
  ref,
) {
  return LoadPlaylistIntoCarousel(
    ref.watch(playlistRepositoryProvider),
    ref.watch(carouselRepositoryProvider),
  );
});

/// UC-07 — gerar URL de compartilhamento (Fase 4.4).
final generatePlaylistShareUrlProvider = Provider<GeneratePlaylistShareUrl>((
  ref,
) {
  return GeneratePlaylistShareUrl(ref.watch(playlistRepositoryProvider));
});

/// UC-07 — importar playlist compartilhada (Fase 4.4).
final importSharedPlaylistFromUrlProvider =
    Provider<ImportSharedPlaylistFromUrl>((ref) {
      return ImportSharedPlaylistFromUrl(
        ref.watch(playlistRepositoryProvider),
        ref.watch(loadPlaylistIntoCarouselProvider),
      );
    });
