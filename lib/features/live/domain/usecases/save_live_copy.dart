import '../../../playlists/domain/entities/saved_playlist.dart';
import '../../../playlists/domain/repositories/playlist_repository.dart';
import '../entities/live_snapshot.dart';

/// «Guardar cópia» (spec D4): a projeção do gestor vira uma lista **salva**
/// do consumidor — mesmo contrato de `DuplicatePlaylist` (`pendingPush`,
/// nunca publicada, id novo). [copyName] já vem formatado (ARB `liveCopyName`).
class SaveLiveCopy {
  const SaveLiveCopy(this._repository);

  final PlaylistRepository _repository;

  /// Lança [StateError] com snapshot vazio.
  Future<SavedPlaylist> call({
    required LiveSnapshot snapshot,
    required String copyName,
  }) async {
    if (snapshot.entries.isEmpty) {
      throw StateError('SaveLiveCopy: snapshot sem entradas');
    }
    final now = DateTime.now();
    final id = await _repository.create(
      nome: copyName,
      entries: snapshot.entries,
      salva: true,
      savedAt: now,
      createdAt: now,
      syncStatus: PlaylistSyncStatus.pendingPush,
    );
    final created = await _repository.getById(id);
    if (created == null) {
      throw StateError('SaveLiveCopy: cópia $id não encontrada após criar');
    }
    return created;
  }
}
