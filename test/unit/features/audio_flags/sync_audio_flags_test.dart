import 'package:coldigui/features/audio_flags/domain/entities/remote_audio_flag.dart';
import 'package:coldigui/features/audio_flags/domain/entities/saved_audio_flag.dart';
import 'package:coldigui/features/audio_flags/domain/repositories/audio_flag_repository.dart';
import 'package:coldigui/features/audio_flags/domain/usecases/sync_audio_flags.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryAudioFlagRepository implements AudioFlagRepository {
  final map = <String, SavedAudioFlag>{};

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
  Future<List<SavedAudioFlag>> getPendingPush() async => map.values
      .where(
        (f) =>
            f.deletedAt == null &&
            f.syncStatus == PlaylistSyncStatus.pendingPush,
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
  Future<void> markAllPendingPush() async {
    for (final e in map.entries.toList()) {
      if (e.value.deletedAt == null) {
        map[e.key] = e.value.copyWith(
          syncStatus: PlaylistSyncStatus.pendingPush,
        );
      }
    }
  }

  @override
  Future<void> upsert(SavedAudioFlag flag) async {
    map[flag.flagId] = flag;
  }
}

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

    final result = await sync(idToken: null);
    expect(result.skipped, isTrue);
    expect(fetchCalled, isFalse);
  });

  test('pull insere remota ausente localmente', () async {
    final repo = _MemoryAudioFlagRepository();
    final remote = RemoteAudioFlag(
      id: 'f1',
      audioId: 'a1',
      positionMs: 12000,
      label: 'Intro',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
      version: 2,
    );

    final sync = SyncAudioFlags(
      repo,
      (_) async => [remote],
      ({required idToken, required flag}) async => flag,
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token');
    expect(result.pulled, 1);
    expect(repo.map['f1']?.label, 'Intro');
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.synced);
  });

  test('pendingPush local mais novo não é sobrescrito no pull', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      SavedAudioFlag(
        flagId: 'f1',
        audioId: 'a1',
        positionMs: 5000,
        label: 'Local',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    final sync = SyncAudioFlags(
      repo,
      (_) async => [
        RemoteAudioFlag(
          id: 'f1',
          audioId: 'a1',
          positionMs: 9000,
          label: 'Remoto',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 2, 1),
          version: 5,
        ),
      ],
      ({required idToken, required flag}) async => RemoteAudioFlag(
        id: flag.id,
        audioId: flag.audioId,
        positionMs: flag.positionMs,
        label: flag.label,
        createdAt: flag.createdAt,
        updatedAt: flag.updatedAt,
        version: flag.version + 1,
      ),
      ({required idToken, required flagId}) async {},
    );

    final result = await sync(idToken: 'token');
    expect(result.pulled, 0);
    expect(result.pushed, 1);
    expect(repo.map['f1']?.label, 'Local');
    expect(repo.map['f1']?.syncStatus, PlaylistSyncStatus.synced);
  });

  test('tombstone dispara DELETE remoto e hard delete local', () async {
    final repo = _MemoryAudioFlagRepository();
    await repo.upsert(
      SavedAudioFlag(
        flagId: 'gone',
        audioId: 'a1',
        positionMs: 1000,
        createdAt: DateTime.utc(2026, 1, 1),
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

    final result = await sync(idToken: 'token');
    expect(deletedId, 'gone');
    expect(result.deleted, 1);
    expect(repo.map.containsKey('gone'), isFalse);
  });
}
