import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../catalog/domain/constants/catalog_materials.dart';

/// Persistência das categorias de material cujo bulk ZIP já foi concluído.
class OfflineBulkCategoriesStore {
  const OfflineBulkCategoriesStore(this._prefs);

  final SharedPreferences _prefs;

  Set<String> load() {
    final raw = _prefs.getString(StorageKeys.offlineBulkCategories);
    if (raw == null || raw.isEmpty) return {};

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => e as String)
          .where(CatalogMaterials.uiMaterials.contains)
          .toSet();
    } on Object {
      return {};
    }
  }

  Future<void> save(Set<String> categories) async {
    final ordered = CatalogMaterials.uiMaterials
        .where(categories.contains)
        .toList(growable: false);
    await _prefs.setString(
      StorageKeys.offlineBulkCategories,
      jsonEncode(ordered),
    );
  }

  Future<Set<String>> addCategories(Iterable<String> categories) async {
    final merged = {
      ...load(),
      ...categories.where(CatalogMaterials.uiMaterials.contains),
    };
    await save(merged);
    return merged;
  }

  /// Migração lazy: usuários em UC-10 sem registro explícito.
  Future<Set<String>> loadOrMigrate({
    required bool isConfigured,
    required Map<String, int> byCategory,
  }) async {
    final stored = load();
    if (stored.isNotEmpty || !isConfigured) return stored;

    final inferred = {
      for (final material in CatalogMaterials.uiMaterials)
        if ((byCategory[material] ?? 0) > 0) material,
    };
    if (inferred.isEmpty) return stored;

    await save(inferred);
    return inferred;
  }

  Future<void> clear() async {
    await _prefs.remove(StorageKeys.offlineBulkCategories);
  }
}
