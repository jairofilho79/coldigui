import 'dart:typed_data';

/// Item para upsert em lote no índice offline (Fase 3.5).
class OfflinePdfBatchItem {
  const OfflinePdfBatchItem({
    required this.pdfId,
    required this.bytes,
    required this.category,
  });

  final String pdfId;
  final Uint8List bytes;
  final String category;
}

/// PDF extraído do ZIP — bytes prontos para indexação no isolate principal.
class ExtractedPdfItem {
  const ExtractedPdfItem({
    required this.pdfId,
    required this.absolutePath,
    required this.fileSize,
  });

  final String pdfId;
  final String absolutePath;
  final int fileSize;
}

/// Resultado da extração de um pacote ZIP.
class ExtractResult {
  const ExtractResult({
    required this.storedCount,
    required this.skippedCount,
    required this.totalInZip,
    this.unmatchedPdfIds = const [],
    this.failedPdfIds = const [],
  });

  final int storedCount;
  final int skippedCount;
  final int totalInZip;

  /// Entradas PDF no ZIP sem correspondência no manifest.
  final List<String> unmatchedPdfIds;

  /// pdfIds esperados cujo conteúdo não pôde ser gravado ou validado.
  final List<String> failedPdfIds;
}
