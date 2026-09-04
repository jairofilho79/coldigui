import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
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

/// Lista de resultados da Home — isolada da [SearchBar] para evitar rebuilds
/// do campo de busca quando o pipeline assíncrono conclui.
class HomeSearchResultsSliver extends ConsumerWidget {
  const HomeSearchResultsSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(homeSearchGroupResultsProvider);
    final coldigomLoading = ref.watch(homeSearchColdigomLoadingProvider);
    final coldigomError = ref.watch(homeSearchColdigomErrorProvider);
    final page = ref.watch(homeSearchColdigomPageProvider);
    final hasNext = ref.watch(homeSearchColdigomHasNextProvider);
    final coldigomCount = ref
        .watch(homeSearchColdigomGroupsDataProvider)
        .length;

    // Busca coldigom falhando é visível (linha com retry) em vez de lista
    // vazia silenciosa (C.8).
    final showError = !coldigomLoading && coldigomError;
    final showPager =
        !coldigomLoading &&
        !coldigomError &&
        (page > 1 || hasNext || coldigomCount > 0);
    final trailingCount =
        (coldigomLoading ? 1 : 0) + (showError ? 1 : 0) + (showPager ? 1 : 0);

    if (results.isEmpty && trailingCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < results.length) {
          final card = LouvorGroupCard(group: results[index]);
          if (index != 0) return card;
          return KeyedSubtree(key: homeFirstSearchResultKey, child: card);
        }
        var trailingIndex = index - results.length;
        if (coldigomLoading) {
          if (trailingIndex == 0) {
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
          trailingIndex -= 1;
        }
        if (showError && trailingIndex == 0) {
          return _ColdigomUnavailableRow(
            onRetry: () =>
                ref.read(homeSearchPipelineDriverProvider.notifier).retry(),
          );
        }
        if (showPager && trailingIndex == 0) {
          return const HomeColdigomPaginationControls();
        }
        return const SizedBox.shrink();
      }, childCount: results.length + trailingCount),
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
