import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../domain/usecases/navigate_pdf_pages.dart';
import '../../domain/usecases/open_pdf_document.dart';
import '../../domain/usecases/set_zoom_and_fit_mode.dart';
import '../adapters/pdfrx_viewer_adapter.dart';
import '../datasources/reader_preferences_datasource.dart';

/// Factory do adaptador PDF — lifecycle do handle pertence à sessão
/// ([pdfReaderSessionProvider]); dispose aqui é safety net no shutdown.
final pdfViewerAdapterProvider = Provider<PdfrxViewerAdapter>((ref) {
  final adapter = PdfrxViewerAdapter(ref.watch(pdfBytesDatasourceProvider));
  ref.onDispose(adapter.dispose);
  return adapter;
});

/// Use case UC-11 — validação de path antes da abertura PDF.
final openPdfDocumentProvider = Provider<OpenPdfDocument>((ref) {
  return const OpenPdfDocument();
});

/// Preferências do leitor em SharedPreferences (UC-11 Fase 2.3).
final readerPreferencesDatasourceProvider =
    Provider<ReaderPreferencesDatasource>((ref) {
      return ReaderPreferencesDatasource(ref.watch(sharedPreferencesProvider));
    });

/// Use case UC-11 — navegação programática entre páginas (Fase 2.3).
final navigatePdfPagesProvider = Provider<NavigatePdfPages>((ref) {
  return NavigatePdfPages(ref.watch(pdfViewerAdapterProvider));
});

/// Use case UC-11 — page-fit / page-width (Fase 2.3).
final setZoomAndFitModeProvider = Provider<SetZoomAndFitMode>((ref) {
  return SetZoomAndFitMode(ref.watch(pdfViewerAdapterProvider));
});
