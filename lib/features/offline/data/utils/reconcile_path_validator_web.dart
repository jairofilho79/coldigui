import '../../domain/ports/pdf_storage_port.dart';
import 'pdf_integrity_validator.dart';
import 'reconcile_path_validator.dart';

/// Valida storage keys via [PdfStoragePort] — web-safe (sem `dart:io`).
Future<ReconcilePathValidationResult> validateReconcilePathChunk(
  List<ReconcilePathEntry> entries,
  PdfStoragePort store,
) async {
  final invalidPdfIds = <String>[];
  final validAbsolutePaths = <String>[];

  for (final entry in entries) {
    final header = await store.readBytes(entry.absolutePath, maxBytes: 4);
    if (header != null && PdfIntegrityValidator.hasValidPdfMagicBytes(header)) {
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
