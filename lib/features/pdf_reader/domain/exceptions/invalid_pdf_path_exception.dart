/// Caminho PDF rejeitado pela validação UC-11 (Fase 2.2).
class InvalidPdfPathException implements Exception {
  const InvalidPdfPathException(this.reason);

  /// Motivo técnico da rejeição — só para logs/diagnóstico via [toString].
  ///
  /// Sem `message` em PT (E8 fix round 1): o texto do usuário sai do
  /// fallback genérico de `pdfReaderErrorMessage` — nunca houve chave l10n
  /// própria para esta exceção.
  final String reason;

  @override
  String toString() => 'InvalidPdfPathException: $reason';
}
