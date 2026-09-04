import 'package:flutter/foundation.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/chord_content_cache.dart';

/// Cache Isar do conteúdo `.chord`, indexado por `r2Key`.
///
/// Best-effort de propósito: sem Isar (modo degradado web) a leitura devolve
/// `null` e a escrita vira no-op registrada — perder o cache degrada a
/// experiência offline, mas nunca pode derrubar a busca da cifra.
class ChordContentLocalDatasource {
  const ChordContentLocalDatasource(this._isar);

  final Isar? _isar;

  /// Conteúdo cru guardado para [r2Key], ou `null` se não houver.
  String? read(String r2Key) {
    final isar = _isar;
    final key = r2Key.trim();
    if (isar == null || key.isEmpty) return null;
    try {
      return isar.chordContentCaches
          .where()
          .r2KeyEqualTo(key)
          .findFirst()
          ?.content;
    } on Object catch (error) {
      debugPrint('[cifras] leitura do cache de $key falhou: $error');
      return null;
    }
  }

  /// Guarda [content] para [r2Key], substituindo o que houver.
  void write(String r2Key, String content) {
    final isar = _isar;
    final key = r2Key.trim();
    if (key.isEmpty) return;
    if (isar == null) {
      debugPrint('[cifras] sem Isar — cache de $key não persistido');
      return;
    }
    try {
      isar.write((isar) {
        final coll = isar.chordContentCaches;
        final row =
            coll.where().r2KeyEqualTo(key).findFirst() ??
            (ChordContentCache()..id = coll.autoIncrement());
        row
          ..r2Key = key
          ..content = content
          ..fetchedAt = DateTime.now();
        coll.put(row);
      });
    } on Object catch (error) {
      debugPrint('[cifras] escrita do cache de $key falhou: $error');
    }
  }
}
