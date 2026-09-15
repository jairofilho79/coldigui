import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_freshness_line.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LouvorGroup _group(String id) => LouvorGroup(
  groupId: id,
  numero: '001',
  nome: id,
  sections: const [],
  coldigomMeta: const ColdigomPraiseMetadata(name: 'x'),
);

late SharedPreferences _prefs;

Future<void> _pump(WidgetTester tester, HomeSearchState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        homeSearchStateProvider.overrideWithValue(state),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(
          body: CustomScrollView(slivers: [HomeSearchResultsSliver()]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  final local = [_group('a'), _group('b')];

  testWidgets('checking / updated / offline / failed', (tester) async {
    await _pump(
      tester,
      HomeSearchState(
        query: 'x',
        localGroups: local,
        remote: const AsyncLoading(),
      ),
    );
    expect(find.text('Em cache · a verificar…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await _pump(
      tester,
      HomeSearchState(
        query: 'x',
        localGroups: local,
        remote: const AsyncData(CatalogSearchPage.empty),
      ),
    );
    expect(find.text('Atualizado'), findsOneWidget);

    await _pump(
      tester,
      HomeSearchState(
        query: 'x',
        localGroups: local,
        remote: const AsyncLoading(),
        offline: true,
      ),
    );
    expect(find.text('Em cache · sem ligação'), findsOneWidget);

    await _pump(
      tester,
      HomeSearchState(
        query: 'x',
        localGroups: local,
        remote: AsyncError(Exception('boom'), StackTrace.empty),
      ),
    );
    expect(find.text('Em cache · não foi possível verificar'), findsOneWidget);
    expect(find.text('Coldigom indisponível · tentar de novo'), findsNothing);
  });

  testWidgets(
    'updatedWithNew: «N novos» na linha e chip «novo» só nos cards novos',
    (tester) async {
      await _pump(
        tester,
        HomeSearchState(
          query: 'x',
          localGroups: local,
          remote: AsyncData(CatalogSearchPage(groups: [_group('c')], page: 1)),
          newGroups: [_group('c')],
        ),
      );

      expect(find.text('Atualizado · 1 novo'), findsOneWidget);
      expect(find.text('novo'), findsOneWidget);
      // O chip vive no card do grupo novo, o último da lista.
      final chip = find.text('novo');
      expect(
        find.ancestor(
          of: chip,
          matching: find.byWidgetPredicate(
            (w) => w.key == const ValueKey('card-c'),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'sem query não há linha; query com resultado vazio a verificar mostra só a linha',
    (tester) async {
      await _pump(
        tester,
        const HomeSearchState(
          query: '',
          localGroups: [],
          remote: AsyncData(CatalogSearchPage.empty),
        ),
      );
      expect(find.byType(SearchFreshnessLine), findsNothing);

      await _pump(
        tester,
        const HomeSearchState(
          query: 'zzz',
          localGroups: [],
          remote: AsyncLoading(),
        ),
      );
      expect(find.byType(SearchFreshnessLine), findsOneWidget);
      expect(find.text('Nenhum louvor para «zzz»'), findsNothing);

      await _pump(
        tester,
        const HomeSearchState(
          query: 'zzz',
          localGroups: [],
          remote: AsyncData(CatalogSearchPage.empty),
        ),
      );
      expect(find.text('Nenhum louvor para «zzz»'), findsOneWidget);
    },
  );
}
