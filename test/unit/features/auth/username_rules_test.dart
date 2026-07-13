import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/domain/username_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsernameRules', () {
    test('normaliza e valida handle', () {
      expect(UsernameRules.normalize('  Ana_1 '), 'ana_1');
      expect(UsernameRules.validate('abc'), isNull);
      expect(UsernameRules.validate('ab'), 'invalid username');
      expect(UsernameRules.validate('Bad-Name'), 'invalid username');
    });
  });

  group('AuthUser username', () {
    test('serializa e desserializa username', () {
      const user = AuthUser(
        googleSub: 'sub',
        idToken: 'token',
        username: 'joao',
      );
      final restored = AuthUser.fromJson(user.toJson());
      expect(restored?.username, 'joao');
      expect(restored?.hasUsername, isTrue);
    });

    test('hasUsername false sem handle', () {
      const user = AuthUser(googleSub: 'sub', idToken: 'token');
      expect(user.hasUsername, isFalse);
    });
  });
}
