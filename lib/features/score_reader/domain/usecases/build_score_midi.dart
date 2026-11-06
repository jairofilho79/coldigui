import 'dart:typed_data';
import 'dart:math' show max;

import 'package:crisp_notation_core/crisp_notation_core.dart';

import '../entities/score_document.dart';
import 'score_performance_plan.dart';

const int kScoreMidiTicksPerQuarter = 480;
const int _scoreExpressionStepTicks = kScoreMidiTicksPerQuarter ~/ 4;

/// Canal MIDI de cada pauta: um canal por pauta, pulando o 9 (percussão GM).
/// A partir da 16ª pauta os canais se repetem; o mute/solo continua por faixa.
int midiChannelForStaff(int staffIndex) => scoreMidiChannelForStaff(staffIndex);

/// SMF format 1 com uma faixa por pauta (faixa i = pauta i).
///
/// Cada pauta usa o score linearizado do plano; a serializacao base do crisp
/// recebe as duracoes, curvas de expressao e controles de pedal do mesmo plano
/// antes de ser remapeada para o canal da pauta. So a pauta 0 mantem os metas
/// de tempo: e nela que MuseScore/MusicXML gravam o andamento, e metas
/// conflitantes das outras faixas fariam o player saltar de tempo.
///
/// [programOverrides] troca só o programa GM (0–127) das pautas indicadas,
/// sem alterar a partitura original ou os eventos musicais.
///
/// [includeChordAccompaniment] adiciona uma faixa separada usando as cifras do
/// plano. Sem um [performancePlan] explícito, o plano é criado com cifras;
/// planos fornecidos pelo chamador devem usar `includeChordSymbols: true`.
Uint8List buildScoreMidi(
  ScoreDocument document, {
  Map<int, int> programOverrides = const {},
  ScorePerformancePlan? performancePlan,
  bool includeChordAccompaniment = false,
  int? chordSourceStaffIndex,
  int chordProgram = 0,
}) {
  for (final entry in programOverrides.entries) {
    RangeError.checkValidIndex(entry.key, document.staves, 'staff');
    RangeError.checkValueInInterval(entry.value, 0, 127, 'program');
  }
  RangeError.checkValueInInterval(chordProgram, 0, 127, 'chordProgram');
  final plan =
      performancePlan ??
      ScorePerformancePlan.fromDocument(
        document,
        includeChordSymbols: includeChordAccompaniment,
      );
  if (!identical(plan.score, document.score)) {
    throw ArgumentError.value(
      performancePlan,
      'performancePlan',
      'must be built from document.score',
    );
  }
  if (includeChordAccompaniment &&
      document.chordSymbolCount > 0 &&
      (!plan.includeChordSymbols || plan.chordRoute == null)) {
    throw ArgumentError.value(
      performancePlan,
      'performancePlan',
      'must include chord symbols when accompaniment is enabled',
    );
  }
  final staffRoutes = plan.routes
      .where((route) => route.kind == ScorePerformanceRouteKind.staff)
      .toList();
  final selectedStaffOrder = plan.selectedStaffIndices.toList()..sort();
  if (staffRoutes.length != selectedStaffOrder.length ||
      staffRoutes.indexed.any(
        (entry) =>
            entry.$2.staffIndex != selectedStaffOrder[entry.$1] ||
            entry.$2.trackIndex != entry.$1,
      )) {
    throw ArgumentError.value(
      plan,
      'performancePlan',
      'must route every selected staff in score order',
    );
  }
  final bpm = document.quarterBpm;
  final tracks = <List<int>>[];
  for (final route in staffRoutes) {
    final i = route.staffIndex!;
    final single = scoreToMidi(
      plan.linearizedScoreForStaff(i),
      quarterBpm: bpm,
      ticksPerQuarter: kScoreMidiTicksPerQuarter,
    );
    tracks.add(
      _rechannel(
        _firstTrackData(single),
        channel: route.midiChannel,
        program: programOverrides[i] ?? document.staves[i].midiProgram,
        keepTempo: route.trackIndex == 0,
        minimumEndTick: _fractionToTicks(plan.totalWholeNotes),
        noteSchedules: _staffNoteSchedules(plan, i),
        remapSourceTime: plan.playbackTimeForSource,
        expressionCurves: _expressionCurvesForRoute(plan, route),
        controlChanges: _staffControlChanges(plan, i),
      ),
    );
  }

  if (includeChordAccompaniment && plan.chordRoute != null) {
    final sourceStaffIndex =
        chordSourceStaffIndex ?? _firstChordStaffIndex(document);
    if (sourceStaffIndex != null &&
        (sourceStaffIndex < 0 ||
            sourceStaffIndex >= document.score.parts.length ||
            document.score.parts[sourceStaffIndex].chordSymbols.isEmpty)) {
      throw RangeError.value(
        sourceStaffIndex,
        'chordSourceStaffIndex',
        'must identify a staff containing chord symbols',
      );
    }
    if (sourceStaffIndex != null) {
      final chordEvents = plan.events.where(
        (event) =>
            event.route?.kind == ScorePerformanceRouteKind.accompaniment &&
            event.origin.staffIndex == sourceStaffIndex &&
            event.chordPitches != null,
      );
      tracks.add(
        _chordTrackData(
          chordEvents,
          channel: plan.chordRoute!.midiChannel,
          program: chordProgram,
          minimumEndTick: _fractionToTicks(plan.totalWholeNotes),
          expressionCurves: _expressionCurvesForRoute(plan, plan.chordRoute!),
        ),
      );
    }
  }

  final out = BytesBuilder(copy: false)
    ..add(const [0x4D, 0x54, 0x68, 0x64])
    ..add(_u32(6))
    ..add(_u16(1))
    ..add(_u16(tracks.length))
    ..add(_u16(kScoreMidiTicksPerQuarter));
  for (final track in tracks) {
    out
      ..add(const [0x4D, 0x54, 0x72, 0x6B])
      ..add(_u32(track.length))
      ..add(track);
  }
  return out.takeBytes();
}

