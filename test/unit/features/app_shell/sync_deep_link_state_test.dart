import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/app_shell/domain/usecases/sync_deep_link_state.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:coldigui/features/playlists/domain/usecases/load_playlist_into_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late SyncDeepLinkState useCase;


  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_deep_link_');
    isar = Isar.open(schemas: [CarouselEntrySchema, PlaylistSchema],
      directory: tempDir.path,
    );
    final carouselRepository =
        CarouselRepositoryImpl(CarouselLocalDatasource(isar));
    final playlistRepository =
        PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = SyncDeepLinkState(
      ImportSharedPlaylistFromUrl(
        playlistRepository,
        LoadPlaylistIntoCarousel(playlistRepository, carouselRepository),
      ),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('retorna skipped quando URI sem params de share', () async {
    final result = await useCase(uri: Uri.parse('/'));
    expect(result.outcome, SyncDeepLinkOutcome.skipped);
    expect(result.playlistId, isNull);
  });

  test('retorna success e playlistId quando import ok', () async {
    final result = await useCase(
      uri: Uri.parse('/?sharepdfs=a,b&sharename=Ensaio'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);
    expect(result.playlistId, isNotEmpty);

    final playlists = isar.playlists.where().findAll();
    expect(playlists.single.nome, 'Ensaio');
  });

  test('aceita queryParams map', () async {
    final result = await useCase(
      queryParams: const {
        'sharepdfs': 'x',
        'sharename': 'Lista',
      },
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);
    expect(result.playlistId, isNotEmpty);
  });

  test('retorna invalid quando params de share inválidos', () async {
    final result = await useCase(
      uri: Uri.parse('/?sharepdfs= , &sharename=Nome'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });
}
