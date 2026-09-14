import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/lyrics/presentation/utils/lyrics_reader_url_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _praise = PraiseDetailDto(
  id: 'p-001',
  name: 'Ainda há tempo',
  number: '001',
  rhythm: 'Básico',
  materials: [],
);

void main() {
  test('materialKindOfRawType e materialIdKindOf reconhecem letra', () {
    expect(materialKindOfRawType('lyrics'), MaterialKind.lyrics);
    expect(materialKindOfRawType('LYRICS'), MaterialKind.lyrics);
    expect(materialIdKindOf('lyrics:p-001'), MaterialKind.lyrics);
    expect(materialIdKindOf('lyrics:'), MaterialKind.unknown);
  });

  test('adapter só cria LyricsMaterial quando há texto', () {
    expect(ColdigomLouvorAdapter.toLyricsMaterial(_praise, '   '), isNull);

    final lyrics = ColdigomLouvorAdapter.toLyricsMaterial(
      _praise,
      'Ainda há tempo\nde voltar',
    )!;

    expect(lyrics.id, 'lyrics:p-001');
    expect(lyrics.kind, MaterialKind.lyrics);
    expect(lyrics.groupId, 'p-001');
    expect(lyrics.categoria, 'Letra');
    expect(lyrics.materialKindId, isNull);
    expect(lyrics.text, 'Ainda há tempo\nde voltar');
    expect(canAddMaterialToPlaylist(lyrics), isFalse);
    expect(LouvorMaterialIcons.forMaterial(lyrics), Icons.subject);
  });

  test('LouvorGroup põe a letra no fim de extras e conta como Coldigom', () {
    final lyrics = ColdigomLouvorAdapter.toLyricsMaterial(_praise, 'texto')!;
    final group = LouvorGroup(
      groupId: 'p-001',
      numero: '001',
      nome: 'Ainda há tempo',
      sections: const [],
      lyrics: lyrics,
    );

    expect(group.extras.last, same(lyrics));
    expect(group.lyrics, same(lyrics));
    expect(group.isColdigom, isTrue);
    expect(group.totalMaterials, 1);
  });

  test('fromLouvores anexa a letra pelo groupId', () {
    final lyrics = ColdigomLouvorAdapter.toLyricsMaterial(_praise, 'texto')!;

    final groups = LouvorGroup.fromLouvores(
      const [],
      lyricsByGroupId: {'p-001': lyrics},
    );

    expect(groups.single.groupId, 'p-001');
    expect(groups.single.nome, 'Ainda há tempo');
    expect(groups.single.numero, '001');
    expect(groups.single.lyrics, same(lyrics));
  });

  test('buildLyricsReaderLocation monta /letra?praiseId=…&titulo=…', () {
    expect(
      buildLyricsReaderLocation(
        praiseId: 'p 1',
        titulo: 'Ainda há tempo',
        subtitulo: '001',
      ),
      '/letra?praiseId=p%201&titulo=Ainda%20h%C3%A1%20tempo&subtitulo=001',
    );
    expect(buildLyricsReaderLocation(praiseId: 'p1'), '/letra?praiseId=p1');
  });
}
