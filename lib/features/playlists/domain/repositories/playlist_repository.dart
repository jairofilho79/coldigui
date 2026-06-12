import '../entities/playlist_tab.dart';
import '../entities/saved_playlist.dart';

/// Contrato de persistência de playlists (UC-06).
abstract class PlaylistRepository {
  /// Todas as playlists (sem ordenação específica de aba).
  Future<List<SavedPlaylist>> getAll();

  /// Playlists filtradas e ordenadas por aba (pilha — mais recente no topo).
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab);

  /// Lookup O(1) por [playlistId].
  Future<SavedPlaylist?> getById(String playlistId);

  /// Persiste nova playlist; retorna [playlistId] gerado.
  Future<String> create({
    required String nome,
    required List<String> pdfIds,
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
  });

  /// Atualização parcial — lança [StateError] se playlist ausente.
  Future<void> update(
    String playlistId, {
    String? nome,
    List<String>? pdfIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
  });

  /// Remove playlist — idempotente se ausente.
  Future<void> delete(String playlistId);

  /// Remove todas as playlists não salvas.
  Future<void> deleteAllUnsaved();
}
