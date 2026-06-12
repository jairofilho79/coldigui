import 'app_config.dart';

/// Configuração de deep links PLPCG (UC-14, Fase 4.5).
///
/// Domínio e scheme derivados de [AppConfig.apiBaseUrl] quando disponível.
abstract final class DeepLinkConfig {
  /// URL scheme customizado para dev/testes (`plpcg:///?sharepdfs=...`).
  static const String customScheme = 'plpcg';

  /// Host Universal Links — extraído de [AppConfig.apiBaseUrl].
  static String get universalLinkHost {
    final base = AppConfig.apiBaseUrl;
    if (base.isEmpty) return 'plpcg.com';
    return Uri.parse(base).host;
  }

  /// Entitlement Associated Domains (`applinks:plpcg.com`).
  static String get associatedDomain => 'applinks:$universalLinkHost';
}
