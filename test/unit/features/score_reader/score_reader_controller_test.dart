import 'dart:async';
import 'dart:io';

import 'package:coldigui/features/score_reader/data/audio/score_audio_engine.dart';
import 'package:coldigui/features/score_reader/data/providers/score_providers.dart';
import 'package:coldigui/features/score_reader/data/repositories/score_sound_font_repository.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_reader_controller.dart';
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

  Future<ScoreReaderController> open() async {
    container = makeContainer();
    final provider = scoreReaderControllerProvider(doc);
    container.listen(provider, (_, _) {});
    final controller = container.read(provider.notifier);
    await pumpEventQueue();
    return controller;
  }

  ScoreReaderState read() => container.read(scoreReaderControllerProvider(doc));

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
        buildScoreMidi(doc, programOverrides: {1: 127}),
      );
      final note = controller.playbackMap.timelines[1].firstWhere(
        (note) => !note.isRest,
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
      buildScoreMidi(doc, programOverrides: {1: 48}),
    );
    final note = controller.playbackMap.timelines[1].firstWhere(
      (note) => !note.isRest,
    );
    await controller.onElementTap(note.elementId);
    expect(engine.previews.last.$2, 48);
  });

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
        buildScoreMidi(doc, programOverrides: {0: 12, 1: 64}),
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

  test('tapping a note previews its pitch and moves the cursor', () async {
    final controller = await open();
    final note = controller.playbackMap.timelines.first.firstWhere(
      (n) => !n.isRest,
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
