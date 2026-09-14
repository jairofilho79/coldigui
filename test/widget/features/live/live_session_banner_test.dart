import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/presentation/providers/live_leader_session_prefs.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:coldigui/features/live/presentation/widgets/live_session_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';
import '../../../support/test_overrides.dart';

/// Controller que só expõe o estado que o teste quer e grava as chamadas.
class _StubController extends LiveSessionController {
  _StubController(this._initial);
  final LiveSessionState _initial;
  final List<String> calls = [];
  @override
  LiveSessionState build() => _initial;
  @override
  Future<void> leave() async {
    calls.add('leave');
  }

  @override
  Future<void> endLive() async {
    calls.add('endLive');
  }

  @override
  void returnToLeader() {
    calls.add('returnToLeader');
  }

  @override
  Future<void> resumeLeader(LiveLeaderSession session) async {
    calls.add('resume:${session.code}');
  }

  @override
  Future<void> discardLeaderSession() async {
    calls.add('discard');
  }
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final snapshot = LiveSnapshot(
    playlistId: 'p',
    name: 'Culto',
    entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
    focusKey: 'a',
  );

  Future<_StubController> pump(
    WidgetTester tester,
    LiveSessionState state,
  ) async {
    final stub = _StubController(state);
    await pumpApp(
      tester,
      const LiveSessionBanner(),
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveSessionProvider.overrideWith(() => stub),
      ],
    );
    return stub;
  }

  testWidgets(
    'consumidor seguindo: nome do gestor, lista, Sair; sem «Voltar» enquanto segue o foco',
    (tester) async {
      await pump(
        tester,
        LiveSessionState(
          phase: LivePhase.connected,
          code: 'c',
          role: LiveRole.consumer,
          roomStatus: LiveRoomStatus.live,
          ownerName: 'Fulano',
          snapshot: snapshot,
          leaderPresent: true,
          viewers: 3,
        ),
      );
      expect(find.text('Seguindo Fulano · Culto'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
      expect(find.text('Voltar ao gestor'), findsNothing);
    },
  );

  testWidgets(
    'desviou: «Voltar ao gestor» chama returnToLeader; gestor ausente aparece',
    (tester) async {
      final stub = await pump(
        tester,
        LiveSessionState(
          phase: LivePhase.connected,
          code: 'c',
          role: LiveRole.consumer,
          roomStatus: LiveRoomStatus.live,
          ownerName: 'Fulano',
          snapshot: snapshot,
          leaderPresent: false,
          followingFocus: false,
        ),
      );
      expect(find.textContaining('gestor ausente'), findsOneWidget);
      await tester.tap(find.text('Voltar ao gestor'));
      expect(stub.calls, ['returnToLeader']);
    },
  );

  testWidgets('reconectando mostra o estado e Sair chama leave', (
    tester,
  ) async {
    final stub = await pump(
      tester,
      const LiveSessionState(
        phase: LivePhase.reconnecting,
        code: 'c',
        role: LiveRole.consumer,
        roomStatus: LiveRoomStatus.live,
      ),
    );
    expect(find.text('Reconectando…'), findsOneWidget);
    await tester.tap(find.text('Sair'));
    expect(stub.calls, ['leave']);
  });

  testWidgets('gestor ao vivo: AO VIVO · N, Sala e Encerrar com confirmação', (
    tester,
  ) async {
    final stub = await pump(
      tester,
      const LiveSessionState(
        phase: LivePhase.connected,
        code: 'c',
        role: LiveRole.leader,
        roomStatus: LiveRoomStatus.live,
        viewers: 23,
      ),
    );
    expect(find.text('AO VIVO · 23'), findsOneWidget);
    await tester.tap(find.text('Encerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar a sessão ao vivo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Encerrar').last);
    await tester.pumpAndSettle();
    expect(stub.calls, ['endLive']);
  });

  testWidgets('sessão pendente do gestor: Retomar / Encerrar', (tester) async {
    await prefs.setString(
      kLiveLeaderSessionPrefsKey,
      '{"code":"k7x2m9q","playlistId":"p1","playlistName":"Culto"}',
    );
    final stub = await pump(tester, const LiveSessionState());
    expect(find.text('Você estava ao vivo com «Culto»'), findsOneWidget);
    await tester.tap(find.text('Retomar'));
    expect(stub.calls, ['resume:k7x2m9q']);
  });

  testWidgets('idle sem nada pendente não renderiza', (tester) async {
    await pump(tester, const LiveSessionState());
    expect(find.byType(LiveSessionBanner), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byIcon(Icons.sensors), findsNothing);
  });
}
