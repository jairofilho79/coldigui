import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/utils/retryable_init.dart';
import 'providers/pdf_reader_prefetch_providers.dart';

final RetryableInit<void> _pdfrxInit = RetryableInit(pdfrxFlutterInitialize);
var _idlePreloadScheduled = false;

/// Inicializa pdfrx/pdfium — idempotente; compartilhada entre preload e
/// abertura de PDF. Em falha, não memoiza o erro: a próxima chamada tenta
/// de novo em vez de re-aguardar o mesmo [Future] rejeitado.
Future<void> ensurePdfrxInitialized() => _pdfrxInit();

/// Baixa/compila WASM pdfrx após UI visível, sem competir com paint ou fetch do catálogo.
void schedulePdfrxIdlePreload() {
  if (_idlePreloadScheduled || AppConfig.isApiBaseUrlMissing) return;
  _idlePreloadScheduled = true;

  SchedulerBinding.instance.scheduleFrameCallback((_) {
    SchedulerBinding.instance.scheduleTask(() {
      unawaited(ensurePdfrxInitialized().catchError((_) {}));
    }, Priority.idle);
  });
}

/// Dispara [schedulePdfrxIdlePreload] após o primeiro frame do subtree.
///
/// Só prefetcha em conexão não medida (Wi-Fi/ethernet), alinhado à política
/// Wi-Fi-only de downloads offline.
class PdfrxIdlePreloader extends ConsumerStatefulWidget {
  const PdfrxIdlePreloader({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PdfrxIdlePreloader> createState() => _PdfrxIdlePreloaderState();
}

class _PdfrxIdlePreloaderState extends ConsumerState<PdfrxIdlePreloader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeSchedulePreload());
    });
  }

  Future<void> _maybeSchedulePreload() async {
    final checker = ref.read(networkConnectionCheckerProvider);
    if (!await checker.isUnmeteredConnection()) return;
    schedulePdfrxIdlePreload();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
