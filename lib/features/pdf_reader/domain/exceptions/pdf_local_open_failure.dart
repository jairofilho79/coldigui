/// Falha ao abrir um PDF **local**, carregando a evidência de magic bytes
/// obtida a partir dos bytes que o adapter realmente leu (UC-11 B3).
///
/// Lançada pela camada de dados (`PdfrxViewerAdapter`) apenas quando os bytes
/// do arquivo foram lidos com sucesso e a abertura do documento falhou depois
/// disso — por isso [hasValidMagicBytes] é uma evidência confiável.
///
/// Contrato de [hasValidMagicBytes]:
/// - `true` — bytes lidos e começam com `%PDF`;
/// - `false` — bytes lidos e **não** começam com `%PDF` (corrupção real);
/// - `null` — a própria leitura falhou (permissão, storage, arquivo ausente,
///   plataforma sem acesso ao arquivo): **sem evidência**, o PDF local não
///   pode ser apagado.
///
/// Independe de plataforma: a leitura dos bytes já passa pelo datasource
/// com import condicional, então web e nativo produzem o mesmo veredito.
class PdfLocalOpenFailure implements Exception {
  const PdfLocalOpenFailure({
    required this.cause,
    required this.hasValidMagicBytes,
  });

  /// Erro original lançado ao abrir o documento (pdfrx, etc.).
  final Object cause;

  /// Veredito do magic `%PDF` sobre os bytes efetivamente lidos.
  final bool? hasValidMagicBytes;

  /// Delega ao erro original — mantém os padrões de mensagem do pdfrx
  /// (`FPDF_ERR_FORMAT`, "Failed to open document") visíveis para logs.
  @override
  String toString() => cause.toString();
}
