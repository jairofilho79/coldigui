import '../../../helpers/legacy_ids_normalizer_test_helpers.dart';
import '../../../helpers/louvores_manifest_test_helpers.dart';
import '../../../support/fakes/fake_isar.dart';

import 'dart:async';
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conta as chamadas de sync sem encostar em rede nem em auth.
class _RecordingSyncNotifier extends PlaylistSyncNotifier {
  var calls = 0;

  @override
  PlaylistSyncState build() => const PlaylistSyncState();

  @override
  Future<PlaylistSyncResult> sync() async {
    calls++;
    return PlaylistSyncResult.skippedAuth;
  }
}

/// Repositório cujo `update` falha nas primeiras [failures] chamadas e, quando
/// [gate] está armado, só escreve depois que o teste o libera.
class _FlakyRepository extends PlaylistRepositoryImpl {
  _FlakyRepository(super.local);

  /// Quantas das próximas escritas ainda falham.
  var failures = 0;
  Completer<void>? gate;
  var updateCalls = 0;

  @override
  Future<void> update(
    String playlistId, {
    String? nome,
    List<PlaylistEntry>? entries,
    List<String>? pdfIds,
    List<String>? audioIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) async {
    updateCalls++;
    await gate?.future;
    if (failures > 0) {
      failures--;
      throw StateError('escrita falhou');
    }
    return super.update(
      playlistId,
      nome: nome,
      entries: entries,
      pdfIds: pdfIds,
      audioIds: audioIds,
      salva: salva,
      savedAt: savedAt,
      favoritedAt: favoritedAt,
      favorita: favorita,
      clearFavoritedAt: clearFavoritedAt,
      updatedAt: updatedAt,
      version: version,
      syncStatus: syncStatus,
      deletedAt: deletedAt,
      clearDeletedAt: clearDeletedAt,
    );
  }
}

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
  late _FlakyRepository repository;

  late _RecordingSyncNotifier sync;

