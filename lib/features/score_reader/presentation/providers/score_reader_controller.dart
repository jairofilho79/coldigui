import 'dart:async';

import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/score_audio_engine.dart';
import '../../data/providers/score_providers.dart';
import '../../domain/entities/score_document.dart';
import '../../domain/usecases/build_score_midi.dart';
import '../../domain/usecases/score_playback_map.dart';
import '../../domain/usecases/transpose_score.dart';

/// Situação do motor de áudio.
enum ScoreAudioStatus { loading, ready, failed }

/// Qual SoundFont está tocando.
enum ScoreSoundFontStatus {
  /// Som mínimo embutido (um timbre só); o completo ainda não foi baixado.
  minimal,
  downloading,
  full,

  /// O download falhou; segue com o som mínimo e dá para tentar de novo.
  failed,
}

/// Ajuste de uma pauta na mesa de som.
@immutable
class StaffMix {
  const StaffMix({
    this.volume = 1,
    this.muted = false,
    this.solo = false,
    this.program = 0,
    this.programChanging = false,
    this.programFailed = false,
  });

  final double volume;
  final bool muted;
  final bool solo;
  final int program;
  final bool programChanging;
  final bool programFailed;

  StaffMix copyWith({
    double? volume,
    bool? muted,
    bool? solo,
    int? program,
    bool? programChanging,
    bool? programFailed,
  }) => StaffMix(
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    solo: solo ?? this.solo,
    program: program ?? this.program,
    programChanging: programChanging ?? this.programChanging,
    programFailed: programFailed ?? this.programFailed,
  );
}

@immutable
class ScoreReaderState {
  const ScoreReaderState({
    required this.document,
    required this.displayed,
    required this.duration,
    required this.mix,
    this.transpose = 0,
    this.speed = 1,
    this.playing = false,
    this.position = Duration.zero,
    this.activeIds = const {},
    this.activeMeasure,
    this.loopStart,
    this.loopEnd,
    this.audio = ScoreAudioStatus.loading,
    this.soundFont = ScoreSoundFontStatus.minimal,
    this.soundFontProgress,
  });

  final ScoreDocument document;

  /// A partitura como desenhada (com a transposição aplicada).
  final MultiPartScore displayed;
  final Duration duration;
  final List<StaffMix> mix;

  /// Semitons (−12 a +12) aplicados ao desenho e ao som.
  final int transpose;

  /// Multiplicador de andamento (0,25 a 2).
  final double speed;
  final bool playing;
  final Duration position;

  /// Ids em destaque: notas soando (e pausas com cifra), ou o elemento
  /// tocado pelo usuário com a execução parada.
  final Set<String> activeIds;

  /// Compasso do cursor — guia a rolagem automática e o loop.
  final int? activeMeasure;

  /// Loop A-B por compasso (inclusive). Só [loopStart] = A marcado.
  final int? loopStart;
  final int? loopEnd;

  final ScoreAudioStatus audio;
  final ScoreSoundFontStatus soundFont;

  /// 0 a 1 durante [ScoreSoundFontStatus.downloading], quando conhecido.
  final double? soundFontProgress;

  double get bpm => document.quarterBpm * speed;
  bool get isLoopActive => loopStart != null && loopEnd != null;

  ScoreReaderState copyWith({
    MultiPartScore? displayed,
    List<StaffMix>? mix,
    int? transpose,
    double? speed,
    bool? playing,
    Duration? position,
    Set<String>? activeIds,
    int? Function()? activeMeasure,
    int? Function()? loopStart,
    int? Function()? loopEnd,
    ScoreAudioStatus? audio,
    ScoreSoundFontStatus? soundFont,
    double? Function()? soundFontProgress,
  }) => ScoreReaderState(
    document: document,
    displayed: displayed ?? this.displayed,
    duration: duration,
    mix: mix ?? this.mix,
    transpose: transpose ?? this.transpose,
    speed: speed ?? this.speed,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    activeIds: activeIds ?? this.activeIds,
    activeMeasure: activeMeasure == null ? this.activeMeasure : activeMeasure(),
    loopStart: loopStart == null ? this.loopStart : loopStart(),
    loopEnd: loopEnd == null ? this.loopEnd : loopEnd(),
    audio: audio ?? this.audio,
    soundFont: soundFont ?? this.soundFont,
    soundFontProgress: soundFontProgress == null
        ? this.soundFontProgress
        : soundFontProgress(),
  );
}

