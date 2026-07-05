import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../../core/utils/url_sync_params.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../data/adapters/pdfrx_viewer_adapter.dart';
import '../../data/models/pdf_reader_viewer_handle.dart';
import '../../data/providers/pdf_reader_viewer_providers.dart';
import '../../data/utils/pdf_source_resolver.dart';
import '../../domain/exceptions/invalid_pdf_path_exception.dart';
import '../../domain/usecases/open_pdf_document.dart';
import 'pdf_session_cache.dart';

/// Sessão PDF aberta no leitor — handle pdfrx + metadados (UC-11 Fase 2.2).
///
/// O [PdfReaderViewerHandle] pode ser reutilizado via [PdfSessionCache] ao trocar
/// PDF no carousel; descartado ao sair de `/leitor` (cache limpo).
class PdfReaderSession {
  const PdfReaderSession({
    required this.handle,
    required this.filePath,
    this.fromCache = false,
  });

  /// Handle ativo para [PdfReaderPdfView].
  final PdfReaderViewerHandle handle;

  /// Valor bruto do query param [UrlSyncParams.file].
  final String filePath;

  /// `true` quando o handle veio do [PdfSessionCache] (LRU).
  final bool fromCache;
}

/// Abre documento PDF para a rota `/leitor` (UC-11 Fase 2.2).
///
/// `autoDispose.family` — sessão por [filePath]; ao trocar no carousel o
/// handle vai para [PdfSessionCache] (LRU) em vez de ser descartado.
/// Ao sair de `/leitor`, o cache é limpo e todos os handles são liberados.
///
/// Valida via [OpenPdfDocument], delega renderização a [PdfrxViewerAdapter].
final pdfReaderSessionProvider = FutureProvider.autoDispose
    .family<PdfReaderSession, String>((ref, filePath) async {
      final openPdf = ref.watch(openPdfDocumentProvider);
      final adapter = ref.watch(pdfViewerAdapterProvider);
      final cache = ref.watch(pdfSessionCacheProvider);
      const resolver = PdfSourceResolver();

      openPdf.validateFilePath(filePath);
      final source = resolver.resolve(filePath);

      var handle = cache.acquire(filePath);
      final fromCache = handle != null;
      try {
        if (handle == null) {
          handle = await adapter.openDocument(filePath);
          if (source.kind == PdfSourceKind.localFile) {
            // Garante documento válido antes de exibir (detecta corrupção cedo).
            if (handle.document.pages.isEmpty) {
              throw StateError('PDF sem páginas');
            }
          }
        }
      } on Object catch (_) {
        handle?.dispose();
        cache.remove(filePath);
        if (source.kind == PdfSourceKind.localFile) {
          final pdfId = await _removeCorruptedLocalPdf(ref, source.value);
          if (pdfId != null) {
            throw PdfLocalCorruptedException(pdfId: pdfId);
          }
        }
        rethrow;
      }

      final sessionHandle = handle;
      adapter.bindHandle(sessionHandle);

      ref.onDispose(() {
        adapter.unbindHandle(sessionHandle);
        cache.release(filePath, sessionHandle);
      });

      return PdfReaderSession(
        handle: sessionHandle,
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

/// Desembrulha [ProviderException] (Riverpod 3) para mensagens e handlers de erro.
Object unwrapProviderError(Object error) {
  if (error is ProviderException) return error.exception;
  return error;
}

/// Mensagem amigável para erros de abertura PDF na UI.
String pdfReaderErrorMessage(Object error) {
  error = unwrapProviderError(error);
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
