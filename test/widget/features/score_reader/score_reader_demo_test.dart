import 'dart:async';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_dio_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/score_reader/data/audio/score_audio_engine.dart';
import 'package:coldigui/features/score_reader/data/providers/score_providers.dart';
import 'package:coldigui/features/score_reader/demo/score_reader_demo_fixture.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/presentation/pages/score_reader_screen.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_music_font_provider.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_reader_controller.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_sheet_view.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_system_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:coldigui/main_score_reader_demo.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart' as soundfont;

class _WidgetAudioEngine implements ScoreAudioEngine {
  final loaded = Completer<void>();
  Uint8List? midi;
  Uint8List? soundFont;
  bool disposed = false;

  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<bool> get playingChanges => const Stream.empty();
  @override
  bool get isPlaying => false;
  @override
  Duration get position => Duration.zero;

  @override
  Future<void> load({
    required Uint8List midi,
    required Uint8List soundFont,
  }) async {
    this.midi = midi;
    this.soundFont = soundFont;
    loaded.complete();
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  set speed(double multiplier) {}
  @override
  set transpose(int semitones) {}
  @override
  void setLoop(({Duration start, Duration end})? range) {}
  @override
  void setTrackMuted(int track, bool muted) {}
  @override
  void setTrackSolo(int track, bool solo) {}
  @override
  void setChannelVolume(int channel, double volume) {}
  @override
  Future<void> preview(int pitch, {int program = 0}) async {}
  @override
  Future<void> dispose() async => disposed = true;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ScoreReaderScreen)));

Future<void> _settleReader(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(_container(tester).read(scoreMusicFontProvider).hasValue, isTrue);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() {
    // Cache indisponível: exercita o fallback do repositório real sem I/O nativo.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async {
      throw PlatformException(code: 'cache-unavailable');
    });
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null),
  );
  setUpAll(() async {
    // O carregamento de assets deve começar fora do relógio fake do widget.
    final container = ProviderContainer();
    try {
      await container
          .read(scoreMusicFontProvider.future)
          .timeout(const Duration(seconds: 15));
    } finally {
      container.dispose();
    }
  });

  test('override da demo mantém o motor de áudio real', () async {
    final container = ProviderContainer(
      overrides: [scoreReaderDemoDocumentOverride],
    );
    addTearDown(container.dispose);
    final engine = container.read(scoreAudioEngineFactoryProvider)();
    addTearDown(engine.dispose);

    expect(engine, isA<SoundFontScoreAudioEngine>());
    final document = await container.read(
      scoreDocumentProvider(scoreReaderDemoKey).future,
    );
    expect(document!.measureCount, 4);
    expect(document.lyricCount, 16);
    expect(document.chordSymbolCount, 4);
  });

  test('override da demo não intercepta documentos do catálogo', () async {
    final catalogRead = StateError('provider original do catálogo consultado');
    final container = ProviderContainer(
      overrides: [
        scoreReaderDemoDocumentOverride,
        scoreFileRepositoryProvider.overrideWith((ref) => throw catalogRead),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(scoreDocumentProvider(scoreReaderDemoKey).future),
      isNotNull,
    );
    await expectLater(
      container.read(
        scoreDocumentProvider('assets/praises/p1/catalogo.musicxml').future,
      ),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains(catalogRead.toString()),
          'erro do provider original do catálogo',
        ),
      ),
    );
  });

  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('demo abre partitura real offline em ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      final engine = _WidgetAudioEngine();
      var fileRepositoryReads = 0;
      var requests = 0;
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (_, _) {
            requests++;
            fail('abrir a demo não pode acessar a rede');
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scoreReaderDemoDocumentOverride,
            scoreAudioEngineFactoryProvider.overrideWithValue(() => engine),
            coldigomDioProvider.overrideWithValue(dio),
            scoreFileRepositoryProvider.overrideWith((ref) {
              fileRepositoryReads++;
              throw StateError('a demo não deve consultar catálogo/rede');
            }),
          ],
          child: const ScoreReaderDemoApp(),
        ),
      );
      await _settleReader(tester);
      expect(engine.loaded.isCompleted, isTrue);

      expect(find.byType(ScoreReaderScreen), findsOneWidget);
      expect(find.byType(ScoreSystemView), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final container = _container(tester);
      final document = container
          .read(scoreDocumentProvider(scoreReaderDemoKey))
          .requireValue!;
      final sheet = tester.widget<ScoreSheetView>(find.byType(ScoreSheetView));
      expect(sheet.score, same(document.score));
      final notes = playbackTimeline(
        sheet.score.parts.single,
        expandRepeats: false,
      ).where((note) => !note.isRest).toList();
      expect(notes, hasLength(16));
      expect(
        sheet.score.parts.single.lyrics.map((lyric) => lyric.text),
        containsAll(['Som', 'vem', 'Paz']),
      );
      expect(sheet.score.parts.single.chordSymbols.map((chord) => chord.text), [
        'C',
        'F',
        'G',
        'C',
      ]);
      final primitives = [
        for (final view in tester.widgetList<ScoreSystemView>(
          find.byType(ScoreSystemView),
        ))
          for (final staff in view.system.layout.staves) ...staff.primitives,
      ];
      // Letra e cifra precisam chegar ao layout pintado, não só ao parser.
      final paintedText = primitives.whereType<TextPrimitive>().map(
        (primitive) => primitive.text,
      );
      expect(paintedText, containsAll(['Som', 'Paz', 'C', 'F', 'G']));
      expect(fileRepositoryReads, 0);
      expect(requests, 0);
      expect(
        container.read(readerRouteParamsProvider)['pdfId'],
        encodePdfId(scoreReaderDemoKey),
      );
      expect(
        container.read(scoreReaderControllerProvider(document)).audio,
        ScoreAudioStatus.ready,
      );
      expect(
        container.read(scoreReaderControllerProvider(document)).soundFont,
        ScoreSoundFontStatus.minimal,
      );
      expect(soundfont.MidiReader.fromBytes(engine.midi!).tracks, isNotEmpty);
      final bank = await tester.runAsync(
        () => soundfont.SoundFontFile.fromBytes(engine.soundFont!),
      );
      expect(bank!.presets, isNotEmpty);
      expect(bank.samples, isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(engine.disposed, isTrue);
    });
  }

  testWidgets('documento inválido mostra erro explícito e permite retry', (
    tester,
  ) async {
    var attempts = 0;
    final engine = _WidgetAudioEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scoreAudioEngineFactoryProvider.overrideWithValue(() => engine),
          scoreDocumentProvider(scoreReaderDemoKey).overrideWith((ref) async {
            if (++attempts == 1) {
              return parseScoreDocument(Uint8List(0));
            }
            return loadScoreReaderDemoDocument();
          }),
        ],
        child: const ScoreReaderDemoApp(),
      ),
    );
    await _settleReader(tester);
    final screenContext = tester.element(find.byType(ScoreReaderScreen));
    expect(
      find.text(AppLocalizations.of(screenContext)!.scoreReaderUnavailable),
      findsOneWidget,
    );
    expect(find.byType(ScoreSheetView), findsNothing);
    expect(engine.midi, isNull);

    await tester.tap(find.byKey(scoreReaderRetryKey));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(ScoreSystemView), findsWidgets);
    expect(find.byKey(scoreReaderRetryKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
