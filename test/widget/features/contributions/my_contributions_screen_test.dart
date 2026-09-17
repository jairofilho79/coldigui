import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribution_detail_screen.dart';
import 'package:coldigui/features/contributions/presentation/pages/my_contributions_screen.dart';
import 'package:coldigui/features/contributions/presentation/providers/my_contributions_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/pump_app.dart';

ContributionSummary _summary(
  String id, {
  required ContributionStatus status,
  String? decisionNote,
  List<ContributionFileSummary> files = const [],
}) => ContributionSummary(
  id: id,
  kind: ContributionKind.other,
  subkind: null,
  title: 'Contribuição $id',
  body: 'Corpo da contribuição $id',
  status: status,
  decisionNote: decisionNote,
  createdAt: DateTime.utc(2026, 9, 10),
  updatedAt: DateTime.utc(2026, 9, 10),
  links: const [],
  files: files,
  fields: const {},
);

/// Notifier de mentira: devolve os itens fixos passados no construtor sem
/// tocar em rede — mesmo papel do `_FakePraiseMetaNotifier` da Task 4.
class _FixedNotifier extends MyContributionsNotifier {
  _FixedNotifier(this._items);
  final List<ContributionSummary> _items;

  @override
  Future<MyContributionsState> build() async =>
      MyContributionsState(items: _items);
}

/// Registra quantas vezes `loadMore()` foi chamado — usado para provar que a
/// tela dispara a paginação ao *construir* o último item, não só ao rolar
/// (round 1: listas curtas o bastante para caber no viewport nunca emitem
/// notificação de scroll).
class _PagingRecordingNotifier extends MyContributionsNotifier {
  int loadMoreCalls = 0;

  @override
  Future<MyContributionsState> build() async => MyContributionsState(
    items: [
      _summary('p1', status: ContributionStatus.pendente),
      _summary('p2', status: ContributionStatus.pendente),
    ],
    nextCursor: 'c2',
  );

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
    final current = state.value;
    if (current == null || current.nextCursor == null) return;
    state = AsyncData(
      MyContributionsState(
        items: [
          ...current.items,
          _summary('p3', status: ContributionStatus.pendente),
        ],
        nextCursor: null,
      ),
    );
  }
}

/// `loadMore()` sempre falha, mas mantém a lista já carregada — espelha o
/// `catch` de `MyContributionsNotifier.loadMore()` real (`loadingMore` volta
/// a `false`, `nextCursor` continua o mesmo). Usado para provar que o
/// gatilho de construção do último item não vira uma tempestade de pedidos.
class _FailingPagingNotifier extends MyContributionsNotifier {
  int loadMoreCalls = 0;

  @override
  Future<MyContributionsState> build() async => MyContributionsState(
    items: [
      _summary('p1', status: ContributionStatus.pendente),
      _summary('p2', status: ContributionStatus.pendente),
    ],
    nextCursor: 'c2',
  );

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(loadingMore: false));
    throw Exception('falha de rede');
  }
}

List<Override> _loggedOverrides(List<ContributionSummary> items) => [
  authStateProvider.overrideWith(
    () => FakeAuthNotifier(
      const AuthUser(googleSub: 'u', sessionToken: 'sess_t'),
    ),
  ),
  myContributionsProvider.overrideWith(() => _FixedNotifier(items)),
];

void main() {
  testWidgets('mostra o texto de cada um dos quatro estados (spec §6.4)', (
    tester,
  ) async {
    final items = [
      _summary('p1', status: ContributionStatus.pendente),
      _summary('p2', status: ContributionStatus.emAnalise),
      _summary('p3', status: ContributionStatus.aceita, decisionNote: 'ok'),
      _summary('p4', status: ContributionStatus.bloqueada),
    ];

    await pumpApp(
      tester,
      const MyContributionsScreen(),
      overrides: _loggedOverrides(items),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aguardando análise'), findsOneWidget);
    expect(find.text('Em análise'), findsOneWidget);
    expect(find.text('Aceita'), findsOneWidget);
    expect(
      find.text(
        'Não pôde ser analisada: anexo recusado pela verificação de segurança',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lista vazia mostra o texto de «nenhuma contribuição»', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const MyContributionsScreen(),
      overrides: _loggedOverrides(const []),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Você ainda não enviou nenhuma contribuição.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tocar num item navega para o detalhe com nota da equipe e anexos',
    (tester) async {
      final item = _summary(
        'p3',
        status: ContributionStatus.aceita,
        decisionNote: 'ok',
        files: const [
          ContributionFileSummary(
            id: 'f1',
            originalName: 'foto.jpg',
            size: 1024,
            scanStatus: 'limpa',
          ),
          ContributionFileSummary(
            id: 'f2',
            originalName: 'video.mp4',
            size: 2048,
            scanStatus: 'pendente',
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: RoutePaths.myContributions,
        routes: [
          GoRoute(
            path: RoutePaths.myContributions,
            builder: (_, _) => const Scaffold(body: MyContributionsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => Scaffold(
                  body: ContributionDetailScreen(
                    id: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._loggedOverrides([item]),
            contributionDetailProvider(item.id)
                .overrideWith((ref) async => item),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contribuição p3'));
      await tester.pumpAndSettle();

      expect(find.byType(ContributionDetailScreen), findsOneWidget);
      expect(find.text('Nota da equipe'), findsOneWidget);
      expect(find.text('ok'), findsOneWidget);
      expect(find.textContaining('foto.jpg'), findsOneWidget);
      expect(find.textContaining('ok'), findsWidgets);
      expect(find.textContaining('verificando'), findsOneWidget);
    },
  );

  testWidgets(
    'lista curta cabe no viewport e ainda assim pagina ao construir o '
    'último item, sem precisar rolar',
    (tester) async {
      final notifier = _PagingRecordingNotifier();

      await pumpApp(
        tester,
        const MyContributionsScreen(),
        overrides: [
          authStateProvider.overrideWith(
            () => FakeAuthNotifier(
              const AuthUser(googleSub: 'u', sessionToken: 'sess_t'),
            ),
          ),
          myContributionsProvider.overrideWith(() => notifier),
        ],
      );
      await tester.pumpAndSettle();

      expect(notifier.loadMoreCalls, 1);
      expect(find.text('Contribuição p1'), findsOneWidget);
      expect(find.text('Contribuição p2'), findsOneWidget);
      expect(find.text('Contribuição p3'), findsOneWidget);

      // `nextCursor` virou `null`: reconstruir o (novo) último item não
      // chama `loadMore()` de novo.
      await tester.pumpAndSettle();
      expect(notifier.loadMoreCalls, 1);
    },
  );

  testWidgets(
    'falha ao paginar não vira tempestade de tentativas ao reconstruir o '
    'último item',
    (tester) async {
      final notifier = _FailingPagingNotifier();

      await pumpApp(
        tester,
        const MyContributionsScreen(),
        overrides: [
          authStateProvider.overrideWith(
            () => FakeAuthNotifier(
              const AuthUser(googleSub: 'u', sessionToken: 'sess_t'),
            ),
          ),
          myContributionsProvider.overrideWith(() => notifier),
        ],
      );
      await tester.pumpAndSettle();

      // Sem o cursor já pedido (`_requestedCursor`), cada rebuild do último
      // item (o `loadingMore: false` da falha causa um) dispararia
      // `loadMore()` de novo — um pedido por frame, para sempre.
      expect(notifier.loadMoreCalls, 1);
      expect(find.text('Contribuição p1'), findsOneWidget);
      expect(find.text('Contribuição p2'), findsOneWidget);
    },
  );
}
