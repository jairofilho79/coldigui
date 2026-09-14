import 'dart:typed_data';

import '../../../../core/database/collections/offline_audio_index.dart';
import '../../domain/entities/local_audio_source.dart';
import '../../domain/entities/offline_audio_entry.dart';
import '../../domain/ports/audio_storage_port.dart';
import '../../domain/repositories/offline_audio_repository.dart';
import '../datasources/offline_audio_local_datasource.dart';

/// Orquestra [AudioStoragePort] + [OfflineAudioLocalDatasource].
class OfflineAudioRepositoryImpl implements OfflineAudioRepository {
  OfflineAudioRepositoryImpl({required this._store, required this._local});

  final AudioStoragePort _store;
  final OfflineAudioLocalDatasource _local;

  @override
  Future<LocalAudioSource?> lookup(String audioId) async {
    final index = _local.findByAudioIdSync(audioId);
    if (index == null) return null;
    // Índice órfão (ficheiro apagado pelo SO) fica até «Remover»: não há
    // reconcile de áudio — o player cai na rede como se não estivesse.
    if (!await _store.exists(index.storageKey)) return null;
    return LocalAudioSource(audioId: audioId, storageKey: index.storageKey);
  }

  @override
  Future<Set<String>> lookupBatch(Set<String> audioIds) async {
    final valid = <String>{};
    for (final index in _local.findByAudioIds(audioIds)) {
      if (await _store.exists(index.storageKey)) valid.add(index.audioId);
    }
    return valid;
  }

  @override
  Future<OfflineAudioEntry> upsert({
    required String audioId,
    required String r2Key,
    required Uint8List bytes,
  }) async {
    // O `r2Key` já é um path relativo único (`assets/praises/<p>/<m>.mp3`).
    final storageKey = await _store.writeAtomic(bytes, r2Key);
    final now = DateTime.now();
    await _local.put(
      OfflineAudioIndex()
        ..audioId = audioId
        ..r2Key = r2Key
        ..storageKey = storageKey
        ..fileSize = bytes.length
        ..downloadedAt = now,
    );
    return OfflineAudioEntry(
      audioId: audioId,
      r2Key: r2Key,
      storageKey: storageKey,
      fileSize: bytes.length,
      downloadedAt: now,
    );
  }

  @override
  Future<void> remove(String audioId) async {
    final index = _local.findByAudioIdSync(audioId);
    if (index == null) return;
    await _store.delete(index.storageKey);
    await _local.deleteByAudioId(audioId);
  }

  @override
  Future<List<OfflineAudioEntry>> listAll() async => [
    for (final index in _local.findAllSync())
      OfflineAudioEntry(
        audioId: index.audioId,
        r2Key: index.r2Key,
        storageKey: index.storageKey,
        fileSize: index.fileSize,
        downloadedAt: index.downloadedAt,
      ),
  ];

  @override
  Future<int> totalBytes() async => _local.sumFileSizes();

  @override
  Future<void> removeAll() async {
    await _store.deleteTree();
    await _local.clearAll();
  }
}
