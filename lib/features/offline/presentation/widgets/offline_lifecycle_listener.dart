import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/providers/catalog_checksum_poll_provider.dart';
import '../../data/providers/offline_providers.dart';
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
    switch (state) {
      case AppLifecycleState.paused:
        unawaited(
          ref
              .read(offlinePdfRepositoryProvider)
              .flushPendingTouchLastAccessed(),
        );
      case AppLifecycleState.resumed:
        ref.read(offlineReconcileProvider.notifier).requestReconcileDebounced();
        ref.read(catalogChecksumPollProvider.notifier).requestPollDebounced();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
