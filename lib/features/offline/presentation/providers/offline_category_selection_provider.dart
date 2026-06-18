import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/constants/catalog_materials.dart';
import '../../data/datasources/offline_available_store.dart';
import '../../data/datasources/offline_bulk_categories_store.dart';
import '../../data/datasources/offline_selected_categories_store.dart';
import '../../data/providers/offline_providers.dart';
import 'offline_cache_status_provider.dart';

/// Estado da seleção de categorias offline (chips UC-09/UC-10).
class OfflineCategorySelectionState {
  const OfflineCategorySelectionState({
    required this.selected,
    required this.bulkDownloaded,
  });

  final Set<String> selected;
  final Set<String> bulkDownloaded;

  /// Categorias selecionadas com packages já baixados — escopo de faltantes.
  Set<String> get missingScope => selected.intersection(bulkDownloaded);

  /// Categorias selecionadas sem packages — escopo de bulk ZIP.
  Set<String> get packagesScope => selected.difference(bulkDownloaded);

  OfflineCategorySelectionState copyWith({
    Set<String>? selected,
    Set<String>? bulkDownloaded,
  }) {
    return OfflineCategorySelectionState(
      selected: selected ?? this.selected,
      bulkDownloaded: bulkDownloaded ?? this.bulkDownloaded,
    );
  }
}

final offlineCategorySelectionProvider = NotifierProvider<
    OfflineCategorySelectionNotifier, OfflineCategorySelectionState>(
  OfflineCategorySelectionNotifier.new,
);

/// Gerencia chips selecionados e categorias com bulk concluído.
class OfflineCategorySelectionNotifier
    extends Notifier<OfflineCategorySelectionState> {
  OfflineBulkCategoriesStore get _bulkStore =>
      ref.read(offlineBulkCategoriesStoreProvider);

  OfflineSelectedCategoriesStore get _selectedStore =>
      ref.read(offlineSelectedCategoriesStoreProvider);

  OfflineAvailableStore get _availableStore =>
      ref.read(offlineAvailableStoreProvider);

  @override
  OfflineCategorySelectionState build() {
    final selected = _selectedStore.load();
    final bulkDownloaded = _bulkStore.load();

    ref.listen(offlineCacheStatusProvider, (previous, next) {
      if (previous?.stats.byCategory == next.stats.byCategory) return;
      unawaited(_syncBulkFromMigration(next.stats.byCategory));
    });

    Future.microtask(() async {
      final byCategory = ref.read(offlineCacheStatusProvider).stats.byCategory;
      await _syncBulkFromMigration(byCategory);
    });

    return OfflineCategorySelectionState(
      selected: selected,
      bulkDownloaded: bulkDownloaded,
    );
  }

  Future<void> _syncBulkFromMigration(Map<String, int> byCategory) async {
    final migrated = await _bulkStore.loadOrMigrate(
      isConfigured: _availableStore.isConfigured,
      byCategory: byCategory,
    );
    if (!_setsEqual(migrated, state.bulkDownloaded)) {
      state = state.copyWith(bulkDownloaded: migrated);
    }
  }

  Future<void> toggle(String material) async {
    if (!CatalogMaterials.uiMaterials.contains(material)) return;

    final next = Set<String>.from(state.selected);
    if (next.contains(material)) {
      next.remove(material);
    } else {
      next.add(material);
    }
    await _selectedStore.save(next);
    state = state.copyWith(selected: next);
  }

  Future<void> setSelected(Set<String> categories) async {
    final valid =
        categories.where(CatalogMaterials.uiMaterials.contains).toSet();
    if (valid.isEmpty) return;
    await _selectedStore.save(valid);
    state = state.copyWith(selected: valid);
  }

  Future<Set<String>> registerBulkCompleted(Iterable<String> categories) async {
    final merged = await _bulkStore.addCategories(categories);
    state = state.copyWith(bulkDownloaded: merged);
    return merged;
  }

  Future<void> clearAll() async {
    await _bulkStore.clear();
    await _selectedStore.clear();
    state = OfflineCategorySelectionState(
      selected: Set<String>.from(CatalogMaterials.defaultSelected),
      bulkDownloaded: {},
    );
  }

  bool _setsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }
}
