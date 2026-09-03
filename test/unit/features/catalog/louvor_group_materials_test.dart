// test/unit/features/catalog/louvor_group_materials_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String categoria,
  required String classificacao,
  required String pdfId,
}) {
  return Louvor.fromManifest(
    nome: 'Grande Deus',
    numero: '001',
    categoria: categoria,
    classificacao: classificacao,
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'praise-1',
    source: LouvorDataSource.coldigom,
  );
}

const _chord = ChordMaterial(
  chordId: 'chord1',
  r2Key: 'assets/praises/praise-1/a.chord',
  nome: 'Grande Deus',
  numero: '001',
  groupId: 'praise-1',
  categoria: 'Cifra',
  classificacao: 'Coletânea',
);

const _track = AudioTrack(
  audioId: 'audio1',
  r2Key: 'assets/praises/praise-1/a.mp3',
  nome: 'Grande Deus',
  numero: '001',
  groupId: 'praise-1',
  categoria: 'Áudio',
  classificacao: 'Coletânea',
);

const _youtube = YoutubeMaterial(
  id: 'yt1',
  url: 'https://youtu.be/1Pks43ceAac',
  nome: 'Grande Deus',
  numero: '001',
  groupId: 'praise-1',
  categoria: 'YouTube',
  classificacao: 'Coletânea',
);

void main() {
  group('LouvorGroup.materials', () {
    test('ordena PDFs por seção, cifras, áudios e YouTube', () {
      final groups = LouvorGroup.fromLouvores(
        [
          _louvor(
            categoria: 'Partitura',
            classificacao: 'Coletânea',
            pdfId: 'pdf1',
          ),
          _louvor(categoria: 'Gestos', classificacao: 'Fox', pdfId: 'pdf2'),
        ],
        chordMaterials: const [_chord],
        audioTracks: const [_track],
        youtubeMaterials: const [_youtube],
      );

      final materials = groups.single.materials;

      expect(materials.map((m) => m.kind).toList(), const [
        MaterialKind.pdf,
        MaterialKind.pdf,
        MaterialKind.chord,
        MaterialKind.audio,
        MaterialKind.youtube,
      ]);
      expect(materials.map((m) => m.id).toList(), const [
        'pdf1',
        'pdf2',
        'chord1',
        'audio1',
        'yt1',
      ]);
      expect(materials[0], isA<PdfMaterial>());
      expect(materials[2], isA<ChordMaterialRef>());
      expect(materials[3], isA<AudioMaterial>());
      expect(materials[4], isA<YoutubeMaterialRef>());
    });

    test('preserva a ordem das seções e das entradas dentro delas', () {
      final groups = LouvorGroup.fromLouvores([
        _louvor(categoria: 'Gestos', classificacao: 'Coletânea', pdfId: 'pdf2'),
        _louvor(
          categoria: 'Partitura',
          classificacao: 'Coletânea',
          pdfId: 'pdf1',
        ),
      ]);

      final group = groups.single;
      // A ordem dentro da seção é a de LouvorCategoryOrder (Partitura antes).
      expect(
        group.materials.map((m) => m.id).toList(),
        group.sections.expand((s) => s.materials).map((e) => e.pdfId).toList(),
      );
    });

    test('expõe groupId e categoria de cada material', () {
      final groups = LouvorGroup.fromLouvores(
        [
          _louvor(
            categoria: 'Partitura',
            classificacao: 'Coletânea',
            pdfId: 'pdf1',
          ),
        ],
        chordMaterials: const [_chord],
        audioTracks: const [_track],
        youtubeMaterials: const [_youtube],
      );

      final materials = groups.single.materials;
      expect(materials.every((m) => m.groupId == 'praise-1'), isTrue);
      expect(materials.map((m) => m.categoria).toList(), const [
        'Partitura',
        'Cifra',
        'Áudio',
        'YouTube',
      ]);
    });

    test('grupo sem materiais devolve lista vazia', () {
      final group = LouvorGroup(
        groupId: 'praise-1',
        numero: '001',
        nome: 'Grande Deus',
        sections: const [],
      );
      expect(group.materials, isEmpty);
    });

    test('conta o mesmo total que totalMaterials', () {
      final groups = LouvorGroup.fromLouvores(
        [
          _louvor(
            categoria: 'Partitura',
            classificacao: 'Coletânea',
            pdfId: 'pdf1',
          ),
        ],
        chordMaterials: const [_chord],
        audioTracks: const [_track],
        youtubeMaterials: const [_youtube],
      );

      final group = groups.single;
      expect(group.materials, hasLength(group.totalMaterials));
    });
  });
}
