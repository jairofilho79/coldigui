// test/unit/features/catalog/preferred_material_for_group_test.dart
//
// C5: `preferredMaterialForGroup` resolve o material do «+» sempre visível —
// primeiro favorito disponível no grupo (por `rank`); sem favorito
// disponível, cai no fallback fixo: PDF principal > único áudio > primeiro
// extra adicionável > null.
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/utils/preferred_material_for_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  String categoria = 'Partitura',
  String pdfId = 'pdf1',
  String? materialKindId,
}) {
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
    materialKindId: materialKindId,
  );
}

AudioTrack _audio(String id, {String? materialKindId}) {
  return AudioTrack(
    audioId: id,
    r2Key: 'assets/praises/g1/$id.mp3',
    nome: 'Aleluia',
    numero: '001',
    groupId: 'g1',
    categoria: 'Áudio',
    classificacao: 'Básico',
    materialKindId: materialKindId,
  );
}

ChordMaterial _chord(String id, {String? materialKindId}) {
  return ChordMaterial(
    chordId: id,
    r2Key: 'assets/praises/g1/$id.chord',
    nome: 'Aleluia',
    numero: '001',
    groupId: 'g1',
    categoria: 'Cifra',
    classificacao: 'Básico',
    materialKindId: materialKindId,
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

  test(
    'com favoritos: devolve o áudio favorito mesmo havendo PDF principal',
    () {
      final group = LouvorGroup.fromLouvores([
        _louvor(materialKindId: 'kind-partitura'),
      ], audioTracks: [_audio('a1', materialKindId: 'kind-audio')]).first;

      final material = preferredMaterialForGroup(
        group,
        rank: const {'kind-audio': 0},
      );

      expect(material, isA<AudioMaterial>());
      expect((material! as AudioMaterial).track.audioId, 'a1');
    },
  );

  test('com favoritos: respeita a posição do rank entre vários candidatos', () {
    final group = LouvorGroup.fromLouvores([
      _louvor(materialKindId: 'kind-partitura'),
    ], audioTracks: [_audio('a1', materialKindId: 'kind-audio')]).first;

    final material = preferredMaterialForGroup(
      group,
      // Áudio é favorito nº 1 (posição 0), mas Partitura é favorito nº 2
      // (posição 1) — o favorito de melhor posição vence.
      rank: const {'kind-audio': 1, 'kind-partitura': 0},
    );

    expect(material, isA<PdfMaterial>());
    expect((material! as PdfMaterial).louvor.pdfId, 'pdf1');
  });

  test(
    'com favoritos mas nenhum presente no grupo: cai no fallback (PDF principal)',
    () {
      final group = LouvorGroup.fromLouvores([
        _louvor(materialKindId: 'kind-partitura'),
      ]).first;

      final material = preferredMaterialForGroup(
        group,
        rank: const {'kind-nao-presente': 0},
      );

      expect(material, isA<PdfMaterial>());
      expect((material! as PdfMaterial).louvor.pdfId, 'pdf1');
    },
  );

  test('favoritos não escolhem cifra/YouTube — não são adicionáveis', () {
    final group = LouvorGroup(
      groupId: 'g1',
      numero: '001',
      nome: 'Aleluia',
      sections: const [],
      extras: [
        ChordMaterialRef(_chord('c1', materialKindId: 'kind-cifra')),
        AudioMaterial(_audio('a1', materialKindId: 'kind-audio')),
      ],
    );

    final material = preferredMaterialForGroup(
      group,
      // Cifra é favorito nº 1, mas cifra não é adicionável à lista — o
      // favorito adicionável (áudio) vence mesmo com posição pior.
      rank: const {'kind-cifra': 0, 'kind-audio': 1},
    );

    expect(material, isA<AudioMaterial>());
    expect((material! as AudioMaterial).track.audioId, 'a1');
  });
}
