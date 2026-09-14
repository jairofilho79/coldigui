// test/unit/features/auth/auth_session_store_test.dart
//
// Roda na VM → é a variante stub (nativo). A web só muda o backend
// (`localStorage`); a lógica de (de)serialização é a mesma, estática, no stub.
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const user = AuthUser(
    googleSub: 'sub-1',
    sessionToken: 'sess_a',
    name: 'Ana',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'write persiste em SharedPreferences e um store novo lê de volta',
    () async {
      final prefs = await SharedPreferences.getInstance();
      AuthSessionStore(prefs: prefs).write(user);

      final again = AuthSessionStore(prefs: prefs).read();
      expect(again?.googleSub, 'sub-1');
      expect(again?.sessionToken, 'sess_a');
      expect(prefs.getString('plpcg_auth_session'), isNotNull);
    },
  );

  test('clear apaga da memória e do SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(prefs: prefs)..write(user);
    store.clear();
    expect(store.read(), isNull);
    expect(prefs.getString('plpcg_auth_session'), isNull);
  });

  test('sem prefs é só memória (costura de teste)', () {
    final store = AuthSessionStore()..write(user);
    expect(store.read()?.sessionToken, 'sess_a');
    expect(AuthSessionStore().read(), isNull);
  });
}
