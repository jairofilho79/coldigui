// test/unit/features/playlists/playlist_add_dedupe_test.dart
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';
import '../../../support/test_overrides.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final pdfA = encodePdfId('ColAdultos/001.pdf');

/// Áudio com container que a heurística de extensão **não** reconhece: o
/// worker publicaria isso como `type: mp3`, mas `materialIdKindOf` devolve
/// `unknown` e o id cai na face de partituras.
final audioSemExtensaoConhecida = encodePdfId('assets/praises/a/001.mid');

/// Áudio com extensão reconhecida.
final audioOk = encodePdfId('assets/praises/a/002.mp3');

void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playlist_dedupe_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    SharedPreferences.setMockInitialValues({kActivePlaylistIdPrefsKey: 'p1'});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // `standardTestOverrides` cobre isarStatusProvider/isarOpenerProvider/
  // carouselLocalDatasourceProvider — sem isso, `PlaylistsNotifier.build()`
  // escuta `isarStatusProvider` de verdade e corre contra o Isar real (e o
  // timeout de 15 s de `isarOpenTimeout`) em vez do `playlistRepositoryProvider`
  // que este teste já sobrescreve com o repositório de teste.
  ProviderContainer container({required List<String> carouselPdfIds}) {
    return ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
  }

  test('o id de áudio do fixture realmente não classifica como áudio', () {
    expect(materialIdKindOf(audioSemExtensaoConhecida), MaterialKind.unknown);
    expect(materialIdKindOf(audioOk), MaterialKind.audio);
  });

  test('addAudio não duplica áudio com extensão reconhecida', () async {
    await repository.create(
      nome: 'Rascunho',
      pdfIds: [pdfA],
      playlistId: 'p1',
      salva: false,
    );
    final c = container(carouselPdfIds: [pdfA]);
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    final first = await c
        .read(playlistsProvider.notifier)
        .addAudioToActivePlaylist(audioOk);
    await _flushAsync();
    final second = await c
        .read(playlistsProvider.notifier)
        .addAudioToActivePlaylist(audioOk);
    await _flushAsync();

    expect(first, isTrue);
    expect(second, isFalse);
    expect((await repository.getById('p1'))?.items, [pdfA, audioOk]);
  });

  test('addAudio dedupa contra items, não contra a projeção', () async {
    await repository.create(
      nome: 'Rascunho',
      pdfIds: [pdfA],
      playlistId: 'p1',
      salva: false,
    );
    final c = container(carouselPdfIds: [pdfA]);
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    // A extensão não classifica o id como áudio, mas ele foi declarado áudio
    // ao ser adicionado (A8); o dedupe continua sendo contra `items`.
    await c
        .read(playlistsProvider.notifier)
        .addAudioToActivePlaylist(audioSemExtensaoConhecida);
    await _flushAsync();
    final second = await c
        .read(playlistsProvider.notifier)
        .addAudioToActivePlaylist(audioSemExtensaoConhecida);
    await _flushAsync();

    final saved = await repository.getById('p1');
    expect(second, isFalse);
    expect(saved?.audioIds, [audioSemExtensaoConhecida]);
    expect(saved?.pdfIds, [pdfA]);
    expect(
      saved!.items.where((id) => id == audioSemExtensaoConhecida).length,
      1,
    );
  });

  test('addLouvor dedupa contra items', () async {
    await repository.create(
      nome: 'Rascunho',
      pdfIds: [pdfA],
      playlistId: 'p1',
      salva: false,
    );
    final c = container(carouselPdfIds: [pdfA]);
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    final added = await c
        .read(playlistsProvider.notifier)
        .addLouvorToActivePlaylist(pdfA);
    await _flushAsync();

    expect(added, isFalse);
    expect((await repository.getById('p1'))?.items, [pdfA]);
  });
}
