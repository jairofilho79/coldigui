import 'package:flutter_soloud/flutter_soloud.dart';

import 'soloud_script_loader_stub.dart'
    if (dart.library.js_interop) 'soloud_script_loader_web.dart';

Future<void>? _initializing;

/// Inicializa o motor de áudio (SoLoud) uma única vez por sessão.
///
/// Na web o módulo WASM só é baixado aqui, na primeira partitura aberta —
/// o `init_soloud.js` não entra no `index.html` para não pesar a carga
/// inicial de quem nunca abre uma partitura.
Future<void> ensureSoLoudReady() {
  if (SoLoud.instance.isInitialized) return Future.value();
  return _initializing ??= () async {
    try {
      await loadSoLoudScript();
      await SoLoud.instance.init();
    } finally {
      _initializing = null;
    }
  }();
}
