import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/pages/favorite_material_kinds_screen.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/coldigom_material_kinds_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_types_for_kind_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/widgets/material_kind_card.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'tok');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

/// Sync inerte: a tela só precisa que `sync()` exista.
class _NoopSync extends MaterialKindPrefsSyncNotifier {
  @override
  MaterialKindPrefsSyncState build() => const MaterialKindPrefsSyncState();

  @override
  Future<MaterialKindPrefsSyncResult> sync() async =>
      MaterialKindPrefsSyncResult.skippedAuth;
}

/// Logado, com um «refresh» de token sob demanda: `materialKindPrefsProvider`
/// observa o auth, então a emissão nova o recarrega (reload) — no Riverpod 3
/// isso vira `AsyncLoading` com o valor anterior, e `asData` fica `null`.
class _RefreshingAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'tok');

  void refreshToken() {
    state = const AsyncData(AuthUser(googleSub: 'sub-1', idToken: 'tok-2'));
  }
}

const _kinds = [
  ColdigomMaterialKindDto(id: 'k-partitura', name: 'Partitura'),
  ColdigomMaterialKindDto(id: 'k-soprano', name: 'Voz soprano'),
  ColdigomMaterialKindDto(id: 'k-tenor', name: 'Voz tenor'),
  ColdigomMaterialKindDto(id: 'k-baixo', name: 'Voz baixo'),
  ColdigomMaterialKindDto(id: 'k-coro', name: 'Coro'),
  ColdigomMaterialKindDto(id: 'k-trompete', name: 'Trompete'),
  ColdigomMaterialKindDto(id: 'k-violao', name: 'Violão'),
];

Future<List<ColdigomMaterialKindDto>> _defaultKinds() async => _kinds;

/// Default: nenhum kind tem mais de um material type — o controle de
/// preferência de type fica invisível a menos que um teste passe `types`.
Future<List<String>> _noMaterialTypes(String kindId) async => const [];

