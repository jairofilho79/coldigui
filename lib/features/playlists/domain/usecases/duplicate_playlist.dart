import '../entities/saved_playlist.dart';
import '../repositories/playlist_repository.dart';

/// UC-06 — Duplicar playlist (C11, spec B.3).
///
/// Cria uma lista **salva** nova com as mesmas [SavedPlaylist.entries] da
/// original (partitura e áudio intercalados, repetições preservadas) e nome
/// [copyName] — já formatado pelo chamador (ARB `playlistCopyName`, «Nome
/// (cópia)»), esta classe não conhece l10n. `syncStatus: pendingPush`: a
/// cópia sobe no próximo sync, mas nunca nasce publicada, mesmo que a
/// original seja.
class DuplicatePlaylist {
  const DuplicatePlaylist(this._repository);

  final PlaylistRepository _repository;

  /// Lança [StateError] se [playlistId] não existir.
  Future<SavedPlaylist> call({
    required String playlistId,
    required String copyName,
  }) async {
    final original = await _repository.getById(playlistId);
    if (original == null) {
      throw StateError('DuplicatePlaylist: playlist $playlistId não existe');
    }

    final newId = await _repository.create(
      nome: copyName,
      entries: original.entries,
      salva: true,
      syncStatus: PlaylistSyncStatus.pendingPush,
    );

    final created = await _repository.getById(newId);
    if (created == null) {
      throw StateError(
        'DuplicatePlaylist: cópia $newId não encontrada após criar',
      );
    }
    return created;
  }
}
