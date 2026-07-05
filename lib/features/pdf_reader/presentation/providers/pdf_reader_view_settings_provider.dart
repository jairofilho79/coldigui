import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/pdf_reader_viewer_providers.dart';
import '../../domain/entities/pdf_reader_preferences.dart';
import 'reader_fullscreen_provider.dart';

/// Estado de visualização do leitor — fit mode (UC-11 Fase 2.3).
final pdfReaderViewSettingsProvider =
    NotifierProvider<PdfReaderViewSettingsNotifier, PdfReaderViewSettings>(
      PdfReaderViewSettingsNotifier.new,
    );

/// Carrega, persiste e aplica preferências de fit no adapter ativo.
class PdfReaderViewSettingsNotifier extends Notifier<PdfReaderViewSettings> {
  @override
  PdfReaderViewSettings build() {
    return ref.watch(readerPreferencesDatasourceProvider).loadSettings();
  }

  /// Aplica fit no controller após o documento carregar ou mudar viewport.
  ///
  /// Fullscreen força [PdfFitMode.pageWidth]; fora dele usa a preferência salva.
  Future<void> applyInitialFit() async {
    final mode = ref.read(readerFullscreenProvider)
        ? PdfFitMode.pageWidth
        : state.fitMode;
    await ref.read(setZoomAndFitModeProvider).call(mode: mode);
  }

  /// Alterna page-fit ↔ page-width, persiste e reaplica zoom.
  Future<void> toggleFitMode() async {
    final next = state.fitMode.toggle();
    await ref.read(readerPreferencesDatasourceProvider).saveFitMode(next);
    state = state.copyWith(fitMode: next);
    await ref.read(setZoomAndFitModeProvider).call(mode: next);
  }
}
