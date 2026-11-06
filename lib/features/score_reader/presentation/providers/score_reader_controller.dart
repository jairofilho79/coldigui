import 'dart:async';

import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/score_audio_engine.dart';
import '../../data/providers/score_providers.dart';
import '../../domain/entities/score_document.dart';
import '../../domain/entities/score_playback_diagnostic.dart';
import '../../domain/usecases/build_score_midi.dart';
import '../../domain/usecases/score_playback_map.dart';
import '../../domain/usecases/score_performance_plan.dart';
import '../../domain/usecases/transpose_score.dart';

/// Situação do motor de áudio.
enum ScoreAudioStatus { loading, ready, failed, selectionRequired }

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
class ScoreChordMix {
  const ScoreChordMix({
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

  ScoreChordMix copyWith({
    double? volume,
    bool? muted,
    bool? solo,
    int? program,
    bool? programChanging,
    bool? programFailed,
  }) => ScoreChordMix(
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
    required this.selectedStaffIndices,
    required this.chordMix,
    this.chordAccompanimentEnabled = false,
    this.chordSourceStaffIndex,
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
    this.diagnostics = const [],
  });

  final ScoreDocument document;

  /// A partitura como desenhada (com a transposição aplicada).
  final MultiPartScore displayed;
  final Duration duration;
  final List<StaffMix> mix;
  final Set<int> selectedStaffIndices;
  final ScoreChordMix chordMix;
  final bool chordAccompanimentEnabled;
  final int? chordSourceStaffIndex;

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
  final List<ScorePlaybackDiagnostic> diagnostics;

  double get bpm => document.quarterBpm * speed;
  bool get isLoopActive => loopStart != null && loopEnd != null;
  int get maximumPlayableStaffCount =>
      chordAccompanimentEnabled && document.chordSymbolCount > 0 ? 14 : 15;
  bool get exceedsPlaybackCapacity =>
      selectedStaffIndices.length > maximumPlayableStaffCount;

  ScoreReaderState copyWith({
    MultiPartScore? displayed,
    List<StaffMix>? mix,
    Set<int>? selectedStaffIndices,
    ScoreChordMix? chordMix,
    bool? chordAccompanimentEnabled,
    int? Function()? chordSourceStaffIndex,
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
    List<ScorePlaybackDiagnostic>? diagnostics,
  }) => ScoreReaderState(
    document: document,
    displayed: displayed ?? this.displayed,
    duration: duration,
    mix: mix ?? this.mix,
    selectedStaffIndices: selectedStaffIndices ?? this.selectedStaffIndices,
    chordMix: chordMix ?? this.chordMix,
    chordAccompanimentEnabled:
        chordAccompanimentEnabled ?? this.chordAccompanimentEnabled,
    chordSourceStaffIndex: chordSourceStaffIndex == null
        ? this.chordSourceStaffIndex
        : chordSourceStaffIndex(),
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
    diagnostics: diagnostics ?? this.diagnostics,
  );
}

const kScoreMinSpeed = 0.25;
const kScoreMaxSpeed = 2.0;
const kScoreMaxTranspose = 12;
const kScoreMelodicChannelCount = 15;
const kScoreStaffCapacityWithChords = 14;

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
  ScorePerformancePlan? _performancePlan;
  ScorePerformancePlan? _loadedPerformancePlan;
  late Uint8List _midi;
  Uint8List? _activeSoundFont;
  Future<void> _audioReload = Future.value();
  ScoreAudioEngine? _engine;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false;
  bool _fullSoundFontRequested = false;

  @override
  ScoreReaderState build() {
    final selectedStaffIndices = {
      for (var index = 0; index < document.staves.length; index++) index,
    };
    final chordEnabled =
        document.chordSymbolCount > 0 &&
        selectedStaffIndices.length <= kScoreStaffCapacityWithChords;
    final chordSourceStaffIndex = _firstChordStaffIndex;
    final mix = [
      for (final staff in document.staves)
        StaffMix(program: staff.midiProgram ?? 0),
    ];
    const chordMix = ScoreChordMix();
    final plans = _plansForSelection(selectedStaffIndices, chordEnabled);
    _performancePlan = plans.playback;
    _map = ScorePlaybackMap.fromPlan(plans.map);
    _midi = plans.playback == null
        ? Uint8List(0)
        : _buildMidi(
            plans.playback!,
            mix: mix,
            chordEnabled: chordEnabled,
            chordSourceStaffIndex: chordSourceStaffIndex,
            chordMix: chordMix,
          );
    ref.onDispose(_dispose);
    unawaited(_startAudio());
    return ScoreReaderState(
      document: document,
      displayed: document.score,
      duration: _map.duration,
      mix: mix,
      selectedStaffIndices: Set.unmodifiable(selectedStaffIndices),
      chordMix: chordMix,
      chordAccompanimentEnabled: chordEnabled,
      chordSourceStaffIndex: chordSourceStaffIndex,
      audio: plans.playback != null
          ? ScoreAudioStatus.loading
          : plans.diagnostics.any((item) => item.blocksPlayback)
          ? ScoreAudioStatus.failed
          : ScoreAudioStatus.selectionRequired,
      diagnostics: plans.diagnostics,
    );
  }

