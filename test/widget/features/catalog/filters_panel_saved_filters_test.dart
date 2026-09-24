import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

/// Filtros gravados (C13) restringem a busca da página inicial mesmo sem
/// nada na URL — o painel não pode escondê-los colapsado e mudo.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...catalogIndexOverrides(
          catalogIndexOf([
            catalogGroup(
              praiseId: 'p1',
              number: '001',
              name: 'Aleluia',
              tonality: 'G',
              tags: const ['PES'],
            ),
          ]),
        ),
        connectivityStreamProvider.overrideWith(
          (ref) => const Stream<bool>.empty(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(body: screen),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _persistFilters() {
  SharedPreferences.setMockInitialValues({
    StorageKeys.catalogFilters: jsonEncode({
      'v': 2,
      'tonalities': ['G'],
      'tags': ['PES'],
    }),
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'página inicial com filtros gravados: painel aberto e «Filtros (2)»',
    (tester) async {
      _persistFilters();

      await _pump(tester, const HomeScreen());

      expect(find.byType(CatalogFilterSections), findsOneWidget);
      expect(find.text('Filtros (2)'), findsOneWidget);

      // Colapsado, o cabeçalho continua a contar os filtros ativos.
      await tester.tap(find.text('Filtros (2)'));
      await tester.pump();
      expect(find.byType(CatalogFilterSections), findsNothing);
      expect(find.text('Filtros (2)'), findsOneWidget);
      expect(find.text('Toque para ver mais'), findsNothing);
    },
  );

  testWidgets('/biblioteca com filtros gravados: painel aberto e contagem', (
    tester,
  ) async {
    _persistFilters();

    await _pump(tester, const LibraryScreen());

    expect(find.byType(CatalogFilterSections), findsOneWidget);
    expect(find.text('Filtros (2)'), findsOneWidget);
  });

  testWidgets('sem filtros: painel fechado e «Toque para ver mais»', (
    tester,
  ) async {
    await _pump(tester, const HomeScreen());

    expect(find.byType(CatalogFilterSections), findsNothing);
    expect(find.text('Toque para ver mais'), findsOneWidget);
    expect(find.textContaining('Filtros ('), findsNothing);
  });
}
