import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/contributions_providers.dart';
import '../../domain/entities/contribution_summary.dart';

/// Estado de «Minhas contribuições»: a página já carregada + o cursor para a
/// próxima (spec §6.4 — paginação por cursor).
@immutable
class MyContributionsState {
  const MyContributionsState({
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<ContributionSummary> items;
  final String? nextCursor;
  final bool loadingMore;

  MyContributionsState copyWith({
    List<ContributionSummary>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => MyContributionsState(
    items: items ?? this.items,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Observa o auth: trocar de conta (ou sair) recarrega — a lista é da pessoa.
class MyContributionsNotifier extends AsyncNotifier<MyContributionsState> {
  @override
  Future<MyContributionsState> build() async {
    // `await ref.watch(...future)` (não `.select`): é o padrão já usado por
    // `MaterialKindPrefsNotifier.build()` para esperar o primeiro valor real
    // do auth antes de decidir — `.select` sobre um `AsyncNotifierProvider`
    // ainda carregando trava a espera do `.future` do próprio provider.
    final user = await ref.watch(authStateProvider.future);
    final token = user?.sessionToken;
    if (token == null) return const MyContributionsState();
    final page = await ref
        .read(contributionsRemoteDatasourceProvider)
        .fetchMine(sessionToken: token);
    return MyContributionsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    // O erro já vira `AsyncError` no `state` (é para isso que
    // `invalidateSelf` + `build()` servem) — sem o `catch`, o
    // `RefreshIndicator` (que faz `await onRefresh()`) deixaria a exceção
    // subir e cairia na tela vermelha de erro não tratado do Flutter.
    try {
      await future;
    } on Object {
      // Ignorado de propósito: `_buildError` já mostra o estado de erro.
    }
  }

  /// Busca a próxima página e anexa aos itens já carregados — no-op sem
  /// cursor, já carregando ou deslogado.
  ///
  /// Em erro, o `state` volta para o `AsyncData` anterior (`state.value`
  /// continua com os itens já carregados) e a exceção é relançada para quem
  /// chamou decidir o que fazer (ex.: snackbar). Não usamos
  /// `AsyncError(...).copyWithPrevious(...)`: esse método é `@internal` no
  /// riverpod 3 e o `flutter analyze` reclama (`invalid_use_of_internal_member`).
  /// Também evita que uma falha só da *próxima* página vire erro da lista
  /// inteira.
  Future<void> loadMore() async {
    final current = state.value;
    final token = ref.read(authStateProvider).asData?.value?.sessionToken;
    if (current == null ||
        current.nextCursor == null ||
        current.loadingMore ||
        token == null) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(contributionsRemoteDatasourceProvider)
          .fetchMine(sessionToken: token, cursor: current.nextCursor);
      state = AsyncData(
        MyContributionsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncData(current.copyWith(loadingMore: false));
      Error.throwWithStackTrace(e, st);
    }
  }
}

final myContributionsProvider =
    AsyncNotifierProvider<MyContributionsNotifier, MyContributionsState>(
      MyContributionsNotifier.new,
    );

/// Busca uma contribuição específica para o detalhe — sem reaproveitar o item
/// da lista: mantém simples (spec §6.4 só pede o fetch).
final contributionDetailProvider = FutureProvider.autoDispose
    .family<ContributionSummary, String>((ref, id) async {
      final user = await ref.watch(authStateProvider.future);
      final token = user?.sessionToken;
      if (token == null) throw StateError('unauthorized');
      return ref
          .read(contributionsRemoteDatasourceProvider)
          .fetchOne(sessionToken: token, id: id);
    });
