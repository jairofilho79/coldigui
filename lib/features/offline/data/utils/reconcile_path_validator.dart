import 'dart:io';

/// Entrada serializável para validação de paths em isolate (Fase 3.6).
class ReconcilePathEntry {
  const ReconcilePathEntry({
    required this.pdfId,
    required this.absolutePath,
  });

  final String pdfId;
  final String absolutePath;
}

/// Resultado da validação de um chunk de paths no isolate.
class ReconcilePathValidationResult {
  const ReconcilePathValidationResult({
    required this.invalidPdfIds,
    required this.validAbsolutePaths,
  });

  final List<String> invalidPdfIds;
  final List<String> validAbsolutePaths;
}

/// Valida existência e tamanho > 0 de PDFs no disco — top-level para [compute].
ReconcilePathValidationResult validatePdfPathsChunk(
  List<ReconcilePathEntry> entries,
) {
  final invalidPdfIds = <String>[];
  final validAbsolutePaths = <String>[];

  for (final entry in entries) {
    final file = File(entry.absolutePath);
    final valid = file.existsSync() && file.lengthSync() > 0;
    if (valid) {
      validAbsolutePaths.add(entry.absolutePath);
    } else {
      invalidPdfIds.add(entry.pdfId);
    }
  }

  return ReconcilePathValidationResult(
    invalidPdfIds: invalidPdfIds,
    validAbsolutePaths: validAbsolutePaths,
  );
}
