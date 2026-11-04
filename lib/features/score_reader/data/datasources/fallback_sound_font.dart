import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// SoundFont 2 mínimo gerado em memória (~9 KB): um preset (banco 0,
/// programa 0) com um tom aditivo suave em loop.
///
/// É o instrumento sempre disponível — sem download e sem licença de
/// terceiros — para que o play soe de imediato enquanto o SoundFont completo
/// não chega (ou quando não há rede).
Uint8List buildFallbackSoundFont({int sampleRate = 44100}) {
  // 441 Hz tem período exato de 100 amostras a 44,1 kHz: o loop sobre ciclos
  // inteiros não estala. Nota raiz 69 (Lá 440 Hz) com correção de -4 cents.
  const period = 100;
  const cycles = 44;
  const length = period * cycles;
  final pcm = ByteData((length + 46) * 2);
  const harmonics = [1.0, 0.45, 0.2, 0.08];
  final norm = harmonics.reduce((a, b) => a + b);
  for (var i = 0; i < length; i++) {
    var v = 0.0;
    for (var h = 0; h < harmonics.length; h++) {
      v += harmonics[h] * math.sin(2 * math.pi * (h + 1) * i / period);
    }
    pcm.setInt16(i * 2, (v / norm * 0.8 * 32767).round(), Endian.little);
  }

  Uint8List name(String s, int size) {
    final out = Uint8List(size);
    final bytes = ascii.encode(s);
    out.setRange(0, math.min(bytes.length, size - 1), bytes);
    return out;
  }

  final phdr = BytesBuilder()
    ..add(name('Coldigui Tone', 20))
    ..add(_u16(0)) // preset
    ..add(_u16(0)) // banco
    ..add(_u16(0)) // bag index
    ..add(_u32(0))
    ..add(_u32(0))
    ..add(_u32(0))
    ..add(name('EOP', 20))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(1))
    ..add(_u32(0))
    ..add(_u32(0))
    ..add(_u32(0));
  final pbag = BytesBuilder()
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(1))
    ..add(_u16(0));
  final pmod = Uint8List(10);
  final pgen = BytesBuilder()
    ..add(_u16(41)) // instrumento
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(0));
  final inst = BytesBuilder()
    ..add(name('Tone', 20))
    ..add(_u16(0))
    ..add(name('EOI', 20))
    ..add(_u16(1));
  final igens = <(int, int)>[
    (34, _timecents(0.005)), // ataque
    (36, _timecents(1.8)), // decaimento
    (37, 120), // sustentação: 12 dB abaixo do pico
    (38, _timecents(0.25)), // release
    (54, 1), // loop contínuo
    (53, 0), // sampleID (precisa ser o último)
  ];
  final ibag = BytesBuilder()
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(igens.length))
    ..add(_u16(0));
  final imod = Uint8List(10);
  final igen = BytesBuilder();
  for (final (op, amount) in [...igens, (0, 0)]) {
    igen
      ..add(_u16(op))
      ..add(_u16(amount & 0xFFFF));
  }
  final shdr = BytesBuilder()
    ..add(name('Tone', 20))
    ..add(_u32(0))
    ..add(_u32(length))
    ..add(_u32(0))
    ..add(_u32(length))
    ..add(_u32(sampleRate))
    ..add([69, (-4) & 0xFF])
    ..add(_u16(0))
    ..add(_u16(1)) // mono
    ..add(name('EOS', 20))
    ..add(Uint8List(26));

  final info = _list('INFO', [
    _chunk('ifil', [..._u16(2), ..._u16(1)]),
    _chunk('isng', name('EMU8000', 8)),
    _chunk('INAM', name('Coldigui Tone', 14)),
  ]);
  final sdta = _list('sdta', [_chunk('smpl', pcm.buffer.asUint8List())]);
  final pdta = _list('pdta', [
    _chunk('phdr', phdr.toBytes()),
    _chunk('pbag', pbag.toBytes()),
    _chunk('pmod', pmod),
    _chunk('pgen', pgen.toBytes()),
    _chunk('inst', inst.toBytes()),
    _chunk('ibag', ibag.toBytes()),
    _chunk('imod', imod),
    _chunk('igen', igen.toBytes()),
    _chunk('shdr', shdr.toBytes()),
  ]);
  final body = [...ascii.encode('sfbk'), ...info, ...sdta, ...pdta];
  return Uint8List.fromList(_chunk('RIFF', body));
}

int _timecents(double seconds) => (1200 * math.log(seconds) / math.ln2).round();

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

List<int> _u32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];

List<int> _chunk(String id, List<int> data) => [
  ...ascii.encode(id),
  ..._u32(data.length),
  ...data,
  if (data.length.isOdd) 0,
];

List<int> _list(String type, List<List<int>> chunks) =>
    _chunk('LIST', [...ascii.encode(type), for (final c in chunks) ...c]);
