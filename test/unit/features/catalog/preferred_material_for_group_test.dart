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
    'sem PDF, mais de um áudio: devolve o primeiro extra adicionável (cifra)',
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

      expect(material, isA<ChordMaterialRef>());
      expect(material?.id, 'c1');
    },
  );

  test('cifra e YouTube: devolve a cifra adicionável', () {
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

    expect(material?.id, 'c1');
  });

  test('só YouTube continua sem material adicionável', () {
    final group = LouvorGroup(
      groupId: 'g1',
      numero: '001',
      nome: 'Aleluia',
      sections: const [],
      youtubeMaterials: [_youtube('y1')],
    );
    expect(preferredMaterialForGroup(group), isNull);
  });

  test('áudio salvo por versão anterior não participa dos favoritos', () {
    final group = LouvorGroup.fromLouvores(
      [_louvor(materialKindId: 'kind-partitura')],
      audioTracks: [_audio('a1', materialKindId: 'kind-audio')],
    ).first;

    final material = preferredMaterialForGroup(
      group,
      rank: const {'kind-audio': 0},
    );

    expect(material, isA<PdfMaterial>());
    expect(material?.id, 'pdf1');
  });

  test('com favoritos: respeita a posição do rank entre vários candidatos', () {
    final group = LouvorGroup.fromLouvores(
      [_louvor(materialKindId: 'kind-partitura')],
      audioTracks: [_audio('a1', materialKindId: 'kind-audio')],
    ).first;

    final material = preferredMaterialForGroup(
      group,
      // Áudio é favorito nº 1 (posição 0), mas Partitura é favorito nº 2
      // (posição 1) — o favorito de melhor posição vence.
      rank: const {'kind-audio': 1, 'kind-partitura': 0},
    );

    expect(material, isA<PdfMaterial>());
    expect((material! as PdfMaterial).louvor.pdfId, 'pdf1');
  });

  test('com favoritos mas nenhum presente no grupo: cai no fallback (PDF principal)', () {
    final group = LouvorGroup.fromLouvores([
      _louvor(materialKindId: 'kind-partitura'),
    ]).first;

    final material = preferredMaterialForGroup(
      group,
      rank: const {'kind-nao-presente': 0},
    );

    expect(material, isA<PdfMaterial>());
    expect((material! as PdfMaterial).louvor.pdfId, 'pdf1');
  });

  test('favorito de cifra pode ser escolhido para adicionar à playlist', () {
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
      // Cifra e áudio são adicionáveis; o favorito nº 1 vence.
      rank: const {'kind-cifra': 0, 'kind-audio': 1},
    );

    expect(material, isA<ChordMaterialRef>());
    expect(material?.id, 'c1');
  });

  test('mesmo kind usa o formato preferido em vez do primeiro PDF', () {
    final group = LouvorGroup.fromLouvores(
      [_louvor(materialKindId: 'kind-cifra')],
      chordMaterials: [_chord('c1', materialKindId: 'kind-cifra')],
    ).first;
    expect(
      preferredMaterialForGroup(
        group,
        rank: const {'kind-cifra': 0},
        preferredTypes: const {'kind-cifra': 'chord'},
      )?.id,
      'c1',
    );
  });

  test('formato indisponível cai no outro formato do mesmo favorito', () {
    final group = LouvorGroup.fromLouvores([
      _louvor(materialKindId: 'kind-cifra'),
    ]).first;
    expect(
      preferredMaterialForGroup(
        group,
        rank: const {'kind-cifra': 0},
        preferredTypes: const {'kind-cifra': 'chord'},
      )?.id,
      'pdf1',
    );
  });

  test('ordem das categorias vence a preferência por formato', () {
    final group = LouvorGroup.fromLouvores(
      [_louvor(materialKindId: 'kind-partitura')],
      chordMaterials: [_chord('c1', materialKindId: 'kind-cifra')],
    ).first;
    expect(
      preferredMaterialForGroup(
        group,
        rank: const {'kind-partitura': 0, 'kind-cifra': 1},
        preferredTypes: const {'kind-cifra': 'chord'},
      )?.id,
      'pdf1',
    );
  });

  test('letra pode ser o primeiro favorito mesmo sem material kind', () {
    final group = LouvorGroup.fromLouvores(
      [_louvor(materialKindId: 'kind-partitura')],
      lyricsByGroupId: const {
        'g1': LyricsMaterial(praiseId: 'g1', nome: 'Aleluia', numero: '001'),
      },
    ).first;
    expect(
      preferredMaterialForGroup(group, rank: const {'type:lyrics': 0})?.id,
      'lyrics:g1',
    );
  });
}
