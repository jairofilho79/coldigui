import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/pages/praise_screen.dart';
import 'package:coldigui/features/catalog/presentation/widgets/coldigom_meta_block.dart';
import 'package:coldigui/features/catalog/presentation/widgets/praise_materials_view.dart';
import 'package:coldigui/features/catalog/presentation/widgets/related_praises_bar.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/fakes/fake_active_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    String? mockClipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        mockClipboard = (call.arguments as Map?)?['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': mockClipboard};
      }
      return null;
    });
  });

  LouvorGroup createTestGroup({
    required String praiseId,
    required String name,
    required String number,
    String? shortId,
    String? groupId,
    String author = 'Autor Teste',
    String tonality = 'D',
    String rhythm = 'Básico',
    List<String> tags = const ['Coletânea'],
    Map<String, String> pdfKinds = const {'k-partitura': 'Partitura'},
  }) {
    final detail = PraiseDetailDto(
      id: praiseId,
      name: name,
      number: number,
      author: author,
      tonality: tonality,
      rhythm: rhythm,
      tagNames: tags,
      shortId: shortId ?? praiseId,
      groupId: groupId ?? praiseId,
      materials: [
        for (final entry in pdfKinds.entries)
          MaterialDto(
            id: 'pdf-${entry.key}',
            type: 'pdf',
            r2Key: 'assets/praises/$praiseId/pdf-${entry.key}.pdf',
            materialKindId: entry.key,
            materialKindName: entry.value,
          ),
      ],
    );
    return LouvorGroup.fromLouvores(
      ColdigomLouvorAdapter.toLouvores(detail),
      audioTracks: ColdigomLouvorAdapter.toAudioTracks(detail),
      coldigomMetaByGroupId: {
        praiseId: ColdigomLouvorAdapter.toMetadata(detail),
      },
    ).single;
  }

  ColdigomPraiseCache createRow({
    required String praiseId,
    required String name,
    required String number,
    required String lyrics,
    String author = 'Autor Teste',
    String tonality = 'D',
    String rhythm = 'Básico',
    List<String> tags = const ['Coletânea'],
    String? shortId,
    String? groupId,
  }) {
    return ColdigomPraiseCache()
      ..praiseId = praiseId
      ..name = name
      ..number = number
      ..lyrics = lyrics
      ..author = author
      ..tonality = tonality
      ..rhythm = rhythm
      ..tags = tags
      ..materialsJson = '[]'
      ..searchTokens = ''
      ..shortId = shortId ?? praiseId
      ..groupId = groupId ?? praiseId;
  }

  testWidgets(
    'renderiza PraiseScreen com metadados, materiais e letra à mostra',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final group = createTestGroup(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        shortId: '0a1',
      );
      final index = catalogIndexOf([group]);
      final row = createRow(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        lyrics: 'Glória a Deus nas alturas\nE paz na terra aos homens.',
        shortId: '0a1',
      );

      final router = GoRouter(
        initialLocation: '/louvor/0a1',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) => PraiseScreen(
              id: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeEntriesProvider.overrideWithValue(const []),
            coldigomCatalogHydrationProvider.overrideWithValue(AsyncData(index)),
            coldigomSearchIndexProvider.overrideWithValue(index),
            coldigomCatalogRowProvider('g1').overrideWithValue(row),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Número e título
      expect(find.text('123'), findsWidgets);
      expect(find.text('Glória a Deus'), findsWidgets);

      // Bloco de metadados
      expect(find.byType(ColdigomMetaBlock), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('Básico'), findsOneWidget);
      expect(find.text('Autor Teste'), findsOneWidget);
      expect(find.text('Coletânea'), findsOneWidget);

      // Letra à mostra
      expect(find.textContaining('Glória a Deus nas alturas'), findsOneWidget);
      expect(find.textContaining('E paz na terra aos homens.'), findsOneWidget);

      // Seção de materiais
      expect(find.byType(PraiseMaterialsView), findsOneWidget);
      expect(find.text('Partitura'), findsOneWidget);
    },
  );

  testWidgets(
    'controles de fonte, cópia de letra e abertura do leitor funcionam',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final group = createTestGroup(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        shortId: '0a1',
      );
      final index = catalogIndexOf([group]);
      const sampleLyrics = 'Glória a Deus nas alturas\nE paz na terra aos homens.';
      final row = createRow(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        lyrics: sampleLyrics,
        shortId: '0a1',
      );

      String? navigatedTo;
      final router = GoRouter(
        initialLocation: '/louvor/0a1',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) => PraiseScreen(
              id: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.lyrics,
            builder: (context, state) {
              navigatedTo = state.uri.toString();
              return const Scaffold(body: Text('tela-leitor-letra'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeEntriesProvider.overrideWithValue(const []),
            coldigomCatalogHydrationProvider.overrideWithValue(AsyncData(index)),
            coldigomSearchIndexProvider.overrideWithValue(index),
            coldigomCatalogRowProvider('g1').overrideWithValue(row),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Botões de tamanho de fonte
      final incFinder = find.byIcon(Icons.text_increase);
      final decFinder = find.byIcon(Icons.text_decrease);
      expect(incFinder, findsOneWidget);
      expect(decFinder, findsOneWidget);

      await tester.tap(incFinder);
      await tester.pumpAndSettle();
      await tester.tap(decFinder);
      await tester.pumpAndSettle();

      // Botão de copiar letra
      final copyFinder = find.byIcon(Icons.copy_rounded);
      expect(copyFinder, findsOneWidget);
      await tester.tap(copyFinder);
      await tester.pump();

      // Snackbar de confirmação
      expect(find.text('Letra copiada!'), findsOneWidget);
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, sampleLyrics);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Botão de abrir no leitor
      final openReaderFinder = find.byIcon(Icons.play_circle_outline);
      expect(openReaderFinder, findsOneWidget);
      await tester.tap(openReaderFinder);
      await tester.pumpAndSettle();

      expect(find.text('tela-leitor-letra'), findsOneWidget);
      expect(navigatedTo, contains('/letra'));
      expect(navigatedTo, contains('praiseId=g1'));
    },
  );

  testWidgets(
    'compartilhar copia link direto para o clipboard com snackbar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final group = createTestGroup(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        shortId: '0a1',
      );
      final index = catalogIndexOf([group]);
      final row = createRow(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        lyrics: 'Letra',
        shortId: '0a1',
      );

      final router = GoRouter(
        initialLocation: '/louvor/0a1',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) => PraiseScreen(
              id: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeEntriesProvider.overrideWithValue(const []),
            coldigomCatalogHydrationProvider.overrideWithValue(AsyncData(index)),
            coldigomSearchIndexProvider.overrideWithValue(index),
            coldigomCatalogRowProvider('g1').overrideWithValue(row),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shareFinder = find.byIcon(Icons.share_outlined);
      expect(shareFinder, findsOneWidget);
      await tester.tap(shareFinder);
      await tester.pump();
      await tester.pump();

      expect(find.text('Link do louvor copiado!'), findsOneWidget);
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clip?.text, contains('/louvor/0a1'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'quando o louvor não existe exibe estado de não encontrado e botão de voltar',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? currentPath;
      final router = GoRouter(
        initialLocation: '/louvor/inexistente',
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) {
              currentPath = state.uri.path;
              return const Scaffold(body: Text('tela-home'));
            },
          ),
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) {
              currentPath = state.uri.path;
              return PraiseScreen(id: state.pathParameters['id'] ?? '');
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            catalogIndexStatusProvider.overrideWithValue(CatalogIndexStatus.ready),
            coldigomCatalogHydrationProvider.overrideWithValue(const AsyncData(ColdigomSearchIndex.empty)),
            coldigomSearchIndexProvider.overrideWithValue(ColdigomSearchIndex.empty),
            coldigomCatalogSyncProvider.overrideWith(() => FakeColdigomCatalogSyncNotifier()),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Louvor não encontrado'), findsOneWidget);
      expect(find.text('Voltar para o início'), findsOneWidget);

      await tester.tap(find.text('Voltar para o início'));
      await tester.pumpAndSettle();

      expect(find.text('tela-home'), findsOneWidget);
      expect(currentPath, RoutePaths.home);
    },
  );

  testWidgets(
    'exibe indicador de carregamento enquanto o catálogo está sincronizando',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/louvor/0a1',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) => PraiseScreen(
              id: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            catalogIndexStatusProvider.overrideWithValue(CatalogIndexStatus.loading),
            coldigomSearchIndexProvider.overrideWithValue(ColdigomSearchIndex.empty),
            coldigomCatalogSyncProvider.overrideWith(
              () => FakeColdigomCatalogSyncNotifier(
                const ColdigomCatalogSyncState(isSyncing: true),
              ),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'exibe mensagem de erro e botão tentar novamente quando o catálogo falha',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/louvor/0a1',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) => PraiseScreen(
              id: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            catalogIndexStatusProvider.overrideWithValue(CatalogIndexStatus.failed),
            coldigomSearchIndexProvider.overrideWithValue(ColdigomSearchIndex.empty),
            coldigomCatalogSyncProvider.overrideWith(
              () => FakeColdigomCatalogSyncNotifier(
                const ColdigomCatalogSyncState(
                  lastResult: ColdigomCatalogSyncFailed('falha'),
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    },
  );

  testWidgets(
    'permite adicionar material à lista de reprodução diretamente na página',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final group = createTestGroup(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        shortId: '0a1',
      );
      final index = catalogIndexOf([group]);
      final row = createRow(
        praiseId: 'g1',
        name: 'Glória a Deus',
        number: '123',
        lyrics: 'Letra',
        shortId: '0a1',
      );

      final editor = FakeActiveEditor();

      final router = GoRouter(
        initialLocation: '/louvor/0a1',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) => PraiseScreen(
              id: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeEntriesProvider.overrideWithValue(const []),
            activePlaylistEditorProvider.overrideWith(() => editor),
            coldigomCatalogHydrationProvider.overrideWithValue(AsyncData(index)),
            coldigomSearchIndexProvider.overrideWithValue(index),
            coldigomCatalogRowProvider('g1').overrideWithValue(row),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addBtnFinder = find.byType(CarouselLouvorAddButton);
      expect(addBtnFinder, findsOneWidget);

      await tester.tap(addBtnFinder);
      await tester.pumpAndSettle();

      expect(editor.added.length, 1);
      expect(editor.added.first.kind, MaterialKind.pdf);
    },
  );

  testWidgets(
    'barra de louvores relacionados exibe versões e permite alternar entre elas',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final group1 = createTestGroup(
        praiseId: 'col_003',
        name: 'Clamo a ti',
        number: '003',
        tags: const ['Coletânea'],
        groupId: 'cluster_003',
        shortId: 'c03',
      );
      final group2 = createTestGroup(
        praiseId: 'pes_003',
        name: 'Clamo a ti',
        number: '003',
        tags: const ['PES'],
        groupId: 'cluster_003',
        shortId: 'p03',
      );

      final index = catalogIndexOf([group1, group2]);
      final row1 = createRow(
        praiseId: 'col_003',
        name: 'Clamo a ti',
        number: '003',
        lyrics: 'Clamo a ti Senhor',
        shortId: 'c03',
        groupId: 'cluster_003',
      );
      final row2 = createRow(
        praiseId: 'pes_003',
        name: 'Clamo a ti',
        number: '003',
        lyrics: 'Clamo a ti meu Pai',
        shortId: 'p03',
        groupId: 'cluster_003',
      );

      String? currentLocation;
      final router = GoRouter(
        initialLocation: '/louvor/c03',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) {
              currentLocation = state.uri.path;
              return PraiseScreen(id: state.pathParameters['id'] ?? '');
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarStatusProvider.overrideWithValue(IsarStatus.available),
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeEntriesProvider.overrideWithValue(const []),
            coldigomCatalogHydrationProvider.overrideWithValue(AsyncData(index)),
            coldigomSearchIndexProvider.overrideWithValue(index),
            coldigomCatalogRowProvider('col_003').overrideWithValue(row1),
            coldigomCatalogRowProvider('pes_003').overrideWithValue(row2),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RelatedPraisesBar), findsOneWidget);
      expect(find.text('Coletânea'), findsWidgets);
      expect(find.text('PES'), findsWidgets);

      // Tocar no chip da outra versão (PES)
      await tester.tap(find.text('PES').first);
      await tester.pumpAndSettle();

      expect(currentLocation, '/louvor/p03');
    },
  );
}
