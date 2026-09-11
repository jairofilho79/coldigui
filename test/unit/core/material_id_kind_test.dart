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

    test('reconhece gestos por .gestures', () {
      final id = encodePdfId('assets/praises/abc/def.gestures');
      expect(materialIdKindOf(id), MaterialKind.gesture);
    });

    test('ignora caixa da extensao de gestos', () {
      final id = encodePdfId('assets/praises/abc/def.GESTURES');
      expect(materialIdKindOf(id), MaterialKind.gesture);
    });

    test('.txt e .gest nao sao mais gesto (nada as produz)', () {
      expect(
        materialIdKindOf(encodePdfId('assets/praises/abc/def.txt')),
        MaterialKind.unknown,
      );
      expect(
        materialIdKindOf(encodePdfId('assets/praises/abc/def.gest')),
        MaterialKind.unknown,
      );
    });

    test('classifica extensao desconhecida como unknown', () {
      final id = encodePdfId('assets/praises/abc/def.bin');
      expect(materialIdKindOf(id), MaterialKind.unknown);
    });

    test('reconhece audio por .mp3', () {
      final id = encodePdfId('assets/praises/abc/def.mp3');
      expect(materialIdKindOf(id), MaterialKind.audio);
    });

    test('reconhece toda extensao de kAudioMaterialExtensions', () {
      for (final ext in kAudioMaterialExtensions) {
        expect(
          materialIdKindOf(encodePdfId('assets/praises/abc/def$ext')),
          MaterialKind.audio,
          reason: ext,
        );
      }
    });

    test('cobre os containers de audio que o worker pode publicar', () {
      // `type: mp3`/`audio` no worker não olha a extensão do r2_key, então a
      // lista precisa cobrir os containers usados na prática.
      for (final ext in [
        '.mp3',
        '.m4a',
        '.m4b',
        '.aac',
        '.ogg',
        '.oga',
        '.opus',
        '.wav',
        '.flac',
        '.wma',
        '.weba',
        '.webm',
        '.aiff',
        '.aif',
      ]) {
        expect(kAudioMaterialExtensions, contains(ext), reason: ext);
      }
    });

    test('extensao de audio desconhecida cai em unknown (face de PDF)', () {
      // Documenta a limitação: a extensão é heurística, o `type` do worker é
      // a fonte da verdade.
      expect(
        materialIdKindOf(encodePdfId('assets/praises/abc/def.mid')),
        MaterialKind.unknown,
      );
    });

    test('id de YouTube nao decodifica e cai em unknown', () {
      // Consequência: id de YouTube aparece em `SavedPlaylist.pdfIds`.
      expect(materialIdKindOf('mat_9f2b41'), MaterialKind.unknown);
    });

    test('ignora caixa da extensao de audio', () {
      final id = encodePdfId('assets/praises/abc/def.MP3');
      expect(materialIdKindOf(id), MaterialKind.audio);
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
