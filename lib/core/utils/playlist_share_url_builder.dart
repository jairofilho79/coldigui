import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Params extraídos de URL de compartilhamento de playlist (UC-07, Fase 4.4).
///
/// Valores brutos dos query params [UrlSyncParams.sharePdfs],
/// [UrlSyncParams.shareAudios] e [UrlSyncParams.shareName].
class PlaylistShareParams {
  const PlaylistShareParams({
    required this.sharePdfs,
    required this.shareName,
    this.shareAudios = '',
  });

  /// CSV de [pdfId] conforme query `sharepdfs`.
  final String sharePdfs;

  /// CSV de audioIds conforme query `shareaudios` (opcional).
  final String shareAudios;

  /// Nome exibido da playlist conforme query `sharename`.
  final String shareName;
}

/// Monta path relativo `/?sharepdfs=...&sharename=...` (+ `shareaudios` opcional).
///
/// Lança [ArgumentError] se ambas listas vazias ou [shareName] inválido.
String buildPlaylistShareLocation({
  required List<String> pdfIds,
  required String shareName,
  List<String> audioIds = const [],
}) {
  if (pdfIds.isEmpty && audioIds.isEmpty) {
    throw ArgumentError('pdfIds/audioIds must not both be empty');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }

  final params = <String, String>{
    if (pdfIds.isNotEmpty) UrlSyncParams.sharePdfs: pdfIds.join(','),
    if (audioIds.isNotEmpty) UrlSyncParams.shareAudios: audioIds.join(','),
    UrlSyncParams.shareName: shareName,
  };

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.home}?$query';
}

/// Monta URL absoluta para compartilhamento ([origin] + [buildPlaylistShareLocation]).
String buildPlaylistShareUrl({
  required String origin,
  required List<String> pdfIds,
  required String shareName,
  List<String> audioIds = const [],
}) {
  final normalizedOrigin = origin.endsWith('/')
      ? origin.substring(0, origin.length - 1)
      : origin;
  final location = buildPlaylistShareLocation(
    pdfIds: pdfIds,
    audioIds: audioIds,
    shareName: shareName,
  );
  return '$normalizedOrigin$location';
}

/// Remove params de share de playlist de [uri] (UC-07 / UC-14, Fase 4.5).
Uri stripPlaylistShareParams(Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters)
    ..remove(UrlSyncParams.sharePdfs)
    ..remove(UrlSyncParams.shareAudios)
    ..remove(UrlSyncParams.shareName);
  if (query.isEmpty) {
    return uri.replace(queryParameters: const {});
  }
  return uri.replace(queryParameters: query);
}

/// Extrai params de share de [uri] quando `sharename` e ao menos uma lista presentes.
PlaylistShareParams? parsePlaylistShareParams(Uri uri) {
  final shareName = uri.queryParameters[UrlSyncParams.shareName];
  final sharePdfs = uri.queryParameters[UrlSyncParams.sharePdfs] ?? '';
  final shareAudios = uri.queryParameters[UrlSyncParams.shareAudios] ?? '';
  if (shareName == null || shareName.isEmpty) return null;
  if (sharePdfs.isEmpty && shareAudios.isEmpty) return null;
  return PlaylistShareParams(
    sharePdfs: sharePdfs,
    shareAudios: shareAudios,
    shareName: shareName,
  );
}

/// Parse CSV de IDs — preserva ordem, dedupe (primeira ocorrência).
List<String> parsePdfIdsFromSharePdfs(String sharePdfs) {
  return _parseCsvIds(sharePdfs);
}

/// Parse CSV de audioIds do share.
List<String> parseAudioIdsFromShareAudios(String shareAudios) {
  return _parseCsvIds(shareAudios);
}

List<String> _parseCsvIds(String raw) {
  final seen = <String>{};
  final result = <String>[];
  for (final part in raw.split(',')) {
    final id = part.trim();
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    result.add(id);
  }
  return result;
}

/// Aceita URL completa, query string ou fragmento colado pelo usuário (UC-07 UI).
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

  final hasShareName = trimmed.contains('sharename=');
  final hasList =
      trimmed.contains('sharepdfs=') || trimmed.contains('shareaudios=');
  if (hasShareName && hasList) {
    final questionIndex = trimmed.indexOf('?');
    final queryPart = questionIndex >= 0
        ? trimmed.substring(questionIndex + 1)
        : trimmed;
    return parsePlaylistShareParams(Uri(query: queryPart));
  }

  return null;
}
