/// Abas da tela Listas (UC-06, Fase 4.8).
///
/// Cada aba filtra e ordena playlists por timestamp próprio — pilha com
/// a mais recente no topo.
library;

import 'saved_playlist.dart';

enum PlaylistTab {
  /// Rascunhos (`salva == false`) — ordenados por [SavedPlaylist.createdAt].
  unsaved,

  /// Salvas não favoritas — ordenadas por [SavedPlaylist.savedAt].
  saved,

  /// Favoritas — ordenadas por [SavedPlaylist.favoritedAt].
  favorites,
}

/// Resolve aba de exibição a partir de [SavedPlaylist].
abstract final class PlaylistTabForPlaylist {
  const PlaylistTabForPlaylist._();

  static PlaylistTab forPlaylist(SavedPlaylist playlist) {
    if (!playlist.salva) return PlaylistTab.unsaved;
    if (playlist.favorita) return PlaylistTab.favorites;
    return PlaylistTab.saved;
  }
}
