import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../carousel/data/providers/carousel_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../domain/usecases/navigate_carousel_in_reader.dart';
import '../../domain/usecases/navigate_pdf_pages.dart';
import '../../domain/usecases/open_pdf_document.dart';
import '../../domain/usecases/set_zoom_and_fit_mode.dart';
import '../adapters/pdfx_viewer_adapter.dart';
import '../datasources/reader_preferences_datasource.dart';

/// Factory do adaptador PDFx — lifecycle do controller pertence à sessão
/// ([pdfReaderSessionProvider]); dispose aqui é safety net no shutdown.
final pdfxViewerAdapterProvider = Provider<PdfxViewerAdapter>((ref) {
  final adapter = PdfxViewerAdapter(ref.watch(pdfBytesDatasourceProvider));
  ref.onDispose(adapter.dispose);
  return adapter;
});

/// Use case UC-11 — validação de path antes da abertura PDFx.
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
  return NavigatePdfPages(ref.watch(pdfxViewerAdapterProvider));
});

/// Use case UC-11 — page-fit / page-width (Fase 2.3).
final setZoomAndFitModeProvider = Provider<SetZoomAndFitMode>((ref) {
  return SetZoomAndFitMode(ref.watch(pdfxViewerAdapterProvider));
});

/// Use case UC-11 — navegação carousel no leitor (Fase 4.7).
final navigateCarouselInReaderProvider =
    Provider<NavigateCarouselInReader>((ref) {
  return NavigateCarouselInReader(ref.watch(carouselRepositoryProvider));
});
