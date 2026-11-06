import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:xml/xml.dart';

import '../entities/musescore_performance_metadata.dart';
import '../entities/score_document.dart';
import 'chord_symbol_anchoring.dart';

const _maxInputBytes = 16 * 1024 * 1024;
const _maxXmlBytes = 4 * 1024 * 1024;
const _maxContainerBytes = 64 * 1024;
const _maxEntries = 128;
const _maxEntryBytes = 8 * 1024 * 1024;
const _maxExpandedBytes = 16 * 1024 * 1024;
const _maxExpansionRatio = 200;

/// Falha conclusiva ao abrir uma partitura (arquivo corrompido ou formato
/// não suportado).
class ScoreDocumentParseException implements Exception {
  const ScoreDocumentParseException(this.message);

  final String message;

  @override
  String toString() => 'ScoreDocumentParseException: $message';
}

/// Abre `.mscz`, `.mscx`, `.mxl` ou `.musicxml`/`.xml` a partir dos bytes.
///
/// O formato é detectado pelo conteúdo (assinatura ZIP / raiz XML), não pela
/// extensão: o R2 pode servir um `.mxl` descomprimido, e o nome do arquivo nem
/// sempre chega até aqui. Tudo acontece em memória (sem `dart:io`), então
/// funciona igual na Web.
ScoreDocument parseScoreDocument(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const ScoreDocumentParseException('arquivo vazio');
  }
  if (bytes.length > _maxInputBytes) {
    throw const ScoreDocumentParseException(
      'arquivo excede o limite de 16 MiB',
    );
  }
  try {
    if (_isZip(bytes)) return _parseZip(bytes);
    return _parseText(_decodeText(bytes));
  } on ScoreDocumentParseException {
    rethrow;
  } on Object catch (error) {
    throw ScoreDocumentParseException('$error');
  }
}

