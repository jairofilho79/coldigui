import '../exceptions/invalid_pdf_path_exception.dart';

/// UC-11 — Valida caminho PDF antes da abertura via PDFx (Fase 2.2).
///
/// [filePath] = URL HTTP remota, path relativo `/assets/...`, asset Flutter
/// (`asset:fixtures/sample.pdf`) ou path local absoluto.
/// A renderização é delegada a [PdfxViewerAdapter] na camada data (ADR-002).
class OpenPdfDocument {
  const OpenPdfDocument();

  static final RegExp _blockedSchemePattern = RegExp(
    r'^\s*(file|javascript|data):',
    caseSensitive: false,
  );

  /// Valida [filePath]; lança [InvalidPdfPathException] se inválido.
  ///
  /// Chamado antes de [PdfxViewerAdapter.openDocument].
  void validateFilePath(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) {
      throw const InvalidPdfPathException('Parâmetro file vazio');
    }
    if (trimmed.contains('..')) {
      throw const InvalidPdfPathException('Path traversal não permitido');
    }
    if (_blockedSchemePattern.hasMatch(trimmed)) {
      throw const InvalidPdfPathException('Esquema de URL não permitido');
    }
  }
}
