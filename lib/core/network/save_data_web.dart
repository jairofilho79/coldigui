import 'dart:js_interop';

/// `navigator.connection.saveData` — melhor esforço (Network Information API).
///
/// A API só existe em navegadores Chromium; em Safari/Firefox `connection` vem
/// `undefined` e o getter devolve `null`, que aqui vira `false` (não economizar).
/// É o único sinal de link caro que a web oferece: `connectivity_plus` na web
/// só sabe dizer online/offline, então `connectivityIsUnmetered()` responde
/// `true` para qualquer conexão.
bool isSaveDataEnabled() => _navigator.connection?.saveData ?? false;

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external _NetworkInformation? get connection;
}

extension type _NetworkInformation._(JSObject _) implements JSObject {
  external bool? get saveData;
}
