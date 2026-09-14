import 'dart:async';
import 'dart:convert';

import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/domain/live_reconnect_policy.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const _code = 'k7x2m9q';

const _entries = [
  {'id': 'a', 'kind': 'pdf'},
  {'id': 'b', 'kind': 'pdf'},
];

String _roomFrame({String room = _code}) => jsonEncode({
  't': 'room',
  'room': room,
  'status': 'live',
  'ownerName': 'Fulano',
  'role': 'consumer',
  'version': 1,
  'snapshot': {
    'playlistId': 'p1',
    'name': 'Culto',
    'entries': _entries,
    'focusKey': 'a',
  },
  'leaderPresent': true,
  'viewers': 3,
});

/// Política determinística — sem jitter, sempre o mesmo atraso curto — para
/// não depender de `Random` ao escolher quanto `async.elapse` avançar.
class _FixedDelayReconnectPolicy extends LiveReconnectPolicy {
  _FixedDelayReconnectPolicy(this.delay);
  final Duration delay;

  @override
  Duration delayFor(int attempt) => delay;
}

void main() {
  late FakeLiveTransport transport;
  late ProviderContainer container;

  ProviderContainer build(
    SharedPreferences prefs, {
    LiveReconnectPolicy? reconnectPolicy,
  }) {
    return ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue(
          (c) => Uri.parse('wss://test/api/live/$c/ws'),
        ),
        liveFocusResolverProvider.overrideWithValue((key) async => null),
        liveNavigatorProvider.overrideWithValue((_) {}),
        if (reconnectPolicy != null)
          liveReconnectPolicyProvider.overrideWithValue(reconnectPolicy),
      ],
    );
  }

  LiveSessionState state() => container.read(liveSessionProvider);
  LiveSessionController controller() =>
      container.read(liveSessionProvider.notifier);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    transport = FakeLiveTransport();
  });

  test(
    'handshake falho enquanto pausado não agenda timer — só religa em resumed',
    () async {
      final prefs = await SharedPreferences.getInstance();
      fakeAsync((async) {
        container = build(prefs);
        addTearDown(container.dispose);

        controller().onAppLifecycle(AppLifecycleState.paused);
        transport.failNext(1);

        unawaited(controller().join(_code));
        async.elapse(Duration.zero);

        expect(state().phase, LivePhase.joining);
        expect(transport.attempts, 1);

        // Pausado: `_scheduleReconnect` não arma timer — esperar não muda nada.
        async.elapse(const Duration(seconds: 40));
        expect(transport.attempts, 1);
        expect(state().phase, LivePhase.joining);

        // `resumed`: `joining` sem `_doConnect` em voo religa na hora.
        controller().onAppLifecycle(AppLifecycleState.resumed);
        async.elapse(Duration.zero);

        expect(transport.attempts, 2);
      });
    },
  );

  test(
    'prova de vida não religa enquanto pausado; resumed religa depois',
    () async {
      final prefs = await SharedPreferences.getInstance();
      fakeAsync((async) {
        container = build(prefs);
        addTearDown(container.dispose);

        unawaited(controller().join(_code));
        async.elapse(Duration.zero);
        transport.last.emit(_roomFrame());
        async.elapse(Duration.zero);
        expect(state().phase, LivePhase.connected);

        // `resumed` com conexão viva: manda `ping` e arma a prova de 5 s.
        controller().onAppLifecycle(AppLifecycleState.resumed);
        expect(transport.last.sent.last, 'ping');

        // App vai para segundo plano antes do `pong`.
        controller().onAppLifecycle(AppLifecycleState.paused);

        // A prova estoura enquanto pausado: o controller percebe que a
        // conexão está morta (fase `reconnecting`), mas não tenta religar —
        // isso é trabalho do próximo `resumed`.
        async.elapse(kLivePingProbeTimeout);
        expect(state().phase, LivePhase.reconnecting);
        expect(transport.attempts, 1);

        controller().onAppLifecycle(AppLifecycleState.resumed);
        async.elapse(Duration.zero);
        expect(transport.attempts, 2);
      });
    },
  );

  test('prova de vida presa a uma conexão velha não derruba a nova depois de reconectar', () async {
    final prefs = await SharedPreferences.getInstance();
    fakeAsync((async) {
      container = build(
        prefs,
        reconnectPolicy: _FixedDelayReconnectPolicy(
          const Duration(milliseconds: 100),
        ),
      );
      addTearDown(container.dispose);

      unawaited(controller().join(_code));
      async.elapse(Duration.zero);
      transport.last.emit(_roomFrame());
      async.elapse(Duration.zero);
      expect(state().phase, LivePhase.connected);

      // `resumed`: ping na conexão N, prova de 5 s armada.
      controller().onAppLifecycle(AppLifecycleState.resumed);
      expect(transport.attempts, 1);

      // A rede cai por fora — desconexão "normal" (não é um close code do
      // DO), então o controller religa sozinho com o backoff (100 ms fixos
      // aqui).
      unawaited(transport.last.drop());
      async.elapse(Duration.zero);
      expect(state().phase, LivePhase.reconnecting);

      async.elapse(const Duration(milliseconds: 100));
      async.elapse(Duration.zero);
      expect(transport.attempts, 2);

      // A nova conexão (N+1) confirma a sala antes da prova de N completar
      // os 5 s.
      transport.last.emit(_roomFrame());
      async.elapse(Duration.zero);
      expect(state().phase, LivePhase.connected);
      expect(transport.last.isOpen, isTrue);

      // Os 5 s da prova de N terminam de estourar: como a geração mudou,
      // o timer velho não faz nada com a conexão nova.
      async.elapse(kLivePingProbeTimeout);
      expect(transport.last.isOpen, isTrue);
      expect(transport.attempts, 2);
      expect(state().phase, LivePhase.connected);
    });
  });
}
