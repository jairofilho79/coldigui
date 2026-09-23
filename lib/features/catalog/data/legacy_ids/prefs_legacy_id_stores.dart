import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../pdf_reader/data/datasources/reader_preferences_datasource.dart';
import '../../domain/legacy_ids/legacy_id_store.dart';

/// «Abertos recentemente» (`StorageKeys.recentlyOpened`, JSON, mais recente
/// primeiro) — spec 2026-09-23 §6.2: troca sem repetidos, desconhecido sai.
///
/// Escreve direto na pref; quem chama invalida o `recentlyOpenedProvider`.
class RecentlyOpenedLegacyIdStore implements LegacyIdStore {
  const RecentlyOpenedLegacyIdStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String get name => 'recentlyOpened';

  List<String> _read() {
    final raw = _prefs.getString(StorageKeys.recentlyOpened);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final id in _read())
      if (isLegacyPdfId(id)) id,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    final current = _read();
    final next = <String>[];
    for (final id in current) {
      final rewritten = resolution.rewrite(id);
      if (rewritten != null && !next.contains(rewritten)) next.add(rewritten);
    }
    if (_sameList(current, next)) return 0;
    await _prefs.setString(StorageKeys.recentlyOpened, jsonEncode(next));
    return 1;
  }
}

/// Última página por PDF (`StorageKeys.pdfLastPages`) — spec §6.2: troca o
/// `id`; em colisão fica a entrada mais recente; desconhecido sai.
class PdfLastPagesLegacyIdStore implements LegacyIdStore {
  const PdfLastPagesLegacyIdStore(this._datasource);

  final ReaderPreferencesDatasource _datasource;

  @override
  String get name => 'pdfLastPages';

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final id in _datasource.lastPageIds())
      if (isLegacyPdfId(id)) id,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async =>
      await _datasource.rewriteLastPageIds(resolution.rewrite) ? 1 : 0;
}

/// Entrada focada da lista ativa (`carousel_focused_pdf_id`, formato `id` ou
/// `id#n` — ver `entryKeyFor`) — spec §6.2: troca a parte do id e mantém o
/// sufixo; desconhecido apaga a pref (o foco cai no início).
///
/// Um id Base64 URL-safe nunca tem `#`, por isso o último `#` separa o
/// sufixo. Quem chama invalida o `carouselFocusedKeyProvider`.
class FocusedEntryLegacyIdStore implements LegacyIdStore {
  const FocusedEntryLegacyIdStore(this._prefs, {required this.key});

  final SharedPreferences _prefs;

  /// `kCarouselFocusedPdfIdPrefsKey` — vem por parâmetro para a camada de
  /// dados não importar a de apresentação das playlists.
  final String key;

  @override
  String get name => 'focusedEntry';

  (String id, String suffix)? _read() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final hash = raw.lastIndexOf('#');
    return hash < 0 ? (raw, '') : (raw.substring(0, hash), raw.substring(hash));
  }

  @override
  Future<Set<String>> collectLegacyIds() async {
    final value = _read();
    return value != null && isLegacyPdfId(value.$1)
        ? {value.$1}
        : const <String>{};
  }

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    final value = _read();
    if (value == null) return 0;
    final (id, suffix) = value;
    final next = resolution.rewrite(id);
    if (next == id) return 0;
    if (next == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, '$next$suffix');
    }
    return 1;
  }
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
