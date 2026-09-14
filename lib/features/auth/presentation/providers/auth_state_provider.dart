import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/utils/retryable_init.dart';
import '../../data/auth_remote_datasource.dart';
import '../../data/auth_session_store.dart';
import '../../data/oidc/oidc_browser.dart';
import '../../data/oidc/oidc_browser_factory.dart';
import '../../data/oidc/oidc_callback.dart';
import '../../data/oidc/oidc_callback_inbox.dart';
import '../../data/oidc/oidc_redirect_request.dart';
import '../../domain/entities/auth_user.dart';

/// Persistência da sessão: `localStorage` na web, `SharedPreferences` no
/// nativo. Testes que exercitam o `AuthNotifier` real sobrescrevem este
/// provider com `AuthSessionStore()` (só memória).
final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(prefs: ref.read(sharedPreferencesProvider));
});

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioProvider));
});

/// Client ID OAuth Web. Costura de teste: `String.fromEnvironment` é vazio no
/// `flutter test`, então quem precisa do id lê daqui, nunca de [AppConfig].
final googleClientIdProvider = Provider<String>(
  (ref) => AppConfig.googleClientIdWeb,
);

/// Acesso ao navegador para o login por redirect (spec §3.4).
final oidcBrowserProvider = Provider<OidcBrowser>((ref) => createOidcBrowser());

/// Callback do Google capturado em `main()` (spec D5/D9). `main.dart`
/// sobrescreve com o inbox preenchido; o default vazio serve a testes e ao
/// nativo.
final oidcCallbackInboxProvider = Provider<OidcCallbackInbox>(
  (ref) => OidcCallbackInbox(),
);

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

/// Reautenticação silenciosa: devolve um `id_token` novo sem abrir UI.
///
/// `null` = não deu (SDK bloqueado, sessão Google encerrada, sem `id_token`).
typedef GoogleSilentIdTokenRefresher = Future<String?> Function();

/// Costura de teste sobre `attemptLightweightAuthentication` (nada do plugin
/// roda na VM).
final googleSilentIdTokenRefresherProvider =
    Provider<GoogleSilentIdTokenRefresher>((ref) {
      return () async {
        // Na web o plugin devolve `null` (e não um Future) quando o SDK não
        // está disponível — precisa ser sessão expirada, nunca um crash.
        final attempt = GoogleSignIn.instance
            .attemptLightweightAuthentication();
        if (attempt == null) return null;
        final account = await attempt;
        return account?.authentication.idToken;
      };
    });

/// `true` quando a renovação silenciosa do `id_token` falhou: a sessão local
/// segue existindo, mas o backend vai recusá-la até o usuário entrar de novo.
///
/// Consumido pelo banner "Sessão expirada" no perfil.
final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, bool>(
  SessionExpiredNotifier.new,
);

class SessionExpiredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markExpired() => state = true;

  void clear() => state = false;
}

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  /// Refresh em voo — vários 401 simultâneos compartilham uma só tentativa.
  Future<String?>? _refreshInFlight;

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

    // Callback do redirect OIDC tem precedência sobre a sessão armazenada
    // (spec D9): o usuário acabou de escolher uma conta no Google.
    final pending = ref.read(oidcCallbackInboxProvider).take();
    switch (pending) {
      case OidcCallbackSuccess(:final idToken):
        try {
          return await _establishAndStore(idToken);
        } on Object {
          ref.read(authSessionStoreProvider).clear();
          rethrow;
        }
      case OidcCallbackInvalid(:final reason, :final isContextMismatch):
        if (isContextMismatch) {
          // Botão Voltar depois do login re-dispara o callback já consumido
          // (request/csrf não batem mais) sobre uma aba que já tem sessão
          // válida — spec D9/D15. Só é de fato um mismatch de contexto (e
          // vale a pena pedir para entrar de novo) quando não há sessão
          // guardada; havendo uma, ela é o resultado certo.
          if (ref.read(authSessionStoreProvider).read() == null) {
            throw OidcContextMismatchException(reason);
          }
          debugPrint(
            '[auth] callback OIDC em contexto sem request ($reason) — '
            'mantendo a sessão armazenada',
          );
        } else {
          throw StateError('oidc_$reason');
        }
      case OidcCallbackCancelled() || null:
        break;
    }

    final stored = ref.read(authSessionStoreProvider).read();
    if (stored == null) return null;

    try {
      final remote = ref.read(authRemoteDatasourceProvider);
      final user = await remote.establishSession(stored.sessionToken);
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
        ref.read(sessionExpiredProvider.notifier).clear();
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

  /// Login web por redirect OIDC (spec D1/§3.6): gera nonce/csrf, guarda-os
  /// em `sessionStorage` e manda a página inteira para o Google. Não há
  /// `AsyncLoading` — esta página deixa de existir; quem continua é o
  /// `build()` da próxima carga, via [oidcCallbackInboxProvider].
  void startGoogleRedirect({required String returnTo}) {
    final clientId = ref.read(googleClientIdProvider);
    if (clientId.isEmpty) {
      throw StateError('google_client_id_missing');
    }
    final browser = ref.read(oidcBrowserProvider);
    final request = OidcRedirectRequest.generate();
    browser.writeRequest(request.toJson());
    browser.navigate(
      request.authorizationUri(
        clientId: clientId,
        origin: browser.origin,
        returnTo: returnTo,
      ),
    );
  }

  /// Renova o `id_token` sem UI e devolve o token novo, ou `null`.
  ///
  /// `null` **conclusivo** (o refresher devolveu nada, vazio ou o mesmo token,
  /// sem lançar) marca [sessionExpiredProvider] — o usuário precisa entrar de
  /// novo. `null` por falha **transitória** (o refresher lançou) não marca nada:
  /// o token corrente segue em uso (spec D.4). Em qualquer caso a sessão local é
  /// **preservada**: quem decide deslogar é o Worker, via
  /// [AuthUnauthorizedException]. Nunca propaga exceção — é chamado de dentro de
  /// um interceptor do Dio.
  Future<String?> refreshIdToken() {
    return _refreshInFlight ??= _refreshIdToken().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _refreshIdToken() async {
    final current = state.asData?.value;
    // Sem sessão não há o que renovar — e não é uma sessão "expirada".
    if (current == null) return null;

    final String? idToken;
    try {
      idToken = await ref.read(googleSilentIdTokenRefresherProvider)();
    } on Object catch (error) {
      // Exceção é falha **transitória** (offline, timeout, extensão travando o
      // GIS): o Google não disse que a sessão morreu, só não deu para
      // perguntar. Marcar expirada aqui prendia o usuário num login manual por
      // causa de uma piscada de rede (spec D.4). O token corrente segue valendo
      // e o próximo request tenta de novo — o 401, se vier, é conclusivo.
      debugPrint('[auth] reautenticação silenciosa falhou: $error');
      return null;
    }

    // Resultado sem exceção é conclusivo. Token idêntico conta como falha: o
    // Google não tem nada mais fresco para dar, e reemitir `AsyncData` aqui
    // reconstruiria quem observa [authStateProvider] (AuthUser não tem `==`),
    // gerando request nova → 401 → refresh → laço sem fim enquanto o Worker
    // recusar esse token.
    if (idToken == null || idToken.isEmpty || idToken == current.sessionToken) {
      ref.read(sessionExpiredProvider.notifier).markExpired();
      return null;
    }

    final updated = current.copyWith(sessionToken: idToken);
    ref.read(authSessionStoreProvider).write(updated);
    ref.read(sessionExpiredProvider.notifier).clear();
    state = AsyncData(updated);
    return idToken;
  }

  Future<void> _completeSignIn(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('google_id_token_missing');
    }

    state = const AsyncLoading();
    try {
      state = AsyncData(await _establishAndStore(idToken));
    } on Object catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  /// Troca o `id_token` por sessão no Worker e persiste — caminho comum ao
  /// plugin (nativo) e ao redirect OIDC (web).
  Future<AuthUser> _establishAndStore(String idToken) async {
    final user = await ref
        .read(authRemoteDatasourceProvider)
        .establishSession(idToken);
    ref.read(authSessionStoreProvider).write(user);
    ref.read(sessionExpiredProvider.notifier).clear();
    return user;
  }

  Future<void> signOut() async {
    ref.read(authSessionStoreProvider).clear();
    ref.read(sessionExpiredProvider.notifier).clear();
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
        .setUsername(sessionToken: current.sessionToken, username: username);
    final updated = current.copyWith(username: value);
    ref.read(authSessionStoreProvider).write(updated);
    state = AsyncData(updated);
  }
}
