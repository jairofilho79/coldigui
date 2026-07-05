/// Entrada serializável para validação de paths em isolate (Fase 3.6).
class ReconcilePathEntry {
  const ReconcilePathEntry({required this.pdfId, required this.absolutePath});

  final String pdfId;

  /// Path absoluto (nativo) ou chave de storage OPFS (web).
  final String absolutePath;
}

/// Resultado da validação de um chunk de paths.
class ReconcilePathValidationResult {
  const ReconcilePathValidationResult({
    required this.invalidPdfIds,
    required this.validAbsolutePaths,
  });

  final List<String> invalidPdfIds;
  final List<String> validAbsolutePaths;
}
