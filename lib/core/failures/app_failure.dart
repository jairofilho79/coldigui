import 'dart:io';

import 'package:dio/dio.dart';

import '../../features/audio_flags/domain/entities/remote_audio_flag.dart';
import '../../features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import '../../features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../features/playlists/domain/entities/remote_playlist.dart';
import '../../features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import '../database/storage_unavailable_exception.dart';

/// Falha classificada — ponto único para decidir a categoria de um erro que
/// chega à presentation (E8).
///
/// [AppFailure.from] mapeia exceções de domínio concretas numa das sete
/// categorias abaixo; `failureMessage` (`core/l10n/failure_message.dart`)
/// traduz cada categoria para o texto do usuário. [cause] é o erro original
/// — mantido para logs/diagnóstico, nunca exibido cru na UI.
///
/// Migração desta onda (E8): catches de `pdf_reader`/`offline` presentation.
/// A classificação também cobre exceções de outras features (ex.:
/// `PlaylistNotFoundException`, `PlaylistConflictException`,
/// `AudioFlagConflictException`) para que elas possam migrar depois sem
/// alterar este arquivo de novo — seus catch sites continuam com a mensagem
/// atual por enquanto.
sealed class AppFailure {
  const AppFailure(this.cause);

  /// Erro original que originou esta falha.
  final Object cause;

  /// Classifica [error] numa das sete categorias de [AppFailure].
  ///
  /// `DioException`: sem `response` (timeout, sem conexão, cancelado) vira
  /// [NetworkFailure]; `statusCode` 401/403 vira [AuthFailure]; 404 vira
  /// [NotFoundFailure]; 409 vira [ConflictFailure]; qualquer outro (5xx
  /// incluso) cai em [UnknownFailure] — ver `userMessageFor` para uma
  /// classificação mais fina de 5xx/timeout quando isso for migrado.
  factory AppFailure.from(Object error) {
    if (error is DioException) return _fromDio(error);
    if (error is SocketException) return NetworkFailure(error);
    if (error is PdfOfflineUnavailableException) return OfflineFailure(error);
    if (error is PdfExternallyDeletedException) return NotFoundFailure(error);
    if (error is PlaylistNotFoundException) return NotFoundFailure(error);
    if (error is StorageUnavailableException) return StorageFailure(error);
    if (error is PdfStorageWriteException) return StorageFailure(error);
    if (error is InsufficientDiskSpaceException) return StorageFailure(error);
    if (error is PdfLocalCorruptedException) return StorageFailure(error);
    if (error is PlaylistConflictException) return ConflictFailure(error);
    if (error is AudioFlagConflictException) return ConflictFailure(error);
    return UnknownFailure(error);
  }

  static AppFailure _fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == null) return NetworkFailure(error);
    if (statusCode == 401 || statusCode == 403) return AuthFailure(error);
    if (statusCode == 404) return NotFoundFailure(error);
    if (statusCode == 409) return ConflictFailure(error);
    return UnknownFailure(error);
  }
}

/// Sem conexão, ou o servidor não respondeu — `DioException` sem `response`,
/// `SocketException`.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.cause);
}

/// Recurso não baixado para uso offline — `PdfOfflineUnavailableException`.
final class OfflineFailure extends AppFailure {
  const OfflineFailure(super.cause);
}

/// Recurso não encontrado — HTTP 404, `PlaylistNotFoundException`,
/// `PdfExternallyDeletedException`.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.cause);
}

/// Falha de armazenamento local — `StorageUnavailableException`,
/// `PdfStorageWriteException`, `InsufficientDiskSpaceException`,
/// `PdfLocalCorruptedException`.
final class StorageFailure extends AppFailure {
  const StorageFailure(super.cause);
}

/// Sessão expirada ou sem permissão — HTTP 401/403.
final class AuthFailure extends AppFailure {
  const AuthFailure(super.cause);
}

/// Conflito de sincronização — HTTP 409, `PlaylistConflictException`,
/// `AudioFlagConflictException`.
final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.cause);
}

/// Qualquer erro não classificado nas categorias acima.
final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.cause);
}
