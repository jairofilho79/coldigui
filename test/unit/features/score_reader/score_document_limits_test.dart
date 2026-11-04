import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:flutter_test/flutter_test.dart';

const _mib = 1024 * 1024;
const _xml = '''
<score-partwise version="4.0">
<part-list><score-part id="P1"><part-name>Demo</part-name></score-part></part-list>
<part id="P1"><measure number="1">
<attributes><divisions>1</divisions></attributes>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
</measure></part></score-partwise>
''';

Uint8List _paddedXml(int length) {
  final head = utf8.encode(_xml);
  return (BytesBuilder(copy: false)
        ..add(head)
        ..add(
          Uint8List(length - head.length)
            ..fillRange(0, length - head.length, 32),
        ))
      .takeBytes();
}

Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(
      ArchiveFile.noCompress(entry.key, entry.value.length, entry.value),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  final rejects = throwsA(isA<ScoreDocumentParseException>());

  test('raw XML accepts 4 MiB and rejects one additional byte', () {
    expect(parseScoreDocument(_paddedXml(4 * _mib)).measureCount, 1);
    expect(() => parseScoreDocument(_paddedXml(4 * _mib + 1)), rejects);
  });

  test('selected ZIP XML has the same 4 MiB limit', () {
    expect(
      parseScoreDocument(_zip({'score.musicxml': _paddedXml(4 * _mib)}))
          .measureCount,
      1,
    );
    expect(
      () => parseScoreDocument(
        _zip({'score.musicxml': _paddedXml(4 * _mib + 1)}),
      ),
      rejects,
    );
  });

  test('container expansion cannot bypass its 64 KiB limit', () {
    const container = '<container><rootfiles/></container>';
    expect(
      parseScoreDocument(
        _zip({
          'META-INF/container.xml': utf8.encode(container.padRight(64 * 1024)),
          'score.musicxml': utf8.encode(_xml),
        }),
      ).measureCount,
      1,
    );
    final bytes = utf8.encode(container.padRight(64 * 1024 + 1));
    expect(
      () => parseScoreDocument(
        _zip({
          'META-INF/container.xml': bytes,
          'score.musicxml': utf8.encode(_xml),
        }),
      ),
      rejects,
    );
  });

  test('entry count is bounded before any score is inflated', () {
    final files = {
      'score.musicxml': utf8.encode(_xml),
      for (var i = 0; i < 127; i++) 'sidecar-$i.bin': const [1],
    };
    expect(parseScoreDocument(_zip(files)).measureCount, 1);
    files['one-too-many.bin'] = const [1];
    expect(() => parseScoreDocument(_zip(files)), rejects);
  });

  test('an unselected entry cannot exceed 8 MiB', () {
    final input = _zip({
      'score.musicxml': utf8.encode(_xml),
      'sidecar.bin': Uint8List(8 * _mib + 1),
    });
    expect(input.length, lessThan(16 * _mib));
    expect(() => parseScoreDocument(input), rejects);
  });

  test('highly compressed content cannot bypass expansion ratio', () {
    final input = ZipEncoder().encodeBytes(
      Archive()..add(ArchiveFile.bytes('score.musicxml', _paddedXml(_mib))),
    );
    expect(input.length, lessThan(_mib ~/ 200));
    expect(
      () => parseScoreDocument(input),
      throwsA(
        isA<ScoreDocumentParseException>().having(
          (e) => e.message,
          'expansion limit',
          contains('200'),
        ),
      ),
    );
  });

  test('actual inflation stays bounded even when all size headers lie', () {
    final input = ZipEncoder().encodeBytes(
      Archive()..add(ArchiveFile.bytes('score.musicxml', _paddedXml(4096))),
    );
    final directory = ZipDirectory();
    final header = directory
        .headers(InputMemoryStream(input)..byteOrder = ByteOrder.littleEndian)
        .single;
    final view = ByteData.sublistView(input);
    view.setUint32(header.localHeaderOffset + 22, 128, Endian.little);
    view.setUint32(directory.centralDirectoryOffset + 24, 128, Endian.little);
    if (header.generalPurposeBitFlag & 8 != 0) {
      var descriptor =
          header.localHeaderOffset +
          30 +
          view.getUint16(header.localHeaderOffset + 26, Endian.little) +
          view.getUint16(header.localHeaderOffset + 28, Endian.little) +
          header.compressedSize;
      if (view.getUint32(descriptor, Endian.little) == 0x08074b50) {
        descriptor += 4;
      }
      view.setUint32(descriptor + 8, 128, Endian.little);
    }
    expect(
      () => parseScoreDocument(input),
      throwsA(
        isA<ScoreDocumentParseException>().having(
          (e) => e.message,
          'effective output limit',
          contains('128'),
        ),
      ),
    );
  });

  test('input bytes are limited before ZIP/XML decoding', () {
    final input = _zip({
      'score.musicxml': utf8.encode(_xml),
      'padding.bin': Uint8List(16 * _mib),
    });
    expect(input.length, greaterThan(16 * _mib));
    expect(() => parseScoreDocument(input), rejects);
  });

  test('unsafe or duplicate entry names are rejected', () {
    expect(
      () => parseScoreDocument(_zip({'../score.musicxml': utf8.encode(_xml)})),
      rejects,
    );
    // Archive deduplicates entries, so alias the two encoded names instead.
    final aliased = Uint8List.fromList(
      _zip({'a.musicxml': utf8.encode(_xml), 'b.musicxml': utf8.encode(_xml)}),
    );
    for (var i = 0; i + 10 <= aliased.length; i++) {
      if (utf8.decode(aliased.sublist(i, i + 10), allowMalformed: true) ==
          'b.musicxml') {
        aliased[i] = 'a'.codeUnitAt(0);
      }
    }
    expect(() => parseScoreDocument(aliased), rejects);
  });
}
