import 'dart:convert';

import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

String _b64(Map<String, Object?> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// JWT de mentira: assinatura nunca é validada, só o payload é lido.
String _jwt(Map<String, Object?> payload) =>
    '${_b64({'alg': 'RS256'})}.${_b64(payload)}.assinatura-falsa';

AuthUser _userWith(String idToken) =>
    AuthUser(googleSub: 'sub-1', idToken: idToken);

void main() {
  group('expiresAt', () {
    test('lê o claim exp do payload base64url', () {
      final exp = DateTime.utc(2030, 1, 2, 3, 4, 5);
      final user = _userWith(
        _jwt({'sub': 'sub-1', 'exp': exp.millisecondsSinceEpoch ~/ 1000}),
      );

      expect(user.expiresAt, exp);
      expect(user.expiresAt!.isUtc, isTrue);
    });

    test('aceita payload sem padding base64', () {
      // 'exp' escolhido para o payload não ser múltiplo de 4 bytes.
      final user = _userWith(_jwt({'exp': 1893456000, 'x': 'a'}));

      expect(
        user.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1893456000 * 1000, isUtc: true),
      );
    });

    test('devolve null quando o token não tem três partes', () {
      expect(_userWith('nao-e-um-jwt').expiresAt, isNull);
    });

    test('devolve null quando o payload não é base64url válido', () {
      expect(_userWith('a.!!!!.c').expiresAt, isNull);
    });

    test('devolve null quando o payload não é um objeto JSON', () {
      final user = _userWith(
        'a.${base64Url.encode(utf8.encode('[1,2,3]')).replaceAll('=', '')}.c',
      );

      expect(user.expiresAt, isNull);
    });

    test('devolve null quando o claim exp está ausente ou não é número', () {
      expect(_userWith(_jwt({'sub': 'x'})).expiresAt, isNull);
      expect(_userWith(_jwt({'exp': 'amanhã'})).expiresAt, isNull);
    });
  });

  group('isExpired / expiresSoon', () {
    AuthUser userExpiringIn(Duration delta) => _userWith(
      _jwt({
        'exp': DateTime.now().toUtc().add(delta).millisecondsSinceEpoch ~/ 1000,
      }),
    );

    test('token válido por horas não está expirado nem expirando', () {
      final user = userExpiringIn(const Duration(hours: 2));

      expect(user.isExpired, isFalse);
      expect(user.expiresSoon, isFalse);
    });

    test('token vencido está expirado e expirando', () {
      final user = userExpiringIn(const Duration(minutes: -1));

      expect(user.isExpired, isTrue);
      expect(user.expiresSoon, isTrue);
    });

    test('token dentro da margem está expirando mas ainda não expirado', () {
      final user = userExpiringIn(const Duration(seconds: 30));

      expect(user.isExpired, isFalse);
      expect(user.expiresSoon, isTrue);
    });

    test('sem claim exp o token não é tratado como expirado', () {
      final user = _userWith(_jwt({'sub': 'x'}));

      expect(user.isExpired, isFalse);
      expect(user.expiresSoon, isFalse);
    });
  });
}
