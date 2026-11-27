import 'package:flutter/foundation.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/gesture_document_cache.dart';
import '../../../../core/database/storage_unavailable_exception.dart';

/// Entrada do cache: o JSON cru e quando ele foi buscado.
///
/// [content] vazio é o **marcador negativo** (404): evita um GET por abertura
/// no caso de material publicado sem objeto no R2.
class GestureCacheEntry {
  const GestureCacheEntry({required this.content, required this.fetchedAt});

  final String content;
  final DateTime fetchedAt;

  bool isStaleAt(DateTime now) => now.difference(fetchedAt) > kGestureCacheTtl;
}

/// Idade a partir da qual uma entrada é revalidada em background.
const kGestureCacheTtl = Duration(hours: 24);

/// Cache Isar do documento `.gestures`, indexado por `r2Key`.
///
/// Best-effort como o de cifras: sem Isar (web degradada) `read` devolve
/// `null` e `write` vira no-op registrado.
class GestureContentLocalDatasource {
  const GestureContentLocalDatasource(this._isar, {this.skipAutomaticWrite});

  final Isar? _isar;
  final bool Function(String key)? skipAutomaticWrite;

  bool writeOnRead(String key, String content) {
    if (skipAutomaticWrite?.call(key) == true) return false;
    write(key, content);
    return true;
  }

  void remove(String key) {
    final isar = _isar;
    if (isar == null) {
      throw const StorageUnavailableException('offline.gesture');
    }
    isar.write((isar) {
      final coll = isar.gestureDocumentCaches;
      final row = coll.where().r2KeyEqualTo(key).findFirst();
      if (row != null) coll.delete(row.id);
    });
  }

  GestureCacheEntry? read(String r2Key) {
    final isar = _isar;
    final key = r2Key.trim();
    if (isar == null || key.isEmpty) return null;
    try {
      final row = isar.gestureDocumentCaches
          .where()
          .r2KeyEqualTo(key)
          .findFirst();
      if (row == null) return null;
      return GestureCacheEntry(content: row.content, fetchedAt: row.fetchedAt);
    } on Object catch (error) {
      debugPrint('[gestos] leitura do cache de $key falhou: $error');
      return null;
    }
  }

  void write(String r2Key, String content) {
    final isar = _isar;
    final key = r2Key.trim();
    if (key.isEmpty) return;
    if (isar == null) {
      debugPrint('[gestos] sem Isar — cache de $key não persistido');
      return;
    }
    try {
      isar.write((isar) {
        final coll = isar.gestureDocumentCaches;
        final row =
            coll.where().r2KeyEqualTo(key).findFirst() ??
            (GestureDocumentCache()..id = coll.autoIncrement());
        row
          ..r2Key = key
          ..content = content
          ..fetchedAt = DateTime.now();
        coll.put(row);
      });
    } on Object catch (error) {
      debugPrint('[gestos] escrita do cache de $key falhou: $error');
    }
  }

  /// `r2Key`s com corpo gravado (exclui o marcador negativo) — insumo do
  /// mapa de disponibilidade offline; vazio sem Isar.
  List<String> allKeysWithContent() {
    final isar = _isar;
    if (isar == null) return const [];
    try {
      return [
        for (final row in isar.gestureDocumentCaches.where().findAll())
          if (row.content.isNotEmpty) row.r2Key,
      ];
    } on Object catch (error) {
      debugPrint('[gestos] listagem do cache falhou: $error');
      return const [];
    }
  }
}
