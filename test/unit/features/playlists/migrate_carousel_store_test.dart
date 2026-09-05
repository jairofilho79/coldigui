import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/usecases/migrate_carousel_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _pdfB = encodePdfId('ColAdultos/002.pdf');

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl playlists;
  late CarouselLocalDatasource carousel;
  late MigrateCarouselStore migrate;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migrate_carousel_');
    isar = Isar.open(
      schemas: [PlaylistSchema, CarouselEntrySchema],
      directory: tempDir.path,
    );
    playlists = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    carousel = CarouselLocalDatasource(isar);
    migrate = MigrateCarouselStore(carousel, playlists);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> seedCarousel(List<String> ids) async {
    await isar.write((isar) {
      final coll = isar.carouselEntrys;
      for (var i = 0; i < ids.length; i++) {
        final entry = CarouselEntry()
          ..id = coll.autoIncrement()
          ..pdfId = ids[i]
          ..sortOrder = i;
        coll.put(entry);
      }
    });
  }

  test('MigrateCarouselStore: vazio → nada', () async {
    final outcome = await migrate(activePlaylistId: null);

    expect(outcome.createdPlaylistId, isNull);
    expect(outcome.migratedIds, 0);
    expect(await playlists.getAll(), isEmpty);
  });

  test('MigrateCarouselStore: sem ativa → cria rascunho e limpa', () async {
    await seedCarousel([_pdfA, _pdfB]);

    final outcome = await migrate(activePlaylistId: null);

    expect(outcome.createdPlaylistId, isNotNull);
    expect(outcome.migratedIds, 2);
    final created = await playlists.getById(outcome.createdPlaylistId!);
    expect(created!.salva, isFalse);
    expect(created.items, [_pdfA, _pdfB]);
    expect(created.entries.first.kind, MaterialKind.pdf);
    expect(await carousel.getOrderedPdfIds(), isEmpty);
  });

  test('MigrateCarouselStore: com ativa → só limpa', () async {
    await seedCarousel([_pdfA, _pdfB]);
    await playlists.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: 'outro', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );

    final outcome = await migrate(activePlaylistId: 'p1');

    expect(outcome.createdPlaylistId, isNull);
    expect(outcome.migratedIds, 2);
    expect((await playlists.getById('p1'))!.items, ['outro']);
    expect(await playlists.getAll(), hasLength(1));
    expect(await carousel.getOrderedPdfIds(), isEmpty);
  });

  test('MigrateCarouselStore: id ativo órfão → cria rascunho', () async {
    await seedCarousel([_pdfA]);

    final outcome = await migrate(activePlaylistId: 'sumiu');

    expect(outcome.createdPlaylistId, isNotNull);
    expect(await carousel.getOrderedPdfIds(), isEmpty);
  });

  test('sem Isar não roda e não apaga nada', () async {
    final semIsar = MigrateCarouselStore(
      const CarouselLocalDatasource.unavailable(),
      playlists,
    );

    final outcome = await semIsar(activePlaylistId: null);

    expect(outcome.migratedIds, 0);
    expect(outcome.createdPlaylistId, isNull);
  });
}
