import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_flags/domain/entities/saved_audio_flag.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flag_sync_provider.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flags_for_track_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_position_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_seek_bar.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/mini_player_bar.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Sessão de mentira: registra chamadas de transporte/seek em vez de tocar
/// nada (mesmo padrão do `_FakeAudioSession` de `shell_scaffold_test.dart`).
class _RecordingAudioSession extends AudioPlayerSessionNotifier {
  _RecordingAudioSession(this._state);

  final AudioPlayerSessionState _state;
  var playPauseCalls = 0;
  var skipToPreviousCalls = 0;
  var skipToNextCalls = 0;
  Duration? seeked;

  @override
  AudioPlayerSessionState build() => _state;

  @override
  Future<void> playPause() async => playPauseCalls++;

  @override
  Future<void> skipToPrevious() async => skipToPreviousCalls++;

  @override
  Future<void> skipToNext() async => skipToNextCalls++;

  @override
  Future<void> seek(Duration position) async => seeked = position;
}

/// Posição/duração fixas — sem o `positionStream` de verdade do player.
class _FixedPosition extends AudioPlayerPositionNotifier {
  _FixedPosition(this._state);

  final AudioPlayerPosition _state;

  @override
  AudioPlayerPosition build() => _state;
}

/// Estado de sync fixo, sem `ref.listen` de auth nem rede — a `MiniPlayerBar`
/// só observa para reagir a sync, e o widget test não tem conta/conectividade
/// de verdade (mesmo padrão de `audio_flag_sync_error_row_test.dart`).
class _FixedSyncNotifier extends AudioFlagSyncNotifier {
  @override
  AudioFlagSyncState build() => const AudioFlagSyncState();
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

  /// Sem marcador nenhum por padrão — quem quiser marcadores passa [flags].
  List<Override> flagOverrides({List<SavedAudioFlag> flags = const []}) => [
    audioFlagSyncProvider.overrideWith(_FixedSyncNotifier.new),
    audioFlagsForTrackProvider.overrideWith((ref, audioId) async => flags),
  ];

