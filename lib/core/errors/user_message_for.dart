import 'package:dio/dio.dart';

import '../../features/auth/data/auth_remote_datasource.dart';
import '../../features/catalog/presentation/providers/open_material_provider.dart';
import '../../l10n/app_localizations.dart';
import '../database/storage_unavailable_exception.dart';

/// Mensagem traduzida para qualquer erro que chegue à UI.
///
/// Ponto único: nada de `'Erro: $e'` — `toString()` de exceção é detalhe de
/// implementação (e às vezes vaza URL/token). O que não for classificável cai
/// em [AppLocalizations.errorGeneric].
///
/// Reusa a escada de PDF já existente ([classifyMaterialOpenFailure]) em vez de
/// criar uma quarta lista de casos.
String userMessageFor(AppLocalizations l10n, Object error) {
  if (error is DioException) return _dioMessage(l10n, error);
  if (error is StorageUnavailableException) {
    return l10n.offlineStorageUnavailable;
  }
  if (error is AuthUnauthorizedException) return l10n.errorSessionExpired;

  // Exceções de PDF já carregam mensagem própria voltada ao usuário.
  final pdfMessage = classifyMaterialOpenFailure(error).message;
  if (pdfMessage != null) return pdfMessage;

  return l10n.errorGeneric;
}

String _dioMessage(AppLocalizations l10n, DioException error) {
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
      return l10n.errorGeneric;
    default:
      // cancel/badCertificate/transformTimeout/unknown não têm mensagem útil.
      return l10n.errorGeneric;
  }
}