int? _firstChordStaffIndex(ScoreDocument document) {
  for (final (index, part) in document.score.parts.indexed) {
    if (part.chordSymbols.isNotEmpty) return index;
  }
  return null;
}

List<int> _chordTrackData(
  Iterable<ScorePerformanceEvent> events, {
  required int channel,
  required int program,
  required int minimumEndTick,
  required List<ScorePerformanceExpressionCurve> expressionCurves,
}) {
  final messages =
      <
        ({int tick, int order, int sequence, int status, int data1, int data2})
      >[];
  var sequence = 0;
  for (final event in events) {
    final pitches = event.chordPitches;
    if (pitches == null) continue;
    final start = _fractionToTicks(event.start);
    final end = _fractionToTicks(event.end);
    if (end <= start) continue;
    for (final pitch in pitches) {
      messages
        ..add((
          tick: end,
          order: 1,
          sequence: sequence++,
          status: 0x80 | channel,
          data1: pitch.midiNumber.clamp(0, 127),
          data2: 0x40,
        ))
        ..add((
          tick: start,
          order: 2,
          sequence: sequence++,
          status: 0x90 | channel,
          data1: pitch.midiNumber.clamp(0, 127),
          data2: event.velocity ?? 80,
        ));
    }
  }
  for (final curve in expressionCurves) {
    for (final (tick, value) in _sampleExpressionCurve(curve)) {
      messages.add((
        tick: tick,
        order: 0,
        sequence: sequence++,
        status: 0xb0 | channel,
        data1: 11,
        data2: value,
      ));
    }
  }
  messages.sort((a, b) {
    final byTick = a.tick.compareTo(b.tick);
    if (byTick != 0) return byTick;
    final byOrder = a.order.compareTo(b.order);
    return byOrder != 0 ? byOrder : a.sequence.compareTo(b.sequence);
  });

  final out = <int>[0x00, 0xC0 | channel, program.clamp(0, 127)];
  var absoluteTick = 0;
  for (final message in messages) {
    _writeVarLen(out, message.tick - absoluteTick);
    absoluteTick = message.tick;
    out
      ..add(message.status)
      ..add(message.data1)
      ..add(message.data2);
  }
  final endTick = absoluteTick < minimumEndTick ? minimumEndTick : absoluteTick;
  _writeVarLen(out, endTick - absoluteTick);
  out.addAll(const [0xFF, 0x2F, 0x00]);
  return out;
}

