import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../library/presentation/providers/library_view_settings_provider.dart';
import '../../domain/entities/catalog_filter_state.dart';
import '../../domain/utils/catalog_tag_hierarchy.dart';

// O objeto de valor mora no domínio; quem importava daqui continua a vê-lo.
export '../../domain/entities/catalog_filter_state.dart';

/// Filtros do catálogo — um estado só para a página inicial e a /biblioteca
/// (spec fim-fonte §2.2, C5).
final catalogFiltersProvider =
    NotifierProvider<CatalogFiltersNotifier, CatalogFilterState>(
      CatalogFiltersNotifier.new,
    );

/// Seleção, persistência (C13: pref `catalogFilters`, formato v3; a v2 é
/// lida e convertida) e hidratação da URL.
///
/// Mexer num filtro (toggle ou [clear]) volta a /biblioteca à página 1 — o
/// conjunto de resultados mudou. Hidratar da URL não: a URL traz a página.
class CatalogFiltersNotifier extends Notifier<CatalogFilterState> {
  @override
  CatalogFilterState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.catalogFilters);
    if (raw == null || raw.isEmpty) return CatalogFilterState.empty;

    CatalogFilterState? stored;
    try {
      stored = CatalogFilterState.fromPersistedJson(jsonDecode(raw));
    } on FormatException {
      stored = null;
    }
    if (stored == null) {
      // Formato antigo `{materials, arranjos}` (filtros que já não existem)
      // ou pref ilegível: descarta e apaga (spec §2.2).
      AppLogger.of('catalog')
          .warn('Filtros gravados em formato antigo ou inválido; descartados');
      unawaited(prefs.remove(StorageKeys.catalogFilters));
      return CatalogFilterState.empty;
    }
    return stored;
  }

  /// Hidrata os filtros dos params da rota (página inicial ou /biblioteca).
  ///
  /// Chamado no primeiro build das telas mesmo sem params: sem nenhum dos
  /// cinco (`tonality`, `rhythm`, `category`, `tags`, `materialKinds`),
  /// mantém o estado atual (gravado) em vez de limpar. `category` é legado e
  /// soma-se a `tags` em vez de valer sozinho ([CatalogFilterState.fromUrl]);
  /// um link cujos params só convertem em nada (ex.: `category=Avulsos`, uma
  /// coleção sem seção) também mantém o estado gravado — só substitui os
  /// quatro filtros de [CatalogFilterState] (os ausentes ficam vazios) quando
  /// o resultado da conversão não é vazio. Não grava.
  void hydrateFromUrl({
    String? tonality,
    String? rhythm,
    String? category,
    String? tags,
    String? materialKinds,
  }) {
    final fromUrl = CatalogFilterState.fromUrl(
      tonality: tonality,
      rhythm: rhythm,
      category: category,
      tags: tags,
      materialKinds: materialKinds,
    );
    if (fromUrl.isEmpty) return;
    state = fromUrl;
  }

  void toggleTonality(String value) =>
      _apply(state.copyWith(tonalities: _toggle(state.tonalities, value)));

  void toggleRhythm(String value) =>
      _apply(state.copyWith(rhythms: _toggle(state.rhythms, value)));

  /// Desmarcar uma tag desmarca também as subtags dela — senão ficariam
  /// ativas sem chip visível (as subtags só aparecem com o pai marcado).
  void toggleTag(String name) {
    final tags = state.tags.contains(name)
        ? {
            for (final tag in state.tags)
              if (!catalogTagMatches(tag, name)) tag,
          }
        : {...state.tags, name};
    _apply(state.copyWith(tags: tags));
  }

  void toggleMaterialKind(String kindId) => _apply(
    state.copyWith(materialKindIds: _toggle(state.materialKindIds, kindId)),
  );

  /// Tira todos os filtros e apaga a pref.
  void clear() {
    state = CatalogFilterState.empty;
    unawaited(
      ref.read(sharedPreferencesProvider).remove(StorageKeys.catalogFilters),
    );
    ref.read(libraryViewSettingsProvider.notifier).setPage(1);
  }

  void _apply(CatalogFilterState next) {
    state = next;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(
            StorageKeys.catalogFilters,
            jsonEncode(next.toPersistedJson()),
          ),
    );
    ref.read(libraryViewSettingsProvider.notifier).setPage(1);
  }

  static Set<String> _toggle(Set<String> current, String value) {
    final next = Set<String>.from(current);
    if (!next.remove(value)) next.add(value);
    return next;
  }
}
