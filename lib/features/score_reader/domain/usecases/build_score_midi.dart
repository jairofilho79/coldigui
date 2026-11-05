import 'dart:typed_data';

import 'package:crisp_notation_core/crisp_notation_core.dart';

import '../entities/score_document.dart';

const int kScoreMidiTicksPerQuarter = 480;

/// Canal MIDI de cada pauta: um canal por pauta, pulando o 9 (percussão GM).
/// A partir da 16ª pauta os canais se repetem; o mute/solo continua por faixa.
int midiChannelForStaff(int staffIndex) {
  final slot = staffIndex % 15;
  return slot >= 9 ? slot + 1 : slot;
}

/// SMF format 1 com uma faixa por pauta (faixa i = pauta i).
///
/// Cada faixa sai do `scoreToMidi` do crisp — que já cuida de ligaduras,
/// dinâmica, articulações e mudanças de tempo — e é remapeada para o canal da
/// pauta. Só a pauta 0 mantém os metas de tempo: é nela que MuseScore/MusicXML
/// gravam o andamento, e metas conflitantes das outras faixas fariam o player
/// saltar de tempo.
///
/// [programOverrides] troca só o programa GM (0–127) das pautas indicadas,
/// sem alterar a partitura original ou os eventos musicais.
Uint8List buildScoreMidi(
  ScoreDocument document, {
  Map<int, int> programOverrides = const {},
}) {
  for (final entry in programOverrides.entries) {
    RangeError.checkValidIndex(entry.key, document.staves, 'staff');
    RangeError.checkValueInInterval(entry.value, 0, 127, 'program');
  }
  final bpm = document.quarterBpm;
  final tracks = <List<int>>[];
  for (var i = 0; i < document.score.parts.length; i++) {
    final single = scoreToMidi(
      document.score.parts[i],
      quarterBpm: bpm,
      ticksPerQuarter: kScoreMidiTicksPerQuarter,
    );
    tracks.add(
      _rechannel(
        _firstTrackData(single),
        channel: midiChannelForStaff(i),
        program: programOverrides[i] ?? document.staves[i].midiProgram,
        keepTempo: i == 0,
      ),
    );
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
}) {
  final out = <int>[];
  var pendingDelta = 0;
  var offset = 0;

  if (program != null) {
    out.addAll([0x00, 0xC0 | channel, program.clamp(0, 127)]);
  }

  while (offset < data.length) {
    final (delta, afterDelta) = _readVarLen(data, offset);
    offset = afterDelta;
    pendingDelta += delta;
    final status = data[offset];

    if (status == 0xFF) {
      final type = data[offset + 1];
      final (length, afterLength) = _readVarLen(data, offset + 2);
      final end = afterLength + length;
      final isTempo = type == 0x51;
      if (!isTempo || keepTempo) {
        _writeVarLen(out, pendingDelta);
        pendingDelta = 0;
        out.addAll(data.sublist(offset, end));
      }
      offset = end;
      continue;
    }

    final kind = status & 0xF0;
    final dataLength = (kind == 0xC0 || kind == 0xD0) ? 1 : 2;
    final end = offset + 1 + dataLength;
    // O programa da pauta já foi emitido no início da faixa.
    if (kind != 0xC0) {
      _writeVarLen(out, pendingDelta);
      pendingDelta = 0;
      out
        ..add(kind | channel)
        ..addAll(data.sublist(offset + 1, end));
    }
    offset = end;
  }
  return out;
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
