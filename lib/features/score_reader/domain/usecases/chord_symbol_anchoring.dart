import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:xml/xml.dart';

/// Reancora as cifras de um `.mscx` na nota **ou pausa** sob elas.
///
/// O leitor MuseScore do crisp só prende `<Harmony>` em acordes: uma cifra
/// sobre pausa vai para a nota seguinte e, se o compasso acaba antes, some.
/// Em hinários isso é comum (cifra no tempo 1 de um compasso que começa com
/// pausa), e a cifra é imprescindível para o leitor.
///
/// Aqui cada `<Harmony>` é posicionada pelo tempo dentro do compasso, lido do
/// próprio XML, e ancorada no elemento do crisp que soa naquele instante
/// (pausas inclusive — o layout aceita pausa como âncora).
MultiPartScore reanchorMscxChordSymbols(String mscx, MultiPartScore score) {
  if (!mscx.contains('<Harmony')) return score;
  final XmlElement scoreNode;
  try {
    final root = XmlDocument.parse(mscx).rootElement;
    scoreNode = root.getElement('Score') ?? root;
  } on Object {
    return score;
  }
  final staves = [
    for (final staff in scoreNode.findElements('Staff'))
      if (staff.getElement('Measure') != null) staff,
  ];
  if (staves.length != score.parts.length) return score;
  return _reanchor(score, [
    for (final staff in staves) _mscxHarmoniesOf(staff),
  ], _symbolOfMscx);
}

/// O mesmo que [reanchorMscxChordSymbols] para MusicXML: o leitor do crisp
/// também empurra a `<harmony>` sobre pausa para a nota seguinte e, sem
/// `<staff>`, a repete em todas as pautas da parte. Aqui ela fica na pauta
/// indicada (1 quando omitida, como manda a especificação).
MultiPartScore reanchorMusicXmlChordSymbols(
  String musicXml,
  MultiPartScore score,
) {
  if (!musicXml.contains('<harmony')) return score;
  final XmlElement root;
  try {
    root = XmlDocument.parse(musicXml).rootElement;
  } on Object {
    return score;
  }
  if (root.name.local != 'score-partwise') return score;
  final perStaff = <_StaffHarmonies?>[];
  for (final part in root.findElements('part')) {
    perStaff.addAll(_musicXmlHarmoniesOf(part));
  }
  if (perStaff.length != score.parts.length) return score;
  return _reanchor(score, perStaff, _symbolOfMusicXml);
}

/// Troca as cifras de cada pauta pelas reancoradas, mas só quando todas as
/// cifras legíveis daquela pauta acharam âncora e os compassos batem; senão
/// a pauta fica como o crisp leu — melhor uma cifra deslocada que uma no
/// compasso errado.
MultiPartScore _reanchor(
  MultiPartScore score,
  List<_StaffHarmonies?> perStaff,
  ChordSymbol? Function(String xml) parse,
) {
  final symbolCache = <String, ChordSymbol?>{};
  var changed = false;
  final parts = <Score>[];
  for (var i = 0; i < score.parts.length; i++) {
    final part = score.parts[i];
    final harmonies = perStaff[i];
    final anchors = harmonies == null ? null : _AnchorIndex.of(part);
    if (harmonies == null ||
        anchors == null ||
        anchors.measureCount != harmonies.measureCount) {
      parts.add(part);
      continue;
    }
    final symbols = <ChordSymbol>[];
    var complete = true;
    for (final h in harmonies.items) {
      final symbol = symbolCache.putIfAbsent(h.xml, () => parse(h.xml));
      if (symbol == null) continue;
      final anchor = anchors.at(h.measure, h.position);
      if (anchor == null) {
        complete = false;
        break;
      }
      symbols.add(symbol.copyWith(elementId: anchor.id, offset: anchor.offset));
    }
    if (!complete) {
      parts.add(part);
      continue;
    }
    changed = true;
    parts.add(part.copyWith(chordSymbols: symbols));
  }
  if (!changed) return score;
  return MultiPartScore(
    parts,
    brackets: score.brackets,
    barlineGroups: score.barlineGroups,
    partialParts: score.partialParts,
    crossStaffChords: score.crossStaffChords,
  );
}

typedef _StaffHarmonies = ({int measureCount, List<_Harmony> items});