List<ScorePerformanceExpressionCurve> _expressionCurvesForRoute(
  ScorePerformancePlan plan,
  ScorePerformanceRoute route,
) => [
  for (final curve in plan.expressionCurves)
    if (curve.route.trackIndex == route.trackIndex &&
        curve.route.midiChannel == route.midiChannel &&
        curve.route.kind == route.kind)
      curve,
];

class _ScheduledNote {
  const _ScheduledNote({
    required this.sourceStartTick,
    required this.sourceOffTick,
    required this.voice,
    required this.pitch,
    required this.startTick,
    required this.endTick,
    required this.attack,
    required this.velocity,
    required this.sourceDriven,
  });

  final int sourceStartTick;
  final int sourceOffTick;
  final int voice;
  final int pitch;
  final int startTick;
  final int endTick;
  final bool attack;
  final int velocity;
  final bool sourceDriven;
}

List<_ScheduledNote> _staffNoteSchedules(
  ScorePerformancePlan plan,
  int staffIndex,
) => [
  for (final event in plan.events)
    if (event.origin.staffIndex == staffIndex &&
        !event.isRest &&
        event.chordPitches == null)
      for (final pitchDuration in event.pitchDurations)
        _ScheduledNote(
          sourceStartTick: _fractionToTicks(event.sourceStart),
          sourceOffTick:
              _fractionToTicks(event.sourceStart) +
              max(
                1,
                event.articulations.contains(Articulation.staccato)
                    ? (_fractionToTicks(event.sourceDuration) * 0.5).round()
                    : _fractionToTicks(event.sourceDuration),
              ),
          voice: event.origin.voice.clamp(0, 15),
          pitch: pitchDuration.pitch.midiNumber.clamp(0, 127),
          startTick: _fractionToTicks(event.start + pitchDuration.startOffset),
          endTick:
              _fractionToTicks(event.start + pitchDuration.startOffset) +
              max(1, _fractionToTicks(pitchDuration.duration)),
          attack: pitchDuration.attack,
          velocity: event.velocity ?? 80,
          sourceDriven: pitchDuration.sourceDriven,
        ),
];

List<ScorePerformanceControlChange> _staffControlChanges(
  ScorePerformancePlan plan,
  int staffIndex,
) => [
  for (final change in plan.controlChanges)
    if (change.origin.staffIndex == staffIndex) change,
];

List<(int, int)> _sampleExpressionCurve(ScorePerformanceExpressionCurve curve) {
  final startTick = _fractionToTicks(curve.start);
  final endTick = _fractionToTicks(curve.end);
  final duration = endTick - startTick;
  if (duration <= 0) return const [];
  final values = <(int, int)>[];
  for (
    var tick = startTick;
    tick < endTick;
    tick += _scoreExpressionStepTicks
  ) {
    values.add((tick, _interpolateExpression(curve, startTick, endTick, tick)));
  }
  values.add((endTick, curve.endValue));
  return values;
}

int _interpolateExpression(
  ScorePerformanceExpressionCurve curve,
  int startTick,
  int endTick,
  int tick,
) {
  final duration = endTick - startTick;
  final elapsed = tick - startTick;
  final difference = (curve.endValue - curve.startValue).abs();
  final amount = (difference * elapsed + duration ~/ 2) ~/ duration;
  return curve.endValue >= curve.startValue
      ? curve.startValue + amount
      : curve.startValue - amount;
}

