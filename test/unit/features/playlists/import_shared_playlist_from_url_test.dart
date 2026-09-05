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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_playlist_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = ImportSharedPlaylistFromUrl(playlistRepository);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cria playlist salva a partir do share', () async {
    final id = await useCase(
      sharePdfs: 'pdf-a, pdf-b',
      shareName: 'Lista importada',
    );

    final saved = await playlistRepository.getById(id);
    expect(saved?.nome, 'Lista importada');
    expect(saved?.pdfIds, ['pdf-a', 'pdf-b']);
  });

  test('preserva ordem dos pdfIds', () async {
    await useCase(sharePdfs: 'z,y,x', shareName: 'Ordem');

    final all = await playlistRepository.getAll();
    expect(all.single.pdfIds, ['z', 'y', 'x']);
  });

  test('lança InvalidSharePlaylistException se sharePdfs vazio', () async {
    expect(
      () => useCase(sharePdfs: ' , ', shareName: 'Nome'),
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
        () => useCase(
          sharePdfs: params!.sharePdfs,
          shareAudios: params.shareAudios,
          shareItems: params.shareItems ?? '',
          shareName: params.shareName,
        ),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
    },
  );

  test('lança InvalidSharePlaylistException se shareName vazio', () async {
    expect(
      () => useCase(sharePdfs: 'a,b', shareName: '  '),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
  });

  group('shareitems (v2)', () {
    test('cria a playlist com entries na ordem intercalada', () async {
      final id = await useCase(
        shareItems: 'p:pdf-a,a:aud-1,c:cif-1',
        sharePdfs: 'pdf-a,cif-1',
        shareAudios: 'aud-1',
        shareName: 'Lista v2',
      );

      final saved = await playlistRepository.getById(id);
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
      final id = await useCase(
        shareItems: 'a:aud-1,p:pdf-a',
        sharePdfs: 'pdf-a',
        shareAudios: 'aud-1',
        shareName: 'Ordem v2',
      );

      final saved = await playlistRepository.getById(id);
      expect(saved!.items, ['aud-1', 'pdf-a']);
    });

    test('shareitems inválido cai nos legados', () async {
      final id = await useCase(
        shareItems: 'lixo-sem-prefixo',
        sharePdfs: 'pdf-a',
        shareName: 'Fallback',
      );

      final saved = await playlistRepository.getById(id);
      expect(saved!.pdfIds, ['pdf-a']);
    });

    test('só áudio grava a lista inteira na face de áudio', () async {
      final id = await useCase(
        shareItems: 'a:aud-1,a:aud-2',
        shareName: 'Só áudio',
      );

      final saved = await playlistRepository.getById(id);
      expect(saved!.audioIds, ['aud-1', 'aud-2']);
      expect(saved.pdfIds, isEmpty);
    });

    test('só cifra grava a lista na face de partituras', () async {
      final id = await useCase(shareItems: 'c:cif-1', shareName: 'Só cifra');

      final saved = await playlistRepository.getById(id);
      expect(saved!.pdfIds, ['cif-1']);
    });

    test('lança InvalidSharePlaylistException se tudo vazio', () async {
      expect(
        () => useCase(shareItems: '', sharePdfs: '', shareName: 'Nome'),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
    });
  });
}
