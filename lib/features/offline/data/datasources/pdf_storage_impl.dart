import '../../domain/ports/pdf_storage_port.dart';
import 'pdf_storage_native.dart'
    if (dart.library.js_interop) 'pdf_storage_web.dart';

/// Factory por plataforma (conditional import).
PdfStoragePort createPdfStoragePort() => createPdfStoragePortImpl();
