// test/support/fakes/fake_auth_notifier.dart
//
// Fake de [AuthNotifier]: devolve um usuário fixo (ou `null`) sem tocar em
// `GoogleSignIn`/rede — usado por testes que só precisam de um
// `authStateProvider` estável (ex.: o `sessionToken` do `hello` do gestor).
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this._user);
  final AuthUser? _user;
  @override
  Future<AuthUser?> build() async => _user;

  /// Muda o usuário depois do build — para testes de login/logout (ex.:
  /// `MyLiveRoomNotifier`, que reage a `ref.listen(authStateProvider, …)`).
  void setUser(AuthUser? user) {
    state = AsyncData(user);
  }
}
