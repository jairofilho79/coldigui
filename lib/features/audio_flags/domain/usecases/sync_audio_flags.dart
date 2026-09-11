import 'package:flutter/foundation.dart';

import '../entities/remote_audio_flag.dart';
import '../entities/saved_audio_flag.dart';
import '../repositories/audio_flag_repository.dart';

/// Resultado de [SyncAudioFlags].
class AudioFlagSyncResult {
  const AudioFlagSyncResult({
    this.pulled = 0,
    this.pushed = 0,
    this.deleted = 0,
    this.skipped = false,
    this.conflicts = 0,
    this.deletedRemotely = 0,
    this.pullError,
    this.pushError,
  });

  final int pulled;
  final int pushed;
  final int deleted;
  final bool skipped;

  /// Marcadores que ficaram em [PlaylistSyncStatus.conflict] nesta rodada.
  final int conflicts;

  /// Marcadores apagados localmente por tombstone **do servidor** (spec A.2).
  final int deletedRemotely;

  /// Erro **cru** da fase de pull, se ela falhou (a sync seguiu mesmo assim).
  ///
  /// Cru de propósito: quem traduz é a UI, com `userMessageFor`.
  final Object? pullError;

  /// Último erro cru de push/delete que não era conflito.
  final Object? pushError;

  /// Primeiro erro a mostrar ao usuário — pull perde para nada, é o mais cedo.
  Object? get error => pullError ?? pushError;

  static const skippedAuth = AudioFlagSyncResult(skipped: true);
}

/// Sync offline-first de marcadores: pull → push → tombstones.
///
/// Pré-condição: [idToken] não-nulo. Sem token, retorna
/// [AudioFlagSyncResult.skippedAuth] sem tocar a rede.
///
/// Espelha `SyncPlaylists` campo a campo (spec A.4): as três fases são
/// independentes — um pull que falha não impede push nem tombstones, e o erro
/// volta no resultado em vez de sumir. Um `409` no push vira last-write-wins
/// por `updatedAt`, **sem cópia local**: um marcador é um par posição/rótulo,
/// não um documento que valha duplicar.
class SyncAudioFlags {
  SyncAudioFlags(this._repository, this._fetch, this._upsert, this._delete);

  /// Tentativas de DELETE remoto por tombstone **por boot**.
  ///
  /// Um tombstone que o servidor recusa indefinidamente não pode gastar uma
  /// requisição a cada sync pelo resto da sessão; o registro fica no disco e a
  /// próxima abertura tenta de novo.
  static const int maxTombstoneAttemptsPerBoot = 3;

  /// Falhas de DELETE por `flagId` desde que o app abriu (o provider que guarda
  /// esta instância vive o boot inteiro).
  final Map<String, int> _tombstoneFailures = <String, int>{};

  final AudioFlagRepository _repository;
  final Future<List<RemoteAudioFlag>> Function(String idToken) _fetch;
  final Future<RemoteAudioFlag> Function({
    required String idToken,
    required RemoteAudioFlag flag,
  })
  _upsert;
  final Future<void> Function({required String idToken, required String flagId})
  _delete;

  /// [sub] é o dono corrente: toda linha escrita aqui fica com ele, e o push só
  /// leva as pendências dele (ou as ainda sem dono) — spec A.5.
  Future<AudioFlagSyncResult> call({
    required String? idToken,
    required String? sub,
  }) async {
    if (idToken == null || idToken.isEmpty) {
      return AudioFlagSyncResult.skippedAuth;
    }

    var pulled = 0;
    var pushed = 0;
    var deleted = 0;
    var conflicts = 0;
    var deletedRemotely = 0;
    Object? pullError;
    Object? pushError;

    // Fase A — Pull. Isolada: se cair, push e tombstones ainda rodam.
    try {
      final outcome = await _pull(idToken, sub);
      pulled = outcome.pulled;
      deletedRemotely = outcome.deletedRemotely;
    } on Object catch (e) {
      pullError = e;
      debugPrint('[audio-flags] pull falhou, seguindo com push: $e');
    }

    // Fase B — Push
    final pending = await _repository.getPendingPush(sub: sub);
    for (final local in pending) {
      try {
        pushed += await _push(idToken: idToken, local: local, sub: sub);
      } on AudioFlagConflictException catch (e) {
        final outcome = await _resolveConflict(
          idToken: idToken,
          local: local,
          remote: e.remote,
          sub: sub,
        );
        pulled += outcome.pulled;
        pushed += outcome.pushed;
        conflicts += outcome.conflicts;
      } on Object catch (e) {
        // Mantém pendingPush; próxima sync tenta de novo.
        pushError = e;
        debugPrint('[audio-flags] push de ${local.flagId} falhou: $e');
      }
    }

    // Fase C — Deletes. Só os tombstones desta conta (ou sem dono): o DELETE
    // de um tombstone da conta anterior com este token daria 404 a cada boot.
    final tombstones = await _repository.getTombstones(sub: sub);
    for (final tomb in tombstones) {
      final failures = _tombstoneFailures[tomb.flagId] ?? 0;
      if (failures >= maxTombstoneAttemptsPerBoot) continue;
      try {
        await _delete(idToken: idToken, flagId: tomb.flagId);
        await _repository.hardDelete(tomb.flagId);
        _tombstoneFailures.remove(tomb.flagId);
        deleted++;
      } on Object catch (e) {
        // Mantém tombstone; desiste depois de [maxTombstoneAttemptsPerBoot].
        _tombstoneFailures[tomb.flagId] = failures + 1;
        pushError = e;
        debugPrint(
          '[audio-flags] DELETE de ${tomb.flagId} falhou '
          '(${failures + 1}/$maxTombstoneAttemptsPerBoot): $e',
        );
      }
    }

    return AudioFlagSyncResult(
      pulled: pulled,
      pushed: pushed,
      deleted: deleted,
      conflicts: conflicts,
      deletedRemotely: deletedRemotely,
      pullError: pullError,
      pushError: pushError,
    );
  }

