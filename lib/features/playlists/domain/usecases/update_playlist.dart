import '../repositories/playlist_repository.dart';

/// UC-06 — Atualizar playlist (renomear e/ou alterar pdfIds) (Fase 4.2).
class UpdatePlaylist {
  const UpdatePlaylist(this._repository);

  final PlaylistRepository _repository;

  Future<void> call({
    required String playlistId,
    String? nome,
    List<String>? pdfIds,
  }) async {
    if (nome == null && pdfIds == null) {
      throw ArgumentError('At least one of nome or pdfIds must be provided');
    }

    if (pdfIds != null && pdfIds.isEmpty) {
      await _repository.delete(playlistId);
      return;
    }

    await _repository.update(playlistId, nome: nome, pdfIds: pdfIds);
  }
}
