/// Modo de encaixe da página no viewport do leitor PDF (UC-11 Fase 2.3).
enum PdfFitMode {
  /// Encaixa a página pela altura do viewport (`page-fit` na PWA).
  pageFit,

  /// Encaixa a página pela largura do viewport (`page-width` na PWA).
  pageWidth;

  /// Serializa para [StorageKeys.pdfPreferredFitMode].
  String toStorageString() => switch (this) {
    PdfFitMode.pageFit => 'page-fit',
    PdfFitMode.pageWidth => 'page-width',
  };

  /// Restaura a partir de SharedPreferences; retorna `null` se inválido.
  static PdfFitMode? fromStorageString(String? value) => switch (value) {
    'page-fit' => PdfFitMode.pageFit,
    'page-width' => PdfFitMode.pageWidth,
    _ => null,
  };

  /// Alterna entre page-fit e page-width (toggle da AppBar).
  PdfFitMode toggle() =>
      this == PdfFitMode.pageFit ? PdfFitMode.pageWidth : PdfFitMode.pageFit;
}

/// Preferências de visualização do leitor — fit mode persistido (UC-11 Fase 2.3).
///
/// Navegação usa scroll vertical contínuo fixo em [PdfReaderPdfView]; sem toggle horizontal.
class PdfReaderViewSettings {
  const PdfReaderViewSettings({
    required this.fitMode,
    this.spreadEnabled = true,
  });

  final PdfFitMode fitMode;

  /// Duas páginas lado a lado em viewport largo (spec A.4 C8). Default:
  /// ligado — só tem efeito visual com `viewportAspect > 1.3` e documento
  /// com mais de uma página (ver `spreadPageLayout`).
  final bool spreadEnabled;

  /// Default: page-fit com scroll vertical contínuo, spread ligado.
  static const defaults = PdfReaderViewSettings(fitMode: PdfFitMode.pageFit);

  PdfReaderViewSettings copyWith({PdfFitMode? fitMode, bool? spreadEnabled}) {
    return PdfReaderViewSettings(
      fitMode: fitMode ?? this.fitMode,
      spreadEnabled: spreadEnabled ?? this.spreadEnabled,
    );
  }
}
