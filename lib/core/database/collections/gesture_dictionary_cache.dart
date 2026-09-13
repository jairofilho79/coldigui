import 'package:isar_plus/isar_plus.dart';

part 'gesture_dictionary_cache.g.dart';

/// Cache persistente do dicionário de gestos — **linha única**, `id = 1`.
///
/// Guarda o [etag] porque a revalidação usa `If-None-Match`: um 304 custa um
/// round-trip vazio em vez dos ~40 KB do JSON.
@Collection()
class GestureDictionaryCache {
  /// Sempre [singletonId]; a coleção nunca tem mais de uma linha.
  int id = singletonId;

  static const int singletonId = 1;

  late String content;

  String? etag;

  late DateTime fetchedAt;
}
