import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../exceptions/empty_playlist_share_exception.dart';
import '../exceptions/playlist_not_found_exception.dart';
import '../repositories/playlist_repository.dart';

/// UC-07 — Gerar URL de compartilhamento (Fase 4.4).
class GeneratePlaylistShareUrl {
  const GeneratePlaylistShareUrl(
    this._repository, {
    this.shareOrigin = AppConfig.apiBaseUrl,
  });

  final PlaylistRepository _repository;
  final String shareOrigin;

  /// Retorna URL absoluta `/?sharepdfs=...&sharename=...`.
  ///
  /// Lança [PlaylistNotFoundException] ou [EmptyPlaylistShareException].
  Future<String> call({required String playlistId}) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) {
      throw const PlaylistNotFoundException();
    }
    if (playlist.pdfIds.isEmpty) {
      throw const EmptyPlaylistShareException();
    }

    return buildPlaylistShareUrl(
      origin: shareOrigin,
      pdfIds: playlist.pdfIds,
      shareName: playlist.nome,
    );
  }
}
