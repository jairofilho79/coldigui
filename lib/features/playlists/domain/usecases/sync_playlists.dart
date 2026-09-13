import 'package:flutter/foundation.dart';

import '../entities/remote_playlist.dart';
import '../entities/saved_playlist.dart';
import '../repositories/playlist_repository.dart';
import '../utils/playlist_defaults.dart';

/// Resultado de [SyncPlaylists].
class PlaylistSyncResult {
  const PlaylistSyncResult({
    this.pulled = 0,
    this.pushed = 0,
    this.deleted = 0,
    this.deletedRemotely = 0,
    this.skipped = false,
    this.conflicts = 0,
    this.conflictCopies = const [],
    this.pullError,
    this.pushError,
  });

  final int pulled;
  final int pushed;

  /// Tombstones locais que o servidor aceitou apagar nesta rodada.
  final int deleted;

  /// Listas apagadas **aqui** por causa de um tombstone remoto — alguém as
  /// excluiu em outro aparelho (spec A.2).
  final int deletedRemotely;

  final bool skipped;

  /// Listas que ficaram em [PlaylistSyncStatus.conflict] nesta rodada.
  final int conflicts;

  /// Nomes das cópias criadas nesta rodada para não perder edições locais num
  /// `409` (spec A.3) — já no formato de [conflictCopyName].
  final List<String> conflictCopies;

  /// Erro **cru** da fase de pull, se ela falhou (a sync seguiu mesmo assim).
  ///
  /// Cru de propósito: quem traduz é a UI, com `userMessageFor`.
  final Object? pullError;

  /// Último erro cru de push/delete que não era conflito.
  final Object? pushError;

  /// Primeiro erro a mostrar ao usuário — pull perde para nada, é o mais cedo.
  Object? get error => pullError ?? pushError;

  /// `true` se alguma linha do banco mudou nesta rodada — a tela precisa
  /// recarregar. Um push sozinho conta: ele muda `version`/`syncStatus`, que a
  /// lista mostra. Conflito sem cópia não altera linha nenhuma.
  bool get movedRows =>
      pulled > 0 ||
      pushed > 0 ||
      deleted > 0 ||
      deletedRemotely > 0 ||
      conflictCopies.isNotEmpty;

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

