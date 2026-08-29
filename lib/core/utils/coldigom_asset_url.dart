import 'asset_base_url_resolver.dart';

/// URL HTTP para assets coldigom (`assets/praises/...`).
///
/// Na web o fetch passa pelo proxy same-policy `/api/coldigom/<chave>` em
/// [AppConfig.apiBaseUrl], que devolve `cross-origin-resource-policy:
/// cross-origin` e portanto sobrevive ao COEP exigido pelo pdfrx. No nativo,
/// e como fallback quando não há base configurada, usa a URL direta do worker.
///
/// Compartilhado por [AudioTrackUrl] e pelo datasource de cifras.
abstract final class ColdigomAssetUrl {
  /// URL direta no worker coldigom.
  static String directUrlForKey(String r2Key) {
    final key = r2Key.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return key;
    }
    return AssetBaseUrlResolver.joinAssetUrl(key);
  }

  /// URL de fetch — proxy quando [apiBase] existe, direta caso contrário.
  static String fetchUrlForKey(String r2Key, {required String apiBase}) {
    final key = r2Key.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return key;
    }

    final trimmedBase = apiBase.trim();
    if (trimmedBase.isEmpty) return directUrlForKey(key);

    final normalized = key.startsWith('/') ? key.substring(1) : key;
    final base = trimmedBase.endsWith('/')
        ? trimmedBase.substring(0, trimmedBase.length - 1)
        : trimmedBase;
    return '$base/api/coldigom/$normalized';
  }
}
