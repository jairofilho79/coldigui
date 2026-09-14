import 'dart:typed_data';

/// Resolve URL de reprodução — nativo devolve HTTP direto.
class WebAudioSourceResolver {
  WebAudioSourceResolver({this.fetchBytes});

  final FetchAudioBytesFn? fetchBytes;

  static const int maxBlobBytes = 20 * 1024 * 1024;

  Future<Uri> resolveForPlayback(
    String fetchUrl, {
    String? cacheKey,
    String? streamFallbackUrl,
  }) async {
    return Uri.parse(streamFallbackUrl ?? fetchUrl);
  }

  /// No nativo o áudio local toca por `Uri.file`; blob URL é coisa da web.
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) => null;

  void revokeAll() {}
}

typedef FetchAudioBytesFn = Future<List<int>> Function(
  String url, {
  String? fallbackUrl,
});

WebAudioSourceResolver createWebAudioSourceResolver({
  required FetchAudioBytesFn fetchBytes,
}) {
  return WebAudioSourceResolver(fetchBytes: fetchBytes);
}
