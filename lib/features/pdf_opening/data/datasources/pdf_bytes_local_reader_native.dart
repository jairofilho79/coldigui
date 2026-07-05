import 'dart:io';
import 'dart:typed_data';

/// Lê bytes de PDF em path absoluto no filesystem nativo.
Future<Uint8List> readLocalPdfBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw Exception('Arquivo PDF não encontrado');
  }
  return file.readAsBytes();
}
