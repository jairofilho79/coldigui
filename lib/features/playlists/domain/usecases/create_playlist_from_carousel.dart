import '../../../carousel/domain/repositories/carousel_repository.dart';
import '../exceptions/empty_carousel_exception.dart';
import '../repositories/playlist_repository.dart';
import '../utils/playlist_defaults.dart';

/// UC-06 — Criar playlist a partir do carousel atual (Fase 4.2).
class CreatePlaylistFromCarousel {
  const CreatePlaylistFromCarousel(
    this._carouselRepository,
    this._playlistRepository,
  );

  final CarouselRepository _carouselRepository;
  final PlaylistRepository _playlistRepository;

  /// Retorna [playlistId] da playlist criada.
  ///
  /// Lança [EmptyCarouselException] se a seleção estiver vazia.
  Future<String> call({String? nome}) async {
    final pdfIds = await _carouselRepository.getOrderedPdfIds();
    if (pdfIds.isEmpty) {
      throw const EmptyCarouselException();
    }

    return _playlistRepository.create(
      nome: nome ?? defaultPlaylistName(),
      pdfIds: pdfIds,
    );
  }
}
