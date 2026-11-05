import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:xml/xml.dart';

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
  );
}

ScoreDocument _fromMusicXml(String xml, ScoreSourceFormat format) {
  final system = staffSystemFromMusicXml(xml);
  return ScoreDocument(
    score: reanchorMusicXmlChordSymbols(
      xml,
      MultiPartScore.fromStaffSystem(system),
    ),
    staves: _fitStaves(_musicXmlStaves(xml), system.staves.length),
    format: format,
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

String? _firstText(Iterable<XmlElement?> candidates) {
  for (final element in candidates) {
    final text = element?.innerText.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}
