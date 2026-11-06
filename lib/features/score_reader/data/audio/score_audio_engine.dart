import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:soundfont_kit/soundfont_kit.dart';

import 'score_sound_font.dart';
import 'soloud_bootstrap.dart';

/// Motor de execução da partitura: sequenciador MIDI + sintetizador
/// SoundFont. Porta para o controller poder ser testado sem áudio.
abstract interface class ScoreAudioEngine {
  /// Posição (tempo virtual da música, já sem o multiplicador de velocidade).
  Stream<Duration> get positions;

  /// Emite a cada play/pause/stop — inclusive o stop automático no fim.
  Stream<bool> get playingChanges;

  bool get isPlaying;
  Duration get position;

  /// Carrega (ou troca) MIDI e SoundFont, preservando posição, ajustes e
  /// estado de execução. Rejeita com [StateError] se descartado ou substituído
  /// por outro carregamento; falhas de preparo são propagadas ao chamador.
  Future<void> load({required Uint8List midi, required Uint8List soundFont});

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  set speed(double multiplier);
  set transpose(int semitones);

  /// Loop A-B; `null` desliga.
  void setLoop(({Duration start, Duration end})? range);

  void setTrackMuted(int track, bool muted);
  void setTrackSolo(int track, bool solo);

  /// [volume] de 0 a 1 sobre o volume padrão do canal.
  void setChannelVolume(int channel, double volume);

  /// Toca [pitch] (MIDI) uma vez, com o timbre de [program] (GM, 0-based).
  Future<void> preview(int pitch, {int program = 0});

  Future<void> dispose();
}

/// Volume padrão de canal do General MIDI (CC7 = 100).
const double _defaultChannelVolume = 100 / 127;

/// [ScoreAudioEngine] sobre `soundfont_kit` (Dart puro + SoLoud: web,
/// Android e iOS).
class SoundFontScoreAudioEngine implements ScoreAudioEngine {
  SoundFontScoreAudioEngine() : _loadMidi = _prepareMidi;

  @visibleForTesting
  SoundFontScoreAudioEngine.withMidiLoader(this._loadMidi);

  final Future<void> Function(MidiPlayer, MidiFile) _loadMidi;

  static Future<void> _prepareMidi(MidiPlayer sequencer, MidiFile midi) =>
      sequencer.load(midi);

  final _positions = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  SoundFontPlayer? _synth;
  MidiPlayer? _sequencer;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<MidiPlaybackEvent>? _eventSub;

  double _speed = 1;
  int _transpose = 0;
  ({Duration start, Duration end})? _loop;
  final _muted = <int>{};
  final _solo = <int>{};
  final _volumes = <int, double>{};
  bool _lastPlaying = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  Future<void> _loadsDone = Future.value();
  Future<void>? _disposing;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<bool> get playingChanges => _playing.stream;

  @override
  bool get isPlaying => _sequencer?.isPlaying ?? false;

  @override
  Duration get position => _sequencer?.position ?? Duration.zero;

