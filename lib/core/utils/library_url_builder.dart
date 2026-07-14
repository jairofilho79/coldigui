import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path da Biblioteca com query params sincronizados (§2.5 MAPEAMENTO).
///
/// Omite params com valor padrão: [materiais] todos selecionados, [arranjo] e
/// [arranjoEspecial] vazios, [ordenar] `numero`, [itensPorPagina] `10`,
/// [pagina] `1`, [fonte] `plpcg`. Valores codificados via [Uri.encodeComponent].
String buildLibraryLocation({
  String? fonte,
  String? materiais,
  String? arranjo,
  String? arranjoEspecial,
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

  if (fonte != null && fonte.isNotEmpty) {
    params[UrlSyncParams.fonte] = fonte;
  }
  if (materiais != null && materiais.isNotEmpty) {
    params[UrlSyncParams.materiais] = materiais;
  }
  if (arranjo != null && arranjo.isNotEmpty) {
    params[UrlSyncParams.arranjo] = arranjo;
  }
  if (arranjoEspecial != null && arranjoEspecial.isNotEmpty) {
    params[UrlSyncParams.arranjoEspecial] = arranjoEspecial;
  }
  if (tonality != null && tonality.isNotEmpty) {
    params[UrlSyncParams.tonality] = tonality;
  }
  if (rhythm != null && rhythm.isNotEmpty) {
    params[UrlSyncParams.rhythm] = rhythm;
  }
  if (category != null && category.isNotEmpty) {
    params[UrlSyncParams.category] = category;
  }
  if (tags != null && tags.isNotEmpty) {
    params[UrlSyncParams.tags] = tags;
  }
  if (materialKinds != null && materialKinds.isNotEmpty) {
    params[UrlSyncParams.materialKinds] = materialKinds;
  }
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

/// Normaliza [uri] da Biblioteca para comparação com [buildLibraryLocation].
///
/// Usado por [LibraryScreen] para evitar `go()` redundante no sync de URL.
String buildLibraryLocationFromUri(Uri uri) => buildLibraryLocation(
  fonte: uri.queryParameters[UrlSyncParams.fonte],
  materiais: uri.queryParameters[UrlSyncParams.materiais],
  arranjo: uri.queryParameters[UrlSyncParams.arranjo],
  arranjoEspecial: uri.queryParameters[UrlSyncParams.arranjoEspecial],
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
