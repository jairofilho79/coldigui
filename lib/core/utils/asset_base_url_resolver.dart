import 'package:coldigui/core/constants/app_config.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_api_config.dart';

/// Resolve a base URL HTTP para paths `assets/...` conforme a origem.
abstract final class AssetBaseUrlResolver {
  /// Prefixo de assets coldigom no R2.
  static const coldigomAssetPrefix = 'assets/praises/';

  /// Retorna base URL sem barra final.
  static String baseUrlForAssetPath(String assetPath) {
    final normalized = assetPath.startsWith('/')
        ? assetPath.substring(1)
        : assetPath;
    if (normalized.startsWith(coldigomAssetPrefix)) {
      return ColdigomApiConfig.baseUrl;
    }
    return _trimTrailingSlash(AppConfig.apiBaseUrl);
  }

  /// Junta base + path relativo (`/assets/...` ou `assets/...`).
  static String joinAssetUrl(String assetPath) {
    final normalizedPath = assetPath.startsWith('/')
        ? assetPath
        : '/$assetPath';
    final base = baseUrlForAssetPath(normalizedPath);
    if (base.isEmpty) return normalizedPath;
    return '$base$normalizedPath';
  }

  static String _trimTrailingSlash(String url) {
    if (url.isEmpty) return url;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