  ScorePlaybackMap get playbackMap => _map;

  int? get _firstChordStaffIndex {
    for (final (index, part) in document.score.parts.indexed) {
      if (part.chordSymbols.isNotEmpty) return index;
    }
    return null;
  }

  bool _fitsCapacity(Set<int> selectedStaffIndices, bool chordEnabled) =>
      selectedStaffIndices.length <=
      (chordEnabled && document.chordSymbolCount > 0
          ? kScoreStaffCapacityWithChords
          : kScoreMelodicChannelCount);

  ScorePerformancePlan? _planFor(
    Set<int> selectedStaffIndices,
    bool chordEnabled,
  ) {
    if (!_fitsCapacity(selectedStaffIndices, chordEnabled)) return null;
    return ScorePerformancePlan.fromDocument(
      document,
      includeChordSymbols: chordEnabled,
      selectedStaffIndices: selectedStaffIndices,
    );
  }

  ScorePerformancePlan _mapOnlyPlan(bool chordEnabled) =>
      ScorePerformancePlan.fromDocument(
        document,
        includeChordSymbols: chordEnabled,
        selectedStaffIndices: const {},
      );

  ({
    ScorePerformancePlan? playback,
    ScorePerformancePlan map,
    List<ScorePlaybackDiagnostic> diagnostics,
  })
  _plansForSelection(Set<int> selectedStaffIndices, bool chordEnabled) {
    try {
      final playback = _planFor(selectedStaffIndices, chordEnabled);
      if (playback != null) {
        return (
          playback: playback,
          map: playback,
          diagnostics: playback.diagnostics,
        );
      }
    } on ScorePerformanceNavigationException catch (error) {
      final diagnostics = _navigationDiagnostics(error);
      return (
        playback: null,
        map: ScorePerformancePlan.unavailable(document),
        diagnostics: diagnostics,
      );
    }

    try {
      return (
        playback: null,
        map: _mapOnlyPlan(chordEnabled),
        diagnostics: const [],
      );
    } on ScorePerformanceNavigationException catch (error) {
      return (
        playback: null,
        map: ScorePerformancePlan.unavailable(document),
        diagnostics: _navigationDiagnostics(error),
      );
    }
  }

  List<ScorePlaybackDiagnostic> _navigationDiagnostics(
    ScorePerformanceNavigationException error,
  ) => [
    for (final issue in error.issues)
      ScorePlaybackDiagnostic(
        code: switch (issue.code) {
          ScorePerformanceNavigationIssueCode.invalidNavigation =>
            ScorePlaybackDiagnosticCode.invalidNavigation,
          ScorePerformanceNavigationIssueCode.conflictingNavigation =>
            ScorePlaybackDiagnosticCode.conflictingNavigation,
          ScorePerformanceNavigationIssueCode.unresolvedDestination =>
            ScorePlaybackDiagnosticCode.unresolvedNavigation,
          ScorePerformanceNavigationIssueCode.cyclicNavigation =>
            ScorePlaybackDiagnosticCode.cyclicNavigation,
          ScorePerformanceNavigationIssueCode.measureOccurrenceLimitExceeded =>
            ScorePlaybackDiagnosticCode.measureOccurrenceLimitExceeded,
        },
        staffIndex: issue.staffIndex,
        measureIndex: issue.measureIndex,
      ),
  ];

  Uint8List _buildMidi(
    ScorePerformancePlan plan, {
    required List<StaffMix> mix,
    required bool chordEnabled,
    required int? chordSourceStaffIndex,
    required ScoreChordMix chordMix,
    Map<int, int> programOverrides = const {},
  }) => buildScoreMidi(
    document,
    programOverrides: {..._programOverrides(mix), ...programOverrides},
    performancePlan: plan,
    includeChordAccompaniment: chordEnabled,
    chordSourceStaffIndex: chordSourceStaffIndex,
    chordProgram: chordMix.program,
  );

