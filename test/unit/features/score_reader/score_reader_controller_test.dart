import 'dart:async';
import 'dart:io';

import 'package:coldigui/features/score_reader/data/audio/score_audio_engine.dart';
import 'package:coldigui/features/score_reader/data/providers/score_providers.dart';
import 'package:coldigui/features/score_reader/data/repositories/score_sound_font_repository.dart';
import 'package:coldigui/features/score_reader/domain/entities/musescore_performance_metadata.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_playback_diagnostic.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_reader_controller.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngine implements ScoreAudioEngine {
  final positionsCtl = StreamController<Duration>.broadcast();
  final playingCtl = StreamController<bool>.broadcast();
  final loads = <Uint8List>[];
  final midiLoads = <Uint8List>[];
  Object? loadError;
  Completer<void>? loadGate;
  Object? pauseError;
  Object? disposeError;
  int loadStarts = 0;
  int loadsFinishedAfterDispose = 0;
  int disposeCalls = 0;
  bool hasResources = false;
  final previews = <(int, int)>[];
  final mutedTracks = <int>{};
  final soloTracks = <int>{};
  final volumes = <int, double>{};
  ({Duration start, Duration end})? loop;
  double currentSpeed = 1;
  int currentTranspose = 0;
  bool playing = false;
  Duration pos = Duration.zero;
  bool disposed = false;

  @override
  Stream<Duration> get positions => positionsCtl.stream;
  @override
  Stream<bool> get playingChanges => playingCtl.stream;
  @override
  bool get isPlaying => playing;
  @override
  Duration get position => pos;

  @override
  Future<void> load({
    required Uint8List midi,
    required Uint8List soundFont,
  }) async {
    loadStarts++;
    final resumePlaying = playing;
    await loadGate?.future;
    if (loadError != null) throw loadError!;
    if (disposed) loadsFinishedAfterDispose++;
    hasResources = true;
    playing = resumePlaying;
    loads.add(soundFont);
    midiLoads.add(midi);
  }

  @override
  Future<void> play() async {
    playing = true;
    playingCtl.add(true);
  }

  @override
  Future<void> pause() async {
    if (pauseError != null) throw pauseError!;
    playing = false;
    playingCtl.add(false);
  }

  @override
  Future<void> seek(Duration position) async => pos = position;
  @override
  set speed(double multiplier) => currentSpeed = multiplier;
  @override
  set transpose(int semitones) => currentTranspose = semitones;
  @override
  void setLoop(({Duration start, Duration end})? range) => loop = range;
  @override
  void setTrackMuted(int track, bool muted) =>
      muted ? mutedTracks.add(track) : mutedTracks.remove(track);
  @override
  void setTrackSolo(int track, bool solo) =>
      solo ? soloTracks.add(track) : soloTracks.remove(track);
  @override
  void setChannelVolume(int channel, double volume) =>
      volumes[channel] = volume;
  @override
  Future<void> preview(int pitch, {int program = 0}) async =>
      previews.add((pitch, program));
  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (disposeError != null) throw disposeError!;
    disposed = true;
    hasResources = false;
    playing = false;
  }
}

class _FakeSounds implements ScoreSoundFontRepository {
  _FakeSounds({this.fail = false});

  Uint8List? cached;
  final bool fail;
  final full = Uint8List.fromList([9, 9, 9]);
  int downloads = 0;
  Completer<void>? gate;

  @override
  Uint8List get fallback => Uint8List.fromList([1]);

  @override
  Future<Uint8List?> readCached() async => cached;

