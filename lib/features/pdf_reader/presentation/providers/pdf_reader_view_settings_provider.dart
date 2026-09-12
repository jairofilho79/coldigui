import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/pdf_reader_viewer_providers.dart';
import '../../domain/entities/pdf_reader_preferences.dart';
import 'reader_fullscreen_provider.dart';

/// Estado de visualização do leitor — fit mode (UC-11 Fase 2.3).
final pdfReaderViewSettingsProvider =
    NotifierProvider<PdfReaderViewSettingsNotifier, PdfReaderViewSettings>(
      PdfReaderViewSettingsNotifier.new,
    );

/// Fit mode efetivo — puro (sem `ref`) para servir tanto ao provider
/// derivado abaixo quanto a [PdfReaderViewSettingsNotifier.applyInitialFit]:
/// o notifier não pode ler de volta [pdfReaderEffectiveFitModeProvider], que
/// depende de [pdfReaderViewSettingsProvider] — seria uma dependência
/// circular (o próprio provider dependendo, via outro, de si mesmo).
PdfFitMode _effectiveFitMode({
  required bool fullscreen,
  required PdfFitMode fitMode,
}) => fullscreen ? PdfFitMode.pageWidth : fitMode;

/// Fit mode efetivo aplicado ao viewer — fullscreen força
/// [PdfFitMode.pageWidth] independente da preferência salva; fora dele usa
/// [PdfReaderViewSettings.fitMode].
final pdfReaderEffectiveFitModeProvider = Provider<PdfFitMode>((ref) {
  final fullscreen = ref.watch(readerFullscreenProvider);
  final fitMode = ref.watch(
    pdfReaderViewSettingsProvider.select((settings) => settings.fitMode),
  );
  return _effectiveFitMode(fullscreen: fullscreen, fitMode: fitMode);
});

/// Spread (duas páginas lado a lado) efetivamente ativo (Important 1, onda 4).
///
/// pdfrx 2.4.4 só oferece `calcMatrixFitWidthForPage`/`calcMatrixFitHeightForPage`
/// — não existe um `calcMatrixFitWidthForRect`/equivalente nesta versão para
/// enquadrar a LINHA (par de páginas) inteira. Com fit `pageWidth` e spread
/// ligado, `applyFitMode` enquadraria só a página do par, deixando a segunda
/// fora da viewport (a página 2 do par fica invisível). Mais simples e
/// correto que reimplementar o cálculo de matriz à mão sobre APIs internas
/// do pdfrx: desativar o spread enquanto o fit efetivo é `pageWidth` — a
/// preferência do usuário continua salva ([PdfReaderViewSettings.spreadEnabled])
/// e volta a valer assim que o fit efetivo for `pageFit`.
final pdfReaderEffectiveSpreadEnabledProvider = Provider<bool>((ref) {
  final spreadEnabled = ref.watch(
    pdfReaderViewSettingsProvider.select((settings) => settings.spreadEnabled),
  );
  if (!spreadEnabled) return false;
  return ref.watch(pdfReaderEffectiveFitModeProvider) != PdfFitMode.pageWidth;
});

/// Carrega, persiste e aplica preferências de fit no adapter ativo.
class PdfReaderViewSettingsNotifier extends Notifier<PdfReaderViewSettings> {
  @override
  PdfReaderViewSettings build() {
    return ref.watch(readerPreferencesDatasourceProvider).loadSettings();
  }

  /// Aplica fit no controller após o documento carregar ou mudar viewport.
  ///
  /// Fullscreen força [PdfFitMode.pageWidth]; fora dele usa a preferência
  /// salva. Não lê [pdfReaderEffectiveFitModeProvider] (ciclo — ver
  /// [_effectiveFitMode]): calcula com o mesmo cálculo puro, direto do
  /// próprio `state`.
  Future<void> applyInitialFit() async {
    final mode = _effectiveFitMode(
      fullscreen: ref.read(readerFullscreenProvider),
      fitMode: state.fitMode,
    );
    await ref.read(setZoomAndFitModeProvider).call(mode: mode);
  }

  /// Alterna page-fit ↔ page-width, persiste e reaplica zoom.
  Future<void> toggleFitMode() async {
    final next = state.fitMode.toggle();
    await ref.read(readerPreferencesDatasourceProvider).saveFitMode(next);
    state = state.copyWith(fitMode: next);
    await ref.read(setZoomAndFitModeProvider).call(mode: next);
  }

  /// Alterna «duas páginas em tela larga» e persiste (spec A.4 C8).
  Future<void> toggleSpread() async {
    final next = !state.spreadEnabled;
    await ref.read(readerPreferencesDatasourceProvider).saveSpreadEnabled(next);
    state = state.copyWith(spreadEnabled: next);
  }
}
