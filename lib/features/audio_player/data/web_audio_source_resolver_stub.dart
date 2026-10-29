import 'dart:typed_data';

/// Resolve URL de reprodução — nativo devolve HTTP direto.
class WebAudioSourceResolver {
  WebAudioSourceResolver();

  static const int maxBlobBytes = 20 * 1024 * 1024;

  /// No nativo o áudio local toca por `Uri.file`; blob URL é coisa da web.
  Future<Uri?> resolveFromCache(String storageKey) async => null;

  /// No nativo o áudio local toca por `Uri.file`; blob URL é coisa da web.
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) => null;

  /// No-op no nativo — não há blob pra revogar entre filas.
  void beginQueue() {}

  /// No-op no nativo — não há pending/current pra promover (fix round 2).
  void commitQueue() {}

  void revokeAll() {}
}

WebAudioSourceResolver createWebAudioSourceResolver() {
  return WebAudioSourceResolver();
}
