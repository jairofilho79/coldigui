import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/entities/louvor.dart';
import '../../catalog/domain/entities/louvor_data_source.dart';
import '../domain/utils/coldigom_praise_id.dart';
import 'adapters/coldigom_louvor_adapter.dart';
import 'providers/coldigom_providers.dart';

/// Busca sob demanda os materiais do praise ao abrir o leitor, se o cache
/// tiver só o PDF escolhido — habilita "Trocar material" na toolbar.
final ensureColdigomPraiseMaterialsCachedProvider =
    Provider<Future<void> Function(Louvor)>((ref) {
      return (Louvor louvor) async {
        if (louvor.source != LouvorDataSource.coldigom) return;

        final praiseId = coldigomPraiseIdFromPdfId(louvor.pdfId);
        if (praiseId == null) return;

        ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
          louvor,
        ]);

        final cache = ref.read(coldigomLouvoresCacheProvider);
        final siblingsInCache = cache.values
            .where((l) => coldigomPraiseIdFromPdfId(l.pdfId) == praiseId)
            .length;
        if (siblingsInCache > 1) return;

        final detail = await ref
            .read(coldigomRemoteDatasourceProvider)
            .fetchDetail(praiseId);
        ref
            .read(coldigomLouvoresCacheProvider.notifier)
            .mergeLouvores(ColdigomLouvorAdapter.toLouvores(detail));
      };
    });
