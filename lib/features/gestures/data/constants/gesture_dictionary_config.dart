import '../../../coldigom/data/constants/coldigom_api_config.dart';

/// Onde buscar `GET /api/gestures/dictionary`.
///
/// Por padrão é o Worker coldigom ([ColdigomApiConfig.baseUrl]).
/// `--dart-define=GESTURE_DICTIONARY_BASE_URL=http://localhost:8787` aponta
/// para outro servidor enquanto o coldigom não publica o dicionário real.
abstract final class GestureDictionaryConfig {
  static const String _override = String.fromEnvironment(
    'GESTURE_DICTIONARY_BASE_URL',
  );

  static String get baseUrl =>
      _override.isEmpty ? ColdigomApiConfig.baseUrl : _override;

  static const String path = '/api/gestures/dictionary';
}
