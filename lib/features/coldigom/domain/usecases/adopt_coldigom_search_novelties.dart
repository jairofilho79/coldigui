import 'package:flutter/foundation.dart';

import '../../../catalog/domain/entities/louvor_group.dart';
import '../../data/datasources/coldigom_catalog_local_datasource.dart';
import '../../data/mappers/coldigom_praise_cache_mapper.dart';

/// Adota no catálogo local os louvores que a página remota trouxe e o
/// Isar não conhecia (§6.2, O15).
///
/// Só grupos fora de [knownPraiseIds] (os ids do índice hidratado) e fora
/// do Isar. É o segundo escritor de
/// `ColdigomPraiseCache` — o `replaceAll` do sync vence sempre (é o estado
/// do servidor) e quem chama dispara esse sync quando isto adota algo.
/// Best-effort: sem Isar devolve vazio.
class AdoptColdigomSearchNovelties {
  const AdoptColdigomSearchNovelties(this._local);

  final ColdigomCatalogLocalDatasource _local;

  Future<Set<String>> call(
    Iterable<LouvorGroup> remoteGroups, {
    required Set<String> knownPraiseIds,
  }) async {
    if (!_local.isAvailable) return const {};
    final rows = [
      for (final group in remoteGroups)
        if (!knownPraiseIds.contains(group.groupId) &&
            _local.findByPraiseIdSync(group.groupId) == null)
          ColdigomPraiseCacheMapper.fromLouvorGroup(group),
    ];
    if (rows.isEmpty) return const {};
    try {
      await _local.upsertMany(rows);
    } on Object catch (error) {
      debugPrint('[coldigom] adoção de novos da pesquisa falhou: $error');
      return const {};
    }
    return {for (final row in rows) row.praiseId};
  }
}
