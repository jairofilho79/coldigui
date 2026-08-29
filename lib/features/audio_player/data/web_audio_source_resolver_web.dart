import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

typedef FetchAudioBytesFn =
    Future<List<int>> Function(String url, {String? fallbackUrl});

/// Cache blob URLs — faixa atual + próxima; revoga ao trocar/fechar.
class WebAudioSourceResolver {
  WebAudioSourceResolver({required this.fetchBytes});

  final FetchAudioBytesFn fetchBytes;
  final _blobUrls = <String, String>{};
  static const int maxBlobBytes = 20 * 1024 * 1024;
  static const int _maxCacheEntries = 2;

  Future<Uri> resolveForPlayback(
    String fetchUrl, {
    String? cacheKey,
    String? streamFallbackUrl,
  }) async {
    final key = cacheKey ?? fetchUrl;
    final cached = _blobUrls[key];
    if (cached != null) {
      return Uri.parse(cached);
    }

    final streamUrl = streamFallbackUrl ?? fetchUrl;

    try {
      final raw = await fetchBytes(fetchUrl, fallbackUrl: streamFallbackUrl);
      if (raw.length > maxBlobBytes) {
        return Uri.parse(streamUrl);
      }
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      final blobParts = [bytes.toJS].toJS;
      final blob = Blob(
        blobParts,
        BlobPropertyBag(type: _mimeFromUrl(fetchUrl)),
      );
      final blobUrl = URL.createObjectURL(blob);
      _blobUrls[key] = blobUrl;
      _trimCache(key);
      return Uri.parse(blobUrl);
    } on Object {
      return Uri.parse(streamUrl);
    }
  }

  void revokeAll() {
    for (final url in _blobUrls.values) {
      URL.revokeObjectURL(url);
    }
    _blobUrls.clear();
  }

  void _trimCache(String keepKey) {
    while (_blobUrls.length > _maxCacheEntries) {
      final removeKey = _blobUrls.keys.firstWhere((k) => k != keepKey);
      final url = _blobUrls.remove(removeKey);
      if (url != null) URL.revokeObjectURL(url);
    }
  }

  static String _mimeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m4a')) return 'audio/mp4';
    if (lower.contains('.wav')) return 'audio/wav';
    return 'audio/mpeg';
  }
}

WebAudioSourceResolver createWebAudioSourceResolver({
  required FetchAudioBytesFn fetchBytes,
}) {
  return WebAudioSourceResolver(fetchBytes: fetchBytes);
}
