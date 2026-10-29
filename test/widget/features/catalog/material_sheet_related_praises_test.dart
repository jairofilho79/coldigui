import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/related_praises_bar.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/fakes/fake_active_editor.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Finder findRelatedBar() => find.byType(RelatedPraisesBar);

  testWidgets(
    'exibe barra de versões quando há praises relacionados no índice e alterna ao tocar no chip',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final groupCol = catalogGroup(
        praiseId: 'col_003',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['Coletânea'],
        groupId: 'g_003',
        pdfKinds: const {'k-col': 'Partitura'},
      );

      final groupPes = catalogGroup(
        praiseId: 'pes_003',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['PES'],
        groupId: 'g_003',
        pdfKinds: const {'k-pes': 'Partitura'},
      );

      final colPdfId = groupCol.flatPdfMaterials.first.pdfId;
      final pesPdfId = groupPes.flatPdfMaterials.first.pdfId;

      final index = catalogIndexOf([groupCol, groupPes]);
      final source = ColdigomCatalogSource(
        louvores: {
          colPdfId: groupCol.flatPdfMaterials.first.louvor,
          pesPdfId: groupPes.flatPdfMaterials.first.louvor,
        },
        praiseMeta: {
          'col_003': groupCol.coldigomMeta!,
          'pes_003': groupPes.coldigomMeta!,
        },
        index: index,
      );

      final entry = PlaylistEntry(id: colPdfId, kind: MaterialKind.pdf);
      final editor = FakeActiveEditor([entry]);

      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showMaterialSheet(
                    context,
                    ref,
                    groupCol,
                    canAddToPlaylist: false,
                    currentMaterialId: colPdfId,
                    currentEntryKey: entry.id,
                  ),
                  child: const Text('Abrir Sheet'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, _) => const Scaffold(body: Text('Leitor')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePlaylistEditorProvider.overrideWith(() => editor),
            coldigomCatalogSourceProvider.overrideWithValue(source),
            coldigomSearchIndexProvider.overrideWithValue(index),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Sheet'));
      await tester.pumpAndSettle();

      final bar = findRelatedBar();
      // Barra de versões relacionadas está visível
      expect(bar, findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('Coletânea')), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('PES')), findsOneWidget);

      // Toca na versão 'PES' dentro da barra
      await tester.tap(find.descendant(of: bar, matching: find.text('PES')));
      await tester.pumpAndSettle();

      // Confirma que chamou replaceByKey na playlist ativa
      expect(editor.replaced.single.replacement.id, pesPdfId);
      expect(editor.replaced.single.key, entry.id);

      // Feedback snackbar exibido
      expect(find.textContaining('PES'), findsWidgets);
    },
  );

  testWidgets(
    'suporta swipe horizontal na barra de versões relacionadas para alternar versão',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final groupCol = catalogGroup(
        praiseId: 'col_003',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['Coletânea'],
        groupId: 'g_003',
        pdfKinds: const {'k-col': 'Partitura'},
      );

      final groupPes = catalogGroup(
        praiseId: 'pes_003',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['PES'],
        groupId: 'g_003',
        pdfKinds: const {'k-pes': 'Partitura'},
      );

      final colPdfId = groupCol.flatPdfMaterials.first.pdfId;
      final pesPdfId = groupPes.flatPdfMaterials.first.pdfId;

      final index = catalogIndexOf([groupCol, groupPes]);
      final source = ColdigomCatalogSource(
        louvores: {
          colPdfId: groupCol.flatPdfMaterials.first.louvor,
          pesPdfId: groupPes.flatPdfMaterials.first.louvor,
        },
        praiseMeta: {
          'col_003': groupCol.coldigomMeta!,
          'pes_003': groupPes.coldigomMeta!,
        },
        index: index,
      );

      final entry = PlaylistEntry(id: colPdfId, kind: MaterialKind.pdf);
      final editor = FakeActiveEditor([entry]);

      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showMaterialSheet(
                    context,
                    ref,
                    groupCol,
                    canAddToPlaylist: false,
                    currentMaterialId: colPdfId,
                    currentEntryKey: entry.id,
                  ),
                  child: const Text('Abrir Sheet'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, _) => const Scaffold(body: Text('Leitor')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePlaylistEditorProvider.overrideWith(() => editor),
            coldigomCatalogSourceProvider.overrideWithValue(source),
            coldigomSearchIndexProvider.overrideWithValue(index),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Sheet'));
      await tester.pumpAndSettle();

      final bar = findRelatedBar();
      // Swipe para a esquerda na barra de versões relacionadas
      await tester.drag(
        find.descendant(of: bar, matching: find.text('Coletânea')),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();

      // Substituiu pelo PES
      expect(editor.replaced.single.replacement.id, pesPdfId);
      expect(editor.replaced.single.key, entry.id);
    },
  );

  testWidgets(
    'não exibe barra de versões quando o praise não possui versões relacionadas',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final groupSolo = catalogGroup(
        praiseId: 'solo_001',
        number: '001',
        name: 'Praise Único',
        tags: const ['Avulso'],
        groupId: 'g_solo',
        pdfKinds: const {'k-solo': 'Partitura'},
      );

      final soloPdfId = groupSolo.flatPdfMaterials.first.pdfId;
      final index = catalogIndexOf([groupSolo]);
      final source = ColdigomCatalogSource(
        louvores: {soloPdfId: groupSolo.flatPdfMaterials.first.louvor},
        praiseMeta: {'solo_001': groupSolo.coldigomMeta!},
        index: index,
      );

      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showMaterialSheet(
                    context,
                    ref,
                    groupSolo,
                  ),
                  child: const Text('Abrir Sheet'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            coldigomCatalogSourceProvider.overrideWithValue(source),
            coldigomSearchIndexProvider.overrideWithValue(index),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Sheet'));
      await tester.pumpAndSettle();

      // Sem barra de versões relacionadas
      expect(findRelatedBar(), findsNothing);
    },
  );
}
