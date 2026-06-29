import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pdf_reader_viewer_handle.dart';
import 'reader_route_params_provider.dart';

/// Capacidade padrão do cache LRU de sessões PDF no carousel.
const kPdfSessionCacheMaxSize = 3;

/// Cache LRU de [PdfReaderViewerHandle] por [filePath] para troca rápida no carousel.
///
/// Cada entrada mantém um handle dedicado — não reutilizar o mesmo handle
/// em duas instâncias de widget ([ValueKey] em [PdfReaderPdfView]).
class PdfSessionCache {
  PdfSessionCache({this.maxSize = kPdfSessionCacheMaxSize})
    : assert(maxSize > 0, 'maxSize must be positive');

  final int maxSize;

  final _entries = <String, PdfReaderViewerHandle>{};

  /// Retira handle em cache para [filePath], ou `null` se ausente.
  PdfReaderViewerHandle? acquire(String filePath) => _entries.remove(filePath);

  /// Devolve handle ao cache; descarta o mais antigo se exceder [maxSize].
  void release(String filePath, PdfReaderViewerHandle handle) {
    _entries.remove(filePath);
    _entries[filePath] = handle;
    while (_entries.length > maxSize) {
      final oldestKey = _entries.keys.first;
      _entries.remove(oldestKey)?.dispose();
    }
  }

  /// Remove entrada e descarta handle — ex.: PDF corrompido.
  void remove(String filePath) {
    _entries.remove(filePath)?.dispose();
  }

  /// Descarta todos os handles — ao sair de `/leitor`.
  void clear() {
    for (final handle in _entries.values) {
      handle.dispose();
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