/// Cifras de uma `<part>` MusicXML, uma entrada por pauta da parte; null na
/// pauta quando algo no compasso não dá para medir.
List<_StaffHarmonies?> _musicXmlHarmoniesOf(XmlElement part) {
  final measures = part.findElements('measure').toList();
  var staves = 1;
  for (final m in measures) {
    for (final attributes in m.findElements('attributes')) {
      final n = int.tryParse(
        attributes.getElement('staves')?.innerText.trim() ?? '',
      );
      if (n != null && n > staves) staves = n;
    }
  }
  final items = [for (var s = 0; s < staves; s++) <_Harmony>[]];
  var divisions = 1;
  var valid = true;
  for (final (index, measure) in measures.indexed) {
    var cursor = Fraction.zero;
    for (final node in measure.childElements) {
      switch (node.name.local) {
        case 'attributes':
          final d = int.tryParse(
            node.getElement('divisions')?.innerText.trim() ?? '',
          );
          if (d != null && d > 0) divisions = d;
        case 'backup' || 'forward':
          final length = _divisionsLength(node, divisions);
          if (length == null) {
            valid = false;
            break;
          }
          cursor = node.name.local == 'backup'
              ? cursor - length
              : cursor + length;
        case 'harmony':
          final staff =
              int.tryParse(node.getElement('staff')?.innerText.trim() ?? '') ??
              1;
          final offset =
              int.tryParse(node.getElement('offset')?.innerText.trim() ?? '') ??
              0;
          if (staff < 1 || staff > staves) continue;
          items[staff - 1].add((
            measure: index,
            position: cursor + Fraction(offset, 4 * divisions),
            xml: node.toXmlString(),
          ));
        case 'note':
          if (node.getElement('grace') != null) continue;
          if (node.getElement('chord') != null) {
            // O acorde começa onde a nota anterior começou.
            continue;
          }
          final length = _divisionsLength(node, divisions);
          if (length == null) {
            valid = false;
            break;
          }
          cursor += length;
      }
    }
    if (!valid) break;
  }
  if (!valid) return [for (var s = 0; s < staves; s++) null];
  return [
    for (final list in items) (measureCount: measures.length, items: list),
  ];
}

Fraction? _divisionsLength(XmlElement node, int divisions) {
  final d = int.tryParse(node.getElement('duration')?.innerText.trim() ?? '');
  if (d == null) return null;
  return Fraction(d, 4 * divisions);
}

typedef _Harmony = ({int measure, Fraction position, String xml});

/// Cifras de uma `<Staff>` com compasso e tempo (em semibreves desde o início
/// do compasso), ou null se o compasso tiver algo que não sabemos medir.
_StaffHarmonies? _mscxHarmoniesOf(XmlElement staff) {
  final items = <_Harmony>[];
  var measure = 0;
  for (final node in staff.findElements('Measure')) {
    final voices = node.findElements('voice').toList();
    for (final voice in voices.isEmpty ? [node] : voices) {
      if (!_walkVoice(voice, measure, items)) return null;
    }
    measure++;
  }
  return (measureCount: measure, items: items);
}

bool _walkVoice(XmlElement voice, int measure, List<_Harmony> out) {
  var position = Fraction.zero;
  var shift = Fraction.zero;
  final tuplets = <Fraction>[];
  final idTuplets = <String, Fraction>{};
  for (final node in voice.childElements) {
    switch (node.name.local) {
      case 'location':
        final f = _fraction(node.getElement('fractions')?.innerText);
        if (f != null) shift += f;
      case 'Harmony':
        out.add((
          measure: measure,
          position: position + shift,
          xml: node.toXmlString(),
        ));
      case 'FretDiagram':
        for (final h in node.findElements('Harmony')) {
          out.add((
            measure: measure,
            position: position + shift,
            xml: h.toXmlString(),
          ));
        }
      case 'Tuplet':
        final ratio = _tupletRatio(node);
        if (ratio == null) return false;
        final id = node.getAttribute('id');
        if (id != null) {
          // MuseScore 2: o `<Tuplet id>` é declarado e os membros o citam.
          idTuplets[id] = ratio;
        } else {
          tuplets.add(ratio);
        }
      case 'endTuplet':
        if (tuplets.isNotEmpty) tuplets.removeLast();
      case 'Chord' || 'Rest':
        shift = Fraction.zero;
        if (_isGrace(node)) continue;
        final length = _durationOf(node);
        if (length == null) return false;
        var scaled = length;
        for (final ratio in tuplets) {
          scaled = scaled * ratio;
        }
        final memberOf = node.getElement('Tuplet')?.innerText.trim();
        if (memberOf != null && memberOf.isNotEmpty) {
          final ratio = idTuplets[memberOf];
          if (ratio == null) return false;
          scaled = scaled * ratio;
        }
        position += scaled;
    }
  }
  return true;
}

const _graceTags = {
  'acciaccatura',
  'appoggiatura',
  'grace4',
  'grace16',
  'grace32',
  'grace8after',
  'grace16after',
  'grace32after',
};

bool _isGrace(XmlElement chord) =>
    chord.childElements.any((c) => _graceTags.contains(c.name.local));

final _durationTypes = {
  'long': Fraction(4, 1),
  'breve': Fraction(2, 1),
  'whole': Fraction(1, 1),
  'half': Fraction(1, 2),
  'quarter': Fraction(1, 4),
  'eighth': Fraction(1, 8),
  '16th': Fraction(1, 16),
  '32nd': Fraction(1, 32),
  '64th': Fraction(1, 64),
  '128th': Fraction(1, 128),
  '256th': Fraction(1, 256),
  '512th': Fraction(1, 512),
  '1024th': Fraction(1, 1024),
};

