import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/safe_query_parameters.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
// `saved_playlist.dart` re-exporta `PlaylistEntry`/`MaterialKind`.
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';

import '../../features/coldigom/domain/utils/praise_short_id.dart';

/// Prefixo de uma letra por [MaterialKind] no param `shareitems` (spec A.5).
///
/// Ids de material já são base64url (sem `,` nem `:`), então `prefixo:id`
/// separado por `,` é reversível sem escape adicional.
const Map<MaterialKind, String> _shareItemPrefixes = {
  MaterialKind.pdf: 'p',
  MaterialKind.chord: 'c',
  MaterialKind.audio: 'a',
  MaterialKind.youtube: 'y',
  MaterialKind.gesture: 'g',
  MaterialKind.unknown: 'u',
};

const Map<String, MaterialKind> _shareItemKinds = {
  'p': MaterialKind.pdf,
  'c': MaterialKind.chord,
  'a': MaterialKind.audio,
  'y': MaterialKind.youtube,
  'g': MaterialKind.gesture,
  'u': MaterialKind.unknown,
};

/// Serializa a ordem única tipada como `p:ID,a:ID,c:ID`.
String encodeShareItems(List<PlaylistEntry> entries) => entries
    .map((e) => '${_shareItemPrefixes[e.kind] ?? 'u'}:${e.id}')
    .join(',');

/// Lê o param `shareitems`; devolve `null` se **qualquer** token for inválido.
///
/// Token inválido = sem `:`, com prefixo fora da tabela, com prefixo vazio ou
/// com id vazio. Segmentos vazios (`a,,b`, vírgula final) são tolerados, como
/// nos CSVs legados. Ids repetidos **ficam**: a lista pode repetir um louvor
/// («Adicionar de novo»), e o link tem que reproduzir a reunião como ela é —
/// só os CSVs legados ([parsePdfIdsFromSharePdfs]) continuam deduplicando.
///
/// O tipo decodificado passa por [resolveWireKind], como no caminho de sync
/// ([PlaylistEntry.fromJson]): uma URL escrita à mão (ou montada por um app
/// que só sabe dizer `p`) com `p:<id de um .chord>` normaliza para
/// [MaterialKind.chord]. Só [MaterialKind.audio] atravessa intocado.
///
/// Devolver `null` (e não uma lista parcial) é deliberado: quem chama cai nos
/// params legados, que um app antigo sabe montar, em vez de importar uma
/// playlist pela metade.
List<PlaylistEntry>? decodeShareItems(String raw) {
  final entries = <PlaylistEntry>[];
  for (final part in raw.split(',')) {
    final token = part.trim();
    if (token.isEmpty) continue;
    final separator = token.indexOf(':');
    if (separator <= 0 || separator == token.length - 1) return null;
    final kind = _shareItemKinds[token.substring(0, separator)];
    if (kind == null) return null;
    final id = token.substring(separator + 1);
    entries.add(PlaylistEntry(id: id, kind: resolveWireKind(kind, id)));
  }
  return entries.isEmpty ? null : entries;
}

final RegExp _shortIdPattern = RegExp(r'^[0-9a-f]{4,8}$');

/// `shortId` válido (spec short-id-share D1/D5): **string** hex minúscula de
/// 4 a 8 caracteres. Nunca é número — `"0000"` é um id.
bool isShortId(Object? value) =>
    value is String && _shortIdPattern.hasMatch(value);

/// Serializa `shortId`s para o param `s` — minúsculo, separados por `-`
/// (não sofre URL-encode e nunca ocorre em hex). Ignora o que não é shortId.
String encodeShortShareIds(List<String> shortIds) => [
  for (final id in shortIds)
    if (isShortId(id.toLowerCase())) id.toLowerCase(),
].join('-');

/// Lê o param `s`: normaliza maiúsculas, ignora token fora do padrão,
/// preserva ordem e repetições (a lista pode repetir um louvor).
List<String> decodeShortShareIds(String raw) => [
  for (final part in raw.split('-'))
    if (isShortId(part.trim().toLowerCase())) part.trim().toLowerCase(),
];

/// Monta `/?s=…&n=…` (spec §1). Lança [ArgumentError] se [shortIds] vazio
/// ou [shareName] em branco.
String buildShortPlaylistShareLocation({
  required List<String> shortIds,
  required String shareName,
}) {
  if (shortIds.isEmpty) {
    throw ArgumentError.value(shortIds, 'shortIds', 'must not be empty');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }
  return '${RoutePaths.home}'
      '?${UrlSyncParams.shortItems}=${encodeShortShareIds(shortIds)}'
      '&${UrlSyncParams.shortName}=${Uri.encodeComponent(shareName)}';
}

/// URL absoluta do link curto ([origin] + [buildShortPlaylistShareLocation]).
String buildShortPlaylistShareUrl({
  required String origin,
  required List<String> shortIds,
  required String shareName,
}) {
  final normalizedOrigin = origin.endsWith('/')
      ? origin.substring(0, origin.length - 1)
      : origin;
  return '$normalizedOrigin'
      '${buildShortPlaylistShareLocation(shortIds: shortIds, shareName: shareName)}';
}

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

