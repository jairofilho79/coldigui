import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromLouvores agrupa PDF e áudio no mesmo groupId', () {
    final louvor = Louvor.fromManifest(
      nome: 'Grande Deus',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Coletânea',
      pdf: 'a.pdf',
      pdfId: 'pdf1',
      groupId: 'praise-1',
      source: LouvorDataSource.coldigom,
    );
    const track = AudioTrack(
      audioId: 'audio1',
      r2Key: 'assets/praises/praise-1/a.mp3',
      nome: 'Grande Deus',
      numero: '001',
      groupId: 'praise-1',
      categoria: 'Áudio',
      classificacao: 'Coletânea',
    );

    final groups = LouvorGroup.fromLouvores([louvor], audioTracks: [track]);

    expect(groups, hasLength(1));
    expect(groups.first.totalPdfs, 1);
    expect(groups.first.audioTracks, hasLength(1));
    expect(groups.first.totalMaterials, 2);
  });

  test('fromLouvores cria grupo só com áudio', () {
    const track = AudioTrack(
      audioId: 'audio1',
      r2Key: 'assets/praises/praise-1/a.mp3',
      nome: 'Grande Deus',
      numero: '001',
      groupId: 'praise-1',
      categoria: 'Áudio',
      classificacao: 'Coletânea',
    );

    final groups = LouvorGroup.fromLouvores(const [], audioTracks: [track]);
    expect(groups, hasLength(1));
    expect(groups.first.totalPdfs, 0);
    expect(groups.first.audioTracks, hasLength(1));
    expect(groups.first.primaryLouvor, isNull);
  });

  test('fromLouvores agrupa YouTube e conta em totalMaterials', () {
    final louvor = Louvor.fromManifest(
      nome: 'Leão',
      numero: '010',
      categoria: 'Partitura',
      classificacao: 'Fox',
      pdf: 'a.pdf',
      pdfId: 'pdf1',
      groupId: 'praise-1',
      source: LouvorDataSource.coldigom,
    );
    const yt = YoutubeMaterial(
      id: 'yt1',
      url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
      nome: 'Leão',
      numero: '010',
      groupId: 'praise-1',
      categoria: 'Áudio',
      classificacao: 'Fox',
    );

    final groups = LouvorGroup.fromLouvores([louvor], youtubeMaterials: [yt]);

    expect(groups, hasLength(1));
    expect(groups.first.youtubeMaterials, hasLength(1));
    expect(groups.first.totalMaterials, 2);
  });

  test('fromLouvores cria grupo só com YouTube', () {
    const yt = YoutubeMaterial(
      id: 'yt1',
      url: 'https://youtu.be/1Pks43ceAac',
      nome: 'Leão',
      numero: '010',
      groupId: 'praise-1',
      categoria: 'Áudio',
      classificacao: 'Fox',
    );

    final groups = LouvorGroup.fromLouvores(const [], youtubeMaterials: [yt]);
    expect(groups, hasLength(1));
    expect(groups.first.nome, 'Leão');
    expect(groups.first.numero, '010');
    expect(groups.first.totalPdfs, 0);
    expect(groups.first.youtubeMaterials, hasLength(1));
    expect(groups.first.primaryLouvor, isNull);
  });
}
