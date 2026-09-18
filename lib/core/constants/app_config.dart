/// Configuração de build-time da aplicação PLPCG.
abstract final class AppConfig {
  /// URL base do Worker `plpcg-catalog` (auth, playlists, links, live).
  ///
  /// Definida em compile-time via `--dart-define` ou
  /// `--dart-define-from-file=dart_defines/plpcg.json`. O catálogo e os PDFs
  /// **não** vêm daqui — vêm de `COLDIGOM_API_BASE_URL`
  /// (`ColdigomApiConfig.baseUrl`).
  ///
  /// iOS: [ios/Flutter/PlpcgDartDefines.xcconfig] injeta o mesmo valor em builds
  /// Xcode/`flutter install` sem flags no terminal.
  ///
  /// Retorna vazio se nenhum define foi aplicado — [ColdiguiApp] exibe tela de
  /// configuração ausente.
  static const String apiBaseUrl = String.fromEnvironment('PLPCG_API_BASE_URL');

  /// Client ID OAuth Web (Google). Público — validação real no Worker.
  ///
  /// `--dart-define=GOOGLE_CLIENT_ID_WEB` ou `dart_defines/*.json`.
  /// Ver [docs/GOOGLE_OAUTH_SETUP.md].
  static const String googleClientIdWeb = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_WEB',
  );

  /// `true` quando [apiBaseUrl] não foi injetado no build.
  static bool get isApiBaseUrlMissing => apiBaseUrl.isEmpty;

  /// `true` quando o Client ID Web não foi injetado no build.
  static bool get isGoogleClientIdMissing => googleClientIdWeb.isEmpty;
}
