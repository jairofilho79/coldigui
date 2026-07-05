import 'dart:typed_data';

import 'package:coldigui/features/offline/data/datasources/pdf_storage_impl.dart';

/// Web — lê bytes do PDF persistido via [PdfStoragePort] (OPFS).
Future<Uint8List> readLocalPdfBytes(String path) async {
  final store = createPdfStoragePort();
  final bytes = await store.readBytes(path);
  if (bytes == null) {
    throw Exception('Arquivo PDF não encontrado');
  }
  return bytes;
}
