/// PDF indexado mas arquivo removido do disco; fetch offline falhou (Fase 3.2).
///
/// Sem `message`: o texto para o usuário sai de `AppLocalizations.
/// pdfExternallyDeleted` (via `userMessageFor`), senão o app em inglês mostrava
/// português (spec D.6).
class PdfExternallyDeletedException implements Exception {
  const PdfExternallyDeletedException({
    required this.pdfId,
    this.canRetryWhenOnline = true,
  });

  final String pdfId;
  final bool canRetryWhenOnline;

  @override
  String toString() => 'PdfExternallyDeletedException($pdfId)';
}

/// PDF nunca cacheado e fetch offline falhou (Fase 3.2).
class PdfOfflineUnavailableException implements Exception {
  const PdfOfflineUnavailableException({
    required this.pdfId,
    this.message =
        'Este PDF não foi baixado para uso offline. '
        'Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.',
  });

  final String pdfId;
  final String message;

  @override
  String toString() => 'PdfOfflineUnavailableException: $message';
}

/// PDF em cache local passou validação de disco mas falhou ao abrir no leitor.
///
/// Sem `message`: o texto para o usuário sai de `AppLocalizations.
/// pdfLocalCorrupted` (via `userMessageFor`), spec D.6.
class PdfLocalCorruptedException implements Exception {
  const PdfLocalCorruptedException({required this.pdfId});

  final String pdfId;

  @override
  String toString() => 'PdfLocalCorruptedException($pdfId)';
}

/// Fetch falhou por motivo diferente de indisponibilidade de rede (Fase 3.2).
class PdfFetchFailedException implements Exception {
  const PdfFetchFailedException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PdfFetchFailedException: $message';
}
