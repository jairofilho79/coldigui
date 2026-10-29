import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../pdf_reader/domain/usecases/open_pdf_document.dart';
import '../datasources/pdf_bytes_datasource.dart';
import '../datasources/save_pdf_platform_impl.dart';
import '../../domain/usecases/open_pdf_in_reader.dart';
import '../../domain/usecases/save_pdf.dart';
import '../../domain/usecases/share_pdf.dart';

/// Datasource compartilhado para bytes PDF (UC-04 / UC-11).
final pdfBytesDatasourceProvider = Provider<PdfBytesDatasource>((ref) {
  return PdfBytesDatasource(ref.watch(dioProvider));
});

/// UC-04 — abrir PDF no leitor interno `/leitor` (Fase 2.1).
///
/// Injeta [OpenPdfDocument] para validação de path antes de montar a rota.
/// Consumido por [LouvorCard] ao tocar em um louvor.
final openPdfInReaderProvider = Provider<OpenPdfInReader>((ref) {
  return const OpenPdfInReader(OpenPdfDocument());
});

/// UC-04 — compartilhar PDF via share_plus.
final sharePdfProvider = Provider<SharePdf>((ref) {
  return SharePdf(
    ref.watch(pdfBytesDatasourceProvider),
    const OpenPdfDocument(),
  );
});

/// UC-04 — salvar PDF em documents/saved_pdfs/ (nativo) ou download (web).
final savePdfProvider = Provider<SavePdf>((ref) {
  return SavePdf(
    ref.watch(pdfBytesDatasourceProvider),
    const OpenPdfDocument(),
    createSavePdfPlatform(),
  );
});
