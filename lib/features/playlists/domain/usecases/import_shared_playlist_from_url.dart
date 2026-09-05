import '../../../../core/utils/playlist_share_url_builder.dart';
import '../exceptions/invalid_share_playlist_exception.dart';
import '../repositories/playlist_repository.dart';

/// UC-07 — Importar playlist compartilhada (Fase 4.4).
class ImportSharedPlaylistFromUrl {
  const ImportSharedPlaylistFromUrl(this._playlistRepository);

  final PlaylistRepository _playlistRepository;

  /// Persiste a nova playlist e devolve o [playlistId].
  ///
  /// [shareItems] (v2, spec A.5) preserva a ordem intercalada e o tipo de cada
  /// material; quando ausente ou inválido, [sharePdfs]/[shareAudios] valem como
  /// antes. Quem chama torna a lista ativa (D3) — não existe mais carousel a
  /// carregar.
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
    return playlistId;
  }
}
