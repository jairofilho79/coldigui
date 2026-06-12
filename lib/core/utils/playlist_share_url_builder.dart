import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Params extraídos de URL de compartilhamento de playlist (UC-07, Fase 4.4).
///
/// Valores brutos dos query params [UrlSyncParams.sharePdfs] e
/// [UrlSyncParams.shareName] — use [parsePdfIdsFromSharePdfs] para obter IDs.
class PlaylistShareParams {
  const PlaylistShareParams({
    required this.sharePdfs,
    required this.shareName,
  });

  /// CSV de [pdfId] conforme query `sharepdfs`.
  final String sharePdfs;

  /// Nome exibido da playlist conforme query `sharename`.
  final String shareName;
}

/// Monta path relativo `/?sharepdfs=...&sharename=...` (§2.5 MAPEAMENTO).
///
/// Lança [ArgumentError] se [pdfIds] ou [shareName] forem inválidos.
String buildPlaylistShareLocation({
  required List<String> pdfIds,
  required String shareName,
}) {
  if (pdfIds.isEmpty) {
    throw ArgumentError.value(pdfIds, 'pdfIds', 'must not be empty');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }

  final params = {
    UrlSyncParams.sharePdfs: pdfIds.join(','),
    UrlSyncParams.shareName: shareName,
  };

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.home}?$query';
}

/// Monta URL absoluta para compartilhamento ([origin] + [buildPlaylistShareLocation]).
///
/// [origin] tipicamente [AppConfig.apiBaseUrl] (`https://plpcg.com`).
String buildPlaylistShareUrl({
  required String origin,
  required List<String> pdfIds,
  required String shareName,
}) {
  final normalizedOrigin =
      origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
  final location = buildPlaylistShareLocation(
    pdfIds: pdfIds,
    shareName: shareName,
  );
  return '$normalizedOrigin$location';
}

/// Remove params de share de playlist de [uri] (UC-07 / UC-14, Fase 4.5).
///
/// Usado após import via deep link para evitar re-import na navegação.
Uri stripPlaylistShareParams(Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters)
    ..remove(UrlSyncParams.sharePdfs)
    ..remove(UrlSyncParams.shareName);
  if (query.isEmpty) {
    return uri.replace(queryParameters: const {});
  }
  return uri.replace(queryParameters: query);
}

/// Extrai params de share de [uri] quando ambos presentes.
PlaylistShareParams? parsePlaylistShareParams(Uri uri) {
  final sharePdfs = uri.queryParameters[UrlSyncParams.sharePdfs];
  final shareName = uri.queryParameters[UrlSyncParams.shareName];
  if (sharePdfs == null ||
      sharePdfs.isEmpty ||
      shareName == null ||
      shareName.isEmpty) {
    return null;
  }
  return PlaylistShareParams(sharePdfs: sharePdfs, shareName: shareName);
}

/// Parse CSV de [sharePdfs] — preserva ordem, dedupe (primeira ocorrência).
List<String> parsePdfIdsFromSharePdfs(String sharePdfs) {
  final seen = <String>{};
  final result = <String>[];
  for (final part in sharePdfs.split(',')) {
    final id = part.trim();
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    result.add(id);
  }
  return result;
}

/// Aceita URL completa, query string ou fragmento colado pelo usuário (UC-07 UI).
///
/// Retorna `null` se não encontrar ambos `sharepdfs` e `sharename`.
PlaylistShareParams? extractShareParamsFromUserInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasQuery) {
    final fromUri = parsePlaylistShareParams(uri);
    if (fromUri != null) return fromUri;
  }

  final queryOnly = trimmed.startsWith('?') ? trimmed.substring(1) : trimmed;
  final fromQuery = parsePlaylistShareParams(Uri(query: queryOnly));
  if (fromQuery != null) return fromQuery;

  if (trimmed.contains('sharepdfs=') && trimmed.contains('sharename=')) {
    final questionIndex = trimmed.indexOf('?');
    final queryPart =
        questionIndex >= 0 ? trimmed.substring(questionIndex + 1) : trimmed;
    return parsePlaylistShareParams(Uri(query: queryPart));
  }

  return null;
}
