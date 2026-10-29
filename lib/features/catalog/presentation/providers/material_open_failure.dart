import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../../pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';

/// Falha de abertura já classificada pela escada única.
///
/// [message] é a mensagem própria da exceção — `null` quando o erro não tem uma
/// e a tela deve mostrar o texto genérico. [stage] é o rótulo usado nos logs de
/// diagnóstico da playlist; [logWithStack] diz se o log deve levar o stack
/// trace (falhas de I/O) ou só o detalhe.
class MaterialOpenFailure {
  const MaterialOpenFailure({
    required this.stage,
    required this.message,
    required this.logWithStack,
  });

  final String stage;
  final String? message;
  final bool logWithStack;
}

/// Escada única de exceções de abertura de material.
///
/// Mesma ordem que vivia duplicada em `openCarouselPdfInReader` e em
/// `PlaylistListTile._openPdfInReader`. [genericStage] nomeia o caso final nos
/// logs de quem chama.
///
/// Mora num arquivo próprio (e não em `open_material_provider.dart`) porque
/// `userMessageFor` a reusa: importar o provider de volta fechava o ciclo
/// `user_message_for → open_material_provider → open_louvor_in_reader →
/// user_message_for`. Aqui só entram exceções — nada de Flutter nem Riverpod —,
/// então os dois lados importam sem se enxergar.
MaterialOpenFailure classifyMaterialOpenFailure(
  Object error, {
  String genericStage = 'abrir material',
}) {
  return switch (error) {
    InvalidPdfPathException() => const MaterialOpenFailure(
      stage: 'caminho PDF inválido',
      message: null,
      logWithStack: true,
    ),
    PdfOfflineUnavailableException(:final message) => MaterialOpenFailure(
      stage: 'PDF offline indisponível',
      message: message,
      logWithStack: false,
    ),
    // Sem `message`: as duas exceções abaixo não carregam mais literal PT, e o
    // texto sai de `userMessageFor` (chaves `pdfExternallyDeleted` /
    // `pdfLocalCorrupted`). O `stage` continua nomeando o caso nos logs.
    PdfExternallyDeletedException() => const MaterialOpenFailure(
      stage: 'PDF removido externamente',
      message: null,
      logWithStack: false,
    ),
    PdfLocalCorruptedException() => const MaterialOpenFailure(
      stage: 'PDF local corrompido',
      message: null,
      logWithStack: false,
    ),
    PdfFetchFailedException(:final message) => MaterialOpenFailure(
      stage: 'falha ao baixar PDF',
      message: message,
      logWithStack: true,
    ),
    _ => MaterialOpenFailure(
      stage: genericStage,
      message: null,
      logWithStack: true,
    ),
  };
}