const kScoreMinSpeed = 0.25;
const kScoreMaxSpeed = 2.0;
const kScoreMaxTranspose = 12;

/// Leitor + player de uma partitura já carregada.
///
/// Um por documento (a família é pela instância): sair da tela descarta o
/// motor de áudio junto.
final scoreReaderControllerProvider = NotifierProvider.autoDispose
    .family<ScoreReaderController, ScoreReaderState, ScoreDocument>(
      ScoreReaderController.new,
    );

class ScoreReaderController extends Notifier<ScoreReaderState> {
  ScoreReaderController(this.document);

  final ScoreDocument document;

  late ScorePlaybackMap _map;
  late Uint8List _midi;
  Uint8List? _activeSoundFont;
  Future<void> _audioReload = Future.value();
  ScoreAudioEngine? _engine;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false;
  bool _fullSoundFontRequested = false;

  @override
  ScoreReaderState build() {
    _map = ScorePlaybackMap.of(document.score, quarterBpm: document.quarterBpm);
    _midi = buildScoreMidi(document);
    ref.onDispose(_dispose);
    unawaited(_startAudio());
    return ScoreReaderState(
      document: document,
      displayed: document.score,
      duration: _map.duration,
      mix: [
        for (final staff in document.staves)
          StaffMix(program: staff.midiProgram ?? 0),
      ],
    );
  }

  ScorePlaybackMap get playbackMap => _map;

  Future<void> _startAudio() async {
    final engine = ref.read(scoreAudioEngineFactoryProvider)();
    _engine = engine;
    _subscriptions
      ..add(engine.positions.listen(_onPosition))
      ..add(engine.playingChanges.listen(_onPlayingChanged));
    final sounds = ref.read(scoreSoundFontRepositoryProvider);
    try {
      final cached = await sounds.readCached();
      if (_disposed) return;
      await _queueAudioReload(() async {
        final font = cached ?? sounds.fallback;
        await engine.load(midi: _midi, soundFont: font);
        if (_disposed) return;
        _activeSoundFont = font;
        state = state.copyWith(
          audio: ScoreAudioStatus.ready,
          soundFont: cached == null
              ? ScoreSoundFontStatus.minimal
              : ScoreSoundFontStatus.full,
        );
      });
    } on Object catch (error) {
      debugPrint('[partitura] motor de áudio indisponível: $error');
      if (_disposed) return;
      state = state.copyWith(audio: ScoreAudioStatus.failed);
    }
  }

  /// Baixa o SoundFont completo e troca o timbre sem parar a execução.
  Future<void> downloadFullSoundFont() async {
    final engine = _engine;
    if (engine == null ||
        state.soundFont == ScoreSoundFontStatus.full ||
        state.soundFont == ScoreSoundFontStatus.downloading) {
      return;
    }
    _fullSoundFontRequested = true;
    state = state.copyWith(
      soundFont: ScoreSoundFontStatus.downloading,
      soundFontProgress: () => null,
    );
    try {
      final bytes = await ref
          .read(scoreSoundFontRepositoryProvider)
          .download(
            onProgress: (p) {
              if (_disposed) return;
              // Só repinta a cada ponto percentual.
              final last = state.soundFontProgress ?? -1;
              if ((p - last).abs() >= 0.01 || p == 1) {
                state = state.copyWith(soundFontProgress: () => p);
              }
            },
          );
      if (_disposed) return;
      await _queueAudioReload(() async {
        await engine.load(midi: _midi, soundFont: bytes);
        if (_disposed) return;
        _activeSoundFont = bytes;
        state = state.copyWith(
          soundFont: ScoreSoundFontStatus.full,
          soundFontProgress: () => null,
        );
      });
    } on Object catch (error) {
      debugPrint('[partitura] SoundFont completo indisponível: $error');
      if (_disposed) return;
      state = state.copyWith(
        soundFont: ScoreSoundFontStatus.failed,
        soundFontProgress: () => null,
      );
    }
  }

