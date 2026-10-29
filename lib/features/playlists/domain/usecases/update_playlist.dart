import '../entities/playlist_entry.dart';
import '../repositories/playlist_repository.dart';

/// UC-06 — Atualizar playlist (renomear e/ou alterar a seleção).
///
/// [entries] é a ordem única tipada e **vence** [pdfIds]/[audioIds]: é por ela
/// que o `ActivePlaylistEditor` grava repetições e trocas de face.
///
/// **Lista que fica sem entradas:** rascunho é apagado (era um rascunho vazio,
/// não existe motivo para ele ocupar a aba); lista **salva fica**, vazia. Uma
/// salva é do usuário: esvaziá-la por engano no carousel não pode virar um
/// tombstone empurrado para a nuvem e para os outros dispositivos.
class UpdatePlaylist {
  const UpdatePlaylist(this._repository);

  final PlaylistRepository _repository;

  Future<void> call({
    required String playlistId,
    String? nome,
    List<PlaylistEntry>? entries,
    List<String>? pdfIds,
    List<String>? audioIds,
  }) async {
    if (nome == null && entries == null && pdfIds == null && audioIds == null) {
      throw ArgumentError(
        'At least one of nome, entries, pdfIds or audioIds must be provided',
      );
    }

    if (entries != null) {
      if (entries.isEmpty && await _deleteIfDraft(playlistId)) return;
    } else if (pdfIds != null || audioIds != null) {
      final existing = await _repository.getById(playlistId);
      final nextPdfs = pdfIds ?? existing?.pdfIds ?? const <String>[];
      final nextAudios = audioIds ?? existing?.audioIds ?? const <String>[];
      if (nextPdfs.isEmpty &&
          nextAudios.isEmpty &&
          (existing == null || !existing.salva)) {
        await _repository.delete(playlistId);
        return;
      }
    }

    await _repository.update(
      playlistId,
      nome: nome,
      entries: entries,
      pdfIds: pdfIds,
      audioIds: audioIds,
    );
  }

  /// Apaga a lista se ela for rascunho (ou se já não existir — `delete` é
  /// idempotente). Devolve `true` quando não há mais o que gravar.
  Future<bool> _deleteIfDraft(String playlistId) async {
    final existing = await _repository.getById(playlistId);
    if (existing != null && existing.salva) return false;
    await _repository.delete(playlistId);
    return true;
  }
}
