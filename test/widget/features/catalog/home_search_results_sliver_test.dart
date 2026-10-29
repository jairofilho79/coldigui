import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/providers/recently_opened_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_cluster_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

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

  testWidgets('desenha um item por entrada: amendoim e chip solto, na ordem '
      'de entries', (tester) async {
    final aleluia = catalogGroup(
      praiseId: 'p-001',
      number: '001',
      name: 'Aleluia',
      groupId: 'G',
    );
    final aleluiaPes = catalogGroup(
      praiseId: 'r-1',
      number: '001',
      name: 'Aleluia (PES)',
      groupId: 'G',
    );
    final saoJoao = catalogGroup(
      praiseId: 'p-002',
      number: '002',
      name: 'São João',
    );
    final state = HomeSearchState(
      query: 'aleluia',
      localGroups: [aleluia, saoJoao],
      newGroups: [aleluiaPes],
      remote: AsyncData(CatalogSearchPage(groups: [aleluiaPes], page: 1)),
      entries: [
        ClusterEntry(
          praiseGroupId: 'G',
          members: [
            ClusterMember(group: aleluia, matched: true),
            ClusterMember(group: aleluiaPes, matched: true),
          ],
        ),
        SingleEntry(saoJoao),
      ],
    );

    await tester.pumpWidget(
      _sliverTestApp([
        activePlaylistEditorProvider.overrideWith(FakeActiveEditor.new),
        playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        homeSearchStateProvider.overrideWithValue(state),
      ]),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final cluster = find.byKey(const ValueKey('cluster-G'));
    expect(cluster, findsOneWidget);
    expect(
      tester.widget<LouvorClusterCard>(cluster).newGroupIds,
      state.newGroupIds,
    );
    // O «novo» do remoto está dentro do amendoim, não num chip no fim.
    expect(
      find.descendant(of: cluster, matching: find.byType(LouvorGroupCard)),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('card-r-1')), findsNothing);
    expect(find.byKey(const ValueKey('card-p-002')), findsOneWidget);
    expect(
      tester.getTopLeft(cluster).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('card-p-002'))).dy),
    );
  });
}
