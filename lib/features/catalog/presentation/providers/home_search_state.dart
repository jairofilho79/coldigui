import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor_group.dart';

/// O que a linha de estado da Home diz sobre a lista (spec offline
/// Coldigom §6.1).
enum SearchFreshness {
  /// Página remota em voo — «Em cache · a verificar…».
  checking,

  /// Remoto confirmou a lista local — «Atualizado».
  updated,

  /// Remoto trouxe louvores que o local não tinha — «Atualizado · N novos».
  updatedWithNew,

  /// Sem rede: o remoto nem foi chamado — «Em cache · sem ligação».
  offline,

  /// Remoto falhou; a lista local fica — «Em cache · não foi possível verificar».
  failed,
}

/// Tudo o que a Home precisa saber sobre a busca corrente, num valor só (C.2).
///
/// Valor **derivado** por `homeSearchStateProvider` — da `query` debounced,
/// da busca local síncrona (PLPCG + Coldigom, O16), da página remota
/// `AsyncValue` e da conectividade —, nunca mutado na mão: não há geração a
/// comparar nem escrita cruzada entre providers. A lista é 100 % local; o
/// remoto só **valida** (O15): o que ele traz a mais entra em [newGroups],
/// no fim, com o chip «novo».
final class HomeSearchState {
  const HomeSearchState({
    required this.query,
    required this.localGroups,
    required this.remote,
    this.newGroups = const [],
    this.offline = false,
    this.knownIds = const {},
  });

  /// Query já debounced (300 ms) — o texto cru vive em `homeSearchQueryProvider`.
  final String query;

  /// Resultados locais: PLPCG (com filtros UC-02) e depois Coldigom.
  final List<LouvorGroup> localGroups;

  /// Página 1 remota (Coldigom): `loading` | `data` | `error`. Ignorada
  /// quando [offline].
  final AsyncValue<CatalogSearchPage> remote;

  /// Grupos que só o remoto tinha, na ordem remota — anexados no fim.
  final List<LouvorGroup> newGroups;

  /// `true` quando o remoto não foi chamado por falta de rede.
  final bool offline;

  /// Ids que o índice Coldigom já conhece (`coldigomSearchIndexProvider`),
  /// não os do local desta busca: um grupo pode estar em [newGroups] (a
  /// busca textual local não o achou) e ainda assim já ser conhecido do
  /// catálogo — ele entra em [groups] mas não é «novo» (§6.3, ruling do
  /// controller).
  final Set<String> knownIds;

  /// `true` quando não há o que buscar — nenhuma fonte toca a rede.
  bool get isEmptyQuery => query.trim().isEmpty;

  /// Lista exibida: local primeiro, extras do remoto no fim (sem reordenar) —
  /// «extra» é só o que a busca textual local não trouxe, «novo» (chip) é
  /// mais estrito: ver [newGroupIds].
  List<LouvorGroup> get groups => [...localGroups, ...newGroups];

  /// Ids dos cards que levam o chip «novo»: extras do remoto que o catálogo
  /// (não só esta busca) ainda não conhecia.
  Set<String> get newGroupIds => {
    for (final g in newGroups)
      if (!knownIds.contains(g.groupId)) g.groupId,
  };

  int get newCount => newGroupIds.length;

  /// `true` enquanto a página remota está em voo (e há rede).
  bool get remoteLoading => !offline && remote.isLoading;

  /// `true` só quando a busca remota **terminou** em erro.
  ///
  /// Um refresh depois de uma falha mantém o erro anterior dentro do
  /// `AsyncLoading`; enquanto ele estiver em voo a linha volta a «a
  /// verificar…» — que é o que o usuário acabou de pedir ao tocar em
  /// «tentar de novo».
  bool get remoteFailed => !offline && !remote.isLoading && remote.hasError;

  SearchFreshness get freshness {
    if (offline) return SearchFreshness.offline;
    if (remote.isLoading) return SearchFreshness.checking;
    if (remote.hasError) return SearchFreshness.failed;
    return newGroupIds.isEmpty
        ? SearchFreshness.updated
        : SearchFreshness.updatedWithNew;
  }
}
