import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/ports/search_cancellation.dart';
import 'known_praise_ids_provider.dart';

/// Quanto tempo uma página remota bem-sucedida fica em memo.
///
/// É o LRU que não precisamos escrever: o `keepAlive` segura a instância da
/// família e o timer a solta. Voltar a uma query já vista dentro da janela
/// não gasta requisição nenhuma.
const homeRemoteSearchMemoDuration = Duration(minutes: 10);

/// Identidade de uma busca remota: **só** texto e página.
///
/// Os filtros do catálogo ficam de fora de propósito: são aplicados no
/// cliente (`matchesCatalogFilters`), inclusive aos «novos». É por isso que
/// mexer num chip não re-busca nada na rede.
final class HomeRemoteSearchKey {
  const HomeRemoteSearchKey({required this.query, required this.page});

  /// Query já debounced.
  final String query;

  /// Página 1-based.
  final int page;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeRemoteSearchKey &&
          other.query == query &&
          other.page == page;

  @override
  int get hashCode => Object.hash(query, page);

  @override
  String toString() => 'HomeRemoteSearchKey($query, página $page)';
}

/// Página 1 da busca remota — **validação** da lista local (O15), cancelável
/// e memoizada por `(query, página)`; a página é sempre 1 desde a pesquisa
/// híbrida, a chave mantém o campo por compatibilidade.
///
/// Cada instância cria a própria [SearchCancellation] e a cancela no
/// `onDispose`: quando a query muda, o Riverpod descarta a instância antiga e
/// a requisição em voo morre junto — é o que impede uma resposta atrasada de
/// sobrescrever a lista da tecla seguinte (o antigo contador `_generation`).
///
/// O retry automático do Riverpod 3 fica desligado (`retry: (_, _) => null`):
/// a falha remota é um estado de UI com retry **manual** (o estado `failed`
/// de `SearchFreshnessLine`, com o botão "tentar de novo"), não uma falha
/// transitória a esconder atrás de ~30 s de backoff.
final homeRemoteSearchProvider = FutureProvider.autoDispose
    .family<CatalogSearchPage, HomeRemoteSearchKey>((ref, key) async {
      // Query vazia não tem página remota — e não pode custar uma requisição.
      if (key.query.trim().isEmpty) return CatalogSearchPage.empty;

      final cancellation = SearchCancellation();
      ref.onDispose(cancellation.cancel);

      // `read`, não `watch`: o repositório Coldigom grava os caches ao
      // responder, o que recompõe a fonte do catálogo. Observar a fonte
      // aqui faria a resposta re-disparar a própria busca, em laço.
      final source = ref.read(coldigomCatalogSourceProvider);

      final CatalogSearchPage page;
      try {
        page = await source.search(
          CatalogQuery(text: key.query, page: key.page),
          cancellation: cancellation,
        );
      } on SearchCancelledException {
        // Só chega aqui por causa do `onDispose` acima: o provider já foi
        // descartado e o Riverpod joga fora este resultado. Cancelamento não é
        // falha, então nunca vira `AsyncError` visível.
        return CatalogSearchPage.empty;
      }

      // Provider descartado durante o await (navegação, tecla nova): sem
      // `keepAlive` — memoizar o que ninguém pediu mais só ocuparia memória.
      if (!ref.mounted) return page;

      // §6.2: o que o índice local não conhece vai para o Isar já, e o
      // ETag mudou — o dump inteiro vem a seguir pelo sync. Lê os providers
      // **antes** de qualquer await: este provider é autoDispose e um `ref`
      // descartado não pode ser lido.
      final adopt = ref.read(adoptColdigomSearchNoveltiesProvider);
      // Praises que o catálogo local já conhece (`catalogIds`).
      final known = ref.read(knownPraiseIdsProvider);
      final syncNotifier = ref.read(coldigomCatalogSyncProvider.notifier);
      // Filtra pelo índice já aqui: poupa ao use case (e ao Isar, dentro
      // dele) o trabalho de revisitar praises que a Home já sabia de cor —
      // ele ainda confere Isar por conta própria para o resto.
      final candidates = [
        for (final g in page.groups)
          if (!known.contains(g.groupId)) g,
      ];
      // Sem candidatos não há o que adotar — poupa ao use case uma chamada
      // à toa a cada página remota que só confirma o que já sabíamos.
      if (candidates.isNotEmpty) {
        unawaited(
          adopt(candidates, knownPraiseIds: known).then((adopted) {
            // `syncAfterAdoption`, não `sync`: um `Noop`/falha de sync não
            // re-hidrata sozinho, e as linhas adotadas já estão no Isar —
            // ver a doc de `ColdigomCatalogSyncNotifier.syncAfterAdoption`.
            if (adopted.isNotEmpty) {
              unawaited(syncNotifier.syncAfterAdoption());
            }
          }),
        );
      }

      final link = ref.keepAlive();
      final timer = Timer(homeRemoteSearchMemoDuration, link.close);
      ref.onDispose(timer.cancel);

      return page;
    }, retry: (_, _) => null);
