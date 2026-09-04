// test/unit/features/playlists/playlist_material_order_test.dart
//
// Ordem única no Isar e no repositório. Os casos de entidade (projeções,
// `copyWith`, `replaceSubset`) vivem em `saved_playlist_entries_test.dart`.
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
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

/// Áudio real do Worker com container fora de `kAudioMaterialExtensions`.
final audioMisfiled = encodePdfId('assets/praises/a/001.mid');

void main() {
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
      List<PlaylistEntry>? entries,
      List<String> pdfIds = const [],
      List<String> audioIds = const [],
      List<String> items = const [],
    }) {
      isar.write((isar) {
        final row = Playlist()
          ..id = isar.playlists.autoIncrement()
          ..playlistId = playlistId
          ..nome = 'Legada'
          ..pdfIds = pdfIds
          ..audioIds = audioIds
          ..items = items
          ..itemKinds = const []
          ..createdAt = DateTime.utc(2026, 8, 1)
          ..salva = true
          ..savedAt = DateTime.utc(2026, 8, 1)
          ..updatedAt = DateTime.utc(2026, 8, 1);
        isar.playlists.put(row);
      });
    }

    Playlist rawRow(String playlistId) =>
        isar.playlists.where().playlistIdEqualTo(playlistId).findFirst()!;

    test('leitura preenche items com pdfIds + audioIds e persiste', () async {
      writeLegacyRow(
        playlistId: 'legacy',
        pdfIds: [pdfA, pdfB],
        audioIds: [audioA],
      );

      final migrated = await datasource.findByPlaylistId('legacy');
      expect(migrated?.items, [pdfA, pdfB, audioA]);

      // Persistido: uma leitura crua (sem passar pela migração) já vê items.
      expect(rawRow('legacy').items, [pdfA, pdfB, audioA]);
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

    test(
      'linha legada com áudio misfiled fica na face de áudio (A8)',
      () async {
        writeLegacyRow(
          playlistId: 'legacy',
          pdfIds: [pdfA],
          audioIds: [audioMisfiled],
        );

        final playlist = await repository.getById('legacy');

        expect(
          playlist?.audioIds,
          [audioMisfiled],
          reason: 'row.audioIds é o veredito de quem gravou a linha',
        );
        expect(playlist?.pdfIds, [pdfA]);
      },
    );

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

  group('Migração lazy de itemKinds no Isar', () {
    late Directory tempDir;
    late Isar isar;
    late PlaylistLocalDatasource datasource;
    late PlaylistRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('playlist_kinds_');
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

    /// Linha da fatia 1: já tem `items`, ainda não tem `itemKinds`.
    void writeRowWithoutKinds({
      required String playlistId,
      required List<String> items,
      List<String> pdfIds = const [],
      List<String> audioIds = const [],
    }) {
      isar.write((isar) {
        final row = Playlist()
          ..id = isar.playlists.autoIncrement()
          ..playlistId = playlistId
          ..nome = 'Fatia 1'
          ..pdfIds = pdfIds
          ..audioIds = audioIds
          ..items = items
          ..itemKinds = const []
          ..createdAt = DateTime.utc(2026, 8, 1)
          ..salva = true
          ..savedAt = DateTime.utc(2026, 8, 1)
          ..updatedAt = DateTime.utc(2026, 8, 1)
          ..version = 4
          ..syncStatus = PlaylistSyncStatus.synced;
        isar.playlists.put(row);
      });
    }

    Playlist rawRow(String playlistId) =>
        isar.playlists.where().playlistIdEqualTo(playlistId).findFirst()!;

    test(
      'preenche itemKinds a partir de items + audioIds e persiste',
      () async {
        writeRowWithoutKinds(
          playlistId: 'p1',
          items: [pdfA, audioA],
          pdfIds: [pdfA],
          audioIds: [audioA],
        );

        await datasource.findByPlaylistId('p1');

        expect(rawRow('p1').itemKinds, ['pdf', 'audio']);
      },
    );

    test('audioIds vence a extensão na hora de derivar o kind (A8)', () async {
      writeRowWithoutKinds(
        playlistId: 'p1',
        items: [chordA, audioMisfiled],
        pdfIds: [chordA],
        audioIds: [audioMisfiled],
      );

      await datasource.findByPlaylistId('p1');

      expect(rawRow('p1').itemKinds, ['chord', 'audio']);
    });

    test('a migração não toca updatedAt, version nem syncStatus', () async {
      writeRowWithoutKinds(
        playlistId: 'p1',
        items: [pdfA, audioA],
        audioIds: [audioA],
      );

      await datasource.findByPlaylistId('p1');

      final raw = rawRow('p1');
      expect(raw.updatedAt.toUtc(), DateTime.utc(2026, 8, 1));
      expect(raw.version, 4);
      expect(raw.syncStatus, PlaylistSyncStatus.synced);
    });

    test('segunda leitura não regrava itemKinds', () async {
      writeRowWithoutKinds(
        playlistId: 'p1',
        items: [pdfA, audioA],
        audioIds: [audioA],
      );
      await datasource.findByPlaylistId('p1');

      // Marca a linha: se a migração rodar de novo, este valor é sobrescrito.
      isar.write((isar) {
        final row = isar.playlists.where().playlistIdEqualTo('p1').findFirst()!;
        row.itemKinds = ['audio', 'pdf'];
        isar.playlists.put(row);
      });

      await datasource.findByPlaylistId('p1');

      expect(
        rawRow('p1').itemKinds,
        ['audio', 'pdf'],
        reason: 'itemKinds.length == items.length ⇒ nada a migrar',
      );
    });

    test('linha vazia não vira escrita', () async {
      writeRowWithoutKinds(playlistId: 'vazia', items: const []);

      await datasource.findByPlaylistId('vazia');

      expect(rawRow('vazia').itemKinds, isEmpty);
    });

    test('a linha migrada de items ganha itemKinds na mesma leitura', () async {
      // Linha pré-fatia-1: sem `items` e sem `itemKinds`.
      isar.write((isar) {
        isar.playlists.put(
          Playlist()
            ..id = isar.playlists.autoIncrement()
            ..playlistId = 'antiga'
            ..nome = 'Legada'
            ..pdfIds = [pdfA, chordA]
            ..audioIds = [audioA]
            ..items = const []
            ..itemKinds = const []
            ..createdAt = DateTime.utc(2026, 8, 1)
            ..salva = true
            ..updatedAt = DateTime.utc(2026, 8, 1),
        );
      });

      await datasource.findByPlaylistId('antiga');

      final raw = rawRow('antiga');
      expect(raw.items, [pdfA, chordA, audioA]);
      expect(raw.itemKinds, ['pdf', 'chord', 'audio']);
    });

    test('entries da entidade saem de items + itemKinds', () async {
      writeRowWithoutKinds(
        playlistId: 'p1',
        items: [pdfA, audioMisfiled, chordA],
        audioIds: [audioMisfiled],
      );

      final playlist = await repository.getById('p1');

      expect(playlist?.entries.map((e) => e.kind), [
        MaterialKind.pdf,
        MaterialKind.audio,
        MaterialKind.chord,
      ]);
      expect(playlist?.audioIds, [audioMisfiled]);
      expect(playlist?.pdfIds, [pdfA, chordA]);
    });

    test('itemKinds gravado vence a extensão na releitura', () async {
      // Grava explicitamente `unknown` para um id que a extensão diria `pdf`.
      isar.write((isar) {
        isar.playlists.put(
          Playlist()
            ..id = isar.playlists.autoIncrement()
            ..playlistId = 'p1'
            ..nome = 'Tipada'
            ..pdfIds = [pdfA]
            ..audioIds = const []
            ..items = [pdfA]
            ..itemKinds = ['youtube']
            ..createdAt = DateTime.utc(2026, 8, 1)
            ..salva = true
            ..updatedAt = DateTime.utc(2026, 8, 1),
        );
      });

      final playlist = await repository.getById('p1');

      expect(playlist?.entries.single.kind, MaterialKind.youtube);
      expect(playlist?.pdfIds, [
        pdfA,
      ], reason: 'youtube fica na face de leitura');
    });
  });

  group('PlaylistRepositoryImpl — escrita de itemKinds', () {
    late Directory tempDir;
    late Isar isar;
    late PlaylistRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('playlist_write_kinds_');
      isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
      repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    });

    tearDown(() async {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Playlist rawRow(String playlistId) =>
        isar.playlists.where().playlistIdEqualTo(playlistId).findFirst()!;

    test('create grava items, itemKinds e as duas projeções', () async {
      await repository.create(
        nome: 'Nova',
        pdfIds: [pdfA, chordA],
        audioIds: [audioMisfiled],
        playlistId: 'p1',
      );

      final raw = rawRow('p1');
      expect(raw.items, [pdfA, chordA, audioMisfiled]);
      expect(raw.itemKinds, ['pdf', 'chord', 'audio']);
      expect(raw.pdfIds, [pdfA, chordA]);
      expect(
        raw.audioIds,
        [audioMisfiled],
        reason: 'as colunas de compat são reprojetadas de entries no create',
      );
    });

    test('upsert grava itemKinds coerentes com entries', () async {
      await repository.upsert(
        SavedPlaylist(
          playlistId: 'p1',
          nome: 'Ensaio',
          entries: [
            PlaylistEntry.classified(pdfA),
            PlaylistEntry.audio(audioMisfiled),
          ],
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      );

      final raw = rawRow('p1');
      expect(raw.itemKinds, ['pdf', 'audio']);
      expect(raw.pdfIds, [pdfA]);
      expect(raw.audioIds, [audioMisfiled]);
    });

    test('update reescreve itemKinds junto com a ordem única', () async {
      await repository.upsert(
        SavedPlaylist(
          playlistId: 'p1',
          nome: 'Ensaio',
          entries: [
            PlaylistEntry.classified(pdfA),
            PlaylistEntry.audio(audioA),
          ],
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      );

      await repository.update('p1', pdfIds: [chordA, pdfA]);

      final raw = rawRow('p1');
      expect(raw.items, [chordA, pdfA, audioA]);
      expect(raw.itemKinds, ['chord', 'pdf', 'audio']);
    });

    test('round-trip pelo Isar preserva o kind declarado (A8)', () async {
      await repository.create(
        nome: 'Nova',
        pdfIds: [pdfA],
        audioIds: [audioMisfiled],
        playlistId: 'p1',
      );

      final reloaded = await repository.getById('p1');

      expect(reloaded?.audioIds, [audioMisfiled]);
      expect(reloaded?.entries.last.kind, MaterialKind.audio);
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
        SavedPlaylist.fromLegacyLists(
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

    test('update(pdfIds:) não consome o áudio misfiled (A8)', () async {
      await repository.upsert(
        SavedPlaylist.fromLegacyLists(
          playlistId: 'p1',
          nome: 'Ensaio',
          items: [pdfA, audioMisfiled],
          audioIds: [audioMisfiled],
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      );

      // Sync do carousel: reescreve só a face de partituras.
      await repository.update('p1', pdfIds: [pdfA, pdfB]);

      final updated = await repository.getById('p1');
      expect(updated?.items, [pdfA, pdfB, audioMisfiled]);
      expect(updated?.audioIds, [audioMisfiled]);
      expect(updated?.pdfIds, [pdfA, pdfB]);

      final raw = isar.playlists.where().playlistIdEqualTo('p1').findFirst();
      expect(
        raw?.audioIds,
        [audioMisfiled],
        reason: 'o veredito precisa sobreviver ao round-trip pelo Isar',
      );
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
        SavedPlaylist.fromLegacyLists(
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
