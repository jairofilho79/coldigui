// test/unit/features/chords/chord_reader_location_for_test.dart
import 'package:coldigui/core/utils/chord_reader_url_builder.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/presentation/utils/open_chord_in_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final chordId = encodePdfId('assets/praises/praise-1/a.chord');
  final pdfId = encodePdfId('assets/praises/praise-1/a.pdf');
  final chord = ChordMaterial(
    chordId: chordId,
    r2Key: 'assets/praises/praise-1/a.chord',
    nome: 'Grande Deus',
    numero: '001',
    groupId: 'praise-1',
    categoria: 'Cifra',
    classificacao: 'Coletânea',
  );

  group('chordReaderLocationFor', () {
    test('devolve rota /cifra quando o id é cifra e está no cache', () {
      expect(
        chordReaderLocationFor(chordId, {chordId: chord}),
        buildChordReaderLocation(
          chordId: chordId,
          titulo: 'Grande Deus',
          subtitulo: '001',
        ),
      );
    });

    test('devolve null para id de PDF', () {
      expect(chordReaderLocationFor(pdfId, {chordId: chord}), isNull);
    });

    test('devolve null quando a cifra não está no cache', () {
      expect(chordReaderLocationFor(chordId, const {}), isNull);
    });

    test('devolve null para id inválido sem lançar', () {
      expect(chordReaderLocationFor('nao-e-base64!!!', const {}), isNull);
    });
  });
}