void main() {
  late AppLocalizations pt;
  late SharedPreferences prefs;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // `kinds` é parâmetro à parte (não em `extra`): o Riverpod 3.3 lança
  // assertion ao ver o mesmo provider (`coldigomMaterialKindsProvider`)
  // presente duas vezes na lista de overrides do container.
  Future<void> pump(
    WidgetTester tester, {
    AuthNotifier Function() auth = _LoggedIn.new,
    Future<List<ColdigomMaterialKindDto>> Function() kinds = _defaultKinds,
    Future<List<String>> Function(String kindId) types = _noMaterialTypes,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const FavoriteMaterialKindsScreen(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(auth),
        materialKindPrefsSyncProvider.overrideWith(_NoopSync.new),
        coldigomMaterialKindsProvider.overrideWith((ref) => kinds()),
        materialTypesForKindProvider.overrideWith(
          (ref, kindId) => types(kindId),
        ),
        ...extra,
      ],
    );
    await tester.pumpAndSettle();
  }

  /// O `IconButton` de `+` na linha do kind [name]. `find.byTooltip` acharia
  /// o `Tooltip` interno, não o botão — por isso o predicado.
  Finder addButtonFor(String name) => find.descendant(
    of: find.ancestor(
      of: find.text(name),
      matching: find.byType(MaterialKindCard),
    ),
    matching: find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == pt.favoriteMaterialKindsAddTooltip,
    ),
  );

  Finder removeButtons() => find.byWidgetPredicate(
    (w) =>
        w is IconButton && w.tooltip == pt.favoriteMaterialKindsRemoveTooltip,
  );

  testWidgets('deslogado mostra aviso e botão de login, sem lista', (
    tester,
  ) async {
    await pump(tester, auth: _LoggedOut.new);
    expect(find.text(pt.favoriteMaterialKindsSignInPrompt), findsOneWidget);
    expect(find.text('Partitura'), findsNothing);
  });

  testWidgets('adiciona até 5; o 6º + fica desabilitado e o limite aparece', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(pt.favoriteMaterialKindsEmpty), findsOneWidget);

    for (final name in [
      'Partitura',
      'Voz soprano',
      'Voz tenor',
      'Voz baixo',
      'Coro',
    ]) {
      await tester.tap(addButtonFor(name));
      await tester.pumpAndSettle();
    }

    expect(find.text(pt.favoriteMaterialKindsYours(5, 5)), findsOneWidget);
    expect(find.text(pt.favoriteMaterialKindsLimitReached(5)), findsOneWidget);
    final sixth = tester.widget<IconButton>(addButtonFor('Trompete'));
    expect(sixth.onPressed, isNull);

    final stored = MaterialKindPrefsLocalDatasource(prefs).read('sub-1');
    expect(stored!.kindIds, [
      'k-partitura',
      'k-soprano',
      'k-tenor',
      'k-baixo',
      'k-coro',
    ]);
    expect(stored.pendingPush, isTrue);
  });

  testWidgets('a lista não some por um frame quando o provider recarrega', (
    tester,
  ) async {
    await pump(tester, auth: _RefreshingAuth.new);
    await tester.tap(addButtonFor('Coro'));
    await tester.pumpAndSettle();
    expect(find.text(pt.favoriteMaterialKindsYours(1, 5)), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FavoriteMaterialKindsScreen)),
    );
    (container.read(authStateProvider.notifier) as _RefreshingAuth)
        .refreshToken();
    // Frame a frame (não `pumpAndSettle`): a regressão era visível num só —
    // a lista colapsava para «Nenhum favorito ainda / 0 de 5» até o reload
    // terminar.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      expect(find.text(pt.favoriteMaterialKindsEmpty), findsNothing);
      expect(find.text(pt.favoriteMaterialKindsYours(0, 5)), findsNothing);
      expect(find.text(pt.favoriteMaterialKindsYours(1, 5)), findsOneWidget);
    }
    await tester.pumpAndSettle();
    expect(removeButtons(), findsOneWidget);
  });

  testWidgets('remover pelo × tira da lista e salva', (tester) async {
    await pump(tester);
    await tester.tap(addButtonFor('Coro'));
    await tester.pumpAndSettle();
    await tester.tap(removeButtons());
    await tester.pumpAndSettle();

    expect(find.text(pt.favoriteMaterialKindsEmpty), findsOneWidget);
    expect(
      MaterialKindPrefsLocalDatasource(prefs).read('sub-1')!.kindIds,
      isEmpty,
    );
  });

  testWidgets('arrastar reordena e salva a ordem nova', (tester) async {
    await pump(tester);
    await tester.tap(addButtonFor('Partitura'));
    await tester.pumpAndSettle();
    await tester.tap(addButtonFor('Coro'));
    await tester.pumpAndSettle();

    // Handle do segundo item (Coro) arrastado até a posição do primeiro —
    // pela distância real entre as alças, não por um delta fixo: o
    // `SliverReorderableList` só troca quando o começo do proxy cai na
    // metade de cima do item alvo (ou passa dele inteiro).
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    final from = tester.getCenter(handles.at(1));
    final to = tester.getCenter(handles.at(0));
    final drag = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveBy(to - from);
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(MaterialKindPrefsLocalDatasource(prefs).read('sub-1')!.kindIds, [
      'k-coro',
      'k-partitura',
    ]);
  });

  testWidgets('busca filtra sem acento e some do restante o que já é favorito', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(addButtonFor('Violão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'violao');
    await tester.pumpAndSettle();
    // "Violão" já é favorito: aparece só na lista de cima, não na de adicionar.
    expect(addButtonFor('Violão'), findsNothing);
    expect(find.text(pt.favoriteMaterialKindsNoMatch), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'voz');
    await tester.pumpAndSettle();
    expect(addButtonFor('Voz soprano'), findsOneWidget);
    expect(addButtonFor('Partitura'), findsNothing);
  });

  testWidgets(
    'kind com mais de um material type mostra o menu e salva a troca',
    (tester) async {
      await pump(
        tester,
        types: (kindId) async =>
            kindId == 'k-partitura' ? const ['pdf', 'chord'] : const [],
      );
      await tester.tap(addButtonFor('Partitura'));
      await tester.pumpAndSettle();

      final typeButton = find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.tooltip == pt.favoriteMaterialKindsTypePreferenceTooltip,
      );
      expect(typeButton, findsOneWidget);

      await tester.tap(typeButton);
      await tester.pumpAndSettle();
      expect(
        find.text(pt.favoriteMaterialKindsTypePreferenceTitle('Partitura')),
        findsOneWidget,
      );

      // O menu usa `ReorderableListView` (a lista de favoritos por trás usa
      // `SliverReorderableList`) — escopo evita contar a alça da linha por
      // baixo do modal.
      final handles = find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byIcon(Icons.drag_handle),
      );
      expect(handles, findsNWidgets(2));
      final from = tester.getCenter(handles.at(1));
      final to = tester.getCenter(handles.at(0));
      final drag = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveBy(to - from);
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      // Fecha o modal para inspecionar o estado salvo por baixo dele.
      await tester.tapAt(const Offset(400, 50));
      await tester.pumpAndSettle();

      final stored = MaterialKindPrefsLocalDatasource(prefs).read('sub-1');
      expect(stored!.preferredTypeByKind, {'k-partitura': 'chord'});
    },
  );

  testWidgets(
    'erro ao carregar kinds mostra retry, favoritos salvos ficam pelo id',
    (tester) async {
      await prefs.setString(
        MaterialKindPrefsLocalDatasource.keyFor('sub-1'),
        '{"kindIds":["k-x"],"updatedAt":"2026-09-01T00:00:00.000Z","pendingPush":false}',
      );
      await pump(tester, kinds: () async => throw StateError('rede'));
      expect(find.text(pt.favoriteMaterialKindsLoadError), findsOneWidget);
      expect(find.text(pt.favoriteMaterialKindsRetry), findsOneWidget);
      expect(find.text(pt.favoriteMaterialKindsUnknownKind), findsOneWidget);
    },
  );
}