Uint8List _firstTrackData(Uint8List smf) {
  var offset = 14;
  while (offset + 8 <= smf.length) {
    final length = _readU32(smf, offset + 4);
    final isTrack =
        smf[offset] == 0x4D &&
        smf[offset + 1] == 0x54 &&
        smf[offset + 2] == 0x72 &&
        smf[offset + 3] == 0x6B;
    if (isTrack) {
      return Uint8List.sublistView(smf, offset + 8, offset + 8 + length);
    }
    offset += 8 + length;
  }
  throw const FormatException('MIDI sem faixa');
}

/// Reescreve uma faixa sem running status (o formato que `scoreToMidi` emite).
List<int> _rechannel(
  Uint8List data, {
  required int channel,
  required int? program,
  required bool keepTempo,
  required int minimumEndTick,
  required List<_ScheduledNote> noteSchedules,
  required Fraction Function(Fraction) remapSourceTime,
  required List<ScorePerformanceExpressionCurve> expressionCurves,
  required List<ScorePerformanceControlChange> controlChanges,
}) {
  final events = <({int tick, int order, int sequence, List<int> bytes})>[];
  final schedulesByOnset = <(int, int, int), List<_ScheduledNote>>{};
  final schedulesByOffset = <(int, int, int), List<_ScheduledNote>>{};
  for (final schedule in noteSchedules) {
    if (!schedule.sourceDriven) continue;
    schedulesByOnset
        .putIfAbsent((
          schedule.sourceStartTick,
          schedule.voice,
          schedule.pitch,
        ), () => [])
        .add(schedule);
  }
  var sequence = 0;
  var absoluteTick = 0;
  var endTick = 0;
  var offset = 0;
  int remapTick(int sourceTick) => _fractionToTicks(
    remapSourceTime(Fraction(sourceTick, 4 * kScoreMidiTicksPerQuarter)),
  );

  if (program != null) {
    events.add((
      tick: 0,
      order: 0,
      sequence: sequence++,
      bytes: [0xC0 | channel, program.clamp(0, 127)],
    ));
  }

  for (final schedule in noteSchedules) {
    if (schedule.sourceDriven) continue;
    events.add((
      tick: schedule.startTick,
      order: 2,
      sequence: sequence++,
      bytes: [0x90 | channel, schedule.pitch, schedule.velocity],
    ));
  }

  while (offset < data.length) {
    final (delta, afterDelta) = _readVarLen(data, offset);
    offset = afterDelta;
    absoluteTick += delta;
    final status = data[offset];

    if (status == 0xFF) {
      final type = data[offset + 1];
      final (length, afterLength) = _readVarLen(data, offset + 2);
      final end = afterLength + length;
      final mappedTick = remapTick(absoluteTick);
      if (type == 0x2F) {
        endTick = mappedTick;
      } else if (type != 0x51 || keepTempo) {
        events.add((
          tick: mappedTick,
          order: 0,
          sequence: sequence++,
          bytes: data.sublist(offset, end),
        ));
      }
      offset = end;
      continue;
    }

    final kind = status & 0xF0;
    final dataLength = (kind == 0xC0 || kind == 0xD0) ? 1 : 2;
    final end = offset + 1 + dataLength;
    if (kind != 0xC0) {
      final message = data.sublist(offset + 1, end);
      final voice = status & 0x0F;
      final pitch = message[0];
      if (kind == 0x90 && message[1] > 0) {
        final key = (absoluteTick, voice, pitch);
        final schedules = schedulesByOnset[key];
        if (schedules != null && schedules.isNotEmpty) {
          final schedule = schedules.removeAt(0);
          schedulesByOffset
              .putIfAbsent((
                schedule.sourceOffTick,
                schedule.voice,
                schedule.pitch,
              ), () => [])
              .add(schedule);
          if (schedule.attack) {
            events.add((
              tick: schedule.startTick,
              order: 2,
              sequence: sequence++,
              bytes: [0x90 | channel, schedule.pitch, schedule.velocity],
            ));
          }
          offset = end;
          continue;
        }
      }
      if (kind == 0x80 || (kind == 0x90 && message[1] == 0)) {
        final scheduled = schedulesByOffset[(absoluteTick, voice, pitch)];
        if (scheduled != null && scheduled.isNotEmpty) {
          scheduled.removeAt(0);
          offset = end;
          continue;
        }
      }
      events.add((
        tick: remapTick(absoluteTick),
        order: kind == 0x80
            ? 1
            : kind == 0x90
            ? 2
            : 0,
        sequence: sequence++,
        bytes: [kind | channel, ...message],
      ));
    }
    offset = end;
  }

  for (final (tick, pitch) in _mergedNoteOffs(noteSchedules)) {
    events.add((
      tick: tick,
      order: 1,
      sequence: sequence++,
      bytes: [0x80 | channel, pitch, 0x40],
    ));
  }

  for (final change in controlChanges) {
    events.add((
      tick: _fractionToTicks(change.start),
      order: 0,
      sequence: sequence++,
      bytes: [0xB0 | channel, change.controller, change.value],
    ));
  }

  for (final curve in expressionCurves) {
    for (final (tick, value) in _sampleExpressionCurve(curve)) {
      events.add((
        tick: tick,
        order: 0,
        sequence: sequence++,
        bytes: [0xB0 | channel, 11, value],
      ));
    }
  }
  endTick = [
    endTick,
    minimumEndTick,
    for (final event in events) event.tick,
  ].reduce((a, b) => a > b ? a : b);
  events
    ..add((
      tick: endTick,
      order: 3,
      sequence: sequence,
      bytes: const [0xFF, 0x2F, 0x00],
    ))
    ..sort((a, b) {
      final byTick = a.tick.compareTo(b.tick);
      if (byTick != 0) return byTick;
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.sequence.compareTo(b.sequence);
    });

  final out = <int>[];
  var previousTick = 0;
  for (final event in events) {
    _writeVarLen(out, event.tick - previousTick);
    previousTick = event.tick;
    out.addAll(event.bytes);
  }
  return out;
}

