import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/offline_reconcile_provider.dart';

/// Observa lifecycle e dispara reconcile debounced ao retornar ao foreground.
///
/// Montado no shell — **nunca** em `main()`. Cold start não executa reconcile.
class OfflineLifecycleListener extends ConsumerStatefulWidget {
  const OfflineLifecycleListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineLifecycleListener> createState() =>
      _OfflineLifecycleListenerState();
}

class _OfflineLifecycleListenerState
    extends ConsumerState<OfflineLifecycleListener>
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
    if (state == AppLifecycleState.resumed) {
      ref.read(offlineReconcileProvider.notifier).requestReconcileDebounced();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
