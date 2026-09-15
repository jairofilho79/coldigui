import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

Future<bool?>? _request;

/// Pede `navigator.storage.persist()` uma vez por sessão (best-effort, S7).
///
/// Sem persistência, o Safari pode apagar Cache API/OPFS de uma origem após
/// 7 dias sem uso (na aba normal; o PWA no ecrã inicial é isento) — e com
/// isso o shell precacheado pelo `sw.js`, o catálogo e os PDFs offline.
/// Devolve `true` se a origem já era/ficou persistente, `false` se o browser
/// recusou e `null` se a API não existe ou falhou. Nunca lança; o resultado
/// só vai para `debugPrint`.
Future<bool?> requestPersistentStorage() => _request ??= _requestOnce();

Future<bool?> _requestOnce() async {
  try {
    final storage = window.navigator.storage;
    if ((await storage.persisted().toDart).toDart) return true;
    final granted = (await storage.persist().toDart).toDart;
    debugPrint('[storage] persist() → $granted');
    return granted;
  } on Object catch (e) {
    debugPrint('[storage] persist() falhou: $e');
    return null;
  }
}
