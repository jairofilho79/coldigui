import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/models/praise_dto.dart';
import '../../../coldigom/data/providers/coldigom_remote_providers.dart';

/// Catálogo de material kinds do Coldigom (`GET /api/materials/kinds`),
/// já ordenado por rótulo pelo Worker. Fica vivo: a lista muda raramente e
/// a tela de favoritos e o rótulo dos escolhidos leem dela.
final coldigomMaterialKindsProvider =
    FutureProvider<List<ColdigomMaterialKindDto>>((ref) {
      return ref.watch(coldigomRemoteDatasourceProvider).fetchMaterialKinds();
    });
