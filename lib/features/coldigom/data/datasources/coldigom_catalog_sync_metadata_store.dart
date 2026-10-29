import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../catalog/domain/entities/material_kind_taxonomy.dart';

/// Versão do formato do dump que este app lê (spec louvores-agrupados
/// §3.4). Sobe **uma** vez por campo novo do dump que o app passa a ler: o
/// próximo sync ignora o ETag guardado e regrava as linhas, senão o `304`
/// de um dump já com o campo — cujo ETag o app anterior guardou — manteria
/// as linhas sem ele para sempre.
///
/// 1 = `groupId`.
/// 2 = `notes` em praise_materials.
const coldigomCatalogSchemaVersion = 2;

/// Metadados do sync do catálogo Coldigom em SharedPreferences: o ETag que
/// vai no `If-None-Match`, quando foi a última validação e quantos praises o
/// último dump trouxe (linha de estado do `/offline`).
///
/// Fora do Isar de propósito: sem Isar não há catálogo, e um ETag órfão
/// faria o próximo sync receber `304` para um banco vazio.
class ColdigomCatalogSyncMetadataStore {
  const ColdigomCatalogSyncMetadataStore(this._prefs);

  final SharedPreferences _prefs;

  String? readEtag() => _prefs.getString(StorageKeys.coldigomCatalogEtag);

  DateTime? readSyncedAt() {
    final raw = _prefs.getString(StorageKeys.coldigomCatalogSyncedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  int readCount() => _prefs.getInt(StorageKeys.coldigomCatalogCount) ?? 0;

  /// Versão do formato com que as linhas atuais foram gravadas; `0` quando
  /// nunca foi gravada (instalação anterior à trava).
  int readCatalogSchemaVersion() =>
      _prefs.getInt(StorageKeys.coldigomCatalogSchemaVersion) ?? 0;

  Future<void> writeCatalogSchemaVersion(int version) =>
      _prefs.setInt(StorageKeys.coldigomCatalogSchemaVersion, version);

  /// Dump novo gravado no Isar.
  Future<void> markReplaced({
    required String? etag,
    required int count,
    required DateTime at,
  }) async {
    if (etag == null) {
      await _prefs.remove(StorageKeys.coldigomCatalogEtag);
    } else {
      await _prefs.setString(StorageKeys.coldigomCatalogEtag, etag);
    }
    await _prefs.setInt(StorageKeys.coldigomCatalogCount, count);
    await writeCatalogSchemaVersion(coldigomCatalogSchemaVersion);
    await markValidated(at);
  }

  /// `304`: o catálogo continua o do servidor — só a data muda.
  Future<void> markValidated(DateTime at) {
    return _prefs.setString(
      StorageKeys.coldigomCatalogSyncedAt,
      at.toUtc().toIso8601String(),
    );
  }

  /// Taxonomia dos kinds do último dump; `null` quando nunca foi gravada ou
  /// o JSON está ilegível.
  MaterialKindTaxonomy? readKindTaxonomy() {
    final raw = _prefs.getString(StorageKeys.coldigomKindTaxonomy);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? MaterialKindTaxonomy.fromJson(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  /// Gravada a cada dump novo, com ou sem Isar: sem ela o filtro Materiais
  /// não tem classes, e ela não é um ETag (não há risco de `304` órfão).
  Future<void> writeKindTaxonomy(MaterialKindTaxonomy taxonomy) =>
      _prefs.setString(
        StorageKeys.coldigomKindTaxonomy,
        jsonEncode(taxonomy.toJson()),
      );
}
