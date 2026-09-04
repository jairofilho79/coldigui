import 'package:flutter/foundation.dart';

import '../entities/remote_playlist.dart';
import '../entities/saved_playlist.dart';
import '../repositories/playlist_repository.dart';

/// Resultado de [SyncPlaylists].
class PlaylistSyncResult {
  const PlaylistSyncResult({
    this.pulled = 0,
    this.pushed = 0,
    this.deleted = 0,
    this.skipped = false,
    this.conflicts = 0,
    this.pullError,
    this.pushError,
  });

  final int pulled;
  final int pushed;
  final int deleted;
  final bool skipped;

  /// Listas que ficaram em [PlaylistSyncStatus.conflict] nesta rodada.
  final int conflicts;

  /// Erro **cru** da fase de pull, se ela falhou (a sync seguiu mesmo assim).
  ///
  /// Cru de propósito: quem traduz é a UI, com `userMessageFor`.
  final Object? pullError;

  /// Último erro cru de push/delete que não era conflito.
  final Object? pushError;

  /// Primeiro erro a mostrar ao usuário — pull perde para nada, é o mais cedo.
  Object? get error => pullError ?? pushError;

  static const skippedAuth = PlaylistSyncResult(skipped: true);
}

/// Sync offline-first: pull → push → tombstones (UC-15).
///
/// Pré-condição: [idToken] não-nulo. Sem token, retorna [PlaylistSyncResult.skippedAuth]
/// sem tocar a rede.
///
/// **Tolerância (spec A.7):** as três fases são independentes — um pull que
/// falha não impede o push nem os tombstones, e o erro volta no resultado em
/// vez de sumir. Um `409` no push vira last-write-wins por `updatedAt`.
class SyncPlaylists {
  SyncPlaylists(this._repository, this._fetch, this._upsert, this._delete);

  /// Tentativas de DELETE remoto por tombstone **por boot**.
  ///
  /// Um tombstone que o servidor recusa indefinidamente não pode gastar uma
  /// requisição a cada sync pelo resto da sessão; o registro fica no disco e a
  /// próxima abertura tenta de novo.
  static const int maxTombstoneAttemptsPerBoot = 3;

  /// Falhas de DELETE por `playlistId` desde que o app abriu (o provider que
  /// guarda esta instância vive o boot inteiro).
  final Map<String, int> _tombstoneFailures = <String, int>{};

  final PlaylistRepository _repository;
  final Future<List<RemotePlaylist>> Function(String idToken) _fetch;
  final Future<RemotePlaylist> Function({
    required String idToken,
    required RemotePlaylist playlist,
  })
  _upsert;
  final Future<void> Function({
    required String idToken,
    required String playlistId,
  })
  _delete;

  Future<PlaylistSyncResult> call({required String? idToken}) async {
    if (idToken == null || idToken.isEmpty) {
      return PlaylistSyncResult.skippedAuth;
    }

    var pulled = 0;
    var pushed = 0;
    var deleted = 0;
    var conflicts = 0;
    Object? pullError;
    Object? pushError;

    // Fase A — Pull. Isolada: se cair, push e tombstones ainda rodam.
    try {
      pulled = await _pull(idToken);
    } on Object catch (e) {
      pullError = e;
      debugPrint('[playlists] pull falhou, seguindo com push: $e');
    }

    // Fase B — Push
    final pending = await _repository.getPendingPush();
    for (final local in pending) {
      if (!local.salva) continue;
      try {
        pushed += await _push(idToken: idToken, local: local);
      } on PlaylistConflictException catch (e) {
        final outcome = await _resolveConflict(
          idToken: idToken,
          local: local,
          remote: e.remote,
        );
        pulled += outcome.pulled;
        pushed += outcome.pushed;
        conflicts += outcome.conflicts;
      } on Object catch (e) {
        // Mantém pendingPush; próxima sync tenta de novo.
        pushError = e;
        debugPrint('[playlists] push de ${local.playlistId} falhou: $e');
      }
    }

    // Fase C — Deletes
    final tombstones = await _repository.getTombstones();
    for (final tomb in tombstones) {
      final failures = _tombstoneFailures[tomb.playlistId] ?? 0;
      if (failures >= maxTombstoneAttemptsPerBoot) continue;
      try {
        await _delete(idToken: idToken, playlistId: tomb.playlistId);
        await _repository.hardDelete(tomb.playlistId);
        _tombstoneFailures.remove(tomb.playlistId);
        deleted++;
      } on Object catch (e) {
        // Mantém tombstone; desiste depois de [maxTombstoneAttemptsPerBoot].
        _tombstoneFailures[tomb.playlistId] = failures + 1;
        pushError = e;
        debugPrint(
          '[playlists] DELETE de ${tomb.playlistId} falhou '
          '(${failures + 1}/$maxTombstoneAttemptsPerBoot): $e',
        );
      }
    }

    return PlaylistSyncResult(
      pulled: pulled,
      pushed: pushed,
      deleted: deleted,
      conflicts: conflicts,
      pullError: pullError,
      pushError: pushError,
    );
  }

