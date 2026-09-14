import '../../../../core/constants/app_config.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../entities/playlist_share_link.dart';
import '../entities/saved_playlist.dart';
import '../exceptions/empty_playlist_share_exception.dart';
import '../exceptions/playlist_not_found_exception.dart';
import '../ports/share_link_shortener.dart';
import '../repositories/playlist_repository.dart';

final _log = AppLogger.of('playlists');

/// `pdfId → shortId` do catálogo; `null` quando o material não tem.
typedef ShortIdLookup = String? Function(String pdfId);

/// UC-07 — Gerar URL de compartilhamento (Fase 4.4; link curto, D7).
class GeneratePlaylistShareUrl {
  const GeneratePlaylistShareUrl(
    this._repository, {
    this.shareOrigin = AppConfig.apiBaseUrl,
    this.shortener,
    this.shortIdOf,
  });

  final PlaylistRepository _repository;
  final String shareOrigin;

  /// Encurtador opcional (D7) — só é chamado quando [call] recebe
  /// `short: true`. `null` (ou qualquer erro do encurtador) sempre cai na
  /// URL longa.
  final ShareLinkShortener? shortener;

  /// Lookup de `shortId` (spec short-id-share D7). `null` = sem catálogo →
  /// sempre formato longo.
  final ShortIdLookup? shortIdOf;

  /// Formato curto quando **todas** as entradas são PDF com `shortId`; senão
  /// o longo (`shareitems` + legados), com a tentativa de `/l/` se `short`.
  ///
  /// Lança [PlaylistNotFoundException] ou [EmptyPlaylistShareException].
  Future<PlaylistShareLink> call({
    required String playlistId,
    bool short = false,
  }) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) {
      throw const PlaylistNotFoundException();
    }
    if (playlist.entries.isEmpty) {
      throw const EmptyPlaylistShareException();
    }

    final shortIds = _shortIdsFor(playlist.entries);
    if (shortIds != null) {
      return PlaylistShareLink(
        url: buildShortPlaylistShareUrl(
          origin: shareOrigin,
          shortIds: shortIds,
          shareName: playlist.nome,
        ),
        isShort: true,
      );
    }

    final longUrl = buildPlaylistShareUrlFromEntries(
      origin: shareOrigin,
      entries: playlist.entries,
      shareName: playlist.nome,
    );

    final shortenerInstance = shortener;
    if (!short || shortenerInstance == null) {
      return PlaylistShareLink(url: longUrl, isShort: false);
    }

    try {
      final shortened = await shortenerInstance.shorten(
        Uri.parse(longUrl).query,
      );
      return PlaylistShareLink(url: shortened, isShort: false);
    } on Object catch (e, stackTrace) {
      _log.warn('encurtador falhou — caindo na URL longa', e);
      _log.debug('$stackTrace');
      return PlaylistShareLink(url: longUrl, isShort: false);
    }
  }

  /// `null` se alguma entrada não é PDF ou não tem `shortId` (D7).
  List<String>? _shortIdsFor(List<PlaylistEntry> entries) {
    final lookup = shortIdOf;
    if (lookup == null) return null;
    final shortIds = <String>[];
    for (final entry in entries) {
      if (entry.kind != MaterialKind.pdf) return null;
      final shortId = lookup(entry.id);
      if (shortId == null || !isShortId(shortId)) return null;
      shortIds.add(shortId);
    }
    return shortIds;
  }
}
