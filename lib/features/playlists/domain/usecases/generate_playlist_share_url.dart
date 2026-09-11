import '../../../../core/constants/app_config.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../exceptions/empty_playlist_share_exception.dart';
import '../exceptions/playlist_not_found_exception.dart';
import '../ports/share_link_shortener.dart';
import '../repositories/playlist_repository.dart';

final _log = AppLogger.of('playlists');

/// UC-07 — Gerar URL de compartilhamento (Fase 4.4; link curto, D7).
class GeneratePlaylistShareUrl {
  const GeneratePlaylistShareUrl(
    this._repository, {
    this.shareOrigin = AppConfig.apiBaseUrl,
    this.shortener,
  });

  final PlaylistRepository _repository;
  final String shareOrigin;

  /// Encurtador opcional (D7) — só é chamado quando [call] recebe
  /// `short: true`. `null` (ou qualquer erro do encurtador) sempre cai na
  /// URL longa.
  final ShareLinkShortener? shortener;

  /// Retorna URL absoluta com `shareitems` (ordem única tipada) mais os
  /// legados `sharepdfs`/`shareaudios`.
  ///
  /// `short: true` tenta encurtar via [shortener] (spec C.2); qualquer erro —
  /// rede, timeout, ausência de [shortener] — cai na URL longa em vez de
  /// impedir o compartilhamento, logado com `AppLogger.of('playlists')`.
  /// `short: false` (default) nunca chama o encurtador.
  ///
  /// Lança [PlaylistNotFoundException] ou [EmptyPlaylistShareException].
  Future<String> call({required String playlistId, bool short = false}) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) {
      throw const PlaylistNotFoundException();
    }
    if (playlist.entries.isEmpty) {
      throw const EmptyPlaylistShareException();
    }

    final longUrl = buildPlaylistShareUrlFromEntries(
      origin: shareOrigin,
      entries: playlist.entries,
      shareName: playlist.nome,
    );

    final shortenerInstance = shortener;
    if (!short || shortenerInstance == null) {
      return longUrl;
    }

    try {
      return await shortenerInstance.shorten(Uri.parse(longUrl).query);
    } on Object catch (e, stackTrace) {
      _log.warn('encurtador falhou — caindo na URL longa', e);
      _log.debug('$stackTrace');
      return longUrl;
    }
  }
}
