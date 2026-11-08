import '../../../../core/constants/share_config.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../../core/utils/praise_url_builder.dart';

/// Returns the canonical app link for supported deep links hosted on v2.
Uri? appLinkUriForV2WebDeepLink(Uri uri) {
  if (uri.host.toLowerCase() != 'v2.plpcg.com') return null;

  final playlist = parsePlaylistShareParams(uri);
  if (parsePraiseId(uri) == null && !(playlist?.hasMaterial ?? false)) {
    return null;
  }

  final appOrigin = Uri.parse(ShareConfig.appOrigin);
  return uri.replace(
    scheme: appOrigin.scheme,
    userInfo: '',
    host: appOrigin.host,
    port: appOrigin.port,
  );
}
