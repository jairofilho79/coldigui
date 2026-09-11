import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor_group.dart';

/// Tudo o que a Home precisa saber sobre a busca corrente, num valor só (C.2).
///
/// Substitui os seis `StateProvider` mutados imperativamente pelo antigo
/// `HomeSearchPipelineDriver`: não há mais geração a comparar nem escrita
/// cruzada entre providers — o estado é derivado das três fontes
/// (`query` debounced, busca local síncrona e a página remota `AsyncValue`)
/// e não pode ficar inconsistente.
final class HomeSearchState {
  const HomeSearchState({
    required this.query,
    required this.page,
    required this.localGroups,
    required this.remote,
  });

  /// Query já debounced (300 ms) — o texto cru vive em `homeSearchQueryProvider`.
  final String query;

  /// Página 1-based da fonte remota.
  final int page;

  /// Resultados PLPCG do índice em memória, sempre no topo da lista.
  final List<LouvorGroup> localGroups;

  /// Página remota (Coldigom): `loading` | `data` | `error`.
  final AsyncValue<CatalogSearchPage> remote;

  /// `true` quando não há o que buscar — nenhuma fonte toca a rede.
  bool get isEmptyQuery => query.trim().isEmpty;

  /// Grupos da página remota já carregada (vazio enquanto carrega ou falha).
  List<LouvorGroup> get remoteGroups => remote.value?.groups ?? const [];

  /// Lista exibida: PLPCG primeiro, Coldigom depois.
  List<LouvorGroup> get groups => [...localGroups, ...remoteGroups];

  /// `true` enquanto a página remota está em voo.
  bool get remoteLoading => remote.isLoading;

  /// `true` só quando a busca remota **terminou** em erro.
  ///
  /// Um refresh depois de uma falha mantém o erro anterior dentro do
  /// `AsyncLoading`; enquanto ele estiver em voo a linha "Coldigom
  /// indisponível" some e o spinner aparece — que é o que o usuário acabou de
  /// pedir ao tocar em "tentar de novo".
  bool get remoteFailed => !remote.isLoading && remote.hasError;

  /// `true` quando a fonte remota indica que há mais uma página.
  bool get hasNextPage => remote.value?.hasNextPage ?? false;
}
