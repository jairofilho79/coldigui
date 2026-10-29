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

  Widget createHarness({
    required Size size,
    required FakeActiveEditor editor,
    required ColdigomCatalogSource source,
    required dynamic index,
  }) {
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    return ProviderScope(
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
    );
  }

  final groupCol = catalogGroup(
    praiseId: 'col_003',
    number: '003',
    name: 'Clamo a ti',
    tags: const ['Coletânea · Clamor'],
    groupId: 'g_003',
    pdfKinds: const {'k-col': 'Partitura'},
  );

  final groupPes = catalogGroup(
    praiseId: 'pes_003',
    number: '003',
    name: 'Clamo a ti',
    tags: const ['PES · 9.2026'],
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

  testWidgets(
    'em tela mobile (< 600px), a tag com subtag abrevia para o mínimo de 3+3 (ex: «Col · Cla»)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final entry = PlaylistEntry(id: colPdfId, kind: MaterialKind.pdf);
      final editor = FakeActiveEditor([entry]);

      await tester.pumpWidget(
        createHarness(
          size: const Size(390, 844),
          editor: editor,
          source: source,
          index: index,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CarouselChips)),
      );
      container.read(carouselFocusedIndexProvider.notifier).focusKey(entry.id);
      await tester.pumpAndSettle();

      expect(find.text('Col · Cla'), findsOneWidget);
    },
  );

  testWidgets(
    'em tela de tablet compacto (600 a 749px), a tag com subtag abrevia em 4+4 (ex: «Cole · Clam»)',
    (tester) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final entry = PlaylistEntry(id: colPdfId, kind: MaterialKind.pdf);
      final editor = FakeActiveEditor([entry]);

      await tester.pumpWidget(
        createHarness(
          size: const Size(700, 900),
          editor: editor,
          source: source,
          index: index,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CarouselChips)),
      );
      container.read(carouselFocusedIndexProvider.notifier).focusKey(entry.id);
      await tester.pumpAndSettle();

      expect(find.text('Cole · Clam'), findsOneWidget);
    },
  );

  testWidgets(
    'em desktop (>= 900px), a tag com subtag é exibida por completo («Coletânea · Clamor»)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final entry = PlaylistEntry(id: colPdfId, kind: MaterialKind.pdf);
      final editor = FakeActiveEditor([entry]);

      await tester.pumpWidget(
        createHarness(
          size: const Size(1200, 800),
          editor: editor,
          source: source,
          index: index,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CarouselChips)),
      );
      container.read(carouselFocusedIndexProvider.notifier).focusKey(entry.id);
      await tester.pumpAndSettle();

      expect(find.text('Coletânea · Clamor'), findsOneWidget);
    },
  );
}
