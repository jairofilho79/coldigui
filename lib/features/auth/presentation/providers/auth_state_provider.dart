import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../data/auth_remote_datasource.dart';
import '../../data/auth_session_store.dart';
import '../../domain/entities/auth_user.dart';

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore();
});

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioProvider));
});

/// Estado de autenticação Google (null = deslogado).
final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  Future<void>? _googleInitFuture;

  @override
  Future<AuthUser?> build() async {
    ref.onDispose(() {
      unawaited(_authSub?.cancel());
      _authSub = null;
    });

    await ensureGoogleInitialized();

    final stored = ref.read(authSessionStoreProvider).read();
    if (stored == null) return null;

    try {
      final remote = ref.read(authRemoteDatasourceProvider);
      final user = await remote.establishSession(stored.idToken);
      ref.read(authSessionStoreProvider).write(user);
      return user;
    } on Object {
      ref.read(authSessionStoreProvider).clear();
      return null;
    }
  }

  /// Único ponto que chama [GoogleSignIn.initialize] (idempotente).
  Future<void> ensureGoogleInitialized() {
    if (AppConfig.isGoogleClientIdMissing) {
      return Future<void>.value();
    }
    return _googleInitFuture ??= _initGoogle();
  }

  Future<void> _initGoogle() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(clientId: AppConfig.googleClientIdWeb);
    _authSub ??= signIn.authenticationEvents.listen(
      _onGoogleAuthEvent,
      onError: (_) {},
    );
  }

  Future<void> _onGoogleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(:final user):
        await _completeSignIn(user);
      case GoogleSignInAuthenticationEventSignOut():
        ref.read(authSessionStoreProvider).clear();
        state = const AsyncData(null);
    }
  }

  /// Sign-in explícito (plataformas com `supportsAuthenticate`).
  Future<void> signInWithGoogle() async {
    if (AppConfig.isGoogleClientIdMissing) {
      throw StateError('GOOGLE_CLIENT_ID_WEB ausente no build');
    }
    await ensureGoogleInitialized();
    state = const AsyncLoading();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      await _completeSignIn(account);
    } on Object catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> _completeSignIn(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('google_id_token_missing');
    }

    state = const AsyncLoading();
    try {
      final user = await ref
          .read(authRemoteDatasourceProvider)
          .establishSession(idToken);
      ref.read(authSessionStoreProvider).write(user);
      state = AsyncData(user);
    } on Object catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    ref.read(authSessionStoreProvider).clear();
    state = const AsyncData(null);
    try {
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Sessão local já limpa.
    }
  }
}
