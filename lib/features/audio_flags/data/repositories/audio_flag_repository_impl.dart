import 'dart:math';

import '../../../../core/database/collections/audio_flag.dart';
import '../../domain/entities/saved_audio_flag.dart';
import '../../domain/repositories/audio_flag_repository.dart';
import '../datasources/audio_flag_local_datasource.dart';

final _random = Random();

String _generateFlagId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final suffix = _random.nextInt(0xFFFFFF).toRadixString(36);
  return '$timestamp$suffix';
}

/// Orquestra [AudioFlagLocalDatasource].
class AudioFlagRepositoryImpl implements AudioFlagRepository {
  const AudioFlagRepositoryImpl(this._local);

  final AudioFlagLocalDatasource _local;

  @override
  Future<List<SavedAudioFlag>> getByAudioId(String audioId) async {
    final rows = await _local.findByAudioId(audioId);
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<SavedAudioFlag?> getById(String flagId) async {
    final row = await _local.findByFlagId(flagId);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<String> create({
    required String audioId,
    required int positionMs,
    String label = '',
    String? flagId,
    DateTime? createdAt,
  }) async {
    final id = flagId ?? _generateFlagId();
    final now = createdAt ?? DateTime.now().toUtc();
    final row = AudioFlag()
      ..flagId = id
      ..audioId = audioId
      ..positionMs = positionMs
      ..label = label.trim()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..syncStatus = PlaylistSyncStatus.pendingPush;
    await _local.insert(row);
    return id;
  }

  @override
  Future<void> delete(String flagId) => _local.softDeleteByFlagId(flagId);

  @override
  Future<void> hardDelete(String flagId) => _local.deleteByFlagId(flagId);

  @override
  Future<List<SavedAudioFlag>> getPendingPush() async {
    final rows = await _local.findPendingPush();
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<List<SavedAudioFlag>> getTombstones() async {
    final rows = await _local.findTombstones();
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<void> upsert(SavedAudioFlag flag) async {
    final row = AudioFlag()
      ..flagId = flag.flagId
      ..audioId = flag.audioId
      ..positionMs = flag.positionMs
      ..label = flag.label
      ..createdAt = flag.createdAt
      ..updatedAt = flag.updatedAt
      ..version = flag.version
      ..syncStatus = flag.syncStatus
      ..deletedAt = flag.deletedAt;
    await _local.insert(row);
  }

  @override
  Future<void> markAllPendingPush() => _local.markAllPendingPush();

  SavedAudioFlag _toEntity(AudioFlag row) => SavedAudioFlag(
    flagId: row.flagId,
    audioId: row.audioId,
    positionMs: row.positionMs,
    label: row.label,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt.millisecondsSinceEpoch == 0
        ? row.createdAt
        : row.updatedAt,
    version: row.version,
    syncStatus: row.syncStatus,
    deletedAt: row.deletedAt,
  );
}