  @override
  Future<Uint8List> download({
    void Function(double progress)? onProgress,
  }) async {
    downloads++;
    onProgress?.call(0.5);
    await gate?.future;
    if (fail) throw StateError('offline');
    onProgress?.call(1);
    return full;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ScoreDocument _doc() =>
    parseScoreDocument(File('test/fixtures/scores/499.mscz').readAsBytesSync());

ScoreDocument _withStaffCount(ScoreDocument source, int count) {
  final part = source.score.parts.firstWhere(
    (part) => part.chordSymbols.isNotEmpty,
  );
  return ScoreDocument(
    score: MultiPartScore([
      for (var index = 0; index < count; index++) part.copyWith(),
    ]),
    staves: [
      for (var index = 0; index < count; index++)
        ScoreStaff(index: index, partName: 'Staff $index'),
    ],
    format: source.format,
  );
}

ScoreDocument _twoChordSources() {
  final source = parseScoreDocument(
    File('test/fixtures/scores/chord_playback.musicxml').readAsBytesSync(),
  );
  final part = source.score.parts.single;
  final anchor = part.measures.single.elements.single.id!;
  final cMajor = ChordSymbol(
    anchor,
    const Pitch(Step.c),
    ChordSymbolKind.major,
  );
  final aMinor = ChordSymbol(
    anchor,
    const Pitch(Step.a),
    ChordSymbolKind.minor,
  );
  return ScoreDocument(
    score: MultiPartScore([
      part.copyWith(chordSymbols: [cMajor]),
      part.copyWith(chordSymbols: [aMinor]),
    ]),
    staves: const [
      ScoreStaff(index: 0, partName: 'C chords'),
      ScoreStaff(index: 1, partName: 'A chords'),
    ],
    format: source.format,
  );
}

int _trackCount(Uint8List midi) => (midi[10] << 8) | midi[11];

void main() {
  late ScoreDocument doc;
  setUpAll(() => doc = _doc());

  late _FakeEngine engine;
  late _FakeSounds sounds;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      scoreAudioEngineFactoryProvider.overrideWithValue(() => engine),
      scoreSoundFontRepositoryProvider.overrideWithValue(sounds),
    ],
  );

  Future<ScoreReaderController> open([ScoreDocument? document]) async {
    container = makeContainer();
    final provider = scoreReaderControllerProvider(document ?? doc);
    container.listen(provider, (_, _) {});
    final controller = container.read(provider.notifier);
    await pumpEventQueue();
    return controller;
  }

  ScoreReaderState read([ScoreDocument? document]) =>
      container.read(scoreReaderControllerProvider(document ?? doc));

  setUp(() {
    engine = _FakeEngine();
    sounds = _FakeSounds();
  });
  tearDown(() => container.dispose());

  test('starts with the minimal sound font when nothing is cached', () async {
    await open();
    expect(read().audio, ScoreAudioStatus.ready);
    expect(read().soundFont, ScoreSoundFontStatus.minimal);
    expect(engine.loads.single, sounds.fallback);
    expect(read().mix, hasLength(doc.staves.length));
  });

  test('uses the cached full sound font offline', () async {
    sounds.cached = Uint8List.fromList([7]);
    await open();
    expect(read().soundFont, ScoreSoundFontStatus.full);
    expect(engine.loads.single, [7]);
  });

  test('reports invalid navigation and its source location', () async {
    final parsed = parseScoreDocument(
      File('test/fixtures/scores/musicxml_dynamics.musicxml').readAsBytesSync(),
    );
    final document = ScoreDocument(
      score: parsed.score,
      staves: parsed.staves,
      format: parsed.format,
      musicXmlPerformance: const MusicXmlPerformanceMetadata(
        sounds: [
          MusicXmlSoundMetadata(
            origin: MusicXmlPerformanceOrigin(
              partIndex: 0,
              measureIndex: 0,
              staffIndex: 0,
            ),
            dalSegno: 'Missing',
          ),
        ],
      ),
    );

    await open(document);

    expect(read(document).audio, ScoreAudioStatus.failed);
    expect(
      read(document).diagnostics
          .map(
            (diagnostic) => (
              diagnostic.code,
              diagnostic.staffIndex,
              diagnostic.measureIndex,
            ),
          )
          .toList(),
      [(ScorePlaybackDiagnosticCode.unresolvedNavigation, 0, 0)],
    );
    expect(engine.midiLoads, isEmpty);
  });

