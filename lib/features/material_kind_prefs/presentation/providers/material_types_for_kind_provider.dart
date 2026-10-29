import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_remote_providers.dart';

/// Material types (`pdf`/`chord`/...) que de fato existem para um material
/// kind (`GET /api/materials/kinds/:kindId/types`), calculado sob demanda
/// pelo Worker — só usado ao abrir o menu de preferência de type do card
/// (nada mantém isso "vivo" como [coldigomMaterialKindsProvider]).
final materialTypesForKindProvider =
    FutureProvider.family<List<String>, String>((ref, kindId) {
      return ref
          .watch(coldigomRemoteDatasourceProvider)
          .fetchMaterialTypesForKind(kindId);
    });
