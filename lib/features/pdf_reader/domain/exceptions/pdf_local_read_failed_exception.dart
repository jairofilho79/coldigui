/// Leitura de PDF local falhou sem evidência de corrupção (UC-11 B3).
///
/// Diferente de [PdfLocalCorruptedException] (offline domain), esta exceção
/// **não** implica remoção do arquivo local: cobre falhas de storage,
/// timeout ou `StateError` genérico onde não há evidência de que o arquivo
/// em si esteja corrompido (bytes ausentes/erro de leitura). A UI existente
/// do leitor trata pelo fallback genérico com retry via
/// `ref.invalidate(pdfReaderSessionProvider)`.
class PdfLocalReadFailedException implements Exception {
  const PdfLocalReadFailedException({required this.pdfId});

  /// Identificador do PDF na tabela offline.
  final String pdfId;

  /// Sem `message` em PT (E8 fix round 1): o texto do usuário sai da chave
  /// l10n `pdfLocalReadFailedMessage` (`lib/l10n/app_pt.arb` / `app_en.arb`),
  /// lida por quem tem `context`; sem `context`, `pdfReaderErrorMessage`
  /// cai no fallback genérico.
  @override
  String toString() => 'PdfLocalReadFailedException($pdfId)';
}