  /// Fase A isolada — devolve quantas listas vieram do servidor.
  Future<int> _pull(String idToken) async {
    var pulled = 0;
    final remote = await _fetch(idToken);

    for (final r in remote) {
      if (!r.salva) continue;
      final local = await _repository.getById(r.id);
      if (local == null) {
        await _repository.upsert(_fromRemote(r));
        pulled++;
        continue;
      }
      if (local.deletedAt != null) {
        // Tombstone local pendente — não sobrescrever com pull.
        continue;
      }
      final localPending = local.syncStatus == PlaylistSyncStatus.pendingPush;
      if (localPending && !local.updatedAt.isBefore(r.updatedAt)) {
        continue;
      }
      if (local.updatedAt.isBefore(r.updatedAt) ||
          (local.updatedAt.isAtSameMomentAs(r.updatedAt) &&
              local.version < r.version)) {
        await _repository.upsert(_fromRemote(r));
        pulled++;
      }
    }
    return pulled;
  }

  /// `PUT` de uma lista e gravação do que o servidor devolveu. Devolve `1`.
  Future<int> _push({
    required String idToken,
    required SavedPlaylist local,
    int? version,
  }) async {
    final saved = await _upsert(
      idToken: idToken,
      playlist: _toRemote(local, version: version),
    );
    await _repository.upsert(
      local.copyWith(
        version: saved.version,
        updatedAt: saved.updatedAt,
        syncStatus: PlaylistSyncStatus.synced,
        clearDeletedAt: true,
      ),
    );
    return 1;
  }

  /// Last-write-wins por `updatedAt` sobre um `409`.
  ///
  /// Remoto mais novo → a linha do servidor vence e o local vira `synced`.
  /// Local mais novo → **uma** nova tentativa com a `version` do remoto; se ela
  /// também falhar, a lista fica em [PlaylistSyncStatus.conflict] (o banner
  /// conta) e a sync segue para as outras.
  Future<_ConflictOutcome> _resolveConflict({
    required String idToken,
    required SavedPlaylist local,
    required RemotePlaylist remote,
  }) async {
    // `!remote.salva` é ignorado pelo pull (`_pull`), e o 409 segue a mesma
    // regra: um rascunho remoto não ressuscita por cima de uma lista salva.
    if (remote.salva && remote.updatedAt.isAfter(local.updatedAt)) {
      await _repository.upsert(_fromRemote(remote));
      debugPrint(
        '[playlists] conflito em ${local.playlistId}: remoto mais novo venceu',
      );
      return const _ConflictOutcome(pulled: 1);
    }
    // Contra o Worker atual este ramo é inalcançável — ele só devolve 409
    // quando o cliente é o mais **velho** —, mas o spec pede o re-envio e ele
    // protege de um servidor que passe a recusar por versão.
    try {
      final pushed = await _push(
        idToken: idToken,
        local: local,
        version: remote.version,
      );
      return _ConflictOutcome(pushed: pushed);
    } on Object catch (e) {
      await _repository.upsert(
        local.copyWith(syncStatus: PlaylistSyncStatus.conflict),
      );
      debugPrint(
        '[playlists] conflito em ${local.playlistId} não resolvido: $e',
      );
      return const _ConflictOutcome(conflicts: 1);
    }
  }

  static SavedPlaylist _fromRemote(RemotePlaylist r) => SavedPlaylist(
    playlistId: r.id,
    nome: r.nome,
    // A ordem única já vem tipada do payload — o veredito de áudio do Worker
    // viaja no `kind` de cada entrada (A8).
    entries: List<PlaylistEntry>.from(r.entries),
    createdAt: r.createdAt,
    salva: true,
    savedAt: r.savedAt,
    favoritedAt: r.favoritedAt,
    favorita: r.favorita,
    updatedAt: r.updatedAt,
    version: r.version,
    syncStatus: PlaylistSyncStatus.synced,
    isPublished: r.isPublished,
    publicationReach: r.publicationReach,
    publicationCategory: r.publicationCategory,
    publishedAt: r.publishedAt,
  );

  /// [version] força a versão enviada — é o re-envio pós-`409`, que só passa
  /// no Worker se carregar a versão que ele já tem.
  static RemotePlaylist _toRemote(SavedPlaylist p, {int? version}) =>
      RemotePlaylist(
        id: p.playlistId,
        nome: p.nome,
        entries: p.entries,
        salva: true,
        favorita: p.favorita,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
        version: version ?? p.version,
        savedAt: p.savedAt,
        favoritedAt: p.favoritedAt,
        isPublished: p.isPublished,
        publicationReach: p.publicationReach,
        publicationCategory: p.publicationCategory,
        publishedAt: p.publishedAt,
      );
}

/// O que uma resolução de `409` produziu.
class _ConflictOutcome {
  const _ConflictOutcome({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
  });

  final int pulled;
  final int pushed;
  final int conflicts;
}