  Widget buildSubject(
    _RecordingAudioSession session, {
    bool overlay = false,
    List<SavedAudioFlag> flags = const [],
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        audioPlayerSessionProvider.overrideWith(() => session),
        ...flagOverrides(flags: flags),
        ...extraOverrides,
      ],
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

  // Important 3 (fix wave onda 4): o overlay de tela cheia (`shell_scaffold
  // .dart`) empilha a `MiniPlayerBar(overlay: true)` sobre o leitor — uma
  // `MouseRegion` opaca no `_HoverFade` absorvia QUALQUER toque dentro dos
  // seus limites, mesmo em área em branco da faixa, e o leitor por baixo
  // nunca via o toque.
  Widget buildOverlayOverBehind(
    _RecordingAudioSession session, {
    required VoidCallback onBehindTap,
  }) {
    return ProviderScope(
      overrides: [
        audioPlayerSessionProvider.overrideWith(() => session),
        ...flagOverrides(),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBehindTap,
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayerBar(overlay: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'overlay=true: toque numa área em branco da barra atinge o leitor por '
    'baixo',
    (tester) async {
      final session = _RecordingAudioSession(
        const AudioPlayerSessionState(queue: [track]),
      );
      var behindTaps = 0;
      await tester.pumpWidget(
        buildOverlayOverBehind(session, onBehindTap: () => behindTaps++),
      );
      await tester.pumpAndSettle();

      // O título não tem nenhum controle — é a área "em branco" da faixa.
      await tester.tap(find.text('12 — Louvor'));
      await tester.pumpAndSettle();

      expect(behindTaps, 1);
      expect(session.playPauseCalls, 0);
    },
  );

  testWidgets(
    'overlay=true: toque num botão continua exclusivo dele, não passa pro '
    'leitor',
    (tester) async {
      final session = _RecordingAudioSession(
        const AudioPlayerSessionState(queue: [track]),
      );
      var behindTaps = 0;
      await tester.pumpWidget(
        buildOverlayOverBehind(session, onBehindTap: () => behindTaps++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(session.playPauseCalls, 1);
      expect(behindTaps, 0);
    },
  );

  // Task 8: a `LinearProgressIndicator` de 2 px deu lugar ao `AudioSeekBar`
  // compacto (arrastável, com marcadores) entre o título e o transporte.
  testWidgets('mini-player tem seek arrastável e chama seek', (tester) async {
    final session = _RecordingAudioSession(
      const AudioPlayerSessionState(queue: [track]),
    );
    final flag = SavedAudioFlag(
      flagId: 'f1',
      audioId: track.audioId,
      positionMs: const Duration(seconds: 60).inMilliseconds,
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      buildSubject(
        session,
        flags: [flag],
        extraOverrides: [
          audioPlayerPositionProvider.overrideWith(
            () => _FixedPosition(
              const AudioPlayerPosition(
                position: Duration(seconds: 30),
                duration: Duration(minutes: 4),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AudioSeekBar), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('0:30'), findsOneWidget);
    // Marcador salvo em 1:00 desenhado pelo `AudioSeekBar` (flags do track).
    expect(find.byIcon(Icons.flag), findsOneWidget);

    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(session.seeked, isNotNull);
  });

  // Overlay usa `onLightBackground: false` (dourado sobre fundo escuro) mas
  // continua desenhando o mesmo seek bar arrastável e o transporte.
  testWidgets('overlay=true também tem seek arrastável e transporte', (
    tester,
  ) async {
    final session = _RecordingAudioSession(
      const AudioPlayerSessionState(queue: [track]),
    );
    await tester.pumpWidget(
      buildSubject(
        session,
        overlay: true,
        extraOverrides: [
          audioPlayerPositionProvider.overrideWith(
            () => _FixedPosition(
              const AudioPlayerPosition(
                position: Duration(seconds: 30),
                duration: Duration(minutes: 4),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final seekBar = tester.widget<AudioSeekBar>(find.byType(AudioSeekBar));
    expect(seekBar.onLightBackground, isFalse);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
  });

  // Regressão: a barra sem faces (D5, 77ae26a) removeu a `CarouselAudioFaceBar`
  // e, com ela, o único botão que reabria `/audio` a partir da faixa
  // realmente tocando (não do foco do carrossel de PDFs). Sem isso, sair de
  // `/audio` com o áudio ainda tocando não deixa caminho de volta além de
  // iniciar uma faixa nova.
  Widget buildWithRouter(_RecordingAudioSession session, {String? initial}) {
    return ProviderScope(
      overrides: [
        audioPlayerSessionProvider.overrideWith(() => session),
        ...flagOverrides(),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        routerConfig: GoRouter(
          initialLocation: initial ?? '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: Column(children: [MiniPlayerBar(), Text('home')]),
              ),
            ),
            GoRoute(
              path: RoutePaths.audio,
              builder: (_, _) => const Scaffold(
                body: Column(
                  children: [MiniPlayerBar(), Text('tela de áudio')],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets(
    'com faixa tocando fora de /audio, botão «abrir» leva à tela de áudio',
    (tester) async {
      final session = _RecordingAudioSession(
        const AudioPlayerSessionState(queue: [track]),
      );
      await tester.pumpWidget(buildWithRouter(session));
      await tester.pumpAndSettle();

      expect(find.text('tela de áudio'), findsNothing);

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      expect(find.text('tela de áudio'), findsOneWidget);
    },
  );

  testWidgets('já em /audio, botão «abrir» fica desabilitado (no-op)', (
    tester,
  ) async {
    final session = _RecordingAudioSession(
      const AudioPlayerSessionState(queue: [track]),
    );
    await tester.pumpWidget(
      buildWithRouter(session, initial: RoutePaths.audio),
    );
    await tester.pumpAndSettle();

    final open = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.open_in_full),
    );
    expect(open.onPressed, isNull);
  });
}
