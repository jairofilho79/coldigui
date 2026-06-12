import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path do leitor PDF com query params (UC-04 / UC-11).
///
/// Retorna [RoutePaths.reader] com `file` obrigatório e `pdfId`/`titulo`/
/// `subtitulo` opcionais. [UrlSyncParams.pdfId] habilita navegação carousel
/// in-reader (Fase 4.7). Valores codificados via [Uri.encodeComponent].
///
/// Exemplo: `buildReaderLocation(file: '/tmp/x.pdf', pdfId: 'assets/Col/1.pdf', titulo: 'Aleluia')`
/// → `/leitor?file=…&pdfId=…&titulo=Aleluia`
String buildReaderLocation({
  required String file,
  String? pdfId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{
    UrlSyncParams.file: file,
  };

  if (pdfId != null && pdfId.isNotEmpty) {
    params[UrlSyncParams.pdfId] = pdfId;
  }
  if (titulo != null && titulo.isNotEmpty) {
    params[UrlSyncParams.titulo] = titulo;
  }
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.reader}?$query';
}
