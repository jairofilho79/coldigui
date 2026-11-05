import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta o path do leitor de partituras editáveis (`/partitura`).
///
/// Reusa [UrlSyncParams.pdfId] como cifra e gestos: os quatro vivem no mesmo
/// espaço de ids, e o carrossel sincroniza o chip focado com o mesmo código.
String buildScoreReaderLocation({
  required String scoreId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{UrlSyncParams.pdfId: scoreId};
  if (titulo != null && titulo.isNotEmpty) {
    params[UrlSyncParams.titulo] = titulo;
  }
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.partitura}?$query';
}
