import 'dart:typed_data';

import 'package:soundfont_kit/soundfont_kit.dart';

/// Adapta os metadados SF3 de soundfont_kit 1.1.1, sem tocar no Ogg.
///
/// O parser subtrai o início comprimido dos loops PCM (que já são relativos
/// no SF3). SF2 usa índices PCM absolutos e não precisa desta adaptação.
Future<SoundFontFile> parseScoreSoundFont(Uint8List bytes) async {
  final file = await SoundFontFile.fromBytes(bytes);
  if (file.format != SoundFontFormat.sf3) return file;
  return _PcmLoopSoundFont(file, _sampleDataOffset(bytes));
}

class _PcmLoopSoundFont extends SoundFontFile {
  final SoundFontFile _source;

  @override
  late final List<SampleInfo> samples;
  @override
  late final List<Instrument> instruments;
  @override
  late final List<Preset> presets;

  _PcmLoopSoundFont(this._source, int dataOffset) {
    samples = List.unmodifiable([
      for (final sample in _source.samples)
        if (sample.compression != SampleCompression.ogg)
          sample
        else
          SampleInfo(
            id: sample.id,
            name: sample.name,
            sampleRate: sample.sampleRate,
            originalPitch: sample.originalPitch,
            pitchCorrection: sample.pitchCorrection,
            loopStart: sample.loopStart + sample.byteOffset - dataOffset,
            loopEnd: sample.loopEnd + sample.byteOffset - dataOffset,
            sampleCount: sample.sampleCount,
            byteOffset: sample.byteOffset,
            byteLength: sample.byteLength,
            compression: sample.compression,
            samplePath: sample.samplePath,
            channels: sample.channels,
            sampleType: sample.sampleType,
            sampleLink: sample.sampleLink,
          ),
    ]);
    final byId = {for (final sample in samples) sample.id: sample};
    Zone adaptZone(Zone zone) {
      final sample = zone.sampleRef;
      if (sample == null) return zone;
      return Zone(
        keyRangeMin: zone.keyRangeMin,
        keyRangeMax: zone.keyRangeMax,
        velRangeMin: zone.velRangeMin,
        velRangeMax: zone.velRangeMax,
        rootKey: zone.rootKey,
        pitchCorrection: zone.pitchCorrection,
        attenuation: zone.attenuation,
        pan: zone.pan,
        sampleID: zone.sampleID,
        sampleRef: byId[sample.id] ?? sample,
        instrumentID: zone.instrumentID,
        loopMode: zone.loopMode,
        loopStart: zone.loopStart,
        loopEnd: zone.loopEnd,
        volEnvAttack: zone.volEnvAttack,
        volEnvHold: zone.volEnvHold,
        volEnvDecay: zone.volEnvDecay,
        volEnvSustain: zone.volEnvSustain,
        volEnvRelease: zone.volEnvRelease,
        modEnvAttack: zone.modEnvAttack,
        modEnvHold: zone.modEnvHold,
        modEnvDecay: zone.modEnvDecay,
        modEnvSustain: zone.modEnvSustain,
        modEnvRelease: zone.modEnvRelease,
        initialFilterCutoff: zone.initialFilterCutoff,
        initialFilterQ: zone.initialFilterQ,
        generators: zone.generators,
        modulators: zone.modulators,
        opcodes: zone.opcodes,
      );
    }

    instruments = List.unmodifiable([
      for (final instrument in _source.instruments)
        Instrument(
          id: instrument.id,
          name: instrument.name,
          zones: instrument.zones.map(adaptZone).toList(growable: false),
        ),
    ]);
    presets = List.unmodifiable([
      for (final preset in _source.presets)
        Preset(
          bank: preset.bank,
          program: preset.program,
          name: preset.name,
          zones: preset.zones.map(adaptZone).toList(growable: false),
          library: preset.library,
          genre: preset.genre,
          morphology: preset.morphology,
        ),
    ]);
  }

  @override
  SoundFontFormat get format => _source.format;
  @override
  String? get name => _source.name;
  @override
  String? get comment => _source.comment;
  @override
  Future<Uint8List> getSampleBytes(SampleInfo sample) =>
      _source.getSampleBytes(sample);
  @override
  Stream<Uint8List> getSampleByteStream(
    SampleInfo sample, {
    int chunkSize = 16384,
  }) => _source.getSampleByteStream(sample, chunkSize: chunkSize);
}

int _sampleDataOffset(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  Iterable<({String id, int start, int end})> chunks(int start, int end) sync* {
    for (var at = start; at + 8 <= end;) {
      final size = data.getUint32(at + 4, Endian.little);
      final next = at + 8 + size;
      if (next > end) throw const FormatException('Truncated SF3 RIFF chunk');
      yield (id: tag(at), start: at + 8, end: next);
      at = next + (size & 1);
    }
  }

  for (final chunk in chunks(12, bytes.length)) {
    if (chunk.id != 'LIST' || chunk.end - chunk.start < 4) continue;
    if (tag(chunk.start) != 'sdta') continue;
    for (final sample in chunks(chunk.start + 4, chunk.end)) {
      if (sample.id == 'smpl' || sample.id == 's3mp') return sample.start;
    }
  }
  throw const FormatException('Missing SF3 sample data');
}
