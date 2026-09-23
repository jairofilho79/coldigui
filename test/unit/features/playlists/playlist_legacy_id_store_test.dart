import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/legacy/playlist_legacy_id_store.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _legadoB = encodePdfId('ColAdultos/002.pdf');
final _desconhecido = encodePdfId('ColAdultos/999.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomB = encodePdfId('assets/praises/p2/m2.pdf');
final _audio = encodePdfId('assets/praises/p1/a.mp3');

final _ontem = DateTime.utc(2026, 9, 22, 12);

LegacyIdResolution _resolution() => LegacyIdResolution(
  queried: {_legadoA, _legadoB, _desconhecido},
  // Os dois legados caem no mesmo material coldigom (duplicata do PLPCG).
  resolved: {_legadoA: _coldigomA, _legadoB: _coldigomA},
);

SavedPlaylist _playlist(
  String id,
  List<PlaylistEntry> entries, {
  bool salva = true,
  PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
}) => SavedPlaylist(
  playlistId: id,
  nome: 'Culto $id',
  createdAt: _ontem,
  updatedAt: _ontem,
  entries: entries,
  salva: salva,
  syncStatus: syncStatus,
);

/// Repositório real com um gancho entre a leitura de todas as listas e as
/// escritas da store — é onde uma edição do usuário (ou um pull) pode cair.
class _RacingRepository extends PlaylistRepositoryImpl {
  _RacingRepository(super.local);

  Future<void> Function()? afterGetAll;

  @override
  Future<List<SavedPlaylist>> getAll() async {
    final all = await super.getAll();
    final hook = afterGetAll;
    afterGetAll = null;
    if (hook != null) await hook();
    return all;
  }
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late _RacingRepository repository;
  late PlaylistLegacyIdStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('legacy_playlists_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = _RacingRepository(PlaylistLocalDatasource(isar));
    store = PlaylistLegacyIdStore(repository);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('collect junta só os PDFs legados de todas as listas', () async {
    await repository.upsert(
      _playlist('a', [
        PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audio, kind: MaterialKind.audio),
      ]),
    );
    await repository.upsert(
      _playlist('b', [PlaylistEntry(id: _coldigomB, kind: MaterialKind.pdf)]),
    );

    expect(await store.collectLegacyIds(), {_legadoA});
  });

  test(
    'troca os ids mantendo kind, ordem e repetidos; desconhecido fica; salva '
    'sobe sem mexer no updatedAt',
    () async {
      await repository.upsert(
        _playlist('a', [
          PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _audio, kind: MaterialKind.audio),
          PlaylistEntry(id: _legadoB, kind: MaterialKind.pdf),
          PlaylistEntry(id: _desconhecido, kind: MaterialKind.pdf),
        ]),
      );

      expect(await store.rewrite(_resolution()), 1);

      final after = (await repository.getById('a'))!;
      expect(after.entries, [
        PlaylistEntry(id: _coldigomA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audio, kind: MaterialKind.audio),
        PlaylistEntry(id: _coldigomA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _desconhecido, kind: MaterialKind.pdf),
      ]);
      expect(after.syncStatus, PlaylistSyncStatus.pendingPush);
      // Normalizar não é editar: o `updatedAt` da lista fica (o Worker aceita
      // o push com `clientUpdatedAt == updated_at`), e uma edição remota
      // posterior continua a vencer no pull.
      expect(after.updatedAt.isAtSameMomentAs(_ontem), isTrue);
    },
  );

  test('conflito continua conflito', () async {
    await repository.upsert(
      _playlist('c', [
        PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf),
      ], syncStatus: PlaylistSyncStatus.conflict),
    );

    await store.rewrite(_resolution());

    final after = (await repository.getById('c'))!;
    expect(after.entries.single.id, _coldigomA);
    expect(after.syncStatus, PlaylistSyncStatus.conflict);
    expect(after.updatedAt.isAtSameMomentAs(_ontem), isTrue);
  });

  test('rascunho não vira pendingPush', () async {
    await repository.upsert(
      _playlist('r', [
        PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf),
      ], salva: false),
    );

    await store.rewrite(_resolution());

    final after = (await repository.getById('r'))!;
    expect(after.entries.single.id, _coldigomA);
    expect(after.syncStatus, PlaylistSyncStatus.synced);
    expect(after.updatedAt.isAtSameMomentAs(_ontem), isTrue);
  });

  test('lista sem legado resolvido não é tocada', () async {
    await repository.upsert(
      _playlist('d', [
        PlaylistEntry(id: _desconhecido, kind: MaterialKind.pdf),
        PlaylistEntry(id: _coldigomB, kind: MaterialKind.pdf),
      ]),
    );

    expect(await store.rewrite(_resolution()), 0);

    final after = (await repository.getById('d'))!;
    expect(after.updatedAt.isAtSameMomentAs(_ontem), isTrue);
    expect(after.syncStatus, PlaylistSyncStatus.synced);
  });

  group('corrida com outras escritas', () {
    test('edição feita depois da leitura das listas não se perde', () async {
      await repository.upsert(
        _playlist('a', [PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf)]),
      );
      expect(await store.collectLegacyIds(), {_legadoA});

      final editedAt = DateTime.utc(2026, 9, 23, 9);
      repository.afterGetAll = () => repository.update(
        'a',
        nome: 'Culto editado',
        entries: [
          PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _coldigomB, kind: MaterialKind.pdf),
        ],
        updatedAt: editedAt,
      );

      expect(await store.rewrite(_resolution()), 1);

      final after = (await repository.getById('a'))!;
      expect(after.nome, 'Culto editado');
      expect(after.entries, [
        PlaylistEntry(id: _coldigomA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _coldigomB, kind: MaterialKind.pdf),
      ]);
      expect(after.updatedAt.isAtSameMomentAs(editedAt), isTrue);
      expect(after.syncStatus, PlaylistSyncStatus.pendingPush);
    });

    test('lista apagada no meio fica apagada', () async {
      await repository.upsert(
        _playlist('a', [PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf)]),
      );
      await repository.upsert(
        _playlist('b', [PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf)]),
      );
      repository.afterGetAll = () async {
        await repository.delete('a'); // salva → tombstone
        await repository.hardDelete('b'); // tombstone remoto aplicado
      };

      expect(await store.rewrite(_resolution()), 0);

      final tombstone = (await repository.getById('a'))!;
      expect(tombstone.deletedAt, isNotNull);
      expect(tombstone.entries.single.id, _legadoA);
      expect(await repository.getById('b'), isNull);
    });

    test('lista que perdeu o legado no meio não é reescrita', () async {
      await repository.upsert(
        _playlist('a', [PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf)]),
      );
      final editedAt = DateTime.utc(2026, 9, 23, 9);
      repository.afterGetAll = () => repository.update(
        'a',
        entries: [PlaylistEntry(id: _coldigomB, kind: MaterialKind.pdf)],
        updatedAt: editedAt,
        syncStatus: PlaylistSyncStatus.synced,
      );

      expect(await store.rewrite(_resolution()), 0);

      final after = (await repository.getById('a'))!;
      expect(after.entries.single.id, _coldigomB);
      expect(after.syncStatus, PlaylistSyncStatus.synced);
    });
  });

  group('sync depois da reescrita', () {
    final remoteLater = _ontem.add(const Duration(hours: 1));

    RemotePlaylist remote({DateTime? deletedAt}) => RemotePlaylist(
      id: 'a',
      nome: 'Culto editado noutro aparelho',
      entries: [PlaylistEntry(id: _legadoB, kind: MaterialKind.pdf)],
      salva: true,
      favorita: false,
      createdAt: _ontem,
      updatedAt: remoteLater,
      version: 2,
      deletedAt: deletedAt,
    );

    Future<void> seedAndRewrite() async {
      await repository.upsert(
        _playlist('a', [PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf)]),
      );
      expect(await store.rewrite(_resolution()), 1);
      expect(
        (await repository.getById('a'))!.syncStatus,
        PlaylistSyncStatus.pendingPush,
      );
    }

    test('versão remota mais nova ainda vence no pull', () async {
      await seedAndRewrite();
      final pushed = <String>[];
      final sync = SyncPlaylists(repository, (_) async => [remote()], ({
        required sessionToken,
        required playlist,
      }) async {
        pushed.add(playlist.id);
        return playlist;
      }, ({required sessionToken, required playlistId}) async {});

      final result = await sync(sessionToken: 'token', sub: 'sub-1');

      expect(result.pulled, 1);
      expect(pushed, isEmpty);
      final after = (await repository.getById('a'))!;
      expect(after.nome, 'Culto editado noutro aparelho');
      expect(after.version, 2);
      expect(after.syncStatus, PlaylistSyncStatus.synced);
    });

    test('lista apagada noutro aparelho não ressuscita', () async {
      await seedAndRewrite();
      final pushed = <String>[];
      final sync = SyncPlaylists(
        repository,
        (_) async => [remote(deletedAt: remoteLater)],
        ({required sessionToken, required playlist}) async {
          pushed.add(playlist.id);
          return playlist;
        },
        ({required sessionToken, required playlistId}) async {},
      );

      final result = await sync(sessionToken: 'token', sub: 'sub-1');

      expect(result.deletedRemotely, 1);
      expect(pushed, isEmpty);
      expect(await repository.getById('a'), isNull);
    });
  });
}
