import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path da /biblioteca com query params sincronizados (spec fim-fonte
/// §2.5).
///
/// Filtros do catálogo (os mesmos da página inicial): CSV de [tonality],
/// [rhythm], [category], [tags] (nomes) e [materialKinds] (ids de kind);
/// omitidos quando vazios. Vista: [ordenar] `numero`, [itensPorPagina] `10` e
/// [pagina] `1` são omitidos. Valores codificados via [Uri.encodeComponent].
String buildLibraryLocation({
  String? tonality,
  String? rhythm,
  String? category,
  String? tags,
  String? materialKinds,
  String ordenar = UrlSyncParams.defaultOrdenar,
  String itensPorPagina = UrlSyncParams.defaultItensPorPagina,
  String pagina = UrlSyncParams.defaultPagina,
}) {
  final params = <String, String>{};

  void put(String key, String? value) {
    if (value != null && value.isNotEmpty) params[key] = value;
  }

  put(UrlSyncParams.tonality, tonality);
  put(UrlSyncParams.rhythm, rhythm);
  put(UrlSyncParams.category, category);
  put(UrlSyncParams.tags, tags);
  put(UrlSyncParams.materialKinds, materialKinds);
  if (ordenar != UrlSyncParams.defaultOrdenar) {
    params[UrlSyncParams.ordenar] = ordenar;
  }
  if (itensPorPagina != UrlSyncParams.defaultItensPorPagina) {
    params[UrlSyncParams.itensPorPagina] = itensPorPagina;
  }
  if (pagina != UrlSyncParams.defaultPagina) {
    params[UrlSyncParams.pagina] = pagina;
  }

  if (params.isEmpty) return RoutePaths.library;

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.library}?$query';
}

/// Normaliza [uri] da /biblioteca para comparação com [buildLibraryLocation].
///
/// Params que não existem mais (`fonte`, `materiais`, `arranjo`,
/// `arranjoEspecial`) são ignorados — um link antigo abre sem erro e o sync
/// de URL os tira.
String buildLibraryLocationFromUri(Uri uri) => buildLibraryLocation(
  tonality: uri.queryParameters[UrlSyncParams.tonality],
  rhythm: uri.queryParameters[UrlSyncParams.rhythm],
  category: uri.queryParameters[UrlSyncParams.category],
  tags: uri.queryParameters[UrlSyncParams.tags],
  materialKinds: uri.queryParameters[UrlSyncParams.materialKinds],
  ordenar:
      uri.queryParameters[UrlSyncParams.ordenar] ??
      UrlSyncParams.defaultOrdenar,
  itensPorPagina:
      uri.queryParameters[UrlSyncParams.itensPorPagina] ??
      UrlSyncParams.defaultItensPorPagina,
  pagina:
      uri.queryParameters[UrlSyncParams.pagina] ?? UrlSyncParams.defaultPagina,
);
