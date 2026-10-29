// test/widget/features/gestures/open_gesture_in_reader_test.dart
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:coldigui/features/gestures/presentation/utils/open_gesture_in_reader.dart';
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

import '../../../helpers/legacy_ids_normalizer_test_helpers.dart';

final _gestureId = encodePdfId('assets/praises/p1/m1.gestures');
final _pdfA = encodePdfId('ColAdultos/001.pdf');

final _gesture = GestureMaterial(
  gestureId: _gestureId,
  r2Key: 'assets/praises/p1/m1.gestures',
  nome: 'Comigo habita',
  numero: '001',
  groupId: 'p1',
  categoria: 'Gestos',
  classificacao: 'ColAdultos',
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('open_gesture_');
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

  /// Monta a tela com um botão que dispara o `openGestureInReader` de produção.
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
                  onPressed: () => openGestureInReader(
                    ref: ref,
                    context: context,
                    gesture: _gesture,
                  ),
                  child: const Text('abrir'),
                ),
              );
            },
          ),
        ),
        GoRoute(
          path: RoutePaths.gestos,
          builder: (_, state) => Scaffold(
            body: Text('gesto:${state.uri.queryParameters['pdfId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noOpLegacyMaterialIdsNormalizerOverride(),
          isarStatusProvider.overrideWithValue(IsarStatus.available),
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistRepositoryProvider.overrideWithValue(repository),
          carouselLocalDatasourceProvider.overrideWithValue(
            const CarouselLocalDatasource.unavailable(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Garante a lista ativa carregada antes de abrir o gesto.
    capturedRef.read(playlistsProvider);
    // Quem grava o gesto no cache é quem monta o grupo (pelo
    // `coldigomCacheWriter`) antes de o tile abrir; `openGestureInReader` só
    // entra na lista e navega.
    capturedRef.read(coldigomCacheWriterProvider).mergeGestures([_gesture]);
    await tester.pumpAndSettle();
    return capturedRef;
  }

  testWidgets('gesto já na lista ativa abre /gestos sem regravar a lista', (
    tester,
  ) async {
    // O tile passou a abrir o gesto pelo `openMaterialProvider`, que em
    // produção é o `openGestureInReader` — e ele entra na lista ativa como o
    // PDF faz. Este teste fixa o efeito colateral do caminho composto: o
    // gesto que já está na lista **não** regrava a lista (só foca o chip).
    await repository.create(
      nome: 'Ensaio',
      pdfIds: [_gestureId],
      playlistId: 'p1',
      salva: false,
    );
    final before = await repository.getById('p1');

    final ref = await pump(tester, carouselPdfIds: [_gestureId]);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final after = await repository.getById('p1');
    expect(after!.updatedAt, before!.updatedAt);
    expect(after.version, before.version);
    expect(after.items, [_gestureId]);
    expect(find.text('gesto:$_gestureId'), findsOneWidget);
    expect(
      ref.read(coldigomGestureMaterialsCacheProvider)[_gestureId],
      isNotNull,
    );
  });

  testWidgets('gesto fora da lista ativa entra na lista (controle)', (
    tester,
  ) async {
    // Controle do teste acima: com o gesto ausente o mesmo caminho **grava**
    // a lista, o que prova que as asserções de "não regravou" pegam a escrita.
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
    expect(after!.items, [_pdfA, _gestureId]);
    expect(after.updatedAt.isAfter(before!.updatedAt), isTrue);
    expect(find.text('gesto:$_gestureId'), findsOneWidget);
  });
}
