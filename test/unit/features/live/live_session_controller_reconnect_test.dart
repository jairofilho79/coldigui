import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/domain/live_reconnect_policy.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/live/presentation/providers/live_navigation_providers.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';
const _entries = [
  {'id': 'a', 'kind': 'pdf'},
  {'id': 'b', 'kind': 'pdf'},
];

String roomFrame({int version = 1, String? focusKey}) => jsonEncode({
  't': 'room',
  'room': code,
  'status': 'live',
  'ownerName': 'F',
  'role': 'consumer',
  'version': version,
  'snapshot': {
    'playlistId': 'p1',
    'name': 'Culto',
    'entries': _entries,
    'focusKey': focusKey,
  },
  'leaderPresent': true,
  'viewers': 1,
});

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

/// Política determinística — sem jitter, sempre o mesmo atraso curto — para
/// não depender de `Random` ao escolher quanto `async.elapse` avançar.
class _FixedDelayReconnectPolicy extends LiveReconnectPolicy {
  _FixedDelayReconnectPolicy(this.delay);
  final Duration delay;

  @override
  Duration delayFor(int attempt) => delay;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer(
    FakeLiveTransport transport, {
    LiveReconnectPolicy? reconnectPolicy,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue((c) => Uri.parse('wss://test/$c')),
        liveReconnectPolicyProvider.overrideWithValue(
          reconnectPolicy ?? LiveReconnectPolicy(random: _ZeroRandom()),
        ),
        liveFocusResolverProvider.overrideWithValue((_) async => null),
        liveNavigatorProvider.overrideWithValue((_) {}),
      ],
    );
    return container;
  }

  test(
    'handshake falho enquanto pausado não agenda timer — só religa em resumed',
    () {
      fakeAsync((async) {
        final transport = FakeLiveTransport();
        final container = makeContainer(transport);
        final controller = container.read(liveSessionProvider.notifier);

        controller.onAppLifecycle(AppLifecycleState.paused);
        transport.failNext(1);

        unawaited(controller.join(code));
        async.elapse(Duration.zero);

        expect(container.read(liveSessionProvider).phase, LivePhase.joining);
        expect(transport.attempts, 1);

        // Pausado: `_scheduleReconnect` não arma timer — esperar não muda nada.
        async.elapse(const Duration(seconds: 40));
        expect(transport.attempts, 1);
        expect(container.read(liveSessionProvider).phase, LivePhase.joining);

        // `resumed`: `joining` sem `_doConnect` em voo religa na hora.
        controller.onAppLifecycle(AppLifecycleState.resumed);
        async.elapse(Duration.zero);

        expect(transport.attempts, 2);
        container.dispose();
      });
    },
  );

  test('prova de vida não religa enquanto pausado; resumed religa depois', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);

      unawaited(controller.join(code));
      async.elapse(Duration.zero);
      transport.last.emit(roomFrame());
      async.elapse(Duration.zero);
      expect(container.read(liveSessionProvider).phase, LivePhase.connected);

      // `resumed` com conexão viva: manda `ping` e arma a prova de 5 s.
      controller.onAppLifecycle(AppLifecycleState.resumed);
      expect(transport.last.sent.last, 'ping');

      // App vai para segundo plano antes do `pong`.
      controller.onAppLifecycle(AppLifecycleState.paused);

      // A prova estoura enquanto pausado: o controller percebe que a
      // conexão está morta (fase `reconnecting`), mas não tenta religar —
      // isso é trabalho do próximo `resumed`.
      async.elapse(kLivePingProbeTimeout);
      expect(container.read(liveSessionProvider).phase, LivePhase.reconnecting);
      expect(transport.attempts, 1);

      controller.onAppLifecycle(AppLifecycleState.resumed);
      async.elapse(Duration.zero);
      expect(transport.attempts, 2);
      container.dispose();
    });
  });

  test('prova de vida presa a uma conexão velha não derruba a nova depois de reconectar', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(
        transport,
        reconnectPolicy: _FixedDelayReconnectPolicy(
          const Duration(milliseconds: 100),
        ),
      );
      final controller = container.read(liveSessionProvider.notifier);

      unawaited(controller.join(code));
      async.elapse(Duration.zero);
      transport.last.emit(roomFrame());
      async.elapse(Duration.zero);
      expect(container.read(liveSessionProvider).phase, LivePhase.connected);

      // `resumed`: ping na conexão N, prova de 5 s armada.
      controller.onAppLifecycle(AppLifecycleState.resumed);
      expect(transport.attempts, 1);

      // A rede cai por fora — desconexão "normal" (não é um close code do
      // DO), então o controller religa sozinho com o backoff (100 ms fixos
      // aqui).
      unawaited(transport.last.drop());
      async.elapse(Duration.zero);
      expect(container.read(liveSessionProvider).phase, LivePhase.reconnecting);

      async.elapse(const Duration(milliseconds: 100));
      async.elapse(Duration.zero);
      expect(transport.attempts, 2);

      // A nova conexão (N+1) confirma a sala antes da prova de N completar
      // os 5 s.
      transport.last.emit(roomFrame());
      async.elapse(Duration.zero);
      expect(container.read(liveSessionProvider).phase, LivePhase.connected);
      expect(transport.last.isOpen, isTrue);

      // Os 5 s da prova de N terminam de estourar: como a geração mudou,
      // o timer velho não faz nada com a conexão nova.
      async.elapse(kLivePingProbeTimeout);
      expect(transport.last.isOpen, isTrue);
      expect(transport.attempts, 2);
      expect(container.read(liveSessionProvider).phase, LivePhase.connected);
      container.dispose();
    });
  });

  test(
    'queda com 1006 → reconnecting, religa após 1 s e manda hello{since}',
    () {
      fakeAsync((async) {
        final transport = FakeLiveTransport();
        final container = makeContainer(transport);
        final controller = container.read(liveSessionProvider.notifier);
        controller.join(code);
        async.flushMicrotasks();
        transport.last.emit(roomFrame(version: 4));
        async.flushMicrotasks();

        transport.last.drop();
        async.flushMicrotasks();
        expect(
          container.read(liveSessionProvider).phase,
          LivePhase.reconnecting,
        );
        // Projeção fica de pé durante a reconexão: a tela não pisca vazia.
        expect(container.read(liveProjectionProvider), isNotNull);

        async.elapse(const Duration(milliseconds: 999));
        expect(transport.attempts, 1);
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(transport.attempts, 2);
        final hello =
            jsonDecode(transport.last.sent.single) as Map<String, Object?>;
        expect(hello['since'], 4);

        transport.last.emit(roomFrame(version: 4));
        async.flushMicrotasks();
        expect(container.read(liveSessionProvider).phase, LivePhase.connected);
        container.dispose();
      });
    },
  );

  test('backoff cresce 1, 2, 4 s entre handshakes falhados depois de já ter estado ligado', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      transport.last.drop();
      async.flushMicrotasks();

      transport.failNext(3);
      async.elapse(const Duration(milliseconds: 999));
      async.flushMicrotasks();
      expect(transport.attempts, 1);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(transport.attempts, 2);
      async.elapse(const Duration(milliseconds: 1999));
      async.flushMicrotasks();
      expect(transport.attempts, 2);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(transport.attempts, 3);
      async.elapse(const Duration(milliseconds: 3999));
      async.flushMicrotasks();
      expect(transport.attempts, 3);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(transport.attempts, 4);
      // Nunca vira unavailable depois de já ter estado conectado.
      expect(container.read(liveSessionProvider).phase, LivePhase.reconnecting);
      container.dispose();
    });
  });

  test(
    '3 handshakes falhados ao entrar → unavailable, sem mais tentativas',
    () {
      fakeAsync((async) {
        final transport = FakeLiveTransport()..failNext(3);
        final container = makeContainer(transport);
        container.read(liveSessionProvider.notifier).join(code);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(transport.attempts, 3);
        expect(
          container.read(liveSessionProvider).phase,
          LivePhase.unavailable,
        );
        async.elapse(const Duration(minutes: 1));
        expect(transport.attempts, 3);
        container.dispose();
      });
    },
  );

  test('em paused nenhum timer religa; em resumed religa na hora', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();

      controller.onAppLifecycle(AppLifecycleState.paused);
      transport.last.drop();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));
      expect(transport.attempts, 1);
      expect(container.read(liveSessionProvider).phase, LivePhase.reconnecting);

      controller.onAppLifecycle(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(transport.attempts, 2);
      container.dispose();
    });
  });

  test('resumed com socket "vivo" manda ping; sem pong em 5 s religa', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();

      controller.onAppLifecycle(AppLifecycleState.resumed);
      expect(transport.last.sent.last, 'ping');
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(transport.attempts, 2);

      // Com pong, nada acontece.
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      controller.onAppLifecycle(AppLifecycleState.resumed);
      transport.last.emit('pong');
      async.elapse(const Duration(seconds: 6));
      expect(transport.attempts, 2);
      container.dispose();
    });
  });

  test('evento de conectividade online em reconnecting religa sem esperar o backoff', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      transport.last.drop();
      async.flushMicrotasks();
      transport.failNext(2);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(transport.attempts, 3); // próximo só em 4 s
      controller.onConnectivity(true);
      async.flushMicrotasks();
      expect(transport.attempts, 4);
      container.dispose();
    });
  });

  test(
    'dispose do container fecha o socket e nenhum frame tardio é processado',
    () async {
      // `lingerOnClose`: o fake não fecha o stream quando o cliente chama
      // `close()` — sem isto, `emit` depois do `close()` já seria um no-op
      // do próprio fake (ver `FakeLiveConnection.emit`), e o teste provaria
      // nada sobre o controller. Com o stream aberto, é `_sub?.cancel()` +
      // a checagem de geração/`ref.mounted` do controller quem tem de
      // ignorar o frame tardio — a navegação é a prova disso.
      final transport = FakeLiveTransport()..lingerOnClose = true;
      final navigated = <String>[];
      final container = ProviderContainer(
        overrides: [
          ...standardTestOverrides(prefs: prefs),
          liveTransportProvider.overrideWithValue(transport),
          liveWsUriProvider.overrideWithValue(
            (c) => Uri.parse('wss://test/$c'),
          ),
          liveReconnectPolicyProvider.overrideWithValue(
            LiveReconnectPolicy(random: _ZeroRandom()),
          ),
          liveFocusResolverProvider.overrideWithValue(
            (key) async => '/leitor?key=$key',
          ),
          liveNavigatorProvider.overrideWithValue(navigated.add),
        ],
      );
      final controller = container.read(liveSessionProvider.notifier);
      await controller.join(code);
      transport.last.emit(roomFrame(focusKey: 'a'));
      await Future<void>.delayed(Duration.zero);
      expect(navigated, ['/leitor?key=a']);

      final conn = transport.last;
      container.dispose();
      expect(conn.closedWith, 1000);

      // Um container novo (hot restart) começa do zero e não vê o socket velho.
      final fresh = makeContainer(transport);

      // Frame tardio: versão maior e foco diferente — se o controller velho
      // o processasse, navegaria para 'b'.
      conn.emit(roomFrame(version: 9, focusKey: 'b'));
      await Future<void>.delayed(Duration.zero);

      expect(navigated, ['/leitor?key=a']); // nenhuma navegação nova
      expect(fresh.read(liveProjectionProvider), isNull);
      expect(fresh.read(liveSessionProvider).phase, LivePhase.idle);
      fresh.dispose();
    },
  );
}
