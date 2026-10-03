import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
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

  testWidgets(
    'exibe tag da versão e swipe no botão de material alterna entre praises relacionados e atualiza playlist',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
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
            builder: (_, _) => const Scaffold(body: CarouselChips()),
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

      // Foca a entrada do louvor
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CarouselChips)),
      );
      container
          .read(carouselFocusedIndexProvider.notifier)
          .focusKey(entry.id);
      await tester.pumpAndSettle();

      // Botão «Material» aparece
      expect(find.byIcon(Icons.change_circle_outlined), findsOneWidget);

      // Tag da versão atual aparece na barra (ex: «Coletânea»)
      expect(find.text('Coletânea'), findsOneWidget);

      // Faz swipe horizontal para a esquerda no botão de material para trocar para o praise relacionado
      await tester.drag(
        find.byIcon(Icons.change_circle_outlined),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();

      // A playlist ativa foi atualizada com o material do praise relacionado (PES)
      expect(editor.replaced.single.replacement.id, pesPdfId);
      expect(editor.replaced.single.key, entry.id);

      // Feedback snackbar exibido
      expect(find.textContaining('PES'), findsWidgets);
    },
  );
}
