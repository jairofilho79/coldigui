import 'package:coldigui/core/constants/app_config.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_api_config.dart';

/// Resolve a base URL HTTP para paths `assets/...` conforme a origem.
abstract final class AssetBaseUrlResolver {
  /// Prefixo de assets coldigom no R2.
  static const coldigomAssetPrefix = 'assets/praises/';

  /// Retorna base URL sem barra final.
  ///
  /// [baseUrl], quando informado, substitui [AppConfig.apiBaseUrl] para
  /// paths que não são assets coldigom (ex.: base injetada em testes ou por
  /// um resolver com configuração própria).
  static String baseUrlForAssetPath(String assetPath, {String? baseUrl}) {
    final normalized = assetPath.startsWith('/')
        ? assetPath.substring(1)
        : assetPath;
    if (normalized.startsWith(coldigomAssetPrefix)) {
      return ColdigomApiConfig.baseUrl;
    }
    return _trimTrailingSlash(baseUrl ?? AppConfig.apiBaseUrl);
  }

  /// Junta base + path relativo (`/assets/...` ou `assets/...`).
  ///
  /// [baseUrl] é repassado a [baseUrlForAssetPath]; quando omitido, mantém o
  /// comportamento atual (base global de [AppConfig.apiBaseUrl]).
  static String joinAssetUrl(String assetPath, {String? baseUrl}) {
    final normalizedPath = assetPath.startsWith('/')
        ? assetPath
        : '/$assetPath';
    final base = baseUrlForAssetPath(normalizedPath, baseUrl: baseUrl);
    if (base.isEmpty) return normalizedPath;
    return '$base$normalizedPath';
  }

  static String _trimTrailingSlash(String url) {
    if (url.isEmpty) return url;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
