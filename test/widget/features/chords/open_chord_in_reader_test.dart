// test/widget/features/chords/open_chord_in_reader_test.dart
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/presentation/utils/open_chord_in_reader.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

final _chordId = encodePdfId('assets/praises/p1/m1.chord');
final _pdfA = encodePdfId('ColAdultos/001.pdf');

final _chord = ChordMaterial(
  chordId: _chordId,
  r2Key: 'assets/praises/p1/m1.chord',
  nome: 'Comigo habita',
  numero: '001',
  groupId: 'p1',
  categoria: 'Cifra',
  classificacao: 'ColAdultos',
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('open_chord_');
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

  /// Monta a tela com um botão que dispara o `openChordInReader` de produção.
  Future<WidgetRef> pump(
    WidgetTester tester, {
    required List<String> carouselPdfIds,
  }) async {
    late WidgetRef capturedRef;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: TextButton(
                  onPressed: () => openChordInReader(
                    ref: ref,
                    context: context,
                    chord: _chord,
                  ),
                  child: const Text('abrir'),
                ),
              );
            },
          ),
        ),
        GoRoute(
          path: RoutePaths.chords,
          builder: (_, state) => Scaffold(
            body: Text('cifra:${state.uri.queryParameters['pdfId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistRepositoryProvider.overrideWithValue(repository),
          carouselLocalDatasourceProvider.overrideWithValue(
            const CarouselLocalDatasource.unavailable(),
          ),
          louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Garante a lista ativa carregada antes de abrir a cifra.
    capturedRef.read(playlistsProvider);
    // Quem grava a cifra no cache é o sheet de materiais (pelo
    // `coldigomCacheWriter`) antes de o tile abrir; `openChordInReader` só
    // entra na lista e navega.
    capturedRef.read(coldigomCacheWriterProvider).mergeChords([_chord]);
    await tester.pumpAndSettle();
    return capturedRef;
  }

  testWidgets('cifra já na lista ativa abre /cifra sem regravar a lista', (
    tester,
  ) async {
    // O tile passou a abrir a cifra pelo `openMaterialProvider`, que em
    // produção é o `openChordInReader` — e ele entra na lista ativa como o PDF
    // faz. Este teste fixa o efeito colateral do caminho composto: a cifra que
    // já está na lista **não** regrava a lista (só foca o chip).
    await repository.create(
      nome: 'Ensaio',
      pdfIds: [_chordId],
      playlistId: 'p1',
      salva: false,
    );
    final before = await repository.getById('p1');

    final ref = await pump(tester, carouselPdfIds: [_chordId]);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final after = await repository.getById('p1');
    expect(after!.updatedAt, before!.updatedAt);
    expect(after.version, before.version);
    expect(after.items, [_chordId]);
    expect(find.text('cifra:$_chordId'), findsOneWidget);
    expect(ref.read(coldigomChordMaterialsCacheProvider)[_chordId], isNotNull);
  });

  testWidgets('cifra fora da lista ativa entra na lista (controle)', (
    tester,
  ) async {
    // Controle do teste acima: com a cifra ausente o mesmo caminho **grava** a
    // lista, o que prova que as asserções de "não regravou" pegam a escrita.
    await repository.create(
      nome: 'Ensaio',
      pdfIds: [_pdfA],
      playlistId: 'p1',
      salva: false,
    );
    final before = await repository.getById('p1');

    await pump(tester, carouselPdfIds: [_pdfA]);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final after = await repository.getById('p1');
    expect(after!.items, [_pdfA, _chordId]);
    expect(after.updatedAt.isAfter(before!.updatedAt), isTrue);
    expect(find.text('cifra:$_chordId'), findsOneWidget);
  });
}
