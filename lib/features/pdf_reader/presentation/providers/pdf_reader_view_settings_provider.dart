import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/pdf_reader_providers.dart';
import '../../domain/entities/pdf_reader_preferences.dart';

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

  /// Aplica fit mode salvo no controller após o documento carregar.
  Future<void> applyInitialFit() async {
    await ref.read(setZoomAndFitModeProvider).call(mode: state.fitMode);
  }

  /// Alterna page-fit ↔ page-width, persiste e reaplica zoom.
  Future<void> toggleFitMode() async {
    final next = state.fitMode.toggle();
    await ref.read(readerPreferencesDatasourceProvider).saveFitMode(next);
    state = state.copyWith(fitMode: next);
    await ref.read(setZoomAndFitModeProvider).call(mode: next);
  }
}