  /// Fase A isolada — o que veio do servidor e o que ele mandou apagar.
  Future<_PullOutcome> _pull(String idToken, String? sub) async {
    var pulled = 0;
    var deletedRemotely = 0;
    final remote = await _fetch(idToken);

    for (final r in remote) {
      final local = await _repository.getById(r.id);
      final remoteDeletedAt = r.deletedAt;
      if (remoteDeletedAt != null) {
        deletedRemotely += await _applyRemoteTombstone(
          remoteDeletedAt: remoteDeletedAt,
          flagId: r.id,
          local: local,
        );
        continue;
      }
      if (local == null) {
        await _repository.upsert(_fromRemote(r, sub));
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
        await _repository.upsert(_fromRemote(r, sub));
        pulled++;
      }
    }
    return _PullOutcome(pulled: pulled, deletedRemotely: deletedRemotely);
  }

  /// Tombstone do servidor (spec A.2). Devolve `1` quando apagou local.
  ///
  /// Sem linha local não há nada a apagar; uma edição local pendente **mais
  /// nova** que a exclusão sobrevive, e o push a ressuscita no servidor.
  Future<int> _applyRemoteTombstone({
    required DateTime remoteDeletedAt,
    required String flagId,
    required SavedAudioFlag? local,
  }) async {
    if (local == null) return 0;
    if (local.syncStatus == PlaylistSyncStatus.pendingPush &&
        local.updatedAt.isAfter(remoteDeletedAt)) {
      return 0;
    }
    await _repository.hardDelete(flagId);
    debugPrint('[audio-flags] $flagId apagado em outro aparelho');
    return 1;
  }

  /// `PUT` de um marcador e gravação do que o servidor devolveu. Devolve `1`.
  Future<int> _push({
    required String idToken,
    required SavedAudioFlag local,
    required String? sub,
    int? version,
  }) async {
    final saved = await _upsert(
      idToken: idToken,
      flag: _toRemote(local, version: version),
    );
    await _repository.upsert(
      local.copyWith(
        version: saved.version,
        updatedAt: saved.updatedAt,
        syncStatus: PlaylistSyncStatus.synced,
        clearDeletedAt: true,
        ownerSub: sub,
      ),
    );
    return 1;
  }

  /// Last-write-wins por `updatedAt` sobre um `409`.
  ///
  /// Remoto mais novo → a linha do servidor vence e o local vira `synced`.
  /// Local mais novo → **uma** nova tentativa com a `version` do remoto; se ela
  /// também falhar, o marcador fica em [PlaylistSyncStatus.conflict] (a linha
  /// de erro do player conta) e a sync segue para os outros.
  Future<_ConflictOutcome> _resolveConflict({
    required String idToken,
    required SavedAudioFlag local,
    required RemoteAudioFlag remote,
    required String? sub,
  }) async {
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      await _repository.upsert(_fromRemote(remote, sub));
      debugPrint(
        '[audio-flags] conflito em ${local.flagId}: remoto mais novo venceu',
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
        sub: sub,
        version: remote.version,
      );
      return _ConflictOutcome(pushed: pushed);
    } on Object catch (e) {
      await _repository.upsert(
        local.copyWith(syncStatus: PlaylistSyncStatus.conflict),
      );
      debugPrint('[audio-flags] conflito em ${local.flagId} não resolvido: $e');
      return const _ConflictOutcome(conflicts: 1);
    }
  }

  static SavedAudioFlag _fromRemote(RemoteAudioFlag r, String? sub) =>
      SavedAudioFlag(
        flagId: r.id,
        audioId: r.audioId,
        positionMs: r.positionMs,
        label: r.label,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        version: r.version,
        syncStatus: PlaylistSyncStatus.synced,
        ownerSub: sub,
      );

  /// [version] força a versão enviada — é o re-envio pós-`409`, que só passa no
  /// Worker se carregar a versão que ele já tem.
  static RemoteAudioFlag _toRemote(SavedAudioFlag f, {int? version}) =>
      RemoteAudioFlag(
        id: f.flagId,
        audioId: f.audioId,
        positionMs: f.positionMs,
        label: f.label,
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
        version: version ?? f.version,
      );
}

/// O que a fase de pull produziu.
class _PullOutcome {
  const _PullOutcome({this.pulled = 0, this.deletedRemotely = 0});

  final int pulled;
  final int deletedRemotely;
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
