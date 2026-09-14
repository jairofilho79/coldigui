import 'dart:convert';
import 'dart:math';

import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/domain/live_reconnect_policy.dart';
import 'package:coldigui/features/live/presentation/providers/live_leader_session_prefs.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';
const user = AuthUser(
  googleSub: 'owner',
  sessionToken: 'sess_owner',
  name: 'Fulano',
);

final playlist = SavedPlaylist(
  playlistId: 'p1',
  nome: 'Culto',
  createdAt: DateTime(2026, 9, 14),
  entries: const [
    PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
    PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
  ],
);

String roomFrame({
  String status = 'live',
  int version = 1,
  String role = 'leader',
}) => jsonEncode({
  't': 'room',
  'room': code,
  'status': status,
  'ownerName': 'Fulano',
  'role': role,
  'version': version,
  'snapshot': null,
  'leaderPresent': true,
  'viewers': 0,
});

Map<String, Object?> lastSent(FakeLiveTransport t) =>
    jsonDecode(t.last.sent.last) as Map<String, Object?>;

List<Object?> sentTypes(FakeLiveTransport t) => t.last.sent
    .map((s) => (jsonDecode(s) as Map<String, Object?>)['t'])
    .toList();

/// Sem jitter — os testes de backoff (3 falhas → `unavailable`) precisam de
/// atrasos determinísticos para `fakeAsync.elapse` acertar em cheio.
class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

