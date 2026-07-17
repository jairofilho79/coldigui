import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/audio_flag_providers.dart';
import '../../domain/usecases/sync_audio_flags.dart';
import 'audio_flags_for_track_provider.dart';

class AudioFlagSyncState {
  const AudioFlagSyncState({this.isSyncing = false, this.lastResult});

  final bool isSyncing;
  final AudioFlagSyncResult? lastResult;

  AudioFlagSyncState copyWith({
    bool? isSyncing,
    AudioFlagSyncResult? lastResult,
  }) {
    return AudioFlagSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

final audioFlagSyncProvider =
    NotifierProvider<AudioFlagSyncNotifier, AudioFlagSyncState>(
      AudioFlagSyncNotifier.new,
    );

class AudioFlagSyncNotifier extends Notifier<AudioFlagSyncState> {
  Future<void>? _inFlight;
  String? _lastSyncedSub;

  @override
  AudioFlagSyncState build() {
    ref.listen(authStateProvider, (prev, next) {
      final user = next.asData?.value;
      if (user == null) {
        _lastSyncedSub = null;
        return;
      }
      if (_lastSyncedSub == user.googleSub) return;
      _lastSyncedSub = user.googleSub;
      unawaited(syncAfterLogin());
    }, fireImmediately: true);
    return const AudioFlagSyncState();
  }

  Future<AudioFlagSyncResult> sync() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      return AudioFlagSyncResult.skippedAuth;
    }

    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return state.lastResult ?? AudioFlagSyncResult.skippedAuth;
    }

    final future = _run(user.idToken);
    _inFlight = future;
    try {
      await future;
      return state.lastResult ?? const AudioFlagSyncResult();
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _run(String idToken) async {
    state = state.copyWith(isSyncing: true);
    try {
      final result = await ref.read(syncAudioFlagsProvider)(idToken: idToken);
      state = AudioFlagSyncState(isSyncing: false, lastResult: result);
      if (!result.skipped &&
          (result.pulled > 0 || result.pushed > 0 || result.deleted > 0)) {
        ref.invalidate(audioFlagsForTrackProvider);
      }
    } on Object {
      state = const AudioFlagSyncState(isSyncing: false);
    }
  }

  Future<void> syncAfterLogin() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    await ref.read(audioFlagRepositoryProvider).markAllPendingPush();
    await sync();
  }
}
