/// PDF indexado mas arquivo removido do disco; fetch offline falhou (Fase 3.2).
class PdfExternallyDeletedException implements Exception {
  const PdfExternallyDeletedException({
    required this.pdfId,
    this.canRetryWhenOnline = true,
    this.message = 'O PDF foi removido do dispositivo. '
        'Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.',
  });

  final String pdfId;
  final bool canRetryWhenOnline;
  final String message;

  @override
  String toString() => 'PdfExternallyDeletedException: $message';
}

/// PDF nunca cacheado e fetch offline falhou (Fase 3.2).
class PdfOfflineUnavailableException implements Exception {
  const PdfOfflineUnavailableException({
    required this.pdfId,
    this.message = 'Este PDF não foi baixado para uso offline. '
        'Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.',
  });

  final String pdfId;
  final String message;

  @override
  String toString() => 'PdfOfflineUnavailableException: $message';
}

/// PDF em cache local passou validação de disco mas falhou ao abrir no leitor.
class PdfLocalCorruptedException implements Exception {
  const PdfLocalCorruptedException({
    required this.pdfId,
    this.message =
        'O PDF salvo no dispositivo está corrompido. Baixe novamente para continuar.',
  });

  final String pdfId;
  final String message;

  @override
  String toString() => 'PdfLocalCorruptedException: $message';
}

/// Fetch falhou por motivo diferente de indisponibilidade de rede (Fase 3.2).
class PdfFetchFailedException implements Exception {
  const PdfFetchFailedException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PdfFetchFailedException: $message';
}
