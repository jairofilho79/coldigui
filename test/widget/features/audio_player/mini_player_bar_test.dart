import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/mini_player_bar.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sessão de mentira: registra chamadas de transporte em vez de tocar nada.
class _RecordingAudioSession extends AudioPlayerSessionNotifier {
  _RecordingAudioSession(this._state);

  final AudioPlayerSessionState _state;
  var playPauseCalls = 0;
  var skipToPreviousCalls = 0;
  var skipToNextCalls = 0;

  @override
  AudioPlayerSessionState build() => _state;

  @override
  Future<void> playPause() async => playPauseCalls++;

  @override
  Future<void> skipToPrevious() async => skipToPreviousCalls++;

  @override
  Future<void> skipToNext() async => skipToNextCalls++;
}

void main() {
  const track = AudioTrack(
    audioId: 'aud-1',
    r2Key: 'assets/praises/p1/a.mp3',
    nome: 'Louvor',
    numero: '12',
    groupId: 'p1',
    categoria: 'Áudio',
    classificacao: 'Coro',
  );

  Widget buildSubject(_RecordingAudioSession session, {bool overlay = false}) {
    return ProviderScope(
      overrides: [audioPlayerSessionProvider.overrideWith(() => session)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(body: MiniPlayerBar(overlay: overlay)),
      ),
    );
  }

  testWidgets('sem faixa não renderiza nada', (tester) async {
    final session = _RecordingAudioSession(const AudioPlayerSessionState());
    await tester.pumpWidget(buildSubject(session));
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayerBar), findsOneWidget);
    expect(tester.getSize(find.byType(MiniPlayerBar)), Size.zero);
  });

  testWidgets(
    'com faixa mostra «numero — nome» e tap no play chama playPause',
    (tester) async {
      final session = _RecordingAudioSession(
        const AudioPlayerSessionState(queue: [track]),
      );
      await tester.pumpWidget(buildSubject(session));
      await tester.pumpAndSettle();

      expect(find.text('12 — Louvor'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(session.playPauseCalls, 1);
    },
  );

  testWidgets('sem faixa anterior/próxima na fila, setas ficam desabilitadas', (
    tester,
  ) async {
    final session = _RecordingAudioSession(
      const AudioPlayerSessionState(queue: [track]),
    );
    await tester.pumpWidget(buildSubject(session));
    await tester.pumpAndSettle();

    final previous = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_previous),
    );
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_next),
    );
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);
  });

  testWidgets('com faixa anterior/próxima na fila, tap chama o notifier', (
    tester,
  ) async {
    const other = AudioTrack(
      audioId: 'aud-2',
      r2Key: 'assets/praises/p2/a.mp3',
      nome: 'Outro',
      numero: '13',
      groupId: 'p2',
      categoria: 'Áudio',
      classificacao: 'Coro',
    );
    final session = _RecordingAudioSession(
      const AudioPlayerSessionState(queue: [track, other], currentIndex: 0),
    );
    await tester.pumpWidget(buildSubject(session));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pumpAndSettle();
    expect(session.skipToNextCalls, 1);
  });

  testWidgets('overlay=true renderiza a mesma barra', (tester) async {
    final session = _RecordingAudioSession(
      const AudioPlayerSessionState(queue: [track]),
    );
    await tester.pumpWidget(buildSubject(session, overlay: true));
    await tester.pumpAndSettle();

    expect(find.text('12 — Louvor'), findsOneWidget);
  });
}
