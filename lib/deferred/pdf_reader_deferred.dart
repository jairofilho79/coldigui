export '../features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
export '../features/pdf_reader/data/pdfrx_bootstrap.dart';

import '../features/pdf_reader/data/pdfrx_bootstrap.dart';

/// Carrega chunk deferred do leitor e inicializa pdfrx/pdfium WASM.
Future<void> preparePdfReaderModule(Future<void> Function() loadLibrary) async {
  await loadLibrary();
  await ensurePdfrxInitialized();
}
