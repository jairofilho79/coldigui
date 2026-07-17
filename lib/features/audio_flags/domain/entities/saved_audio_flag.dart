import '../../../../core/database/collections/playlist_sync_status.dart';

export '../../../../core/database/collections/playlist_sync_status.dart';

/// Marcador de áudio do usuário (domínio — sem Isar).
class SavedAudioFlag {
  SavedAudioFlag({
    required this.flagId,
    required this.audioId,
    required this.positionMs,
    required this.createdAt,
    this.label = '',
    DateTime? updatedAt,
    this.version = 1,
    this.syncStatus = PlaylistSyncStatus.synced,
    this.deletedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String flagId;
  final String audioId;
  final int positionMs;
  final String label;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final PlaylistSyncStatus syncStatus;
  final DateTime? deletedAt;

  Duration get position => Duration(milliseconds: positionMs);

  SavedAudioFlag copyWith({
    String? flagId,
    String? audioId,
    int? positionMs,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return SavedAudioFlag(
      flagId: flagId ?? this.flagId,
      audioId: audioId ?? this.audioId,
      positionMs: positionMs ?? this.positionMs,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
