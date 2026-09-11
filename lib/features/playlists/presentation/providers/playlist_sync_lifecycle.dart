import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_sync_provider.dart';

/// Dispara sync ao voltar ao foreground / online (debounce 30s).
///
/// Usado pela [PlaylistsScreen]; no-op se deslogado (gate no sync). A tela
/// recarrega dentro do próprio [PlaylistSyncNotifier] quando a sync mexeu em
/// alguma linha — aqui só se agenda a rodada.
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
      if (!mounted) return;
      unawaited(ref.read(playlistSyncProvider.notifier).sync());
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
