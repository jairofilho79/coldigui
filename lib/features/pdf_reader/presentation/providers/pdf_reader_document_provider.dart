import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/utils/url_sync_params.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../data/adapters/pdfx_viewer_adapter.dart';
import '../../data/providers/pdf_reader_providers.dart';
import '../../data/utils/pdf_source_resolver.dart';
import '../../domain/exceptions/invalid_pdf_path_exception.dart';
import '../../domain/usecases/open_pdf_document.dart';

/// Sessão PDF aberta no leitor — controller PDFx + metadados (UC-11 Fase 2.2).
///
/// Uma instância por visita a `/leitor`; o [PdfControllerPinch] é descartado
/// quando [pdfReaderSessionProvider] faz autoDispose ao sair da rota.
class PdfReaderSession {
  const PdfReaderSession({
    required this.controller,
    required this.filePath,
  });

  /// Controller PDFx ativo para [PdfxPdfView].
  final PdfControllerPinch controller;

  /// Valor bruto do query param [UrlSyncParams.file].
  final String filePath;
}

/// Abre documento PDF para a rota `/leitor` (UC-11 Fase 2.2).
///
/// `autoDispose.family` — cada visita ao leitor cria sessão e controller novos;
/// ao sair, `ref.onDispose` libera o controller (evita reutilização PDFx).
///
/// Valida via [OpenPdfDocument], delega renderização a [PdfxViewerAdapter].
final pdfReaderSessionProvider = FutureProvider.autoDispose
    .family<PdfReaderSession, String>((ref, filePath) async {
  final openPdf = ref.watch(openPdfDocumentProvider);
  final adapter = ref.watch(pdfxViewerAdapterProvider);
  const resolver = PdfSourceResolver();

  openPdf.validateFilePath(filePath);
  final source = resolver.resolve(filePath);

  PdfControllerPinch? controller;
  try {
    controller = await adapter.openDocument(filePath);
    if (source.kind == PdfSourceKind.localFile) {
      await controller.document;
    }
  } on Object catch (_) {
    controller?.dispose();
    if (source.kind == PdfSourceKind.localFile) {
      final pdfId = await _removeCorruptedLocalPdf(ref, source.value);
      if (pdfId != null) {
        throw PdfLocalCorruptedException(pdfId: pdfId);
      }
    }
    rethrow;
  }

  adapter.bindController(controller);

  ref.onDispose(() {
    adapter.unbindController(controller!);
    controller.dispose();
  });

  return PdfReaderSession(
    controller: controller,
    filePath: filePath,
  );
});

Future<String?> _removeCorruptedLocalPdf(Ref ref, String absolutePath) async {
  final repository = ref.read(offlinePdfRepositoryProvider);
  final pdfId = await repository.findPdfIdByAbsolutePath(absolutePath);
  if (pdfId == null) return null;
  await repository.remove(pdfId);
  return pdfId;
}

/// Mensagem amigável para erros de abertura PDF na UI.
///
/// Suporta [InvalidPdfPathException] e exceções offline ([PdfOfflineUnavailableException],
/// [PdfExternallyDeletedException], [PdfFetchFailedException], [PdfLocalCorruptedException]);
/// fallback genérico.
String pdfReaderErrorMessage(Object error) {
  if (error is InvalidPdfPathException) {
    return error.message;
  }
  if (error is PdfOfflineUnavailableException) {
    return error.message;
  }
  if (error is PdfExternallyDeletedException) {
    return error.message;
  }
  if (error is PdfFetchFailedException) {
    return error.message;
  }
  if (error is PdfLocalCorruptedException) {
    return error.message;
  }
  return 'Não foi possível abrir o PDF';
}
