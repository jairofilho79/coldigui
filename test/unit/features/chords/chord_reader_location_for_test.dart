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

  group('chordRouteFor', () {
    test('id de cifra no cache: isChord com rota /cifra', () {
      final route = chordRouteFor(chordId, {chordId: chord});

      expect(route.isChord, isTrue);
      expect(
        route.location,
        buildChordReaderLocation(
          chordId: chordId,
          titulo: 'Grande Deus',
          subtitulo: '001',
        ),
      );
    });

    test('id de PDF: não é cifra e não tem rota', () {
      final route = chordRouteFor(pdfId, {chordId: chord});

      expect(route.isChord, isFalse);
      expect(route.location, isNull);
    });

    test('cifra fora do cache: isChord sem rota', () {
      final route = chordRouteFor(chordId, const {});

      expect(route.isChord, isTrue);
      expect(route.location, isNull);
    });

    test('id inválido não lança e não é cifra', () {
      final route = chordRouteFor('nao-e-base64!!!', const {});

      expect(route.isChord, isFalse);
      expect(route.location, isNull);
    });
  });
}
