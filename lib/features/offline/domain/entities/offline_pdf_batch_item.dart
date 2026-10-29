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
