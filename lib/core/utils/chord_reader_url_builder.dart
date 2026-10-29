import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path do leitor de cifras.
///
/// Reusa [UrlSyncParams.pdfId] em vez de uma chave própria: cifra e PDF vivem no
/// mesmo espaço de ids, e é isso que deixa [CarouselChips] sincronizar o chip
/// focado nas duas rotas com o mesmo código.
String buildChordReaderLocation({
  required String chordId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{UrlSyncParams.pdfId: chordId};

  if (titulo != null && titulo.isNotEmpty) {
    params[UrlSyncParams.titulo] = titulo;
  }
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.chords}?$query';
}
