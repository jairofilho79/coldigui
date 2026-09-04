import 'package:flutter/foundation.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/chord_content_cache.dart';

/// Entrada do cache: o corpo cru e quando ele foi buscado.
///
/// [content] vazio é o **marcador negativo** — o Worker respondeu 404, a cifra
/// não existe. Guardar isso evita um GET por abertura de sheet no caso mais
/// comum (louvor sem cifra), e o [fetchedAt] deixa a revalidação recuperar uma
/// cifra publicada depois.
class ChordCacheEntry {
  const ChordCacheEntry({required this.content, required this.fetchedAt});

  final String content;
  final DateTime fetchedAt;

  /// `true` quando a entrada passou de [kChordCacheTtl].
  bool isStaleAt(DateTime now) => now.difference(fetchedAt) > kChordCacheTtl;
}

/// Idade a partir da qual uma entrada do cache é revalidada em background.
///
/// Cifras mudam raramente; o que importa é não disparar um GET a cada abertura
/// de sheet, já que o `chordSongProvider` é `autoDispose`.
const kChordCacheTtl = Duration(hours: 24);

/// Cache Isar do conteúdo `.chord`, indexado por `r2Key`.
///
/// Best-effort de propósito: sem Isar (modo degradado web) a leitura devolve
/// `null` e a escrita vira no-op registrada — perder o cache degrada a
/// experiência offline, mas nunca pode derrubar a busca da cifra.
class ChordContentLocalDatasource {
  const ChordContentLocalDatasource(this._isar);

  final Isar? _isar;

  /// Entrada guardada para [r2Key], ou `null` quando não há nenhuma.
  ///
  /// `null` significa "nunca buscamos"; uma entrada com [ChordCacheEntry.content]
  /// vazio significa "buscamos e não existe".
  ChordCacheEntry? read(String r2Key) {
    final isar = _isar;
    final key = r2Key.trim();
    if (isar == null || key.isEmpty) return null;
    try {
      final row = isar.chordContentCaches.where().r2KeyEqualTo(key).findFirst();
      if (row == null) return null;
      return ChordCacheEntry(content: row.content, fetchedAt: row.fetchedAt);
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
