import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../carousel/data/providers/carousel_providers.dart';
import '../../domain/ports/share_link_shortener.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/usecases/delete_all_unsaved_playlists.dart';
import '../../domain/usecases/delete_playlist.dart';
import '../../domain/usecases/ensure_active_playlist.dart';
import '../../domain/usecases/favorite_playlist.dart';
import '../../domain/usecases/generate_playlist_share_url.dart';
import '../../domain/usecases/import_shared_playlist_from_url.dart';
import '../../domain/usecases/migrate_carousel_store.dart';
import '../../domain/usecases/publish_playlist.dart';
import '../../domain/usecases/save_playlist.dart';
import '../../domain/usecases/toggle_playlist_favorite.dart';
import '../../domain/usecases/unfavorite_playlist.dart';
import '../../domain/usecases/update_playlist.dart';
import '../datasources/playlist_local_datasource.dart';
import '../datasources/share_link_shortener_remote.dart';
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

/// Publicar lista salva (irreversível).
final publishPlaylistProvider = Provider<PublishPlaylist>((ref) {
  return PublishPlaylist(ref.watch(playlistRepositoryProvider));
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

/// D3 — garantir lista ativa ao adicionar um material.
final ensureActivePlaylistProvider = Provider<EnsureActivePlaylist>((ref) {
  return EnsureActivePlaylist(ref.watch(playlistRepositoryProvider));
});

/// D3 — migração única da coleção `CarouselEntry` para a lista ativa.
final migrateCarouselStoreProvider = Provider<MigrateCarouselStore>((ref) {
  return MigrateCarouselStore(
    ref.watch(carouselLocalDatasourceProvider),
    ref.watch(playlistRepositoryProvider),
  );
});

/// D7 — encurtador de link de compartilhamento (`POST /api/links`).
///
/// `idToken` é resolvido a cada chamada de [ShareLinkShortener.shorten] (não
/// na hora de montar o provider): a rota exige autenticação, e a instância
/// sobrevive a logins/logouts sem precisar ser recriada.
final shareLinkShortenerProvider = Provider<ShareLinkShortener>((ref) {
  return ShareLinkShortenerRemote(
    ref.watch(dioProvider),
    idToken: () => ref.read(authStateProvider).value?.idToken,
  );
});

/// UC-07 — gerar URL de compartilhamento (Fase 4.4; link curto, D7).
final generatePlaylistShareUrlProvider = Provider<GeneratePlaylistShareUrl>((
  ref,
) {
  return GeneratePlaylistShareUrl(
    ref.watch(playlistRepositoryProvider),
    shortener: ref.watch(shareLinkShortenerProvider),
  );
});

/// UC-07 — importar playlist compartilhada (Fase 4.4).
final importSharedPlaylistFromUrlProvider =
    Provider<ImportSharedPlaylistFromUrl>((ref) {
      return ImportSharedPlaylistFromUrl(ref.watch(playlistRepositoryProvider));
    });
