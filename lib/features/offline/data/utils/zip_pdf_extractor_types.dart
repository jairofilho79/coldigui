import 'dart:typed_data';

import '../../domain/entities/offline_pdf_batch_item.dart';

/// Intervalo de reporte de progresso durante extração em isolate (backlog #5).
const zipExtractProgressInterval = 25;

/// Parâmetros serializáveis para extração em isolate (`compute`).
class ZipExtractParams {
  const ZipExtractParams({
    required this.zipPath,
    required this.rootPath,
    required this.expectedPdfIds,
    required this.skipPdfIds,
    this.zipBytes,
  });

  final String zipPath;
  final String rootPath;
  final List<String> expectedPdfIds;
  final List<String> skipPdfIds;

  /// Conteúdo ZIP em memória — obrigatório na web; omitido no nativo.
  final Uint8List? zipBytes;
}

/// Progresso emitido pelo isolate a cada [zipExtractProgressInterval] PDFs.
class ZipExtractProgressReport {
  const ZipExtractProgressReport({
    required this.extracted,
    required this.total,
  });

  final int extracted;
  final int total;
}

/// Resultado serializável da extração em isolate.
class ZipExtractResult {
  const ZipExtractResult({
    required this.items,
    required this.unmatchedEntries,
    this.failedPdfIds = const [],
  });

  final List<ExtractedPdfItem> items;

  /// Nomes relativos de entradas PDF no ZIP sem pdfId no manifest.
  final List<String> unmatchedEntries;

  /// pdfIds esperados cujo conteúdo não pôde ser gravado ou validado.
  final List<String> failedPdfIds;
}

/// Resultado de [persistExtractedItems] — itens prontos para indexação Isar.
class PersistExtractedOutcome {
  const PersistExtractedOutcome({
    required this.items,
    this.failedPdfIds = const [],
  });

  final List<ExtractedPdfItem> items;
  final List<String> failedPdfIds;
}
