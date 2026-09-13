// test/support/fakes/fake_auth_remote_datasource.dart
//
// Fake compartilhada de [AuthRemoteDatasource] (E10) — os 4 arquivos que a
// duplicavam já convergiam num único formato (`establishSession` delegado a
// um callback); [FakeAuthRemoteDatasource.returning] cobre o caso mais
// simples (devolver sempre o mesmo usuário) sem precisar de um callback.
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:dio/dio.dart';

class FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  FakeAuthRemoteDatasource(this._behavior) : super(Dio());

  /// Sempre devolve [user] — atalho para quando não interessa simular erro.
  factory FakeAuthRemoteDatasource.returning(AuthUser user) =>
      FakeAuthRemoteDatasource((_) async => user);

  final Future<AuthUser> Function(String idToken) _behavior;

  @override
  Future<AuthUser> establishSession(String idToken) => _behavior(idToken);
}
