import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/utils/retryable_init.dart';
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

/// [GoogleSignIn.initialize] só pode rodar uma vez no processo (plugin web).
///
/// Usa [RetryableInit] para não memoizar falha: se a inicialização falhar,
/// a próxima chamada tenta de novo em vez de re-aguardar o mesmo erro.
final RetryableInit<void> _googleSignInInit = RetryableInit(
  () => GoogleSignIn.instance.initialize(clientId: AppConfig.googleClientIdWeb),
);

/// Inicializa o SDK do Google e devolve o stream de eventos de autenticação.
typedef GoogleSignInInitializer =
    Future<Stream<GoogleSignInAuthenticationEvent>> Function();

/// Costura de teste sobre o SDK do Google — nada do plugin roda na VM.
final googleSignInInitializerProvider = Provider<GoogleSignInInitializer>((
  ref,
) {
  return () async {
    if (AppConfig.isGoogleClientIdMissing) {
      debugPrint(
        '[auth] GOOGLE_CLIENT_ID_WEB ausente no build — '
        'login com Google indisponível',
      );
      throw StateError('google_client_id_missing');
    }
    await _googleSignInInit();
    return GoogleSignIn.instance.authenticationEvents;
  };
});

/// `true` quando o SDK do Google não pôde ser inicializado — bloqueado por
/// extensão/CORS, offline ou `GOOGLE_CLIENT_ID_WEB` ausente no build.
///
/// Desabilita **só o botão de login**: a sessão já armazenada continua valendo
/// e o sync segue rodando, senão o usuário parece deslogado sem estar (A5).
final googleSignInUnavailableProvider =
    NotifierProvider<GoogleSignInUnavailableNotifier, bool>(
      GoogleSignInUnavailableNotifier.new,
    );

class GoogleSignInUnavailableNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void report({required bool unavailable}) => state = unavailable;
}

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  @override
  Future<AuthUser?> build() async {
    ref.onDispose(() {
      unawaited(_authSub?.cancel());
      _authSub = null;
    });

    final unavailability = ref.read(googleSignInUnavailableProvider.notifier);
    try {
      await ensureGoogleInitialized();
      unavailability.report(unavailable: false);
    } on Object catch (error) {
      // SDK bloqueado/ausente desabilita só o login — a sessão armazenada
      // continua válida e o sync não pode parar por causa disso (A5).
      debugPrint('[auth] inicialização do Google Sign-In falhou: $error');
      unavailability.report(unavailable: true);
    }

    final stored = ref.read(authSessionStoreProvider).read();
    if (stored == null) return null;

    try {
      final remote = ref.read(authRemoteDatasourceProvider);
      final user = await remote.establishSession(stored.idToken);
      ref.read(authSessionStoreProvider).write(user);
      return user;
    } on AuthUnauthorizedException {
      // Worker recusou o idToken — sessão realmente inválida.
      ref.read(authSessionStoreProvider).clear();
      return null;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == null || statusCode >= 500) {
        // Rede/timeout ou 5xx: mantém a sessão local como "não verificada"
        // em vez de deslogar por uma falha transitória do backend.
        debugPrint('[auth] sessão mantida sem verificação: $e');
        return stored;
      }
      ref.read(authSessionStoreProvider).clear();
      return null;
    } on Object {
      ref.read(authSessionStoreProvider).clear();
      return null;
    }
  }

  /// Único ponto que chama [GoogleSignIn.initialize] (idempotente no processo).
  ///
  /// Lança quando o SDK não sobe (inclusive `GOOGLE_CLIENT_ID_WEB` ausente).
  Future<void> ensureGoogleInitialized() async {
    final events = await ref.read(googleSignInInitializerProvider)();
    _authSub ??= events.listen(
      _onGoogleAuthEvent,
      onError: (Object error) =>
          debugPrint('[auth] evento do Google Sign-In em erro: $error'),
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

  /// Cadastra username único e atualiza a sessão local.
  Future<void> setUsername(String username) async {
    final current = state.asData?.value;
    if (current == null) {
      throw StateError('not_authenticated');
    }
    final value = await ref
        .read(authRemoteDatasourceProvider)
        .setUsername(idToken: current.idToken, username: username);
    final updated = current.copyWith(username: value);
    ref.read(authSessionStoreProvider).write(updated);
    state = AsyncData(updated);
  }
}
