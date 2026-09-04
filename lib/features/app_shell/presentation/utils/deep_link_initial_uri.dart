import 'package:flutter/foundation.dart';

import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../../core/utils/safe_query_parameters.dart';

/// Resolve URI inicial de deep link na web.
///
/// Navegação direta com `/?sharepdfs=&sharename=` não usa esquema `plpcg://`;
/// [Uri.base] carrega os query params da URL do browser. Preferimos essa URI
/// quando contém params de share, mesmo que [AppLinks.getInitialLink] exista.
///
/// [browserUri] substitui [Uri.base] — exposto só para teste (Tarefa 8, spec
/// C.4): um `%` malformado em [Uri.base] nunca deve propagar exceção, então
/// tentamos recuperar os params válidos via [safeQueryParameters] antes de
/// cair para [fromAppLinks].
Uri? resolveWebInitialDeepLinkUri(Uri? fromAppLinks, {Uri? browserUri}) {
  final base = browserUri ?? Uri.base;
  try {
    if (parsePlaylistShareParams(base) != null) {
      return base;
    }
  } on FormatException catch (e) {
    debugPrint('[deep-link] query malformada na URL inicial: $e');
    final sanitized = base.replace(queryParameters: safeQueryParameters(base));
    if (parsePlaylistShareParams(sanitized) != null) {
      return sanitized;
    }
  }
  return fromAppLinks;
}
