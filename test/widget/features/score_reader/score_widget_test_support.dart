import 'dart:async';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/data/audio/score_audio_engine.dart';
import 'package:coldigui/features/score_reader/data/providers/score_providers.dart';
import 'package:coldigui/features/score_reader/data/repositories/score_sound_font_repository.dart';
import 'package:coldigui/features/score_reader/demo/score_reader_demo_fixture.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_music_font_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Same in-memory boundary as T2; this records commands, not audible output.
class WidgetScoreEngine implements ScoreAudioEngine {
  final positionsCtl = StreamController<Duration>.broadcast();
  final playingCtl = StreamController<bool>.broadcast();
  final previews = <(int, int)>[];
  final loads = <({Uint8List midi, Uint8List soundFont})>[];
  Object? loadError;
  final mutedTracks = <int>{};
  final soloTracks = <int>{};
  final volumes = <int, double>{};
  ({Duration start, Duration end})? loop;
  double currentSpeed = 1;
  int currentTranspose = 0;
  bool playing = false;
  Duration pos = Duration.zero;

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
    if (loadError != null) throw loadError!;
    loads.add((midi: midi, soundFont: soundFont));
  }

  @override
  Future<void> play() async {
    playing = true;
    playingCtl.add(true);
  }

  @override
  Future<void> pause() async {
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
    await positionsCtl.close();
    await playingCtl.close();
  }
}

class _WidgetSounds implements ScoreSoundFontRepository {
  @override
  String get key => 'widget-test.sf2';
  @override
  Uint8List get fallback => Uint8List.fromList([1]);
  @override
  Future<Uint8List?> readCached() async => null;
  @override
  Future<Uint8List> download({
    void Function(double progress)? onProgress,
  }) async => fallback;
}

Future<void> loadWidgetScoreFont() async {
  final container = ProviderContainer();
  try {
    await container
        .read(scoreMusicFontProvider.future)
        .timeout(const Duration(seconds: 15));
  } finally {
    container.dispose();
  }
}

Future<ProviderContainer> pumpScoreWidget(
  WidgetTester tester, {
  required WidgetScoreEngine engine,
  required Widget child,
  Size size = const Size(800, 600),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scoreAudioEngineFactoryProvider.overrideWithValue(() => engine),
        scoreSoundFontRepositoryProvider.overrideWithValue(_WidgetSounds()),
      ],
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

ScoreDocument widgetScoreDocument() => loadScoreReaderDemoDocument();
