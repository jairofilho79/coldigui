import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

List<LouvorGroup> _groups(int count) => [
  for (var i = 1; i <= count; i++)
    catalogGroup(
      praiseId: 'p$i',
      number: '$i'.padLeft(3, '0'),
      name: 'Louvor $i',
    ),
];

Widget _libraryTestApp({
  required SharedPreferences prefs,
  required List<Override> catalogOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...catalogOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(body: LibraryScreen()),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLibrary(
    WidgetTester tester,
    List<LouvorGroup> groups,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _libraryTestApp(
        prefs: prefs,
        catalogOverrides: catalogIndexOverrides(catalogIndexOf(groups)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista os louvores do índice local, sem seletor de fonte', (
    tester,
  ) async {
    await pumpLibrary(tester, _groups(15));

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    // O seletor «Fonte: PLPCG | Coldigom» não existe mais.
    expect(find.text('Fonte'), findsNothing);
  });

  testWidgets('resumo dentro do card Visualização', (tester) async {
    await pumpLibrary(tester, _groups(15));

    final summary = find.textContaining('Mostrando 1');
    expect(summary, findsOneWidget);
    expect(find.text('10 por página'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: summary,
          matching: find.byType(GoldenTaggedContainer),
        ),
        matching: find.text('Visualização'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('troca página e ordenação', (tester) async {
    await pumpLibrary(tester, _groups(15));

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    expect(find.text('#011 — Louvor 11'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('#011 — Louvor 11'), findsOneWidget);
    expect(find.text('#001 — Louvor 1'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('#001 — Louvor 1'), findsOneWidget);

    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('#001 — Louvor 1')).dy,
      lessThan(tester.getTopLeft(find.text('#010 — Louvor 10')).dy),
    );
  });

  testWidgets('skeleton enquanto o índice hidrata', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final pending = Completer<ColdigomSearchIndex>();

    await tester.pumpWidget(
      _libraryTestApp(
        prefs: prefs,
        catalogOverrides: [
          coldigomCatalogHydrationProvider.overrideWith(
            (ref) => pending.future,
          ),
          coldigomCatalogSyncProvider.overrideWith(
            FakeColdigomCatalogSyncNotifier.new,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(LouvorGroupCardSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
  });
}