  Map<int, int> _programOverrides(List<StaffMix> mix) => {
    for (var index = 0; index < mix.length; index++)
      if (mix[index].program != (document.staves[index].midiProgram ?? 0))
        index: mix[index].program,
  };

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
        _activeSoundFont = font;
        final plan = _performancePlan;
        if (plan == null) {
          state = state.copyWith(
            audio: state.diagnostics.any((item) => item.blocksPlayback)
                ? ScoreAudioStatus.failed
                : ScoreAudioStatus.selectionRequired,
            soundFont: cached == null
                ? ScoreSoundFontStatus.minimal
                : ScoreSoundFontStatus.full,
          );
          return;
        }
        await _loadMidiIntoEngine(_midi, plan, font);
        if (_disposed) return;
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
      state = _withDiagnostic(
        const ScorePlaybackDiagnostic(
          code: ScorePlaybackDiagnosticCode.audioUnavailable,
        ),
        audio: ScoreAudioStatus.failed,
      );
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
        final plan = _performancePlan;
        if (plan != null) {
          await _loadMidiIntoEngine(_midi, plan, bytes);
        } else {
          _activeSoundFont = bytes;
        }
        if (_disposed) return;
        state = state.copyWith(
          soundFont: ScoreSoundFontStatus.full,
          soundFontProgress: () => null,
          diagnostics: _withoutDiagnostic(
            ScorePlaybackDiagnosticCode.soundFontUnavailable,
          ),
        );
      });
    } on Object catch (error) {
      debugPrint('[partitura] SoundFont completo indisponível: $error');
      if (_disposed) return;
      state = _withDiagnostic(
        const ScorePlaybackDiagnostic(
          code: ScorePlaybackDiagnosticCode.soundFontUnavailable,
        ),
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
    try {
      if (engine.isPlaying) {
        await engine.pause();
        return;
      }
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
    } on Object catch (error) {
      debugPrint('[partitura] falha ao controlar áudio: $error');
      if (_disposed) return;
      state = _withDiagnostic(
        const ScorePlaybackDiagnostic(
          code: ScorePlaybackDiagnosticCode.audioUnavailable,
        ),
        audio: ScoreAudioStatus.failed,
        playing: false,
      );
    }
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
    final value = volume.clamp(0, 1).toDouble();
    _updateMix(staff, state.mix[staff].copyWith(volume: value));
    final route = _performancePlan?.staffRoutes[staff];
    if (route != null) _engine?.setChannelVolume(route.midiChannel, value);
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
      _clearDiagnostic(
        ScorePlaybackDiagnosticCode.staffInstrumentUnavailable,
        staffIndex: staff,
      );
      return;
    }
    _updateMix(
      staff,
      mix.copyWith(programChanging: true, programFailed: false),
    );
    try {
      final plan = _performancePlan;
      if (plan == null) {
        _updateMix(
          staff,
          state.mix[staff].copyWith(program: program, programChanging: false),
        );
        _clearDiagnostic(
          ScorePlaybackDiagnosticCode.staffInstrumentUnavailable,
          staffIndex: staff,
        );
        return;
      }
      if (_activeSoundFont == null) {
        _midi = _buildMidi(
          plan,
          mix: state.mix,
          chordEnabled: state.chordAccompanimentEnabled,
          chordSourceStaffIndex: state.chordSourceStaffIndex,
          chordMix: state.chordMix,
          programOverrides: {staff: program},
        );
        _updateMix(
          staff,
          state.mix[staff].copyWith(program: program, programChanging: false),
        );
        _clearDiagnostic(
          ScorePlaybackDiagnosticCode.staffInstrumentUnavailable,
          staffIndex: staff,
        );
        return;
      }
      await _queueAudioReload(() async {
        final currentPlan = _performancePlan;
        final font = _activeSoundFont;
        if (currentPlan == null || font == null) {
          _updateMix(
            staff,
            state.mix[staff].copyWith(program: program, programChanging: false),
          );
          _clearDiagnostic(
            ScorePlaybackDiagnosticCode.staffInstrumentUnavailable,
            staffIndex: staff,
          );
          return;
        }
        final midi = _buildMidi(
          currentPlan,
          mix: state.mix,
          chordEnabled: state.chordAccompanimentEnabled,
          chordSourceStaffIndex: state.chordSourceStaffIndex,
          chordMix: state.chordMix,
          programOverrides: {staff: program},
        );
        await _loadMidiIntoEngine(midi, currentPlan, font);
        if (_disposed) return;
        _updateMix(
          staff,
          state.mix[staff].copyWith(program: program, programChanging: false),
        );
        _clearDiagnostic(
          ScorePlaybackDiagnosticCode.staffInstrumentUnavailable,
          staffIndex: staff,
        );
      });
    } on Object catch (error) {
      debugPrint('[partitura] troca de instrumento indisponível: $error');
      if (_disposed) return;
      _updateMix(
        staff,
        state.mix[staff].copyWith(programChanging: false, programFailed: true),
      );
      state = _withDiagnostic(
        ScorePlaybackDiagnostic(
          code: ScorePlaybackDiagnosticCode.staffInstrumentUnavailable,
          staffIndex: staff,
        ),
      );
    }
  }

  Future<void> setStaffSelected(int staff, bool selected) async {
    RangeError.checkValidIndex(staff, document.staves, 'staff');
    final selectedStaffIndices = {...state.selectedStaffIndices};
    if (selected) {
      selectedStaffIndices.add(staff);
    } else {
      selectedStaffIndices.remove(staff);
    }
    if (setEquals(selectedStaffIndices, state.selectedStaffIndices)) return;
    state = state.copyWith(
      selectedStaffIndices: Set.unmodifiable(selectedStaffIndices),
    );
    await _rebuildPerformance();
  }

  Future<void> setChordAccompanimentEnabled(bool enabled) async {
    if (document.chordSymbolCount == 0 ||
        enabled == state.chordAccompanimentEnabled) {
      return;
    }
    state = state.copyWith(chordAccompanimentEnabled: enabled);
    await _rebuildPerformance();
  }

  Future<void> setChordSource(int staff) async {
    RangeError.checkValidIndex(staff, document.staves, 'staff');
    if (document.score.parts[staff].chordSymbols.isEmpty) {
      throw ArgumentError.value(staff, 'staff', 'must contain chord symbols');
    }
    if (staff == state.chordSourceStaffIndex) return;
    state = state.copyWith(chordSourceStaffIndex: () => staff);
    if (state.chordAccompanimentEnabled && _performancePlan != null) {
      await _rebuildPerformance();
    }
  }

  void setChordVolume(double volume) {
    final value = volume.clamp(0, 1).toDouble();
    state = state.copyWith(chordMix: state.chordMix.copyWith(volume: value));
    final route = _performancePlan?.chordRoute;
    if (route != null) {
      _engine?.setChannelVolume(route.midiChannel, value);
    }
  }

  void toggleChordMute() {
    final muted = !state.chordMix.muted;
    state = state.copyWith(chordMix: state.chordMix.copyWith(muted: muted));
    final route = _performancePlan?.chordRoute;
    if (route != null) _engine?.setTrackMuted(route.trackIndex, muted);
  }

  void toggleChordSolo() {
    final solo = !state.chordMix.solo;
    state = state.copyWith(chordMix: state.chordMix.copyWith(solo: solo));
    final route = _performancePlan?.chordRoute;
    if (route != null) _engine?.setTrackSolo(route.trackIndex, solo);
  }

  Future<void> setChordProgram(int program) async {
    RangeError.checkValueInInterval(program, 0, 127, 'program');
    final mix = state.chordMix;
    if (mix.programChanging) return;
    if (program == mix.program) {
      if (mix.programFailed) {
        state = state.copyWith(chordMix: mix.copyWith(programFailed: false));
      }
      _clearDiagnostic(ScorePlaybackDiagnosticCode.chordInstrumentUnavailable);
      return;
    }
    state = state.copyWith(
      chordMix: mix.copyWith(programChanging: true, programFailed: false),
    );
    try {
      final plan = _performancePlan;
      if (plan == null || !state.chordAccompanimentEnabled) {
        state = state.copyWith(
          chordMix: state.chordMix.copyWith(
            program: program,
            programChanging: false,
          ),
        );
        _clearDiagnostic(
          ScorePlaybackDiagnosticCode.chordInstrumentUnavailable,
        );
        return;
      }
      if (_activeSoundFont == null) {
        _midi = _buildMidi(
          plan,
          mix: state.mix,
          chordEnabled: true,
          chordSourceStaffIndex: state.chordSourceStaffIndex,
          chordMix: state.chordMix.copyWith(program: program),
        );
        state = state.copyWith(
          chordMix: state.chordMix.copyWith(
            program: program,
            programChanging: false,
          ),
        );
        _clearDiagnostic(
          ScorePlaybackDiagnosticCode.chordInstrumentUnavailable,
        );
        return;
      }
      await _queueAudioReload(() async {
        final currentPlan = _performancePlan;
        final font = _activeSoundFont;
        if (currentPlan == null || font == null) {
          state = state.copyWith(
            chordMix: state.chordMix.copyWith(
              program: program,
              programChanging: false,
            ),
          );
          _clearDiagnostic(
            ScorePlaybackDiagnosticCode.chordInstrumentUnavailable,
          );
          return;
        }
        final midi = _buildMidi(
          currentPlan,
          mix: state.mix,
          chordEnabled: state.chordAccompanimentEnabled,
          chordSourceStaffIndex: state.chordSourceStaffIndex,
          chordMix: state.chordMix.copyWith(program: program),
        );
        await _loadMidiIntoEngine(midi, currentPlan, font);
        if (_disposed) return;
        state = state.copyWith(
          chordMix: state.chordMix.copyWith(
            program: program,
            programChanging: false,
          ),
        );
        _clearDiagnostic(
          ScorePlaybackDiagnosticCode.chordInstrumentUnavailable,
        );
      });
    } on Object catch (error) {
      debugPrint(
        '[partitura] troca do instrumento de cifras indisponível: $error',
      );
      if (_disposed) return;
      state = state.copyWith(
        chordMix: state.chordMix.copyWith(
          programChanging: false,
          programFailed: true,
        ),
      );
      state = _withDiagnostic(
        const ScorePlaybackDiagnostic(
          code: ScorePlaybackDiagnosticCode.chordInstrumentUnavailable,
        ),
      );
    }
  }

  Future<void> _rebuildPerformance() async {
    final selectedStaffIndices = state.selectedStaffIndices;
    final chordEnabled = state.chordAccompanimentEnabled;
    final plans = _plansForSelection(selectedStaffIndices, chordEnabled);
    final plan = plans.playback;
    _map = ScorePlaybackMap.fromPlan(plans.map);
    if (plan == null) {
      final engine = _engine;
      var pauseFailed = false;
      if (engine?.isPlaying ?? false) {
        try {
          await engine!.pause();
        } on Object catch (error) {
          debugPrint(
            '[partitura] falha ao pausar por limite de pautas: $error',
          );
          pauseFailed = true;
        }
      }
      _clearEngineMix(_loadedPerformancePlan);
      _loadedPerformancePlan = null;
      _performancePlan = null;
      _midi = Uint8List(0);
      if (!_disposed) {
        state = state.copyWith(
          audio:
              pauseFailed ||
                  plans.diagnostics.any((item) => item.blocksPlayback)
              ? ScoreAudioStatus.failed
              : ScoreAudioStatus.selectionRequired,
          playing: false,
          activeIds: const {},
          activeMeasure: () => null,
          diagnostics: [
            ...plans.diagnostics,
            if (pauseFailed)
              const ScorePlaybackDiagnostic(
                code: ScorePlaybackDiagnosticCode.audioUnavailable,
              ),
          ],
        );
      }
      return;
    }

    final midi = _buildMidi(
      plan,
      mix: state.mix,
      chordEnabled: chordEnabled,
      chordSourceStaffIndex: state.chordSourceStaffIndex,
      chordMix: state.chordMix,
    );
    _performancePlan = plan;
    _midi = midi;
    if (_activeSoundFont == null || _engine == null) {
      state = state.copyWith(
        audio: state.audio == ScoreAudioStatus.selectionRequired
            ? ScoreAudioStatus.loading
            : null,
        diagnostics: plans.diagnostics,
      );
      return;
    }
    state = state.copyWith(
      audio: ScoreAudioStatus.loading,
      diagnostics: plans.diagnostics,
    );
    try {
      await _queueAudioReload(() async {
        final currentPlan = _performancePlan;
        final font = _activeSoundFont;
        if (currentPlan == null || font == null) return;
        await _loadMidiIntoEngine(_midi, currentPlan, font);
        if (!_disposed) state = state.copyWith(audio: ScoreAudioStatus.ready);
      });
    } on Object catch (error) {
      debugPrint('[partitura] falha ao atualizar roteamento: $error');
      if (!_disposed) {
        state = _withDiagnostic(
          const ScorePlaybackDiagnostic(
            code: ScorePlaybackDiagnosticCode.audioUnavailable,
          ),
          audio: ScoreAudioStatus.failed,
        );
      }
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

  Future<void> _loadMidiIntoEngine(
    Uint8List midi,
    ScorePerformancePlan plan,
    Uint8List soundFont,
  ) async {
    final engine = _engine;
    if (engine == null) return;
    _clearEngineMix(_loadedPerformancePlan);
    await engine.load(midi: midi, soundFont: soundFont);
    if (_disposed) return;
    _midi = midi;
    _activeSoundFont = soundFont;
    _loadedPerformancePlan = plan;
    _applyEngineMix(plan);
  }

  void _clearEngineMix(ScorePerformancePlan? plan) {
    final engine = _engine;
    if (engine == null || plan == null) return;
    for (final route in plan.routes) {
      engine
        ..setTrackMuted(route.trackIndex, false)
        ..setTrackSolo(route.trackIndex, false)
        ..setChannelVolume(route.midiChannel, 1);
    }
  }

  void _applyEngineMix(ScorePerformancePlan plan) {
    final engine = _engine;
    if (engine == null) return;
    for (final route in plan.routes) {
      if (route.kind == ScorePerformanceRouteKind.staff) {
        final mix = state.mix[route.staffIndex!];
        engine
          ..setTrackMuted(route.trackIndex, mix.muted)
          ..setTrackSolo(route.trackIndex, mix.solo);
        if (mix.volume != 1) {
          engine.setChannelVolume(route.midiChannel, mix.volume);
        }
      } else {
        final mix = state.chordMix;
        engine
          ..setTrackMuted(route.trackIndex, mix.muted)
          ..setTrackSolo(route.trackIndex, mix.solo);
        if (mix.volume != 1) {
          engine.setChannelVolume(route.midiChannel, mix.volume);
        }
      }
    }
  }

  void toggleStaffMute(int staff) {
    final muted = !state.mix[staff].muted;
    _updateMix(staff, state.mix[staff].copyWith(muted: muted));
    final route = _performancePlan?.staffRoutes[staff];
    if (route != null) _engine?.setTrackMuted(route.trackIndex, muted);
  }

  void toggleStaffSolo(int staff) {
    final solo = !state.mix[staff].solo;
    _updateMix(staff, state.mix[staff].copyWith(solo: solo));
    final route = _performancePlan?.staffRoutes[staff];
    if (route != null) _engine?.setTrackSolo(route.trackIndex, solo);
  }

  void _updateMix(int staff, StaffMix mix) {
    state = state.copyWith(mix: [...state.mix]..[staff] = mix);
  }

  ScoreReaderState _withDiagnostic(
    ScorePlaybackDiagnostic diagnostic, {
    ScoreAudioStatus? audio,
    ScoreSoundFontStatus? soundFont,
    double? Function()? soundFontProgress,
    bool? playing,
  }) => state.copyWith(
    audio: audio,
    soundFont: soundFont,
    soundFontProgress: soundFontProgress,
    playing: playing,
    diagnostics: _diagnosticsWith(diagnostic),
  );

  List<ScorePlaybackDiagnostic> _diagnosticsWith(
    ScorePlaybackDiagnostic diagnostic,
  ) {
    if (state.diagnostics.any(
      (item) =>
          item.code == diagnostic.code &&
          item.staffIndex == diagnostic.staffIndex &&
          item.measureIndex == diagnostic.measureIndex &&
          item.articulation == diagnostic.articulation &&
          item.value == diagnostic.value &&
          item.signal == diagnostic.signal,
    )) {
      return state.diagnostics;
    }
    return [...state.diagnostics, diagnostic];
  }

  List<ScorePlaybackDiagnostic> _withoutDiagnostic(
    ScorePlaybackDiagnosticCode code, {
    int? staffIndex,
  }) => [
    for (final item in state.diagnostics)
      if (item.code != code ||
          (staffIndex != null && item.staffIndex != staffIndex))
        item,
  ];

  void _clearDiagnostic(ScorePlaybackDiagnosticCode code, {int? staffIndex}) {
    state = state.copyWith(
      diagnostics: _withoutDiagnostic(code, staffIndex: staffIndex),
    );
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
