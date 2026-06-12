import '../repositories/playlist_repository.dart';
import '../utils/playlist_defaults.dart';
import 'load_playlist_into_carousel.dart';

/// Resultado de [EnsurePlaylistForLouvor].
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

/// UC-06 — Garante playlist ativa contendo [pdfId] (Fase 4.8).
///
/// Se [activePlaylistId] existe e contém [pdfId], reutiliza.
/// Caso contrário, cria lista não salva com nome padrão.
class EnsurePlaylistForLouvor {
  const EnsurePlaylistForLouvor(
    this._playlistRepository,
    this._loadIntoCarousel,
  );

  final PlaylistRepository _playlistRepository;
  final LoadPlaylistIntoCarousel _loadIntoCarousel;

  /// Garante carousel carregado com playlist contendo [pdfId].
  ///
  /// Reutiliza [activePlaylistId] quando o louvor já está na lista;
  /// caso contrário cria rascunho com [defaultPlaylistName] e `[pdfId]`.
  Future<EnsurePlaylistResult> call({
    required String pdfId,
    String? activePlaylistId,
  }) async {
    if (activePlaylistId != null) {
      final active = await _playlistRepository.getById(activePlaylistId);
      if (active != null && active.pdfIds.contains(pdfId)) {
        await _loadIntoCarousel(playlistId: activePlaylistId);
        return EnsurePlaylistResult(
          playlistId: activePlaylistId,
          createdNew: false,
        );
      }
    }

    final playlistId = await _playlistRepository.create(
      nome: defaultPlaylistName(),
      pdfIds: [pdfId],
      salva: false,
    );
    await _loadIntoCarousel(playlistId: playlistId);
    return EnsurePlaylistResult(playlistId: playlistId, createdNew: true);
  }
}