/// Params extraídos de URL de compartilhamento de playlist (UC-07, Fase 4.4).
///
/// Valores brutos dos query params [UrlSyncParams.shareItems],
/// [UrlSyncParams.sharePdfs], [UrlSyncParams.shareAudios],
/// [UrlSyncParams.shareName] — ou, no formato curto (spec short-id-share
/// §1), [UrlSyncParams.shortItems]/[UrlSyncParams.shortName] via [shortIds].
class PlaylistShareParams {
  const PlaylistShareParams({
    required this.shareName,
    this.sharePdfs = '',
    this.shareAudios = '',
    this.shareItems,
    this.shortIds,
  });

  /// CSV de [pdfId] conforme query `sharepdfs`.
  final String sharePdfs;

  /// CSV de audioIds conforme query `shareaudios` (opcional).
  final String shareAudios;

  /// Nome exibido da playlist conforme query `sharename` (ou `n`, no formato
  /// curto).
  final String shareName;

  /// CSV `prefixo:id` conforme query `shareitems` (v2, ausente em apps antigos).
  final String? shareItems;

  /// `shortId`s do link curto (`s`), já validados e minúsculos. **Não nulo**
  /// significa «este share está no formato curto»: [entries] fica vazio e a
  /// resolução `shortId → pdfId` exige o catálogo (`ShortIdResolver`).
  final List<String>? shortIds;

  /// `true` quando o link veio como `?s=…&n=…`.
  bool get isShortFormat => shortIds != null;

  /// Há material para importar — tokens curtos ou entradas longas. É o que
  /// distingue «share inválido» de «share por resolver».
  bool get hasMaterial =>
      isShortFormat ? shortIds!.isNotEmpty : entries.isNotEmpty;

  /// Ordem única tipada da playlist compartilhada.
  ///
  /// No formato curto devolve `[]` — ver [shortIds].
  ///
  /// [shareItems] válido vence — é o único que preserva a ordem intercalada e
  /// o tipo. Sem ele (ou com ele inválido) cai nos legados: `sharepdfs`
  /// classificado pela extensão, depois `shareaudios` declarado como áudio.
  List<PlaylistEntry> get entries {
    if (isShortFormat) return const [];
    final raw = shareItems;
    if (raw != null) {
      final decoded = decodeShareItems(raw);
      if (decoded != null) return decoded;
    }
    return SavedPlaylist.entriesFromLegacyLists(
      pdfIds: parsePdfIdsFromSharePdfs(sharePdfs),
      audioIds: parseAudioIdsFromShareAudios(shareAudios),
    );
  }
}

/// Monta path relativo `/?shareitems=...&sharename=...&sharepdfs=...`.
///
/// Emite o param v2 **e** os dois legados: um app antigo lê `sharepdfs`/
/// `shareaudios` e importa a playlist sem a ordem intercalada; um app novo lê
/// `shareitems` e a preserva junto com o tipo de cada material.
///
/// Lança [ArgumentError] se [entries] vazio ou [shareName] em branco.
String buildPlaylistShareLocation({
  required List<PlaylistEntry> entries,
  required String shareName,
}) {
  if (entries.isEmpty) {
    throw ArgumentError.value(entries, 'entries', 'must not be empty');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }

  final pdfIds = <String>[
    for (final e in entries)
      if (!e.isAudio) e.id,
  ];
  final audioIds = <String>[
    for (final e in entries)
      if (e.isAudio) e.id,
  ];

  final params = <String, String>{
    UrlSyncParams.shareItems: encodeShareItems(entries),
    UrlSyncParams.shareName: shareName,
    if (pdfIds.isNotEmpty) UrlSyncParams.sharePdfs: pdfIds.join(','),
    if (audioIds.isNotEmpty) UrlSyncParams.shareAudios: audioIds.join(','),
  };

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.home}?$query';
}

/// Monta URL absoluta ([origin] + [buildPlaylistShareLocation]).
String buildPlaylistShareUrlFromEntries({
  required String origin,
  required List<PlaylistEntry> entries,
  required String shareName,
}) {
  final normalizedOrigin = origin.endsWith('/')
      ? origin.substring(0, origin.length - 1)
      : origin;
  return '$normalizedOrigin'
      '${buildPlaylistShareLocation(entries: entries, shareName: shareName)}';
}

