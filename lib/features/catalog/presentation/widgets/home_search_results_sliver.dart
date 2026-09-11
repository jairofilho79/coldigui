import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_coldigom_pagination_controls.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Marca o primeiro resultado para o `Enter` da busca (C1).
final GlobalKey homeFirstSearchResultKey = GlobalKey(
  debugLabel: 'homeFirstSearchResult',
);

/// Abre o primeiro resultado da busca como se o usuário tivesse tocado no card.
///
/// Em vez de repetir aqui as regras de abertura (material único vai direto,
/// vários abrem o sheet, áudio abre o player, Coldigom tem sheet próprio), este
/// atalho pega o **mesmo** callback que o toque usa — o `onTap` do
/// [CarouselLouvorChip] montado pelo primeiro [LouvorGroupCard]. Assim a tecla
/// e o dedo não podem divergir.
///
/// Retorna `false` quando não há resultado montado (lista vazia ou rolada para
/// fora da viewport) ou quando o card está com o toque desabilitado (download
/// em andamento).
bool activateFirstHomeSearchResult() {
  final element = homeFirstSearchResultKey.currentContext as Element?;
  if (element == null) return false;

  final onTap = _firstChipOnTap(element);
  if (onTap == null) return false;

  onTap();
  return true;
}

VoidCallback? _firstChipOnTap(Element root) {
  VoidCallback? found;
  void visit(Element element) {
    if (found != null) return;
    final widget = element.widget;
    if (widget is CarouselLouvorChip) {
      found = widget.onTap;
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return found;
}

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

    if (results.isEmpty && trailing == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < results.length) {
          final card = LouvorGroupCard(group: results[index]);
          if (index != 0) return card;
          return KeyedSubtree(key: homeFirstSearchResultKey, child: card);
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
