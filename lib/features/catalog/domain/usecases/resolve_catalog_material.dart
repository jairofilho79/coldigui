import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_source_provider.dart';
import '../entities/catalog_material.dart';

/// Material endereçável por [materialId], ou `null` se não houver.
///
/// PDF, cifra, gesto e áudio saem do catálogo coldigom; YouTube (id que não
/// vive no espaço de ids do app) e id inválido devolvem `null` — quem chama
/// segue pelo caminho que já tinha.
///
/// Quem resolve é a porta [CatalogSource]: nenhum chamador escolhe acervo nem
/// conhece cache.
///
/// Só existe a variante `WidgetRef`: o desvio de material da playlist roda
/// dentro de um `ConsumerState`, e `Ref`/`WidgetRef` não têm supertipo público
/// no Riverpod 3 — a gêmea com `Ref` ficou sem chamador e saiu.
Future<CatalogMaterial?> resolveCatalogMaterialFromWidget(
  WidgetRef ref,
  String materialId,
) {
  return ref.read(catalogSourceProvider).materialById(materialId);
}
