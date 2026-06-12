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
/// Navegação usa scroll vertical contínuo fixo em [PdfxPdfView]; sem toggle horizontal.
class PdfReaderViewSettings {
  const PdfReaderViewSettings({required this.fitMode});

  final PdfFitMode fitMode;

  /// Default: page-fit com scroll vertical contínuo.
  static const defaults = PdfReaderViewSettings(fitMode: PdfFitMode.pageFit);

  PdfReaderViewSettings copyWith({PdfFitMode? fitMode}) {
    return PdfReaderViewSettings(fitMode: fitMode ?? this.fitMode);
  }
}
