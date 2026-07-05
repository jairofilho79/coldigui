import 'save_pdf_platform.dart';
import 'save_pdf_platform_native.dart'
    if (dart.library.js_interop) 'save_pdf_platform_web.dart';

/// Factory por plataforma (conditional import).
SavePdfPlatform createSavePdfPlatform() => createSavePdfPlatformImpl();
