import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

LouvorGroup _remoteGroup(String praiseId) {
  final pdf = Louvor.fromManifest(
    nome: 'Ainda há tempo',
    numero: '001',
    categoria: 'Grade',
    classificacao: 'Básico',
    pdf: 'm-pdf.pdf',
    pdfId: encodePdfId('assets/praises/$praiseId/m-pdf.pdf'),
    groupId: praiseId,
    materialKindId: 'k-grade',
  );
  return LouvorGroup.fromLouvores(
    [pdf],
    audioTracks: [
      AudioTrack(
        audioId: encodePdfId('assets/praises/$praiseId/m-mp3.mp3'),
        r2Key: 'assets/praises/$praiseId/m-mp3.mp3',
        nome: 'Ainda há tempo',
        numero: '001',
        groupId: praiseId,
        categoria: 'Playback',
        classificacao: 'Básico',
        materialKindId: 'k-play',
      ),
    ],
    chordMaterials: [
      ChordMaterial(
        chordId: encodePdfId('assets/praises/$praiseId/m-chord.chord'),
        r2Key: 'assets/praises/$praiseId/m-chord.chord',
        nome: 'Ainda há tempo',
        numero: '001',
        groupId: praiseId,
        categoria: 'Cifra',
        classificacao: 'Básico',
        materialKindId: 'k-cifra',
      ),
    ],
    youtubeMaterials: [
      YoutubeMaterial(
        id: 'yt-1',
        url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
        nome: 'Ainda há tempo',
        numero: '001',
        groupId: praiseId,
        categoria: 'Vídeo',
        classificacao: 'Básico',
      ),
    ],
    coldigomMetaByGroupId: {
      praiseId: const ColdigomPraiseMetadata(
        name: 'Ainda há tempo',
        tonality: 'Dm',
        author: 'Autor',
        rhythm: 'Básico',
        category: 'Dm',
        tagNames: ['PES'],
      ),
    },
  ).single;
}

void main() {
  test('fromLouvorGroup reconstrói a linha a partir do grupo remoto', () {
    final row = ColdigomPraiseCacheMapper.fromLouvorGroup(_remoteGroup('p-9'));

    expect(row.praiseId, 'p-9');
    expect(row.number, '001');
    expect(row.name, 'Ainda há tempo');
    expect(row.author, 'Autor');
    expect(row.tonality, 'Dm');
    expect(row.tags, ['PES']);
    expect(row.lyrics, '');
    expect(
      row.searchTokens.split(' '),
      containsAll(['ainda', 'tempo', '001', 'pes', 'autor']),
    );
    final materials = {
      for (final m in ColdigomPraiseCacheMapper.decodeMaterials(row)) m.id: m,
    };
    expect(materials['m-pdf']!.type, 'pdf');
    expect(materials['m-pdf']!.r2Key, 'assets/praises/p-9/m-pdf.pdf');
    expect(materials['m-pdf']!.kindId, 'k-grade');
    expect(materials['m-pdf']!.kindName, 'Grade');
    expect(materials['m-mp3']!.type, 'mp3');
    expect(materials['m-chord']!.type, 'chord');
    expect(materials['yt-1']!.type, 'youtube');
    expect(materials['yt-1']!.url, isNotNull);
    expect(materials['yt-1']!.r2Key, isNull);
  });

  group('AdoptColdigomSearchNovelties', () {
    late Directory tempDir;
    late Isar isar;
    late ColdigomCatalogLocalDatasource local;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('adopt_');
      isar = Isar.open(
        schemas: [ColdigomPraiseCacheSchema],
        directory: tempDir.path,
        name: 'adopt_${DateTime.now().microsecondsSinceEpoch}',
      );
      local = ColdigomCatalogLocalDatasource(isar);
    });

    tearDown(() async {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test(
      'grava só os desconhecidos (nem no índice nem no Isar) e devolve os ids',
      () async {
        await local.upsertMany([
          ColdigomPraiseCacheMapper.fromLouvorGroup(_remoteGroup('p-isar')),
        ]);
        final usecase = AdoptColdigomSearchNovelties(local);

        final adopted = await usecase(
          [
            _remoteGroup('p-known'),
            _remoteGroup('p-isar'),
            _remoteGroup('p-new'),
          ],
          knownPraiseIds: {'p-known'},
        );

        expect(adopted, {'p-new'});
        expect(local.count(), 2);
        expect(local.findByPraiseIdSync('p-new')!.name, 'Ainda há tempo');
        expect(local.findByPraiseIdSync('p-known'), isNull);
      },
    );

    test(
      'grupo remoto sem meta também é adotado (um espaço de ids só)',
      () async {
        final semMeta = LouvorGroup.fromLouvores([
          Louvor.fromManifest(
            nome: 'Aleluia',
            numero: '001',
            categoria: 'Partitura',
            classificacao: 'Coro',
            pdf: 'm1.pdf',
            pdfId: encodePdfId('assets/praises/p-sem-meta/m1.pdf'),
            groupId: 'p-sem-meta',
            praiseId: 'p-sem-meta',
          ),
        ]).single;

        expect(
          await AdoptColdigomSearchNovelties(local)([
            semMeta,
          ], knownPraiseIds: const {}),
          {'p-sem-meta'},
        );
      },
    );

    test('sem Isar devolve vazio sem lançar', () async {
      expect(
        await const AdoptColdigomSearchNovelties(
          ColdigomCatalogLocalDatasource.unavailable(),
        )([_remoteGroup('p-new')], knownPraiseIds: const {}),
        isEmpty,
      );
    });
  });
}
