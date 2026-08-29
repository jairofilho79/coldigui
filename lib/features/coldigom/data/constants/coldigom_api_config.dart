/// Configuração da API coldigom.
abstract final class ColdigomApiConfig {
  /// URL base do Worker coldigom.
  ///
  /// `--dart-define=COLDIGOM_API_BASE_URL` ou `dart_defines/*.json`.
  /// Default: conta PLPCG (`jairofilho79.workers.dev`).
  static const String baseUrl = String.fromEnvironment(
    'COLDIGOM_API_BASE_URL',
    defaultValue: 'https://coldigom-api.jairofilho79.workers.dev',
  );
}
