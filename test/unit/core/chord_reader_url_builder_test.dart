import 'package:coldigui/core/utils/chord_reader_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta /cifra com pdfId', () {
    expect(
      buildChordReaderLocation(chordId: 'abc123'),
      '/cifra?pdfId=abc123',
    );
  });

  test('inclui titulo e subtitulo codificados', () {
    final location = buildChordReaderLocation(
      chordId: 'abc',
      titulo: 'Comigo habita, ó Deus',
      subtitulo: '692',
    );

    expect(location, startsWith('/cifra?pdfId=abc'));
    expect(location, contains('titulo=Comigo%20habita%2C%20%C3%B3%20Deus'));
    expect(location, contains('subtitulo=692'));
  });

  test('omite titulo e subtitulo vazios', () {
    final location =
        buildChordReaderLocation(chordId: 'abc', titulo: '', subtitulo: '');

    expect(location, '/cifra?pdfId=abc');
  });
}
