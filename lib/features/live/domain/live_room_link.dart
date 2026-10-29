import '../../../core/constants/app_config.dart';
import '../../../core/routing/route_paths.dart';
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

/// Código de sala a partir do que o usuário cola no diálogo «Entrar na
/// sala»: o link partilhado (`plpcg.com/ao-vivo/<code>`), o link da web
/// (`…/?live=<code>`, com ou sem hash route), o path solto ou só o código.
/// Maiúsculas viram minúsculas (o código é `[a-z0-9]{7}`). `null` se nada
/// disso.
String? parseLiveRoomCodeFromUserInput(String raw) {
  final text = raw.trim().toLowerCase();
  if (text.isEmpty) return null;
  if (_codePattern.hasMatch(text)) return text;

  // Sem esquema, o texto pode ser `host/…` ou só o path (`ao-vivo/<code>`):
  // tenta como URL e, se não der, como path.
  final candidates = [
    if (text.contains('://')) text else ...['https://$text', '/$text'],
  ];
  for (final candidate in candidates) {
    final uri = Uri.tryParse(candidate);
    if (uri == null) continue;
    final fromUri = parseLiveRoomCode(uri);
    if (fromUri != null) return fromUri;
    // Hash route da web (`/#/ao-vivo/<code>`): o fragmento é um path.
    final fragment = Uri.tryParse(uri.fragment);
    final fromFragment = fragment == null ? null : parseLiveRoomCode(fragment);
    if (fromFragment != null) return fromFragment;
  }
  return null;
}

/// Rota interna do GoRouter.
String liveRoomRouteFor(String code) => RoutePaths.liveRoomFor(code);

/// O link que o gestor partilha (o Worker responde 302 para a app).
String liveRoomShareUrl(String code) {
  final base = AppConfig.apiBaseUrl;
  final host = base.isEmpty ? 'plpcg.com' : Uri.parse(base).host;
  return 'https://$host/ao-vivo/$code';
}
