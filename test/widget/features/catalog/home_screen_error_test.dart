import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../helpers/louvores_manifest_test_helpers.dart';

Widget _homeErrorTestApp({
  required SharedPreferences prefs,
  required List<Override> extraOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // O estado vazio ainda resolve os «recentes» pelo lookup de materiais,
      // que lê o manifesto até o plano 3 o reapontar — sem isto ele abriria
      // o Isar e a rede de verdade.
      louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const HomeScreen(),
    ),
  );
}

/// `pumpAndSettle` trava com o shimmer do skeleton (animação em loop).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _failed = ColdigomCatalogSyncState(
  lastResult: ColdigomCatalogSyncFailed('sem rede'),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'catálogo vazio com sync falhado: erro e «Tentar novamente» chama sync()',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final sync = FakeColdigomCatalogSyncNotifier(_failed);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);
      final retry = find.widgetWithText(FilledButton, 'Tentar novamente');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await _settle(tester);

      expect(sync.syncCalls, 1);
    },
  );

  testWidgets(
    '«Tentar novamente» também refaz a hidratação (erro ao ler o catálogo)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final sync = FakeColdigomCatalogSyncNotifier();
      var hydrations = 0;

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            coldigomCatalogHydrationProvider.overrideWith((ref) async {
              hydrations++;
              throw StateError('Isar ilegível');
            }),
            coldigomCatalogSyncProvider.overrideWith(() => sync),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);
      expect(hydrations, 1);

      final retry = find.widgetWithText(FilledButton, 'Tentar novamente');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await _settle(tester);

      expect(sync.syncCalls, 1);
      expect(hydrations, 2);
    },
  );

  testWidgets(
    'a rede volta (offline → online) com o catálogo vazio: sync() sozinho',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final sync = FakeColdigomCatalogSyncNotifier(_failed);
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivity.stream,
            ),
          ],
        ),
      );
      await _settle(tester);
      expect(sync.syncCalls, 0);

      connectivity.add(false);
      await _settle(tester);
      expect(sync.syncCalls, 0);

      connectivity.add(true);
      await _settle(tester);
      expect(sync.syncCalls, 1);

      // Outra queda e volta: outra tentativa.
      connectivity.add(false);
      await _settle(tester);
      connectivity.add(true);
      await _settle(tester);
      expect(sync.syncCalls, 2);
    },
  );

  testWidgets(
    'arranque offline: o primeiro «online» (vindo de loading) com o sync '
    'falhado sincroniza',
    (tester) async {
      // Web: o connectivity_plus não emite valor inicial, só os eventos
      // online/offline do browser — depois de um arranque sem rede o
      // primeiro `true` chega direto de loading.
      final prefs = await SharedPreferences.getInstance();
      final sync = FakeColdigomCatalogSyncNotifier(_failed);
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivity.stream,
            ),
          ],
        ),
      );
      await _settle(tester);
      expect(sync.syncCalls, 0);

      connectivity.add(true);
      await _settle(tester);
      expect(sync.syncCalls, 1);
    },
  );

  testWidgets(
    'o primeiro «online» (vindo de loading) com o catálogo ainda a carregar '
    'não sincroniza',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      // Sem resultado de sync ainda: o boot está a sincronizar.
      final sync = FakeColdigomCatalogSyncNotifier(
        const ColdigomCatalogSyncState(),
      );
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivity.stream,
            ),
          ],
        ),
      );
      await _settle(tester);

      connectivity.add(true);
      await _settle(tester);
      expect(sync.syncCalls, 0);
    },
  );

  testWidgets(
    'catálogo pronto: sem erro, e a volta da rede (ou «online» repetido) não sincroniza',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final sync = FakeColdigomCatalogSyncNotifier(_failed);
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            ...catalogIndexOverrides(
              catalogIndexOf([catalogGroup(praiseId: 'p1', name: 'Aleluia')]),
              sync: sync,
            ),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivity.stream,
            ),
          ],
        ),
      );
      await _settle(tester);

      connectivity.add(false);
      await _settle(tester);
      connectivity.add(true);
      await _settle(tester);
      // online → online (evento repetido) com o índice pronto: também não.
      connectivity.add(true);
      await _settle(tester);

      expect(find.text('Não foi possível carregar o catálogo'), findsNothing);
      expect(sync.syncCalls, 0);
    },
  );
}
