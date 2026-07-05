import 'dart:typed_data';

/// Porta de plataforma para persistir PDF (UC-04 D3 OA).
abstract interface class SavePdfPlatform {
  /// Grava [bytes] com [fileName]; retorna path absoluto (nativo) ou nome (web).
  Future<String> savePdf({required Uint8List bytes, required String fileName});
}
