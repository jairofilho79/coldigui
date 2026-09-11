import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _pdfB = encodePdfId('ColAdultos/002.pdf');
final _pdfC = encodePdfId('ColAdultos/003.pdf');
final _audioA = encodePdfId('ColAdultos/001.mp3');

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;

  Future<ProviderContainer> boot({String? activeId}) async {
    SharedPreferences.setMockInitialValues(
      activeId == null ? {} : {kActivePlaylistIdPrefsKey: activeId},
    );
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
    addTearDown(container.dispose);
    container.read(playlistsProvider);
    await _flush();
    return container;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('active_editor_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('addToActive cria rascunho e ativa quando não há lista', () async {
    final c = await boot();

    final outcome = await c
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(_pdfA);
    await _flush();

    expect(outcome, AddToActiveOutcome.added);
    final activeId = c.read(activePlaylistIdProvider);
    expect(activeId, isNotNull);
    final created = await repository.getById(activeId!);
    expect(created!.salva, isFalse);
    expect(created.items, [_pdfA]);
    expect(c.read(activeEntriesProvider).map((e) => e.key), [_pdfA]);
  });

  test('addToActive devolve alreadyPresent e não duplica por padrão', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    final outcome = await c
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(_pdfA);
    await _flush();

    expect(outcome, AddToActiveOutcome.alreadyPresent);
    expect((await repository.getById('p1'))!.items, [_pdfA]);
  });

  test(
    'addToActive com allowDuplicate adiciona segunda ocorrência com chave id#1',
    () async {
      await repository.create(
        nome: 'Ativa',
        entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
        playlistId: 'p1',
        salva: false,
      );
      final c = await boot(activeId: 'p1');

      final outcome = await c
          .read(activePlaylistEditorProvider.notifier)
          .addToActive(_pdfA, allowDuplicate: true);
      await _flush();

      expect(outcome, AddToActiveOutcome.added);
      expect((await repository.getById('p1'))!.items, [_pdfA, _pdfA]);
      expect(c.read(activeEntriesProvider).map((e) => e.key), [
        _pdfA,
        '$_pdfA#1',
      ]);
    },
  );

  test('addEntriesToActive preserva ordem e repetições', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    final added = await c
        .read(activePlaylistEditorProvider.notifier)
        .addEntriesToActive([
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
        ]);
    await _flush();

    expect(added, 3);
    expect((await repository.getById('p1'))!.items, [
      _pdfA,
      _pdfB,
      _pdfA,
      _audioA,
    ]);
  });

  test('removeByKey remove só a ocorrência pedida', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
      ],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c.read(activePlaylistEditorProvider.notifier).removeByKey('$_pdfA#1');
    await _flush();

    expect((await repository.getById('p1'))!.items, [_pdfA, _pdfB]);
  });

  test('replaceByKey troca na mesma posição', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      ],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    final replaced = await c
        .read(activePlaylistEditorProvider.notifier)
        .replaceByKey(_pdfA, PlaylistEntry(id: _pdfC, kind: MaterialKind.pdf));
    await _flush();

    expect(replaced, isTrue);
    expect((await repository.getById('p1'))!.items, [_pdfC, _pdfB]);
  });

  test('replaceByKey devolve false se a chave não existe', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    final replaced = await c
        .read(activePlaylistEditorProvider.notifier)
        .replaceByKey(
          '$_pdfA#3',
          PlaylistEntry(id: _pdfC, kind: MaterialKind.pdf),
        );

    expect(replaced, isFalse);
  });

  test(
    'reorderFace(pdf) reordena a face e mantém os áudios nas posições',
    () async {
      await repository.create(
        nome: 'Ativa',
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
        ],
        playlistId: 'p1',
        salva: false,
      );
      final c = await boot(activeId: 'p1');

      await c.read(activePlaylistEditorProvider.notifier).reorderFace(
        PlaylistMediaFace.pdf,
        [_pdfB, _pdfA],
      );
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect((await repository.getById('p1'))!.items, [_pdfB, _audioA, _pdfA]);
    },
  );

  test('reorderFace aplica override imediato e limpa após persistir', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      ],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c.read(activePlaylistEditorProvider.notifier).reorderFace(
      PlaylistMediaFace.pdf,
      [_pdfB, _pdfA],
    );

    // Override otimista: antes do debounce a view já mostra a nova ordem.
    expect(c.read(activePlaylistEditorProvider), isNotNull);
    expect(c.read(activeEntriesProvider).map((e) => e.id), [_pdfB, _pdfA]);

    await Future<void>.delayed(activeReorderPersistDebounce * 3);
    await _flush();

    expect(c.read(activePlaylistEditorProvider), isNull);
    expect(c.read(activeEntriesProvider).map((e) => e.id), [_pdfB, _pdfA]);
  });

  test(
    'deleteActiveDraft apaga rascunho e limpa o id; salva só desanexa',
    () async {
      await repository.create(
        nome: 'Rascunho',
        entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
        playlistId: 'p1',
        salva: false,
      );
      final c = await boot(activeId: 'p1');

      await c.read(activePlaylistEditorProvider.notifier).deleteActiveDraft();
      await _flush();

      expect(c.read(activePlaylistIdProvider), isNull);
      expect(await repository.getById('p1'), isNull);

      await repository.create(
        nome: 'Salva',
        entries: [PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf)],
        playlistId: 'p2',
        salva: true,
      );
      c.read(activePlaylistIdProvider.notifier).set('p2');
      await c.read(playlistsProvider.notifier).reload();
      await _flush();

      await c.read(activePlaylistEditorProvider.notifier).deleteActiveDraft();
      await _flush();

      expect(c.read(activePlaylistIdProvider), isNull);
      expect((await repository.getById('p2'))!.items, [_pdfB]);
    },
  );

  test('detachActive limpa o id ativo e a lista fica', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c.read(activePlaylistEditorProvider.notifier).detachActive();
    await _flush();

    expect(c.read(activePlaylistIdProvider), isNull);
    expect((await repository.getById('p1'))!.items, [_pdfA]);
    expect(c.read(activeEntriesProvider), isEmpty);
  });

  test('activate devolve o id anterior', () async {
    await repository.create(
      nome: 'Um',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    await repository.create(
      nome: 'Dois',
      entries: [PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf)],
      playlistId: 'p2',
      salva: true,
    );
    final c = await boot(activeId: 'p1');

    final previous = await c
        .read(activePlaylistEditorProvider.notifier)
        .activate('p2');
    await _flush();

    expect(previous, 'p1');
    expect(c.read(activePlaylistIdProvider), 'p2');
    expect(c.read(activeEntriesProvider).map((e) => e.id), [_pdfB]);
  });

  test('sem storage devolve storageUnavailable', () async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playlistRepositoryProvider.overrideWithValue(
          PlaylistRepositoryImpl(const PlaylistLocalDatasource.unavailable()),
        ),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flush();

    final outcome = await c
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(_pdfA);

    expect(outcome, AddToActiveOutcome.storageUnavailable);
  });

  test('lista ativa vazia apaga o rascunho e desanexa', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c.read(activePlaylistEditorProvider.notifier).removeByKey(_pdfA);
    await _flush();

    expect(await repository.getById('p1'), isNull);
    expect(c.read(activePlaylistIdProvider), isNull);
  });

  test('activeEntriesProvider deriva da lista ativa com chaves', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
      ],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    expect(c.read(activeEntriesProvider), [
      ActiveEntry(
        index: 0,
        entry: PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        key: _pdfA,
      ),
      ActiveEntry(
        index: 1,
        entry: PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
        key: _audioA,
      ),
      ActiveEntry(
        index: 2,
        entry: PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        key: '$_pdfA#1',
      ),
    ]);
  });
}
