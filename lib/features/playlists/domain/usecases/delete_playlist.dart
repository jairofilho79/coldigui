import '../repositories/playlist_repository.dart';

/// UC-06 — Excluir playlist (Fase 4.2).
class DeletePlaylist {
  const DeletePlaylist(this._repository);

  final PlaylistRepository _repository;

  Future<void> call({required String playlistId}) =>
      _repository.delete(playlistId);
}
