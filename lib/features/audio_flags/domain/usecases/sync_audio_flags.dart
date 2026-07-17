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
  });

  final int pulled;
  final int pushed;
  final int deleted;
  final bool skipped;

  static const skippedAuth = AudioFlagSyncResult(skipped: true);
}

/// Sync offline-first: pull → push → tombstones.
class SyncAudioFlags {
  const SyncAudioFlags(
    this._repository,
    this._fetch,
    this._upsert,
    this._delete,
  );

  final AudioFlagRepository _repository;
  final Future<List<RemoteAudioFlag>> Function(String idToken) _fetch;
  final Future<RemoteAudioFlag> Function({
    required String idToken,
    required RemoteAudioFlag flag,
  })
  _upsert;
  final Future<void> Function({required String idToken, required String flagId})
  _delete;

  Future<AudioFlagSyncResult> call({required String? idToken}) async {
    if (idToken == null || idToken.isEmpty) {
      return AudioFlagSyncResult.skippedAuth;
    }

    var pulled = 0;
    var pushed = 0;
    var deleted = 0;

    final remote = await _fetch(idToken);

    for (final r in remote) {
      final local = await _repository.getById(r.id);
      if (local == null) {
        await _repository.upsert(_fromRemote(r));
        pulled++;
        continue;
      }
      if (local.deletedAt != null) continue;
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

    final pending = await _repository.getPendingPush();
    for (final local in pending) {
      try {
        final saved = await _upsert(idToken: idToken, flag: _toRemote(local));
        await _repository.upsert(
          local.copyWith(
            version: saved.version,
            updatedAt: saved.updatedAt,
            syncStatus: PlaylistSyncStatus.synced,
            clearDeletedAt: true,
          ),
        );
        pushed++;
      } on Object {
        // Mantém pendingPush.
      }
    }

    final tombstones = await _repository.getTombstones();
    for (final tomb in tombstones) {
      try {
        await _delete(idToken: idToken, flagId: tomb.flagId);
        await _repository.hardDelete(tomb.flagId);
        deleted++;
      } on Object {
        // Mantém tombstone.
      }
    }

    return AudioFlagSyncResult(
      pulled: pulled,
      pushed: pushed,
      deleted: deleted,
    );
  }

  static SavedAudioFlag _fromRemote(RemoteAudioFlag r) => SavedAudioFlag(
    flagId: r.id,
    audioId: r.audioId,
    positionMs: r.positionMs,
    label: r.label,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    version: r.version,
    syncStatus: PlaylistSyncStatus.synced,
  );

  static RemoteAudioFlag _toRemote(SavedAudioFlag f) => RemoteAudioFlag(
    id: f.flagId,
    audioId: f.audioId,
    positionMs: f.positionMs,
    label: f.label,
    createdAt: f.createdAt,
    updatedAt: f.updatedAt,
    version: f.version,
  );
}
