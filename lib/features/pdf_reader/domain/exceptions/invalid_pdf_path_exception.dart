/// Caminho PDF rejeitado pela validação UC-11 (Fase 2.2).
class InvalidPdfPathException implements Exception {
  const InvalidPdfPathException(this.message);

  /// Descrição exibida na UI via [pdfReaderErrorMessage].
  final String message;

  @override
  String toString() => 'InvalidPdfPathException: $message';
}
