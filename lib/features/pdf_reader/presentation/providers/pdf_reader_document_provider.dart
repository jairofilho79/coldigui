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
import '../../domain/exceptions/pdf_local_open_failure.dart';
import '../../domain/exceptions/pdf_local_read_failed_exception.dart';
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
///
/// O retry automático do Riverpod 3 fica **desligado de propósito**
/// (`retry: (_, _) => null`) para todos os erros, inclusive os de rede: um erro
/// imediato somado ao botão manual "Tentar novamente" da tela do leitor é
/// melhor do que ~38 s de spinner enquanto o framework tenta de novo em
/// backoff exponencial.
final pdfReaderSessionProvider = FutureProvider.autoDispose
    .family<PdfReaderSession, String>(
      (ref, filePath) async {
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
        } on Object catch (error, stackTrace) {
          handle?.dispose();
          cache.remove(filePath);
          // O adapter embrulha a falha de abertura em [PdfLocalOpenFailure]
          // com o veredito do magic `%PDF` sobre os bytes que ele leu; se a
          // leitura em si falhou, o erro chega cru e não há evidência.
          final openFailure = error is PdfLocalOpenFailure ? error : null;
          final cause = openFailure?.cause ?? error;
          if (source.kind == PdfSourceKind.localFile) {
            final failureKind = classifyPdfOpenFailure(
              cause,
              hasValidMagicBytes: openFailure?.hasValidMagicBytes,
            );
            if (failureKind == PdfOpenFailureKind.corrupted) {
              final pdfId = await _removeCorruptedLocalPdf(ref, source.value);
              if (pdfId != null) {
                throw PdfLocalCorruptedException(pdfId: pdfId);
              }
            } else {
              final pdfId = await _findLocalPdfId(ref, source.value);
              if (pdfId != null) {
                throw PdfLocalReadFailedException(pdfId: pdfId);
              }
            }
          }
          // Sempre propaga o erro ORIGINAL (não o wrapper interno).
          Error.throwWithStackTrace(cause, stackTrace);
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
      },
      // Desliga o retry automático do Riverpod 3 (backoff exponencial, até
      // 10 tentativas — ver `ProviderContainer.defaultRetry`): os erros deste
      // provider (PDF inválido/corrompido/indisponível/etc.) são estados de
      // UI definitivos com retry MANUAL explícito (botão na tela do leitor),
      // não falhas transitórias — sem isso, o usuário veria o loading por
      // até ~30s antes do erro aparecer.
      retry: (_, _) => null,
    );

Future<String?> _findLocalPdfId(Ref ref, String absolutePath) {
  final repository = ref.read(offlinePdfRepositoryProvider);
  return repository.findPdfIdByAbsolutePath(absolutePath);
}

Future<String?> _removeCorruptedLocalPdf(Ref ref, String absolutePath) async {
  final pdfId = await _findLocalPdfId(ref, absolutePath);
  if (pdfId == null) return null;
  await ref.read(offlinePdfRepositoryProvider).remove(pdfId);
  return pdfId;
}

/// Resultado de [classifyPdfOpenFailure] — decide se há evidência real de
/// corrupção do PDF local ou se a falha deve apenas ser reportada (B3).
enum PdfOpenFailureKind {
  /// Evidência de corrupção — o arquivo local deve ser removido/re-baixado.
  corrupted,

  /// Falha sem evidência de corrupção — o arquivo local é preservado.
  readFailed,
}

/// Mensagens que o pdfrx emite ao falhar por documento malformado.
const _pdfrxFormatErrorPatterns = [
  'FPDF_ERR_FORMAT',
  'Failed to open document',
];

/// Classifica a falha ao abrir um PDF local (UC-11 B3): evita apagar o PDF
/// offline por erro genérico.
///
/// [hasValidMagicBytes] vem de [PdfLocalOpenFailure] (produzido pelo
/// [PdfrxViewerAdapter] a partir dos bytes que ele leu): `null` quando os
/// bytes do arquivo não puderam ser lidos (arquivo ausente, permissão negada,
/// erro de storage); `true`/`false` quando os bytes foram lidos com sucesso e
/// avaliados contra o magic `%PDF`. Não depende de `dart:io` — o veredito é
/// idêntico na web e no nativo.
///
/// Só há [PdfOpenFailureKind.corrupted] quando: (a) os bytes existem e
/// falham no magic `%PDF`, ou (b) o pdfrx sinaliza explicitamente um erro de
/// formato (`FPDF_ERR_FORMAT` / "Failed to open document"). Qualquer outra
/// falha (bytes ausentes, exceção de storage, timeout, `StateError`
/// genérico) resulta em [PdfOpenFailureKind.readFailed] — o arquivo local
/// não é removido.
PdfOpenFailureKind classifyPdfOpenFailure(
  Object error, {
  required bool? hasValidMagicBytes,
}) {
  if (hasValidMagicBytes == false) {
    return PdfOpenFailureKind.corrupted;
  }
  final message = error.toString();
  final looksLikePdfrxFormatError = _pdfrxFormatErrorPatterns.any(
    message.contains,
  );
  if (looksLikePdfrxFormatError) {
    return PdfOpenFailureKind.corrupted;
  }
  return PdfOpenFailureKind.readFailed;
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
  if (error is PdfLocalReadFailedException) {
    return error.message;
  }
  return 'Não foi possível abrir o PDF';
}
