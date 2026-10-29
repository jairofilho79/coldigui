import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/presentation/pages/live_room_screen.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';
import '../../../support/test_overrides.dart';

class _StubController extends LiveSessionController {
  _StubController(this._initial);
  final LiveSessionState _initial;
  final List<String> calls = [];
  @override
  LiveSessionState build() => _initial;
  @override
  Future<void> join(String code) async {
    calls.add('join:$code');
  }

  @override
  Future<void> leave() async {
    calls.add('leave');
  }
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_StubController> pump(
    WidgetTester tester,
    LiveSessionState state,
  ) async {
    final stub = _StubController(state);
    await pumpApp(
      tester,
      const LiveRoomScreen(code: 'k7x2m9q'),
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveSessionProvider.overrideWith(() => stub),
      ],
    );
    await tester.pump();
    return stub;
  }

  testWidgets('monta e entra na sala do código', (tester) async {
    final stub = await pump(
      tester,
      const LiveSessionState(phase: LivePhase.joining, code: 'k7x2m9q'),
    );
    expect(stub.calls, ['join:k7x2m9q']);
    expect(find.text('Entrando…'), findsOneWidget);
  });

  testWidgets('idle mostra que o gestor não está ao vivo', (tester) async {
    await pump(
      tester,
      const LiveSessionState(
        phase: LivePhase.connected,
        code: 'k7x2m9q',
        role: LiveRole.consumer,
        roomStatus: LiveRoomStatus.idle,
        ownerName: 'Fulano',
      ),
    );
    expect(find.text('Fulano não está ao vivo agora'), findsOneWidget);
  });

  testWidgets('unavailable oferece tentar de novo', (tester) async {
    final stub = await pump(
      tester,
      const LiveSessionState(phase: LivePhase.unavailable, code: 'k7x2m9q'),
    );
    await tester.tap(find.text('Tentar de novo'));
    expect(stub.calls.last, 'join:k7x2m9q');
  });

  testWidgets('ended com snapshot mostra Guardar cópia', (tester) async {
    await pump(
      tester,
      LiveSessionState(
        phase: LivePhase.ended,
        code: 'k7x2m9q',
        role: LiveRole.consumer,
        ownerName: 'Fulano',
        snapshot: LiveSnapshot(
          playlistId: 'p',
          name: 'Culto',
          entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
          focusKey: null,
        ),
      ),
    );
    expect(find.text('Sessão encerrada'), findsOneWidget);
    expect(find.text('Guardar cópia'), findsOneWidget);
  });

  testWidgets('gestor vê o link, o QR e Gerar novo link', (tester) async {
    await pump(
      tester,
      const LiveSessionState(
        phase: LivePhase.connected,
        code: 'k7x2m9q',
        role: LiveRole.leader,
        roomStatus: LiveRoomStatus.live,
        viewers: 2,
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is SelectableText && w.data!.contains('/ao-vivo/k7x2m9q'),
      ),
      findsOneWidget,
    );
    expect(find.text('Gerar novo link'), findsOneWidget);
    expect(find.text('2 pessoas conectadas'), findsOneWidget);
  });
}
