import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/offline_audio_index.dart';
import '../../../../core/database/storage_unavailable_exception.dart';

/// CRUD Isar de [OfflineAudioIndex] — espelho enxuto de
/// `OfflinePdfLocalDatasource` (sem LRU, sem `isPersistent`).
///
/// Sem Isar as leituras devolvem vazio e as escritas lançam
/// [StorageUnavailableException]. [onIndexChanged] sobe a revisão do índice
/// de áudio (`offlineAudioIndexRevisionProvider`) depois de cada escrita —
/// é o que re-deriva `materialAvailabilityMapProvider` e as stats.
class OfflineAudioLocalDatasource {
  const OfflineAudioLocalDatasource(this._isar, {this.onIndexChanged});

  const OfflineAudioLocalDatasource.unavailable()
    : _isar = null,
      onIndexChanged = null;

  final Isar? _isar;
  final void Function()? onIndexChanged;

  OfflineAudioIndex? findByAudioIdSync(String audioId) {
    final isar = _isar;
    if (isar == null || audioId.isEmpty) return null;
    return isar.offlineAudioIndexs.where().audioIdEqualTo(audioId).findFirst();
  }

  List<OfflineAudioIndex> findByAudioIds(Set<String> audioIds) {
    final isar = _isar;
    if (isar == null || audioIds.isEmpty) return const [];
    return isar.offlineAudioIndexs
        .where()
        .anyOf(audioIds, (q, id) => q.audioIdEqualTo(id))
        .findAll();
  }

  List<OfflineAudioIndex> findAllSync() {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.offlineAudioIndexs.where().findAll();
  }

  /// Upsert por `audioId`.
  Future<void> put(OfflineAudioIndex index) async {
    final isar = _requireIsar('put');
    await isar.write((isar) {
      final coll = isar.offlineAudioIndexs;
      final existing = coll.where().audioIdEqualTo(index.audioId).findFirst();
      if (existing != null) {
        index.id = existing.id;
      } else if (index.id == 0) {
        index.id = coll.autoIncrement();
      }
      coll.put(index);
    });
    onIndexChanged?.call();
  }

  /// Idempotente se ausente.
  Future<void> deleteByAudioId(String audioId) async {
    final isar = _requireIsar('deleteByAudioId');
    await isar.write((isar) {
      final coll = isar.offlineAudioIndexs;
      final existing = coll.where().audioIdEqualTo(audioId).findFirst();
      if (existing != null) coll.delete(existing.id);
    });
    onIndexChanged?.call();
  }

  Future<void> clearAll() async {
    final isar = _requireIsar('clearAll');
    await isar.write((isar) {
      isar.offlineAudioIndexs.clear();
    });
    onIndexChanged?.call();
  }

  /// Soma de [OfflineAudioIndex.fileSize] — stats sem scan de disco.
  int sumFileSizes() =>
      findAllSync().fold<int>(0, (sum, index) => sum + index.fileSize);

  Isar _requireIsar(String operation) {
    final isar = _isar;
    if (isar == null) {
      throw StorageUnavailableException('offline_audio.$operation');
    }
    return isar;
  }
}
