import '../entities/playlist_tab.dart';
import '../entities/saved_playlist.dart';

/// Contrato de persistência de playlists (UC-06 + UC-15).
abstract class PlaylistRepository {
  /// Todas as playlists ativas (sem tombstones).
  Future<List<SavedPlaylist>> getAll();

  /// Playlists filtradas e ordenadas por aba (pilha — mais recente no topo).
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab);

  /// Lookup O(1) por [playlistId] (inclui tombstone se existir).
  Future<SavedPlaylist?> getById(String playlistId);

  /// Persiste nova playlist; retorna [playlistId] gerado.
  Future<String> create({
    required String nome,
    required List<String> pdfIds,
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
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
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  });

  /// Soft delete se salva; hard delete se rascunho.
  Future<void> delete(String playlistId);

  /// Hard delete imediato (após DELETE remoto ok).
  Future<void> hardDelete(String playlistId);

  /// Remove todas as playlists não salvas.
  Future<void> deleteAllUnsaved();

  /// Pendentes de push (ativas, salvas).
  Future<List<SavedPlaylist>> getPendingPush();

  /// Tombstones locais aguardando DELETE remoto.
  Future<List<SavedPlaylist>> getTombstones();

  /// Upsert completo a partir do remoto / sync.
  Future<void> upsert(SavedPlaylist playlist);

  /// Marca todas as salvas locais como pendingPush (pós-login).
  Future<void> markAllSavedPendingPush();
}
