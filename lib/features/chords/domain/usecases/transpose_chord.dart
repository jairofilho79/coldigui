/// Transposição de acordes ChordPro por semitons.
///
/// Move raiz e baixo invertido preservando o sufixo de qualidade. O corpus tem
/// 36 sufixos distintos (`m`, `7`, `m7`, `ø`, `7M`, `sus4`, `m(b13)`…) e
/// nenhum deles carrega altura — só a raiz e o que vem depois de `/` mudam.
library;

/// Grafia com sustenidos, indexada por classe de altura.
const _sharpNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

/// Grafia com bemóis, indexada por classe de altura.
const _flatNames = [
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

/// Classes de altura cujo tom usual se escreve com bemóis.
///
/// Db, Eb, F, Ab e Bb — F entra porque Fá maior tem um bemol na armadura.
const _flatKeyPitches = {1, 3, 5, 8, 10};

final _rootRe = RegExp(r'^([A-G])([#b]?)');

/// Classe de altura de [note] (`C`, `F#`, `Bb`), ou `null` se não for nota.
int? _pitchOf(String note) {
  final match = _rootRe.firstMatch(note);
  if (match == null || match.end != note.length) return null;

  const naturals = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  var pitch = naturals[match.group(1)]!;
  final accidental = match.group(2)!;
  if (accidental == '#') pitch += 1;
  if (accidental == 'b') pitch -= 1;
  return (pitch % 12 + 12) % 12;
}

String _spell(int pitch, {required bool preferFlats}) {
  final normalized = (pitch % 12 + 12) % 12;
  return preferFlats ? _flatNames[normalized] : _sharpNames[normalized];
}

/// Transpõe [label] em [semitones], preservando o sufixo de qualidade.
///
/// Devolve [label] intacto quando não é um acorde: marcadores do corpus que
/// começam com `*` (`[*2x]`, `[*Coro]`), rótulos vazios e qualquer coisa cuja
/// raiz não seja `A`–`G`. Melhor deixar passar do que corromper.
String transposeChordLabel(
  String label,
  int semitones, {
  required bool preferFlats,
}) {
  if (semitones == 0) return label;
  if (label.isEmpty || label.startsWith('*')) return label;

  final rootMatch = _rootRe.firstMatch(label);
  if (rootMatch == null) return label;

  final rootPitch = _pitchOf(label.substring(0, rootMatch.end));
  if (rootPitch == null) return label;

  final root = _spell(rootPitch + semitones, preferFlats: preferFlats);
  final suffix = label.substring(rootMatch.end);

  final slash = suffix.indexOf('/');
  if (slash == -1) return '$root$suffix';

  // Baixo invertido: transpõe só se o que vem depois da barra for uma nota.
  final quality = suffix.substring(0, slash);
  final bass = suffix.substring(slash + 1);
  final bassPitch = _pitchOf(bass);
  if (bassPitch == null) return '$root$suffix';

  final newBass = _spell(bassPitch + semitones, preferFlats: preferFlats);
  return '$root$quality/$newBass';
}

/// `true` quando o tom resultante de transpor [key] em [semitones] se escreve
/// com bemóis.
///
/// Evita enarmonias que o músico não espera: Sol subindo um vira Láb (quatro
/// bemóis), não Sol# (oito sustenidos); Sol descendo um vira Fá#, não Solb.
/// Tom ausente ou irreconhecível cai em bemóis, convenção do hinário.
bool preferFlatsForKey(String key, int semitones) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return true;

  final tonic = trimmed.endsWith('m')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  final pitch = _pitchOf(tonic);
  if (pitch == null) return true;

  // Dart devolve resto negativo para operando negativo — normaliza antes.
  final target = ((pitch + semitones) % 12 + 12) % 12;
  return _flatKeyPitches.contains(target);
}

/// Transpõe o rótulo de tom do cabeçalho (`G`, `Dm`, `Eb`), mantendo o `m`.
String transposeKeyLabel(String key, int semitones) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return key;
  if (semitones == 0) return key;

  final isMinor = trimmed.endsWith('m');
  final tonic = isMinor ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  final pitch = _pitchOf(tonic);
  if (pitch == null) return key;

  final spelled = _spell(
    pitch + semitones,
    preferFlats: preferFlatsForKey(key, semitones),
  );
  return isMinor ? '${spelled}m' : spelled;
}
