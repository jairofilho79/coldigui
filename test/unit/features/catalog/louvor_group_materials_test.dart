// test/unit/features/catalog/louvor_group_materials_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
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

  group('LouvorGroup.extras', () {
    final pdf = _louvor(
      categoria: 'Partitura',
      classificacao: 'Coletânea',
      pdfId: 'pdf1',
    );

    test('getters por tipo saem de extras', () {
      final group = LouvorGroup(
        groupId: 'praise-1',
        numero: '001',
        nome: 'Grande Deus',
        sections: const [],
        extras: const [
          ChordMaterialRef(_chord),
          AudioMaterial(_track),
          YoutubeMaterialRef(_youtube),
        ],
      );

      expect(group.chordMaterials, const [_chord]);
      expect(group.audioTracks, const [_track]);
      expect(group.youtubeMaterials, const [_youtube]);
    });

    test('materials = PDFs por seção + extras na ordem canônica', () {
      final group = LouvorGroup(
        groupId: 'praise-1',
        numero: '001',
        nome: 'Grande Deus',
        sections: [
          LouvorMaterialSection(
            classificacao: 'Coletânea',
            displayLabel: 'Coletânea',
            materials: [
              LouvorMaterialEntry(
                categoria: pdf.categoria,
                pdfId: pdf.pdfId,
                louvor: pdf,
              ),
            ],
          ),
        ],
        extras: const [
          ChordMaterialRef(_chord),
          AudioMaterial(_track),
          YoutubeMaterialRef(_youtube),
        ],
      );

      expect(group.materials.map((m) => m.id).toList(), const [
        'pdf1',
        'chord1',
        'audio1',
        'yt1',
      ]);
      expect(group.totalMaterials, 4);
      expect(group.totalPdfs, 1);
    });

    test('construtor legado converte as três listas em extras', () {
      final group = LouvorGroup(
        groupId: 'praise-1',
        numero: '001',
        nome: 'Grande Deus',
        sections: const [],
        chordMaterials: const [_chord],
        audioTracks: const [_track],
        youtubeMaterials: const [_youtube],
      );

      expect(group.extras.map((m) => m.kind).toList(), const [
        MaterialKind.chord,
        MaterialKind.audio,
        MaterialKind.youtube,
      ]);
      expect(group.chordMaterials, const [_chord]);
      expect(group.audioTracks, const [_track]);
      expect(group.youtubeMaterials, const [_youtube]);
    });

    test('withColdigomMeta preserva extras', () {
      final group = LouvorGroup(
        groupId: 'praise-1',
        numero: '001',
        nome: 'Grande Deus',
        sections: const [],
        extras: const [ChordMaterialRef(_chord), AudioMaterial(_track)],
      );

      final withMeta = group.withColdigomMeta(
        const ColdigomPraiseMetadata(name: 'Grande Deus'),
      );

      expect(withMeta.extras, group.extras);
      expect(withMeta.chordMaterials, const [_chord]);
      expect(withMeta.audioTracks, const [_track]);
      expect(withMeta.coldigomMeta?.name, 'Grande Deus');
    });

    test('isColdigom continua verdadeiro por cifra em extras', () {
      final group = LouvorGroup(
        groupId: 'praise-1',
        numero: '001',
        nome: 'Grande Deus',
        sections: const [],
        extras: const [ChordMaterialRef(_chord)],
      );

      expect(group.isColdigom, isTrue);
    });
  });

  // Migrado de test/widget/features/coldigom/coldigom_material_sheet_test.dart.
  group('LouvorGroup.fromLouvores com meta Coldigom', () {
    test('anexa coldigomMeta e flatPdfMaterials ordena', () {
      final a = Louvor.fromManifest(
        nome: 'Hino',
        numero: '1',
        categoria: 'Cifra',
        classificacao: 'Básico',
        pdf: 'a.pdf',
        pdfId: 'a',
        groupId: 'g1',
        source: LouvorDataSource.coldigom,
      );
      final b = Louvor.fromManifest(
        nome: 'Hino',
        numero: '1',
        categoria: 'Partitura',
        classificacao: 'Básico',
        pdf: 'b.pdf',
        pdfId: 'b',
        groupId: 'g1',
        source: LouvorDataSource.coldigom,
      );

      final group = LouvorGroup.fromLouvores(
        [a, b],
        coldigomMetaByGroupId: const {
          'g1': ColdigomPraiseMetadata(name: 'Hino', rhythm: 'Básico'),
        },
      ).first;

      expect(group.coldigomMeta?.rhythm, 'Básico');
      expect(group.isColdigom, isTrue);
      expect(group.flatPdfMaterials.map((e) => e.categoria), [
        'Partitura',
        'Cifra',
      ]);
    });
  });
}
