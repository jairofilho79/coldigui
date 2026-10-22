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

/// Extrai o id do louvor a partir de uma URI de deep link (`/louvor/:id`).
///
/// Suporta:
/// - `https://plpcg.com/louvor/:id`
/// - `https://v2.plpcg.com/louvor/:id`
/// - `plpcg://louvor/:id` ou `plpcg:///louvor/:id`
/// - URLs com fragmento web: `https://v2.plpcg.com/#/louvor/:id`
String? parsePraiseId(Uri uri) {
  final segments = uri.pathSegments;
  final louvorIdx = segments.indexOf('louvor');
  if (louvorIdx != -1 && louvorIdx + 1 < segments.length) {
    final id = Uri.decodeComponent(segments[louvorIdx + 1]).trim();
    if (id.isNotEmpty) return id;
  }
  if (uri.host.toLowerCase() == 'louvor' && segments.isNotEmpty) {
    final id = Uri.decodeComponent(segments.first).trim();
    if (id.isNotEmpty) return id;
  }
  final fragment = uri.fragment;
  if (fragment.isNotEmpty) {
    final fragmentUri = Uri.tryParse(
      fragment.startsWith('/') ? fragment : '/$fragment',
    );
    if (fragmentUri != null) {
      final fragSegments = fragmentUri.pathSegments;
      final fragLouvorIdx = fragSegments.indexOf('louvor');
      if (fragLouvorIdx != -1 && fragLouvorIdx + 1 < fragSegments.length) {
        final id = Uri.decodeComponent(fragSegments[fragLouvorIdx + 1]).trim();
        if (id.isNotEmpty) return id;
      }
    }
  }
  return null;
}
