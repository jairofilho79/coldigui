import '../utils/louvor_classification.dart';
import 'louvor.dart';

/// Snapshot do manifest carregado com metadados derivados pré-computados.
///
/// [availableArranjos] é calculado uma vez em [fromLouvores] para evitar varrer
/// ~4600 louvores no thread principal a cada rebuild de filtros UC-02.
class LouvoresManifest {
  const LouvoresManifest({
    required this.louvores,
    required this.availableArranjos,
    this.isStale = false,
  });

  final List<Louvor> louvores;
  final Set<String> availableArranjos;

  /// `true` se o catálogo nunca foi sincronizado ou está há >7 dias sem sync.
  final bool isStale;

  factory LouvoresManifest.fromLouvores(
    List<Louvor> louvores, {
    bool isStale = false,
  }) {
    return LouvoresManifest(
      louvores: louvores,
      availableArranjos:
          LouvorClassification.collectAvailableArranjos(louvores),
      isStale: isStale,
    );
  }
}
