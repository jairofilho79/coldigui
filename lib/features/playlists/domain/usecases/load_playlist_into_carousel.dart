import '../../../carousel/domain/repositories/carousel_repository.dart';
import '../exceptions/playlist_not_found_exception.dart';
import '../repositories/playlist_repository.dart';

/// UC-06 — Carregar playlist salva no carousel temporário (Fase 4.3).
///
/// Orquestra [PlaylistRepository.getById] e [CarouselRepository.replaceAll].
/// PDFs órfãos (ausentes no manifest) entram no carousel com label fallback
/// — validação de catálogo fica na camada de apresentação (abrir leitor).
class LoadPlaylistIntoCarousel {
  const LoadPlaylistIntoCarousel(
    this._playlistRepository,
    this._carouselRepository,
  );

  final PlaylistRepository _playlistRepository;
  final CarouselRepository _carouselRepository;

  /// Substitui toda a seleção do carousel pelos [SavedPlaylist.pdfIds] ordenados.
  ///
  /// Lança [PlaylistNotFoundException] se a playlist não existir.
  Future<void> call({required String playlistId}) async {
    final playlist = await _playlistRepository.getById(playlistId);
    if (playlist == null) {
      throw const PlaylistNotFoundException();
    }

    await _carouselRepository.replaceAll(
      List<String>.from(playlist.pdfIds),
    );
  }
}
