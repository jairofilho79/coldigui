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

  /// Pendências que a conta [sub] pode enviar: as dela e as ainda sem dono.
  ///
  /// O filtro de dono é em memória de propósito — `ownerSub` não é indexado (é
  /// campo novo, e a lista de pendentes já é curta).
  Future<List<AudioFlag>> findPendingPush({String? sub}) async {
    final isar = _isar;
    if (isar == null) return const [];
    final rows = isar.audioFlags
        .where()
        .syncStatusIndexEqualTo(PlaylistSyncStatus.pendingPush.index)
        .and()
        .deletedAtIsNull()
        .findAll();
    return rows
        .where((row) => row.ownerSub == null || row.ownerSub == sub)
        .toList(growable: false);
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

  /// Adota para [sub] as linhas vivas sem dono ou já dele, marcando-as
  /// `pendingPush` (spec A.5).
  ///
  /// Linhas de outra conta ficam intocadas: elas não sobem no push desta.
  Future<void> adoptForSub(String sub) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      final coll = isar.audioFlags;
      final rows = coll.where().deletedAtIsNull().findAll();
      for (final row in rows) {
        if (row.ownerSub != null && row.ownerSub != sub) continue;
        row.syncStatus = PlaylistSyncStatus.pendingPush;
        row.ownerSub = sub;
        coll.put(row);
      }
    });
  }

  /// Apaga de vez as linhas já sincronizadas de [previousSub] (troca de conta).
  ///
  /// Só as `synced`: elas estão na nuvem da conta anterior e voltam no próximo
  /// login dela. `pendingPush`/`conflict` ficam no aparelho, com o dono antigo.
  Future<int> purgeSyncedOwnedBy(String previousSub) async {
    final isar = _isar;
    if (isar == null) return 0;
    return isar.write((isar) {
      final coll = isar.audioFlags;
      final doomed = coll
          .where()
          .findAll()
          .where(
            (row) =>
                row.ownerSub == previousSub &&
                row.syncStatus == PlaylistSyncStatus.synced,
          )
          .toList(growable: false);
      for (final row in doomed) {
        coll.delete(row.id);
      }
      return doomed.length;
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
