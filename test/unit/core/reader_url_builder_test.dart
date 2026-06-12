import 'package:coldigui/core/utils/reader_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildReaderLocation inclui file e titulo', () {
    final location = buildReaderLocation(
      file: '/assets/Col/001.pdf',
      titulo: 'Aleluia',
    );

    expect(location, contains('/leitor?'));
    expect(location, contains('file=%2Fassets%2FCol%2F001.pdf'));
    expect(location, contains('titulo=Aleluia'));
    expect(location, isNot(contains('pdfId=')));
  });

  test('buildReaderLocation inclui pdfId quando informado', () {
    final location = buildReaderLocation(
      file: '/tmp/local.pdf',
      pdfId: 'assets/Col/001.pdf',
      titulo: 'Aleluia',
    );

    expect(location, contains('pdfId=assets%2FCol%2F001.pdf'));
    expect(location, contains('file=%2Ftmp%2Flocal.pdf'));
  });
}
