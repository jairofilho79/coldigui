import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../library/presentation/providers/library_view_settings_provider.dart';
import '../../domain/entities/catalog_filter_state.dart';

// O objeto de valor mora no domínio; quem importava daqui continua a vê-lo.
export '../../domain/entities/catalog_filter_state.dart';

/// Filtros do catálogo — um estado só para a página inicial e a /biblioteca
/// (spec fim-fonte §2.2, C5).
final catalogFiltersProvider =
    NotifierProvider<CatalogFiltersNotifier, CatalogFilterState>(
      CatalogFiltersNotifier.new,
    );

/// Seleção, persistência (C13: pref `catalogFilters`, formato v2) e
/// hidratação da URL.
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
  /// cinco, mantém o estado atual (gravado) em vez de limpar. Com algum,
  /// a URL manda nos cinco (os ausentes ficam vazios). Não grava.
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

  void toggleCategory(String value) =>
      _apply(state.copyWith(categories: _toggle(state.categories, value)));

  void toggleTag(String name) =>
      _apply(state.copyWith(tags: _toggle(state.tags, name)));

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
