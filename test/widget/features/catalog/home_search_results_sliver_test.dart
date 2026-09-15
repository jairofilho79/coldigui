import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/providers/recently_opened_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HomeSearchState _state({
  String query = 'agua',
  List<LouvorGroup> localGroups = const [],
  List<LouvorGroup> newGroups = const [],
  bool offline = false,
  required AsyncValue<CatalogSearchPage> remote,
}) {
  return HomeSearchState(
    query: query,
    localGroups: localGroups,
    remote: remote,
    newGroups: newGroups,
    offline: offline,
  );
}

late SharedPreferences _prefs;

/// Todo teste passa pelo `sharedPreferencesProvider`: desde a C13 o
/// `catalogFiltersProvider` (lido pelo estado vazio) persiste em prefs.
Widget _sliverTestApp(List<Override> overrides) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(
        body: CustomScrollView(slivers: [HomeSearchResultsSliver()]),
      ),
    ),
  );
}

class _EmptyRecentlyOpened extends RecentlyOpenedNotifier {
  @override
  List<String> build() => const [];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('sem consulta e sem grupos mostra o estado vazio da Home (C4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sliverTestApp([
        recentlyOpenedProvider.overrideWith(_EmptyRecentlyOpened.new),
        homeSearchStateProvider.overrideWithValue(
          _state(query: '', remote: const AsyncData(CatalogSearchPage.empty)),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Busque por título ou número'), findsOneWidget);
  });

  testWidgets(
    'consulta sem resultado e remoto concluído mostra "Nenhum louvor" (C4)',
    (tester) async {
      await tester.pumpWidget(
        _sliverTestApp([
          homeSearchStateProvider.overrideWithValue(
            _state(
              query: 'zzz',
              remote: const AsyncData(CatalogSearchPage.empty),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum louvor para «zzz»'), findsOneWidget);
    },
  );
}
