import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Seleção **local** de kinds Coldigom para download (O11): independente
/// dos favoritos da conta — mudar favoritos não mexe no que já foi
/// marcado/baixado. A pré-marcação dos favoritos só se aplica quando o
/// utilizador nunca decidiu ([hasDecision] `false`), por isso «vazio» e
/// «nunca gravado» são estados diferentes.
class OfflineColdigomKindSelectionStore {
  const OfflineColdigomKindSelectionStore(this._prefs);

  final SharedPreferences _prefs;

  bool get hasDecision =>
      _prefs.containsKey(StorageKeys.offlineColdigomKindIds);

  Set<String> read() {
    final raw = _prefs.getString(StorageKeys.offlineColdigomKindIds);
    if (raw == null) return const {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const {};
      return {
        for (final id in list)
          if (id is String && id.isNotEmpty) id,
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> write(Set<String> kindIds) {
    return _prefs.setString(
      StorageKeys.offlineColdigomKindIds,
      jsonEncode(kindIds.toList()..sort()),
    );
  }
}
