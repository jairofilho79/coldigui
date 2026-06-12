/// Configuração de build-time da aplicação PLPCG.
abstract final class AppConfig {
  /// URL base da API (Cloudflare Pages / backend PLPCG).
  ///
  /// Definida em compile-time via `--dart-define` ou
  /// `--dart-define-from-file=dart_defines/plpcg.json`.
  ///
  /// iOS: [ios/Flutter/PlpcgDartDefines.xcconfig] injeta o mesmo valor em builds
  /// Xcode/`flutter install` sem flags no terminal.
  ///
  /// Retorna vazio se nenhum define foi aplicado — [ColdiguiApp] exibe tela de
  /// configuração ausente; [CatalogRemoteDatasource] lança [StateError].
  static const String apiBaseUrl = String.fromEnvironment('PLPCG_API_BASE_URL');

  /// `true` quando [apiBaseUrl] não foi injetado no build.
  static bool get isApiBaseUrlMissing => apiBaseUrl.isEmpty;
}