bool _isZip(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x50 &&
    bytes[1] == 0x4B &&
    bytes[2] == 0x03 &&
    bytes[3] == 0x04;

String _decodeText(List<int> bytes) {
  if (bytes.length > _maxXmlBytes) {
    throw const ScoreDocumentParseException('XML excede o limite de 4 MiB');
  }
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  return utf8.decode(hasBom ? bytes.sublist(3) : bytes, allowMalformed: true);
}

ScoreDocument _parseZip(Uint8List bytes) {
  final files = _readZipFiles(bytes);
  final rootfiles = _containerRootfiles(files['META-INF/container.xml']);

  String? pick(bool Function(String name) accept) {
    for (final path in rootfiles) {
      if (accept(path) && files.containsKey(path)) return path;
    }
    // `container.xml` ausente ou incompleto: primeiro candidato fora das
    // partes extraídas (`Excerpts/`) e dos metadados.
    for (final name in files.keys) {
      final lower = name.toLowerCase();
      if (lower.startsWith('meta-inf/') || lower.startsWith('excerpts/')) {
        continue;
      }
      if (accept(name)) return name;
    }
    return null;
  }

  final mscx = pick((n) => n.toLowerCase().endsWith('.mscx'));
  if (mscx != null) {
    return _fromMscx(
      _decodeText(_readEntry(files[mscx]!, _maxXmlBytes)),
      ScoreSourceFormat.mscz,
    );
  }
  final xml = pick((n) {
    final lower = n.toLowerCase();
    return lower.endsWith('.musicxml') || lower.endsWith('.xml');
  });
  if (xml != null) {
    return _fromMusicXml(
      _decodeText(_readEntry(files[xml]!, _maxXmlBytes)),
      ScoreSourceFormat.mxl,
    );
  }
  throw const ScoreDocumentParseException(
    'ZIP sem partitura MuseScore (.mscx) ou MusicXML',
  );
}

Map<String, ArchiveFile> _readZipFiles(Uint8List bytes) {
  final directory = ZipDirectory();
  final input = InputMemoryStream(bytes)..byteOrder = ByteOrder.littleEndian;
  final files = <String, ArchiveFile>{};
  final names = <String>{};
  var expanded = 0;
  var entries = 0;
  // Iteração lazy limita os próprios metadados; nenhum conteúdo é inflado aqui.
  for (final header in directory.headers(input, verify: true)) {
    if (++entries > _maxEntries) {
      throw const ScoreDocumentParseException(
        'ZIP excede o limite de 128 entradas',
      );
    }
    final name = header.filename;
    final mode = (header.externalFileAttributes >> 16) & 0xf000;
    if (!_safeArchivePath(name) || !names.add(name) || mode == 0xa000) {
      throw const ScoreDocumentParseException(
        'caminho ZIP inválido ou duplicado',
      );
    }
    final size = header.uncompressedSize;
    if (size < 0 || size > _maxEntryBytes) {
      throw const ScoreDocumentParseException(
        'entrada ZIP excede o limite de 8 MiB',
      );
    }
    expanded += size;
    if (expanded > _maxExpandedBytes) {
      throw const ScoreDocumentParseException(
        'ZIP expandido excede o limite de 16 MiB',
      );
    }
    final compressed = header.compressedSize;
    if (size > _maxExpansionRatio * (compressed > 0 ? compressed : 1)) {
      throw const ScoreDocumentParseException(
        'razão de expansão ZIP excede 200',
      );
    }
    if (header.generalPurposeBitFlag & 1 != 0) {
      throw const ScoreDocumentParseException(
        'ZIP protegido por senha não suportado',
      );
    }
    if (name.endsWith('/') ||
        mode == 0x4000 ||
        header.externalFileAttributes & 0x10 != 0) {
      continue;
    }
    final content = header.file;
    if (content == null) {
      throw const ScoreDocumentParseException('entrada ZIP sem conteúdo');
    }
    content
      ..verify = true
      ..throwOnError = true;
    files[name] = ArchiveFile.file(name, size, content);
  }
  if (directory.filePosition < 0) {
    throw const ScoreDocumentParseException('diretório ZIP ausente');
  }
  return files;
}

bool _safeArchivePath(String name) {
  if (name.isEmpty ||
      name.length > 1024 ||
      name.contains(RegExp(r'[\\:%]')) ||
      name.codeUnits.any((c) => c < 0x20 || c == 0x7f)) {
    return false;
  }
  final path = name.endsWith('/') ? name.substring(0, name.length - 1) : name;
  return path.split('/').every((p) => p.isNotEmpty && p != '.' && p != '..');
}

Uint8List _readEntry(ArchiveFile file, int limit) {
  if (file.size > limit) {
    throw ScoreDocumentParseException(
      '${file.name} excede o limite de $limit bytes',
    );
  }
  // archive >=4.6 limita a saída real ao tamanho declarado, mesmo se ele mentir.
  final content = file.readBytes();
  if (content == null || content.length > limit) {
    throw ScoreDocumentParseException('conteúdo ZIP inválido: ${file.name}');
  }
  return content;
}

List<String> _containerRootfiles(ArchiveFile? container) {
  if (container == null) return const [];
  final doc = XmlDocument.parse(
    _decodeText(_readEntry(container, _maxContainerBytes)),
  );
  return [
    for (final node in doc.findAllElements('rootfile'))
      ?node.getAttribute('full-path'),
  ];
}

ScoreDocument _parseText(String text) {
  final head = text.length > 4096 ? text.substring(0, 4096) : text;
  if (head.contains('<museScore')) {
    return _fromMscx(text, ScoreSourceFormat.mscx);
  }
  if (head.contains('<score-partwise') || head.contains('<score-timewise')) {
    return _fromMusicXml(text, ScoreSourceFormat.musicXml);
  }
  throw const ScoreDocumentParseException(
    'formato não reconhecido (esperado MuseScore ou MusicXML)',
  );
}

/// MuseScore 4.6+ aninha a cifra em `<Harmony><harmonyInfo>…` e chama o
/// baixo de `<bass>`; o leitor do crisp só lê `<root>`/`<name>`/`<base>`
/// direto em `<Harmony>` e descartaria todas as cifras (e os baixos das
/// cifras com barra). Desembrulhar mantém compatibilidade com arquivos
/// antigos.
String unwrapMuseScoreHarmonyInfo(String mscx) => mscx.replaceAllMapped(
  RegExp(r'<harmonyInfo>([\s\S]*?)</harmonyInfo>'),
  (match) => match[1]!.replaceAllMapped(
    RegExp(r'<bass>([\s\S]*?)</bass>'),
    (bass) => '<base>${bass[1]}</base>',
  ),
);

ScoreDocument _fromMscx(String mscx, ScoreSourceFormat format) {
  final unwrapped = unwrapMuseScoreHarmonyInfo(mscx);
  final system = staffSystemFromMscx(unwrapped);
  return ScoreDocument(
    score: reanchorMscxChordSymbols(
      unwrapped,
      MultiPartScore.fromStaffSystem(system),
    ),
    staves: _fitStaves(_mscxStaves(mscx), system.staves.length),
    format: format,
    museScorePerformance: _museScorePerformanceFromMscx(mscx),
  );
}

ScoreDocument _fromMusicXml(String xml, ScoreSourceFormat format) {
  final system = staffSystemFromMusicXml(xml);
  final declaredStaves = _musicXmlStaves(xml);
  return ScoreDocument(
    score: reanchorMusicXmlChordSymbols(
      xml,
      MultiPartScore.fromStaffSystem(system),
    ),
    staves: _fitStaves(declaredStaves, system.staves.length),
    format: format,
    musicXmlPerformance: _musicXmlPerformanceFromXml(xml, declaredStaves),
  );
}

/// Garante uma [ScoreStaff] por pauta renderizada, mesmo quando os metadados
/// do arquivo não batem com o que o leitor produziu.
List<ScoreStaff> _fitStaves(List<ScoreStaff> declared, int count) {
  if (declared.length == count) return declared;
  return [
    for (var i = 0; i < count; i++)
      i < declared.length
          ? ScoreStaff(
              index: i,
              partName: declared[i].partName,
              midiProgram: declared[i].midiProgram,
            )
          : ScoreStaff(index: i, partName: 'Pauta ${i + 1}'),
  ];
}

List<ScoreStaff> _mscxStaves(String mscx) {
  final staves = <ScoreStaff>[];
  // `<Part>` vem antes dos compassos; ler só esses blocos evita montar a DOM
  // do arquivo inteiro uma segunda vez.
  for (final match in RegExp(r'<Part\b[\s\S]*?</Part>').allMatches(mscx)) {
    final XmlElement part;
    try {
      part = XmlDocument.parse(match[0]!).rootElement;
    } on Object {
      continue;
    }
    final instrument = part.getElement('Instrument');
    final name = _firstText([
      part.getElement('trackName'),
      instrument?.getElement('trackName'),
      instrument?.getElement('longName'),
      instrument?.getElement('shortName'),
    ]);
    final program = int.tryParse(
      instrument
              ?.findAllElements('program')
              .firstOrNull
              ?.getAttribute('value') ??
          '',
    );
    final count = part.findElements('Staff').length.clamp(1, 16);
    for (var s = 0; s < count; s++) {
      staves.add(
        ScoreStaff(
          index: staves.length,
          partName: name ?? 'Pauta ${staves.length + 1}',
          staffInPart: s,
          staffCountInPart: count,
          midiProgram: program,
        ),
      );
    }
  }
  return staves;
}

List<ScoreStaff> _musicXmlStaves(String xml) {
  final partList = RegExp(r'<part-list\b[\s\S]*?</part-list>').firstMatch(xml);
  if (partList == null) return const [];
  final XmlElement list;
  try {
    list = XmlDocument.parse(partList[0]!).rootElement;
  } on Object {
    return const [];
  }
  final staves = <ScoreStaff>[];
  for (final part in list.findElements('score-part')) {
    final id = part.getAttribute('id') ?? '';
    final name = _firstText([
      part.getElement('part-name'),
      part.getElement('part-abbreviation'),
    ]);
    final program = int.tryParse(
      part.findAllElements('midi-program').firstOrNull?.innerText.trim() ?? '',
    );
    final count = _musicXmlStaffCount(xml, id);
    for (var s = 0; s < count; s++) {
      staves.add(
        ScoreStaff(
          index: staves.length,
          partName: name ?? 'Pauta ${staves.length + 1}',
          staffInPart: s,
          staffCountInPart: count,
          // MusicXML numera programas a partir de 1.
          midiProgram: program == null ? null : (program - 1).clamp(0, 127),
        ),
      );
    }
  }
  return staves;
}

int _musicXmlStaffCount(String xml, String partId) {
  if (partId.isEmpty) return 1;
  final start = xml.indexOf(RegExp('<part\\s+id="${RegExp.escape(partId)}"'));
  if (start == -1) return 1;
  final end = xml.indexOf('</measure>', start);
  final firstMeasure = xml.substring(start, end == -1 ? xml.length : end);
  final staves = RegExp(r'<staves>\s*(\d+)\s*</staves>')
      .firstMatch(firstMeasure);
  return (int.tryParse(staves?[1] ?? '') ?? 1).clamp(1, 16);
}

MusicXmlPerformanceMetadata _musicXmlPerformanceFromXml(
  String xml,
  List<ScoreStaff> declaredStaves,
) {
  final root = XmlDocument.parse(xml).rootElement;
  final sources = _musicXmlPartSources(root);
  final directions = <MusicXmlDirectionMetadata>[];
  final sounds = <MusicXmlSoundMetadata>[];
  final repeats = <MusicXmlRepeatMetadata>[];
  final graceNotes = <MusicXmlGraceMetadata>[];
  final ornaments = <MusicXmlOrnamentMetadata>[];
  final tremolos = <MusicXmlTremoloMetadata>[];
  final fermatas = <MusicXmlFermataMetadata>[];
  final staffCounts = <int>[];
  var declaredStaffOffset = 0;
  for (final _ in sources) {
    final count = declaredStaffOffset < declaredStaves.length
        ? declaredStaves[declaredStaffOffset].staffCountInPart
        : 1;
    staffCounts.add(count);
    declaredStaffOffset += count;
  }
  var staffOffset = 0;

  for (var partIndex = 0; partIndex < sources.length; partIndex++) {
    final source = sources[partIndex];
    final partStaffOffset = staffOffset;
    staffOffset += staffCounts[partIndex];
    _readMusicXmlPartPerformance(
      source: source,
      partIndex: partIndex,
      staffOffset: partStaffOffset,
      staffCount: staffCounts[partIndex],
      directions: directions,
      sounds: sounds,
      repeats: repeats,
      graceNotes: graceNotes,
      ornaments: ornaments,
      tremolos: tremolos,
      fermatas: fermatas,
    );
  }

  return MusicXmlPerformanceMetadata(
    directions: directions,
    sounds: sounds,
    repeats: repeats,
    graceNotes: graceNotes,
    ornaments: ornaments,
    tremolos: tremolos,
    fermatas: fermatas,
  );
}

List<_MusicXmlPartSource> _musicXmlPartSources(XmlElement root) {
  final partwise = root.name.local == 'score-partwise';
  final listedIds = [
    for (final part
        in root.getElement('part-list')?.findElements('score-part') ??
            const <XmlElement>[])
      ?part.getAttribute('id'),
  ];

  if (partwise) {
    final parts = root.findElements('part').toList();
    final byId = {
      for (final part in parts)
        if (part.getAttribute('id') case final String id) id: part,
    };
    final ids = [
      ...listedIds,
      for (final part in parts)
        if (!listedIds.contains(part.getAttribute('id')))
          part.getAttribute('id'),
    ].whereType<String>().toList();
    return [
      for (final id in ids)
        if (byId[id] case final XmlElement part)
          _MusicXmlPartSource(id, _partwiseMusicXmlMeasures(part)),
    ];
  }

  final measures = root.findElements('measure').toList();
  final measuresByPart = <String, List<_MusicXmlMeasureSource>>{};
  for (var i = 0; i < measures.length; i++) {
    for (final part in measures[i].findElements('part')) {
      final id = part.getAttribute('id');
      if (id == null) continue;
      measuresByPart
          .putIfAbsent(id, () => [])
          .add(_MusicXmlMeasureSource(measures[i], part, i));
    }
  }
  final ids = [
    ...listedIds,
    for (final id in measuresByPart.keys)
      if (!listedIds.contains(id)) id,
  ].whereType<String>().toSet().toList();
  return [
    for (final id in ids)
      _MusicXmlPartSource(id, measuresByPart[id] ?? const []),
  ];
}

List<_MusicXmlMeasureSource> _partwiseMusicXmlMeasures(XmlElement part) {
  final measures = part.findElements('measure').toList();
  return [
    for (var i = 0; i < measures.length; i++)
      _MusicXmlMeasureSource(measures[i], measures[i], i),
  ];
}

void _readMusicXmlPartPerformance({
  required _MusicXmlPartSource source,
  required int partIndex,
  required int staffOffset,
  required int staffCount,
  required List<MusicXmlDirectionMetadata> directions,
  required List<MusicXmlSoundMetadata> sounds,
  required List<MusicXmlRepeatMetadata> repeats,
  required List<MusicXmlGraceMetadata> graceNotes,
  required List<MusicXmlOrnamentMetadata> ornaments,
  required List<MusicXmlTremoloMetadata> tremolos,
  required List<MusicXmlFermataMetadata> fermatas,
}) {
  var divisions = _MusicXmlRational.zero;
  for (final measureSource in source.measures) {
    final measure = measureSource.measure;
    final content = measureSource.content;
    final measureIndex = measureSource.measureIndex;
    var cursor = _MusicXmlRational.zero;
    var measureEnd = _MusicXmlRational.zero;
    var measureEndKnown = true;
    final pendingRepeats =
        <({XmlElement element, String location, _MusicXmlRational? cursor})>[];

    void setCursor(_MusicXmlRational? value) {
      cursor = value ?? _MusicXmlRational.invalid;
      if (value == null) measureEndKnown = false;
      if (value != null && value.compareTo(measureEnd) > 0) {
        measureEnd = value;
      }
    }

    for (final element in content.children.whereType<XmlElement>()) {
      switch (element.name.local) {
        case 'attributes':
          final rawDivisions = _musicXmlChildText(element, 'divisions');
          final parsedDivisions = _MusicXmlRational.parse(rawDivisions);
          if (parsedDivisions != null &&
              parsedDivisions.numerator > BigInt.zero) {
            divisions = parsedDivisions;
          }
        case 'direction':
          final offsetElement = element.getElement('offset');
          final rawOffset = _musicXmlRawChildText(element, 'offset');
          final rawOffsetSound = offsetElement?.getAttribute('sound');
          final offsetAffectsSound =
              _parseMusicXmlYesNo(rawOffsetSound) ?? false;
          final directionOffset = _musicXmlOffset(rawOffset, divisions);
          final directionPosition = _musicXmlApplyOffset(
            cursor,
            rawOffset,
            divisions,
          );
          final staffNumber = int.tryParse(
            _musicXmlChildText(element, 'staff') ?? '',
          );
          final voice = _musicXmlChildText(element, 'voice');
          final dynamicMarks = <String>[];
          final displayTexts = <String>[];
          for (final type in element.findElements('direction-type')) {
            for (final dynamicsElement in type.findElements('dynamics')) {
              for (final mark
                  in dynamicsElement.children.whereType<XmlElement>()) {
                final text = mark.innerText.trim();
                dynamicMarks.add(
                  mark.name.local == 'other-dynamics' && text.isNotEmpty
                      ? text
                      : mark.name.local,
                );
              }
            }
            for (final words in type.findElements('words')) {
              final text = words.innerText.trim();
              if (text.isNotEmpty) displayTexts.add(text);
            }
          }
          directions.add(
            MusicXmlDirectionMetadata(
              origin: _musicXmlOrigin(
                source: source,
                partIndex: partIndex,
                measure: measure,
                measureIndex: measureIndex,
                staffOffset: staffOffset,
                staffCount: staffCount,
                staffNumber: staffNumber,
                voice: voice,
                onset: directionPosition,
              ),
              rawOffsetDivisions: rawOffset,
              offset: _musicXmlPublicPosition(directionOffset),
              rawOffsetSound: rawOffsetSound,
              offsetAffectsSound: offsetAffectsSound,
              dynamicMarks: dynamicMarks,
              displayText: displayTexts.isEmpty ? null : displayTexts.join(' '),
            ),
          );
          for (final sound in element.findElements('sound')) {
            sounds.add(
              _musicXmlSound(
                sound: sound,
                source: source,
                partIndex: partIndex,
                measure: measure,
                measureIndex: measureIndex,
                staffOffset: staffOffset,
                staffCount: staffCount,
                staffNumber: staffNumber,
                voice: voice,
                cursor: cursor,
                divisions: divisions,
                inheritedOffset: rawOffset,
                inheritedOffsetAffectsSound: offsetAffectsSound,
              ),
            );
          }
        case 'sound':
          sounds.add(
            _musicXmlSound(
              sound: element,
              source: source,
              partIndex: partIndex,
              measure: measure,
              measureIndex: measureIndex,
              staffOffset: staffOffset,
              staffCount: staffCount,
              cursor: cursor,
              divisions: divisions,
            ),
          );
        case 'note':
          final staffNumber =
              int.tryParse(_musicXmlChildText(element, 'staff') ?? '') ?? 1;
          final voice = _musicXmlChildText(element, 'voice');
          final origin = _musicXmlOrigin(
            source: source,
            partIndex: partIndex,
            measure: measure,
            measureIndex: measureIndex,
            staffOffset: staffOffset,
            staffCount: staffCount,
            staffNumber: staffNumber,
            voice: voice,
            onset: cursor,
          );
          if (element.getElement('rest') != null &&
              element
                  .findElements('notations')
                  .any(
                    (notations) => notations.findElements('fermata').isNotEmpty,
                  )) {
            fermatas.add(MusicXmlFermataMetadata(origin: origin, isRest: true));
          }
          final grace = element.getElement('grace');
          if (grace == null) {
            final tremolo = _musicXmlTremolo(element, origin);
            if (tremolo != null) tremolos.add(tremolo);
          }
          if (grace != null) {
            graceNotes.add(
              _musicXmlGrace(
                grace: grace,
                note: element,
                divisions: divisions,
                origin: origin,
              ),
            );
          } else if (element.getElement('chord') == null) {
            final ornament = _musicXmlOrnament(element, origin);
            if (ornament != null) ornaments.add(ornament);
          }
          if (grace == null && element.getElement('chord') == null) {
            final duration = _musicXmlDuration(
              _musicXmlChildText(element, 'duration'),
              divisions,
            );
            setCursor(
              cursor.isValid && duration != null ? cursor + duration : null,
            );
          }
        case 'backup':
          final duration = _musicXmlDuration(
            _musicXmlChildText(element, 'duration'),
            divisions,
          );
          setCursor(
            cursor.isValid && duration != null ? cursor - duration : null,
          );
        case 'forward':
          final duration = _musicXmlDuration(
            _musicXmlChildText(element, 'duration'),
            divisions,
          );
          setCursor(
            cursor.isValid && duration != null ? cursor + duration : null,
          );
        case 'barline':
          final location = element.getAttribute('location') ?? 'right';
          for (final repeat in element.findElements('repeat')) {
            pendingRepeats.add((
              element: repeat,
              location: location,
              cursor: cursor.isValid ? cursor : null,
            ));
          }
      }
    }

    for (final pending in pendingRepeats) {
      final position = switch (pending.location) {
        'left' => _MusicXmlRational.zero,
        'middle' => pending.cursor,
        _ => measureEndKnown ? measureEnd : null,
      };
      final rawTimes = pending.element.getAttribute('times');
      final rawAfterJump = pending.element.getAttribute('after-jump');
      repeats.add(
        MusicXmlRepeatMetadata(
          origin: _musicXmlOrigin(
            source: source,
            partIndex: partIndex,
            measure: measure,
            measureIndex: measureIndex,
            staffOffset: staffOffset,
            staffCount: staffCount,
            onset: position,
          ),
          direction: pending.element.getAttribute('direction') ?? '',
          location: pending.location,
          rawTimes: rawTimes,
          times: int.tryParse(rawTimes ?? ''),
          rawAfterJump: rawAfterJump,
          afterJump: _parseMusicXmlYesNo(rawAfterJump),
        ),
      );
    }
  }
}

MusicXmlSoundMetadata _musicXmlSound({
  required XmlElement sound,
  required _MusicXmlPartSource source,
  required int partIndex,
  required XmlElement measure,
  required int measureIndex,
  required int staffOffset,
  required int staffCount,
  required _MusicXmlRational? cursor,
  required _MusicXmlRational divisions,
  int? staffNumber,
  String? voice,
  String? inheritedOffset,
  bool inheritedOffsetAffectsSound = false,
}) {
  final rawTempo = sound.getAttribute('tempo');
  final rawDynamics = sound.getAttribute('dynamics');
  final rawDaCapo = sound.getAttribute('dacapo');
  final rawForwardRepeat = sound.getAttribute('forward-repeat');
  final rawTimeOnly = sound.getAttribute('time-only');
  final rawSoundDivisions = sound.getAttribute('divisions');
  final soundDivisions =
      _MusicXmlRational.parse(rawSoundDivisions) ?? divisions;
  final ownOffsetElement = sound.getElement('offset');
  final rawOwnOffset = _musicXmlRawChildText(sound, 'offset');
  final effectiveOffset = ownOffsetElement != null
      ? rawOwnOffset
      : inheritedOffsetAffectsSound
      ? inheritedOffset
      : null;
  final effectivePosition = _musicXmlApplyOffset(
    cursor,
    effectiveOffset,
    soundDivisions,
  );
  final rawOffsetPosition = ownOffsetElement == null
      ? null
      : _musicXmlOffset(rawOwnOffset, soundDivisions);

  return MusicXmlSoundMetadata(
    origin: _musicXmlOrigin(
      source: source,
      partIndex: partIndex,
      measure: measure,
      measureIndex: measureIndex,
      staffOffset: staffOffset,
      staffCount: staffCount,
      staffNumber: staffNumber,
      voice: voice,
      onset: effectivePosition,
    ),
    rawTempo: rawTempo,
    tempo: _parseMusicXmlDecimal(rawTempo),
    rawDynamics: rawDynamics,
    dynamics: _parseMusicXmlDecimal(rawDynamics),
    rawDaCapo: rawDaCapo,
    daCapo: _parseMusicXmlYesNo(rawDaCapo),
    segno: sound.getAttribute('segno'),
    dalSegno: sound.getAttribute('dalsegno'),
    coda: sound.getAttribute('coda'),
    toCoda: sound.getAttribute('tocoda'),
    fine: sound.getAttribute('fine'),
    rawForwardRepeat: rawForwardRepeat,
    forwardRepeat: _parseMusicXmlYesNo(rawForwardRepeat),
    rawTimeOnly: rawTimeOnly,
    timeOnlyPasses: _parseMusicXmlTimeOnly(rawTimeOnly),
    rawDivisions: rawSoundDivisions,
    divisions: _parseMusicXmlDecimal(rawSoundDivisions),
    rawOffsetDivisions: rawOwnOffset,
    offset: _musicXmlPublicPosition(rawOffsetPosition),
  );
}

MusicXmlGraceMetadata _musicXmlGrace({
  required XmlElement grace,
  required XmlElement note,
  required _MusicXmlRational divisions,
  required MusicXmlPerformanceOrigin origin,
}) {
  final rawSlash = grace.getAttribute('slash');
  final rawMakeTime = grace.getAttribute('make-time');
  final rawStealTimePrevious = grace.getAttribute('steal-time-previous');
  final rawStealTimeFollowing = grace.getAttribute('steal-time-following');
  final rawPitchAlter = _musicXmlRawChildText(
    note.getElement('pitch') ?? note,
    'alter',
  );
  final parsedPitchAlter = double.tryParse(rawPitchAlter ?? '');
  return MusicXmlGraceMetadata(
    origin: origin,
    rawSlash: rawSlash,
    slash: _parseMusicXmlYesNo(rawSlash),
    rawMakeTime: rawMakeTime,
    makeTime: _parseMusicXmlDecimal(rawMakeTime),
    makeTimeQuarterNotes: _musicXmlPublicPosition(
      _musicXmlDuration(rawMakeTime, divisions),
    ),
    rawStealTimePrevious: rawStealTimePrevious,
    stealTimePrevious: _parseMusicXmlDecimal(rawStealTimePrevious),
    rawStealTimeFollowing: rawStealTimeFollowing,
    stealTimeFollowing: _parseMusicXmlDecimal(rawStealTimeFollowing),
    rawPitchAlter: rawPitchAlter,
    pitchAlter:
        parsedPitchAlter != null &&
            parsedPitchAlter == parsedPitchAlter.roundToDouble() &&
            parsedPitchAlter >= -2 &&
            parsedPitchAlter <= 2
        ? parsedPitchAlter.round()
        : null,
  );
}

MusicXmlOrnamentMetadata? _musicXmlOrnament(
  XmlElement note,
  MusicXmlPerformanceOrigin origin,
) {
  for (final notations in note.findElements('notations')) {
    for (final ornaments in notations.findElements('ornaments')) {
      final names = [
        for (final mark in ornaments.children.whereType<XmlElement>())
          if (mark.name.local != 'accidental-mark' &&
              mark.name.local != 'tremolo')
            mark.name.local,
      ];
      if (names.isEmpty) continue;
      final rawAccidental = ornaments
          .findElements('accidental-mark')
          .map((mark) => mark.innerText.trim())
          .firstOrNull;
      return MusicXmlOrnamentMetadata(
        origin: origin,
        ornamentNames: names,
        rawAccidentalMark: rawAccidental,
        accidentalAlter: switch (rawAccidental) {
          'sharp' => 1,
          'flat' => -1,
          'natural' => 0,
          'double-sharp' || 'sharp-sharp' => 2,
          'double-flat' || 'flat-flat' => -2,
          _ => null,
        },
      );
    }
  }
  return null;
}

MusicXmlTremoloMetadata? _musicXmlTremolo(
  XmlElement note,
  MusicXmlPerformanceOrigin origin,
) {
  for (final notations in note.findElements('notations')) {
    for (final ornaments in notations.findElements('ornaments')) {
      for (final tremolo in ornaments.findElements('tremolo')) {
        final rawStrokes = tremolo.innerText.trim();
        return MusicXmlTremoloMetadata(
          origin: origin,
          rawType: tremolo.getAttribute('type') ?? 'single',
          rawStrokes: rawStrokes.isEmpty ? null : rawStrokes,
          strokes: int.tryParse(rawStrokes),
        );
      }
    }
  }
  return null;
}

MusicXmlPerformanceOrigin _musicXmlOrigin({
  required _MusicXmlPartSource source,
  required int partIndex,
  required XmlElement measure,
  required int measureIndex,
  required int staffOffset,
  required int staffCount,
  required _MusicXmlRational? onset,
  int? staffNumber,
  String? voice,
}) {
  final staffIndex =
      staffNumber != null && staffNumber > 0 && staffNumber <= staffCount
      ? staffOffset + staffNumber - 1
      : null;
  return MusicXmlPerformanceOrigin(
    partId: source.partId,
    partIndex: partIndex,
    measureIndex: measureIndex,
    measureNumber: measure.getAttribute('number'),
    staffNumber: staffNumber,
    staffIndex: staffIndex,
    voice: voice,
    onset: _musicXmlPublicPosition(onset),
  );
}

_MusicXmlRational? _musicXmlDuration(
  String? rawDuration,
  _MusicXmlRational divisions,
) {
  final duration = _MusicXmlRational.parse(rawDuration);
  if (duration == null ||
      !divisions.isValid ||
      divisions.numerator <= BigInt.zero) {
    return null;
  }
  return duration / divisions;
}

_MusicXmlRational? _musicXmlOffset(
  String? rawOffset,
  _MusicXmlRational divisions,
) {
  if (rawOffset == null) return null;
  final offset = _MusicXmlRational.parse(rawOffset);
  if (offset == null) return null;
  if (offset.numerator == BigInt.zero) return _MusicXmlRational.zero;
  if (!divisions.isValid || divisions.numerator <= BigInt.zero) return null;
  return offset / divisions;
}

_MusicXmlRational? _musicXmlApplyOffset(
  _MusicXmlRational? cursor,
  String? rawOffset,
  _MusicXmlRational divisions,
) {
  if (rawOffset == null) return cursor;
  final offset = _musicXmlOffset(rawOffset, divisions);
  if (offset == null || cursor == null || !cursor.isValid) return null;
  return cursor + offset;
}

MusicXmlPosition? _musicXmlPublicPosition(_MusicXmlRational? position) {
  if (position == null || !position.isValid) return null;
  return MusicXmlPosition(
    numerator: position.numerator.toString(),
    denominator: position.denominator.toString(),
  );
}

String? _musicXmlRawChildText(XmlElement element, String name) =>
    element.getElement(name)?.innerText.trim();

String? _musicXmlChildText(XmlElement element, String name) {
  final text = _musicXmlRawChildText(element, name);
  return text == null || text.isEmpty ? null : text;
}

bool? _parseMusicXmlYesNo(String? value) => switch (value?.trim()) {
  'yes' => true,
  'no' => false,
  _ => null,
};

double? _parseMusicXmlDecimal(String? value) {
  final parsed = _MusicXmlRational.parse(value);
  return parsed?.toDouble();
}

List<int> _parseMusicXmlTimeOnly(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  final passes = <int>[];
  for (final item in value.split(',')) {
    final pass = int.tryParse(item.trim());
    if (pass == null || pass < 1) return const [];
    passes.add(pass);
  }
  return passes;
}

class _MusicXmlPartSource {
  const _MusicXmlPartSource(this.partId, this.measures);

  final String? partId;
  final List<_MusicXmlMeasureSource> measures;
}

class _MusicXmlMeasureSource {
  const _MusicXmlMeasureSource(this.measure, this.content, this.measureIndex);

  final XmlElement measure;
  final XmlElement content;
  final int measureIndex;
}

class _MusicXmlRational {
  factory _MusicXmlRational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      return _MusicXmlRational._(BigInt.zero, BigInt.zero, isValid: false);
    }
    final sign = denominator.isNegative ? BigInt.from(-1) : BigInt.one;
    final signedNumerator = numerator * sign;
    final positiveDenominator = denominator.abs();
    final divisor = _musicXmlGcd(signedNumerator.abs(), positiveDenominator);
    return _MusicXmlRational._(
      signedNumerator ~/ divisor,
      positiveDenominator ~/ divisor,
    );
  }

  const _MusicXmlRational._(
    this.numerator,
    this.denominator, {
    this.isValid = true,
  });

  static final zero = _MusicXmlRational(BigInt.zero, BigInt.one);
  static final invalid = _MusicXmlRational._(
    BigInt.zero,
    BigInt.zero,
    isValid: false,
  );

  final BigInt numerator;
  final BigInt denominator;
  final bool isValid;

  static _MusicXmlRational? parse(String? value) {
    final text = value?.trim();
    if (text == null ||
        text.isEmpty ||
        text.length > 128 ||
        !RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(text)) {
      return null;
    }
    final negative = text.startsWith('-');
    final unsigned = text.startsWith('-') || text.startsWith('+')
        ? text.substring(1)
        : text;
    final parts = unsigned.split('.');
    final whole = parts.first.isEmpty ? '0' : parts.first;
    final fraction = parts.length == 1 ? '' : parts[1];
    final digits = '$whole$fraction';
    final numerator =
        BigInt.parse(digits) * (negative ? BigInt.from(-1) : BigInt.one);
    return _MusicXmlRational(numerator, BigInt.from(10).pow(fraction.length));
  }

  double toDouble() => numerator.toDouble() / denominator.toDouble();

  _MusicXmlRational operator +(_MusicXmlRational other) => _MusicXmlRational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  _MusicXmlRational operator -(_MusicXmlRational other) => _MusicXmlRational(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );

  _MusicXmlRational operator /(_MusicXmlRational other) => _MusicXmlRational(
    numerator * other.denominator,
    denominator * other.numerator,
  );

  int compareTo(_MusicXmlRational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
}

