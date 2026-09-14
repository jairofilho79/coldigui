import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import '../../../../core/constants/offline_config.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/exceptions/quota_exceeded_classifier.dart';
import '../../domain/ports/audio_storage_port.dart';

AudioStoragePort createAudioStoragePortImpl() => AudioStorageWeb();

/// Áudios Coldigom na Cache API (web) — bucket próprio
/// [OfflineConfig.audioCacheStoreName], chaves `plpcg_audio/<relPath>` na
/// origem lógica `https://plpcg-offline.local`, como [PdfStorageWeb].
class AudioStorageWeb implements AudioStoragePort {
  static const _offlineOrigin = 'https://plpcg-offline.local';

  Cache? _cache;

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    final storageKey =
        '${OfflineConfig.audioStorageSubdir}/${relPath.replaceAll(r'\', '/')}';
    final cache = await _openCache();
    final blob = Blob(
      [bytes.toJS].toJS,
      BlobPropertyBag(type: _mimeForKey(storageKey)),
    );
    try {
      await cache
          .put(
            _requestForKey(storageKey),
            Response(blob, ResponseInit(status: 200)),
          )
          .toDart;
    } on Object catch (e) {
      // `isA` (não `on DOMException catch`) — checagem de tipo interop
      // consistente entre dart2js e dart2wasm.
      if (e.isA<DOMException>()) {
        final domError = e as DOMException;
        if (isQuotaExceededError(
          name: domError.name,
          message: domError.message,
        )) {
          throw InsufficientDiskSpaceException(
            requiredBytes: bytes.length,
            availableBytes: null,
          );
        }
        throw AudioStorageWriteException(domError.toString());
      }
      throw AudioStorageWriteException(e.toString());
    }
    return storageKey;
  }

  @override
  Future<bool> exists(String storageKey) async {
    try {
      final cache = await _openCache();
      return await cache.match(_requestForKey(storageKey)).toDart != null;
    } on Object {
      return false;
    }
  }

  @override
  Future<Uint8List?> readBytes(String storageKey) async {
    try {
      final cache = await _openCache();
      final response = await cache.match(_requestForKey(storageKey)).toDart;
      if (response == null) return null;
      final buffer = await response.arrayBuffer().toDart;
      return Uint8List.view(buffer.toDart);
    } on Object {
      return null;
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
  }

  @override
  Future<void> deleteTree() async {
    await window.caches.delete(OfflineConfig.audioCacheStoreName).toDart;
    _cache = null;
  }

  @override
  Future<int> getTotalBytes() async {
    final cache = await _openCache();
    final requests = await cache.keys().toDart;
    var total = 0;
    for (var i = 0; i < requests.length; i++) {
      final response = await cache.match(requests[i]).toDart;
      if (response == null) continue;
      total += (await response.blob().toDart).size;
    }
    return total;
  }

  Future<Cache> _openCache() async {
    _cache ??= await window.caches
        .open(OfflineConfig.audioCacheStoreName)
        .toDart;
    return _cache!;
  }

  Request _requestForKey(String storageKey) => Request(
    Uri(
      scheme: 'https',
      host: Uri.parse(_offlineOrigin).host,
      pathSegments: storageKey.split('/'),
    ).toString().toJS,
  );

  static String _mimeForKey(String key) {
    final lower = key.toLowerCase();
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    return 'audio/mpeg';
  }
}
