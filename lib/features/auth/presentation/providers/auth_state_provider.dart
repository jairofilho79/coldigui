import 'dart:async';

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

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  @override
  Future<AuthUser?> build() async {
    ref.onDispose(() {
      unawaited(_authSub?.cancel());
      _authSub = null;
    });

    final store = ref.read(authSessionStoreProvider);

    // Callback do redirect OIDC tem precedência sobre a sessão armazenada
    // (spec D9 do login): o usuário acabou de escolher uma conta no Google.
    final pending = ref.read(oidcCallbackInboxProvider).take();
    switch (pending) {
      case OidcCallbackSuccess(:final idToken):
        try {
          return await _establishAndStore(idToken);
        } on Object {
          store.clear();
          rethrow;
        }
      case OidcCallbackInvalid(:final reason, :final isContextMismatch):
        if (isContextMismatch) {
          // Botão Voltar depois do login re-dispara o callback já consumido
          // (request/csrf não batem mais) sobre uma aba que já tem sessão
          // válida — spec D9/D15. Só é de fato um mismatch de contexto (e
          // vale a pena pedir para entrar de novo) quando não há sessão
          // guardada; havendo uma, ela é o resultado certo.
          if (store.read() == null) {
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

    // Sessão do Worker guardada: vale até o Worker dizer o contrário (401 →
    // onUnauthorized). Nada de rede no boot (spec D7) — offline continua logado.
    final stored = store.read();
    if (stored != null) return stored;

    return _migrateLegacyWebSession(store);
  }

  /// Sessão do formato anterior (id_token do Google em `sessionStorage`) —
  /// troca uma vez por sessão do Worker; qualquer falha vira deslogado
  /// (spec D12). O `sessionStorage` é consumido nos dois casos.
  Future<AuthUser?> _migrateLegacyWebSession(AuthSessionStore store) async {
    final legacyIdToken = AuthSessionStore.legacyIdToken(
      store.takeLegacySessionStorage(),
    );
    if (legacyIdToken == null) return null;
    try {
      return await _establishAndStore(legacyIdToken);
    } on Object catch (error) {
      debugPrint('[auth] migração da sessão antiga falhou: $error');
      store.clear();
      return null;
    }
  }

  /// Único ponto que chama [GoogleSignIn.initialize] (idempotente no processo).
  ///
  /// Chamada só pelo login nativo ([signInWithGoogle]); a web entra por
  /// redirect e não precisa do SDK.
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

  /// O Worker recusou o `sessionToken` (401 numa request `Bearer sess_…`):
  /// sessão revogada ou vencida (spec D8). Sem renovação — quem entra de
  /// novo é o usuário. Idempotente: chamadas repetidas (várias requests em
  /// voo) não reemitem estado.
  void onUnauthorized() {
    ref.read(authSessionStoreProvider).clear();
    if (state.asData?.value != null || state is! AsyncData) {
      state = const AsyncData(null);
    }
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
    return user;
  }

  Future<void> signOut() async {
    final current = state.asData?.value;
    ref.read(authSessionStoreProvider).clear();
    state = const AsyncData(null);
    if (current != null) {
      try {
        await ref
            .read(authRemoteDatasourceProvider)
            .revokeSession(current.sessionToken);
      } on Object catch (error) {
        // A sessão local já morreu; a linha no Worker expira em 60 d.
        debugPrint('[auth] revogação da sessão falhou: $error');
      }
    }
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
