import '../repositories/playlist_repository.dart';

/// UC-06 — Atualizar playlist (renomear e/ou alterar pdfIds/audioIds).
class UpdatePlaylist {
  const UpdatePlaylist(this._repository);

  final PlaylistRepository _repository;

  Future<void> call({
    required String playlistId,
    String? nome,
    List<String>? pdfIds,
    List<String>? audioIds,
  }) async {
    if (nome == null && pdfIds == null && audioIds == null) {
      throw ArgumentError(
        'At least one of nome, pdfIds or audioIds must be provided',
      );
    }

    if (pdfIds != null || audioIds != null) {
      final existing = await _repository.getById(playlistId);
      final nextPdfs = pdfIds ?? existing?.pdfIds ?? const <String>[];
      final nextAudios = audioIds ?? existing?.audioIds ?? const <String>[];
      if (nextPdfs.isEmpty && nextAudios.isEmpty) {
        await _repository.delete(playlistId);
        return;
      }
    }

    await _repository.update(
      playlistId,
      nome: nome,
      pdfIds: pdfIds,
      audioIds: audioIds,
    );
  }
}
