import '../../../helpers/louvores_manifest_test_helpers.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor({required String categoria}) => Louvor.fromManifest(
  nome: 'Aleluia',
  numero: '001',
  categoria: categoria,
  classificacao: 'ColAdultos',
  pdf: '001-${categoria.toLowerCase()}.pdf',
  pdfId: 'id-001-$categoria',
  groupId: '001:aleluia',
);

/// Grupo com dois materiais: se algo abrisse o card, o sheet apareceria com
/// «Cifra»/«Partitura» sem resolver PDF nenhum — prova barata de que o Enter
/// não abre nada.
LouvorGroup _multiMaterialGroup() => LouvorGroup.fromLouvores([
  _louvor(categoria: 'Partitura'),
  _louvor(categoria: 'Cifra'),
]).first;

class _EmptyColdigomRepo implements ColdigomSearchRepository {
  @override
  Future<ColdigomSearchResult> search(
    String query, {
    int page = 1,
    SearchCancellation? cancellation,
  }) async {
    return const ColdigomSearchResult(
      groups: [],
      louvores: [],
      page: 1,
      hasNextPage: false,
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
        catalogIndexStatusProvider.overrideWithValue(CatalogIndexStatus.ready),
        playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        coldigomSearchRepositoryProvider.overrideWithValue(
          _EmptyColdigomRepo(),
        ),
        // O pipeline de busca tem cobertura própria; aqui interessa só o que
        // o teclado faz com a lista já pronta.
        homeSearchStateProvider.overrideWithValue(
          HomeSearchState(
            query: 'aleluia',
            localGroups: results,
            remote: const AsyncData(CatalogSearchPage.empty),
          ),
        ),
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

  testWidgets('Enter na busca não abre resultado nenhum', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await _pumpHome(tester, prefs: prefs, results: [_multiMaterialGroup()]);

    await tester.enterText(find.byType(TextField), 'aleluia');
    await tester.pumpAndSettle();

    // Abrir o primeiro card no Enter parecia produtividade, mas na maioria
    // das vezes o usuário quer outro card da lista — o Enter só confirma a
    // busca, e o sheet de materiais continua fechado.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Cifra'), findsNothing);
    expect(find.text('Partitura'), findsNothing);
  });
}
