import '../entities/louvor.dart';
import '../entities/louvor_group.dart';

/// Agrupa louvores filtrados por `groupId` — ver [LOUVOR_GROUPING.md].
class GroupLouvoresByMaterial {
  const GroupLouvoresByMaterial();

  /// Agrupa por `groupId`. [sortByNumber] `true` (padrão) ordena por número;
  /// `false` preserva ordem de entrada (busca ranqueada).
  List<LouvorGroup> call(List<Louvor> louvores, {bool sortByNumber = true}) =>
      LouvorGroup.fromLouvores(louvores, sortByNumber: sortByNumber);
}
