import 'package:dio/dio.dart';

import '../../features/auth/data/auth_remote_datasource.dart';
import '../../features/catalog/presentation/providers/open_material_provider.dart';
import '../../features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../features/pdf_reader/domain/exceptions/pdf_local_open_failure.dart';
import '../../features/pdf_reader/domain/exceptions/pdf_local_read_failed_exception.dart';
import '../../l10n/app_localizations.dart';
import '../database/storage_unavailable_exception.dart';

/// Mensagem traduzida para qualquer erro que chegue à UI.
///
/// Ponto único: nada de `'Erro: $e'` — `toString()` de exceção é detalhe de
/// implementação (e às vezes vaza URL/token). O que não for classificável cai
/// em [AppLocalizations.errorGeneric].
String userMessageFor(AppLocalizations l10n, Object error) {
  final direct = _classify(l10n, error);
  if (direct != null) return direct;

  // Exceções de domínio embrulham o erro real: "Falha ao baixar o PDF" com uma
  // `DioException` dentro é, para o usuário, falta de conexão.
  final cause = _causeOf(error);
  if (cause != null) {
    final fromCause = _classify(l10n, cause);
    if (fromCause != null) return fromCause;
  }

  return _pdfMessage(l10n, error) ?? l10n.errorGeneric;
}

/// Erros que já se traduzem sozinhos, sem olhar causa.
String? _classify(AppLocalizations l10n, Object error) {
  if (error is DioException) return _dioMessage(l10n, error);
  if (error is StorageUnavailableException) {
    return l10n.offlineStorageUnavailable;
  }
  if (error is AuthUnauthorizedException) return l10n.errorSessionExpired;
  return null;
}

/// Erro original guardado por exceções que embrulham outro.
Object? _causeOf(Object error) => switch (error) {
  PdfFetchFailedException(:final cause) => cause,
  PdfLocalOpenFailure(:final cause) => cause,
  _ => null,
};

/// Família PDF: chave l10n quando existe; senão a mensagem da própria exceção.
///
/// A escada de casos é a que já existia ([classifyMaterialOpenFailure]) — não
/// vale criar uma quarta. O que muda aqui é preferir texto traduzido ao literal
/// PT embutido na exceção, para o app em inglês não mostrar português.
String? _pdfMessage(AppLocalizations l10n, Object error) => switch (error) {
  PdfOfflineUnavailableException() => l10n.pdfOfflineUnavailableMessage,
  PdfLocalReadFailedException() => l10n.pdfLocalReadFailedMessage,
  _ => classifyMaterialOpenFailure(error).message,
};

/// `null` quando o `DioException` não diz nada além de "deu ruim".
///
/// Devolver [AppLocalizations.errorGeneric] aqui fazia a causa embrulhada
/// vencer o wrapper: `PdfFetchFailedException(cause: 404)` mostrava o texto
/// genérico em vez de "Falha ao baixar o PDF". Com `null`, a cadeia de
/// [userMessageFor] segue para `_pdfMessage` e só cai no genérico no fim.
String? _dioMessage(AppLocalizations l10n, DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return l10n.errorTimeout;
    case DioExceptionType.connectionError:
      return l10n.errorNoConnection;
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 401 || status == 403) return l10n.errorSessionExpired;
      if (status >= 500) return l10n.errorServer;
      return null;
    default:
      // cancel/badCertificate/transformTimeout/unknown não têm mensagem útil.
      return null;
  }
}
