import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/exceptions/invalid_share_playlist_exception.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:coldigui/features/playlists/domain/usecases/load_playlist_into_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CarouselRepositoryImpl carouselRepository;
  late PlaylistRepositoryImpl playlistRepository;
  late ImportSharedPlaylistFromUrl useCase;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_playlist_');
    isar = await Isar.open(
      [CarouselEntrySchema, PlaylistSchema],
      directory: tempDir.path,
    );
    carouselRepository = CarouselRepositoryImpl(CarouselLocalDatasource(isar));
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      LoadPlaylistIntoCarousel(playlistRepository, carouselRepository),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cria playlist e carrega carousel', () async {
    await carouselRepository.add('pdf-old');

    final id = await useCase(
      sharePdfs: 'pdf-a, pdf-b',
      shareName: 'Lista importada',
    );

    final saved = await playlistRepository.getById(id);
    expect(saved?.nome, 'Lista importada');
    expect(saved?.pdfIds, ['pdf-a', 'pdf-b']);
    expect(await carouselRepository.getOrderedPdfIds(), ['pdf-a', 'pdf-b']);
  });

  test('preserva ordem dos pdfIds', () async {
    await useCase(
      sharePdfs: 'z,y,x',
      shareName: 'Ordem',
    );

    final all = await playlistRepository.getAll();
    expect(all.single.pdfIds, ['z', 'y', 'x']);
  });

  test('lança InvalidSharePlaylistException se sharePdfs vazio', () async {
    expect(
      () => useCase(sharePdfs: ' , ', shareName: 'Nome'),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
  });

  test('lança InvalidSharePlaylistException se shareName vazio', () async {
    expect(
      () => useCase(sharePdfs: 'a,b', shareName: '  '),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
  });
}