  /// [sub] é o dono corrente: toda linha escrita aqui fica com ele, e o push
  /// só envia o que é dele ou ainda não tem dono (spec A.5).
  Future<PlaylistSyncResult> call({
    required String? idToken,
    required String? sub,
  }) async {
    if (idToken == null || idToken.isEmpty) {
      return PlaylistSyncResult.skippedAuth;
    }

    var pulled = 0;
    var pushed = 0;
    var deleted = 0;
    var deletedRemotely = 0;
    var conflicts = 0;
    final conflictCopies = <String>[];
    Object? pullError;
    Object? pushError;

    // Fase A — Pull. Isolada: se cair, push e tombstones ainda rodam.
    try {
      final outcome = await _pull(idToken, sub);
      pulled = outcome.pulled;
      deletedRemotely = outcome.deletedRemotely;
    } on Object catch (e) {
      pullError = e;
      debugPrint('[playlists] pull falhou, seguindo com push: $e');
    }

    // Fase B — Push
    final pending = await _repository.getPendingPush(sub: sub);
    for (final local in pending) {
      if (!local.salva) continue;
      try {
        pushed += await _push(idToken: idToken, local: local, sub: sub);
      } on PlaylistConflictException catch (e) {
        final outcome = await _resolveConflict(
          idToken: idToken,
          local: local,
          remote: e.remote,
          sub: sub,
        );
        pulled += outcome.pulled;
        pushed += outcome.pushed;
        conflicts += outcome.conflicts;
        final copy = outcome.copyName;
        if (copy != null) conflictCopies.add(copy);
      } on Object catch (e) {
        // Mantém pendingPush; próxima sync tenta de novo.
        pushError = e;
        debugPrint('[playlists] push de ${local.playlistId} falhou: $e');
      }
    }

    // Fase C — Deletes
    final tombstones = await _repository.getTombstones(sub: sub);
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
      deletedRemotely: deletedRemotely,
      conflicts: conflicts,
      conflictCopies: List<String>.unmodifiable(conflictCopies),
      pullError: pullError,
      pushError: pushError,
    );
  }

  /// Fase A isolada — o que o servidor trouxe e o que ele mandou apagar.
  Future<_PullOutcome> _pull(String idToken, String? sub) async {
    var pulled = 0;
    var deletedRemotely = 0;
    final remote = await _fetch(idToken);

    for (final r in remote) {
      final remoteDeletedAt = r.deletedAt;
      if (remoteDeletedAt != null) {
        if (await _applyRemoteDeletion(r.id, remoteDeletedAt)) {
          deletedRemotely++;
        }
        continue;
      }
      if (!r.salva) continue;
      final local = await _repository.getById(r.id);
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

  /// Aplica um tombstone remoto (spec A.2). `true` se a lista sumiu daqui.
  ///
  /// A exclusão nunca é deduzida por ausência — só por um `deletedAt` explícito
  /// do servidor —, e uma edição local **posterior** à exclusão ganha: ela fica
  /// e o push a ressuscita no ramo `deleted_at IS NOT NULL` do Worker.
  Future<bool> _applyRemoteDeletion(String id, DateTime deletedAt) async {
    final local = await _repository.getById(id);
    if (local == null) return false;
    final localWins =
        local.syncStatus == PlaylistSyncStatus.pendingPush &&
        local.updatedAt.isAfter(deletedAt);
    if (localWins) return false;
    await _repository.hardDelete(local.playlistId);
    debugPrint('[playlists] $id apagada em outro aparelho: hard delete local');
    return true;
  }

  /// `PUT` de uma lista e gravação do que o servidor devolveu. Devolve `1`.
  Future<int> _push({
    required String idToken,
    required SavedPlaylist local,
    required String? sub,
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
        ownerSub: sub,
      ),
    );
    return 1;
  }

  /// Last-write-wins por `updatedAt` sobre um `409`.
  ///
  /// Remoto mais novo → a linha do servidor vence e o local vira `synced`, mas
  /// as edições locais pendentes não somem: viram uma lista nova em
  /// [PlaylistSyncStatus.conflict] (spec A.3).
  /// Local mais novo → **uma** nova tentativa com a `version` do remoto; se ela
  /// também falhar, a lista fica em [PlaylistSyncStatus.conflict] (o banner
  /// conta) e a sync segue para as outras.
  Future<_ConflictOutcome> _resolveConflict({
    required String idToken,
    required SavedPlaylist local,
    required RemotePlaylist remote,
    required String? sub,
  }) async {
    // Remoto já apagado: o tombstone é assunto do pull (`_applyRemoteDeletion`),
    // não do 409. Aqui ele não vira upsert nem cópia — ressuscitar por cima da
    // lista local seria desfazer uma exclusão feita em outro aparelho.
    if (remote.deletedAt != null) {
      debugPrint(
        '[playlists] conflito em ${local.playlistId}: remoto já apagado, '
        'nada a fazer',
      );
      return const _ConflictOutcome();
    }
    // `!remote.salva` é ignorado pelo pull (`_pull`), e o 409 segue a mesma
    // regra: um rascunho remoto não ressuscita por cima de uma lista salva.
    if (remote.salva && remote.updatedAt.isAfter(local.updatedAt)) {
      final copyName = await _saveConflictCopy(
        local: local,
        remote: remote,
        sub: sub,
      );
      await _repository.upsert(_fromRemote(remote, sub));
      debugPrint(
        '[playlists] conflito em ${local.playlistId}: remoto mais novo venceu',
      );
      return _ConflictOutcome(pulled: 1, copyName: copyName);
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
      debugPrint(
        '[playlists] conflito em ${local.playlistId} não resolvido: $e',
      );
      return const _ConflictOutcome(conflicts: 1);
    }
  }

  /// Guarda as edições locais que o remoto está prestes a sobrescrever.
  ///
  /// Só quando havia mesmo edição pendente (`pendingPush`) **e** ela difere do
  /// remoto em `entries` ou `nome` — reenviar a mesma coisa não vira lixo. A
  /// cópia nasce em [PlaylistSyncStatus.conflict], que o push ignora: ela só
  /// sobe se o usuário a editar (qualquer `update` a marca `pendingPush`).
  ///
  /// Devolve o nome da cópia, ou `null` se não houve o que guardar.
  Future<String?> _saveConflictCopy({
    required SavedPlaylist local,
    required RemotePlaylist remote,
    required String? sub,
  }) async {
    if (local.syncStatus != PlaylistSyncStatus.pendingPush) return null;
    if (!_entriesDiffer(local.entries, remote.entries) &&
        local.nome == remote.nome) {
      return null;
    }
    final copyName = conflictCopyName(local.nome);
    // Sem `playlistId`: o repositório gera um novo, e a cópia é uma lista
    // independente — o id remoto continua sendo o da original.
    await _repository.create(
      nome: copyName,
      entries: local.entries,
      salva: true,
      syncStatus: PlaylistSyncStatus.conflict,
      updatedAt: local.updatedAt,
      createdAt: local.createdAt,
      ownerSub: sub,
    );
    debugPrint(
      '[playlists] edições locais de ${local.playlistId} guardadas em '
      '"$copyName"',
    );
    return copyName;
  }

  /// Igualdade de lista elemento a elemento ([PlaylistEntry] já tem `==`).
  ///
  /// À mão em vez de `ListEquality`: `package:collection` é dependência
  /// transitiva, e importá-la aqui exigiria declará-la no `pubspec`.
  static bool _entriesDiffer(List<PlaylistEntry> a, List<PlaylistEntry> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  static SavedPlaylist _fromRemote(
    RemotePlaylist r,
    String? sub,
  ) => SavedPlaylist(
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
    ownerSub: sub,
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
    this.copyName,
  });

  final int pulled;
  final int pushed;
  final int conflicts;

  /// Nome da cópia local criada, se as edições pendentes foram guardadas.
  final String? copyName;
}

/// O que a fase de pull produziu.
class _PullOutcome {
  const _PullOutcome({required this.pulled, required this.deletedRemotely});

  final int pulled;
  final int deletedRemotely;
}
