@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/data/audio/score_audio_engine.dart';
import 'package:coldigui/features/score_reader/data/audio/score_sound_font.dart';
import 'package:coldigui/features/score_reader/data/audio/soloud_bootstrap.dart';
import 'package:coldigui/features/score_reader/data/datasources/fallback_sound_font.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart';
import 'package:web/web.dart' as web;

@JS('miniaudio.devices')
external JSArray<JSObject?> get _webAudioDevices;

// Run: python3 scripts/test_score_audio_web.py
// The runner automates asset exposure and trusted WebAudio activation; the
// SF2 parser, MIDI sequencer, WASM mixer and output PCM remain real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lifecycle dispose invalidates a real MIDI load still preparing',
    () async {
      final prepared = Completer<void>();
      final release = Completer<void>();
      var sequencerClosed = false;
      var positionsClosed = false;
      final engine = SoundFontScoreAudioEngine.withMidiLoader((
        sequencer,
        midi,
      ) async {
        await sequencer.load(midi);
        sequencer.positionStream.listen(
          (_) {},
          onDone: () => sequencerClosed = true,
        );
        prepared.complete();
        await release.future;
      });
      engine.positions.listen((_) {}, onDone: () => positionsClosed = true);
      final outcome = engine
          .load(midi: _midi(), soundFont: buildFallbackSoundFont())
          .then<Object?>((_) => null, onError: (Object error) => error);
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await outcome;
        await engine.dispose();
        await _disposeBackend();
      });
      await prepared.future;
      expect(SoLoud.instance.activeSounds, isNotEmpty);
      final disposing = engine.dispose();
      release.complete();
      final error = await outcome;
      await disposing;
      expect(
        error,
        isStateError,
        reason: 'obsolete load must reject its caller',
      );
      await _until(
        () => sequencerClosed && positionsClosed,
        'all streams disposed',
      );
      expect(SoLoud.instance.activeSounds, isEmpty);
      expect(engine.isPlaying, isFalse);
      await expectLater(
        engine.load(midi: _midi(), soundFont: buildFallbackSoundFont()),
        throwsStateError,
      );
      await engine.dispose();
    },
  );

  test(
    'lifecycle failed preload releases real sources and preserves its error',
    () async {
      final failure = StateError('intentional preload failure');
      var failNext = true;
      var failedSequencerClosed = false;
      final engine = SoundFontScoreAudioEngine.withMidiLoader((
        sequencer,
        midi,
      ) async {
        await sequencer.load(midi);
        if (failNext) {
          failNext = false;
          sequencer.positionStream.listen(
            (_) {},
            onDone: () => failedSequencerClosed = true,
          );
          throw failure;
        }
      });
      addTearDown(() async {
        await engine.dispose();
        await _disposeBackend();
      });
      await expectLater(
        engine.load(midi: _midi(), soundFont: buildFallbackSoundFont()),
        throwsA(same(failure)),
      );
      expect(SoLoud.instance.activeSounds, isEmpty);
      await _until(() => failedSequencerClosed, 'failed sequencer disposed');
      await engine.load(midi: _midi(), soundFont: buildFallbackSoundFont());
      await engine.seek(const Duration(seconds: 3));
      expect(engine.position, const Duration(seconds: 3));
    },
  );

  test(
    'lifecycle newest concurrent load wins and discards the obsolete MIDI',
    () async {
      final firstPrepared = Completer<void>();
      final releaseFirst = Completer<void>();
      var preparation = 0;
      var firstClosed = false;
      final engine = SoundFontScoreAudioEngine.withMidiLoader((
        sequencer,
        midi,
      ) async {
        await sequencer.load(midi);
        if (preparation++ == 0) {
          sequencer.positionStream.listen(
            (_) {},
            onDone: () => firstClosed = true,
          );
          firstPrepared.complete();
          await releaseFirst.future;
        }
      });
      final first = engine
          .load(midi: _midi(), soundFont: buildFallbackSoundFont())
          .then<Object?>((_) => null, onError: (Object error) => error);
      addTearDown(() async {
        if (!releaseFirst.isCompleted) releaseFirst.complete();
        await first;
        await engine.dispose();
        await _disposeBackend();
      });
      await firstPrepared.future;
      final second = engine.load(
        midi: _midi(secondNoteTicks: 960),
        soundFont: buildFallbackSoundFont(),
      );
      releaseFirst.complete();
      final firstError = await first;
      await second;
      expect(firstError, isStateError);
      await _until(() => firstClosed, 'superseded sequencer disposed');
      expect(SoLoud.instance.activeSounds, hasLength(1));
      await engine.seek(const Duration(seconds: 20));
      expect(
        engine.position,
        const Duration(seconds: 2),
        reason: 'newest MIDI owns playback',
      );
      await engine.play();
      await engine.seek(Duration.zero);
      await _until(
        () => engine.isPlaying && SoLoud.instance.getActiveVoiceCount() > 0,
        'newest real MIDI remains playable after obsolete cleanup',
      );
    },
  );

  test(
    'SF3 retains PCM loop coordinates, compressed bytes and zone references',
    () async {
      final bytes = await _fixtureSf3();
      final original = await SoundFontFile.fromBytes(bytes);
      final file = await parseScoreSoundFont(bytes);
      expect(file.format, SoundFontFormat.sf3);
      expect(file.samples, hasLength(3));
      for (var i = 0; i < file.samples.length; i++) {
        final sample = file.samples[i];
        expect(sample.loopStart, 400);
        expect(sample.loopEnd, 15000);
        expect(sample.compression, SampleCompression.ogg);
        expect(sample.byteOffset, original.samples[i].byteOffset);
        expect(sample.byteLength, original.samples[i].byteLength);
        expect(sample.sampleLink, original.samples[i].sampleLink);
        expect(sample.sampleType, original.samples[i].sampleType);
        expect(
          await file.getSampleBytes(sample),
          await original.getSampleBytes(original.samples[i]),
        );
        expect(
          await file
              .getSampleByteStream(sample, chunkSize: 64)
              .expand((b) => b)
              .toList(),
          await file.getSampleBytes(sample),
        );
      }
      expect(file.instruments[0].zones.last.sampleRef, same(file.samples[2]));
      expect(file.instruments[1].zones.last.sampleRef, same(file.samples[1]));
      expect(file.instruments[0].zones.last.loopMode, LoopMode.continuous);
      // Positive but wrong offsets need correction too, not only negatives.
      final positive = Uint8List.fromList(bytes);
      final shdr = _chunkOffset(positive, 'shdr');
      ByteData.sublistView(positive)
        ..setUint32(shdr + 46 + 28, 12000, Endian.little)
        ..setUint32(shdr + 46 + 32, 16000, Endian.little);
      final positiveFile = await parseScoreSoundFont(positive);
      expect(positiveFile.samples[1].loopStart, 12000);
      expect(positiveFile.samples[1].loopEnd, 16000);
    },
  );

  test(
    'SF2 sample-relative loops stay unchanged with a nonzero sample start',
    () async {
      final bytes = buildFallbackSoundFont();
      final shdr = _chunkOffset(bytes, 'shdr');
      final data = ByteData.sublistView(bytes);
      // The sample's first 128 PCM frames are unused; SF2 loop indices remain
      // absolute in shdr and become sample-relative in the upstream parser.
      data
        ..setUint32(shdr + 20, 128, Endian.little)
        ..setUint32(shdr + 28, 328, Endian.little)
        ..setUint32(shdr + 32, 4128, Endian.little);
      final file = await parseScoreSoundFont(bytes);
      expect(file.format, SoundFontFormat.sf2);
      expect(file.samples.single.loopStart, 200);
      expect(file.samples.single.loopEnd, 4000);
      expect(file.samples.single.compression, SampleCompression.pcm16);
    },
  );

  for (final (label, program) in [('mono', 0), ('linked stereo', 1)]) {
    test(
      'real SF3 $label decodes Ogg and produces looped MIDI PCM',
      () async =>
          _exerciseSf3(await _fixtureSf3(), program: program, label: label),
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }
  const officialUrl = String.fromEnvironment('SCORE_AUDIO_SF3_URL');
  if (officialUrl.isNotEmpty) {
    test('official SF3 produces real MIDI PCM', () async {
      await _exerciseSf3(
        await _fetchBytes(Uri.parse(officialUrl)),
        program: 0,
        label: 'official FluidR3',
      );
    }, timeout: const Timeout(Duration(seconds: 90)));
  }

  test('499 score playback produces real non-silent WASM PCM', () async {
    final document = parseScoreDocument(
      await _fetchBytes(Uri.base.resolve('../fixtures/scores/499.mscz')),
    );
    final plan = ScorePerformancePlan.fromDocument(
      document,
      includeChordSymbols: true,
    );
    expect(
      plan.events.where((event) => event.chordPitches != null),
      isNotEmpty,
    );
    final midi = buildScoreMidi(
      document,
      programOverrides: {for (final staff in document.staves) staff.index: 0},
      performancePlan: plan,
      includeChordAccompaniment: true,
    );
    await _exerciseFallbackMidi(midi, label: '499');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('real WASM backend plays fallback SF2 from MIDI, pauses, seeks and disposes', () async {
    final engine = SoundFontScoreAudioEngine();
    final backend = SoLoud.instance;
    final positions = <Duration>[];
    final playing = <bool>[];
    var positionsClosed = false;
    var playingClosed = false;
    var disposed = false;
    var peak = 0.0;
    var pcmSamples = 0;
    var phase = 'load/playback';
    final rejections = <String>[];
    final onRejection = ((web.PromiseRejectionEvent event) {
      final reason = event.reason as JSObject;
      final stack =
          reason.getProperty<JSString?>('stack'.toJS)?.toDart ??
          '${reason.getProperty<JSString?>('name'.toJS)?.toDart}: '
              '${reason.getProperty<JSString?>('message'.toJS)?.toDart}';
      rejections.add('$phase: $stack');
      debugPrint('BROWSER UNHANDLED [$phase]: $stack');
    }).toJS;
    web.window.addEventListener('unhandledrejection', onRejection);
    StreamSubscription<Uint8List>? capture;
    final positionSub = engine.positions.listen(
      positions.add,
      onDone: () => positionsClosed = true,
    );
    final playingSub = engine.playingChanges.listen(
      playing.add,
      onDone: () => playingClosed = true,
    );
    addTearDown(() async {
      if (!disposed) await engine.dispose();
      if (backend.isMixerOutputStreamRunning) backend.stopMixerOutputStream();
      await capture?.cancel();
      await positionSub.cancel();
      await playingSub.cancel();
      phase = 'final backend deinit';
      if (backend.isInitialized) await backend.deinitAsync();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      web.window.removeEventListener('unhandledrejection', onRejection);
      expect(rejections, isEmpty);
    });

    await engine
        .load(midi: _midi(), soundFont: buildFallbackSoundFont())
        .timeout(const Duration(seconds: 20));
    expect(backend.isInitialized, isTrue);
    expect(backend.activeSounds, isNotEmpty, reason: 'SF2 samples preloaded');
    expect(engine.isPlaying, isFalse);
    expect(engine.position, Duration.zero);

    capture = backend.startMixerOutputStream().listen((bytes) {
      final data = ByteData.sublistView(bytes);
      for (var offset = 0; offset + 4 <= bytes.length; offset += 4) {
        final sample = data.getFloat32(offset, Endian.little);
        expect(sample.isFinite, isTrue);
        if (sample.abs() > peak) peak = sample.abs();
        pcmSamples++;
      }
    });
    await engine.play();
    try {
      await _until(
        () =>
            playing.contains(true) &&
            backend.getActiveVoiceCount() > 0 &&
            engine.position >= const Duration(milliseconds: 150) &&
            peak > 0.001,
        'MIDI must create a real voice and non-silent mixer PCM',
      );
    } finally {
      debugPrint(
        'SoLoud WASM: voices=${backend.getActiveVoiceCount()}, '
        'pcmSamples=$pcmSamples, peak=$peak, position=${engine.position}, '
        'playing=$playing',
      );
    }
    expect(engine.isPlaying, isTrue);
    expect(positions, isNotEmpty);

    await engine.pause();
    await _until(() => playing.last == false, 'pause state event');
    final pausedAt = engine.position;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(engine.isPlaying, isFalse);
    expect(engine.position, pausedAt);

    const target = Duration(seconds: 1);
    await engine.seek(target);
    await _until(() => positions.last == target, 'seek position event');
    expect(engine.position, target);
    expect(engine.isPlaying, isFalse);

    await engine.play();
    await _until(
      () =>
          playing.last &&
          engine.position > target &&
          backend.getActiveVoiceCount() > 0,
      'play resumes from the sought position',
    );
    await engine.seek(const Duration(milliseconds: 3800));
    await _until(
      () => !engine.isPlaying && playing.last == false,
      'end of MIDI emits stopped state',
    );
    expect(playing, [true, false, true, false]);

    await engine.seek(Duration.zero);
    await engine.play();
    await _until(
      () => backend.getActiveVoiceCount() > 0,
      'voice before disposal',
    );
    phase = 'engine dispose';
    await engine.dispose();
    disposed = true;
    await _until(
      () => positionsClosed && playingClosed,
      'public streams close on disposal',
    );
    expect(engine.isPlaying, isFalse);
    expect(engine.position, Duration.zero);
    expect(backend.activeSounds, isEmpty);
    await _until(
      () => backend.getActiveVoiceCount() == 0,
      'disposal releases real voices',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(rejections, isEmpty, reason: 'engine disposal must be clean');
    debugPrint(
      'T1: engine.dispose clean; backend initialized=${backend.isInitialized}',
    );

    phase = 'first backend deinit';
    backend.stopMixerOutputStream();
    await capture.cancel();
    await backend.deinitAsync();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(rejections, isEmpty, reason: 'first backend deinit must be clean');
    debugPrint('T1: first global backend deinit clean');
    phase = 'backend reinitialization';
    await ensureSoLoudReady().timeout(const Duration(seconds: 20));
    expect(backend.isInitialized, isTrue, reason: 'backend can reinitialize');
    // Native init resolves before WebAudio's resume Promise. This test's
    // immediate global shutdown must await it, unlike engine.dispose(),
    // which releases score voices/sources but keeps the shared backend alive.
    for (final device in _webAudioDevices.toDart.nonNulls) {
      final context = device.getProperty<web.AudioContext?>('webaudio'.toJS);
      if (context != null) {
        await context.resume().toDart.timeout(const Duration(seconds: 5));
      }
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'real MIDI CC64 routing releases on pause, seek, loop, end and dispose',
    () async {
      final backend = SoLoud.instance;
      final midiEvents = <MidiPlaybackEvent>[];
      MidiPlayer? sequencer;
      StreamSubscription<MidiPlaybackEvent>? midiSub;
      final engine = SoundFontScoreAudioEngine.withMidiLoader((
        player,
        midi,
      ) async {
        await player.load(midi);
        sequencer = player;
        midiSub = player.eventStream.listen(midiEvents.add);
      });
      var previousPosition = Duration.zero;
      var loopTransitions = 0;
      final positionSub = engine.positions.listen((position) {
        if (previousPosition - position > const Duration(milliseconds: 100)) {
          loopTransitions++;
        }
        previousPosition = position;
      });
      addTearDown(() async {
        await engine.dispose();
        await midiSub?.cancel();
        await positionSub.cancel();
        await _disposeBackend();
      });

      await engine.load(
        midi: _sustainPedalMidi(),
        soundFont: buildFallbackSoundFont(),
      );
      final channel = sequencer!.channels[0];

      await engine.play();
      await _until(
        () => midiEvents.any(
          (event) =>
              event.type == MidiPlaybackEventType.controlChange &&
              event.controller == 64 &&
              event.value == 127,
        ),
        'the real MIDI player receives CC64 down',
      );
      await _until(
        () => channel.sustainedVoices.isNotEmpty,
        'a note-off is held by the real sustain pedal',
      );
      expect(channel.isSustainPedalOn, isTrue);

      await engine.pause();
      await _until(
        () => !channel.isSustainPedalOn,
        'pause releases and resets the sustain pedal',
      );
      expect(channel.sustainedVoices, isEmpty);

      await engine.play();
      await _until(
        () => channel.isSustainPedalOn,
        'resume restores the pedal state at the paused position',
      );
      await _until(
        () => midiEvents.any(
          (event) =>
              event.type == MidiPlaybackEventType.controlChange &&
              event.controller == 64 &&
              event.value == 0 &&
              event.timestamp == const Duration(seconds: 1),
        ),
        'the real MIDI player receives CC64 up',
      );
      await engine.seek(const Duration(milliseconds: 750));
      await _until(
        () => engine.position == const Duration(milliseconds: 750),
        'seek reaches an active pedal span',
      );
      expect(channel.isSustainPedalOn, isTrue);
      expect(channel.activeVoices, isEmpty);
      expect(channel.sustainedVoices, isEmpty);

      await engine.pause();
      await _until(
        () => !channel.isSustainPedalOn,
        'paused seek leaves no pedal engaged',
      );
      await engine.seek(Duration.zero);
      expect(channel.isSustainPedalOn, isFalse);

      engine.setLoop((
        start: Duration.zero,
        end: const Duration(milliseconds: 250),
      ));
      await engine.play();
      await _until(() => loopTransitions >= 2, 'two real loop transitions');
      expect(channel.sustainedVoices, isEmpty);
      expect(channel.activeVoices[60]?.length ?? 0, lessThanOrEqualTo(1));

      engine.setLoop(null);
      await engine.pause();
      await _until(
        () => !channel.isSustainPedalOn,
        'loop stop releases the pedal',
      );
      await engine.seek(const Duration(milliseconds: 1200));
      await engine.play();
      await _until(() => !engine.isPlaying, 'natural MIDI end');
      expect(channel.isSustainPedalOn, isFalse);
      expect(channel.heldNotes, isEmpty);
      expect(channel.sustainedVoices, isEmpty);
      expect(channel.activeVoices, isEmpty);
      expect(
        midiEvents
            .where(
              (event) =>
                  event.type == MidiPlaybackEventType.controlChange &&
                  event.controller == 64,
            )
            .map((event) => (event.value, event.timestamp)),
        containsAll([(127, Duration.zero), (0, const Duration(seconds: 1))]),
      );

      await engine.seek(Duration.zero);
      await engine.play();
      await _until(
        () => channel.activeVoices.isNotEmpty,
        'active real note before engine disposal',
      );
      await engine.dispose();
      expect(channel.isSustainPedalOn, isFalse);
      expect(channel.heldNotes, isEmpty);
      expect(channel.sustainedVoices, isEmpty);
      expect(channel.activeVoices, isEmpty);
      expect(backend.getActiveVoiceCount(), 0);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

// Authored fixture: 441 Hz sine, mono Vorbis, 17640 PCM frames, serial 79.
// Its linked right/left and mono samples start at compressed byte offsets
// 0/3956/7912, while all three PCM loop ranges are [400,15000).
Future<Uint8List> _fixtureSf3() async {
  return _fetchBytes(
    Uri.base.resolve('../fixtures/scores/loop_regression.sf3'),
  );
}

Future<Uint8List> _fetchBytes(Uri uri) async {
  final response = await web.window.fetch(uri.toString().toJS).toDart;
  expect(response.status, 200, reason: 'Load audio fixture $uri');
  return (await response.arrayBuffer().toDart).toDart.asUint8List();
}

Future<void> _disposeBackend() async {
  if (!SoLoud.instance.isInitialized) return;
  for (final device in _webAudioDevices.toDart.nonNulls) {
    final context = device.getProperty<web.AudioContext?>('webaudio'.toJS);
    if (context != null) {
      await context.resume().toDart.timeout(const Duration(seconds: 5));
    }
  }
  await SoLoud.instance.deinitAsync();
}

Future<void> _exerciseSf3(
  Uint8List font, {
  required int program,
  required String label,
}) async {
  final engine = SoundFontScoreAudioEngine();
  final backend = SoLoud.instance;
  StreamSubscription<Uint8List>? capture;
  var peak = 0.0;
  var sampleCount = 0;
  var lastNonSilentAt = Duration.zero;
  addTearDown(() async {
    await engine.dispose();
    if (backend.isMixerOutputStreamRunning) backend.stopMixerOutputStream();
    await capture?.cancel();
    if (backend.isInitialized) {
      for (final device in _webAudioDevices.toDart.nonNulls) {
        final context = device.getProperty<web.AudioContext?>('webaudio'.toJS);
        if (context != null) {
          await context.resume().toDart.timeout(const Duration(seconds: 5));
        }
      }
      await backend.deinitAsync();
    }
  });
  await engine.load(
    midi: _midi(program: program),
    soundFont: font,
  );
  capture = backend.startMixerOutputStream().listen((bytes) {
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 4 <= bytes.length; i += 4) {
      final value = data.getFloat32(i, Endian.little);
      expect(value.isFinite, isTrue);
      sampleCount++;
      if (value.abs() > peak) peak = value.abs();
      if (value.abs() > 0.001) lastNonSilentAt = engine.position;
    }
  });
  await engine.play();
  await _until(
    () =>
        backend.getActiveVoiceCount() > 0 &&
        engine.position > const Duration(milliseconds: 1800) &&
        lastNonSilentAt > const Duration(milliseconds: 1800),
    'SF3 must sustain real PCM beyond the 400ms authored sample',
  );
  debugPrint(
    'SF3 $label: samples=$sampleCount peak=$peak '
    'nonSilentAt=$lastNonSilentAt voices=${backend.getActiveVoiceCount()}',
  );
  expect(peak, greaterThan(0.001));
  await engine.pause();
  final paused = engine.position;
  await Future<void>.delayed(const Duration(milliseconds: 100));
  expect(engine.position, paused);
  await engine.seek(const Duration(seconds: 1));
  expect(engine.position, const Duration(seconds: 1));
}

Future<void> _exerciseFallbackMidi(
  Uint8List midi, {
  required String label,
}) async {
  final engine = SoundFontScoreAudioEngine();
  final backend = SoLoud.instance;
  StreamSubscription<Uint8List>? capture;
  var peak = 0.0;
  var sampleCount = 0;
  addTearDown(() async {
    await engine.dispose();
    if (backend.isMixerOutputStreamRunning) backend.stopMixerOutputStream();
    await capture?.cancel();
    if (backend.isInitialized) {
      for (final device in _webAudioDevices.toDart.nonNulls) {
        final context = device.getProperty<web.AudioContext?>('webaudio'.toJS);
        if (context != null) {
          await context.resume().toDart.timeout(const Duration(seconds: 5));
        }
      }
      await backend.deinitAsync();
    }
  });
  await engine
      .load(midi: midi, soundFont: buildFallbackSoundFont())
      .timeout(const Duration(seconds: 20));
  expect(backend.activeSounds, isNotEmpty);
  capture = backend.startMixerOutputStream().listen((bytes) {
    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset + 4 <= bytes.length; offset += 4) {
      final sample = data.getFloat32(offset, Endian.little);
      expect(sample.isFinite, isTrue);
      if (sample.abs() > peak) peak = sample.abs();
      sampleCount++;
    }
  });
  await engine.play();
  await _until(
    () =>
        backend.getActiveVoiceCount() > 0 &&
        engine.position > const Duration(milliseconds: 100) &&
        peak > 0.001,
    '$label MIDI must produce real non-silent mixer PCM',
  );
  debugPrint(
    '$label WASM: voices=${backend.getActiveVoiceCount()}, '
    'pcmSamples=$sampleCount, peak=$peak, position=${engine.position}',
  );
  expect(peak, greaterThan(0.001));
  await engine.pause();
}

int _chunkOffset(Uint8List bytes, String id) {
  final needle = id.codeUnits;
  for (var i = 12; i + 8 < bytes.length; i++) {
    if (bytes[i] == needle[0] &&
        bytes[i + 1] == needle[1] &&
        bytes[i + 2] == needle[2] &&
        bytes[i + 3] == needle[3]) {
      return i + 8;
    }
  }
  throw StateError('Missing $id in test fixture');
}

Uint8List _sustainPedalMidi() {
  final score = MultiPartScore([
    Score(
      clef: Clef.treble,
      timeSignature: const TimeSignature(4, 4),
      measures: [
        Measure([
          NoteElement.note(Pitch(Step.c), NoteDuration.quarter, id: 'pedal-on'),
          NoteElement.note(
            Pitch(Step.d),
            NoteDuration.quarter,
            id: 'pedal-off',
          ),
          NoteElement.note(Pitch(Step.e), NoteDuration.quarter),
          NoteElement.note(Pitch(Step.f), NoteDuration.quarter),
        ]),
      ],
      pedals: const [Pedal('pedal-on', 'pedal-off')],
    ),
  ]);
  final document = ScoreDocument(
    score: score,
    staves: const [ScoreStaff(index: 0, partName: 'Test')],
    format: ScoreSourceFormat.musicXml,
  );
  final plan = ScorePerformancePlan.fromDocument(document);
  return buildScoreMidi(document, performancePlan: plan);
}

Future<void> _until(bool Function() condition, String reason) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out: $reason');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

// Standard MIDI format 0, 480 ticks/quarter at 120 BPM: A4 for one
// second, then C5 for three seconds, including real note-off/end events.
Uint8List _midi({int program = 0, int secondNoteTicks = 2880}) =>
    Uint8List.fromList([
      ...'MThd'.codeUnits,
      0,
      0,
      0,
      6,
      0,
      0,
      0,
      1,
      1,
      0xe0,
      ...'MTrk'.codeUnits,
      0,
      0,
      0,
      32,
      0,
      0xff,
      0x51,
      3,
      0x07,
      0xa1,
      0x20,
      0,
      0xc0,
      program,
      0,
      0x90,
      69,
      100,
      0x87,
      0x40,
      0x80,
      69,
      0,
      0,
      0x90,
      72,
      100,
      0x80 | (secondNoteTicks >> 7),
      secondNoteTicks & 0x7f,
      0x80,
      72,
      0,
      0,
      0xff,
      0x2f,
      0,
    ]);
