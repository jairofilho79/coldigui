import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/save_data_stub.dart'
    if (dart.library.js_interop) '../../../core/network/save_data_web.dart';
import '../../../core/utils/retryable_init.dart';
import '../../catalog/presentation/providers/louvores_manifest_provider.dart';
import 'providers/pdf_reader_prefetch_providers.dart';

final RetryableInit<void> _pdfrxInit = RetryableInit(pdfrxFlutterInitialize);
var _idlePreloadScheduled = false;

/// Ociosidade exigida depois do manifest antes de buscar o `pdfium.wasm` (A11).
const pdfrxPreloadIdleDelay = Duration(seconds: 3);

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

/// Indireção sobre [schedulePdfrxIdlePreload] — permite observar o
/// agendamento em teste sem baixar o `pdfium.wasm` de verdade.
@visibleForTesting
final pdfrxIdlePreloadSchedulerProvider = Provider<void Function()>(
  (ref) => schedulePdfrxIdlePreload,
);

/// Agenda [schedulePdfrxIdlePreload] só depois que o manifest sai da frente (A11).
///
/// O `pdfium.wasm` tem 5,2 MB e o manifest 1,45 MB: disparar os dois logo após
/// o primeiro frame fazia um brigar pela banda do outro justamente no boot.
/// Aqui o preload espera [louvoresManifestProvider] chegar a `data` **ou**
/// `error` e, depois disso, mais [pdfrxPreloadIdleDelay] de folga.
///
/// Continua valendo a política Wi-Fi-only dos downloads offline; na web, onde
/// `connectivity_plus` não distingue Wi-Fi de dados móveis, `saveData` do
/// navegador é o desempate possível.
class PdfrxIdlePreloader extends ConsumerStatefulWidget {
  const PdfrxIdlePreloader({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PdfrxIdlePreloader> createState() => _PdfrxIdlePreloaderState();
}

class _PdfrxIdlePreloaderState extends ConsumerState<PdfrxIdlePreloader> {
  Timer? _idleTimer;
  var _armed = false;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  /// Arma a folga ociosa uma única vez, quando o manifest já não usa a rede.
  void _armIdleTimer() {
    if (_armed) return;
    _armed = true;
    _idleTimer = Timer(pdfrxPreloadIdleDelay, () {
      unawaited(_maybeSchedulePreload());
    });
  }

  Future<void> _maybeSchedulePreload() async {
    if (isSaveDataEnabled()) {
      debugPrint('[pdfrx] preload adiado: navegador em modo economia de dados');
      return;
    }

    final checker = ref.read(networkConnectionCheckerProvider);
    if (!await checker.isUnmeteredConnection()) return;
    if (!mounted) return;

    ref.read(pdfrxIdlePreloadSchedulerProvider)();
  }

  @override
  Widget build(BuildContext context) {
    // `listen` (não `watch`): o preload reage à conclusão do manifest sem
    // reconstruir a subárvore inteira quando os ~4600 louvores chegam.
    ref.listen(louvoresManifestProvider, (_, next) {
      if (next.hasValue || next.hasError) _armIdleTimer();
    });

    final manifest = ref.read(louvoresManifestProvider);
    if (manifest.hasValue || manifest.hasError) _armIdleTimer();

    return widget.child;
  }
}
