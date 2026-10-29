/// Extrai os query params de [uri] tolerando pares malformados (Tarefa 8,
/// spec C.4 — deep link seguro).
///
/// Tenta [Uri.queryParameters] primeiro; se lançar [FormatException] (`%`
/// inválido em algum valor), decodifica [Uri.query] par a par com
/// [Uri.decodeQueryComponent], descartando somente o par que falhar e
/// mantendo os demais.
Map<String, String> safeQueryParameters(Uri uri) {
  try {
    return uri.queryParameters;
  } on FormatException {
    final result = <String, String>{};
    for (final pair in uri.query.split('&')) {
      if (pair.isEmpty) continue;
      final separatorIndex = pair.indexOf('=');
      final rawKey = separatorIndex < 0
          ? pair
          : pair.substring(0, separatorIndex);
      final rawValue = separatorIndex < 0
          ? ''
          : pair.substring(separatorIndex + 1);
      try {
        final key = Uri.decodeQueryComponent(rawKey);
        final value = Uri.decodeQueryComponent(rawValue);
        result[key] = value;
      } on FormatException {
        continue;
      }
    }
    return result;
  }
}
