import '../entities/louvor.dart';
import '../entities/louvor_group.dart';

/// Agrupa louvores filtrados por `groupId` — ver [LOUVOR_GROUPING.md].
class GroupLouvoresByMaterial {
  const GroupLouvoresByMaterial();

  /// Retorna grupos ordenados por número (numérico) e desempate por nome.
  List<LouvorGroup> call(List<Louvor> louvores) =>
      LouvorGroup.fromLouvores(louvores);
}
