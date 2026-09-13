// ignore_for_file: prefer_const_constructors
import 'package:coldigui/features/auth/data/oidc/oidc_callback.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/oidc_test_tokens.dart';

void main() {
  const request = OidcRedirectRequest(nonce: 'n-1', csrf: 'c-1');
  final goodState = OidcRedirectRequest.encodeState(
    csrf: 'c-1',
    returnTo: '/perfil',
  );
  final wrongCsrfState = OidcRedirectRequest.encodeState(
    csrf: 'c-X',
    returnTo: '/perfil',
  );

  OidcCallbackResult? parse(
    String fragment, {
    OidcRedirectRequest? req = request,
  }) => OidcCallbackParser.parse(fragment: fragment, request: req);

  group('não é callback', () {
    test('fragmento vazio', () => expect(parse(''), isNull));
    test('rota do go_router', () => expect(parse('/leitor?id=1'), isNull));
    test(
      'rota com state na query',
      () => expect(parse('/x?state=abc'), isNull),
    );
    test('sem state', () => expect(parse('foo=bar'), isNull));
    test('sem state com id_token', () => expect(parse('id_token=abc'), isNull));
  });

  group('sucesso', () {
    test('id_token com nonce certo e csrf certo', () {
      final token = fakeIdToken(nonce: 'n-1');
      final r = parse('id_token=$token&state=$goodState');
      expect(r, isA<OidcCallbackSuccess>());
      expect((r! as OidcCallbackSuccess).idToken, token);
      expect(r.returnTo, '/perfil');
    });

    test('ordem dos parâmetros não importa', () {
      final token = fakeIdToken(nonce: 'n-1');
      final r = parse(
        'state=$goodState&authuser=0&id_token=$token&prompt=none',
      );
      expect(r, isA<OidcCallbackSuccess>());
    });
  });

  group('cancelamento', () {
    test('error=access_denied', () {
      final r = parse('error=access_denied&state=$goodState');
      expect(r, isA<OidcCallbackCancelled>());
      expect((r! as OidcCallbackCancelled).error, 'access_denied');
      expect(r.returnTo, '/perfil');
    });
  });

  group('inválido', () {
    OidcCallbackInvalid invalid(OidcCallbackResult? r) {
      expect(r, isA<OidcCallbackInvalid>());
      return r! as OidcCallbackInvalid;
    }

    test('request ausente → request_missing (contexto)', () {
      final r = invalid(
        parse(
          'id_token=${fakeIdToken(nonce: 'n-1')}&state=$goodState',
          req: null,
        ),
      );
      expect(r.reason, 'request_missing');
      expect(r.isContextMismatch, isTrue);
      expect(r.returnTo, '/perfil');
    });

    test('csrf diferente → csrf_mismatch (contexto)', () {
      final r = invalid(
        parse('id_token=${fakeIdToken(nonce: 'n-1')}&state=$wrongCsrfState'),
      );
      expect(r.reason, 'csrf_mismatch');
      expect(r.isContextMismatch, isTrue);
    });

    test('state indecifrável → state_missing', () {
      final r = invalid(
        parse('id_token=${fakeIdToken(nonce: 'n-1')}&state=@@@'),
      );
      expect(r.reason, 'state_missing');
      expect(r.isContextMismatch, isFalse);
      expect(r.returnTo, '/');
    });

    test('nonce diferente → nonce_mismatch', () {
      final r = invalid(
        parse('id_token=${fakeIdToken(nonce: 'outro')}&state=$goodState'),
      );
      expect(r.reason, 'nonce_mismatch');
      expect(r.isContextMismatch, isFalse);
    });

    test('JWT com 2 segmentos → jwt_malformed', () {
      expect(
        invalid(parse('id_token=a.b&state=$goodState')).reason,
        'jwt_malformed',
      );
    });

    test('payload não-JSON → jwt_malformed', () {
      expect(
        invalid(parse('id_token=a.bm90LWpzb24.c&state=$goodState')).reason,
        'jwt_malformed',
      );
    });

    test('state ok mas sem id_token nem error → jwt_malformed', () {
      expect(invalid(parse('state=$goodState')).reason, 'jwt_malformed');
    });
  });

  group('sanitizeReturnTo', () {
    test('aceita caminhos da app', () {
      expect(OidcCallbackParser.sanitizeReturnTo('/perfil'), '/perfil');
      expect(
        OidcCallbackParser.sanitizeReturnTo('/listas/publicas?x=1&y=2'),
        '/listas/publicas?x=1&y=2',
      );
      expect(
        OidcCallbackParser.sanitizeReturnTo('/materiais-favoritos'),
        '/materiais-favoritos',
      );
    });

    test('rejeita o resto', () {
      expect(OidcCallbackParser.sanitizeReturnTo(null), '/');
      expect(OidcCallbackParser.sanitizeReturnTo(''), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('//evil.com'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('https://x'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('perfil'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('/a b'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('/a#b'), '/');
    });
  });

  test('OidcContextMismatchException carrega a razão', () {
    expect(
      OidcContextMismatchException('csrf_mismatch').toString(),
      contains('csrf_mismatch'),
    );
  });
}
