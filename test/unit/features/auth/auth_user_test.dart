import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    googleSub: 'sub-1',
    sessionToken: 'sess_abc',
    email: 'a@b.com',
    name: 'Ana',
    username: 'ana',
  );

  test('toJson/fromJson fazem round-trip com sessionToken', () {
    final decoded = AuthUser.fromJson(user.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.googleSub, 'sub-1');
    expect(decoded.sessionToken, 'sess_abc');
    expect(decoded.email, 'a@b.com');
    expect(decoded.username, 'ana');
  });

  test('JSON antigo (idToken) não vira AuthUser', () {
    // A migração da sessão antiga (spec D12) lê esse JSON por fora.
    expect(
      AuthUser.fromJson({'googleSub': 'sub-1', 'idToken': 'eyJ.x.y'}),
      isNull,
    );
  });

  test('sessionToken vazio não vira AuthUser', () {
    expect(
      AuthUser.fromJson({'googleSub': 'sub-1', 'sessionToken': ''}),
      isNull,
    );
  });

  test('kSessionTokenPrefix é o prefixo do Worker', () {
    expect(kSessionTokenPrefix, 'sess_');
  });
}