/// Wrapper legado por duas listas — monta [PlaylistEntry] e delega a
/// [buildPlaylistShareUrlFromEntries].
///
/// Duas perdas, ambas inerentes a receber a entrada já separada em faces:
///
/// - **A ordem intercalada** vira partituras primeiro, áudios depois. Quem tem
///   a ordem única deve chamar [buildPlaylistShareUrlFromEntries].
/// - **O tipo é reclassificado pela extensão** ([PlaylistEntry.classified]):
///   um id com extensão de áudio passado em [pdfIds] sai como `a:` no
///   `shareitems` e em `shareaudios`, não em `sharepdfs` — o inverso do que o
///   chamador declarou. `audioIds` não sofre disso (é declaração, A8).
String buildPlaylistShareUrl({
  required String origin,
  required List<String> pdfIds,
  required String shareName,
  List<String> audioIds = const [],
}) {
  if (pdfIds.isEmpty && audioIds.isEmpty) {
    throw ArgumentError('pdfIds/audioIds must not both be empty');
  }
  return buildPlaylistShareUrlFromEntries(
    origin: origin,
    entries: <PlaylistEntry>[
      ...pdfIds.map(PlaylistEntry.classified),
      ...audioIds.map(PlaylistEntry.audio),
    ],
    shareName: shareName,
  );
}

/// Remove params de share de playlist de [uri] (UC-07 / UC-14, Fase 4.5).
Uri stripPlaylistShareParams(Uri uri) {
  final query = Map<String, String>.from(safeQueryParameters(uri))
    ..remove(UrlSyncParams.shareItems)
    ..remove(UrlSyncParams.sharePdfs)
    ..remove(UrlSyncParams.shareAudios)
    ..remove(UrlSyncParams.shareName)
    ..remove(UrlSyncParams.shortItems)
    ..remove(UrlSyncParams.shortName);
  if (query.isEmpty) {
    return uri.replace(queryParameters: const {});
  }
  return uri.replace(queryParameters: query);
}

/// Extrai params de share de [uri] quando `sharename` está presente.
///
/// `null` significa **"não é uma URL de share"** — sem `sharename` não há nada a
/// importar, e todo link comum do app passa por aqui. Um `sharename` sem
/// material devolve params com [PlaylistShareParams.entries] vazio: é um share,
/// só que inválido, e quem decide o aviso é `ImportSharedPlaylistFromUrl`
/// (`InvalidSharePlaylistException` → snackbar `playlistImportInvalidUrl`).
/// Devolver `null` aqui fazia o link sumir sem nenhuma mensagem (spec D.6).
PlaylistShareParams? parsePlaylistShareParams(Uri uri) {
  final query = safeQueryParameters(uri);

  // Formato curto (spec §1): `s` + `n` vencem os params legados.
  final shortRaw = query[UrlSyncParams.shortItems];
  final shortName = query[UrlSyncParams.shortName];
  if (shortRaw != null && shortName != null && shortName.isNotEmpty) {
    return PlaylistShareParams(
      shareName: shortName,
      shortIds: decodeShortShareIds(shortRaw),
    );
  }

  final shareName = query[UrlSyncParams.shareName];
  if (shareName == null || shareName.isEmpty) return null;

  return PlaylistShareParams(
    sharePdfs: query[UrlSyncParams.sharePdfs] ?? '',
    shareAudios: query[UrlSyncParams.shareAudios] ?? '',
    shareName: shareName,
    shareItems: query[UrlSyncParams.shareItems],
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
///
/// Um texto colado pode ser lido de três formas (URL, query crua, trecho depois
/// do `?`), e só uma delas costuma achar os materiais — «abre isto:
/// plpcg.com/?shareitems=…» vira uma chave lixo nas outras duas. Por isso um
/// resultado **sem entradas** fica guardado como último recurso, e a primeira
/// leitura com material vence. Quando nenhuma acha material, o params sem
/// entradas ainda é devolvido: aí é um share inválido, que precisa de aviso
/// (`playlistImportInvalidUrl`), não de silêncio (spec D.6).
PlaylistShareParams? extractShareParamsFromUserInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  PlaylistShareParams? named;
  PlaylistShareParams? withEntries(PlaylistShareParams? params) {
    if (params == null) return null;
    if (params.hasMaterial) return params;
    named ??= params;
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasQuery) {
    final fromUri = withEntries(parsePlaylistShareParams(uri));
    if (fromUri != null) return fromUri;
  }

  final queryOnly = trimmed.startsWith('?') ? trimmed.substring(1) : trimmed;
  final fromQuery = withEntries(
    parsePlaylistShareParams(Uri(query: queryOnly)),
  );
  if (fromQuery != null) return fromQuery;

  final hasShareName = trimmed.contains('${UrlSyncParams.shareName}=');
  final hasList =
      trimmed.contains('${UrlSyncParams.shareItems}=') ||
      trimmed.contains('${UrlSyncParams.sharePdfs}=') ||
      trimmed.contains('${UrlSyncParams.shareAudios}=');
  final hasShort =
      trimmed.contains('${UrlSyncParams.shortItems}=') &&
      trimmed.contains('${UrlSyncParams.shortName}=');
  if ((hasShareName && hasList) || hasShort) {
    final questionIndex = trimmed.indexOf('?');
    final queryPart = questionIndex >= 0
        ? trimmed.substring(questionIndex + 1)
        : trimmed;
    final fromFragment = withEntries(
      parsePlaylistShareParams(Uri(query: queryPart)),
    );
    if (fromFragment != null) return fromFragment;
  }

  return named;
}
