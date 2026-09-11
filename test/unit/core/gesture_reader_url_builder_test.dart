import 'package:coldigui/core/utils/gesture_reader_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta /gestos com pdfId', () {
    expect(buildGestureReaderLocation(gestureId: 'abc123'), '/gestos?pdfId=abc123');
  });

  test('inclui titulo e subtitulo codificados', () {
    final location = buildGestureReaderLocation(
      gestureId: 'abc',
      titulo: 'Quero viver, ó Deus',
      subtitulo: '182',
    );
    expect(location, startsWith('/gestos?pdfId=abc'));
    expect(location, contains('titulo=Quero%20viver%2C%20%C3%B3%20Deus'));
    expect(location, contains('subtitulo=182'));
  });

  test('omite titulo e subtitulo vazios', () {
    expect(buildGestureReaderLocation(gestureId: 'abc', titulo: '', subtitulo: ''), '/gestos?pdfId=abc');
  });
}
