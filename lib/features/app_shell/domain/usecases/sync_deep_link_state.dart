import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../playlists/domain/exceptions/invalid_share_playlist_exception.dart';
import '../../../playlists/domain/exceptions/legacy_share_link_exception.dart';
import '../../../playlists/domain/usecases/import_shared_playlist_from_url.dart';

/// Resultado tipado de [SyncDeepLinkState.call] (UC-14, Fase 4.5).
enum SyncDeepLinkOutcome {
  /// URI sem params de share de playlist.
  skipped,

  /// Playlist importada e carousel carregado.
  success,

  /// Params de share presentes porém inválidos.
  invalid,

  /// Link de uma versão antiga (`?s=`, `sharepdfs`… — spec fim-fonte-plpcg
  /// §4.4): nada importado; a UI avisa com `playlistShareLegacyLinkUnsupported`
  /// e limpa a URL.
  legacy,

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
    this.alreadyExisted = false,
    this.nome,
  });

  /// Desfecho do processamento da URI.
  final SyncDeepLinkOutcome outcome;

  /// ID da playlist criada (ou reaproveitada) quando [outcome] é
  /// [SyncDeepLinkOutcome.success].
  final String? playlistId;

  /// Exceção capturada quando [outcome] é [SyncDeepLinkOutcome.failed].
  final Object? reason;

  /// `true` quando [outcome] é [SyncDeepLinkOutcome.success] e o import
  /// reaproveitou uma lista salva já existente em vez de criar uma nova
  /// (dedupe de conteúdo, spec C.2, Tarefa 8).
  final bool alreadyExisted;

  /// Nome da lista — só preenchido quando [alreadyExisted] (a UI usa para a
  /// snackbar «Lista já estava salva: {nome}»).
  final String? nome;

  static const skipped = SyncDeepLinkResult(
    outcome: SyncDeepLinkOutcome.skipped,
  );
  static const invalid = SyncDeepLinkResult(
    outcome: SyncDeepLinkOutcome.invalid,
  );
  static const legacy = SyncDeepLinkResult(outcome: SyncDeepLinkOutcome.legacy);

  static SyncDeepLinkResult success(
    String playlistId, {
    bool alreadyExisted = false,
    String? nome,
  }) => SyncDeepLinkResult(
    outcome: SyncDeepLinkOutcome.success,
    playlistId: playlistId,
    alreadyExisted: alreadyExisted,
    nome: nome,
  );

  static SyncDeepLinkResult failed(Object reason) =>
      SyncDeepLinkResult(outcome: SyncDeepLinkOutcome.failed, reason: reason);
}

/// UC-14 — Sincronizar deep link de lista com o estado local (Fase 4.5).
///
/// Detecta `p` (link por praise) ou um param de link antigo na URI e delega a
/// [ImportSharedPlaylistFromUrl]. Sem UI — import automático (paridade PWA).
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
      final result = await _importSharedPlaylist(params: params);
      return SyncDeepLinkResult.success(
        result.playlist.playlistId,
        alreadyExisted: result.alreadyExisted,
        nome: result.playlist.nome,
      );
    } on InvalidSharePlaylistException {
      return SyncDeepLinkResult.invalid;
    } on LegacyShareLinkException {
      return SyncDeepLinkResult.legacy;
    } on StorageUnavailableException catch (e) {
      return SyncDeepLinkResult.failed(e);
    } on Object catch (e) {
      return SyncDeepLinkResult.failed(e);
    }
  }
}
