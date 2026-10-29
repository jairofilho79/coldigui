import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/audio_flag_providers.dart';
import '../../domain/entities/saved_audio_flag.dart';
import 'audio_flag_sync_provider.dart';

/// Flags ativas (sem tombstone) para um [audioId], ordenadas por posição.
final audioFlagsForTrackProvider =
    FutureProvider.family<List<SavedAudioFlag>, String>((ref, audioId) async {
      if (audioId.isEmpty) return const [];
      return ref.watch(audioFlagRepositoryProvider).getByAudioId(audioId);
    });

/// Mutações de flags + invalidate + sync best-effort.
final audioFlagActionsProvider = Provider<AudioFlagActions>((ref) {
  return AudioFlagActions(ref);
});

class AudioFlagActions {
  AudioFlagActions(this._ref);

  final Ref _ref;

  Future<void> add({
    required String audioId,
    required int positionMs,
    String label = '',
  }) async {
    await _ref
        .read(audioFlagRepositoryProvider)
        .create(audioId: audioId, positionMs: positionMs, label: label);
    _ref.invalidate(audioFlagsForTrackProvider(audioId));
    unawaited(_ref.read(audioFlagSyncProvider.notifier).sync());
  }

  Future<void> remove({required String audioId, required String flagId}) async {
    await _ref.read(audioFlagRepositoryProvider).delete(flagId);
    _ref.invalidate(audioFlagsForTrackProvider(audioId));
    unawaited(_ref.read(audioFlagSyncProvider.notifier).sync());
  }
}
