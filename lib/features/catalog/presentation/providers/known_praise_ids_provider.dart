import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';

/// Praises que o app já conhece localmente: o catálogo hidratado inteiro
/// ([ColdigomSearchIndex.catalogIds], inclui os que não entram na busca,
/// ex. só-YouTube).
///
/// É contra isto que a página inicial decide o chip «novo» e a adoção dos
/// «novos» da pesquisa remota (spec fim-fonte §2.4).
final knownPraiseIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(coldigomSearchIndexProvider).catalogIds;
});