  void _onPosition(Duration position) {
    if (_disposed) return;
    final ids = _map.soundingAt(position);
    final measure = _map.measureAt(position) ?? state.activeMeasure;
    final idsChanged = !setEquals(ids, state.activeIds);
    final measureChanged = measure != state.activeMeasure;
    // A posição só alimenta a barra de progresso: 10 quadros por segundo
    // bastam e poupam reconstruções.
    final positionStale =
        (position - state.position).abs() >= const Duration(milliseconds: 100);
    if (!idsChanged && !measureChanged && !positionStale) return;
    state = state.copyWith(
      position: position,
      activeIds: idsChanged ? ids : null,
      activeMeasure: measureChanged ? () => measure : null,
    );
  }

  void _onPlayingChanged(bool playing) {
    if (_disposed) return;
    state = state.copyWith(playing: playing);
  }

  Future<void> togglePlay() async {
    final engine = _engine;
    if (engine == null || state.audio != ScoreAudioStatus.ready) return;
    if (engine.isPlaying) {
      await engine.pause();
      return;
    }
    // "Sob demanda": o primeiro play começa a baixar os timbres reais
    // enquanto o som mínimo já toca.
    if (!_fullSoundFontRequested &&
        state.soundFont == ScoreSoundFontStatus.minimal) {
      unawaited(downloadFullSoundFont());
    }
    final loop = _loopRange();
    if (loop != null &&
        (engine.position < loop.start || engine.position >= loop.end)) {
      await engine.seek(loop.start);
    }
    await engine.play();
  }

