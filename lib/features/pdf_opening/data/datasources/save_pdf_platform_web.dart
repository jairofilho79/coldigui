import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'save_pdf_platform.dart';

SavePdfPlatform createSavePdfPlatformImpl() => _WebSavePdfPlatform();

class _WebSavePdfPlatform implements SavePdfPlatform {
  @override
  Future<String> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final blobParts = [bytes.toJS].toJS;
    final blob = Blob(blobParts, BlobPropertyBag(type: 'application/pdf'));
    final url = URL.createObjectURL(blob);
    final anchor = HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
    return fileName;
  }
}
