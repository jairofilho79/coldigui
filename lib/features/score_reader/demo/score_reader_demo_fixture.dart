import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/score_document.dart';
import '../domain/usecases/parse_score_document.dart';

const scoreReaderDemoKey = 'demo/som-que-vem.musicxml';

/// "Som que vem": melodia e letra originais criadas para esta demo.
/// Dedicadas ao domínio público sob CC0-1.0; não transcrevem outra canção.
/// Quatro compassos 4/4, uma voz, 16 semínimas e cifras C–F–G–C.
ScoreDocument loadScoreReaderDemoDocument() {
  const measures = [
    (
      chord: 'C',
      notes: ['C', 'E', 'D', 'G'],
      words: ['Som', 'que', 'vem', 'já'],
    ),
    (
      chord: 'F',
      notes: ['A', 'F', 'E', 'F'],
      words: ['Luz', 'no', 'céu', 'há'],
    ),
    (
      chord: 'G',
      notes: ['G', 'E', 'B', 'G'],
      words: ['Voz', 'que', 'diz', 'sim'],
    ),
    (
      chord: 'C',
      notes: ['F', 'D', 'E', 'C'],
      words: ['Paz', 'não', 'tem', 'fim'],
    ),
  ];
  final xml = StringBuffer('''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <work><work-title>Som que vem</work-title></work>
  <identification>
    <creator type="composer">Demo autoral coldigui</creator>
    <rights>CC0-1.0 — melodia e letra originais</rights>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Voz</part-name>
      <score-instrument id="I1"><instrument-name>Piano</instrument-name></score-instrument>
      <midi-instrument id="I1">
        <midi-channel>1</midi-channel><midi-program>1</midi-program>
      </midi-instrument>
    </score-part>
  </part-list>
  <part id="P1">
''');
  for (final (index, measure) in measures.indexed) {
    xml.writeln('<measure number="${index + 1}">');
    if (index == 0) {
      xml.writeln('''
<attributes>
  <divisions>1</divisions>
  <key><fifths>0</fifths></key>
  <time><beats>4</beats><beat-type>4</beat-type></time>
  <clef><sign>G</sign><line>2</line></clef>
</attributes>
<direction><sound tempo="96"/></direction>
''');
    }
    xml.writeln('''
<harmony>
  <root><root-step>${measure.chord}</root-step></root>
  <kind>major</kind>
</harmony>
''');
    for (var beat = 0; beat < 4; beat++) {
      xml.writeln('''
<note>
  <pitch><step>${measure.notes[beat]}</step><octave>4</octave></pitch>
  <duration>1</duration><type>quarter</type>
  <lyric number="1"><syllabic>single</syllabic><text>${measure.words[beat]}</text></lyric>
</note>
''');
    }
    if (index == 3) {
      xml.writeln('<barline><bar-style>light-heavy</bar-style></barline>');
    }
    xml.writeln('</measure>');
  }
  xml.write('</part></score-partwise>');
  return parseScoreDocument(Uint8List.fromList(utf8.encode(xml.toString())));
}