  Future<ProviderContainer> boot({String? activeId}) async {
    SharedPreferences.setMockInitialValues(
      activeId == null ? {} : {kActivePlaylistIdPrefsKey: activeId},
    );
    prefs = await SharedPreferences.getInstance();
    sync = _RecordingSyncNotifier();
    final container = ProviderContainer(
      overrides: [
        noOpLegacyMaterialIdsNormalizerOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        playlistRepositoryProvider.overrideWithValue(repository),
        playlistSyncProvider.overrideWith(() => sync),
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
    repository = _FlakyRepository(PlaylistLocalDatasource(isar));
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

  test('removeById remove todas as ocorrências do material', () async {
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

    await c.read(activePlaylistEditorProvider.notifier).removeById(_pdfA);
    await _flush();

    expect((await repository.getById('p1'))!.items, [_pdfB]);
  });

  test('removeById de material ausente não grava nada', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c.read(activePlaylistEditorProvider.notifier).removeById(_pdfC);
    await _flush();

    expect((await repository.getById('p1'))!.items, [_pdfA]);
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

  test('reorder aplica a permutação completa, áudio incluído', () async {
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

    await c.read(activePlaylistEditorProvider.notifier).reorder([
      _pdfB,
      _audioA,
      _pdfA,
    ]);
    await _flush();

    expect(c.read(activeEntriesProvider).map((e) => e.id), [
      _pdfB,
      _audioA,
      _pdfA,
    ]);
  });

  test('reorder aplica override imediato e limpa após persistir', () async {
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

    await c.read(activePlaylistEditorProvider.notifier).reorder([_pdfB, _pdfA]);

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
        noOpLegacyMaterialIdsNormalizerOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
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

  group('reordenação em voo × outra mutação', () {
    Future<ProviderContainer> bootTres() async {
      await repository.create(
        nome: 'Ativa',
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfC, kind: MaterialKind.pdf),
        ],
        playlistId: 'p1',
        salva: false,
      );
      return boot(activeId: 'p1');
    }

    test('remover dentro do debounce não ressuscita a entrada', () async {
      final c = await bootTres();
      final editor = c.read(activePlaylistEditorProvider.notifier);

      await editor.reorder([_pdfB, _pdfA, _pdfC]);
      // Sem esperar o debounce: a remoção chega antes do flush.
      await editor.removeByKey(_pdfC);
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect((await repository.getById('p1'))!.items, [_pdfB, _pdfA]);
      expect(c.read(activeEntriesProvider).map((e) => e.id), [_pdfB, _pdfA]);
    });

    test('adicionar dentro do debounce mantém a entrada nova', () async {
      final c = await bootTres();
      final editor = c.read(activePlaylistEditorProvider.notifier);
      final novo = encodePdfId('ColAdultos/004.pdf');

      await editor.reorder([_pdfC, _pdfB, _pdfA]);
      await editor.addToActive(novo);
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect((await repository.getById('p1'))!.items, [
        _pdfC,
        _pdfB,
        _pdfA,
        novo,
      ]);
    });

    test('trocar dentro do debounce preserva a ordem arrastada', () async {
      final c = await bootTres();
      final editor = c.read(activePlaylistEditorProvider.notifier);

      await editor.reorder([_pdfC, _pdfB, _pdfA]);
      await editor.replaceByKey(
        _pdfB,
        PlaylistEntry(
          id: encodePdfId('ColAdultos/009.pdf'),
          kind: MaterialKind.pdf,
        ),
      );
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect((await repository.getById('p1'))!.items, [
        _pdfC,
        encodePdfId('ColAdultos/009.pdf'),
        _pdfA,
      ]);
    });

    test(
      'detachActive grava a ordem pendente antes de soltar a lista',
      () async {
        final c = await bootTres();
        final editor = c.read(activePlaylistEditorProvider.notifier);

        await editor.reorder([_pdfC, _pdfB, _pdfA]);
        await editor.detachActive();
        await _flush();

        expect(c.read(activePlaylistIdProvider), isNull);
        expect((await repository.getById('p1'))!.items, [_pdfC, _pdfB, _pdfA]);
      },
    );
  });

  group('reorder só aceita permutação completa', () {
    Future<ProviderContainer> bootDuas() async {
      await repository.create(
        nome: 'Ativa',
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfC, kind: MaterialKind.pdf),
        ],
        playlistId: 'p1',
        salva: false,
      );
      return boot(activeId: 'p1');
    }

    test('lista curta de chaves não apaga nada', () async {
      final c = await bootDuas();

      await c.read(activePlaylistEditorProvider.notifier).reorder([
        _pdfB,
        _pdfA,
      ]);
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect(c.read(activeEntriesProvider).map((e) => e.id), [
        _pdfA,
        _pdfB,
        _pdfC,
      ]);
      expect((await repository.getById('p1'))!.items, [_pdfA, _pdfB, _pdfC]);
    });

    test('chave desconhecida não apaga nada', () async {
      final c = await bootDuas();

      await c.read(activePlaylistEditorProvider.notifier).reorder([
        _pdfB,
        _pdfA,
        'nao-existe',
      ]);
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect((await repository.getById('p1'))!.items, [_pdfA, _pdfB, _pdfC]);
    });

    test('chave repetida não apaga nada', () async {
      final c = await bootDuas();

      await c.read(activePlaylistEditorProvider.notifier).reorder([
        _pdfB,
        _pdfB,
        _pdfA,
      ]);
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect((await repository.getById('p1'))!.items, [_pdfA, _pdfB, _pdfC]);
    });
  });

  group('lista que fica vazia', () {
    test('rascunho é apagado e o id ativo é limpo', () async {
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

    test('lista salva fica, vazia e sem tombstone', () async {
      await repository.create(
        nome: 'Salva',
        entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
        playlistId: 'p2',
        salva: true,
      );
      final c = await boot(activeId: 'p2');

      await c.read(activePlaylistEditorProvider.notifier).removeByKey(_pdfA);
      await _flush();

      final saved = await repository.getById('p2');
      expect(saved, isNotNull);
      expect(saved!.entries, isEmpty);
      expect(saved.deletedAt, isNull);
      expect(c.read(activePlaylistIdProvider), 'p2');
    });
  });

  test('mutação em lista salva dispara o sync', () async {
    await repository.create(
      nome: 'Salva',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p2',
      salva: true,
    );
    final c = await boot(activeId: 'p2');
    expect(sync.calls, 0);

    await c.read(activePlaylistEditorProvider.notifier).addToActive(_pdfB);
    await _flush();

    expect((await repository.getById('p2'))!.items, [_pdfA, _pdfB]);
    expect(sync.calls, 1);
  });

  test('mutação em rascunho não dispara o sync', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c.read(activePlaylistEditorProvider.notifier).addToActive(_pdfB);
    await _flush();

    expect(sync.calls, 0);
  });

  test('adicionar áudio foca a chave do novo chip, como qualquer outro tipo '
      '(spec 2026-09-12, D1: sem faces)', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(_audioA, kind: MaterialKind.audio);
    await _flush();

    expect((await repository.getById('p1'))!.audioIds, [_audioA]);
    expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), _audioA);
  });

  test('addToActive com allowDuplicate foca a ocorrência nova', () async {
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

    await c
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(_pdfA, allowDuplicate: true);
    await _flush();

    expect(c.read(carouselFocusedKeyProvider), '$_pdfA#1');
  });

