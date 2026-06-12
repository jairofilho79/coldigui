import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path da Home com query params sincronizados (§2.5 MAPEAMENTO).
///
/// Omite params com valor padrão: [pesquisa] vazia, [materiais] todos
/// selecionados, [arranjo] vazio. Valores codificados via [Uri.encodeComponent].
String buildHomeLocation({
  String pesquisa = '',
  String? materiais,
  String? arranjo,
}) {
  final params = <String, String>{};

  if (pesquisa.isNotEmpty) {
    params[UrlSyncParams.pesquisa] = pesquisa;
  }
  if (materiais != null && materiais.isNotEmpty) {
    params[UrlSyncParams.materiais] = materiais;
  }
  if (arranjo != null && arranjo.isNotEmpty) {
    params[UrlSyncParams.arranjo] = arranjo;
  }

  if (params.isEmpty) return RoutePaths.home;

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.home}?$query';
}

/// Normaliza [uri] da Home para comparação com [buildHomeLocation].
///
/// Usado por [HomeScreen] para evitar `go()` redundante no sync de URL.
String buildHomeLocationFromUri(Uri uri) => buildHomeLocation(
      pesquisa: uri.queryParameters[UrlSyncParams.pesquisa] ?? '',
      materiais: uri.queryParameters[UrlSyncParams.materiais],
      arranjo: uri.queryParameters[UrlSyncParams.arranjo],
    );
