import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/safe_query_parameters.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

import '../../features/coldigom/domain/utils/praise_short_id.dart';

/// `shortId` de praise válido (spec fim-fonte-plpcg §4.1): **string** hex
/// minúscula de 3 a 8 caracteres. Nunca é número — `"000"` é um id.
///
/// Delega em `normalizePraiseShortId` (plano 1, `praise_short_id.dart`) — uma
/// fonte só para o padrão `[0-9a-f]{3,8}`.
bool isPraiseShortId(Object? value) =>
    value is String && normalizePraiseShortId(value) == value;

/// Lê o param `p`: `trim`, maiúsculas viram minúsculas, token fora do padrão
/// é ignorado; ordem e repetições ficam (a lista pode repetir um louvor).
List<String> decodePraiseShareIds(String raw) => [
  for (final part in raw.split('-')) ?normalizePraiseShortId(part),
];

/// Monta `/?p=…&n=…` (spec fim-fonte-plpcg §4.1).
///
/// Lança [ArgumentError] com [praiseShortIds] vazio, com um token que não é
/// [isPraiseShortId] (quem gera valida antes — aqui seria bug) ou com
/// [shareName] em branco.
String buildPraiseShareLocation({
  required List<String> praiseShortIds,
  required String shareName,
}) {
  if (praiseShortIds.isEmpty) {
    throw ArgumentError.value(
      praiseShortIds,
      'praiseShortIds',
      'must not be empty',
    );
  }
  final invalid = [
    for (final id in praiseShortIds)
      if (!isPraiseShortId(id)) id,
  ];
  if (invalid.isNotEmpty) {
    throw ArgumentError.value(invalid, 'praiseShortIds', 'invalid shortId');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }
  return '${RoutePaths.home}'
      '?${UrlSyncParams.praiseItems}=${praiseShortIds.join('-')}'
      '&${UrlSyncParams.shortName}=${Uri.encodeComponent(shareName)}';
}

/// URL absoluta do link por praise ([origin] + [buildPraiseShareLocation]).
String buildPraiseShareUrl({
  required String origin,
  required List<String> praiseShortIds,
  required String shareName,
}) {
  final normalizedOrigin = origin.endsWith('/')
      ? origin.substring(0, origin.length - 1)
      : origin;
  return '$normalizedOrigin'
      '${buildPraiseShareLocation(praiseShortIds: praiseShortIds, shareName: shareName)}';
}

/// Params dos links de lista **anteriores** ao link por praise (spec
/// fim-fonte-plpcg §4.4): o curto por material (`?s=`) e o longo
/// (`shareitems`/`sharepdfs`/`shareaudios`/`sharename`). Só são reconhecidos
/// para avisar e limpar a URL — nenhum deles abre mais.
const Set<String> legacyPlaylistShareParams = {
  UrlSyncParams.shortItems,
  UrlSyncParams.shareItems,
  UrlSyncParams.sharePdfs,
  UrlSyncParams.shareAudios,
  UrlSyncParams.shareName,
};

/// Params de um link de lista (UC-07).
class PlaylistShareParams {
  /// Link por praise (`?p=…&n=…`). [praiseShortIds] já validados e minúsculos.
  const PlaylistShareParams({
    required this.shareName,
    required this.praiseShortIds,
  }) : isLegacy = false;

  /// Link de uma versão antiga (§4.4) — não importa nada.
  const PlaylistShareParams.legacy()
    : shareName = '',
      praiseShortIds = const [],
      isLegacy = true;

  /// Nome da lista (`n`).
  final String shareName;

  /// Tokens do `p`, na ordem, com repetições.
  final List<String> praiseShortIds;

  /// `true` quando a URL só tem params de link antigo.
  final bool isLegacy;

  /// Há o que importar. Um `p` sem token válido é link **inválido** (aviso),
  /// não «não é link».
  bool get hasMaterial => praiseShortIds.isNotEmpty;
}

/// Remove de [uri] os params de link de lista — `p`, `n` e os antigos.
Uri stripPlaylistShareParams(Uri uri) {
  final query = Map<String, String>.from(safeQueryParameters(uri))
    ..remove(UrlSyncParams.praiseItems)
    ..remove(UrlSyncParams.shortName)
    ..removeWhere((key, _) => legacyPlaylistShareParams.contains(key));
  if (query.isEmpty) {
    return uri.replace(queryParameters: const {});
  }
  return uri.replace(queryParameters: query);
}

/// Lê um link de lista em [uri].
///
/// - `p` presente → link por praise, mesmo sem token válido ou sem `n` (aí é
///   inválido e o import avisa — D.6 de 2026-09-13).
/// - sem `p`, com algum param antigo → [PlaylistShareParams.legacy].
/// - senão `null`: não é link de lista (todo link comum do app passa aqui;
///   `n` sozinho também não é).
///
/// Lê a query por [safeQueryParameters] — `%` malformado não lança.
PlaylistShareParams? parsePlaylistShareParams(Uri uri) {
  final query = safeQueryParameters(uri);
  final praiseRaw = query[UrlSyncParams.praiseItems];
  if (praiseRaw != null) {
    return PlaylistShareParams(
      shareName: query[UrlSyncParams.shortName] ?? '',
      praiseShortIds: decodePraiseShareIds(praiseRaw),
    );
  }
  if (query.keys.any(legacyPlaylistShareParams.contains)) {
    return const PlaylistShareParams.legacy();
  }
  return null;
}

/// Aceita URL completa, query crua ou texto colado com o link no meio
/// («Importar lista», UC-07).
///
/// Tenta três leituras (URL, query crua, trecho depois do `?`); a primeira
/// com material vence. Sem material em nenhuma, devolve o melhor recurso —
/// link antigo antes de um `p` sem token válido, porque a mensagem de link
/// antigo diz mais ao usuário — ou `null` se nada parece link de lista.
PlaylistShareParams? extractShareParamsFromUserInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  PlaylistShareParams? fallback;
  PlaylistShareParams? consider(PlaylistShareParams? params) {
    if (params == null) return null;
    if (params.hasMaterial) return params;
    final current = fallback;
    if (current == null || (params.isLegacy && !current.isLegacy)) {
      fallback = params;
    }
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasQuery) {
    final fromUri = consider(parsePlaylistShareParams(uri));
    if (fromUri != null) return fromUri;
  }

  final queryOnly = trimmed.startsWith('?') ? trimmed.substring(1) : trimmed;
  final fromQuery = consider(parsePlaylistShareParams(Uri(query: queryOnly)));
  if (fromQuery != null) return fromQuery;

  final questionIndex = trimmed.indexOf('?');
  if (questionIndex >= 0) {
    final fromFragment = consider(
      parsePlaylistShareParams(
        Uri(query: trimmed.substring(questionIndex + 1)),
      ),
    );
    if (fromFragment != null) return fromFragment;
  }

  return fallback;
}
