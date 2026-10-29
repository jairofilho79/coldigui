/// Bootstrap Isar por plataforma (Fase 2 web build).
///
/// Fase 3 (share PDF / folheto, D4 OA): preferir [XFile.fromData] com bytes
/// em memória em vez de gravar em diretório temporário via path_provider.
library;

export 'isar_bootstrap_native.dart'
    if (dart.library.js_interop) 'isar_bootstrap_web.dart';
