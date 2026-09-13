import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
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

/// D6 — importar por URL torna a importada a lista ativa pelo mesmo caminho
/// do «Tornar lista ativa»: a lista que era ativa continua salva.
void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playlist_import_act_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: 'p-anterior',
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer container() {
    return ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
  }

  test('importar por URL ativa a importada e mantém a anterior', () async {
    await repository.create(
      nome: 'Anterior',
      pdfIds: const ['pdf-x'],
      playlistId: 'p-anterior',
      salva: true,
    );
    final c = container();
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();
    c.read(carouselFocusedKeyProvider.notifier).focus('pdf-x');

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            shareItems: 'p:pdf-a,a:aud-1,p:pdf-a',
            shareName: 'Importada',
          ),
        );
    await _flushAsync();

    expect(imported, isNotNull);
    expect(c.read(activePlaylistIdProvider), imported);
    expect(c.read(activePlaylistProvider)?.items, ['pdf-a', 'aud-1', 'pdf-a']);
    // A anterior continua existindo — nada foi "substituído".
    expect((await repository.getById('p-anterior'))?.nome, 'Anterior');
    // Foco da face de partituras zerado, como em qualquer ativação.
    expect(c.read(carouselFocusedKeyProvider), isNull);
  });

  // Fix round 2 (Minor): a dedupe por conteúdo (spec C.2) não pode reaproveitar
  // uma lista que está na graça de uma exclusão adiada (C11) — o repositório
  // ainda não sabe que ela foi apagada (commit só roda depois).
  test('importar com o mesmo conteúdo de uma lista pendente de exclusão cria '
      'nova, não reaproveita a pendente', () async {
    await repository.create(
      nome: 'Vai sair (exclusão adiada, ainda não comitou)',
      pdfIds: const ['pdf-a'],
      playlistId: 'p1',
      salva: true,
    );
    final c = container();
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    c.read(playlistsProvider.notifier).deleteWithUndo('p1');

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            sharePdfs: 'pdf-a',
            shareName: 'Reimportada',
          ),
        );

    expect(imported, isNotNull);
    expect(imported, isNot('p1'));
    final importedPlaylist = await repository.getById(imported!);
    expect(importedPlaylist?.nome, 'Reimportada');
  });
}
