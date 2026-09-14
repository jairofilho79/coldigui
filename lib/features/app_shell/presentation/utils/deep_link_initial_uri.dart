import 'package:flutter/foundation.dart';

import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../../core/utils/safe_query_parameters.dart';
import '../../../live/domain/live_room_link.dart';

/// Resolve URI inicial de deep link na web.
///
/// Navegação direta com `/?sharepdfs=&sharename=` não usa esquema `plpcg://`;
/// [Uri.base] carrega os query params da URL do browser. Preferimos essa URI
/// quando contém params de share, mesmo que [AppLinks.getInitialLink] exista.
/// O mesmo vale para `?live=<code>` — o 302 do Worker para `/ao-vivo/<code>`
/// (spec lista-ao-vivo D6).
///
/// [browserUri] substitui [Uri.base] — exposto só para teste (Tarefa 8, spec
/// C.4): um `%` malformado em [Uri.base] nunca deve propagar exceção, então
/// tentamos recuperar os params válidos via [safeQueryParameters] antes de
/// cair para [fromAppLinks].
Uri? resolveWebInitialDeepLinkUri(Uri? fromAppLinks, {Uri? browserUri}) {
  final base = browserUri ?? Uri.base;
  // `parsePlaylistShareParams` já lê a query por [safeQueryParameters] e não
  // lança (Tarefa 3): o `%` malformado só aparece para quem receber esta URI
  // de volta (router, listener), então a saneamos aqui em vez de esperar a
  // exceção.
  if (parsePlaylistShareParams(base) == null &&
      parseLiveRoomCode(base) == null) {
    return fromAppLinks;
  }
  if (_queryDecodes(base)) return base;
  debugPrint('[deep-link] query malformada na URL inicial: ${base.query}');
  return base.replace(queryParameters: safeQueryParameters(base));
}

bool _queryDecodes(Uri uri) {
  try {
    uri.queryParameters;
    return true;
  } on FormatException {
    return false;
  }
}
