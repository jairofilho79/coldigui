import '../entities/playlist_entry.dart';
import '../repositories/playlist_repository.dart';
import '../utils/playlist_defaults.dart';

/// Resultado de [EnsureActivePlaylist].
class EnsurePlaylistResult {
  const EnsurePlaylistResult({
    required this.playlistId,
    required this.createdNew,
  });

  /// ID da playlist ativa após a operação.
  final String playlistId;

  /// `true` quando um rascunho novo foi criado (`salva: false`).
  final bool createdNew;
}

/// UC-06 — Garante uma lista ativa contendo [entry] (D3).
///
/// Substitui `EnsurePlaylistForLouvor`: não existe mais carousel para carregar,
/// e a entrada chega **tipada** (o `kind` do chamador vence a extensão, A8).
///
/// - Sem lista ativa (ou id órfão): cria rascunho `entries: [entry]` com
///   [defaultPlaylistName].
/// - Com lista ativa que já tem o id: reutiliza sem escrever.
/// - Com lista ativa sem o id: acrescenta a entrada ao fim.
class EnsureActivePlaylist {
  const EnsureActivePlaylist(this._playlistRepository);

  final PlaylistRepository _playlistRepository;

  Future<EnsurePlaylistResult> call({
    required PlaylistEntry entry,
    String? activePlaylistId,
  }) async {
    if (activePlaylistId != null) {
      final active = await _playlistRepository.getById(activePlaylistId);
      if (active != null) {
        if (!active.entries.any((e) => e.id == entry.id)) {
          await _playlistRepository.update(
            activePlaylistId,
            entries: [...active.entries, entry],
          );
        }
        return EnsurePlaylistResult(
          playlistId: activePlaylistId,
          createdNew: false,
        );
      }
    }

    final playlistId = await _playlistRepository.create(
      nome: defaultPlaylistName(),
      entries: [entry],
      salva: false,
    );
    return EnsurePlaylistResult(playlistId: playlistId, createdNew: true);
  }
}
