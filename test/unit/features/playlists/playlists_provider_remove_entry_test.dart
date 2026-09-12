import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';
import '../../../support/test_overrides.dart';

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

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _pdfB = encodePdfId('ColAdultos/002.pdf');
final _pdfC = encodePdfId('ColAdultos/003.pdf');
final _audioA = encodePdfId('ColAdultos/001.mp3');

PlaylistEntry _pdf(String id) => PlaylistEntry(id: id, kind: MaterialKind.pdf);
PlaylistEntry _audio(String id) =>
    PlaylistEntry(id: id, kind: MaterialKind.audio);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// `PlaylistsNotifier.removeEntryAt` (B.1): remove **uma** ocorrência, pela
/// posição na ordem única — a lista ativa passa pelo editor, as outras vão
/// direto a `UpdatePlaylist(entries:)`.
void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;
  late _RecordingSyncNotifier sync;

  Future<ProviderContainer> boot({String? activeId}) async {
    SharedPreferences.setMockInitialValues(
      activeId == null ? {} : {kActivePlaylistIdPrefsKey: activeId},
    );
    prefs = await SharedPreferences.getInstance();
    sync = _RecordingSyncNotifier();
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
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
    tempDir = await Directory.systemTemp.createTemp('remove_entry_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('lista ativa com X duas vezes: remover a segunda deixa uma X', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [_pdf(_pdfA), _pdf(_pdfB), _pdf(_pdfA)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c
        .read(playlistsProvider.notifier)
        .removeEntryAt(playlistId: 'p1', index: 2);
    await _flush();

    expect((await repository.getById('p1'))!.items, [_pdfA, _pdfB]);
    expect(c.read(activeEntriesProvider).map((e) => e.key), [_pdfA, _pdfB]);
  });

  test('lista ativa: a reordenação em voo assenta antes de remover', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [_pdf(_pdfA), _pdf(_pdfB), _pdf(_pdfC)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');

    await c.read(activePlaylistEditorProvider.notifier).reorderFace(
      PlaylistMediaFace.pdf,
      [_pdfC, _pdfB, _pdfA],
    );
    // O tile mostra a ordem do banco ([A, B, C]): posição 0 é A. A remoção
    // não pode ressuscitar a ordem antiga nem apagar C por engano.
    await c
        .read(playlistsProvider.notifier)
        .removeEntryAt(playlistId: 'p1', index: 0);
    await Future<void>.delayed(activeReorderPersistDebounce * 3);
    await _flush();

    expect((await repository.getById('p1'))!.items, [_pdfC, _pdfB]);
  });

  test('lista não ativa: remove só a posição pedida', () async {
    await repository.create(
      nome: 'Outra',
      entries: [_pdf(_pdfA), _pdf(_pdfA), _audio(_audioA)],
      playlistId: 'p2',
      salva: true,
    );
    final c = await boot(activeId: 'p1');

    await c
        .read(playlistsProvider.notifier)
        .removeEntryAt(playlistId: 'p2', index: 0);
    await _flush();

    expect((await repository.getById('p2'))!.items, [_pdfA, _audioA]);
    expect(
      c
          .read(playlistsProvider)
          .firstWhere((i) => i.playlist.playlistId == 'p2')
          .playlist
          .items,
      [_pdfA, _audioA],
      reason: 'a tela recarrega depois da escrita',
    );
    expect(sync.calls, 1, reason: 'lista salva dispara o sync');
  });

  test('rascunho não ativo que fica vazio é apagado, sem sync', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [_pdf(_pdfA)],
      playlistId: 'p3',
      salva: false,
    );
    final c = await boot();

    await c
        .read(playlistsProvider.notifier)
        .removeEntryAt(playlistId: 'p3', index: 0);
    await _flush();

    expect(await repository.getById('p3'), isNull);
    expect(sync.calls, 0);
  });

  test('posição fora da lista não grava nada', () async {
    await repository.create(
      nome: 'Outra',
      entries: [_pdf(_pdfA)],
      playlistId: 'p2',
      salva: true,
    );
    final c = await boot();

    await c
        .read(playlistsProvider.notifier)
        .removeEntryAt(playlistId: 'p2', index: 5);
    await _flush();

    expect((await repository.getById('p2'))!.items, [_pdfA]);
    expect(sync.calls, 0);
  });
}