void main() {
  late SharedPreferences prefs;
  late FakeLiveTransport transport;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    transport = FakeLiveTransport();
    container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue((c) => Uri.parse('wss://test/$c')),
        liveReconnectPolicyProvider.overrideWithValue(
          LiveReconnectPolicy(random: _ZeroRandom()),
        ),
        liveFocusResolverProvider.overrideWithValue((_) async => null),
        liveNavigatorProvider.overrideWithValue((_) {}),
        authStateProvider.overrideWith(() => FakeAuthNotifier(user)),
        // Lista ativa = `playlist`, sem Isar (fake da suíte de playlists).
        playlistsProvider.overrideWith(
          () => FakePlaylistsNotifier([
            PlaylistViewItem(playlist: playlist, pdfLabels: const []),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activePlaylistIdProvider.notifier).set('p1');
    container.read(liveMyRoomCodeProvider.notifier).set(code);
    // `startLive`/`resumeLeader` esperam `authStateProvider.future` por
    // conta própria agora (fix round 1, Important 3) — não precisa mais
    // "esquentar" o provider aqui.
  });

  LiveSessionController controller() =>
      container.read(liveSessionProvider.notifier);

  test(
    'startLive manda hello com token e start com a lista ativa e o foco',
    () async {
      container.read(carouselFocusedKeyProvider.notifier).focus('b');
      await controller().startLive(code: code, playlistId: 'p1');
      final sent = transport.last.sent
          .map((s) => jsonDecode(s) as Map<String, Object?>)
          .toList();
      expect(sent[0]['t'], 'hello');
      expect(sent[0]['sessionToken'], 'sess_owner');
      expect(sent[1]['t'], 'start');
      final snapshot = sent[1]['snapshot'] as Map<String, Object?>;
      expect(snapshot['playlistId'], 'p1');
      expect(snapshot['name'], 'Culto');
      expect((snapshot['entries'] as List).length, 2);
      expect(snapshot['focusKey'], 'b');
      // Pref de retomada gravada.
      expect(container.read(liveLeaderSessionPrefsProvider).read()?.code, code);
    },
  );

  test('ordem real dos frames: room{idle} antes de room{live} (eco do hello '
      'antes do start) não duplica start nem manda set à toa', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    // RoomCore responde ao `hello` antes de processar o `start` já
    // enfileirado atrás dele — o primeiro `room` que volta é `idle`.
    transport.last.emit(roomFrame(status: 'idle'));
    await Future<void>.delayed(Duration.zero);
    // Só depois o DO aplica o `start` e manda o `room{live}` que o confirma.
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    final types = sentTypes(transport);
    expect(types.where((t) => t == 'start').length, 1);
    expect(types.where((t) => t == 'set').length, 0);
  });

  test('handshake falha antes do primeiro start: a reconexão reenvia start uma única vez', () async {
    transport.failNext(1);
    await controller().startLive(code: code, playlistId: 'p1');
    // O primeiro handshake falhou: nenhuma conexão chegou a existir, logo
    // nenhum `start` foi mandado (`_conn` continuou nulo).
    expect(transport.connections, isEmpty);
    controller().onConnectivity(true);
    await Future<void>.delayed(Duration.zero);
    transport.last.emit(roomFrame(status: 'idle'));
    await Future<void>.delayed(Duration.zero);
    expect(sentTypes(transport).where((t) => t == 'start').length, 1);
  });

  test('3 handshakes falhados → unavailable limpa _pendingStart; join novo não reenvia start sozinho', () {
    fakeAsync((async) {
      transport.failNext(3);
      controller().startLive(code: code, playlistId: 'p1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(container.read(liveSessionProvider).phase, LivePhase.unavailable);
      expect(transport.attempts, 3);

      controller().join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame(status: 'idle'));
      async.flushMicrotasks();
      expect(sentTypes(transport).where((t) => t == 'start').length, 0);
    });
  });

  test('room live como leader → isLeading; mudança de foco dispara set após o debounce', () {
    fakeAsync((async) {
      controller().startLive(code: code, playlistId: 'p1');
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      expect(container.read(liveSessionProvider).isLeading, isTrue);

      final before = transport.last.sent.length;
      container.read(carouselFocusedKeyProvider.notifier).focus('b');
      async.elapse(const Duration(milliseconds: 299));
      expect(transport.last.sent.length, before);
      async.elapse(const Duration(milliseconds: 1));
      expect(lastSent(transport)['t'], 'set');
      expect((lastSent(transport)['snapshot'] as Map)['focusKey'], 'b');
    });
  });

  test('ack atualiza version e viewers', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    transport.last.emit(roomFrame());
    transport.last.emit(
      jsonEncode({'t': 'ack', 'room': code, 'version': 7, 'viewers': 12}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveSessionProvider).version, 7);
    expect(container.read(liveSessionProvider).viewers, 12);
  });

  test('ao religar, o gestor reenvia set com a lista corrente', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    await transport.last.drop();
    await Future<void>.delayed(Duration.zero);
    controller().onConnectivity(true);
    await Future<void>.delayed(Duration.zero);
    transport.last.emit(roomFrame(version: 3));
    await Future<void>.delayed(Duration.zero);
    expect(lastSent(transport)['t'], 'set');
  });

  test('endLive manda end, vai a ended{leader} e apaga a pref', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    await controller().endLive();
    expect(lastSent(transport)['t'], 'end');
    expect(container.read(liveSessionProvider).phase, LivePhase.ended);
    expect(container.read(liveSessionProvider).endReason, LiveEndReason.leader);
    expect(container.read(liveLeaderSessionPrefsProvider).read(), isNull);
  });

  test(
    'segundo dispositivo: ended{replaced} + 4002 → ended, pref apagada',
    () async {
      await controller().startLive(code: code, playlistId: 'p1');
      transport.last.emit(roomFrame());
      transport.last.emit(
        jsonEncode({'t': 'ended', 'room': code, 'reason': 'replaced'}),
      );
      await transport.last.drop(code: 4002);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(liveSessionProvider).endReason,
        LiveEndReason.replaced,
      );
      expect(container.read(liveLeaderSessionPrefsProvider).read(), isNull);
    },
  );

  test('room ended para quem retoma tarde limpa a pref', () async {
    await container
        .read(liveLeaderSessionPrefsProvider)
        .write(
          const LiveLeaderSession(
            code: code,
            playlistId: 'p1',
            playlistName: 'Culto',
          ),
        );
    await controller().resumeLeader(
      const LiveLeaderSession(
        code: code,
        playlistId: 'p1',
        playlistName: 'Culto',
      ),
    );
    transport.last.emit(roomFrame(status: 'ended'));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(liveSessionProvider).roomStatus,
      LiveRoomStatus.ended,
    );
    expect(container.read(liveLeaderSessionPrefsProvider).read(), isNull);
  });

  test('not_leader no hello (token de outra conta) deixa o consumidor e marca lastError', () async {
    container.read(liveMyRoomCodeProvider.notifier).set(null);
    await controller().join(code);
    transport.last.emit(
      jsonEncode({'t': 'error', 'room': code, 'code': 'not_leader'}),
    );
    transport.last.emit(roomFrame(role: 'consumer'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveSessionProvider).role, LiveRole.consumer);
  });

  test('handshake falha enquanto pausado: join(code) de novo religa (attempts == 2)', () {
    fakeAsync((async) {
      controller().onAppLifecycle(AppLifecycleState.paused);
      transport.failNext(1);
      controller().join(code);
      async.flushMicrotasks();
      expect(container.read(liveSessionProvider).phase, LivePhase.joining);
      expect(transport.attempts, 1);

      controller().join(code);
      async.flushMicrotasks();
      expect(transport.attempts, 2);
    });
  });
}
