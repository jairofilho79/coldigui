import 'dart:js_interop';

import 'package:web/web.dart';

/// Estima bytes livres via `navigator.storage.estimate()` (OPFS quota).
Future<int?> estimateFreeStorageBytes() async {
  try {
    final estimate = await window.navigator.storage.estimate().toDart;
    final free = estimate.quota - estimate.usage;
    return free > 0 ? free.toInt() : 0;
  } on Object {
    return null;
  }
}
