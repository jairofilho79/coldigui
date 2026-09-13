import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_source_provider.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/ports/search_cancellation.dart';

/// Quanto tempo uma página remota bem-sucedida fica em memo.
///
/// É o LRU que não precisamos escrever: o `keepAlive` segura a instância da
/// família e o timer a solta. Voltar da página 2 para a 1 dentro da janela não
/// gasta requisição nenhuma.
const homeRemoteSearchMemoDuration = Duration(minutes: 10);

/// Identidade de uma busca remota: **só** texto e página.
///
/// Os filtros UC-02 ficam de fora de propósito — a API Coldigom não os aceita,
/// eles são aplicados em memória sobre o resultado local. É por isso que mexer
/// num chip de material não re-busca nada na rede.
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

/// Uma página da busca remota, cancelável e memoizada por `(query, página)`.
///
/// Cada instância cria a própria [SearchCancellation] e a cancela no
/// `onDispose`: quando a query muda, o Riverpod descarta a instância antiga e
/// a requisição em voo morre junto — é o que impede uma resposta atrasada de
/// sobrescrever a lista da tecla seguinte (o antigo contador `_generation`).
///
/// O retry automático do Riverpod 3 fica desligado (`retry: (_, _) => null`):
/// a falha remota é um estado de UI com retry **manual** (a linha "Coldigom
/// indisponível"), não uma falha transitória a esconder atrás de ~30 s de
/// backoff.
final homeRemoteSearchProvider = FutureProvider.autoDispose
    .family<CatalogSearchPage, HomeRemoteSearchKey>((ref, key) async {
      // Query vazia não tem página remota — e não pode custar uma requisição.
      if (key.query.trim().isEmpty) return CatalogSearchPage.empty;

      final cancellation = SearchCancellation();
      ref.onDispose(cancellation.cancel);

      // `read`, não `watch`: o repositório Coldigom grava os caches ao
      // responder, o que recompõe `catalogSourceProvider`. Observar a fonte
      // aqui faria a resposta re-disparar a própria busca, em laço.
      final source = ref.read(catalogSourceProvider);

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

      final link = ref.keepAlive();
      final timer = Timer(homeRemoteSearchMemoDuration, link.close);
      ref.onDispose(timer.cancel);

      return page;
    }, retry: (_, _) => null);