  test(
    'blocks playback when repeat expansion exceeds the occurrence limit',
    () async {
      final document = ScoreDocument(
        score: MultiPartScore([
          Score(
            clef: Clef.treble,
            timeSignature: const TimeSignature(4, 4),
            measures: [
              Measure([
                NoteElement.note(
                  const Pitch(Step.c, octave: 4),
                  NoteDuration.whole,
                  id: 'repeat-start',
                ),
              ], startRepeat: true),
              Measure([
                NoteElement.note(
                  const Pitch(Step.d, octave: 4),
                  NoteDuration.whole,
                  id: 'repeat-end',
                ),
              ], endRepeat: true),
            ],
          ),
        ]),
        staves: const [ScoreStaff(index: 0, partName: 'Test')],
        format: ScoreSourceFormat.musicXml,
        musicXmlPerformance: const MusicXmlPerformanceMetadata(
          repeats: [
            MusicXmlRepeatMetadata(
              origin: MusicXmlPerformanceOrigin(partIndex: 0, measureIndex: 1),
              direction: 'backward',
              rawTimes: '5001',
              times: 5001,
            ),
          ],
        ),
      );

      await open(document);

      final diagnostic = read(document).diagnostics.single;
      expect(
        diagnostic.code,
        ScorePlaybackDiagnosticCode.measureOccurrenceLimitExceeded,
      );
      expect(diagnostic.blocksPlayback, isTrue);
      expect(engine.midiLoads, isEmpty);
    },
  );

