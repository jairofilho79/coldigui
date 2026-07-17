import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/audio_flag.dart';
import '../../../../core/database/collections/playlist_sync_status.dart';

/// CRUD Isar para [AudioFlag].
class AudioFlagLocalDatasource {
  const AudioFlagLocalDatasource(this._isar);

  const AudioFlagLocalDatasource.unavailable() : _isar = null;

  final Isar? _isar;

  Future<List<AudioFlag>> findByAudioId(String audioId) async {
    final isar = _isar;
    if (isar == null) return const [];
    final rows = isar.audioFlags
        .where()
        .audioIdEqualTo(audioId)
        .and()
        .deletedAtIsNull()
        .findAll();
    rows.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return rows;
  }

  Future<AudioFlag?> findByFlagId(String flagId) async {
    final isar = _isar;
    if (isar == null) return null;
    return isar.audioFlags.where().flagIdEqualTo(flagId).findFirst();
  }

  Future<List<AudioFlag>> findPendingPush() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.audioFlags
        .where()
        .syncStatusIndexEqualTo(PlaylistSyncStatus.pendingPush.index)
        .and()
        .deletedAtIsNull()
        .findAll();
  }

  Future<List<AudioFlag>> findTombstones() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.audioFlags
        .where()
        .deletedAtIsNotNull()
        .and()
        .syncStatusIndexEqualTo(PlaylistSyncStatus.pendingPush.index)
        .findAll();
  }

  Future<void> insert(AudioFlag flag) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      _putByFlagId(isar.audioFlags, flag);
    });
  }

  Future<void> softDeleteByFlagId(String flagId) async {
    final isar = _isar;
    if (isar == null) return;
    final now = DateTime.now().toUtc();
    await isar.write((isar) {
      final coll = isar.audioFlags;
      final existing = coll.where().flagIdEqualTo(flagId).findFirst();
      if (existing == null) return;
      existing.deletedAt = now;
      existing.updatedAt = now;
      existing.syncStatus = PlaylistSyncStatus.pendingPush;
      coll.put(existing);
    });
  }

  Future<void> deleteByFlagId(String flagId) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      final coll = isar.audioFlags;
      final existing = coll.where().flagIdEqualTo(flagId).findFirst();
      if (existing != null) {
        coll.delete(existing.id);
      }
    });
  }

  Future<void> markAllPendingPush() async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      final coll = isar.audioFlags;
      final rows = coll.where().deletedAtIsNull().findAll();
      for (final row in rows) {
        row.syncStatus = PlaylistSyncStatus.pendingPush;
        coll.put(row);
      }
    });
  }

  void _putByFlagId(IsarCollection<int, AudioFlag> coll, AudioFlag flag) {
    final existing = coll.where().flagIdEqualTo(flag.flagId).findFirst();
    if (existing != null) {
      flag.id = existing.id;
    } else if (flag.id == 0) {
      flag.id = coll.autoIncrement();
    }
    coll.put(flag);
  }
}
