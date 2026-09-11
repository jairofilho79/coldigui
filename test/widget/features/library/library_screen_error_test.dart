import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/library/domain/entities/library_catalog_mode.dart';
import 'package:coldigui/features/library/domain/entities/paginated_louvor_groups.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/features/library/presentation/providers/coldigom_library_filters_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_catalog_mode_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_coldigom_browse_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_worker.dart';
import 'package:coldigui/features/library/presentation/providers/library_last_good_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

/// Fixa o modo (PLPCG/Coldigom) sem hidratar por URL — evita depender do
/// [WidgetsBinding.addPostFrameCallback] de [LibraryScreen._hydrateFromUrl].
class _FixedLibraryCatalogModeNotifier extends LibraryCatalogModeNotifier {
  _FixedLibraryCatalogModeNotifier(this._mode);

  final LibraryCatalogMode _mode;

  @override
  LibraryCatalogMode build() => _mode;

  // `LibraryScreen._hydrateFromUrl` chama isto com `fonte: null` no
  // primeiro frame — sem o no-op, ele reverte para `plpcg` (default de
  // `LibraryCatalogMode.fromUrl`) e desfaz o override.
  @override
  void hydrateFromUrl({String? fonte}) {}
}

/// Sempre falha — `StateError` evita o auto-retry padrão do Riverpod 3
/// (mesmo cuidado do `_ErrorLouvoresManifestNotifier`, ver
/// `louvores_manifest_test_helpers.dart`).
class _ErrorLibraryColdigomBrowseNotifier
    extends LibraryColdigomBrowseNotifier {
  _ErrorLibraryColdigomBrowseNotifier(this._onBuild);

  final void Function()? _onBuild;

  @override
  Future<PaginatedLouvorGroups> build() async {
    _onBuild?.call();
    throw StateError('coldigom indisponível (teste)');
  }
}

/// Página 1 de duas, com um grupo Coldigom — a "última página boa".
PaginatedLouvorGroups _goodFirstPage(int itemsPerPage) => PaginatedLouvorGroups(
  items: LouvorGroup.fromLouvores([
    Louvor.fromManifest(
      nome: 'Comigo habita',
      numero: '002',
      categoria: 'Partitura',
      classificacao: 'Country',
      pdf: 'm1.pdf',
      pdfId: encodePdfId('assets/praises/p1/m1.pdf'),
      groupId: 'p1',
      source: LouvorDataSource.coldigom,
    ),
  ]),
  page: 1,
  itemsPerPage: itemsPerPage,
  totalItems: 20,
  totalPages: 2,
);

/// Sem filtro de tom a página 1 vem boa; com filtro, a busca falha.
///
/// Serve para o caso "mudou a consulta e a primeira busca da consulta nova
/// falhou": a última página boa é da consulta **anterior** e não pode ser
/// servida como se descrevesse a nova.
class _FilterAwareBrowseNotifier extends LibraryColdigomBrowseNotifier {
  @override
  Future<PaginatedLouvorGroups> build() async {
    final filters = ref.watch(coldigomLibraryFiltersProvider);
    final view = ref.watch(libraryViewSettingsProvider);
    if (filters.selectedTonalities.isNotEmpty) {
      throw StateError('coldigom indisponível para o filtro novo (teste)');
    }
    return _goodFirstPage(view.itemsPerPage);
  }
}

/// Última página boa fixa, sem escutar o browse — isola o `?? lastGood`.
class _FixedLastGoodNotifier extends LibraryLastGoodResultsNotifier {
  @override
  PaginatedLouvorGroups build() => _goodFirstPage(10);
}

/// Página 1 boa, página ≥ 2 em erro — o caso do paginador que sumia (D.6).
class _SecondPageFailsBrowseNotifier extends LibraryColdigomBrowseNotifier {
  @override
  Future<PaginatedLouvorGroups> build() async {
    final view = ref.watch(libraryViewSettingsProvider);
    if (view.page >= 2) {
      throw StateError('coldigom indisponível na página 2 (teste)');
    }
    return _goodFirstPage(view.itemsPerPage);
  }
}

Widget _libraryErrorTestApp({
  required SharedPreferences prefs,
  required List<Override> extraOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      libraryGroupPipelineExecutorProvider.overrideWith(
        (ref) =>
            (input) async => runLibraryGroupPipeline(input),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(body: LibraryScreen()),
    ),
  );
}

