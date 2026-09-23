import 'dart:async';
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/exceptions/invalid_share_playlist_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/legacy_share_link_exception.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

const _pdfA = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _audio1 = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);
const _pdfB = PlaylistEntry(id: 'pdf-b', kind: MaterialKind.pdf);

PlaylistShareParams _link(String nome, List<String> tokens) =>
    PlaylistShareParams(shareName: nome, praiseShortIds: tokens);

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl playlistRepository;
  late ImportSharedPlaylistFromUrl useCase;
  const catalog = {'0a1': _pdfA, '0c3': _audio1, 'fff': _pdfB};
  var loaderCalls = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_playlist_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    loaderCalls = 0;
    useCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      loadPraiseEntryResolver: () async {
        loaderCalls++;
        return (shortId) => catalog[shortId];
      },
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'cria lista salva com uma entrada por token, na ordem, com repetição',
    () async {
      final result = await useCase(
        params: _link('Culto', ['0a1', '0c3', '0a1']),
      );

      expect(result.alreadyExisted, isFalse);
      final saved = await playlistRepository.getById(
        result.playlist.playlistId,
      );
      expect(saved!.nome, 'Culto');
      expect(saved.salva, isTrue);
      expect(saved.entries, const [_pdfA, _audio1, _pdfA]);
    },
  );

  test('token desconhecido é saltado e o resto importa', () async {
    final result = await useCase(params: _link('Culto', ['abc', 'fff']));
    final saved = await playlistRepository.getById(result.playlist.playlistId);
    expect(saved!.entries, const [_pdfB]);
  });

  test('nenhum token resolvido → InvalidSharePlaylistException', () async {
    await expectLater(
      useCase(params: _link('Culto', ['abc'])),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
    expect(await playlistRepository.getAll(), isEmpty);
  });

  test(
    'sem token ou com nome em branco lança sem acordar o resolver',
    () async {
      await expectLater(
        useCase(params: _link('Culto', const [])),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
      await expectLater(
        useCase(params: _link('  ', ['0a1'])),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
      expect(loaderCalls, 0);
    },
  );

  test(
    'link antigo → LegacyShareLinkException sem acordar o resolver',
    () async {
      await expectLater(
        useCase(params: const PlaylistShareParams.legacy()),
        throwsA(isA<LegacyShareLinkException>()),
      );
      expect(loaderCalls, 0);
    },
  );

  test('o resolver é aguardado (deep link antes do catálogo)', () async {
    final completer = Completer<PraiseEntryResolver>();
    final lateUseCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      loadPraiseEntryResolver: () => completer.future,
    );
    final future = lateUseCase(params: _link('Culto', ['0a1']));
    completer.complete((shortId) => catalog[shortId]);
    expect((await future).playlist.entries, const [_pdfA]);
  });

  test(
    'catálogo que não chegou no prazo → InvalidSharePlaylistException',
    () async {
      final emptyUseCase = ImportSharedPlaylistFromUrl(
        playlistRepository,
        loadPraiseEntryResolver: () async =>
            (_) => null,
      );
      await expectLater(
        emptyUseCase(params: _link('Culto', ['0a1'])),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
    },
  );

  group('dedupe por conteúdo (spec C.2)', () {
    test(
      'lista salva com o mesmo conteúdo — alreadyExisted, nenhuma create',
      () async {
        final first = await useCase(params: _link('Original', ['0a1', 'fff']));
        expect(first.alreadyExisted, isFalse);

        final second = await useCase(
          params: _link('Outro nome', ['0a1', 'fff']),
        );

        expect(second.alreadyExisted, isTrue);
        expect(second.playlist.playlistId, first.playlist.playlistId);
        expect(second.playlist.nome, 'Original');
        expect(await playlistRepository.getAll(), hasLength(1));
      },
    );

    test('a ordem importa — não deduplica', () async {
      await useCase(params: _link('Ordem 1', ['0a1', 'fff']));
      final result = await useCase(params: _link('Ordem 2', ['fff', '0a1']));
      expect(result.alreadyExisted, isFalse);
      expect(await playlistRepository.getAll(), hasLength(2));
    });

    test('rascunho com o mesmo conteúdo não conta', () async {
      await playlistRepository.create(
        nome: 'Rascunho',
        entries: const [_pdfA, _pdfB],
        salva: false,
      );
      final result = await useCase(params: _link('Importada', ['0a1', 'fff']));
      expect(result.alreadyExisted, isFalse);
      expect(await playlistRepository.getAll(), hasLength(2));
    });

    test('lista salva apagada (tombstone) não conta', () async {
      final id = await playlistRepository.create(
        nome: 'Apagada',
        entries: const [_pdfA, _pdfB],
        salva: true,
      );
      await playlistRepository.update(id, deletedAt: DateTime.now());

      final result = await useCase(params: _link('Importada', ['0a1', 'fff']));
      expect(result.alreadyExisted, isFalse);
    });

    // Fix round 2 (Minor): exclusão adiada (C11) ainda sem `deletedAt`.
    test('lista pendente de exclusão (excludePlaylistId) não conta', () async {
      final id = await playlistRepository.create(
        nome: 'Vai sair',
        entries: const [_pdfA, _pdfB],
        salva: true,
      );
      final result = await useCase(
        params: _link('Importada', ['0a1', 'fff']),
        excludePlaylistId: id,
      );
      expect(result.alreadyExisted, isFalse);
      expect(result.playlist.playlistId, isNot(id));
    });
  });
}
