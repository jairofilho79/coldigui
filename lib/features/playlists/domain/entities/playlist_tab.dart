/// Abas da tela Listas (UC-06, Fase 4.8).
///
/// Cada aba filtra e ordena playlists por timestamp próprio — pilha com
/// a mais recente no topo.
enum PlaylistTab {
  /// Rascunhos (`salva == false`) — ordenados por [SavedPlaylist.createdAt].
  unsaved,

  /// Salvas não favoritas — ordenadas por [SavedPlaylist.savedAt].
  saved,

  /// Favoritas — ordenadas por [SavedPlaylist.favoritedAt].
  favorites,
}
