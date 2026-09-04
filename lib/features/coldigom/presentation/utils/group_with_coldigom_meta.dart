import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor_group.dart';
import '../../data/providers/coldigom_providers.dart';

/// Anexa a [ColdigomPraiseMetadata] em cache ao [group], quando ela falta.
///
/// Substitui os dois ramos `isColdigom` que o card e a troca de material
/// repetiam: quem não é Coldigom simplesmente não tem entrada no cache de
/// metadados, então a checagem por acervo era só um atalho.
///
/// Só lê o cache — nunca busca na rede. Um praise cujo detalhe ainda não foi
/// carregado abre o sheet sem o cabeçalho de metadados, como antes.
Future<LouvorGroup> groupWithColdigomMeta(
  WidgetRef ref,
  LouvorGroup group,
) async {
  if (group.coldigomMeta != null) return group;
  final meta = ref.read(coldigomPraiseMetaCacheProvider)[group.groupId];
  if (meta == null) return group;
  return group.withColdigomMeta(meta);
}
