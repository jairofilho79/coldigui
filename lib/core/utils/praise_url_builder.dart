import '../constants/share_config.dart';
import '../routing/route_paths.dart';

/// Monta o path relativo da página do louvor (`/louvor/:id`).
String buildPraiseLocation(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return RoutePaths.home;
  return RoutePaths.praiseFor(trimmed);
}

/// Monta a URL absoluta para compartilhamento do louvor.
String buildPraiseShareUrl({
  required String id,
  String? origin,
}) {
  final baseOrigin = (origin ?? ShareConfig.appOrigin).trim();
  final normalizedOrigin = baseOrigin.endsWith('/')
      ? baseOrigin.substring(0, baseOrigin.length - 1)
      : baseOrigin;
  return '$normalizedOrigin${buildPraiseLocation(id)}';
}
