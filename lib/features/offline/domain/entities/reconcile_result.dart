/// Resultado de [ReconcileOfflineIndex] (Fase 3.5 mínimo / 3.6 completo).
class ReconcileResult {
  const ReconcileResult({
    required this.removedFromIndex,
    required this.orphanFiles,
  });

  final int removedFromIndex;
  final int orphanFiles;
}
