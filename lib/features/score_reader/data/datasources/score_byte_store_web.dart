import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

import 'score_byte_store.dart';

ScoreByteStorePort createScoreByteStoreImpl() => ScoreByteStoreWeb();

/// Store web via Cache API, em cache próprio (`plpcg-scores`).
class ScoreByteStoreWeb implements ScoreByteStorePort {
  static const _cacheName = 'plpcg-scores';
  static const _host = 'plpcg-scores.local';

  Cache? _cache;

  Future<Cache> _openCache() async =>
      _cache ??= await window.caches.open(_cacheName).toDart;

  Request _requestFor(String key) => Request(
    Uri(
      scheme: 'https',
      host: _host,
      pathSegments: [kScoreByteStoreSubdir, scoreByteStoreFileName(key)],
    ).toString().toJS,
  );

  @override
  Future<Uint8List?> read(String key) async {
    if (key.trim().isEmpty) return null;
    try {
      final cache = await _openCache();
      final response = await cache.match(_requestFor(key)).toDart;
      if (response == null) return null;
      final buffer = await response.arrayBuffer().toDart;
      return Uint8List.view(buffer.toDart);
    } on Object catch (error) {
      debugPrint('[partitura] leitura de $key falhou: $error');
      return null;
    }
  }

  @override
  Future<bool> contains(String key) async {
    if (key.trim().isEmpty) return false;
    try {
      final cache = await _openCache();
      return await cache.match(_requestFor(key)).toDart != null;
    } on Object catch (error) {
      debugPrint('[partitura] presença de $key falhou: $error');
      return false;
    }
  }

  @override
  Future<Set<String>> fileNames() async {
    try {
      final cache = await _openCache();
      final requests = (await cache.keys().toDart).toDart;
      return {
        for (final request in requests)
          if (Uri.tryParse(request.url)?.pathSegments case [..., final name])
            Uri.decodeComponent(name),
      };
    } on Object catch (error) {
      debugPrint('[partitura] listagem falhou: $error');
      return const {};
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (key.trim().isEmpty) return;
    try {
      final cache = await _openCache();
      final blob = Blob(
        [bytes.toJS].toJS,
        BlobPropertyBag(type: 'application/octet-stream'),
      );
      await cache
          .put(_requestFor(key), Response(blob, ResponseInit(status: 200)))
          .toDart;
    } on Object catch (error) {
      // Quota estourada ou Cache API indisponível: fica só nesta sessão.
      debugPrint('[partitura] escrita de $key falhou: $error');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final cache = await _openCache();
      await cache.delete(_requestFor(key)).toDart;
    } on Object catch (error) {
      debugPrint('[partitura] remoção de $key falhou: $error');
    }
  }
}
