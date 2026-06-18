import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../catalog/domain/constants/catalog_materials.dart';

/// Persistência da seleção de chips de material na tela offline.
class OfflineSelectedCategoriesStore {
  const OfflineSelectedCategoriesStore(this._prefs);

  final SharedPreferences _prefs;

  Set<String> load() {
    final raw = _prefs.getString(StorageKeys.offlineSelectedCategories);
    if (raw == null || raw.isEmpty) {
      return Set<String>.from(CatalogMaterials.defaultSelected);
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((e) => e as String)
          .where(CatalogMaterials.uiMaterials.contains)
          .toSet();
      return parsed.isEmpty
          ? Set<String>.from(CatalogMaterials.defaultSelected)
          : parsed;
    } on Object {
      return Set<String>.from(CatalogMaterials.defaultSelected);
    }
  }

  Future<void> save(Set<String> categories) async {
    final ordered = CatalogMaterials.uiMaterials
        .where(categories.contains)
        .toList(growable: false);
    await _prefs.setString(
      StorageKeys.offlineSelectedCategories,
      jsonEncode(ordered),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(StorageKeys.offlineSelectedCategories);
  }
}
