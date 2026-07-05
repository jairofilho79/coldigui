import '../../../../core/utils/playlist_share_url_builder.dart';

/// Resolve URI inicial de deep link na web.
///
/// Navegação direta com `/?sharepdfs=&sharename=` não usa esquema `plpcg://`;
/// [Uri.base] carrega os query params da URL do browser. Preferimos essa URI
/// quando contém params de share, mesmo que [AppLinks.getInitialLink] exista.
Uri? resolveWebInitialDeepLinkUri(Uri? fromAppLinks) {
  final browserUri = Uri.base;
  if (parsePlaylistShareParams(browserUri) != null) {
    return browserUri;
  }
  return fromAppLinks;
}
