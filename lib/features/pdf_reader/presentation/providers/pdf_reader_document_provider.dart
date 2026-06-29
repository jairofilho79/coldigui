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
import 'pdf_session_cache.dart';

/// Sessão PDF aberta no leitor — controller PDFx + metadados (UC-11 Fase 2.2).
///
/// O [PdfControllerPinch] pode ser reutilizado via [PdfSessionCache] ao trocar
/// PDF no carousel; descartado ao sair de `/leitor` (cache limpo).
class PdfReaderSession {
  const PdfReaderSession({
    required this.controller,
    required this.filePath,
    this.fromCache = false,
  });

  /// Controller PDFx ativo para [PdfxPdfView].
  final PdfControllerPinch controller;

  /// Valor bruto do query param [UrlSyncParams.file].
  final String filePath;

  /// `true` quando o controller veio do [PdfSessionCache] (LRU).
  final bool fromCache;
}

/// Abre documento PDF para a rota `/leitor` (UC-11 Fase 2.2).
///
/// `autoDispose.family` — sessão por [filePath]; ao trocar no carousel o
/// controller vai para [PdfSessionCache] (LRU) em vez de ser descartado.
/// Ao sair de `/leitor`, o cache é limpo e todos os controllers são liberados.
///
/// Valida via [OpenPdfDocument], delega renderização a [PdfxViewerAdapter].
final pdfReaderSessionProvider = FutureProvider.autoDispose
    .family<PdfReaderSession, String>((ref, filePath) async {
  final openPdf = ref.watch(openPdfDocumentProvider);
  final adapter = ref.watch(pdfxViewerAdapterProvider);
  final cache = ref.watch(pdfSessionCacheProvider);
  const resolver = PdfSourceResolver();

  openPdf.validateFilePath(filePath);
  final source = resolver.resolve(filePath);

  var controller = cache.acquire(filePath);
  final fromCache = controller != null;
  try {
    if (controller == null) {
      controller = await adapter.openDocument(filePath);
      if (source.kind == PdfSourceKind.localFile) {
        await controller.document;
      }
    }
  } on Object catch (_) {
    controller?.dispose();
    cache.remove(filePath);
    if (source.kind == PdfSourceKind.localFile) {
      final pdfId = await _removeCorruptedLocalPdf(ref, source.value);
      if (pdfId != null) {
        throw PdfLocalCorruptedException(pdfId: pdfId);
      }
    }
    rethrow;
  }

  final sessionController = controller;
  adapter.bindController(sessionController);

  ref.onDispose(() {
    adapter.unbindController(sessionController);
    cache.release(filePath, sessionController);
  });

  return PdfReaderSession(
    controller: sessionController,
    filePath: filePath,
    fromCache: fromCache,
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
