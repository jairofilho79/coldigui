import '../entities/pdf_reader_preferences.dart';
import '../ports/pdf_reader_controller_port.dart';

/// UC-11 — Ajustar zoom e fit mode (Fase 2.3).
///
/// Aplica page-fit ou page-width via adapter; pinch permanece nativo no PDFx.
/// Botões +/- de zoom estão fora de escopo (Fase 2.3).
class SetZoomAndFitMode {
  const SetZoomAndFitMode(this._controller);

  final PdfReaderControllerPort _controller;

  /// Aplica [mode] no controller ativo.
  Future<void> call({required PdfFitMode mode}) async {
    await _controller.applyFitMode(mode);
  }
}
