import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import '../../../../core/constants/offline_config.dart';
import '../../domain/ports/pdf_storage_port.dart';

PdfStoragePort createPdfStoragePortImpl() => PdfStorageWeb();

/// Persistência de PDFs offline via Cache API (web — Solução C).
///
/// Chaves lógicas: `plpcg_pdfs/<relPath>` — compatíveis com [OfflinePdfIndex.storagePath].
class PdfStorageWeb implements PdfStoragePort {
  static const _offlineOrigin = 'https://plpcg-offline.local';
  static const _tmpSuffix = '.tmp';

  Cache? _cache;

  @override
  Future<String> get rootPath async => OfflineConfig.pdfStorageSubdir;

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    final storageKey = _storageKey(relPath);
    final tmpKey = '$storageKey$_tmpSuffix';
    try {
      await _putBytes(tmpKey, bytes);
      await _putBytes(storageKey, bytes);
      await delete(tmpKey);
      return storageKey;
    } on Object {
      await delete(tmpKey);
      rethrow;
    }
  }

  @override
  Future<bool> exists(String storageKey) async {
    try {
      final cache = await _openCache();
      final response = await cache.match(_requestForKey(storageKey)).toDart;
      return response != null;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> delete(String storageKey) async {
    final cache = await _openCache();
    try {
      await cache.delete(_requestForKey(storageKey)).toDart;
    } on Object {
      // Idempotente.
    }
    try {
      await cache.delete(_requestForKey('$storageKey$_tmpSuffix')).toDart;
    } on Object {
      // Idempotente.
    }
  }

  @override
  Future<void> deleteTree() async {
    await window.caches.delete(OfflineConfig.pdfCacheStoreName).toDart;
    _cache = null;
  }

  @override
  Future<void> purgeLegacyStorage() async {
    try {
      final opfsRoot = await window.navigator.storage.getDirectory().toDart;
      await opfsRoot
          .removeEntry(
            OfflineConfig.pdfStorageSubdir,
            FileSystemRemoveOptions(recursive: true),
          )
          .toDart;
    } on Object {
      // OPFS legado ausente ou inacessível.
    }
  }

  @override
  Future<int> getTotalOfflineBytes() async {
    final cache = await _openCache();
    final keys = await _listStorageKeys(cache);
    var total = 0;
    for (final key in keys) {
      if (!key.endsWith('.pdf') || key.endsWith(_tmpSuffix)) continue;
      final response = await cache.match(_requestForKey(key)).toDart;
      if (response == null) continue;
      final blob = await response.blob().toDart;
      total += blob.size;
    }
    return total;
  }

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) async {
    final cache = await _openCache();
    final keys = await _listStorageKeys(cache);
    return [
      for (final key in keys)
        if (key.endsWith('.pdf') &&
            !key.endsWith(_tmpSuffix) &&
            !indexedStorageKeys.contains(key))
          key,
    ];
  }

  @override
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes}) async {
    try {
      final cache = await _openCache();
      final response = await cache.match(_requestForKey(storageKey)).toDart;
      if (response == null) return null;
      final blob = await response.blob().toDart;
      final sliced = maxBytes == null ? blob : blob.slice(0, maxBytes);
      final buffer = await sliced.arrayBuffer().toDart;
      return buffer.toUint8List();
    } on Object {
      return null;
    }
  }

  Future<Cache> _openCache() async {
    _cache ??= await window.caches.open(OfflineConfig.pdfCacheStoreName).toDart;
    return _cache!;
  }

  Future<void> _putBytes(String storageKey, Uint8List bytes) async {
    final cache = await _openCache();
    final request = Request(_urlForKey(storageKey).toJS);
    final response = Response(bytes.toJS);
    await cache.put(request, response).toDart;
  }

  Future<List<String>> _listStorageKeys(Cache cache) async {
    final requests = await cache.keys().toDart;
    final keys = <String>[];
    final prefix = '$_offlineOrigin/';
    for (var i = 0; i < requests.length; i++) {
      final url = requests[i].url;
      if (url.startsWith(prefix)) {
        keys.add(url.substring(prefix.length));
      }
    }
    return keys;
  }

  Request _requestForKey(String storageKey) =>
      Request(_urlForKey(storageKey).toJS);

  static String _urlForKey(String storageKey) => '$_offlineOrigin/$storageKey';

  static String _storageKey(String relPath) {
    final normalized = relPath.replaceAll(r'\', '/');
    return '${OfflineConfig.pdfStorageSubdir}/$normalized';
  }
}

extension on JSArrayBuffer {
  Uint8List toUint8List() {
    final byteBuffer = toDart;
    return Uint8List.view(byteBuffer);
  }
}
