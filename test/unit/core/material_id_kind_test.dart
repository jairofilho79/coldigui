// test/unit/core/material_id_kind_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('materialIdKindOf', () {
    test('reconhece material PDF', () {
      final id = encodePdfId('assets/praises/abc/def.pdf');
      expect(materialIdKindOf(id), MaterialIdKind.pdf);
    });

    test('reconhece material de cifra', () {
      final id = encodePdfId('assets/praises/abc/def.chord');
      expect(materialIdKindOf(id), MaterialIdKind.chord);
    });

    test('ignora caixa da extensao', () {
      final id = encodePdfId('assets/praises/abc/def.CHORD');
      expect(materialIdKindOf(id), MaterialIdKind.chord);
    });

    test('classifica extensao desconhecida como unknown', () {
      final id = encodePdfId('assets/praises/abc/def.mp3');
      expect(materialIdKindOf(id), MaterialIdKind.unknown);
    });

    test('devolve unknown em id invalido sem lancar', () {
      expect(materialIdKindOf('nao-e-base64-valido!!!'), MaterialIdKind.unknown);
    });

    test('devolve unknown em id vazio', () {
      expect(materialIdKindOf(''), MaterialIdKind.unknown);
    });

    test('aceita pdfId do manifest PLPCG sem prefixo assets/', () {
      final id = encodePdfId('ColAdultos/001.pdf');
      expect(materialIdKindOf(id), MaterialIdKind.pdf);
    });
  });
}
