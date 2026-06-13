import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import 'reader_route_params_provider.dart';

/// Capacidade padrão do cache LRU de sessões PDF no carousel.
const kPdfSessionCacheMaxSize = 3;

/// Cache LRU de [PdfControllerPinch] por [filePath] para troca rápida no carousel.
///
/// Cada entrada mantém um controller dedicado — não reutilizar o mesmo controller
/// em duas instâncias de widget ([ValueKey] em [PdfxPdfView]).
class PdfSessionCache {
  PdfSessionCache({this.maxSize = kPdfSessionCacheMaxSize})
      : assert(maxSize > 0, 'maxSize must be positive');

  final int maxSize;

  final _entries = <String, PdfControllerPinch>{};

  /// Retira controller em cache para [filePath], ou `null` se ausente.
  PdfControllerPinch? acquire(String filePath) => _entries.remove(filePath);

  /// Devolve controller ao cache; descarta o mais antigo se exceder [maxSize].
  void release(String filePath, PdfControllerPinch controller) {
    _entries.remove(filePath);
    _entries[filePath] = controller;
    while (_entries.length > maxSize) {
      final oldestKey = _entries.keys.first;
      _entries.remove(oldestKey)?.dispose();
    }
  }

  /// Remove entrada e descarta controller — ex.: PDF corrompido.
  void remove(String filePath) {
    _entries.remove(filePath)?.dispose();
  }

  /// Descarta todos os controllers — ao sair de `/leitor`.
  void clear() {
    for (final controller in _entries.values) {
      controller.dispose();
    }
    _entries.clear();
  }

  int get length => _entries.length;
}

/// Cache compartilhado de sessões PDF; limpo ao sair de `/leitor`.
final pdfSessionCacheProvider = Provider<PdfSessionCache>((ref) {
  final cache = PdfSessionCache();
  ref.onDispose(cache.clear);

  ref.listen(readerRouteParamsProvider, (previous, next) {
    if (next.isEmpty) {
      cache.clear();
    }
  });

  return cache;
});
