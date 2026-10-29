import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/material_kind_prefs.dart';

/// Documento de favoritos em SharedPreferences, uma chave por conta.
///
/// Não é Isar de propósito: são cinco ids por conta, e a coleção Isar
/// custaria codegen e mais um caminho de `StorageUnavailableException`.
class MaterialKindPrefsLocalDatasource {
  MaterialKindPrefsLocalDatasource(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'material_kind_prefs.';

  static String keyFor(String sub) => '$_keyPrefix$sub';

  MaterialKindPrefs? read(String sub) {
    final raw = _prefs.getString(keyFor(sub));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MaterialKindPrefs.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException catch (e) {
      debugPrint('[material-kind-prefs] JSON local ilegível: $e');
      return null;
    }
  }

  Future<void> write(String sub, MaterialKindPrefs prefs) async {
    await _prefs.setString(keyFor(sub), jsonEncode(prefs.toJson()));
  }
}