  group('escrita que falha não deixa o override preso (#5)', () {
    Future<ProviderContainer> bootDuas() async {
      await repository.create(
        nome: 'Ativa',
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
        ],
        playlistId: 'p1',
        salva: false,
      );
      return boot(activeId: 'p1');
    }

    test('removeByKey propaga o erro e a view volta para a lista', () async {
      final c = await bootDuas();
      repository.failures = 1;

      await expectLater(
        c.read(activePlaylistEditorProvider.notifier).removeByKey(_pdfA),
        throwsStateError,
      );
      await _flush();

      expect(c.read(activePlaylistEditorProvider), isNull);
      expect(c.read(activeEntriesProvider).map((e) => e.id), [_pdfA, _pdfB]);
    });

    test('replaceByKey propaga o erro e a view volta para a lista', () async {
      final c = await bootDuas();
      repository.failures = 1;

      await expectLater(
        c
            .read(activePlaylistEditorProvider.notifier)
            .replaceByKey(
              _pdfA,
              PlaylistEntry(id: _pdfC, kind: MaterialKind.pdf),
            ),
        throwsStateError,
      );
      await _flush();

      expect(c.read(activePlaylistEditorProvider), isNull);
      expect(c.read(activeEntriesProvider).map((e) => e.id), [_pdfA, _pdfB]);
    });

    test('flush da reordenação engole o erro e solta o override', () async {
      final c = await bootDuas();
      repository.failures = 1;

      // O flush roda num Timer: um erro que escapasse daqui seria assíncrono
      // sem dono — e o teste falharia por ele.
      await c.read(activePlaylistEditorProvider.notifier).reorder([
        _pdfB,
        _pdfA,
      ]);
      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect(repository.updateCalls, 1);
      expect(c.read(activePlaylistEditorProvider), isNull);
      expect(c.read(activeEntriesProvider).map((e) => e.id), [
        _pdfA,
        _pdfB,
      ], reason: 'a escrita não aconteceu: a view mostra o que está no banco');
    });
  });

  test(
    'duas reordenações seguidas: a segunda persiste e nunca pisca (#6)',
    () async {
      await repository.create(
        nome: 'Ativa',
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfC, kind: MaterialKind.pdf),
        ],
        playlistId: 'p1',
        salva: false,
      );
      final c = await boot(activeId: 'p1');
      final editor = c.read(activePlaylistEditorProvider.notifier);

      // Primeira ordem: o debounce vence e o flush trava na escrita (gate).
      final gate = Completer<void>();
      repository.gate = gate;
      await editor.reorder([_pdfB, _pdfA, _pdfC]);
      await Future<void>.delayed(activeReorderPersistDebounce * 2);
      expect(repository.updateCalls, 1, reason: 'o primeiro flush está em voo');

      // Segunda ordem chega enquanto a primeira ainda escreve.
      await editor.reorder([_pdfC, _pdfB, _pdfA]);
      expect(c.read(activeEntriesProvider).map((e) => e.id), [
        _pdfC,
        _pdfB,
        _pdfA,
      ]);

      // A primeira escrita termina: o override da segunda tem que continuar —
      // sem ele a barra piscaria [B, A, C] até o segundo flush.
      repository.gate = null;
      gate.complete();
      await _flush();
      expect(c.read(activeEntriesProvider).map((e) => e.id), [
        _pdfC,
        _pdfB,
        _pdfA,
      ]);

      await Future<void>.delayed(activeReorderPersistDebounce * 3);
      await _flush();

      expect(repository.updateCalls, 2);
      expect((await repository.getById('p1'))!.items, [_pdfC, _pdfB, _pdfA]);
      expect(c.read(activePlaylistEditorProvider), isNull);
      expect(c.read(activeEntriesProvider).map((e) => e.id), [
        _pdfC,
        _pdfB,
        _pdfA,
      ]);
    },
  );

  test('addToActive espera o Isar abrir antes de decidir', () async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    sync = _RecordingSyncNotifier();
    final opening = Completer<Isar>();
    final c = ProviderContainer(
      overrides: [
        noOpLegacyMaterialIdsNormalizerOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarOpenerProvider.overrideWithValue(() => opening.future),
        carouselLocalDatasourceProvider.overrideWithValue(
          const CarouselLocalDatasource.unavailable(),
        ),
        playlistRepositoryProvider.overrideWithValue(repository),
        playlistSyncProvider.overrideWith(() => sync),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flush();

    var settled = false;
    final pending = c
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(_pdfA)
        .whenComplete(() => settled = true);
    await _flush();
    expect(settled, isFalse, reason: 'com o Isar abrindo, o toque espera');
    expect(await repository.getAll(), isEmpty);

    opening.complete(FakeIsar());
    expect(await pending, AddToActiveOutcome.added);
    expect((await repository.getAll()).single.entries.single.id, _pdfA);
  });
}
