import 'package:coldigui/features/auth/data/oidc/oidc_callback.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_callback_inbox.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_capture.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fakes/fake_oidc_browser.dart';
import '../../../../support/oidc_test_tokens.dart';

void main() {
  const request = OidcRedirectRequest(nonce: 'n-1', csrf: 'c-1');
  final state = OidcRedirectRequest.encodeState(
    csrf: 'c-1',
    returnTo: '/perfil',
  );

  test('hash de rota normal: não toca em storage nem URL', () {
    final browser = FakeOidcBrowser(
      fragment: '/leitor?id=1',
      storedRequest: request.toJson(),
    );
    expect(captureOidcRedirectCallback(browser), isNull);
    expect(browser.storedRequest, isNotNull);
    expect(browser.clearRequestCalls, 0);
    expect(browser.replacedHashes, isEmpty);
  });

  test('callback válido: consome request e reescreve o hash para returnTo', () {
    final token = fakeIdToken(nonce: 'n-1');
    final browser = FakeOidcBrowser(
      fragment: 'id_token=$token&state=$state',
      storedRequest: request.toJson(),
    );

    final result = captureOidcRedirectCallback(browser);

    expect(result, isA<OidcCallbackSuccess>());
    expect((result! as OidcCallbackSuccess).idToken, token);
    expect(browser.clearRequestCalls, 1);
    expect(browser.storedRequest, isNull);
    expect(browser.replacedHashes, ['/perfil']);
  });

  test('cancelamento: idem, com Cancelled', () {
    final browser = FakeOidcBrowser(
      fragment: 'error=access_denied&state=$state',
      storedRequest: request.toJson(),
    );
    expect(captureOidcRedirectCallback(browser), isA<OidcCallbackCancelled>());
    expect(browser.clearRequestCalls, 1);
    expect(browser.replacedHashes, ['/perfil']);
  });

  test('sem request no storage: Invalid(request_missing) e URL limpa', () {
    final browser = FakeOidcBrowser(
      fragment: 'id_token=${fakeIdToken(nonce: 'n-1')}&state=$state',
    );
    final result = captureOidcRedirectCallback(browser);
    expect(result, isA<OidcCallbackInvalid>());
    expect((result! as OidcCallbackInvalid).reason, 'request_missing');
    expect(browser.replacedHashes, ['/perfil']);
  });

  test('request ilegível no storage conta como ausente', () {
    final browser = FakeOidcBrowser(
      fragment: 'id_token=${fakeIdToken(nonce: 'n-1')}&state=$state',
      storedRequest: 'lixo',
    );
    final result = captureOidcRedirectCallback(browser);
    expect((result! as OidcCallbackInvalid).reason, 'request_missing');
    expect(browser.clearRequestCalls, 1);
  });

  test('OidcCallbackInbox.take entrega uma vez', () {
    final inbox = OidcCallbackInbox(
      const OidcCallbackCancelled(error: 'x', returnTo: '/'),
    );
    expect(inbox.take(), isA<OidcCallbackCancelled>());
    expect(inbox.take(), isNull);
    expect(OidcCallbackInbox().take(), isNull);
  });
}
