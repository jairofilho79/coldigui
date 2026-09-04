import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../playlists/domain/exceptions/invalid_share_playlist_exception.dart';
import '../../../playlists/domain/usecases/import_shared_playlist_from_url.dart';

/// Resultado tipado de [SyncDeepLinkState.call] (UC-14, Fase 4.5).
enum SyncDeepLinkOutcome {
  /// URI sem params de share de playlist.
  skipped,

  /// Playlist importada e carousel carregado.
  success,

  /// Params de share presentes porém inválidos.
  invalid,

  /// Import falhou por [StorageUnavailableException] ou outra exceção —
  /// ver [SyncDeepLinkResult.reason] (Tarefa 8, spec C.4).
  failed,
}

/// Resultado tipado do sync de deep link (UC-14, Fase 4.5).
class SyncDeepLinkResult {
  const SyncDeepLinkResult({
    required this.outcome,
    this.playlistId,
    this.reason,
  });

  /// Desfecho do processamento da URI.
  final SyncDeepLinkOutcome outcome;

  /// ID da playlist criada quando [outcome] é [SyncDeepLinkOutcome.success].
  final String? playlistId;

  /// Exceção capturada quando [outcome] é [SyncDeepLinkOutcome.failed].
  final Object? reason;

  static const skipped = SyncDeepLinkResult(
    outcome: SyncDeepLinkOutcome.skipped,
  );
  static const invalid = SyncDeepLinkResult(
    outcome: SyncDeepLinkOutcome.invalid,
  );

  static SyncDeepLinkResult success(String playlistId) => SyncDeepLinkResult(
    outcome: SyncDeepLinkOutcome.success,
    playlistId: playlistId,
  );

  static SyncDeepLinkResult failed(Object reason) =>
      SyncDeepLinkResult(outcome: SyncDeepLinkOutcome.failed, reason: reason);
}

/// UC-14 — Sincronizar deep link de playlist com estado local (Fase 4.5).
///
/// Detecta `sharepdfs` + `sharename` na URI e delega a
/// [ImportSharedPlaylistFromUrl]. Sem UI — confirmação de carousel não se
/// aplica (paridade PWA: import automático).
class SyncDeepLinkState {
  const SyncDeepLinkState(this._importSharedPlaylist);

  final ImportSharedPlaylistFromUrl _importSharedPlaylist;

  /// Processa [uri] ou [queryParams] e importa playlist quando aplicável.
  Future<SyncDeepLinkResult> call({
    Uri? uri,
    Map<String, String>? queryParams,
  }) async {
    final resolvedUri = uri ?? Uri(queryParameters: queryParams ?? const {});
    final params = parsePlaylistShareParams(resolvedUri);
    if (params == null) {
      return SyncDeepLinkResult.skipped;
    }

    try {
      final playlistId = await _importSharedPlaylist(
        sharePdfs: params.sharePdfs,
        shareAudios: params.shareAudios,
        shareName: params.shareName,
      );
      return SyncDeepLinkResult.success(playlistId);
    } on InvalidSharePlaylistException {
      return SyncDeepLinkResult.invalid;
    } on StorageUnavailableException catch (e) {
      return SyncDeepLinkResult.failed(e);
    } on Object catch (e) {
      return SyncDeepLinkResult.failed(e);
    }
  }
}
