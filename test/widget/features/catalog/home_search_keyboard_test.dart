import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_worker.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Louvor _louvor({required String categoria}) => Louvor.fromManifest(
  nome: 'Aleluia',
  numero: '001',
  categoria: categoria,
  classificacao: 'ColAdultos',
  pdf: '001-${categoria.toLowerCase()}.pdf',
  pdfId: 'id-001-$categoria',
  groupId: '001:aleluia',
);

/// Grupo com dois materiais: o toque abre o sheet, sem resolver PDF nenhum —
/// é o caminho mais barato para provar que o Enter faz o mesmo que o dedo.
LouvorGroup _multiMaterialGroup() => LouvorGroup.fromLouvores([
  _louvor(categoria: 'Partitura'),
  _louvor(categoria: 'Cifra'),
]).first;

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<String> ensurePlaylistForLouvor(String pdfId) async => 'fake-playlist';

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) async => true;
}

class _EmptyColdigomRepo implements ColdigomSearchRepository {
  @override
  Future<ColdigomSearchResult> search(String query, {int page = 1}) async {
    return const ColdigomSearchResult(
      groups: [],
      louvores: [],
      page: 1,
      hasNextPage: false,
    );
  }

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    return const ColdigomBrowseResult(
      groups: [],
      louvores: [],
      page: 1,
      limit: 10,
      totalItems: 0,
      totalPages: 0,
    );
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required SharedPreferences prefs,
  List<LouvorGroup> results = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarAvailableProvider.overrideWithValue(true),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
        carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
        playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
        coldigomSearchRepositoryProvider.overrideWithValue(
          _EmptyColdigomRepo(),
        ),
        homeSearchPipelineExecutorProvider.overrideWith(
          (ref) =>
              (input) async => runHomeSearchPipeline(input),
        ),
        // O pipeline de busca tem cobertura própria; aqui interessa só o que
        // o teclado faz com a lista já pronta.
        homeSearchGroupResultsProvider.overrideWithValue(results),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('shouldAutofocusSearch', () {
    test('web abre com o cursor no campo', () {
      expect(
        shouldAutofocusSearch(isWeb: true, platform: TargetPlatform.android),
        isTrue,
      );
    });

    test('desktop abre com o cursor no campo', () {
      for (final platform in const [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(
          shouldAutofocusSearch(isWeb: false, platform: platform),
          isTrue,
          reason: '$platform tem teclado físico',
        );
      }
    });

    test('celular nativo não abre o teclado sozinho', () {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        expect(
          shouldAutofocusSearch(isWeb: false, platform: platform),
          isFalse,
          reason: '$platform abriria o teclado virtual sem pedido',
        );
      }
    });
  });

  testWidgets('Esc limpa o campo de busca', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await _pumpHome(tester, prefs: prefs);

    final field = find.byType(TextField);
    await tester.enterText(field, 'aleluia');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'aleluia');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
  });

  testWidgets('Enter na busca abre o primeiro resultado', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await _pumpHome(tester, prefs: prefs, results: [_multiMaterialGroup()]);

    await tester.enterText(find.byType(TextField), 'aleluia');
    await tester.pumpAndSettle();

    // O sheet de materiais ainda não existe antes do Enter.
    expect(find.text('Cifra'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Cifra'), findsOneWidget);
    expect(find.text('Partitura'), findsOneWidget);
  });

  testWidgets('Enter sem resultados não quebra', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await _pumpHome(tester, prefs: prefs);

    await tester.enterText(find.byType(TextField), 'nada');
    await tester.pumpAndSettle();

    expect(activateFirstHomeSearchResult(), isFalse);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  });
}