  test('reports audio engine load failures as playback diagnostics', () async {
    engine.loadError = StateError('audio load failed');

    await open();

    expect(read().audio, ScoreAudioStatus.failed);
    expect(
      read().diagnostics,
      contains(
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.audioUnavailable,
            )
            .having(
              (diagnostic) => diagnostic.blocksPlayback,
              'blocksPlayback',
              true,
            ),
      ),
    );
  });

  test(
    'staff programs default to the document and drive MIDI and preview',
    () async {
      final controller = await open();
      expect(
        read().mix.map((mix) => mix.program),
        doc.staves.map((staff) => staff.midiProgram ?? 0),
      );
      await controller.setStaffProgram(1, 127);
      expect(read().mix[1].program, 127);
      expect(read().mix.first.program, doc.staves.first.midiProgram ?? 0);
      expect(
        engine.midiLoads.last,
        buildScoreMidi(
          doc,
          programOverrides: {1: 127},
          includeChordAccompaniment: true,
        ),
      );
      final note = controller.playbackMap.timelines[1].firstWhere(
        (note) => !note.isRest && note.chordPitches == null,
      );
      await controller.onElementTap(note.elementId);
      expect(engine.previews.last.$2, 127);
      expect(read().mix[1].program, 127);
      expect(read().mix[1].programChanging, isFalse);
      expect(read().mix[1].programFailed, isFalse);
      await controller.setStaffProgram(1, doc.staves[1].midiProgram ?? 0);
      expect(engine.midiLoads.last, engine.midiLoads.first);
    },
  );

  test(
    'instrument reload preserves cursor, playing, mix and playback settings',
    () async {
      sounds.cached = sounds.full;
      final controller = await open();
      await controller.seekToMeasure(2);
      controller
        ..setStaffVolume(0, .35)
        ..toggleStaffMute(0)
        ..toggleStaffSolo(1)
        ..setSpeed(.8)
        ..setTranspose(3)
        ..setLoop(1, 3);
      await controller.togglePlay();
      await pumpEventQueue();
      final before = read();
      final loop = engine.loop;
      final position = engine.pos;
      await controller.setStaffProgram(1, 42);
      expect(read().position, before.position);
      expect(read().activeMeasure, before.activeMeasure);
      expect(read().playing, isTrue);
      expect(read().speed, .8);
      expect(read().transpose, 3);
      expect(read().mix[0].volume, .35);
      expect(read().mix[0].muted, isTrue);
      expect(read().mix[1].solo, isTrue);
      expect(engine.pos, position);
      expect(engine.playing, isTrue);
      expect(engine.currentSpeed, .8);
      expect(engine.currentTranspose, 3);
      expect(engine.mutedTracks, {0});
      expect(engine.soloTracks, {1});
      expect(engine.volumes[0], .35);
      expect(engine.loop, loop);
    },
  );

  test('program survives seeking and a full SoundFont reload', () async {
    final controller = await open();
    await controller.setStaffProgram(1, 48);
    await controller.seekToMeasure(3);
    await controller.downloadFullSoundFont();
    expect(read().soundFont, ScoreSoundFontStatus.full);
    expect(read().mix[1].program, 48);
    expect(engine.loads.last, sounds.full);
    expect(
      engine.midiLoads.last,
      buildScoreMidi(
        doc,
        programOverrides: {1: 48},
        includeChordAccompaniment: true,
      ),
    );
    final note = controller.playbackMap.timelines[1].firstWhere(
      (note) => !note.isRest && note.chordPitches == null,
    );
    await controller.onElementTap(note.elementId);
    expect(engine.previews.last.$2, 48);
  });

  test(
    'seek and MIDI reload retain CC11 and independent mixer volume',
    () async {
      final document = parseScoreDocument(
        File('test/fixtures/scores/musicxml_dynamics.musicxml')
            .readAsBytesSync(),
      );
      final controller = await open(document);
      final plan = controller.playbackMap.performancePlan;
      expect(plan.expressionCurves, isNotEmpty);
      controller.setStaffVolume(0, .35);

      await controller.seekToMeasure(1);
      expect(
        engine.midiLoads.last,
        buildScoreMidi(document, performancePlan: plan),
      );
      expect(engine.volumes[0], .35);

      await controller.setStaffProgram(0, 42);
      expect(
        engine.midiLoads.last,
        buildScoreMidi(
          document,
          programOverrides: {0: 42},
          performancePlan: plan,
        ),
      );
      expect(engine.volumes[0], .35);
    },
  );

  test(
    'invalid program or staff leaves the selection and MIDI unchanged',
    () async {
      final controller = await open();
      for (final (staff, program) in [
        (-1, 0),
        (doc.staves.length, 0),
        (0, -1),
        (0, 128),
      ]) {
        await expectLater(
          controller.setStaffProgram(staff, program),
          throwsRangeError,
        );
      }
      expect(engine.midiLoads, hasLength(1));
      expect(read().mix[0].program, doc.staves[0].midiProgram ?? 0);
    },
  );

  test(
    'failed program load keeps the previous selection and can be retried',
    () async {
      final controller = await open();
      final original = read().mix[1].program;
      final program = original == 40 ? 41 : 40;
      engine.loadError = StateError('instrument load failed');
      await controller.setStaffProgram(1, program);
      expect(read().mix[1].program, original);
      expect(read().mix[1].programChanging, isFalse);
      expect(read().mix[1].programFailed, isTrue);
      expect(read().audio, ScoreAudioStatus.ready);
      expect(
        read().diagnostics,
        contains(
          isA<ScorePlaybackDiagnostic>()
              .having(
                (diagnostic) => diagnostic.code,
                'code',
                ScorePlaybackDiagnosticCode.staffInstrumentUnavailable,
              )
              .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 1),
        ),
      );
      engine.loadError = null;
      await controller.setStaffProgram(1, program);
      expect(read().mix[1].program, program);
      expect(read().mix[1].programFailed, isFalse);
    },
  );

  test(
    'program changes and SoundFont loads are serialized without stale MIDI',
    () async {
      final controller = await open();
      final gate = engine.loadGate = Completer<void>();
      final first = controller.setStaffProgram(0, 12);
      await pumpEventQueue();
      expect(read().mix.first.programChanging, isTrue);
      final fullFont = controller.downloadFullSoundFont();
      await pumpEventQueue();
      final second = controller.setStaffProgram(1, 64);
      gate.complete();
      engine.loadGate = null;
      await Future.wait([first, fullFont, second]);
      expect(read().mix[0].program, 12);
      expect(read().mix[1].program, 64);
      expect(read().soundFont, ScoreSoundFontStatus.full);
      expect(engine.loads.last, sounds.full);
      expect(
        engine.midiLoads.last,
        buildScoreMidi(
          doc,
          programOverrides: {0: 12, 1: 64},
          includeChordAccompaniment: true,
        ),
      );
    },
  );

  test('first play starts the full sound font download and swaps it', () async {
    final controller = await open();
    await controller.togglePlay();
    await pumpEventQueue();
    expect(engine.playing, isTrue);
    expect(read().playing, isTrue);
    expect(sounds.downloads, 1);
    expect(read().soundFont, ScoreSoundFontStatus.full);
    expect(engine.loads.last, sounds.full);

    await controller.togglePlay();
    await pumpEventQueue();
    expect(read().playing, isFalse);
    await controller.togglePlay();
    expect(sounds.downloads, 1, reason: 'only one download');
  });

  test('failed download keeps playing with the minimal sound', () async {
    sounds = _FakeSounds(fail: true);
    final controller = await open();
    await controller.togglePlay();
    await pumpEventQueue();
    expect(read().soundFont, ScoreSoundFontStatus.failed);
    expect(engine.playing, isTrue);
    expect(engine.loads, hasLength(1));
    expect(
      read().diagnostics,
      contains(
        isA<ScorePlaybackDiagnostic>().having(
          (diagnostic) => diagnostic.code,
          'code',
          ScorePlaybackDiagnosticCode.soundFontUnavailable,
        ),
      ),
    );
  });

  test('positions drive highlight and active measure', () async {
    final controller = await open();
    final map = controller.playbackMap;
    final at = map.startOfMeasure(2)! + const Duration(milliseconds: 10);
    engine.positionsCtl.add(at);
    await pumpEventQueue();
    expect(read().activeMeasure, 2);
    expect(read().activeIds, map.soundingAt(at));
    expect(read().activeIds, isNotEmpty);
  });

  test(
    'fermata timing drives seek and A-B loop before, during and after',
    () async {
      final document = ScoreDocument(
        score: MultiPartScore([
          Score(
            clef: Clef.treble,
            timeSignature: const TimeSignature(4, 4),
            measures: [
              Measure([
                NoteElement.note(
                  Pitch(Step.c),
                  NoteDuration.quarter,
                  id: 'before-fermata',
                ),
                NoteElement.note(
                  Pitch(Step.d),
                  NoteDuration.quarter,
                  articulations: const {Articulation.fermata},
                  id: 'held-fermata',
                ),
                NoteElement.note(
                  Pitch(Step.e),
                  NoteDuration.quarter,
                  id: 'after-fermata',
                ),
                NoteElement.note(
                  Pitch(Step.f),
                  NoteDuration.quarter,
                  id: 'measure-one-last',
                ),
              ]),
              Measure([
                for (final (index, step) in [
                  Step.c,
                  Step.d,
                  Step.e,
                  Step.f,
                ].indexed)
                  NoteElement.note(
                    Pitch(step),
                    NoteDuration.quarter,
                    id: 'measure-two-$index',
                  ),
              ]),
            ],
          ),
        ]),
        staves: const [ScoreStaff(index: 0, partName: 'Fermata')],
        format: ScoreSourceFormat.musicXml,
      );
      final controller = await open(document);
      final map = controller.playbackMap;

      expect(map.duration, const Duration(milliseconds: 4500));
      expect(map.startOfElement('before-fermata'), Duration.zero);
      expect(
        map.soundingAt(const Duration(milliseconds: 250)),
        contains('before-fermata'),
      );
      for (final (position, id) in [
        (const Duration(milliseconds: 250), 'before-fermata'),
        (const Duration(milliseconds: 750), 'held-fermata'),
        (const Duration(milliseconds: 1750), 'after-fermata'),
      ]) {
        await controller.seek(position);
        expect(engine.pos, position);
        expect(read(document).activeIds, contains(id));
        expect(read(document).activeIds, map.soundingAt(position));
        expect(read(document).activeMeasure, 0);
      }

      await controller.seekToMeasure(1);
      expect(read(document).position, const Duration(milliseconds: 2500));
      controller.setLoop(0, 1);
      expect(engine.loop, (
        start: Duration.zero,
        end: const Duration(milliseconds: 4500),
      ));
      controller.setLoop(1, 1);
      expect(engine.loop, (
        start: const Duration(milliseconds: 2500),
        end: const Duration(milliseconds: 4500),
      ));
    },
  );

  test(
    'navigation plan drives cursor, seeking and A-B loop boundaries',
    () async {
      final controller = await open();
      final map = controller.playbackMap;
      final expected = [
        ...List.generate(73, (index) => index),
        ...List.generate(13, (index) => index + 29),
        ...List.generate(14, (index) => index + 73),
      ];

      expect(
        map.performancePlan.measureOccurrences.map(
          (occurrence) => occurrence.measureIndex,
        ),
        expected,
      );
      expect(read().duration, map.duration);

      final returnedSegno = map.performancePlan.measureOccurrences[73];
      final atReturnedSegno =
          map.durationAt(returnedSegno.start) +
          const Duration(milliseconds: 10);
      engine.positionsCtl.add(atReturnedSegno);
      await pumpEventQueue();
      expect(read().activeMeasure, 29);
      expect(read().activeIds, map.soundingAt(atReturnedSegno));

      await controller.seekToMeasure(72);
      expect(read().position, map.startOfMeasure(72));
      controller.setLoop(29, 42);
      expect(engine.loop, (
        start: map.startOfMeasure(29)!,
        end: map.endOfMeasure(42)!,
      ));
    },
  );

  test('tapping a note previews its pitch and moves the cursor', () async {
    final controller = await open();
    final note = controller.playbackMap.timelines.first.firstWhere(
      (n) => !n.isRest && n.chordPitches == null,
    );
    await controller.onElementTap(note.elementId);
    expect(engine.previews, isNotEmpty);
    expect(engine.pos, controller.playbackMap.startOfElement(note.elementId));
    expect(read().activeIds, {note.elementId});
    expect(read().activeMeasure, note.measureIndex);
  });

  test('loop A-B cycles and maps to measure boundaries', () async {
    final controller = await open();
    final map = controller.playbackMap;
    await controller.seekToMeasure(3);
    controller.cycleLoop();
    expect(read().loopStart, 3);
    expect(engine.loop, isNull);

    await controller.seekToMeasure(1);
    controller.cycleLoop();
    expect((read().loopStart, read().loopEnd), (1, 3));
    expect(engine.loop, (
      start: map.startOfMeasure(1)!,
      end: map.endOfMeasure(3)!,
    ));

    // Play fora do trecho volta para A.
    await controller.seek(map.startOfMeasure(6)!);
    await controller.togglePlay();
    expect(engine.pos, map.startOfMeasure(1));

    controller.cycleLoop();
    expect(read().isLoopActive, isFalse);
    expect(engine.loop, isNull);
  });

  test('transpose re-renders and transposes audio, clamped to ±12', () async {
    final controller = await open();
    controller.setTranspose(2);
    expect(read().transpose, 2);
    expect(engine.currentTranspose, 2);
    expect(identical(read().displayed, doc.score), isFalse);
    controller.setTranspose(40);
    expect(read().transpose, 12);
    controller.setTranspose(0);
    expect(identical(read().displayed, doc.score), isTrue);
  });

  test('speed is clamped and reflected in bpm', () async {
    final controller = await open();
    controller.setSpeed(5);
    expect(read().speed, kScoreMaxSpeed);
    expect(engine.currentSpeed, kScoreMaxSpeed);
    controller.setSpeed(0.5);
    expect(read().bpm, closeTo(doc.quarterBpm / 2, 0.01));
  });

  test('mixer mute, solo and volume reach the engine', () async {
    final controller = await open();
    controller
      ..toggleStaffMute(1)
      ..toggleStaffSolo(0)
      ..setStaffVolume(1, 0.3);
    expect(read().mix[1].muted, isTrue);
    expect(read().mix[0].solo, isTrue);
    expect(read().mix[1].volume, 0.3);
    expect(engine.mutedTracks, {1});
    expect(engine.soloTracks, {0});
    expect(engine.volumes.values, [0.3]);
  });

  for (final (staffCount, chordTrackExpected) in [
    (2, true),
    (14, true),
    (15, false),
  ]) {
    test(
      '$staffCount staves route without exceeding melodic channel capacity',
      () async {
        final document = _withStaffCount(doc, staffCount);
        final controller = await open(document);
        final state = read(document);
        final plan = controller.playbackMap.performancePlan;

        expect(
          state.selectedStaffIndices,
          Set<int>.from(List.generate(staffCount, (index) => index)),
        );
        expect(state.chordAccompanimentEnabled, chordTrackExpected);
        expect(state.audio, ScoreAudioStatus.ready);
        expect(
          plan.routes.where(
            (route) => route.kind == ScorePerformanceRouteKind.staff,
          ),
          hasLength(staffCount),
        );
        expect(plan.chordRoute != null, chordTrackExpected);
        expect(
          plan.routes.map((route) => route.midiChannel).toSet(),
          hasLength(plan.routes.length),
        );
        expect(
          _trackCount(engine.midiLoads.last),
          staffCount + (chordTrackExpected ? 1 : 0),
        );
      },
    );
  }

  test('16 staves require explicit routing before playback', () async {
    final document = _withStaffCount(doc, 16);
    final controller = await open(document);
    expect(read(document).audio, ScoreAudioStatus.selectionRequired);
    expect(
      read(document).selectedStaffIndices,
      Set<int>.from(List.generate(16, (index) => index)),
    );
    expect(engine.midiLoads, isEmpty);

    await controller.setStaffSelected(0, false);
    expect(
      read(document).selectedStaffIndices,
      Set<int>.from(List.generate(15, (index) => index + 1)),
    );
    expect(read(document).audio, ScoreAudioStatus.ready);
    expect(_trackCount(engine.midiLoads.last), 15);

    await controller.setChordAccompanimentEnabled(true);
    expect(read(document).audio, ScoreAudioStatus.selectionRequired);
    expect(read(document).selectedStaffIndices, hasLength(15));
    await controller.setStaffSelected(1, false);
    expect(read(document).audio, ScoreAudioStatus.ready);
    expect(
      read(document).selectedStaffIndices,
      Set<int>.from(List.generate(14, (index) => index + 2)),
    );
    expect(_trackCount(engine.midiLoads.last), 15);
    expect(
      controller.playbackMap.performancePlan.routes
          .map((route) => route.midiChannel)
          .toSet(),
      hasLength(15),
    );

    controller
      ..setStaffVolume(2, .42)
      ..toggleStaffMute(3)
      ..setChordVolume(.33)
      ..toggleChordSolo()
      ..setSpeed(.8)
      ..setTranspose(-2)
      ..setLoop(0, 0);
    await controller.setChordSource(3);
    await controller.setStaffProgram(4, 51);
    await controller.setChordProgram(65);
    await controller.seekToMeasure(0);
    await controller.downloadFullSoundFont();

    final state = read(document);
    final selected = Set<int>.from(List.generate(14, (index) => index + 2));
    expect(state.selectedStaffIndices, selected);
    expect(state.chordSourceStaffIndex, 3);
    expect(state.chordMix.program, 65);
    expect(state.chordMix.volume, .33);
    expect(state.chordMix.solo, isTrue);
    expect(state.mix[3].muted, isTrue);
    expect(state.mix[4].program, 51);
    expect(state.transpose, -2);
    expect(state.speed, .8);
    expect(state.isLoopActive, isTrue);
    expect(state.soundFont, ScoreSoundFontStatus.full);
    expect(engine.mutedTracks, contains(1));
    expect(engine.soloTracks, contains(14));
    expect(engine.volumes[0], .42);
    expect(engine.volumes[15], .33);
    expect(
      engine.midiLoads.last,
      buildScoreMidi(
        document,
        programOverrides: {4: 51},
        performancePlan: controller.playbackMap.performancePlan,
        includeChordAccompaniment: true,
        chordSourceStaffIndex: 3,
        chordProgram: 65,
      ),
    );
  });

  test(
    'staff and chord controls stay independent and source changes MIDI',
    () async {
      final document = _twoChordSources();
      final controller = await open(document);
      final initialMidi = engine.midiLoads.last;

      controller
        ..setStaffVolume(0, .35)
        ..toggleStaffMute(0)
        ..toggleStaffSolo(1)
        ..setChordVolume(.6)
        ..toggleChordMute()
        ..toggleChordSolo();
      await controller.setChordSource(1);
      final selectedSourceMidi = engine.midiLoads.last;
      expect(selectedSourceMidi, isNot(equals(initialMidi)));
      await controller.setChordProgram(48);

      final state = read(document);
      expect(state.mix[0].volume, .35);
      expect(state.mix[0].muted, isTrue);
      expect(state.mix[1].solo, isTrue);
      expect(state.chordMix.volume, .6);
      expect(state.chordMix.muted, isTrue);
      expect(state.chordMix.solo, isTrue);
      expect(state.chordSourceStaffIndex, 1);
      expect(state.chordMix.program, 48);
      expect(engine.volumes[0], .35);
      expect(engine.volumes[15], .6);
      expect(engine.mutedTracks, containsAll([0, 2]));
      expect(engine.soloTracks, containsAll([1, 2]));
      expect(engine.midiLoads.last, isNot(equals(selectedSourceMidi)));
      expect(_trackCount(engine.midiLoads.last), 3);
    },
  );

  test(
    'chord settings survive GM, SoundFont, seek, loop and transpose',
    () async {
      final document = _twoChordSources();
      final controller = await open(document);
      controller
        ..setStaffVolume(1, .4)
        ..toggleStaffMute(1)
        ..setChordVolume(.3)
        ..toggleChordSolo()
        ..setSpeed(.75)
        ..setTranspose(3)
        ..setLoop(0, 0);
      await controller.setChordSource(1);
      await controller.setStaffProgram(0, 42);
      await controller.setChordProgram(46);
      await controller.seekToMeasure(0);
      await controller.downloadFullSoundFont();
      await controller.togglePlay();

      final state = read(document);
      final expectedPlan = ScorePerformancePlan.fromDocument(
        document,
        includeChordSymbols: true,
        selectedStaffIndices: state.selectedStaffIndices,
      );
      expect(
        engine.midiLoads.last,
        buildScoreMidi(
          document,
          programOverrides: {0: 42},
          performancePlan: expectedPlan,
          includeChordAccompaniment: true,
          chordSourceStaffIndex: 1,
          chordProgram: 46,
        ),
      );
      expect(state.mix[1].volume, .4);
      expect(state.mix[1].muted, isTrue);
      expect(state.chordMix.volume, .3);
      expect(state.chordMix.solo, isTrue);
      expect(state.chordSourceStaffIndex, 1);
      expect(state.chordMix.program, 46);
      expect(state.transpose, 3);
      expect(state.speed, .75);
      expect(state.position, Duration.zero);
      expect(state.isLoopActive, isTrue);
      expect(state.playing, isTrue);
      expect(engine.currentTranspose, 3);
      expect(engine.currentSpeed, .75);
      expect(engine.loop, isNotNull);
      expect(engine.soloTracks, contains(2));
      expect(engine.mutedTracks, contains(1));
      expect(engine.volumes[15], .3);
      expect(state.soundFont, ScoreSoundFontStatus.full);
    },
  );

  test('disposing the reader disposes the engine', () async {
    await open();
    container.dispose();
    await pumpEventQueue();
    expect(engine.disposed, isTrue);
    container = makeContainer();
  });

  for (final reload in ['GM', 'SoundFont']) {
    test(
      'dispose waits for $reload load and skips queued program changes',
      () async {
        final controller = await open();
        await engine.play();
        await pumpEventQueue();
        final gate = engine.loadGate = Completer<void>();
        final work = reload == 'GM'
            ? controller.setStaffProgram(0, 42)
            : controller.downloadFullSoundFont();
        await pumpEventQueue();
        expect(engine.loadStarts, 2);
        final queued = controller.setStaffProgram(1, 64);
        await pumpEventQueue();
        expect(engine.loadStarts, 2);

        container.dispose();
        final stoppedImmediately = !engine.playing;
        await pumpEventQueue();
        final disposedBeforeDrain = engine.disposed;
        gate.complete();
        await Future.wait([work, queued]);
        await pumpEventQueue();

        expect(
          engine.loadsFinishedAfterDispose,
          0,
          reason: 'load must never recreate resources after final teardown',
        );
        expect(disposedBeforeDrain, isFalse);
        expect(stoppedImmediately, isTrue);
        expect(engine.loadStarts, 2, reason: 'queued work must not start');
        expect(engine.disposed, isTrue);
        expect(engine.disposeCalls, 1);
        expect(engine.hasResources, isFalse);
        expect(engine.playing, isFalse);
        container = makeContainer();
      },
    );
  }

  test('dispose also drains the initial audio load', () async {
    final gate = engine.loadGate = Completer<void>();
    await open();
    expect(engine.loadStarts, 1);
    container.dispose();
    await pumpEventQueue();
    final disposedBeforeDrain = engine.disposed;
    gate.complete();
    await pumpEventQueue();
    expect(engine.loadsFinishedAfterDispose, 0);
    expect(disposedBeforeDrain, isFalse);
    expect(engine.disposed, isTrue);
    expect(engine.hasResources, isFalse);
    container = makeContainer();
  });

  test(
    'dispose logs pause and teardown failures without losing cleanup',
    () async {
      await open();
      final logs = <String>[];
      final previousPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = previousPrint);
      engine.pauseError = StateError('pause cleanup failed');
      engine.disposeError = StateError('teardown cleanup failed');
      container.dispose();
      await pumpEventQueue();
      expect(
        engine.disposeCalls,
        1,
        reason: 'pause failure cannot skip teardown',
      );
      expect(logs.any((line) => line.contains('pause cleanup failed')), isTrue);
      expect(
        logs.any((line) => line.contains('teardown cleanup failed')),
        isTrue,
      );
      engine.pauseError = null;
      engine.disposeError = null;
      await engine.dispose();
      container = makeContainer();
    },
  );
}
