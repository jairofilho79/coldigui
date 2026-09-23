import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../entities/saved_playlist.dart';
import '../exceptions/invalid_share_playlist_exception.dart';
import '../exceptions/legacy_share_link_exception.dart';
import '../ports/praise_entry_resolver.dart';
import '../repositories/playlist_repository.dart';
import '../utils/content_fingerprint.dart';

final _log = AppLogger.of('playlists');

/// Resultado de [ImportSharedPlaylistFromUrl.call] (D7, spec C.2).
class ImportResult {
  const ImportResult({required this.playlist, required this.alreadyExisted});

  /// A lista salva — nova, ou a já existente reaproveitada.
  final SavedPlaylist playlist;

  /// `true` quando já havia uma lista salva com o mesmo conteúdo: nenhuma
  /// lista nova foi criada, [playlist] é a existente.
  final bool alreadyExisted;
}

/// UC-07 — importar lista de um link por praise (spec fim-fonte-plpcg §4.3).
class ImportSharedPlaylistFromUrl {
  const ImportSharedPlaylistFromUrl(
    this._playlistRepository, {
    required this.loadPraiseEntryResolver,
  });

  final PlaylistRepository _playlistRepository;
  final PraiseEntryResolverLoader loadPraiseEntryResolver;

  /// Persiste a nova lista (ou reaproveita uma existente) e devolve o
  /// [ImportResult].
  ///
  /// Cada token do `p` vira a entrada que [loadPraiseEntryResolver] escolhe
  /// (favorito da conta, senão PDF principal → único áudio → primeiro
  /// adicionável). Token desconhecido ou praise sem material adicionável é
  /// saltado; repetições ficam. O material escolhido por quem enviou não
  /// viaja — o link é por louvor. Quem chama torna a lista ativa (D3).
  ///
  /// **Dedupe por conteúdo (spec C.2):** antes de criar, procura entre as
  /// listas salvas e não apagadas uma com o mesmo [contentFingerprint]
  /// (`kind:id` por entrada, na ordem — o nome do link não entra na conta).
  /// Se existir, não cria: devolve a existente com `alreadyExisted: true`.
  ///
  /// [excludePlaylistId] tira da dedupe a lista na graça de uma exclusão
  /// adiada (C11), que o repositório ainda não sabe apagada.
  ///
  /// Lança [LegacyShareLinkException] para link antigo (§4.4) e
  /// [InvalidSharePlaylistException] sem token, com nome em branco ou sem
  /// nenhum token resolvido — inclusive quando o catálogo não chegou no prazo
  /// (§8).
  Future<ImportResult> call({
    required PlaylistShareParams params,
    String? excludePlaylistId,
  }) async {
    if (params.isLegacy) throw const LegacyShareLinkException();
    final nome = params.shareName.trim();
    // Sem token ou sem nome nem vale acordar o resolver, que espera o catálogo.
    if (!params.hasMaterial || nome.isEmpty) {
      throw const InvalidSharePlaylistException();
    }

    final resolve = await loadPraiseEntryResolver();
    final entries = <PlaylistEntry>[
      for (final shortId in params.praiseShortIds) ?resolve(shortId),
    ];
    if (entries.isEmpty) throw const InvalidSharePlaylistException();
    final skipped = params.praiseShortIds.length - entries.length;
    if (skipped > 0) {
      _log.warn(
        'import: $skipped de ${params.praiseShortIds.length} louvores do '
        'link sem entrada — saltados',
      );
    }

    final fingerprint = contentFingerprint(entries);
    final saved = await _playlistRepository.getAll();
    for (final playlist in saved) {
      if (!playlist.salva || playlist.deletedAt != null) continue;
      if (playlist.playlistId == excludePlaylistId) continue;
      if (contentFingerprint(playlist.entries) == fingerprint) {
        return ImportResult(playlist: playlist, alreadyExisted: true);
      }
    }

    final now = DateTime.now();
    final playlistId = await _playlistRepository.create(
      nome: nome,
      entries: entries,
      salva: true,
      savedAt: now,
    );
    final created = await _playlistRepository.getById(playlistId);
    return ImportResult(playlist: created!, alreadyExisted: false);
  }
}
