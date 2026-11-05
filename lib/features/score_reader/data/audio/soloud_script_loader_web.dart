import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

const _scriptId = 'flutter-soloud-init';
const _scriptSrc = 'assets/packages/flutter_soloud/web/init_soloud.js';

/// Injeta `init_soloud.js` sob demanda e espera o script carregar; o próprio
/// `SoLoud.init()` aguarda o módulo WASM terminar de instanciar.
Future<void> loadSoLoudScript() async {
  if (document.getElementById(_scriptId) != null) return;
  final completer = Completer<void>();
  final script = HTMLScriptElement()
    ..id = _scriptId
    ..src = _scriptSrc;
  script.onload = ((Event _) => completer.complete()).toJS;
  script.onerror = ((Event _) {
    script.remove();
    completer.completeError(StateError('falha ao carregar $_scriptSrc'));
  }).toJS;
  document.head!.append(script);
  return completer.future;
}
