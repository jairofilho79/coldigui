import 'dart:typed_data';

/// Web — sem filesystem por path (Fase 4 trará store persistente).
///
/// Falha até [PdfWebStore] existir; remote/asset continuam via outros ramos.
Future<Uint8List> readLocalPdfBytes(String path) async {
  throw Exception(
    'PDF local indisponível na web sem cache offline (path: $path)',
  );
}
