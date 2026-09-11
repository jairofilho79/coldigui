import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/pdf_reader_preferences.dart';

/// Teto de entradas do LRU de última página (spec A.3 C8).
const _maxLastPageEntries = 50;

/// Persistência de preferências do leitor PDF (UC-11 Fase 2.3 / spec A.3 C8).
///
/// Lê/grava [StorageKeys.pdfPreferredFitMode] e [StorageKeys.pdfLastPages].
class ReaderPreferencesDatasource {
  const ReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Modo de encaixe salvo ou default `page-fit`.
  PdfFitMode getFitMode() {
    final stored = _prefs.getString(StorageKeys.pdfPreferredFitMode);
    return PdfFitMode.fromStorageString(stored) ?? PdfFitMode.pageFit;
  }

  /// Carrega preferências de visualização.
  PdfReaderViewSettings loadSettings() {
    return PdfReaderViewSettings(fitMode: getFitMode());
  }

  /// Persiste modo de encaixe.
  Future<void> saveFitMode(PdfFitMode mode) async {
    await _prefs.setString(
      StorageKeys.pdfPreferredFitMode,
      mode.toStorageString(),
    );
  }

  /// Última página lembrada para [pdfId], ou `null` se nunca salva / JSON
  /// corrompido (não lança — trata como cache vazio).
  int? lastPageFor(String pdfId) {
    final entries = _readLastPages();
    for (final entry in entries) {
      if (entry.id == pdfId) return entry.page;
    }
    return null;
  }

  /// Salva [page] como última página de [pdfId] — LRU de
  /// [_maxLastPageEntries]: entrada existente é atualizada e vai para o fim
  /// (mais recente); ao estourar o teto, a mais antiga (início da lista) sai.
  Future<void> saveLastPage(String pdfId, int page) async {
    final entries = _readLastPages()
      ..removeWhere((entry) => entry.id == pdfId)
      ..add(_LastPageEntry(id: pdfId, page: page));

    while (entries.length > _maxLastPageEntries) {
      entries.removeAt(0);
    }

    await _prefs.setString(
      StorageKeys.pdfLastPages,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  List<_LastPageEntry> _readLastPages() {
    final raw = _prefs.getString(StorageKeys.pdfLastPages);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map(_LastPageEntry.fromJson)
          .whereType<_LastPageEntry>()
          .toList();
    } on FormatException {
      return [];
    }
  }
}

/// Entrada do LRU de última página — chaves compactas `id`/`p` no JSON.
class _LastPageEntry {
  const _LastPageEntry({required this.id, required this.page});

  final String id;
  final int page;

  Map<String, Object?> toJson() => {'id': id, 'p': page};

  /// `null` quando o item não tem o shape esperado (JSON corrompido/parcial).
  static _LastPageEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final page = json['p'];
    if (id is! String || page is! num) return null;
    return _LastPageEntry(id: id, page: page.toInt());
  }
}
