import 'package:coldigui/features/audio_flags/domain/entities/remote_audio_flag.dart';
import 'package:coldigui/features/audio_flags/domain/entities/saved_audio_flag.dart';
import 'package:coldigui/features/audio_flags/domain/repositories/audio_flag_repository.dart';
import 'package:coldigui/features/audio_flags/domain/usecases/sync_audio_flags.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryAudioFlagRepository implements AudioFlagRepository {
  final map = <String, SavedAudioFlag>{};
  var adoptCalls = 0;
  final purgedSubs = <String>[];

  @override
  Future<String> create({
    required String audioId,
    required int positionMs,
    String label = '',
    String? flagId,
    DateTime? createdAt,
  }) async {
    final id = flagId ?? 'gen';
    final now = createdAt ?? DateTime.utc(2026, 1, 1);
    map[id] = SavedAudioFlag(
      flagId: id,
      audioId: audioId,
      positionMs: positionMs,
      label: label,
      createdAt: now,
      updatedAt: now,
      syncStatus: PlaylistSyncStatus.pendingPush,
    );
    return id;
  }

  @override
  Future<void> delete(String flagId) async {
    final existing = map[flagId];
    if (existing == null) return;
    map[flagId] = existing.copyWith(
      deletedAt: DateTime.utc(2026, 6, 1),
      syncStatus: PlaylistSyncStatus.pendingPush,
      updatedAt: DateTime.utc(2026, 6, 1),
    );
  }

  @override
  Future<List<SavedAudioFlag>> getByAudioId(String audioId) async => map.values
      .where((f) => f.audioId == audioId && f.deletedAt == null)
      .toList();

  @override
  Future<SavedAudioFlag?> getById(String flagId) async => map[flagId];

  @override
  Future<List<SavedAudioFlag>> getPendingPush({String? sub}) async => map.values
      .where(
        (f) =>
            f.deletedAt == null &&
            f.syncStatus == PlaylistSyncStatus.pendingPush &&
            (f.ownerSub == null || f.ownerSub == sub),
      )
      .toList();

  @override
  Future<List<SavedAudioFlag>> getTombstones() async => map.values
      .where(
        (f) =>
            f.deletedAt != null &&
            f.syncStatus == PlaylistSyncStatus.pendingPush,
      )
      .toList();

  @override
  Future<void> hardDelete(String flagId) async {
    map.remove(flagId);
  }

  @override
  Future<void> adoptForSub(String sub) async {
    adoptCalls++;
    for (final e in map.entries.toList()) {
      final row = e.value;
      if (row.deletedAt != null) continue;
      if (row.ownerSub != null && row.ownerSub != sub) continue;
      map[e.key] = row.copyWith(
        syncStatus: PlaylistSyncStatus.pendingPush,
        ownerSub: sub,
      );
    }
  }

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) async {
    purgedSubs.add(previousSub);
    final doomed = map.entries
        .where(
          (e) =>
              e.value.ownerSub == previousSub &&
              e.value.syncStatus == PlaylistSyncStatus.synced,
        )
        .map((e) => e.key)
        .toList();
    for (final id in doomed) {
      map.remove(id);
    }
    return doomed.length;
  }

  @override
  Future<void> upsert(SavedAudioFlag flag) async {
    map[flag.flagId] = flag;
  }
}

RemoteAudioFlag _remote({
  String id = 'f1',
  String audioId = 'a1',
  int positionMs = 1000,
  String label = 'Remoto',
  DateTime? createdAt,
  DateTime? updatedAt,
  int version = 1,
  DateTime? deletedAt,
}) => RemoteAudioFlag(
  id: id,
  audioId: audioId,
  positionMs: positionMs,
  label: label,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 2, 1),
  version: version,
  deletedAt: deletedAt,
);

SavedAudioFlag _local({
  String flagId = 'f1',
  String audioId = 'a1',
  int positionMs = 5000,
  String label = 'Local',
  DateTime? createdAt,
  DateTime? updatedAt,
  int version = 1,
  PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
  DateTime? deletedAt,
  String? ownerSub,
}) => SavedAudioFlag(
  flagId: flagId,
  audioId: audioId,
  positionMs: positionMs,
  label: label,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 2, 1),
  version: version,
  syncStatus: syncStatus,
  deletedAt: deletedAt,
  ownerSub: ownerSub,
);

