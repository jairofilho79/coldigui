import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import '../../../helpers/louvores_manifest_test_helpers.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('resolve_active_playlist_');
    isar = Isar.open(
      schemas: [CarouselEntrySchema, PlaylistSchema],
      directory: tempDir.path,
    );
    container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(isar),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'recupera rascunho existente quando playlist ativa foi perdida em memória',
    () async {
      final carouselRepository = CarouselRepositoryImpl(
        CarouselLocalDatasource(isar),
      );
      final playlistRepository = PlaylistRepositoryImpl(
        PlaylistLocalDatasource(isar),
      );

      await carouselRepository.add('pdf-a');
      final playlistId = await playlistRepository.create(
        nome: 'Ensaio',
        pdfIds: const ['pdf-a'],
        salva: false,
      );

      container.read(playlistsProvider);
      await Future<void>.delayed(Duration.zero);
      final resolved = await container
          .read(playlistsProvider.notifier)
          .resolveActivePlaylistFromCarousel();

      expect(resolved?.playlistId, playlistId);
      expect(resolved?.nome, 'Ensaio');
      expect(container.read(activePlaylistIdProvider), playlistId);
    },
  );

  test('retorna null quando carousel está vazio', () async {
    container.read(playlistsProvider);
    await Future<void>.delayed(Duration.zero);
    final resolved = await container
        .read(playlistsProvider.notifier)
        .resolveActivePlaylistFromCarousel();

    expect(resolved, isNull);
  });
}