List<(int, int)> _mergedNoteOffs(List<_ScheduledNote> schedules) {
  final byPitch = <int, List<_ScheduledNote>>{};
  for (final schedule in schedules) {
    if (schedule.attack) {
      byPitch.putIfAbsent(schedule.pitch, () => []).add(schedule);
    }
  }

  final releases = <(int, int)>[];
  for (final entry in byPitch.entries) {
    final notes = entry.value
      ..sort((a, b) {
        final byStart = a.startTick.compareTo(b.startTick);
        return byStart != 0 ? byStart : a.endTick.compareTo(b.endTick);
      });
    int? overlapEnd;
    for (final note in notes) {
      if (overlapEnd != null && note.startTick < overlapEnd) {
        if (note.endTick > overlapEnd) overlapEnd = note.endTick;
      } else {
        if (overlapEnd != null) releases.add((overlapEnd, entry.key));
        overlapEnd = note.endTick;
      }
    }
    if (overlapEnd != null) releases.add((overlapEnd, entry.key));
  }
  return releases;
}

int _fractionToTicks(Fraction time) {
  final numerator = time.numerator * 4 * kScoreMidiTicksPerQuarter;
  return (numerator + time.denominator ~/ 2) ~/ time.denominator;
}

(int, int) _readVarLen(Uint8List data, int offset) {
  var value = 0;
  var i = offset;
  while (true) {
    final byte = data[i++];
    value = (value << 7) | (byte & 0x7F);
    if (byte & 0x80 == 0) break;
  }
  return (value, i);
}

void _writeVarLen(List<int> out, int value) {
  var v = value < 0 ? 0 : value;
  final buffer = <int>[v & 0x7F];
  v >>= 7;
  while (v > 0) {
    buffer.add((v & 0x7F) | 0x80);
    v >>= 7;
  }
  out.addAll(buffer.reversed);
}

int _readU32(Uint8List data, int offset) =>
    (data[offset] << 24) |
    (data[offset + 1] << 16) |
    (data[offset + 2] << 8) |
    data[offset + 3];

List<int> _u32(int value) => [
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

List<int> _u16(int value) => [(value >> 8) & 0xFF, value & 0xFF];
