/// Página fora do intervalo válido do documento PDF (UC-11 Fase 2.3).
class InvalidPdfPageException implements Exception {
  const InvalidPdfPageException(this.message);

  final String message;

  @override
  String toString() => 'InvalidPdfPageException: $message';
}
