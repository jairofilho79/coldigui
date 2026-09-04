import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import 'isar_bootstrap.dart';

/// Tempo máximo aceitável para abrir o Isar antes de degradar (spec C.9).
const isarOpenTimeout = Duration(seconds: 15);

/// Indireção sobre [openAppIsar] só para permitir simular travamentos em
/// teste (ver `test/unit/core/database/isar_provider_timeout_test.dart`).
@visibleForTesting
final isarOpenerProvider = Provider<Future<Isar> Function()>(
  (ref) => openAppIsar,
);

/// Abre Isar em background após o primeiro frame (Fase B web perf).
///
/// Se a abertura travar (ex.: lock de OPFS preso), falha após
/// [isarOpenTimeout] em vez de deixar o app preso no spinner para sempre;
/// [BootstrapApp] monta [ColdiguiApp] mesmo em erro (modo degradado sem storage).
///
/// O timer do timeout é sempre cancelado via [Ref.onDispose] — evita deixar
/// um `Timer` real pendente quando o provider é descartado antes da
/// abertura terminar (ex.: fim de um teste de widget que não espera o Isar
/// abrir; usar `Future.timeout` puro deixaria esse timer pendente).
///
/// `Future.any` não cancela o "perdedor" da corrida: se o timeout vencer e
/// [opener] só resolver depois, essa instância chegaria tarde demais e
/// ninguém mais a fecharia. Por isso guardamos [opener] numa variável e, se
/// ela resolver (ou falhar) depois que [timedOut] já for `true`, fechamos a
/// instância tardia (ou só logamos a falha tardia) em vez de vazá-la.
final isarInitializerProvider = FutureProvider<Isar>((ref) async {
  final opener = ref.watch(isarOpenerProvider);

  var timedOut = false;
  final timeoutCompleter = Completer<Isar>();
  final timer = Timer(isarOpenTimeout, () {
    timedOut = true;
    debugPrint('[isar] abertura excedeu 15 s; modo degradado');
    timeoutCompleter.completeError(
      TimeoutException(
        'Abertura do Isar excedeu $isarOpenTimeout',
        isarOpenTimeout,
      ),
    );
  });
  ref.onDispose(timer.cancel);

  final openerFuture = opener();
  unawaited(
    openerFuture.then(
      (isar) {
        if (timedOut) isar.close();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (timedOut) {
          debugPrint('[isar] abertura tardia falhou após o timeout: $error');
        }
      },
    ),
  );

  final isar = await Future.any([openerFuture, timeoutCompleter.future]);
  timer.cancel();
  ref.onDispose(isar.close);
  return isar;
});

/// Isar quando disponível; `null` em modo degradado (falha de OPFS/WASM).
final optionalIsarProvider = Provider<Isar?>((ref) {
  return ref.watch(isarInitializerProvider).asData?.value;
});

/// `true` quando [isarInitializerProvider] concluiu com sucesso.
final isarAvailableProvider = Provider<bool>((ref) {
  return ref.watch(optionalIsarProvider) != null;
});

/// Provider de instância Isar Plus (ADR-001).
///
/// Schemas: [LouvorCache], [CarouselEntry], [Playlist], [OfflinePdfIndex].
/// Resolve via [isarInitializerProvider] em produção; sobrescrever em testes com
/// [isarProvider.overrideWithValue].
final isarProvider = Provider<Isar>((ref) {
  return ref.watch(isarInitializerProvider).requireValue;
});
