import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart';

typedef FetchAudioBytesFn =
    Future<List<int>> Function(String url, {String? fallbackUrl});

/// Cache blob URLs em duas fases (O7 fix round 2): [_pending] é a fila que
/// uma `_applyQueue` está resolvendo — pode nunca chegar a tocar, se outra
/// geração a superar no meio do caminho; [_current] é a fila que o player
/// tem carregada agora de verdade. Só [commitQueue] promove pending →
/// current; [beginQueue] mexe só no pending. Assim, uma geração que perde a
/// corrida (`gen != _generation` em `_applyQueue`) nunca revoga o blob que
/// está tocando — ela só limpa o que ela própria vinha montando.
class WebAudioSourceResolver {
  WebAudioSourceResolver({required this.fetchBytes});

  final FetchAudioBytesFn fetchBytes;

  /// Blobs da fila que o player tem carregada — só [commitQueue] escreve
  /// aqui; usado também por [resolveForPlayback] (cache de streaming, sem
  /// fase pendente — resolve e já vale na hora).
  final _current = <String, String>{};

  /// Blobs da fila sendo montada agora — [beginQueue] limpa,
  /// [resolveFromBytes] escreve, [commitQueue] promove pra [_current].
  final _pending = <String, String>{};

  static const int maxBlobBytes = 20 * 1024 * 1024;
  static const int _maxCacheEntries = 2;

  /// Teto de blobs simultâneos por fila offline (O7 fix round 1) — o
  /// navegador não libera `blob:` sozinho, então sem teto uma fila longa
  /// vazaria memória. Acima dele, [resolveFromBytes] devolve `null` e a
  /// faixa cai para a URL de rede (streaming direto, sem blob). O teto vale
  /// sobre [_pending] — é aí que a fila em montagem se acumula.
  static const int maxQueueBlobs = 30;

  Future<Uri> resolveForPlayback(
    String fetchUrl, {
    String? cacheKey,
    String? streamFallbackUrl,
  }) async {
    final key = cacheKey ?? fetchUrl;
    final cached = _current[key];
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
      _current[key] = blobUrl;
      _trimCache(key);
      return Uri.parse(blobUrl);
    } on Object {
      return Uri.parse(streamUrl);
    }
  }

  /// Blob URL para bytes já no aparelho (Cache API) — o caminho offline.
  ///
  /// Escreve em [_pending], nunca em [_current] direto (fix round 2): uma
  /// `_applyQueue` que perde a corrida de geração não pode revogar o que
  /// está tocando — só [commitQueue] promove. Mesmo teto [maxBlobBytes]:
  /// acima dele devolve `null` e quem chama cai na URL de rede. Sem trim
  /// por faixa — o teto é [maxQueueBlobs] (ver doc do campo).
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) {
    final cached = _pending[cacheKey];
    if (cached != null) return Uri.parse(cached);
    if (bytes.length > maxBlobBytes) return null;
    if (_pending.length >= maxQueueBlobs) {
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
    _pending[cacheKey] = blobUrl;
    return Uri.parse(blobUrl);
  }

  /// Início de uma fila nova (O7 fix round 1/2): revoga e limpa só
  /// [_pending] — nunca mexe no que está tocando ([_current]). Chamado no
  /// topo de `_applyQueue`, antes mesmo de a geração ter vencido a corrida;
  /// é seguro porque só afeta blobs de uma tentativa (esta ou uma anterior
  /// abandonada) que ainda não tocam.
  void beginQueue() {
    for (final url in _pending.values) {
      URL.revokeObjectURL(url);
    }
    _pending.clear();
  }

  /// Promove [_pending] a [_current] (fix round 2) — chamado só depois do
  /// último `gen != _generation` de `_applyQueue`, imediatamente antes de
  /// `player.setAudioSources`: só a geração vencedora chega aqui, então só
  /// ela revoga os blobs que o player tinha até então.
  void commitQueue() {
    for (final url in _current.values) {
      URL.revokeObjectURL(url);
    }
    _current
      ..clear()
      ..addAll(_pending);
    _pending.clear();
  }

  /// Fecho de sessão (dispose/stop) — limpa tudo, tocando ou não.
  void revokeAll() {
    for (final url in _current.values) {
      URL.revokeObjectURL(url);
    }
    _current.clear();
    for (final url in _pending.values) {
      URL.revokeObjectURL(url);
    }
    _pending.clear();
  }

  void _trimCache(String keepKey) {
    while (_current.length > _maxCacheEntries) {
      final removeKey = _current.keys.firstWhere((k) => k != keepKey);
      final url = _current.remove(removeKey);
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
