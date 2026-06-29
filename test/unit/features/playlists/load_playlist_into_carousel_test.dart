import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:coldigui/features/playlists/domain/usecases/load_playlist_into_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CarouselRepositoryImpl carouselRepository;
  late PlaylistRepositoryImpl playlistRepository;
  late LoadPlaylistIntoCarousel useCase;


  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('load_playlist_');
    isar = Isar.open(schemas: [CarouselEntrySchema, PlaylistSchema],
      directory: tempDir.path,
    );
    carouselRepository = CarouselRepositoryImpl(CarouselLocalDatasource(isar));
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = LoadPlaylistIntoCarousel(
      playlistRepository,
      carouselRepository,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('substitui carousel com pdfIds da playlist', () async {
    await carouselRepository.add('pdf-old');
    final playlistId = await playlistRepository.create(
      nome: 'Ensaio',
      pdfIds: ['pdf-a', 'pdf-b'],
    );

    await useCase(playlistId: playlistId);

    expect(await carouselRepository.getOrderedPdfIds(), ['pdf-a', 'pdf-b']);
  });

  test('preserva ordem dos pdfIds', () async {
    final playlistId = await playlistRepository.create(
      nome: 'Ordem',
      pdfIds: ['pdf-z', 'pdf-y', 'pdf-x'],
    );

    await useCase(playlistId: playlistId);

    expect(await carouselRepository.getOrderedPdfIds(), [
      'pdf-z',
      'pdf-y',
      'pdf-x',
    ]);
  });

  test('lança PlaylistNotFoundException quando playlist ausente', () async {
    expect(
      () => useCase(playlistId: 'missing-id'),
      throwsA(isA<PlaylistNotFoundException>()),
    );
  });

  test('playlist vazia limpa carousel', () async {
    await carouselRepository.add('pdf-old');
    final playlistId = await playlistRepository.create(
      nome: 'Vazia',
      pdfIds: const [],
    );

    await useCase(playlistId: playlistId);

    expect(await carouselRepository.getOrderedPdfIds(), isEmpty);
  });
}
