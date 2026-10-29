import 'dart:convert';
import 'dart:math';

import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = OidcRedirectRequest(nonce: 'nonce-1', csrf: 'csrf-1');
  final origin = Uri.parse('https://v2.plpcg.com');

  group('authorizationUri', () {
    final uri = request.authorizationUri(
      clientId: 'cid.apps.googleusercontent.com',
      origin: origin,
      returnTo: '/perfil',
    );

    test('aponta para o endpoint OIDC do Google', () {
      expect(uri.scheme, 'https');
      expect(uri.host, 'accounts.google.com');
      expect(uri.path, '/o/oauth2/v2/auth');
    });

    test('carrega todos os parâmetros do fluxo implícito', () {
      final q = uri.queryParameters;
      expect(q['client_id'], 'cid.apps.googleusercontent.com');
      expect(q['redirect_uri'], 'https://v2.plpcg.com/');
      expect(q['response_type'], 'id_token');
      expect(q['scope'], 'openid email profile');
      expect(q['prompt'], 'select_account');
      expect(q['nonce'], 'nonce-1');
    });

    test('state decodifica para csrf + returnTo', () {
      final state = OidcRedirectRequest.decodeState(
        uri.queryParameters['state'],
      );
      expect(state, {'csrf': 'csrf-1', 'returnTo': '/perfil'});
    });

    test('redirect_uri termina em barra mesmo com origem sem barra', () {
      final u = request.authorizationUri(
        clientId: 'x',
        origin: Uri.parse('http://localhost:8080'),
        returnTo: '/',
      );
      expect(u.queryParameters['redirect_uri'], 'http://localhost:8080/');
    });
  });

  group('encodeState/decodeState', () {
    test('é base64url sem padding', () {
      final s = OidcRedirectRequest.encodeState(
        csrf: 'a',
        returnTo: '/listas/publicas?x=1',
      );
      expect(s, isNot(contains('=')));
      expect(s, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(OidcRedirectRequest.decodeState(s), {
        'csrf': 'a',
        'returnTo': '/listas/publicas?x=1',
      });
    });

    test('lixo devolve null', () {
      expect(OidcRedirectRequest.decodeState(null), isNull);
      expect(OidcRedirectRequest.decodeState(''), isNull);
      expect(OidcRedirectRequest.decodeState('%%%'), isNull);
      expect(
        OidcRedirectRequest.decodeState(base64Url.encode(utf8.encode('[1]'))),
        isNull,
      );
      expect(
        OidcRedirectRequest.decodeState(
          base64Url.encode(utf8.encode('{"csrf":1}')),
        ),
        isNull,
      );
    });
  });

  group('generate', () {
    test('nonce e csrf são base64url de 32 bytes, distintos', () {
      final r = OidcRedirectRequest.generate(Random(7));
      expect(r.nonce, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(r.csrf, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(r.nonce, isNot(r.csrf));
    });

    test('duas gerações não repetem', () {
      expect(
        OidcRedirectRequest.generate().nonce,
        isNot(OidcRedirectRequest.generate().nonce),
      );
    });
  });

  group('toJson/fromJson', () {
    test('round-trip', () {
      final back = OidcRedirectRequest.fromJson(request.toJson());
      expect(back?.nonce, 'nonce-1');
      expect(back?.csrf, 'csrf-1');
    });

    test('lixo devolve null', () {
      expect(OidcRedirectRequest.fromJson(null), isNull);
      expect(OidcRedirectRequest.fromJson('nope'), isNull);
      expect(OidcRedirectRequest.fromJson('{"nonce":"a"}'), isNull);
    });
  });
}
