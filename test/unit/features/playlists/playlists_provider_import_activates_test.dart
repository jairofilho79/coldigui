import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/praise_entry_resolver_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/shared_import_outcome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_overrides.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _pdfA = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _catalog = {
  '0a1': _pdfA,
  '0c3': PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
};

/// D6 — importar por URL torna a importada a lista ativa pelo mesmo caminho
/// do «Editar por aqui»: a lista que era ativa continua salva.
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

  ProviderContainer container({PraiseEntryResolverLoader? loader}) {
    return ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        praiseEntryResolverLoaderProvider.overrideWithValue(
          loader ??
              () async =>
                  (shortId) => _catalog[shortId],
        ),
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
            shareName: 'Importada',
            praiseShortIds: ['0a1', '0c3', '0a1'],
          ),
        );
    await _flushAsync();

    expect(imported.status, SharedImportStatus.imported);
    expect(imported.skippedCount, 0);
    expect(c.read(activePlaylistIdProvider), imported.playlistId);
    expect(c.read(activePlaylistProvider)?.items, ['pdf-a', 'aud-1', 'pdf-a']);
    expect((await repository.getById('p-anterior'))?.nome, 'Anterior');
    expect(c.read(carouselFocusedKeyProvider), isNull);
  });

  // Fix round 2 (Minor): a dedupe por conteúdo (spec C.2) não pode reaproveitar
  // uma lista na graça de uma exclusão adiada (C11).
  test('importar com o mesmo conteúdo de uma lista pendente de exclusão cria '
      'nova, não reaproveita a pendente', () async {
    await repository.create(
      nome: 'Vai sair (exclusão adiada, ainda não comitou)',
      entries: const [_pdfA],
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
            shareName: 'Reimportada',
            praiseShortIds: ['0a1'],
          ),
        );

    expect(imported.status, SharedImportStatus.imported);
    expect(imported.playlistId, isNot('p1'));
    expect(
      (await repository.getById(imported.playlistId!))?.nome,
      'Reimportada',
    );
  });

  test('louvores que ficaram de fora vêm contados no desfecho', () async {
    final c = container();
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            shareName: 'Com buracos',
            praiseShortIds: ['0a1', 'abc', '0c3', 'fff'],
          ),
        );

    expect(imported.status, SharedImportStatus.imported);
    expect(imported.skippedCount, 2);
  });

  // M5: link antigo que chegue ao notifier dá o aviso de link antigo, não o
  // genérico de link inválido.
  test('link antigo devolve o desfecho legacy', () async {
    final c = container();
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(params: const PlaylistShareParams.legacy());

    expect(imported.status, SharedImportStatus.legacy);
    expect(imported.playlistId, isNull);
  });

  test('nenhum token resolvido devolve o desfecho invalid', () async {
    final c = container();
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            shareName: 'X',
            praiseShortIds: ['abc'],
          ),
        );

    expect(imported.status, SharedImportStatus.invalid);
  });

  // Fix round final (#3): o resolver espera o catálogo — se ele falhar, o
  // import não derruba quem chamou; a tela mostra link inválido.
  test('resolver que falha devolve invalid sem lançar', () async {
    final c = container(
      loader: () async => throw StateError('catálogo indisponível'),
    );
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            shareName: 'X',
            praiseShortIds: ['0a1'],
          ),
        );

    expect(imported.status, SharedImportStatus.invalid);
  });
}
