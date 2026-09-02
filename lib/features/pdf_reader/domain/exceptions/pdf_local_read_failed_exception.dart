/// Leitura de PDF local falhou sem evidência de corrupção (UC-11 B3).
///
/// Diferente de [PdfLocalCorruptedException] (offline domain), esta exceção
/// **não** implica remoção do arquivo local: cobre falhas de storage,
/// timeout ou `StateError` genérico onde não há evidência de que o arquivo
/// em si esteja corrompido (bytes ausentes/erro de leitura). A UI existente
/// do leitor trata pelo fallback genérico com retry via
/// `ref.invalidate(pdfReaderSessionProvider)`.
class PdfLocalReadFailedException implements Exception {
  const PdfLocalReadFailedException({
    required this.pdfId,
    this.message = 'Não foi possível ler o arquivo. Tente novamente.',
  });

  /// Identificador do PDF na tabela offline.
  final String pdfId;

  /// Mensagem amigável exibida na UI — ver `pdfLocalReadFailedMessage`
  /// em `lib/l10n/app_pt.arb` / `app_en.arb`.
  final String message;

  @override
  String toString() => 'PdfLocalReadFailedException: $message';
}
