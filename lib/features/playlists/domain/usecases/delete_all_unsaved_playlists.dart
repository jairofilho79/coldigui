import '../repositories/playlist_repository.dart';

/// UC-06 — Apagar todas as listas não salvas (Fase 4.8).
class DeleteAllUnsavedPlaylists {
  const DeleteAllUnsavedPlaylists(this._repository);

  final PlaylistRepository _repository;

  Future<void> call() => _repository.deleteAllUnsaved();
}
