import 'dart:io';

import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/exceptions/invalid_share_playlist_exception.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl playlistRepository;
  late ImportSharedPlaylistFromUrl useCase;
  var resolverMap = <String, String>{};

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_playlist_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    resolverMap = <String, String>{};
    useCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      resolveShortIds: () async => resolverMap,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cria playlist salva a partir do share', () async {
    final result = await useCase(
      params: const PlaylistShareParams(
        sharePdfs: 'pdf-a, pdf-b',
        shareName: 'Lista importada',
      ),
    );

    expect(result.alreadyExisted, isFalse);
    final saved = await playlistRepository.getById(result.playlist.playlistId);
    expect(saved?.nome, 'Lista importada');
    expect(saved?.pdfIds, ['pdf-a', 'pdf-b']);
  });

  test('preserva ordem dos pdfIds', () async {
    await useCase(
      params: const PlaylistShareParams(sharePdfs: 'z,y,x', shareName: 'Ordem'),
    );

    final all = await playlistRepository.getAll();
    expect(all.single.pdfIds, ['z', 'y', 'x']);
  });

  test('lança InvalidSharePlaylistException se sharePdfs vazio', () async {
    expect(
      () => useCase(
        params: const PlaylistShareParams(sharePdfs: ' , ', shareName: 'Nome'),
      ),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
  });

  test(
    'URL só com sharename chega ao use case e lança InvalidShare... (D.6)',
    () async {
      final params = parsePlaylistShareParams(
        Uri.parse('https://plpcg.com/?sharename=Ensaio'),
      );
      // O parser não pode mais engolir o caso: quem avisa o usuário é a
      // exceção daqui, via snackbar `playlistImportInvalidUrl`.
      expect(params, isNotNull);

      expect(
        () => useCase(params: params!),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
    },
  );

  test('lança InvalidSharePlaylistException se shareName vazio', () async {
    expect(
      () => useCase(
        params: const PlaylistShareParams(sharePdfs: 'a,b', shareName: '  '),
      ),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
  });

  group('dedupe por conteúdo (spec C.2)', () {
    test(
      'lista salva já existente com o mesmo conteúdo — alreadyExisted true, nenhuma create',
      () async {
        final first = await useCase(
          params: const PlaylistShareParams(
            sharePdfs: 'a,b',
            shareName: 'Original',
          ),
        );
        expect(first.alreadyExisted, isFalse);

        final second = await useCase(
          params: const PlaylistShareParams(
            sharePdfs: 'a,b',
            shareName: 'Outro nome',
          ),
        );

        expect(second.alreadyExisted, isTrue);
        expect(second.playlist.playlistId, first.playlist.playlistId);
        // O nome não é atualizado — a lista existente não é tocada.
        expect(second.playlist.nome, 'Original');

        final all = await playlistRepository.getAll();
        expect(all, hasLength(1));
      },
    );

    test('a ordem das entradas importa — não deduplica', () async {
      await useCase(
        params: const PlaylistShareParams(
          shareItems: 'p:a,a:b',
          shareName: 'Ordem 1',
        ),
      );

      final result = await useCase(
        params: const PlaylistShareParams(
          shareItems: 'a:b,p:a',
          shareName: 'Ordem 2',
        ),
      );

      expect(result.alreadyExisted, isFalse);
      final all = await playlistRepository.getAll();
      expect(all, hasLength(2));
    });

    test('lista não salva (rascunho) com o mesmo conteúdo não conta', () async {
      await playlistRepository.create(
        nome: 'Rascunho',
        pdfIds: const ['a', 'b'],
        salva: false,
      );

      final result = await useCase(
        params: const PlaylistShareParams(
          sharePdfs: 'a,b',
          shareName: 'Importada',
        ),
      );

      expect(result.alreadyExisted, isFalse);
      final all = await playlistRepository.getAll();
      expect(all, hasLength(2));
    });

    test(
      'lista salva apagada (tombstone) com o mesmo conteúdo não conta',
      () async {
        final id = await playlistRepository.create(
          nome: 'Apagada',
          pdfIds: const ['a', 'b'],
          salva: true,
        );
        await playlistRepository.update(id, deletedAt: DateTime.now());

        final result = await useCase(
          params: const PlaylistShareParams(
            sharePdfs: 'a,b',
            shareName: 'Importada',
          ),
        );

        expect(result.alreadyExisted, isFalse);
      },
    );

    // Fix round 2 (Minor): uma exclusão adiada (C11) ainda não comitou —
    // `deletedAt` continua `null` no repositório durante a graça — então o
    // filtro de tombstone acima não basta; quem chama passa o id pendente
    // explicitamente para não reaproveitar uma lista que está pra sumir.
    test('lista pendente de exclusão (excludePlaylistId) com o mesmo conteúdo '
        'não conta', () async {
      final id = await playlistRepository.create(
        nome: 'Vai sair (exclusão adiada, ainda não comitou)',
        pdfIds: const ['a', 'b'],
        salva: true,
      );

      final result = await useCase(
        params: const PlaylistShareParams(
          sharePdfs: 'a,b',
          shareName: 'Importada',
        ),
        excludePlaylistId: id,
      );

      expect(result.alreadyExisted, isFalse);
      expect(result.playlist.playlistId, isNot(id));
    });
  });

  group('shareitems (v2)', () {
    test('cria a playlist com entries na ordem intercalada', () async {
      final result = await useCase(
        params: const PlaylistShareParams(
          shareItems: 'p:pdf-a,a:aud-1,c:cif-1',
          sharePdfs: 'pdf-a,cif-1',
          shareAudios: 'aud-1',
          shareName: 'Lista v2',
        ),
      );

      final saved = await playlistRepository.getById(
        result.playlist.playlistId,
      );
      expect(saved!.entries, const [
        PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
        PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
        PlaylistEntry(id: 'cif-1', kind: MaterialKind.chord),
      ]);
      expect(saved.items, ['pdf-a', 'aud-1', 'cif-1']);
      expect(saved.pdfIds, ['pdf-a', 'cif-1']);
      expect(saved.audioIds, ['aud-1']);
    });

    test('shareitems vence os legados quando divergem', () async {
      final result = await useCase(
        params: const PlaylistShareParams(
          shareItems: 'a:aud-1,p:pdf-a',
          sharePdfs: 'pdf-a',
          shareAudios: 'aud-1',
          shareName: 'Ordem v2',
        ),
      );

      final saved = await playlistRepository.getById(
        result.playlist.playlistId,
      );
      expect(saved!.items, ['aud-1', 'pdf-a']);
    });

    test('shareitems inválido cai nos legados', () async {
      final result = await useCase(
        params: const PlaylistShareParams(
          shareItems: 'lixo-sem-prefixo',
          sharePdfs: 'pdf-a',
          shareName: 'Fallback',
        ),
      );

      final saved = await playlistRepository.getById(
        result.playlist.playlistId,
      );
      expect(saved!.pdfIds, ['pdf-a']);
    });

    test('só áudio grava a lista inteira na face de áudio', () async {
      final result = await useCase(
        params: const PlaylistShareParams(
          shareItems: 'a:aud-1,a:aud-2',
          shareName: 'Só áudio',
        ),
      );

      final saved = await playlistRepository.getById(
        result.playlist.playlistId,
      );
      expect(saved!.audioIds, ['aud-1', 'aud-2']);
      expect(saved.pdfIds, isEmpty);
    });

    test('só cifra grava a lista na face de partituras', () async {
      final result = await useCase(
        params: const PlaylistShareParams(
          shareItems: 'c:cif-1',
          shareName: 'Só cifra',
        ),
      );

      final saved = await playlistRepository.getById(
        result.playlist.playlistId,
      );
      expect(saved!.pdfIds, ['cif-1']);
    });

    test('lança InvalidSharePlaylistException se tudo vazio', () async {
      expect(
        () => useCase(
          params: const PlaylistShareParams(
            shareItems: '',
            sharePdfs: '',
            shareName: 'Nome',
          ),
        ),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
    });

    // A reunião de origem pode repetir um louvor («Adicionar de novo»); a
    // importada tem que repetir também — o link é a lista, não um conjunto.
    test('id repetido cria duas entradas', () async {
      final result = await useCase(
        params: const PlaylistShareParams(
          shareItems: 'p:pdf-a,a:aud-1,p:pdf-a',
          sharePdfs: 'pdf-a,pdf-a',
          shareAudios: 'aud-1',
          shareName: 'Com repetição',
        ),
      );

      final saved = await playlistRepository.getById(
        result.playlist.playlistId,
      );
      expect(saved!.entries, const [
        PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
        PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
        PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
      ]);
      expect(saved.pdfIds, ['pdf-a', 'pdf-a']);
    });
  });
}
