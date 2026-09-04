// test/unit/features/catalog/louvor_material_icons_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LouvorMaterialIcons.forKind', () {
    test('mapeia cada kind ao seu ícone', () {
      expect(LouvorMaterialIcons.forKind(MaterialKind.pdf), Icons.piano);
      expect(LouvorMaterialIcons.forKind(MaterialKind.chord), Icons.music_note);
      expect(
        LouvorMaterialIcons.forKind(MaterialKind.gesture),
        Icons.pan_tool_outlined,
      );
      expect(
        LouvorMaterialIcons.forKind(MaterialKind.audio),
        LouvorMaterialIcons.audio,
      );
      expect(
        LouvorMaterialIcons.forKind(MaterialKind.youtube),
        LouvorMaterialIcons.youtube,
      );
      expect(LouvorMaterialIcons.forKind(MaterialKind.unknown), Icons.piano);
    });
  });

  group('LouvorMaterialIcons.kindForCategory', () {
    test('classifica categorias do manifest', () {
      expect(
        LouvorMaterialIcons.kindForCategory('Partitura'),
        MaterialKind.pdf,
      );
      expect(
        LouvorMaterialIcons.kindForCategory('Cifra I'),
        MaterialKind.chord,
      );
      expect(
        LouvorMaterialIcons.kindForCategory('Gestos CIAs'),
        MaterialKind.gesture,
      );
      expect(LouvorMaterialIcons.kindForCategory('Áudio'), MaterialKind.audio);
      expect(
        LouvorMaterialIcons.kindForCategory('Playback'),
        MaterialKind.audio,
      );
      expect(LouvorMaterialIcons.kindForCategory('MP3'), MaterialKind.audio);
      expect(
        LouvorMaterialIcons.kindForCategory('Qualquer outra'),
        MaterialKind.pdf,
      );
    });
  });

  group('LouvorMaterialIcons.forEntry', () {
    test('usa a heurística de categoria da entrada PDF', () {
      LouvorMaterialEntry entry(String categoria) {
        final louvor = Louvor.fromManifest(
          nome: 'Hino',
          numero: '1',
          categoria: categoria,
          classificacao: 'Básico',
          pdf: 'a.pdf',
          pdfId: 'pdf1',
          groupId: 'g1',
        );
        return LouvorMaterialEntry(
          categoria: categoria,
          pdfId: louvor.pdfId,
          louvor: louvor,
        );
      }

      expect(LouvorMaterialIcons.forEntry(entry('Partitura')), Icons.piano);
      expect(LouvorMaterialIcons.forEntry(entry('Cifra I')), Icons.music_note);
      expect(
        LouvorMaterialIcons.forEntry(entry('Gestos CIAs')),
        Icons.pan_tool_outlined,
      );
    });
  });

  group('LouvorMaterialIcons.forMaterial', () {
    test('PDF cai na heurística de categoria', () {
      PdfMaterial pdf(String categoria) {
        return PdfMaterial(
          Louvor.fromManifest(
            nome: 'Hino',
            numero: '1',
            categoria: categoria,
            classificacao: 'Básico',
            pdf: 'a.pdf',
            pdfId: 'pdf1',
            groupId: 'g1',
          ),
        );
      }

      expect(LouvorMaterialIcons.forMaterial(pdf('Partitura')), Icons.piano);
      expect(
        LouvorMaterialIcons.forMaterial(pdf('Gestos CIAs')),
        Icons.pan_tool_outlined,
      );
    });

    test('cifra, áudio e YouTube usam o kind, não a categoria', () {
      // Categoria mentirosa de propósito: o kind do material é a verdade.
      const chord = ChordMaterialRef(
        ChordMaterial(
          chordId: 'c1',
          r2Key: 'k1',
          nome: 'Hino',
          numero: '1',
          groupId: 'g1',
          categoria: 'Áudio',
          classificacao: 'Básico',
        ),
      );
      const audio = AudioMaterial(
        AudioTrack(
          audioId: 'a1',
          r2Key: 'k2',
          nome: 'Hino',
          numero: '1',
          groupId: 'g1',
          categoria: 'Partitura',
          classificacao: 'Básico',
        ),
      );
      const youtube = YoutubeMaterialRef(
        YoutubeMaterial(
          id: 'y1',
          url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
          nome: 'Hino',
          numero: '1',
          groupId: 'g1',
          categoria: 'Partitura',
          classificacao: 'Básico',
        ),
      );

      expect(LouvorMaterialIcons.forMaterial(chord), Icons.music_note);
      expect(LouvorMaterialIcons.forMaterial(audio), LouvorMaterialIcons.audio);
      expect(
        LouvorMaterialIcons.forMaterial(youtube),
        LouvorMaterialIcons.youtube,
      );
    });
  });

  group('LouvorMaterialIcons.forCategory (deprecated)', () {
    test('mantém o mapeamento por string da onda anterior', () {
      // ignore: deprecated_member_use_from_same_package
      IconData icon(String c) => LouvorMaterialIcons.forCategory(c);

      expect(icon('Partitura'), Icons.piano);
      expect(icon('Cifra II'), Icons.music_note);
      expect(icon('Gestos'), Icons.pan_tool_outlined);
      expect(icon('Áudio'), LouvorMaterialIcons.audio);
      expect(icon('audio'), LouvorMaterialIcons.audio);
      expect(icon('Desconhecido'), Icons.piano);
    });
  });
}
