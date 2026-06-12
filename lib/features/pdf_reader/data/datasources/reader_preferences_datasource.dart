import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/pdf_reader_preferences.dart';

/// Persistência de preferências do leitor PDF (UC-11 Fase 2.3).
///
/// Lê/grava [StorageKeys.pdfPreferredFitMode].
class ReaderPreferencesDatasource {
  const ReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Modo de encaixe salvo ou default `page-fit`.
  PdfFitMode getFitMode() {
    final stored = _prefs.getString(StorageKeys.pdfPreferredFitMode);
    return PdfFitMode.fromStorageString(stored) ?? PdfFitMode.pageFit;
  }

  /// Carrega preferências de visualização.
  PdfReaderViewSettings loadSettings() {
    return PdfReaderViewSettings(fitMode: getFitMode());
  }

  /// Persiste modo de encaixe.
  Future<void> saveFitMode(PdfFitMode mode) async {
    await _prefs.setString(
      StorageKeys.pdfPreferredFitMode,
      mode.toStorageString(),
    );
  }
}
