import 'package:flutter/foundation.dart';

import '../../domain/ports/pdf_storage_port.dart';
import 'pdf_integrity_validator.dart';
import 'reconcile_path_validator.dart';

/// Valida existência e magic bytes `%PDF` — top-level para [compute] (nativo).
ReconcilePathValidationResult validatePdfPathsChunk(
  List<ReconcilePathEntry> entries,
) {
  final invalidPdfIds = <String>[];
  final validAbsolutePaths = <String>[];

  for (final entry in entries) {
    if (PdfIntegrityValidator.isValidPdfFileSync(entry.absolutePath)) {
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

Future<ReconcilePathValidationResult> validateReconcilePathChunk(
  List<ReconcilePathEntry> entries,
  PdfStoragePort store,
) => compute(validatePdfPathsChunk, entries);
