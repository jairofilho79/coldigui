import '../../../carousel/domain/repositories/carousel_repository.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../playlists/domain/repositories/playlist_repository.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/catalog_pdf_id_remap.dart';

/// Reconcilia `pdfId`s obsoletos após atualização do manifest.
///
/// Quando um louvor é substituído (novo caminho → novo `pdfId`), remapeia o
/// índice offline, playlists e carousel para o id atual.
class RemapPdfIdsAfterCatalogUpdate {
  const RemapPdfIdsAfterCatalogUpdate(
    this._offlineRepository,
    this._playlistRepository,
    this._carouselRepository,
  );

  final OfflinePdfRepository _offlineRepository;
  final PlaylistRepository _playlistRepository;
  final CarouselRepository _carouselRepository;

  Future<void> call({
    required List<Louvor> previousLouvores,
    required List<Louvor> newLouvores,
  }) async {
    final remappings = computeCatalogPdfIdRemappings(
      previousLouvores: previousLouvores,
      newLouvores: newLouvores,
    );
    if (remappings.isEmpty) return;

    for (final entry in remappings.entries) {
      await _offlineRepository.remapPdfId(
        fromPdfId: entry.key,
        toPdfId: entry.value,
      );
    }

    final playlists = await _playlistRepository.getAll();
    for (final playlist in playlists) {
      final remapped = remapPdfIdList(playlist.pdfIds, remappings);
      if (!_listsEqual(playlist.pdfIds, remapped)) {
        await _playlistRepository.update(
          playlist.playlistId,
          pdfIds: remapped,
        );
      }
    }

    final carouselPdfIds = await _carouselRepository.getOrderedPdfIds();
    final remappedCarousel = remapPdfIdList(carouselPdfIds, remappings);
    if (!_listsEqual(carouselPdfIds, remappedCarousel)) {
      await _carouselRepository.replaceAll(remappedCarousel);
    }
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