  @override
  Future<void> load({required Uint8List midi, required Uint8List soundFont}) {
    if (_disposed) {
      return Future.error(StateError('Score audio engine is disposed'));
    }
    final generation = ++_loadGeneration;
    // MidiPlayer.load/dispose call the shared backend's stopAll(). Serialize
    // preparation/cleanup so obsolete players cannot stop the newest score.
    final operation = _loadsDone.then(
      (_) => _load(midi: midi, soundFont: soundFont, generation: generation),
    );
    // Only the queue tail recovers; callers receive the original operation.
    _loadsDone = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  void _checkLoad(int generation) {
    if (_disposed) throw StateError('Score audio engine is disposed');
    if (generation != _loadGeneration) {
      throw StateError('Score audio load was superseded');
    }
  }

  Future<void> _load({
    required Uint8List midi,
    required Uint8List soundFont,
    required int generation,
  }) async {
    _checkLoad(generation);
    await ensureSoLoudReady();
    _checkLoad(generation);
    final resumeAt = position;
    final wasPlaying = isPlaying;

    final file = await parseScoreSoundFont(soundFont);
    _checkLoad(generation);
    final synth = file.createPlayer();
    MidiPlayer? sequencer;
    var installed = false;
    try {
      sequencer = MidiPlayer(player: synth);
      await _loadMidi(sequencer, MidiReader.fromBytes(midi));
      _checkLoad(generation);

      await _teardown();
      _checkLoad(generation);
      _synth = synth;
      _sequencer = sequencer;
      installed = true;
      _positionSub = sequencer.positionStream.listen(_positions.add);
      _eventSub = sequencer.eventStream.listen(_onEvent);
      _applySettings();
      if (resumeAt > Duration.zero) {
        await sequencer.seek(resumeAt);
        _checkLoad(generation);
      }
      if (wasPlaying) {
        await _syncSustainPedals(sequencer, restoreAtPosition: true);
        await sequencer.play();
        _checkLoad(generation);
      }
    } catch (error, stack) {
      try {
        if (!installed) {
          await _disposePlayers(sequencer, synth);
        } else if (identical(_sequencer, sequencer)) {
          await _teardown();
        }
      } on Object catch (cleanupError) {
        debugPrint(
          '[partitura] falha ao liberar carga de áudio: $cleanupError',
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  void _onEvent(MidiPlaybackEvent event) {
    switch (event.type) {
      case MidiPlaybackEventType.seek:
        // `seek` reaplica o snapshot do MIDI e apaga o volume da mesa.
        _applyVolumes();
        final sequencer = _sequencer;
        if (sequencer != null) {
          _applySustainPedalSnapshot(
            sequencer,
            restoreAtPosition: sequencer.isPlaying,
          );
        }
      case MidiPlaybackEventType.stateChange:
        _applyVolumes();
        final playing = isPlaying;
        if (!playing) {
          final sequencer = _sequencer;
          if (sequencer != null) {
            _applySustainPedalSnapshot(sequencer, restoreAtPosition: false);
          }
        }
        if (playing != _lastPlaying) {
          _lastPlaying = playing;
          _playing.add(playing);
        }
      default:
        break;
    }
  }

  void _applySustainPedalSnapshot(
    MidiPlayer sequencer, {
    required bool restoreAtPosition,
  }) {
    final snapshots = restoreAtPosition
        ? sequencer.timeline?.getSnapshotAt(sequencer.position).$1
        : null;
    for (final (channel, state) in sequencer.channels.indexed) {
      state.isSustainPedalOn = snapshots?[channel]?.isSustainPedalOn ?? false;
    }
  }

  Future<void> _syncSustainPedals(
    MidiPlayer sequencer, {
    required bool restoreAtPosition,
  }) async {
    final snapshots = restoreAtPosition
        ? sequencer.timeline?.getSnapshotAt(sequencer.position).$1
        : null;
    await Future.wait<void>([
      for (final (channel, state) in sequencer.channels.indexed)
        state.setSustainPedal(
          snapshots?[channel]?.isSustainPedalOn ?? false,
          releaseDuration: Duration.zero,
        ),
    ]);
  }

  void _applySettings() {
    final sequencer = _sequencer;
    if (sequencer == null) return;
    sequencer
      ..speedMultiplier = _speed
      ..transpose = _transpose;
    _applyLoop();
    for (final track in _muted) {
      sequencer.setTrackMute(track, true);
    }
    for (final track in _solo) {
      sequencer.setTrackSolo(track, true);
    }
    _applyVolumes();
  }

  void _applyLoop() {
    final sequencer = _sequencer;
    if (sequencer == null) return;
    final loop = _loop;
    if (loop == null) {
      sequencer
        ..clearLoopRange()
        ..looping = false;
    } else {
      sequencer
        ..setLoopRange(loop.start, loop.end)
        ..looping = true;
    }
  }

  void _applyVolumes() {
    final sequencer = _sequencer;
    if (sequencer == null) return;
    for (final MapEntry(key: channel, value: volume) in _volumes.entries) {
      sequencer.setChannelVolume(channel, volume * _defaultChannelVolume);
    }
  }

  @override
  Future<void> play() async {
    final sequencer = _sequencer;
    if (sequencer == null) return;
    await _syncSustainPedals(sequencer, restoreAtPosition: true);
    await sequencer.play();
  }

  @override
  Future<void> pause() async {
    final sequencer = _sequencer;
    if (sequencer == null) return;
    await sequencer.pause();
    await _syncSustainPedals(sequencer, restoreAtPosition: false);
  }

  @override
  Future<void> seek(Duration position) async {
    final sequencer = _sequencer;
    if (sequencer == null) return;
    await sequencer.seek(position);
    await _syncSustainPedals(sequencer, restoreAtPosition: sequencer.isPlaying);
  }

  @override
  set speed(double multiplier) {
    _speed = multiplier;
    _sequencer?.speedMultiplier = multiplier;
  }

  @override
  set transpose(int semitones) {
    _transpose = semitones;
    _sequencer?.transpose = semitones;
  }

  @override
  void setLoop(({Duration start, Duration end})? range) {
    _loop = range;
    _applyLoop();
  }

  @override
  void setTrackMuted(int track, bool muted) {
    muted ? _muted.add(track) : _muted.remove(track);
    _sequencer?.setTrackMute(track, muted);
  }

  @override
  void setTrackSolo(int track, bool solo) {
    solo ? _solo.add(track) : _solo.remove(track);
    _sequencer?.setTrackSolo(track, solo);
  }

  @override
  void setChannelVolume(int channel, double volume) {
    _volumes[channel] = volume.clamp(0, 1);
    _applyVolumes();
  }

  @override
  Future<void> preview(int pitch, {int program = 0}) async {
    final synth = _synth;
    if (synth == null) return;
    final font = synth.soundFont;
    final preset =
        font.findPreset(bank: 0, program: program) ??
        (font.presets.isEmpty ? null : font.presets.first);
    await synth.noteOn(
      (pitch + _transpose).clamp(0, 127),
      velocity: 90,
      preset: preset,
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _teardown() async {
    final positionSub = _positionSub;
    final eventSub = _eventSub;
    final sequencer = _sequencer;
    final synth = _synth;
    _positionSub = null;
    _eventSub = null;
    _sequencer = null;
    _synth = null;
    try {
      try {
        await positionSub?.cancel();
      } finally {
        await eventSub?.cancel();
      }
    } finally {
      await _disposePlayers(sequencer, synth);
    }
  }

  Future<void> _disposePlayers(
    MidiPlayer? sequencer,
    SoundFontPlayer? synth,
  ) async {
    try {
      await sequencer?.dispose();
    } finally {
      try {
        if (sequencer != null) {
          await _syncSustainPedals(sequencer, restoreAtPosition: false);
        }
      } finally {
        await synth?.dispose();
      }
    }
  }

  @override
  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    _disposed = true;
    _loadGeneration++;
    return _disposing = () async {
      try {
        await _teardown();
        await _loadsDone;
      } finally {
        await _positions.close();
        await _playing.close();
      }
    }();
  }
}
