import '../repositories/playlist_repository.dart';

/// UC-06 — Marca playlist como salva (Fase 4.8).
class SavePlaylist {
  const SavePlaylist(this._repository);

  final PlaylistRepository _repository;

  /// Define [salva] e [savedAt] = agora. Opcionalmente renomeia.
  Future<void> call({
    required String playlistId,
    String? nome,
  }) async {
    final now = DateTime.now();
    await _repository.update(
      playlistId,
      salva: true,
      savedAt: now,
      nome: nome,
    );
  }
}