/// Eco do `upsert`: devolve o que foi enviado com a versão incrementada.
Future<RemoteAudioFlag> _echo({
  required String idToken,
  required RemoteAudioFlag flag,
}) async => RemoteAudioFlag(
  id: flag.id,
  audioId: flag.audioId,
  positionMs: flag.positionMs,
  label: flag.label,
  createdAt: flag.createdAt,
  updatedAt: flag.updatedAt,
  version: flag.version + 1,
);

void main() {
  test('sem idToken não chama rede', () async {
    var fetchCalled = false;
    final sync = SyncAudioFlags(
      _MemoryAudioFlagRepository(),
      (_) async {
        fetchCalled = true;
        return <RemoteAudioFlag>[];
      },
      ({required idToken, required flag}) async => flag,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: null, sub: 'sub-1');
    expect(result.skipped, isTrue);
    expect(fetchCalled, isFalse);
  });

  test('pull insere remota ausente localmente', () async {
    final repo = _MemoryAudioFlagRepository();
    final sync = SyncAudioFlags(
      repo,
      (_) async => [_remote(label: 'Intro', positionMs: 12000, version: 2)],
      ({required idToken, required flag}) async => flag,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.pulled, 1);
    expect(repo.map['f1']?.label, 'Intro');
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.synced);
  });

  test('pendingPush local mais novo não é sobrescrito no pull', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        updatedAt: DateTime.utc(2026, 3, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    final sync = SyncAudioFlags(
      repo,
      (_) async => [_remote(positionMs: 9000, version: 5)],
      _echo,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.pulled, 0);
    expect(result.pushed, 1);
    expect(repo.map['f1']?.label, 'Local');
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.synced);
  });

  test('tombstone dispara DELETE remoto e hard delete local', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        flagId: 'gone',
        deletedAt: DateTime.utc(2026, 6, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    String? deletedId;
    final sync = SyncAudioFlags(
      repo,
      (_) async => <RemoteAudioFlag>[],
      ({required idToken, required flag}) async => flag,
      ({required idToken, required flagId}) async {
        deletedId = flagId;
      },
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(deletedId, 'gone');
    expect(result.deleted, 1);
    expect(repo.map.containsKey('gone'), isFalse);
  });

  test('pull que falha não impede push nem tombstones', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(syncStatus: PlaylistSyncStatus.pendingPush, ownerSub: 'sub-1'),
    );
    await repo.upsert(
      _local(
        flagId: 'gone',
        deletedAt: DateTime.utc(2026, 6, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );
    final boom = StateError('rede caiu no pull');

    final sync = SyncAudioFlags(
      repo,
      (_) async => throw boom,
      _echo,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.pullError, same(boom));
    expect(result.error, same(boom));
    expect(result.pushed, 1);
    expect(result.deleted, 1);
  });

  test('erro de push vira pushError e mantém pendingPush', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(_local(syncStatus: PlaylistSyncStatus.pendingPush));
    final boom = StateError('PUT recusado');

    final sync = SyncAudioFlags(
      repo,
      (_) async => <RemoteAudioFlag>[],
      ({required idToken, required flag}) async => throw boom,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.pushError, same(boom));
    expect(result.pushed, 0);
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.pendingPush);
  });

  test('tombstone remoto apaga a linha local sincronizada', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(_local(ownerSub: 'sub-1'));

    final sync = SyncAudioFlags(
      repo,
      (_) async => [
        _remote(
          deletedAt: DateTime.utc(2026, 5, 1),
          updatedAt: DateTime.utc(2026, 5, 1),
        ),
      ],
      _echo,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.deletedRemotely, 1);
    expect(repo.map.containsKey('f1'), isFalse);
  });

  test('tombstone remoto de flag ausente localmente é ignorado', () async {
    final repo = _MemoryAudioFlagRepository();

    final sync = SyncAudioFlags(
      repo,
      (_) async => [_remote(deletedAt: DateTime.utc(2026, 5, 1))],
      _echo,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.deletedRemotely, 0);
    expect(result.pulled, 0);
    expect(repo.map, isEmpty);
  });

  test('tombstone remoto não apaga edição local pendente mais nova', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        updatedAt: DateTime.utc(2026, 7, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    final sync = SyncAudioFlags(
      repo,
      (_) async => [_remote(deletedAt: DateTime.utc(2026, 5, 1))],
      _echo,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.deletedRemotely, 0);
    expect(result.pushed, 1, reason: 'o push ressuscita a linha');
    expect(repo.map.containsKey('f1'), isTrue);
  });

  test('409 com remoto mais novo faz o remoto vencer', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        updatedAt: DateTime.utc(2026, 2, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    final sync = SyncAudioFlags(
      repo,
      (_) async => <RemoteAudioFlag>[],
      ({required idToken, required flag}) async =>
          throw AudioFlagConflictException(
            _remote(
              label: 'Servidor',
              positionMs: 7777,
              updatedAt: DateTime.utc(2026, 3, 1),
              version: 9,
            ),
          ),
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.pulled, 1);
    expect(result.conflicts, 0);
    expect(repo.map['f1']?.label, 'Servidor');
    expect(repo.map['f1']?.positionMs, 7777);
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.synced);
    expect(repo.map['f1']?.ownerSub, 'sub-1');
  });

  test('409 com local mais novo reenvia com a version remota', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        updatedAt: DateTime.utc(2026, 8, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    var calls = 0;
    final sentVersions = <int>[];
    final sync = SyncAudioFlags(
      repo,
      (_) async => <RemoteAudioFlag>[],
      ({required idToken, required flag}) async {
        calls++;
        sentVersions.add(flag.version);
        if (calls == 1) {
          throw AudioFlagConflictException(
            _remote(updatedAt: DateTime.utc(2026, 4, 1), version: 42),
          );
        }
        return _echo(idToken: idToken, flag: flag);
      },
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.pushed, 1);
    expect(result.conflicts, 0);
    expect(sentVersions, [1, 42]);
    expect(repo.map['f1']?.label, 'Local');
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.synced);
  });

  test('segundo erro no reenvio deixa a flag em conflict', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        updatedAt: DateTime.utc(2026, 8, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    final sync = SyncAudioFlags(
      repo,
      (_) async => <RemoteAudioFlag>[],
      ({required idToken, required flag}) async {
        if (flag.version == 1) {
          throw AudioFlagConflictException(
            _remote(updatedAt: DateTime.utc(2026, 4, 1), version: 42),
          );
        }
        throw StateError('recusado de novo');
      },
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(result.conflicts, 1);
    expect(result.pushed, 0);
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.conflict);
    expect(repo.map['f1']?.label, 'Local', reason: 'sem cópia para flags');
  });

  test('tombstone que falha desiste depois de 3 tentativas por boot', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        flagId: 'gone',
        deletedAt: DateTime.utc(2026, 6, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    var attempts = 0;
    final sync = SyncAudioFlags(
      repo,
      (_) async => <RemoteAudioFlag>[],
      ({required idToken, required flag}) async => flag,
      ({required idToken, required flagId}) async {
        attempts++;
        throw StateError('DELETE recusado');
      },
    );

    for (var i = 0; i < 6; i++) {
      await sync(idToken: 'token', sub: 'sub-1');
    }

    expect(attempts, SyncAudioFlags.maxTombstoneAttemptsPerBoot);
    expect(repo.map.containsKey('gone'), isTrue);
  });

  test('toda linha escrita pelo pull recebe o ownerSub corrente', () async {
    final repo = _MemoryAudioFlagRepository();
    final sync = SyncAudioFlags(
      repo,
      (_) async => [_remote()],
      _echo,
      ({required idToken, required flagId}) async {},
    );

    await sync(idToken: 'token', sub: 'sub-9');
    expect(repo.map['f1']?.ownerSub, 'sub-9');
  });

  test('push só leva as pendências do dono corrente (ou sem dono)', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      _local(
        flagId: 'minha',
        syncStatus: PlaylistSyncStatus.pendingPush,
        ownerSub: 'sub-1',
      ),
    );
    await repo.upsert(
      _local(flagId: 'orfa', syncStatus: PlaylistSyncStatus.pendingPush),
    );
    await repo.upsert(
      _local(
        flagId: 'alheia',
        syncStatus: PlaylistSyncStatus.pendingPush,
        ownerSub: 'sub-2',
      ),
    );

    final sent = <String>[];
    final sync = SyncAudioFlags(
      repo,
      (_) async => <RemoteAudioFlag>[],
      ({required idToken, required flag}) async {
        sent.add(flag.id);
        return _echo(idToken: idToken, flag: flag);
      },
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token', sub: 'sub-1');
    expect(sent..sort(), ['minha', 'orfa']);
    expect(result.pushed, 2);
    expect(repo.map['orfa']?.ownerSub, 'sub-1', reason: 'o push adota a órfã');
    expect(repo.map['alheia']?.syncStatus, PlaylistSyncStatus.pendingPush);
  });
}
