/// Link de compartilhamento de lista (spec fim-fonte-plpcg §4.1).
abstract final class ShareConfig {
  /// Origem dos links `?p=…&n=…` e do QR do folheto — o PWA v2.
  ///
  /// Constante, não derivada de `AppConfig.apiBaseUrl` (Worker
  /// `plpcg-catalog`): o link abre o app, não a API.
  static const String appOrigin = 'https://v2.plpcg.com';
}
