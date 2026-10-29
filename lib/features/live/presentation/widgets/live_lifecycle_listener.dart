import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../providers/live_session_controller.dart';

/// Liga o ciclo de vida da app e a conectividade ao [LiveSessionController]
/// (spec §6.1: sem retry em `paused`, retry imediato em `resumed`/online).
/// Montado no shell, como `OfflineLifecycleListener`.
class LiveLifecycleListener extends ConsumerStatefulWidget {
  const LiveLifecycleListener({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<LiveLifecycleListener> createState() =>
      _LiveLifecycleListenerState();
}

class _LiveLifecycleListenerState extends ConsumerState<LiveLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(liveSessionProvider.notifier).onAppLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityStreamProvider, (_, next) {
      final online = next.asData?.value;
      if (online != null) {
        ref.read(liveSessionProvider.notifier).onConnectivity(online);
      }
    });
    return widget.child;
  }
}
