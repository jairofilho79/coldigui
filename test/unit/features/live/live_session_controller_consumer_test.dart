import 'dart:convert';

import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';

String roomFrame({
  String status = 'live',
  int version = 1,
  Object? snapshot = _snap,
  bool leaderPresent = true,
  int viewers = 3,
  String room = code,
  String role = 'consumer',
}) => jsonEncode({
  't': 'room',
  'room': room,
  'status': status,
  'ownerName': 'Fulano',
  'role': role,
  'version': version,
  'snapshot': snapshot,
  'leaderPresent': leaderPresent,
  'viewers': viewers,
});

String snapshotFrame({
  required int version,
  String focus = 'a',
  String room = code,
  List<Map<String, String>>? entries,
}) => jsonEncode({
  't': 'snapshot',
  'room': room,
  'version': version,
  'snapshot': {
    'playlistId': 'p1',
    'name': 'Culto',
    'entries': entries ?? _entries,
    'focusKey': focus,
  },
  'viewers': 3,
});

const _entries = [
  {'id': 'a', 'kind': 'pdf'},
  {'id': 'b', 'kind': 'pdf'},
];
const _snap = {
  'playlistId': 'p1',
  'name': 'Culto',
  'entries': _entries,
  'focusKey': 'a',
};

void main() {
  late ProviderContainer container;
  late FakeLiveTransport transport;
  late List<String> resolvedKeys;
  late List<String> navigated;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    transport = FakeLiveTransport();
    resolvedKeys = [];
    navigated = [];
    container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue(
          (c) => Uri.parse('wss://test/api/live/$c/ws'),
        ),
        liveFocusResolverProvider.overrideWithValue((key) async {
          resolvedKeys.add(key);
          return '/leitor?key=$key';
        }),
        liveNavigatorProvider.overrideWithValue(navigated.add),
      ],
    );
    addTearDown(container.dispose);
  });

  LiveSessionState state() => container.read(liveSessionProvider);
  LiveSessionController controller() =>
      container.read(liveSessionProvider.notifier);

  Future<void> joinAndReceiveRoom() async {
    await controller().join(code);
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'join conecta ao URI da sala, manda hello sem token e entra em joining',
    () async {
      await controller().join(code);
      expect(state().phase, LivePhase.joining);
      expect(transport.last.uri.toString(), 'wss://test/api/live/$code/ws');
      final hello =
          jsonDecode(transport.last.sent.single) as Map<String, Object?>;
      expect(hello['t'], 'hello');
      expect(hello['room'], code);
      expect(hello['since'], 0);
      expect(hello['clientId'], isNotEmpty);
      expect(hello.containsKey('sessionToken'), isFalse);
    },
  );

  test('room live projeta a lista e aplica o foco do gestor', () async {
    await joinAndReceiveRoom();
    expect(state().phase, LivePhase.connected);
    expect(state().roomStatus, LiveRoomStatus.live);
    expect(state().ownerName, 'Fulano');
    expect(state().version, 1);
    expect(state().isFollowing, isTrue);
    expect(container.read(liveProjectionProvider)!.entries.length, 2);
    expect(container.read(activeEntriesProvider).map((e) => e.key), ['a', 'b']);
    expect(resolvedKeys, ['a']);
    expect(navigated, ['/leitor?key=a']);
  });

  test('room idle conecta sem projetar; um room live depois entra', () async {
    await controller().join(code);
    transport.last.emit(
      roomFrame(
        status: 'idle',
        version: 0,
        snapshot: null,
        leaderPresent: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, LivePhase.connected);
    expect(state().isFollowing, isFalse);
    expect(container.read(liveProjectionProvider), isNull);
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    expect(state().isFollowing, isTrue);
  });

  test(
    'snapshot com versão maior atualiza; versão ≤ atual é descartada',
    () async {
      await joinAndReceiveRoom();
      transport.last.emit(snapshotFrame(version: 2, focus: 'b'));
      await Future<void>.delayed(Duration.zero);
      expect(state().version, 2);
      expect(state().snapshot!.focusKey, 'b');
      transport.last.emit(snapshotFrame(version: 2, focus: 'a'));
      transport.last.emit(snapshotFrame(version: 1, focus: 'a'));
      await Future<void>.delayed(Duration.zero);
      expect(state().snapshot!.focusKey, 'b');
    },
  );

  test('frames de outra sala são descartados', () async {
    await joinAndReceiveRoom();
    transport.last.emit(snapshotFrame(version: 9, room: 'zzzzzzz'));
    transport.last.emit(
      jsonEncode({'t': 'ended', 'room': 'zzzzzzz', 'reason': 'leader'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(state().version, 1);
    expect(state().phase, LivePhase.connected);
  });

  test('presence atualiza leaderPresent e viewers', () async {
    await joinAndReceiveRoom();
    transport.last.emit(
      jsonEncode({
        't': 'presence',
        'room': code,
        'leaderPresent': false,
        'viewers': 7,
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(state().leaderPresent, isFalse);
    expect(state().viewers, 7);
  });

  test('ended limpa a projeção, guarda o motivo e mantém o snapshot para «Guardar cópia»', () async {
    await joinAndReceiveRoom();
    transport.last.emit(
      jsonEncode({'t': 'ended', 'room': code, 'reason': 'inactivity'}),
    );
    await transport.last.drop(code: 4001);
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, LivePhase.ended);
    expect(state().endReason, LiveEndReason.inactivity);
    expect(container.read(liveProjectionProvider), isNull);
    expect(state().snapshot, isNotNull);
    expect(transport.attempts, 1); // não religa depois de ended
  });

  test('error not_found → notFound, sem retry', () async {
    await controller().join(code);
    transport.last.emit(
      jsonEncode({'t': 'error', 'room': '', 'code': 'not_found'}),
    );
    await transport.last.drop(code: 4004);
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, LivePhase.notFound);
    expect(transport.attempts, 1);
  });

  test(
    'leave fecha com 1000, limpa a projeção e ignora frames tardios',
    () async {
      // Sem `lingerOnClose`, `emit` depois do `close()` já é um no-op do
      // próprio fake (stream fechado) — o teste não provaria que é o
      // controller quem ignora o frame tardio, e não o fake.
      transport.lingerOnClose = true;
      await joinAndReceiveRoom();
      final conn = transport.last;
      await controller().leave();
      expect(state().phase, LivePhase.left);
      expect(conn.closedWith, 1000);
      expect(container.read(liveProjectionProvider), isNull);
      conn.emit(snapshotFrame(version: 5));
      await Future<void>.delayed(Duration.zero);
      expect(state().version, 1);
      await controller().leave(); // idempotente
      expect(state().phase, LivePhase.left);
    },
  );

  test('join da mesma sala em curso é single-flight; join de outra sala sai da primeira', () async {
    await controller().join(code);
    await controller().join(code);
    expect(transport.attempts, 1);
    final first = transport.last;
    await controller().join('abcdefg');
    expect(first.closedWith, 1000);
    expect(transport.attempts, 2);
    expect(state().code, 'abcdefg');
    expect(state().phase, LivePhase.joining);
  });

  test(
    'join de outra sala durante um handshake em voo não fica preso em joining',
    () async {
      final gate = transport.holdNext();
      final firstJoin = controller().join(code);
      // `connect()` da primeira sala está pendurado no gate — o handshake
      // nunca resolve sozinho.
      await Future<void>.delayed(Duration.zero);
      expect(state().phase, LivePhase.joining);
      expect(state().code, code);
      expect(transport.attempts, 1);
      expect(transport.connections, isEmpty);

      await controller().join('abcdefg');
      expect(transport.attempts, 2);
      expect(state().code, 'abcdefg');
      expect(state().phase, LivePhase.joining);
      expect(transport.connections.length, 1); // só a de 'abcdefg' resolveu

      // Libera o handshake velho: o `_doConnect` original acorda, vê que a
      // geração mudou e fecha a conexão que acabou de abrir, sem religar —
      // sem o fix, `_connecting` continuaria apontando para esse `Future`
      // velho e o `join` de cima teria voltado sem religar nada.
      gate.complete();
      await firstJoin;

      expect(transport.connections.length, 2);
      final stale = transport.connections.last;
      expect(stale.uri.toString(), 'wss://test/api/live/$code/ws');
      expect(stale.closedWith, 1000);
      expect(state().code, 'abcdefg');
      expect(state().phase, LivePhase.joining);
    },
  );

  test('foco: chave do gestor que não existe na lista não navega', () async {
    await controller().join(code);
    transport.last.emit(roomFrame(snapshot: {..._snap, 'focusKey': 'nope'}));
    await Future<void>.delayed(Duration.zero);
    expect(resolvedKeys, isEmpty);
    expect(navigated, isEmpty);
  });

  test('foco: entrada de áudio só foca a chip, sem navegar', () async {
    await controller().join(code);
    transport.last.emit(
      roomFrame(
        snapshot: {
          'playlistId': 'p1',
          'name': 'n',
          'entries': [
            {'id': 'trk', 'kind': 'audio'},
          ],
          'focusKey': 'trk',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(carouselFocusedKeyProvider), 'trk');
    expect(navigated, isEmpty);
  });
}