BigInt _musicXmlGcd(BigInt first, BigInt second) {
  var a = first;
  var b = second;
  while (b != BigInt.zero) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return a == BigInt.zero ? BigInt.one : a;
}

String? _firstText(Iterable<XmlElement?> candidates) {
  for (final element in candidates) {
    final text = element?.innerText.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

MuseScorePerformanceMetadata _museScorePerformanceFromMscx(String mscx) {
  final score = XmlDocument.parse(mscx).rootElement.getElement('Score');
  if (score == null) return const MuseScorePerformanceMetadata();

  final markers = <MuseScoreMarkerMetadata>[];
  final passages = <MuseScorePassageMetadata>[];
  final playRepeats = <MuseScorePlayRepeatsMetadata>[];
  final diagnostics = <MuseScorePerformanceDiagnostic>[];
  final rawJumps =
      <
        ({
          String? jumpTo,
          String? playUntil,
          String? continueAt,
          String? playRepeats,
          String? subtype,
          String? style,
          String? text,
          MuseScorePerformanceOrigin origin,
        })
      >[];

  final staffs = score.findElements('Staff').toList();
  final staffMeasureCounts = <int>[];
  for (var staffIndex = 0; staffIndex < staffs.length; staffIndex++) {
    final staff = staffs[staffIndex];
    final measures = staff.findElements('Measure').toList();
    staffMeasureCounts.add(measures.length);
    for (var measureIndex = 0; measureIndex < measures.length; measureIndex++) {
      final measure = measures[measureIndex];
      for (final marker in measure.findElements('Marker')) {
        markers.add(
          MuseScoreMarkerMetadata(
            origin: _museScoreOrigin(
              MuseScorePerformanceOriginKind.marker,
              'Marker',
              staffIndex,
              measureIndex,
              marker,
            ),
            label: _childText(marker, 'label'),
            markerType:
                _childText(marker, 'markerType') ??
                _childText(marker, 'subtype'),
            subtype: _childText(marker, 'subtype'),
            style: _childText(marker, 'style'),
            text: _childText(marker, 'text'),
          ),
        );
      }
      for (final jump in measure.findElements('Jump')) {
        final origin = _museScoreOrigin(
          MuseScorePerformanceOriginKind.jump,
          'Jump',
          staffIndex,
          measureIndex,
          jump,
        );
        rawJumps.add((
          jumpTo: _childText(jump, 'jumpTo'),
          playUntil: _childText(jump, 'playUntil'),
          continueAt: _childText(jump, 'continueAt'),
          playRepeats: _childText(jump, 'playRepeats'),
          subtype: _childText(jump, 'subtype'),
          style: _childText(jump, 'style'),
          text: _childText(jump, 'text'),
          origin: origin,
        ));
      }

      for (final volta in measure.findElements('Volta')) {
        passages.add(
          _museScorePassage(
            volta: volta,
            spanner: null,
            staffIndex: staffIndex,
            measureIndex: measureIndex,
            measureCount: measures.length,
            diagnostics: diagnostics,
          ),
        );
      }
      for (final spanner in _measureSpanners(measure)) {
        if (spanner.getAttribute('type') != 'Volta') continue;
        final volta = spanner.getElement('Volta');
        if (volta == null) {
          diagnostics.add(
            MuseScorePerformanceDiagnostic(
              code: MuseScorePerformanceDiagnosticCode.invalidPassage,
              origin: _museScoreOrigin(
                MuseScorePerformanceOriginKind.passage,
                'Spanner',
                staffIndex,
                measureIndex,
                spanner,
              ),
              message: 'Volta spanner has no Volta payload.',
            ),
          );
          continue;
        }
        passages.add(
          _museScorePassage(
            volta: volta,
            spanner: spanner,
            staffIndex: staffIndex,
            measureIndex: measureIndex,
            measureCount: measures.length,
            diagnostics: diagnostics,
          ),
        );
      }
    }
  }

  for (final declaration in score.findElements('playRepeats')) {
    final origin = MuseScorePerformanceOrigin(
      kind: MuseScorePerformanceOriginKind.playRepeats,
      elementName: 'playRepeats',
    );
    playRepeats.add(
      _museScorePlayRepeats(declaration.innerText, origin, diagnostics),
    );
  }

  final markersByLabel = <String, List<MuseScoreMarkerMetadata>>{};
  for (final marker in markers) {
    final label = marker.label?.trim();
    if (label == null || label.isEmpty) continue;
    markersByLabel.putIfAbsent(label, () => []).add(marker);
  }
  for (final entry in markersByLabel.entries) {
    final locations = entry.value
        .map((marker) => marker.origin.measureIndex)
        .toSet();
    if (locations.length < 2) continue;
    diagnostics.add(
      MuseScorePerformanceDiagnostic(
        code: MuseScorePerformanceDiagnosticCode.duplicateMarkerLabel,
        origin: entry.value.first.origin,
        relatedOrigins: [
          for (final marker in entry.value.skip(1)) marker.origin,
        ],
        reference: entry.key,
        message: 'Marker label "${entry.key}" identifies multiple measures.',
      ),
    );
  }

  final declaredPlayRepeats = playRepeats.map((setting) => setting.value);
  final repeatValues = declaredPlayRepeats.whereType<bool>().toSet();
  if (repeatValues.length > 1) {
    final first = playRepeats.firstWhere((setting) => setting.value != null);
    diagnostics.add(
      MuseScorePerformanceDiagnostic(
        code: MuseScorePerformanceDiagnosticCode.conflictingPlayRepeats,
        origin: first.origin,
        relatedOrigins: [
          for (final setting in playRepeats)
            if (setting.value != null && setting.value != first.value)
              setting.origin,
        ],
        reference: 'playRepeats',
        message: 'Score-wide playRepeats declarations disagree.',
      ),
    );
  }

  _diagnoseConflictingPassages(passages, diagnostics);

  final totalMeasureCount = staffMeasureCounts.isEmpty
      ? 0
      : staffMeasureCounts.reduce((a, b) => a > b ? a : b);
  MuseScorePerformanceDestination? resolveDestination(
    String? reference,
    MuseScorePerformanceOrigin jumpOrigin,
  ) {
    final label = reference?.trim();
    if (label == null || label.isEmpty) return null;
    final matches = markersByLabel[label];
    if (matches != null && matches.isNotEmpty) {
      final locations = matches
          .map((marker) => marker.origin.measureIndex!)
          .toSet();
      if (locations.length > 1) {
        diagnostics.add(
          MuseScorePerformanceDiagnostic(
            code: MuseScorePerformanceDiagnosticCode.ambiguousDestination,
            origin: jumpOrigin,
            relatedOrigins: matches.map((marker) => marker.origin).toList(),
            reference: reference,
            message: 'Destination "$reference" matches multiple marker labels.',
          ),
        );
        return null;
      }
      final marker = matches.first;
      return MuseScorePerformanceDestination(
        reference: reference!,
        measureIndex: marker.origin.measureIndex!,
        kind: MuseScoreDestinationKind.marker,
        origin: marker.origin,
      );
    }

    final specialMeasure = switch (label) {
      'start' when totalMeasureCount > 0 => 0,
      'end' when totalMeasureCount > 0 => totalMeasureCount - 1,
      _ => null,
    };
    if (specialMeasure != null) {
      return MuseScorePerformanceDestination(
        reference: reference!,
        measureIndex: specialMeasure,
        kind: label == 'start'
            ? MuseScoreDestinationKind.scoreStart
            : MuseScoreDestinationKind.scoreEnd,
        origin: MuseScorePerformanceOrigin(
          kind: MuseScorePerformanceOriginKind.score,
          elementName: 'Score',
          measureIndex: specialMeasure,
        ),
      );
    }

    diagnostics.add(
      MuseScorePerformanceDiagnostic(
        code: MuseScorePerformanceDiagnosticCode.unresolvedDestination,
        origin: jumpOrigin,
        reference: reference,
        message: 'Destination "$reference" has no matching marker label.',
      ),
    );
    return null;
  }

  final jumps = <MuseScoreJumpMetadata>[];
  for (final raw in rawJumps) {
    final playRepeatsOrigin = raw.playRepeats == null
        ? null
        : MuseScorePerformanceOrigin(
            kind: MuseScorePerformanceOriginKind.playRepeats,
            elementName: 'playRepeats',
            staffIndex: raw.origin.staffIndex,
            measureIndex: raw.origin.measureIndex,
            elementId: raw.origin.elementId,
          );
    final playRepeatsDeclaration = raw.playRepeats == null
        ? null
        : _museScorePlayRepeats(
            raw.playRepeats!,
            playRepeatsOrigin!,
            diagnostics,
          );
    jumps.add(
      MuseScoreJumpMetadata(
        origin: raw.origin,
        jumpTo: raw.jumpTo,
        playUntil: raw.playUntil,
        continueAt: raw.continueAt,
        playRepeats: playRepeatsDeclaration?.value,
        rawPlayRepeats: raw.playRepeats,
        playRepeatsDeclaration: playRepeatsDeclaration,
        subtype: raw.subtype,
        style: raw.style,
        text: raw.text,
        jumpToDestination: resolveDestination(raw.jumpTo, raw.origin),
        playUntilDestination: resolveDestination(raw.playUntil, raw.origin),
        continueAtDestination: resolveDestination(raw.continueAt, raw.origin),
      ),
    );
  }

  return MuseScorePerformanceMetadata(
    markers: markers,
    jumps: jumps,
    passages: passages,
    playRepeatsDeclarations: playRepeats,
    diagnostics: diagnostics,
  );
}

MuseScorePassageMetadata _museScorePassage({
  required XmlElement volta,
  required XmlElement? spanner,
  required int staffIndex,
  required int measureIndex,
  required int measureCount,
  required List<MuseScorePerformanceDiagnostic> diagnostics,
}) {
  final origin = _museScoreOrigin(
    MuseScorePerformanceOriginKind.passage,
    spanner == null ? 'Volta' : 'Spanner',
    staffIndex,
    measureIndex,
    spanner ?? volta,
  );
  final passNumbers = [
    for (final match in RegExp(
      r'\d+',
    ).allMatches(_childText(volta, 'endings') ?? ''))
      if (int.parse(match[0]!) > 0) int.parse(match[0]!),
  ];
  final rawMeasureCount = spanner == null
      ? '1'
      : _childText(
              spanner.getElement('next')?.getElement('location') ?? volta,
              'measures',
            ) ??
            '';
  final declaredMeasureCount = int.tryParse(rawMeasureCount);
  final validEnd =
      declaredMeasureCount != null &&
      declaredMeasureCount > 0 &&
      measureIndex + declaredMeasureCount <= measureCount;
  if (passNumbers.isEmpty || !validEnd) {
    diagnostics.add(
      MuseScorePerformanceDiagnostic(
        code: MuseScorePerformanceDiagnosticCode.invalidPassage,
        origin: origin,
        reference: rawMeasureCount,
        message: passNumbers.isEmpty
            ? 'Volta passage has no valid ending numbers.'
            : 'Volta passage has an invalid or out-of-range measure span.',
      ),
    );
  }

  final endHook = _childText(volta, 'endHookType');
  return MuseScorePassageMetadata(
    origin: origin,
    startMeasureIndex: measureIndex,
    passNumbers: passNumbers,
    declaredMeasureCount: declaredMeasureCount,
    endMeasureIndexExclusive: validEnd
        ? measureIndex + declaredMeasureCount
        : null,
    text: _childText(volta, 'text') ?? _childText(volta, 'beginText'),
    openEnd: endHook == null ? spanner != null : endHook == '0',
  );
}

void _diagnoseConflictingPassages(
  List<MuseScorePassageMetadata> passages,
  List<MuseScorePerformanceDiagnostic> diagnostics,
) {
  for (var i = 0; i < passages.length; i++) {
    final first = passages[i];
    if (first.endMeasureIndexExclusive == null) continue;
    for (final second in passages.skip(i + 1)) {
      if (first.origin.staffIndex != second.origin.staffIndex ||
          first.startMeasureIndex != second.startMeasureIndex ||
          first.endMeasureIndexExclusive != second.endMeasureIndexExclusive ||
          _sameInts(first.passNumbers, second.passNumbers)) {
        continue;
      }
      diagnostics.add(
        MuseScorePerformanceDiagnostic(
          code: MuseScorePerformanceDiagnosticCode.conflictingPassages,
          origin: first.origin,
          relatedOrigins: [second.origin],
          message: 'Volta passages at the same measures disagree.',
        ),
      );
    }
  }
}

bool _sameInts(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

MuseScorePlayRepeatsMetadata _museScorePlayRepeats(
  String rawValue,
  MuseScorePerformanceOrigin origin,
  List<MuseScorePerformanceDiagnostic> diagnostics,
) {
  return MuseScorePlayRepeatsMetadata(
    origin: origin,
    rawValue: rawValue.trim(),
    value: _parseMuseScorePlayRepeats(rawValue, origin, diagnostics),
  );
}

bool? _parseMuseScorePlayRepeats(
  String rawValue,
  MuseScorePerformanceOrigin origin,
  List<MuseScorePerformanceDiagnostic> diagnostics,
) {
  final value = switch (rawValue.trim().toLowerCase()) {
    '1' || 'true' || 'yes' => true,
    '0' || 'false' || 'no' => false,
    _ => null,
  };
  if (value == null) {
    diagnostics.add(
      MuseScorePerformanceDiagnostic(
        code: MuseScorePerformanceDiagnosticCode.invalidPlayRepeats,
        origin: origin,
        reference: rawValue,
        message: 'playRepeats must be a boolean value.',
      ),
    );
  }
  return value;
}

List<XmlElement> _measureSpanners(XmlElement measure) => [
  ...measure.findElements('Spanner'),
  for (final voice in measure.findElements('voice'))
    ...voice.findElements('Spanner'),
];

MuseScorePerformanceOrigin _museScoreOrigin(
  MuseScorePerformanceOriginKind kind,
  String elementName,
  int staffIndex,
  int measureIndex,
  XmlElement element,
) => MuseScorePerformanceOrigin(
  kind: kind,
  elementName: elementName,
  staffIndex: staffIndex,
  measureIndex: measureIndex,
  elementId: _elementId(element),
);

String? _elementId(XmlElement? element) => _childText(element, 'eid');

String? _childText(XmlElement? element, String childName) {
  final text = element?.getElement(childName)?.innerText.trim();
  return text == null || text.isEmpty ? null : text;
}
