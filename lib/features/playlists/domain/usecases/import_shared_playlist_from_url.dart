import '../../../../core/utils/playlist_share_url_builder.dart';
import '../entities/playlist_entry.dart';
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

  /// Persiste nova playlist e carrega o carousel. Retorna [playlistId].
  ///
  /// [shareItems] (v2, spec A.5) preserva a ordem intercalada e o tipo de cada
  /// material; quando ausente ou inválido, [sharePdfs]/[shareAudios] valem como
  /// antes. O carousel é carregado sempre que houver **qualquer** entrada de
  /// partitura (PDF, cifra, gesto, YouTube ou id legado) — não só quando
  /// `sharepdfs` estiver preenchido.
  ///
  /// Lança [InvalidSharePlaylistException] se params inválidos.
  Future<String> call({
    required String shareName,
    String sharePdfs = '',
    String shareAudios = '',
    String shareItems = '',
  }) async {
    final params = PlaylistShareParams(
      sharePdfs: sharePdfs,
      shareAudios: shareAudios,
      shareName: shareName,
      shareItems: shareItems.isEmpty ? null : shareItems,
    );
    final entries = params.entries;
    final nome = shareName.trim();
    if (entries.isEmpty || nome.isEmpty) {
      throw const InvalidSharePlaylistException();
    }

    final now = DateTime.now();
    final playlistId = await _playlistRepository.create(
      nome: nome,
      entries: entries,
      salva: true,
      savedAt: now,
    );
    if (entries.any((PlaylistEntry e) => !e.isAudio)) {
      await _loadIntoCarousel(playlistId: playlistId);
    }
    return playlistId;
  }
}
