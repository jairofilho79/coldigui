import 'dart:convert';

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

String fakeIdToken({
  required String nonce,
  Map<String, Object?> extra = const {},
}) {
  final header = _b64({'alg': 'RS256', 'typ': 'JWT'});
  final payload = _b64({'sub': 'sub-1', 'nonce': nonce, ...extra});
  return '$header.$payload.assinatura-fake';
}
