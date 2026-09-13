// test/unit/features/catalog/preferred_material_for_group_test.dart
//
// C5: `preferredMaterialForGroup` resolve o material do «+» sempre visível —
// PDF principal > único áudio > primeiro extra adicionável > null.
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/utils/preferred_material_for_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({String categoria = 'Partitura', String pdfId = 'pdf1'}) {
  return Louvor(
    nome: 'Aleluia',
    numero: '001',
    categoria: categoria,
    classificacao: 'Básico',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'g1',
    searchTitleNorm: 'aleluia',
    searchContentTokens: const [],
    searchCompactContent: '',
  );
}

AudioTrack _audio(String id) {
  return AudioTrack(
    audioId: id,
    r2Key: 'assets/praises/g1/$id.mp3',
    nome: 'Aleluia',
    numero: '001',
    groupId: 'g1',
    categoria: 'Áudio',
    classificacao: 'Básico',
  );
}

ChordMaterial _chord(String id) {
  return ChordMaterial(
    chordId: id,
    r2Key: 'assets/praises/g1/$id.chord',
    nome: 'Aleluia',
    numero: '001',
    groupId: 'g1',
    categoria: 'Cifra',
    classificacao: 'Básico',
  );
}

YoutubeMaterial _youtube(String id) {
  return YoutubeMaterial(
    id: id,
    url: 'https://youtu.be/$id',
    nome: 'Aleluia',
    numero: '001',
    groupId: 'g1',
    categoria: 'YouTube',
    classificacao: 'Básico',
  );
}

void main() {
  test('grupo com PDF: devolve o PDF principal', () {
    final group = LouvorGroup.fromLouvores([_louvor()]).first;

    final material = preferredMaterialForGroup(group);

    expect(material, isA<PdfMaterial>());
    expect((material! as PdfMaterial).louvor.pdfId, 'pdf1');
  });

  test('sem PDF, um único áudio: devolve o áudio', () {
    final group = LouvorGroup(
      groupId: 'g1',
      numero: '001',
      nome: 'Aleluia',
      sections: const [],
      audioTracks: [_audio('a1')],
    );

    final material = preferredMaterialForGroup(group);

    expect(material, isA<AudioMaterial>());
    expect((material! as AudioMaterial).track.audioId, 'a1');
  });

  test(
    'sem PDF, mais de um áudio: devolve o primeiro extra adicionável (áudio, não cifra)',
    () {
      final group = LouvorGroup(
        groupId: 'g1',
        numero: '001',
        nome: 'Aleluia',
        sections: const [],
        extras: [
          ChordMaterialRef(_chord('c1')),
          AudioMaterial(_audio('a1')),
          AudioMaterial(_audio('a2')),
        ],
      );

      final material = preferredMaterialForGroup(group);

      expect(material, isA<AudioMaterial>());
      expect((material! as AudioMaterial).track.audioId, 'a1');
    },
  );

  test('nada adicionável (só cifra/YouTube): devolve null', () {
    final group = LouvorGroup(
      groupId: 'g1',
      numero: '001',
      nome: 'Aleluia',
      sections: const [],
      extras: [
        ChordMaterialRef(_chord('c1')),
        YoutubeMaterialRef(_youtube('y1')),
      ],
    );

    final material = preferredMaterialForGroup(group);

    expect(material, isNull);
  });
}
