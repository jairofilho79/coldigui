import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta o path do leitor de letra — espelho de `buildChordReaderLocation`.
String buildLyricsReaderLocation({
  required String praiseId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{UrlSyncParams.praiseId: praiseId};
  if (titulo != null && titulo.isNotEmpty) {
    params[UrlSyncParams.titulo] = titulo;
  }
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.lyrics}?$query';
}
