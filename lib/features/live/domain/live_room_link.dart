import '../../../core/constants/app_config.dart';
import '../../../core/utils/safe_query_parameters.dart';

final _codePattern = RegExp(r'^[a-z0-9]{7}$');

/// Código da sala num link `plpcg.com/ao-vivo/<code>` (Universal Link) ou
/// `plpcg.com/?live=<code>` (o 302 do Worker para a web). `null` se não houver.
String? parseLiveRoomCode(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length == 2 && segments[0] == 'ao-vivo') {
    return _codePattern.hasMatch(segments[1]) ? segments[1] : null;
  }
  final fromQuery = safeQueryParameters(uri)['live'];
  if (fromQuery != null && _codePattern.hasMatch(fromQuery)) return fromQuery;
  return null;
}

/// Rota interna do GoRouter.
String liveRoomRouteFor(String code) => '/ao-vivo/$code';

/// O link que o gestor partilha (o Worker responde 302 para a app).
String liveRoomShareUrl(String code) {
  final base = AppConfig.apiBaseUrl;
  final host = base.isEmpty ? 'plpcg.com' : Uri.parse(base).host;
  return 'https://$host/ao-vivo/$code';
}
