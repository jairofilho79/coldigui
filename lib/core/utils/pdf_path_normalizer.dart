import 'dart:convert';

/// Spec crítica §10.3 — normalização de paths PDF para lookup O(1).
///
/// Regra: SW, app e R2 devem usar a mesma regra de normalização.
abstract final class PdfPathNormalizer {
  /// Decodifica pdfId Base64 URL-safe UTF-8; preserva case e acentos.
  ///
  /// Passos: normaliza padding URL-safe → `base64.decode` → `utf8.decode`.
  static String getPdfRelPath(String pdfId) {
    var normalized = pdfId.replaceAll('-', '+').replaceAll('_', '/');
    final mod = normalized.length % 4;
    if (mod == 2) {
      normalized += '==';
    } else if (mod == 3) {
      normalized += '=';
    }
    final bytes = base64.decode(normalized);
    return utf8.decode(bytes);
  }

  /// Normaliza URL para comparação/lookup no cache.
  ///
  /// Passos: remove protocolo → trim slashes → decode URI (até 3x) →
  /// remove acentos → lowercase → normaliza separadores → prefixo assets/.
  static String normalizePdfUrl(String url) {
    var path = url.trim();

    final schemeIndex = path.indexOf('://');
    if (schemeIndex != -1) {
      final slashIndex = path.indexOf('/', schemeIndex + 3);
      path = slashIndex == -1 ? '' : path.substring(slashIndex);
    }

    path = path.replaceAll(r'\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    if (path.contains('%')) {
      for (var i = 0; i < 3; i++) {
        try {
          final decoded = Uri.decodeComponent(path);
          if (decoded == path) break;
          path = decoded;
        } on ArgumentError {
          break;
        } on FormatException {
          break;
        }
      }
    }

    path = _stripAccents(path).toLowerCase();

    if (!path.startsWith('assets/')) {
      path = 'assets/$path';
    }

    return path;
  }

  static String _stripAccents(String input) {
    const accents = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
    final buffer = StringBuffer();
    for (final char in input.runes) {
      final s = String.fromCharCode(char);
      final index = accents.indexOf(s);
      buffer.write(index == -1 ? s : plain[index]);
    }
    return buffer.toString();
  }
}
