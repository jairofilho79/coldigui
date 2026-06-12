import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/usecases/ensure_playlist_for_louvor.dart';
import 'package:coldigui/features/playlists/domain/usecases/load_playlist_into_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl playlistRepo;
  late EnsurePlaylistForLouvor useCase;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ensure_pl_');
    isar = await Isar.open(
      [PlaylistSchema, CarouselEntrySchema],
      directory: tempDir.path,
    );
    playlistRepo = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    final carouselRepo = CarouselRepositoryImpl(CarouselLocalDatasource(isar));
    useCase = EnsurePlaylistForLouvor(
      playlistRepo,
      LoadPlaylistIntoCarousel(playlistRepo, carouselRepo),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reutiliza lista ativa quando pdfId já está nela', () async {
    final id = await playlistRepo.create(
      nome: 'Lista',
      pdfIds: ['pdf-a', 'pdf-b'],
      playlistId: 'active',
      salva: false,
    );

    final result = await useCase(
      pdfId: 'pdf-b',
      activePlaylistId: id,
    );

    expect(result.createdNew, isFalse);
    expect(result.playlistId, 'active');
  });

  test('cria nova lista não salva quando pdfId não está na ativa', () async {
    await playlistRepo.create(
      nome: 'Lista',
      pdfIds: ['pdf-a'],
      playlistId: 'active',
      salva: false,
    );

    final result = await useCase(
      pdfId: 'pdf-b',
      activePlaylistId: 'active',
    );

    expect(result.createdNew, isTrue);
    final created = await playlistRepo.getById(result.playlistId);
    expect(created?.salva, isFalse);
    expect(created?.pdfIds, ['pdf-b']);
  });
}
