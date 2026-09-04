// test/unit/features/playlists/playlist_material_order_test.dart
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/usecases/update_playlist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

/// Ids realistas — mesmo codec do manifest/Coldigom.
final pdfA = encodePdfId('ColAdultos/001.pdf');
final pdfB = encodePdfId('ColAdultos/002.pdf');
final pdfC = encodePdfId('ColAdultos/003.pdf');
final chordA = encodePdfId('ColAdultos/001.chord');
final audioA = encodePdfId('assets/praises/a/001.mp3');
final audioB = encodePdfId('assets/praises/b/002.mp3');

SavedPlaylist _playlist({
  List<String>? items,
  List<String> pdfIds = const [],
  List<String> audioIds = const [],
}) {
  return SavedPlaylist(
    playlistId: 'p1',
    nome: 'Lista',
    items: items,
    pdfIds: pdfIds,
    audioIds: audioIds,
    createdAt: DateTime.utc(2026, 9, 1),
  );
}

void main() {
  group('SavedPlaylist — projeções derivadas', () {
    test('pdfIds e audioIds derivam de items pela ordem única', () {
      final playlist = _playlist(items: [pdfA, audioA, chordA, pdfB, audioB]);

      expect(playlist.pdfIds, [pdfA, chordA, pdfB]);
      expect(playlist.audioIds, [audioA, audioB]);
    });

    test('cifra entra em pdfIds e não em audioIds', () {
      final playlist = _playlist(items: [chordA]);

      expect(playlist.pdfIds, [chordA]);
      expect(playlist.audioIds, isEmpty);
    });

    test('id legado indecifrável fica com os PDFs', () {
      final playlist = _playlist(items: ['legado-sem-base64!!!', audioA]);

      expect(playlist.pdfIds, ['legado-sem-base64!!!']);
      expect(playlist.audioIds, [audioA]);
    });

    test('round-trip: construtor de compat devolve as mesmas listas', () {
      final playlist = _playlist(
        pdfIds: [pdfA, chordA, pdfB],
        audioIds: [audioA, audioB],
      );

      expect(playlist.items, [pdfA, chordA, pdfB, audioA, audioB]);
      expect(playlist.pdfIds, [pdfA, chordA, pdfB]);
      expect(playlist.audioIds, [audioA, audioB]);
    });

    test('items tem precedência sobre pdfIds/audioIds', () {
      final playlist = _playlist(
        items: [audioA, pdfA],
        pdfIds: [pdfB],
        audioIds: [audioB],
      );

      expect(playlist.items, [audioA, pdfA]);
    });
  });

  group('SavedPlaylist.copyWith — substituição parcial de face', () {
    test('reorder de pdfIds preserva a posição dos áudios', () {
      final before = _playlist(items: [pdfA, audioA, pdfB, audioB, pdfC]);

      final after = before.copyWith(pdfIds: [pdfC, pdfB, pdfA]);

      expect(after.items, [pdfC, audioA, pdfB, audioB, pdfA]);
      expect(after.audioIds, [audioA, audioB]);
    });

    test('remoção de PDF apaga o slot e não move os áudios', () {
      final before = _playlist(items: [pdfA, audioA, pdfB, audioB]);

      final after = before.copyWith(pdfIds: [pdfB]);

      expect(after.items, [pdfB, audioA, audioB]);
    });

    test('PDF novo entra logo depois do último slot PDF', () {
      final before = _playlist(items: [pdfA, audioA, pdfB, audioB]);

      final after = before.copyWith(pdfIds: [pdfA, pdfB, pdfC]);

      expect(after.items, [pdfA, audioA, pdfB, pdfC, audioB]);
    });

    test('sem slot PDF anterior, os novos PDFs vão para o fim', () {
      final before = _playlist(items: [audioA, audioB]);

      final after = before.copyWith(pdfIds: [pdfA]);

      expect(after.items, [audioA, audioB, pdfA]);
      expect(after.audioIds, [audioA, audioB]);
    });

    test('áudio novo entra depois do último slot de áudio', () {
      final before = _playlist(items: [pdfA, audioA, pdfB]);

      final after = before.copyWith(audioIds: [audioA, audioB]);

      expect(after.items, [pdfA, audioA, audioB, pdfB]);
      expect(after.pdfIds, [pdfA, pdfB]);
    });

    test('remoção de áudio não move os PDFs', () {
      final before = _playlist(items: [pdfA, audioA, pdfB, audioB]);

      final after = before.copyWith(audioIds: [audioB]);

      expect(after.items, [pdfA, audioB, pdfB]);
    });

    test('items explícito ignora as duas projeções', () {
      final before = _playlist(items: [pdfA, audioA]);

      final after = before.copyWith(items: [audioA, pdfA], pdfIds: [pdfB]);

      expect(after.items, [audioA, pdfA]);
    });

    test('copyWith sem listas mantém a ordem única', () {
      final before = _playlist(items: [pdfA, audioA, pdfB]);

      expect(before.copyWith(nome: 'Outro').items, [pdfA, audioA, pdfB]);
    });

    test('áudio com container não reconhecido não é perdido', () {
      // `type: mp3` no worker, extensão fora de kAudioMaterialExtensions: o id
      // não classifica como áudio, mas o chamador o declarou em `audioIds:`.
      // Ele entra em `items` (e cai na face de partituras) em vez de sumir.
      final estranho = encodePdfId('assets/praises/a/001.mid');
      expect(materialIdKindOf(estranho), isNot(MaterialKind.audio));

      final before = _playlist(items: [pdfA, audioA]);
      final after = before.copyWith(audioIds: [audioA, estranho]);

      expect(after.items, [pdfA, audioA, estranho]);
      expect(after.audioIds, [audioA]);
      expect(after.pdfIds, [pdfA, estranho]);
    });

    test('reordenar a face de áudio com id estranho é estável', () {
      final estranho = encodePdfId('assets/praises/a/001.mid');
      final before = _playlist(items: [pdfA, audioA, estranho]);

      // Idempotente: repassar a mesma face não move nada.
      final after = before.copyWith(audioIds: [audioA, estranho]);

      expect(after.items, [pdfA, audioA, estranho]);
    });
  });

  group('Migração lazy no Isar', () {
    late Directory tempDir;
    late Isar isar;
    late PlaylistLocalDatasource datasource;
    late PlaylistRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('playlist_items_');
      isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
      datasource = PlaylistLocalDatasource(isar);
      repository = PlaylistRepositoryImpl(datasource);
    });

    tearDown(() async {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    void writeLegacyRow({
      required String playlistId,
      required List<String> pdfIds,
      List<String> audioIds = const [],
    }) {
      isar.write((isar) {
        final row = Playlist()
          ..id = isar.playlists.autoIncrement()
          ..playlistId = playlistId
          ..nome = 'Legada'
          ..pdfIds = pdfIds
          ..audioIds = audioIds
          ..items = const []
          ..createdAt = DateTime.utc(2026, 8, 1)
          ..salva = true
          ..savedAt = DateTime.utc(2026, 8, 1)
          ..updatedAt = DateTime.utc(2026, 8, 1);
        isar.playlists.put(row);
      });
    }

    test('leitura preenche items com pdfIds + audioIds e persiste', () async {
      writeLegacyRow(
        playlistId: 'legacy',
        pdfIds: [pdfA, pdfB],
        audioIds: [audioA],
      );

      final migrated = await datasource.findByPlaylistId('legacy');
      expect(migrated?.items, [pdfA, pdfB, audioA]);

      // Persistido: uma leitura crua (sem passar pela migração) já vê items.
      final raw = isar.playlists
          .where()
          .playlistIdEqualTo('legacy')
          .findFirst();
      expect(raw?.items, [pdfA, pdfB, audioA]);
    });

    test('findAll migra em lote', () async {
      writeLegacyRow(playlistId: 'l1', pdfIds: [pdfA]);
      writeLegacyRow(playlistId: 'l2', pdfIds: [pdfB], audioIds: [audioB]);

      final rows = await datasource.findAll();

      expect(rows.map((r) => r.items), [
        [pdfA],
        [pdfB, audioB],
      ]);
    });

    test('não mexe em registro sem pdfIds nem audioIds', () async {
      writeLegacyRow(playlistId: 'vazia', pdfIds: const []);

      final row = await datasource.findByPlaylistId('vazia');
      expect(row?.items, isEmpty);
    });

    test('migração é idempotente', () async {
      writeLegacyRow(playlistId: 'l1', pdfIds: [pdfA], audioIds: [audioA]);

      await datasource.findAll();
      isar.write((isar) {
        final row = isar.playlists.where().playlistIdEqualTo('l1').findFirst()!;
        row.pdfIds = [pdfA, pdfB];
        isar.playlists.put(row);
      });

      final row = await datasource.findByPlaylistId('l1');
      expect(row?.items, [pdfA, audioA]);
    });

    test('entidade lida de linha legada expõe as duas projeções', () async {
      writeLegacyRow(
        playlistId: 'legacy',
        pdfIds: [pdfA, chordA],
        audioIds: [audioA],
      );

      final playlist = await repository.getById('legacy');
      expect(playlist?.items, [pdfA, chordA, audioA]);
      expect(playlist?.pdfIds, [pdfA, chordA]);
      expect(playlist?.audioIds, [audioA]);
    });
  });

  group('PlaylistRepositoryImpl.update — ordem única', () {
    late Directory tempDir;
    late Isar isar;
    late PlaylistRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('playlist_update_');
      isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
      repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    });

    tearDown(() async {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> seedInterleaved() async {
      await repository.upsert(
        SavedPlaylist(
          playlistId: 'p1',
          nome: 'Ensaio',
          items: [pdfA, audioA, pdfB, audioB],
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      );
    }

    test('update(pdfIds:) do carousel preserva os áudios', () async {
      await seedInterleaved();

      await repository.update('p1', pdfIds: [pdfB, pdfA]);

      final updated = await repository.getById('p1');
      expect(updated?.items, [pdfB, audioA, pdfA, audioB]);
      expect(updated?.audioIds, [audioA, audioB]);
      expect(updated?.pdfIds, [pdfB, pdfA]);
    });

    test('update(audioIds:) preserva os PDFs', () async {
      await seedInterleaved();

      await repository.update('p1', audioIds: [audioB]);

      final updated = await repository.getById('p1');
      expect(updated?.items, [pdfA, audioB, pdfB]);
      expect(updated?.pdfIds, [pdfA, pdfB]);
    });

    test('projeções gravadas em disco continuam coerentes', () async {
      await seedInterleaved();

      await repository.update('p1', pdfIds: [pdfB, pdfA, pdfC]);

      final raw = isar.playlists.where().playlistIdEqualTo('p1').findFirst();
      expect(raw?.items, [pdfB, audioA, pdfA, pdfC, audioB]);
      expect(raw?.pdfIds, [pdfB, pdfA, pdfC]);
      expect(raw?.audioIds, [audioA, audioB]);
    });

    test('create grava items concatenando as duas listas', () async {
      await repository.create(
        nome: 'Nova',
        pdfIds: [pdfA],
        audioIds: [audioA],
        playlistId: 'p2',
      );

      final created = await repository.getById('p2');
      expect(created?.items, [pdfA, audioA]);
    });
  });

  group('UpdatePlaylist — mutações de add/remove sobre a ordem única', () {
    late Directory tempDir;
    late Isar isar;
    late PlaylistRepositoryImpl repository;
    late UpdatePlaylist updatePlaylist;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('playlist_mutations_');
      isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
      repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
      updatePlaylist = UpdatePlaylist(repository);
      await repository.upsert(
        SavedPlaylist(
          playlistId: 'p1',
          nome: 'Ensaio',
          items: [pdfA, audioA, pdfB, audioB],
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      );
    });

    tearDown(() async {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Espelha `PlaylistsNotifier.removePdf`.
    Future<void> removePdf(String pdfId) async {
      final current = (await repository.getById('p1'))!;
      await updatePlaylist(
        playlistId: 'p1',
        pdfIds: current.pdfIds.where((id) => id != pdfId).toList(),
      );
    }

    /// Espelha `PlaylistsNotifier.removeAudio`.
    Future<void> removeAudio(String audioId) async {
      final current = (await repository.getById('p1'))!;
      await updatePlaylist(
        playlistId: 'p1',
        audioIds: current.audioIds.where((id) => id != audioId).toList(),
      );
    }

    /// Espelha `PlaylistsNotifier.addAudioToActivePlaylist`.
    Future<void> addAudio(String audioId) async {
      final current = (await repository.getById('p1'))!;
      await updatePlaylist(
        playlistId: 'p1',
        audioIds: [...current.audioIds, audioId],
      );
    }

    /// Espelha `syncActivePlaylistFromCarousel` (add de louvor e reorder).
    Future<void> syncFromCarousel(List<String> carouselPdfIds) {
      return updatePlaylist(playlistId: 'p1', pdfIds: carouselPdfIds);
    }

    test('removePdf tira um slot PDF e não mexe nos áudios', () async {
      await removePdf(pdfA);

      // O PDF que sobrou desliza para o primeiro slot PDF; os áudios ficam
      // onde estavam (é a regra de `SavedPlaylist.replaceSubset`).
      final updated = await repository.getById('p1');
      expect(updated?.items, [pdfB, audioA, audioB]);
      expect(updated?.audioIds, [audioA, audioB]);
    });

    test('removeAudio tira um slot de áudio e não mexe nos PDFs', () async {
      await removeAudio(audioA);

      final updated = await repository.getById('p1');
      expect(updated?.items, [pdfA, audioB, pdfB]);
      expect(updated?.pdfIds, [pdfA, pdfB]);
    });

    test('addAudio entra na ordem única sem mexer nos PDFs', () async {
      await addAudio(encodePdfId('assets/praises/c/003.mp3'));

      final updated = await repository.getById('p1');
      expect(updated?.pdfIds, [pdfA, pdfB]);
      expect(updated?.audioIds, [
        audioA,
        audioB,
        encodePdfId('assets/praises/c/003.mp3'),
      ]);
    });

    test('add de louvor via carousel preserva os áudios', () async {
      await syncFromCarousel([pdfA, pdfB, pdfC]);

      final updated = await repository.getById('p1');
      expect(updated?.items, [pdfA, audioA, pdfB, pdfC, audioB]);
      expect(updated?.audioIds, [audioA, audioB]);
    });

    test('reorder no carousel não mexe nos áudios', () async {
      await syncFromCarousel([pdfB, pdfA]);

      final updated = await repository.getById('p1');
      expect(updated?.items, [pdfB, audioA, pdfA, audioB]);
    });

    test('esvaziar as duas faces ainda apaga a playlist', () async {
      await updatePlaylist(playlistId: 'p1', pdfIds: const []);
      // Só a face de áudio sobrou — a playlist continua viva.
      expect((await repository.getById('p1'))?.items, [audioA, audioB]);

      await updatePlaylist(playlistId: 'p1', audioIds: const []);

      // Lista salva vira tombstone (comportamento pré-existente do delete).
      expect((await repository.getById('p1'))?.deletedAt, isNotNull);
    });
  });
}
