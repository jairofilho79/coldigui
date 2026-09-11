import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_source_provider.dart';
import '../entities/catalog_material.dart';

/// Material endereçável por [materialId], ou `null` se não houver.
///
/// PDF sai do manifest PLPCG ou do cache Coldigom, cifra, gesto e áudio saem
/// dos caches Coldigom; YouTube (id que não vive no espaço de ids do app) e id
/// inválido devolvem `null` — quem chama segue pelo caminho que já tinha.
///
/// Quem resolve é a porta [CatalogSource]: nenhum chamador escolhe acervo nem
/// conhece cache.
Future<CatalogMaterial?> resolveCatalogMaterial(Ref ref, String materialId) {
  return ref.read(catalogSourceProvider).materialById(materialId);
}

/// [resolveCatalogMaterial] a partir de um widget.
///
/// `Ref` e `WidgetRef` não têm supertipo público no Riverpod 3, e o desvio de
/// material da playlist roda dentro de um `ConsumerState`.
Future<CatalogMaterial?> resolveCatalogMaterialFromWidget(
  WidgetRef ref,
  String materialId,
) {
  return ref.read(catalogSourceProvider).materialById(materialId);
}
