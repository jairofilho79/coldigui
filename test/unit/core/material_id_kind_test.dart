// test/unit/core/material_id_kind_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('materialIdKindOf', () {
    test('reconhece material PDF', () {
      final id = encodePdfId('assets/praises/abc/def.pdf');
      expect(materialIdKindOf(id), MaterialKind.pdf);
    });

    test('reconhece material de cifra', () {
      final id = encodePdfId('assets/praises/abc/def.chord');
      expect(materialIdKindOf(id), MaterialKind.chord);
    });

    test('ignora caixa da extensao', () {
      final id = encodePdfId('assets/praises/abc/def.CHORD');
      expect(materialIdKindOf(id), MaterialKind.chord);
    });

    test('reconhece gestos por .txt', () {
      final id = encodePdfId('assets/praises/abc/def.txt');
      expect(materialIdKindOf(id), MaterialKind.gesture);
    });

    test('reconhece gestos por .gest', () {
      final id = encodePdfId('assets/praises/abc/def.gest');
      expect(materialIdKindOf(id), MaterialKind.gesture);
    });

    test('ignora caixa da extensao de gestos', () {
      final id = encodePdfId('assets/praises/abc/def.TXT');
      expect(materialIdKindOf(id), MaterialKind.gesture);
    });

    test('classifica extensao desconhecida como unknown', () {
      final id = encodePdfId('assets/praises/abc/def.mp3');
      expect(materialIdKindOf(id), MaterialKind.unknown);
    });

    test('devolve unknown em id invalido sem lancar', () {
      expect(materialIdKindOf('nao-e-base64-valido!!!'), MaterialKind.unknown);
    });

    test('devolve unknown em id vazio', () {
      expect(materialIdKindOf(''), MaterialKind.unknown);
    });

    test('aceita pdfId do manifest PLPCG sem prefixo assets/', () {
      final id = encodePdfId('ColAdultos/001.pdf');
      expect(materialIdKindOf(id), MaterialKind.pdf);
    });
  });
}
