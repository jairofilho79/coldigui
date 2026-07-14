import '../../../../core/utils/playlist_share_url_builder.dart';
import '../exceptions/invalid_share_playlist_exception.dart';
import '../repositories/playlist_repository.dart';
import 'load_playlist_into_carousel.dart';

/// UC-07 — Importar playlist compartilhada (Fase 4.4).
class ImportSharedPlaylistFromUrl {
  const ImportSharedPlaylistFromUrl(
    this._playlistRepository,
    this._loadIntoCarousel,
  );

  final PlaylistRepository _playlistRepository;
  final LoadPlaylistIntoCarousel _loadIntoCarousel;

  /// Persiste nova playlist e carrega PDFs no carousel. Retorna [playlistId].
  ///
  /// Lança [InvalidSharePlaylistException] se params inválidos.
  Future<String> call({
    required String sharePdfs,
    required String shareName,
    String shareAudios = '',
  }) async {
    final pdfIds = parsePdfIdsFromSharePdfs(sharePdfs);
    final audioIds = parseAudioIdsFromShareAudios(shareAudios);
    final nome = shareName.trim();
    if ((pdfIds.isEmpty && audioIds.isEmpty) || nome.isEmpty) {
      throw const InvalidSharePlaylistException();
    }

    final now = DateTime.now();
    final playlistId = await _playlistRepository.create(
      nome: nome,
      pdfIds: pdfIds,
      audioIds: audioIds,
      salva: true,
      savedAt: now,
    );
    if (pdfIds.isNotEmpty) {
      await _loadIntoCarousel(playlistId: playlistId);
    }
    return playlistId;
  }
}
