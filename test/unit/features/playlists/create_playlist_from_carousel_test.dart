import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_carousel_exception.dart';
import 'package:coldigui/features/playlists/domain/usecases/create_playlist_from_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CarouselRepositoryImpl carouselRepository;
  late PlaylistRepositoryImpl playlistRepository;
  late CreatePlaylistFromCarousel useCase;


  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('create_playlist_');
    isar = Isar.open(schemas: [CarouselEntrySchema, PlaylistSchema],
      directory: tempDir.path,
    );
    carouselRepository = CarouselRepositoryImpl(CarouselLocalDatasource(isar));
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = CreatePlaylistFromCarousel(
      carouselRepository,
      playlistRepository,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cria playlist com snapshot do carousel', () async {
    await carouselRepository.add('pdf-a');
    await carouselRepository.add('pdf-b');

    final id = await useCase(nome: 'Minha lista');

    final saved = await playlistRepository.getById(id);
    expect(saved?.nome, 'Minha lista');
    expect(saved?.pdfIds, ['pdf-a', 'pdf-b']);
  });

  test('usa nome default quando nome omitido', () async {
    await carouselRepository.add('pdf-a');

    final id = await useCase();

    final saved = await playlistRepository.getById(id);
    expect(saved?.nome, startsWith('lista '));
  });

  test('lança EmptyCarouselException quando carousel vazio', () async {
    expect(() => useCase(), throwsA(isA<EmptyCarouselException>()));
  });
}
