import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_coldigom_pagination_controls.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_empty_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O que vai **depois** dos cards, se algo for.
///
/// Os três estados são mutuamente exclusivos, e é justamente isso que a
/// aritmética antiga de índices (`trailingIndex -= 1`, três flags booleanas)
/// escondia: ou a página remota está em voo, ou falhou, ou chegou. Um `switch`
/// exaustivo sobre este enum não deixa um quarto caso passar despercebido.
enum HomeSearchTrailingSlot {
  /// Página remota em voo.
  loading,

  /// Página remota falhou — linha "Coldigom indisponível · tentar de novo".
  error,

  /// Página remota chegou e há o que paginar.
  pager,
}

/// Slot final correspondente a [state] — vazio quando não há nenhum.
HomeSearchTrailingSlot? homeSearchTrailingSlot(HomeSearchState state) {
  if (state.remoteLoading) return HomeSearchTrailingSlot.loading;
  // Busca coldigom falhando é visível (linha com retry) em vez de lista
  // vazia silenciosa (C.8).
  if (state.remoteFailed) return HomeSearchTrailingSlot.error;
  if (state.page > 1 || state.hasNextPage || state.remoteGroups.isNotEmpty) {
    return HomeSearchTrailingSlot.pager;
  }
  return null;
}

/// Lista de resultados da Home — isolada da [SearchBar] para evitar rebuilds
/// do campo de busca quando a página remota conclui.
class HomeSearchResultsSliver extends ConsumerWidget {
  const HomeSearchResultsSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeSearchStateProvider);
    final results = state.groups;
    final trailing = homeSearchTrailingSlot(state);

    // Sem grupo nenhum (local nem remoto) e nada em voo/paginável: o antigo
    // `SizedBox.shrink()` vira o estado vazio da Home (C4). A linha de erro
    // remoto continua — ela é o mecanismo genérico de retry (C.8), o estado
    // vazio é só o texto amigável por cima.
    if (results.isEmpty &&
        trailing != HomeSearchTrailingSlot.loading &&
        trailing != HomeSearchTrailingSlot.pager) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            HomeEmptyState(state: state),
            if (trailing == HomeSearchTrailingSlot.error)
              _ColdigomUnavailableRow(onRetry: () => retryRemoteSearch(ref)),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < results.length) {
          return LouvorGroupCard(group: results[index]);
        }
        switch (trailing!) {
          case HomeSearchTrailingSlot.loading:
            return const _ColdigomLoadingRow();
          case HomeSearchTrailingSlot.error:
            return _ColdigomUnavailableRow(
              onRetry: () => retryRemoteSearch(ref),
            );
          case HomeSearchTrailingSlot.pager:
            return const HomeColdigomPaginationControls();
        }
      }, childCount: results.length + (trailing == null ? 0 : 1)),
    );
  }
}

/// Spinner enquanto a página remota está em voo.
class _ColdigomLoadingRow extends StatelessWidget {
  const _ColdigomLoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }
}

/// Linha "Coldigom indisponível · tentar de novo" — toque re-dispara a
/// busca coldigom da query atual (C.8).
class _ColdigomUnavailableRow extends StatelessWidget {
  const _ColdigomUnavailableRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text(l10n.coldigomUnavailableRetry),
        ),
      ),
    );
  }
}
