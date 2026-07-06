import 'package:flutter_test/flutter_test.dart';

/// Espelha [PdfStorageWeb] — URLs canônicas para Cache API com paths PLPCG.
String urlForStorageKey(String storageKey) {
  return Uri(
    scheme: 'https',
    host: 'plpcg-offline.local',
    pathSegments: storageKey.split('/'),
  ).toString();
}

String? storageKeyFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'plpcg-offline.local') return null;
  if (uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.join('/');
}

void main() {
  test('roundtrip preserva paths com acentos, espaços e &', () {
    const key = 'plpcg_pdfs/ColAdultos/Partitura & Cifra/001 - Aleluia.pdf';
    final url = urlForStorageKey(key);
    expect(storageKeyFromUrl(url), key);
    expect(url, contains('%20'));
  });

  test('roundtrip preserva Cifra nível I/II', () {
    const key = 'plpcg_pdfs/ColAdultos/Cifra nível I/001.pdf';
    final url = urlForStorageKey(key);
    expect(storageKeyFromUrl(url), key);
  });

  test('paths simples sem encoding especial', () {
    const key = 'plpcg_pdfs/ColAdultos/001.pdf';
    final url = urlForStorageKey(key);
    expect(storageKeyFromUrl(url), key);
    expect(url, 'https://plpcg-offline.local/plpcg_pdfs/ColAdultos/001.pdf');
  });
}
