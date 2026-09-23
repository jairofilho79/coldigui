import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path da página inicial com query params sincronizados (spec
/// fim-fonte §2.5).
///
/// [pesquisa] vazia é omitida; os filtros do catálogo (os mesmos da
/// /biblioteca) vão em CSV — [tags] por nome, [materialKinds] por id de kind
/// — e são omitidos quando vazios. Valores codificados via
/// [Uri.encodeComponent].
String buildHomeLocation({
  String pesquisa = '',
  String? tonality,
  String? rhythm,
  String? category,
  String? tags,
  String? materialKinds,
}) {
  final params = <String, String>{};

  void put(String key, String? value) {
    if (value != null && value.isNotEmpty) params[key] = value;
  }

  put(UrlSyncParams.pesquisa, pesquisa);
  put(UrlSyncParams.tonality, tonality);
  put(UrlSyncParams.rhythm, rhythm);
  put(UrlSyncParams.category, category);
  put(UrlSyncParams.tags, tags);
  put(UrlSyncParams.materialKinds, materialKinds);

  if (params.isEmpty) return RoutePaths.home;

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.home}?$query';
}

/// Normaliza [uri] da página inicial para comparação com [buildHomeLocation].
///
/// `materiais`/`arranjo` de links antigos são ignorados (spec §2.5).
String buildHomeLocationFromUri(Uri uri) => buildHomeLocation(
  pesquisa: uri.queryParameters[UrlSyncParams.pesquisa] ?? '',
  tonality: uri.queryParameters[UrlSyncParams.tonality],
  rhythm: uri.queryParameters[UrlSyncParams.rhythm],
  category: uri.queryParameters[UrlSyncParams.category],
  tags: uri.queryParameters[UrlSyncParams.tags],
  materialKinds: uri.queryParameters[UrlSyncParams.materialKinds],
);
