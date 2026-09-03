// test/unit/features/catalog/louvor_material_icons_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
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