Fraction? _durationOf(XmlElement node) {
  final type = node.getElement('durationType')?.innerText.trim();
  if (type == 'measure') {
    return _fraction(node.getElement('duration')?.innerText);
  }
  final base = _durationTypes[type];
  if (base == null) return null;
  final dots = int.tryParse(node.getElement('dots')?.innerText.trim() ?? '');
  var total = base;
  var add = base;
  for (var d = 0; d < (dots ?? 0); d++) {
    add = add * Fraction(1, 2);
    total += add;
  }
  return total;
}

Fraction? _tupletRatio(XmlElement tuplet) {
  final actual = int.tryParse(
    tuplet.getElement('actualNotes')?.innerText.trim() ?? '',
  );
  final normal = int.tryParse(
    tuplet.getElement('normalNotes')?.innerText.trim() ?? '',
  );
  if (actual == null || normal == null || actual <= 0 || normal <= 0) {
    return null;
  }
  return Fraction(normal, actual);
}

Fraction? _fraction(String? text) {
  final match = RegExp(r'^\s*(-?\d+)/(\d+)\s*$').firstMatch(text ?? '');
  if (match == null) return null;
  final den = int.parse(match[2]!);
  if (den == 0) return null;
  return Fraction(int.parse(match[1]!), den);
}

/// Lê o conteúdo de uma `<Harmony>` com o próprio leitor do crisp, para que a
/// cifra (raiz, qualidade, baixo, graus) seja idêntica à que ele produziria.
ChordSymbol? _symbolOfMscx(String harmonyXml) {
  final mscx =
      '<museScore version="4.20"><Score><Staff id="1"><Measure><voice>'
      '<TimeSig><sigN>4</sigN><sigD>4</sigD></TimeSig>'
      '$harmonyXml'
      '<Chord><durationType>whole</durationType>'
      '<Note><pitch>60</pitch><tpc>14</tpc></Note></Chord>'
      '</voice></Measure></Staff></Score></museScore>';
  try {
    return scoreFromMscx(mscx).chordSymbols.firstOrNull;
  } on Object {
    return null;
  }
}

ChordSymbol? _symbolOfMusicXml(String harmonyXml) {
  final xml =
      '<score-partwise version="4.0"><part-list>'
      '<score-part id="P1"><part-name>P</part-name></score-part></part-list>'
      '<part id="P1"><measure number="1"><attributes><divisions>1</divisions>'
      '<time><beats>4</beats><beat-type>4</beat-type></time>'
      '<clef><sign>G</sign><line>2</line></clef></attributes>'
      '$harmonyXml'
      '<note><pitch><step>C</step><octave>4</octave></pitch>'
      '<duration>4</duration><type>whole</type></note>'
      '</measure></part></score-partwise>';
  try {
    final staves = staffSystemFromMusicXml(xml).staves;
    return staves.first.chordSymbols.firstOrNull?.copyWith(
      offset: Fraction.zero,
    );
  } on Object {
    return null;
  }
}

/// Onde cada elemento do crisp começa dentro do seu compasso (só a primeira
/// passada; repetições não mudam a posição escrita).
class _AnchorIndex {
  _AnchorIndex._(this.measureCount, this._byMeasure);

  factory _AnchorIndex.of(Score score) {
    final timeline = playbackTimeline(score, expandRepeats: false);
    final starts = <int, Fraction>{};
    for (final n in timeline) {
      final s = starts[n.measureIndex];
      if (s == null || n.start < s) starts[n.measureIndex] = n.start;
    }
    final seen = <String>{};
    final byMeasure = <int, List<_Element>>{};
    for (final n in timeline) {
      if (!seen.add(n.elementId)) continue;
      (byMeasure[n.measureIndex] ??= []).add((
        id: n.elementId,
        start: n.start - starts[n.measureIndex]!,
        isRest: n.isRest,
        voice: n.voice,
      ));
    }
    return _AnchorIndex._(score.measures.length, byMeasure);
  }

  final int measureCount;
  final Map<int, List<_Element>> _byMeasure;

  /// O elemento que soa em [position] no compasso [measure]: o de início mais
  /// tardio que não passa de [position], preferindo nota a pausa e vozes
  /// mais altas em empate.
  ({String id, Fraction offset})? at(int measure, Fraction position) {
    _Element? best;
    for (final e in _byMeasure[measure] ?? const <_Element>[]) {
      if (e.start > position) continue;
      if (best == null || _better(e, best)) best = e;
    }
    if (best == null) return null;
    return (id: best.id, offset: position - best.start);
  }

  static bool _better(_Element a, _Element b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart > 0;
    if (a.isRest != b.isRest) return !a.isRest;
    return a.voice < b.voice;
  }
}

typedef _Element = ({String id, Fraction start, bool isRest, int voice});
