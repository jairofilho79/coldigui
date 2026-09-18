/// Configuração da API coldigom.
abstract final class ColdigomApiConfig {
  /// URL base do Worker coldigom — catálogo, PDFs e materiais do app.
  ///
  /// `--dart-define=COLDIGOM_API_BASE_URL` ou `dart_defines/*.json`. Sem
  /// default: vazio quando o define não foi injetado — [ColdiguiApp] mostra
  /// a tela de configuração ausente (mesmo tratamento de
  /// `PLPCG_API_BASE_URL`).
  static const String baseUrl = String.fromEnvironment('COLDIGOM_API_BASE_URL');

  /// `true` quando [baseUrl] não foi injetado no build.
  static bool get isBaseUrlMissing => baseUrl.isEmpty;
}
