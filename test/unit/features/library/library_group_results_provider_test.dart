import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith(List<LouvorGroup> groups) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomSearchIndexProvider.overrideWithValue(catalogIndexOf(groups)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// [count] grupos em ordem **inversa** de número — prova que ordena.
  List<LouvorGroup> numbered(int count) => [
    for (var i = count; i >= 1; i--)
      catalogGroup(
        praiseId: 'p$i',
        number: '$i'.padLeft(3, '0'),
        name: 'Louvor $i',
      ),
  ];

  List<String> ids(ProviderContainer c) => [
    for (final g in c.read(libraryGroupResultsProvider).items) g.groupId,
  ];

  test('ordena por número e pagina', () {
    final c = containerWith(numbered(25));
    c.read(libraryViewSettingsProvider.notifier).setPage(2);

    final page = c.read(libraryGroupResultsProvider);

    expect(page.totalItems, 25);
    expect(page.totalPages, 3);
    expect(page.page, 2);
    expect(page.items, hasLength(10));
    expect(page.items.first.numero, '011');
  });

  test('ordena por nome sem distinguir caixa', () {
    final c = containerWith([
      catalogGroup(praiseId: 'b', number: '001', name: 'Bendito'),
      catalogGroup(praiseId: 'a', number: '002', name: 'aleluia'),
    ]);
    c.read(libraryViewSettingsProvider.notifier).setSortBy('nome');

    expect(ids(c), ['a', 'b']);
  });

  test('página além do fim cai na última', () {
    final c = containerWith(numbered(12));
    c.read(libraryViewSettingsProvider.notifier).setPage(9);

    final page = c.read(libraryGroupResultsProvider);

    expect(page.page, 2);
    expect(page.items, hasLength(2));
  });

  test('índice vazio → página vazia', () {
    final c = containerWith(const []);
    expect(c.read(libraryGroupResultsProvider).totalItems, 0);
  });

  test('2063 grupos: pipeline síncrono folgado (medição do Desvio 1)', () {
    final c = containerWith(numbered(2063));
    final stopwatch = Stopwatch()..start();
    c.read(libraryGroupResultsProvider);
    stopwatch.stop();
    debugPrint(
      'biblioteca: 2063 grupos em ${stopwatch.elapsedMilliseconds} ms',
    );
    expect(stopwatch.elapsedMilliseconds, lessThan(250));
  });
}