  Future<void> stop() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.pause();
    await engine.seek(_loopRange()?.start ?? Duration.zero);
    state = state.copyWith(
      position: engine.position,
      activeIds: const {},
      activeMeasure: () => null,
    );
  }

  /// Toque numa nota/pausa: toca a nota e leva o cursor até ela.
  Future<void> onElementTap(String elementId) async {
    final start = _map.startOfElement(elementId);
    final measure = _map.measureOfElement(elementId);
    if (start == null) return;
    final engine = _engine;
    state = state.copyWith(
      position: start,
      activeIds: {elementId},
      activeMeasure: measure == null ? null : () => measure,
    );
    if (engine == null || state.audio != ScoreAudioStatus.ready) return;
    await engine.seek(start);
    if (!engine.isPlaying) {
      final staff = _staffOf(elementId);
      final program = staff == null ? 0 : state.mix[staff].program;
      for (final pitch in _pitchesOf(elementId, staff)) {
        unawaited(engine.preview(pitch, program: program));
      }
    }
  }

  Future<void> seekToMeasure(int measure) async {
    final start = _map.startOfMeasure(measure);
    if (start == null) return;
    state = state.copyWith(position: start, activeMeasure: () => measure);
    await _engine?.seek(start);
  }

  Future<void> seek(Duration position) async {
    final measure = _map.measureAt(position) ?? state.activeMeasure;
    state = state.copyWith(
      position: position,
      activeIds: _map.soundingAt(position),
      activeMeasure: () => measure,
    );
    await _engine?.seek(position);
  }

  void setTranspose(int semitones) {
    final value = semitones.clamp(-kScoreMaxTranspose, kScoreMaxTranspose);
    if (value == state.transpose) return;
    _engine?.transpose = value;
    state = state.copyWith(
      transpose: value,
      displayed: transposeScore(document.score, value),
    );
  }

  void setSpeed(double speed) {
    final value = speed.clamp(kScoreMinSpeed, kScoreMaxSpeed);
    _engine?.speed = value;
    state = state.copyWith(speed: value);
  }

  /// Ciclo do botão de loop: marca A no compasso do cursor, depois B, depois
  /// desliga.
  void cycleLoop() {
    final measure = state.activeMeasure ?? 0;
    if (state.loopStart == null) {
      state = state.copyWith(loopStart: () => measure, loopEnd: () => null);
    } else if (state.loopEnd == null) {
      final a = state.loopStart!;
      state = state.copyWith(
        loopStart: () => measure < a ? measure : a,
        loopEnd: () => measure < a ? a : measure,
      );
    } else {
      state = state.copyWith(loopStart: () => null, loopEnd: () => null);
    }
    _engine?.setLoop(_loopRange());
  }

  void setLoop(int? start, int? end) {
    state = state.copyWith(loopStart: () => start, loopEnd: () => end);
    _engine?.setLoop(_loopRange());
  }

  ({Duration start, Duration end})? _loopRange() {
    final a = state.loopStart;
    final b = state.loopEnd;
    if (a == null || b == null) return null;
    final start = _map.startOfMeasure(a);
    final end = _map.endOfMeasure(b);
    if (start == null || end == null || end <= start) return null;
    return (start: start, end: end);
  }

  void setStaffVolume(int staff, double volume) {
    _updateMix(staff, state.mix[staff].copyWith(volume: volume));
    _engine?.setChannelVolume(midiChannelForStaff(staff), volume);
  }

  Future<void> setStaffProgram(int staff, int program) async {
    RangeError.checkValidIndex(staff, state.mix, 'staff');
    RangeError.checkValueInInterval(program, 0, 127, 'program');
    final mix = state.mix[staff];
    if (mix.programChanging) return;
    if (program == mix.program) {
      if (mix.programFailed) {
        _updateMix(staff, mix.copyWith(programFailed: false));
      }
      return;
    }
    _updateMix(
      staff,
      mix.copyWith(programChanging: true, programFailed: false),
    );
    try {
      await _queueAudioReload(() async {
        final overrides = <int, int>{};
        for (var i = 0; i < state.mix.length; i++) {
          final selected = i == staff ? program : state.mix[i].program;
          if (selected != (document.staves[i].midiProgram ?? 0)) {
            overrides[i] = selected;
          }
        }
        final midi = buildScoreMidi(document, programOverrides: overrides);
        final font = _activeSoundFont;
        if (font != null) {
          await _engine!.load(midi: midi, soundFont: font);
        }
        if (_disposed) return;
        _midi = midi;
        _updateMix(
          staff,
          state.mix[staff].copyWith(program: program, programChanging: false),
        );
      });
    } on Object catch (error) {
      debugPrint('[partitura] troca de instrumento indisponível: $error');
      if (_disposed) return;
      _updateMix(
        staff,
        state.mix[staff].copyWith(programChanging: false, programFailed: true),
      );
    }
  }

  // MIDI e banco são uma única troca: um download não pode restaurar um
  // programa antigo nem uma seleção atrasada restaurar o banco mínimo.
  Future<void> _queueAudioReload(Future<void> Function() reload) {
    final next = _audioReload.then((_) async {
      if (!_disposed) await reload();
    });
    _audioReload = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  void toggleStaffMute(int staff) {
    final muted = !state.mix[staff].muted;
    _updateMix(staff, state.mix[staff].copyWith(muted: muted));
    _engine?.setTrackMuted(staff, muted);
  }

  void toggleStaffSolo(int staff) {
    final solo = !state.mix[staff].solo;
    _updateMix(staff, state.mix[staff].copyWith(solo: solo));
    _engine?.setTrackSolo(staff, solo);
  }

  void _updateMix(int staff, StaffMix mix) {
    state = state.copyWith(mix: [...state.mix]..[staff] = mix);
  }

  int? _staffOf(String elementId) => _map.staffOfElement(elementId);

  Set<int> _pitchesOf(String elementId, int? staff) {
    if (staff == null) return const {};
    return pitchesForElements(document.score.parts[staff], [elementId]);
  }

  void _dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      unawaited(
        sub.cancel().catchError((Object error) {
          debugPrint(
            '[partitura] falha ao cancelar eventos no descarte: $error',
          );
        }),
      );
    }
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      unawaited(_disposeEngine(engine, _audioReload));
    }
  }

  Future<void> _disposeEngine(
    ScoreAudioEngine engine,
    Future<void> pendingReload,
  ) async {
    try {
      await engine.pause();
    } on Object catch (error) {
      debugPrint('[partitura] falha ao pausar áudio no descarte: $error');
    }
    // Um load em voo pode recriar e retomar o sequenciador após o pause.
    // A fila já está bloqueada por _disposed; só então o teardown é definitivo.
    await pendingReload;
    try {
      await engine.dispose();
    } on Object catch (error) {
      debugPrint('[partitura] falha ao liberar áudio no descarte: $error');
    }
  }
}
