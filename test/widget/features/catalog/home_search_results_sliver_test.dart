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

LouvorGroup _group(String id) =>
    LouvorGroup(groupId: id, numero: '001', nome: id, sections: const []);

HomeSearchState _state({
  String query = 'agua',
  int page = 1,
  List<LouvorGroup> localGroups = const [],
  required AsyncValue<CatalogSearchPage> remote,
}) {
  return HomeSearchState(
    query: query,
    page: page,
    localGroups: localGroups,
    remote: remote,
  );
}

Widget _sliverTestApp(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sem consulta e sem grupos mostra o estado vazio da Home (C4)', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _sliverTestApp([
        sharedPreferencesProvider.overrideWithValue(prefs),
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

  testWidgets(
    'remoto falho e sem grupos ainda mostra "Coldigom indisponível" (C.8 preservado)',
    (tester) async {
      await tester.pumpWidget(
        _sliverTestApp([
          homeSearchStateProvider.overrideWithValue(
            _state(
              query: 'zzz',
              remote: AsyncError(Exception('boom'), StackTrace.empty),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum louvor para «zzz»'), findsOneWidget);
      expect(
        find.text('Coldigom indisponível · tentar de novo'),
        findsOneWidget,
      );
    },
  );

  testWidgets('remoto em erro mostra a linha "Coldigom indisponível"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sliverTestApp([
        homeSearchStateProvider.overrideWithValue(
          _state(remote: AsyncError(Exception('boom'), StackTrace.empty)),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coldigom indisponível · tentar de novo'), findsOneWidget);
    // Sem paginador enquanto a página remota está em erro.
    expect(find.text('Página 1'), findsNothing);

    // O toque re-dispara a busca (`retryRemoteSearch`) sem quebrar a árvore.
    await tester.tap(find.text('Coldigom indisponível · tentar de novo'));
    await tester.pumpAndSettle();
  });

  testWidgets('não mostra linha de erro quando a busca remota tem dados', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sliverTestApp([
        homeSearchStateProvider.overrideWithValue(
          _state(remote: const AsyncData(CatalogSearchPage.empty)),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coldigom indisponível · tentar de novo'), findsNothing);
  });

  testWidgets('remoto carregando mostra o spinner e esconde o paginador', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sliverTestApp([
        homeSearchStateProvider.overrideWithValue(
          _state(
            localGroups: [_group('local-1')],
            remote: const AsyncLoading(),
          ),
        ),
      ]),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Página 1'), findsNothing);
  });

  testWidgets('paginador aparece quando a página remota trouxe resultados', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sliverTestApp([
        homeSearchStateProvider.overrideWithValue(
          _state(
            page: 2,
            remote: AsyncData(
              CatalogSearchPage(
                groups: [_group('coldigom-1')],
                page: 2,
                hasNextPage: true,
              ),
            ),
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Página 2'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('avançar a página usa homeSearchPageProvider', (tester) async {
    await tester.pumpWidget(
      _sliverTestApp([
        homeSearchStateProvider.overrideWithValue(
          _state(
            remote: const AsyncData(
              CatalogSearchPage(groups: [], page: 1, hasNextPage: true),
            ),
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeSearchResultsSliver)),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(container.read(homeSearchPageProvider), 2);
  });
}
