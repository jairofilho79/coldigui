import '../../l10n/app_localizations.dart';
import '../failures/app_failure.dart';

/// Texto do usuário para um [AppFailure] (E8) — ponto único de mensagens
/// para os catches de `pdf_reader`/`offline` migrados nesta onda.
String failureMessage(AppLocalizations l10n, AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.failureNetwork,
    OfflineFailure() => l10n.failureOffline,
    NotFoundFailure() => l10n.failureNotFound,
    StorageFailure() => l10n.failureStorage,
    AuthFailure() => l10n.failureAuth,
    ConflictFailure() => l10n.failureConflict,
    UnknownFailure() => l10n.failureUnknown,
  };
}
