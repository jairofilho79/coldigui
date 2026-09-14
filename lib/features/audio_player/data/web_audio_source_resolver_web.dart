import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart';

typedef FetchAudioBytesFn =
    Future<List<int>> Function(String url, {String? fallbackUrl});

/// Cache blob URLs — faixa atual + próxima ([resolveForPlayback], legado de
/// streaming) ou a fila offline inteira ([resolveFromBytes], O7). Revoga ao
/// trocar/fechar.
class WebAudioSourceResolver {
  WebAudioSourceResolver({required this.fetchBytes});

  final FetchAudioBytesFn fetchBytes;
  final _blobUrls = <String, String>{};
  static const int maxBlobBytes = 20 * 1024 * 1024;
  static const int _maxCacheEntries = 2;

  /// Teto de blobs simultâneos por fila offline (O7 fix round 1) — o
  /// navegador não libera `blob:` sozinho, então sem teto uma fila longa
  /// vazaria memória. Acima dele, [resolveFromBytes] devolve `null` e a
  /// faixa cai para a URL de rede (streaming direto, sem blob).
  static const int maxQueueBlobs = 30;

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

  /// Blob URL para bytes já no aparelho (Cache API) — o caminho offline.
  ///
  /// Mesmo teto [maxBlobBytes]: acima dele devolve `null` e quem chama cai
  /// na URL de rede (um áudio desse tamanho não é tocado por blob nem
  /// online). Ao contrário de [resolveForPlayback], **não** trima pra 2
  /// entradas — os blobs vivem pela fila inteira (fix round 1: a fila
  /// resolve todas as faixas antes de `setAudioSources`; trimar aqui
  /// revogava o blob da própria faixa que ia tocar). O teto é
  /// [maxQueueBlobs]; [beginQueue] é quem libera os blobs da fila anterior.
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) {
    final cached = _blobUrls[cacheKey];
    if (cached != null) return Uri.parse(cached);
    if (bytes.length > maxBlobBytes) return null;
    if (_blobUrls.length >= maxQueueBlobs) {
      debugPrint(
        '[audio] fila local passou de $maxQueueBlobs blobs — '
        '$cacheKey cai para a URL de rede',
      );
      return null;
    }
    final blob = Blob(
      [bytes.toJS].toJS,
      BlobPropertyBag(type: _mimeFromUrl(cacheKey)),
    );
    final blobUrl = URL.createObjectURL(blob);
    _blobUrls[cacheKey] = blobUrl;
    return Uri.parse(blobUrl);
  }

  /// Início de uma fila nova (O7 fix round 1): revoga os blobs da fila
  /// anterior — `_applyQueue` resolve tudo de novo, então nada mais
  /// referencia os antigos, e sem isto eles se acumulariam pra sempre.
  void beginQueue() => revokeAll();

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
