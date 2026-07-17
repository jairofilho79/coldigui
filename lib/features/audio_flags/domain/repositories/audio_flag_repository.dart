import '../entities/saved_audio_flag.dart';

/// Persistência local de marcadores de áudio.
abstract class AudioFlagRepository {
  Future<List<SavedAudioFlag>> getByAudioId(String audioId);

  Future<SavedAudioFlag?> getById(String flagId);

  Future<String> create({
    required String audioId,
    required int positionMs,
    String label = '',
    String? flagId,
    DateTime? createdAt,
  });

  Future<void> delete(String flagId);

  Future<void> hardDelete(String flagId);

  Future<List<SavedAudioFlag>> getPendingPush();

  Future<List<SavedAudioFlag>> getTombstones();

  Future<void> upsert(SavedAudioFlag flag);

  Future<void> markAllPendingPush();
}
