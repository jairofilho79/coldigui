import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'oidc_browser.dart';
import 'oidc_redirect_request.dart';

OidcBrowser createOidcBrowser() => const _WebOidcBrowser();

class _WebOidcBrowser implements OidcBrowser {
  const _WebOidcBrowser();

  @override
  Uri get origin => Uri.parse(web.window.location.origin);

  @override
  String get fragment {
    final hash = web.window.location.hash;
    return hash.startsWith('#') ? hash.substring(1) : hash;
  }

  @override
  bool get isStandaloneDisplay {
    final media = web.window.matchMedia('(display-mode: standalone)').matches;
    // `navigator.standalone` é só do Safari iOS — fora do `package:web`.
    final standalone = web.window.navigator
        .getProperty<JSBoolean?>('standalone'.toJS)
        ?.toDart;
    return media || (standalone ?? false);
  }

  @override
  String? readRequest() =>
      web.window.sessionStorage.getItem(kOidcRequestStorageKey);

  @override
  void writeRequest(String json) =>
      web.window.sessionStorage.setItem(kOidcRequestStorageKey, json);

  @override
  void clearRequest() =>
      web.window.sessionStorage.removeItem(kOidcRequestStorageKey);

  @override
  void navigate(Uri uri) => web.window.location.assign(uri.toString());

  @override
  void replaceHash(String path) =>
      web.window.history.replaceState(null, '', '#$path');
}