/// `pumpAndSettle` trava com o shimmer do skeleton (animação em loop).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'LibraryScreen (PLPCG) em erro mostra "Tentar novamente" que invalida o manifest',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;

      await tester.pumpWidget(
        _libraryErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            louvoresManifestErrorOverride(onBuild: () => buildCount++),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);
      expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Tentar novamente'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
      await _settle(tester);

      expect(buildCount, 2);
    },
  );

  testWidgets(
    'LibraryScreen (Coldigom) em erro mostra "Tentar novamente" que invalida o browse',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;

      await tester.pumpWidget(
        _libraryErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            libraryCatalogModeProvider.overrideWith(
              () =>
                  _FixedLibraryCatalogModeNotifier(LibraryCatalogMode.coldigom),
            ),
            libraryColdigomBrowseProvider.overrideWith(
              () => _ErrorLibraryColdigomBrowseNotifier(() => buildCount++),
            ),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);
      expect(
        find.text('Não foi possível carregar o catálogo Coldigom'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Tentar novamente'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
      await _settle(tester);

      expect(buildCount, 2);
    },
  );

  testWidgets(
    'LibraryScreen (Coldigom) com erro na página 2 mantém o paginador da página 1',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _libraryErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            libraryCatalogModeProvider.overrideWith(
              () =>
                  _FixedLibraryCatalogModeNotifier(LibraryCatalogMode.coldigom),
            ),
            libraryColdigomBrowseProvider.overrideWith(
              _SecondPageFailsBrowseNotifier.new,
            ),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      // Página 1 boa: paginador completo, sem banner de erro.
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(
        find.text('Não foi possível carregar o catálogo Coldigom'),
        findsNothing,
      );

      // Avança para a página 2, que falha.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LibraryScreen)),
      );
      container.read(libraryViewSettingsProvider.notifier).goToNextPage(2);
      await _settle(tester);

      // Banner de erro aparece...
      expect(
        find.text('Não foi possível carregar o catálogo Coldigom'),
        findsOneWidget,
      );
      // ...e o paginador continua de pé com a última página boa.
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
    },
  );

  // Contrato do `libraryLastGoodResultsProvider`: o valor que o paginador usa
  // quando o browse não tem nenhum. O Riverpod 3 costuma carregar o valor
  // anterior junto do `AsyncError`, mas isso é detalhe dele — a última página
  // boa passa a ser guardada explicitamente.
  test(
    'libraryLastGoodResultsProvider guarda a última página boa mesmo com o browse em erro',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryCatalogModeProvider.overrideWith(
            () => _FixedLibraryCatalogModeNotifier(LibraryCatalogMode.coldigom),
          ),
          libraryColdigomBrowseProvider.overrideWith(
            _SecondPageFailsBrowseNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(libraryLastGoodResultsProvider, (_, _) {});

      await container.read(libraryColdigomBrowseProvider.future);
      expect(container.read(libraryLastGoodResultsProvider).totalItems, 20);

      container.read(libraryViewSettingsProvider.notifier).goToNextPage(2);
      await expectLater(
        container.read(libraryColdigomBrowseProvider.future),
        throwsStateError,
      );

      final lastGood = container.read(libraryLastGoodResultsProvider);
      expect(lastGood.page, 1);
      expect(lastGood.totalItems, 20);
      expect(lastGood.totalPages, 2);
      expect(container.read(libraryGroupResultsProvider).totalItems, 20);
    },
  );

  // A fiação `?? lastGood` isolada: browse sem valor nenhum (o `build` falha na
  // primeira vez, então o `AsyncError` não tem valor anterior para carregar) e
  // uma última página boa posta à mão.
  test(
    'libraryGroupResultsProvider cai na última página boa quando o browse não tem valor',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryCatalogModeProvider.overrideWith(
            () => _FixedLibraryCatalogModeNotifier(LibraryCatalogMode.coldigom),
          ),
          libraryColdigomBrowseProvider.overrideWith(
            () => _ErrorLibraryColdigomBrowseNotifier(null),
          ),
          libraryLastGoodResultsProvider.overrideWith(
            _FixedLastGoodNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(libraryColdigomBrowseProvider.future),
        throwsStateError,
      );
      final browse = container.read(libraryColdigomBrowseProvider);
      expect(browse.hasError, isTrue);
      expect(browse.value, isNull);

      final results = container.read(libraryGroupResultsProvider);
      expect(results.totalItems, 20);
      expect(results.totalPages, 2);
    },
  );

  // Mudou a consulta (filtro), a primeira busca dela falhou: a página boa do
  // filtro anterior descrevia outro conjunto e não pode reaparecer como se
  // fosse deste.
  test(
    'libraryLastGoodResultsProvider esquece a página boa quando o filtro muda',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryCatalogModeProvider.overrideWith(
            () => _FixedLibraryCatalogModeNotifier(LibraryCatalogMode.coldigom),
          ),
          libraryColdigomBrowseProvider.overrideWith(
            _FilterAwareBrowseNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(libraryLastGoodResultsProvider, (_, _) {});

      await container.read(libraryColdigomBrowseProvider.future);
      expect(container.read(libraryGroupResultsProvider).totalItems, 20);

      container
          .read(coldigomLibraryFiltersProvider.notifier)
          .toggleTonality('G');
      await expectLater(
        container.read(libraryColdigomBrowseProvider.future),
        throwsStateError,
      );

      final browse = container.read(libraryColdigomBrowseProvider);
      expect(browse.hasError, isTrue);
      // A armadilha: o `AsyncError` ainda carrega a página do filtro anterior.
      expect(browse.value, isNotNull);
      expect(container.read(libraryLastGoodResultsProvider).totalItems, 0);
      expect(container.read(libraryGroupResultsProvider).totalItems, 0);
    },
  );

  // Mesma regra para ordenação e tamanho de página: mudam o conjunto/os totais.
  test(
    'libraryLastGoodResultsProvider esquece a página boa quando a ordenação muda',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryCatalogModeProvider.overrideWith(
            () => _FixedLibraryCatalogModeNotifier(LibraryCatalogMode.coldigom),
          ),
          libraryColdigomBrowseProvider.overrideWith(
            _SecondPageFailsBrowseNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(libraryLastGoodResultsProvider, (_, _) {});

      await container.read(libraryColdigomBrowseProvider.future);
      expect(container.read(libraryLastGoodResultsProvider).totalItems, 20);

      container.read(libraryViewSettingsProvider.notifier).setSortBy('nome');

      expect(container.read(libraryLastGoodResultsProvider).totalItems, 0);
    },
  );

  testWidgets(
    'LibraryScreen recarrega automaticamente quando a conectividade volta',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      await tester.pumpWidget(
        _libraryErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            louvoresManifestErrorOverride(onBuild: () => buildCount++),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivityController.stream,
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);

      connectivityController.add(true);
      await _settle(tester);

      expect(buildCount, 2);
    },
  );
}
