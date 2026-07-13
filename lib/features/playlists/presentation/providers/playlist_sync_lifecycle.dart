import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_sync_provider.dart';
import 'playlists_provider.dart';

/// Dispara sync ao voltar ao foreground / online (debounce 30s).
///
/// Usado pela [PlaylistsScreen]; no-op se deslogado (gate no sync).
mixin PlaylistSyncLifecycleMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  Timer? _debounce;
  DateTime? _lastSyncAt;

  void startPlaylistSyncLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    schedulePlaylistSync();
  }

  void stopPlaylistSyncLifecycle() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
  }

  void schedulePlaylistSync({Duration debounce = Duration.zero}) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () {
      final last = _lastSyncAt;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(seconds: 30) &&
          debounce > Duration.zero) {
        return;
      }
      _lastSyncAt = DateTime.now();
      unawaited(
        ref.read(playlistSyncProvider.notifier).sync().then((result) async {
          if (!result.skipped &&
              (result.pulled > 0 || result.pushed > 0 || result.deleted > 0)) {
            if (mounted) {
              await ref.read(playlistsProvider.notifier).reload();
            }
          }
        }),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      schedulePlaylistSync(debounce: const Duration(seconds: 30));
    }
  }

  @override
  void didChangeMetrics() {
    // Web: retomada de aba às vezes só dispara metrics; sync debounced.
    if (kIsWeb) {
      schedulePlaylistSync(debounce: const Duration(seconds: 30));
    }
  }
}
