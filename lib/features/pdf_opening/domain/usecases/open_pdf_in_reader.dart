import '../../../../core/utils/reader_url_builder.dart';
import '../../../pdf_reader/domain/usecases/open_pdf_document.dart';

/// UC-04 — Abrir PDF no leitor (Fase 2.1).
///
/// Valida [pdfPath] e retorna rota [RoutePaths.reader] com query params
/// [UrlSyncParams.file], [UrlSyncParams.titulo]. Fase 2: online-first.
/// Fase 3.4: [ResolvePdfForReader] resolve path local antes de [buildReaderLocation].
class OpenPdfInReader {
  const OpenPdfInReader(this._openPdf);

  final OpenPdfDocument _openPdf;

  /// [pdfPath] caminho relativo, URL ou path absoluto local (modo leitor).
  ///
  /// [pdfId] opcional — quando informado, habilita [NavigateCarouselInReader]
  /// na rota `/leitor` (Fase 4.7).
  ///
  /// Retorna location para `GoRouter.push` / `replace` (ex.: `/leitor?file=...`).
  String call({
    required String pdfPath,
    String? pdfId,
    String? titulo,
    String? subtitulo,
  }) {
    _openPdf.validateFilePath(pdfPath);
    return buildReaderLocation(
      file: pdfPath,
      pdfId: pdfId,
      titulo: titulo,
      subtitulo: subtitulo,
    );
  }
}
