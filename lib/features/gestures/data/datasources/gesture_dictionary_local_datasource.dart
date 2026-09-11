import 'package:flutter/foundation.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/gesture_dictionary_cache.dart';

/// Entrada única do cache do dicionário.
class GestureDictionaryCacheEntry {
  const GestureDictionaryCacheEntry({
    required this.content,
    required this.etag,
    required this.fetchedAt,
  });

  final String content;
  final String? etag;
  final DateTime fetchedAt;

  bool isStaleAt(DateTime now) =>
      now.difference(fetchedAt) > kGestureDictionaryTtl;
}

/// Idade a partir da qual o dicionário é revalidado (`If-None-Match`).
///
/// Uma hora: o coldigom publica `max-age=300`, mas aqui a revalidação custa
/// um round-trip que na maioria das vezes devolve 304 — não precisa ser a cada
/// abertura de louvor.
const kGestureDictionaryTtl = Duration(hours: 1);

/// Cache Isar do dicionário — linha única `GestureDictionaryCache.singletonId`.
class GestureDictionaryLocalDatasource {
  const GestureDictionaryLocalDatasource(this._isar);

  final Isar? _isar;

  GestureDictionaryCacheEntry? read() {
    final isar = _isar;
    if (isar == null) return null;
    try {
      final row = isar.gestureDictionaryCaches.get(
        GestureDictionaryCache.singletonId,
      );
      if (row == null) return null;
      return GestureDictionaryCacheEntry(
        content: row.content,
        etag: row.etag,
        fetchedAt: row.fetchedAt,
      );
    } on Object catch (error) {
      debugPrint('[gestos] leitura do cache do dicionário falhou: $error');
      return null;
    }
  }

  void write({required String content, required String? etag}) {
    final isar = _isar;
    if (isar == null) {
      debugPrint('[gestos] sem Isar — dicionário não persistido');
      return;
    }
    try {
      isar.write((isar) {
        isar.gestureDictionaryCaches.put(
          GestureDictionaryCache()
            ..content = content
            ..etag = etag
            ..fetchedAt = DateTime.now(),
        );
      });
    } on Object catch (error) {
      debugPrint('[gestos] escrita do cache do dicionário falhou: $error');
    }
  }

  /// Renova [GestureDictionaryCacheEntry.fetchedAt] depois de um 304.
  void touch() {
    final isar = _isar;
    if (isar == null) return;
    try {
      isar.write((isar) {
        final coll = isar.gestureDictionaryCaches;
        final row = coll.get(GestureDictionaryCache.singletonId);
        if (row == null) return;
        coll.put(row..fetchedAt = DateTime.now());
      });
    } on Object catch (error) {
      debugPrint('[gestos] touch do dicionário falhou: $error');
    }
  }
}
