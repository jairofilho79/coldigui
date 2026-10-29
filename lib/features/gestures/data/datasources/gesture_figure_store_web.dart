import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

import 'gesture_figure_store.dart';

GestureFigureStorePort createGestureFigureStoreImpl() => GestureFigureStoreWeb();

/// Store web via Cache API, mesma técnica de `PdfStorageWeb` mas em cache
/// próprio (`plpcg-gesture-figures`), para não colidir com os PDFs offline.
class GestureFigureStoreWeb implements GestureFigureStorePort {
  static const _cacheName = 'plpcg-gesture-figures';
  static const _origin = 'https://plpcg-gestures.local';

  Cache? _cache;

  Future<Cache> _openCache() async =>
      _cache ??= await window.caches.open(_cacheName).toDart;

  Request _requestFor(String r2Key) => Request(
    Uri(
      scheme: 'https',
      host: Uri.parse(_origin).host,
      pathSegments: [kGestureFigureStoreSubdir, gestureFigureFileName(r2Key)],
    ).toString().toJS,
  );

  @override
  Future<Uint8List?> read(String r2Key) async {
    if (r2Key.trim().isEmpty) return null;
    try {
      final cache = await _openCache();
      final response = await cache.match(_requestFor(r2Key)).toDart;
      if (response == null) return null;
      final buffer = await response.arrayBuffer().toDart;
      return Uint8List.view(buffer.toDart);
    } on Object catch (error) {
      debugPrint('[gestos] leitura da figura $r2Key falhou: $error');
      return null;
    }
  }

  @override
  Future<void> write(String r2Key, Uint8List bytes) async {
    if (r2Key.trim().isEmpty) return;
    try {
      final cache = await _openCache();
      final type = r2Key.toLowerCase().endsWith('.gif') ? 'image/gif' : 'image/png';
      final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: type));
      await cache
          .put(_requestFor(r2Key), Response(blob, ResponseInit(status: 200)))
          .toDart;
    } on Object catch (error) {
      // Quota estourada ou Cache API indisponível: a figura fica só em
      // memória nesta sessão.
      debugPrint('[gestos] escrita da figura $r2Key falhou: $error');
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await window.caches.delete(_cacheName).toDart;
      _cache = null;
    } on Object catch (error) {
      debugPrint('[gestos] limpeza das figuras falhou: $error');
    }
  }
}
