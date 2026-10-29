import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta o path do leitor de gestos.
///
/// Reusa [UrlSyncParams.pdfId] como o leitor de cifras: gesto, cifra e PDF
/// vivem no mesmo espaço de ids, e é isso que deixa [CarouselChips]
/// sincronizar o chip focado nas três rotas com o mesmo código.
String buildGestureReaderLocation({
  required String gestureId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{UrlSyncParams.pdfId: gestureId};
  if (titulo != null && titulo.isNotEmpty) params[UrlSyncParams.titulo] = titulo;
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.gestos}?$query';
}
