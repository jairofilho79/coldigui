# Sessão persistente emitida pelo Worker

**Data:** 2026-09-13
**Estado:** aprovado (brainstorm em sessão; decisões D1–D14 abaixo)
**Origem:** bug reportado em produção — «quando me logo e fecho a app, minha sessão morre e tenho que me logar de novo». Efeito colateral: os favoritos de material (`materialKindPrefsProvider`) somem junto, porque são da conta e ficam vazios para quem está deslogado.
**Escopo:** Worker `plpcg-catalog` (`src/auth/*`, `src/index.ts`, migration D1) e app Flutter (`lib/features/auth`, `lib/core/network`, `lib/core/providers/dio_provider.dart`, datasources que mandam `Authorization`). Web e nativo.

## 1. Problema

Hoje a única credencial aceita pelo Worker é o `id_token` do Google: `withAuth` valida assinatura/`aud`/`exp` com `jose`, e o app o manda como `Bearer` em toda rota autenticada. Isso impõe duas limitações que, juntas, matam a sessão ao fechar a app:

1. O `id_token` vence em ~1 h. Para durar mais, o app depende de renovação silenciosa via `GoogleSignIn.attemptLightweightAuthentication` (`AuthRefreshInterceptor` + `AuthNotifier.refreshIdToken`), que na web depende do GIS e da sessão Google no navegador — frágil num PWA iOS standalone.
2. Por decisão da spec de auth (S2: «nunca `localStorage`», por XSS), a sessão web vive em `sessionStorage`, que morre com a aba/PWA. No nativo, `AuthSessionStore` é só memória — também não sobrevive a reiniciar.

A spec do login por redirect (`2026-09-13-google-login-redirect-coop-design.md`, §9) deixou «refresh token / sessão persistente» explicitamente fora de escopo. Esta spec fecha essa lacuna.

## 2. Decisões (fechadas)

| # | Decisão |
|---|---|
| D1 | **O Worker emite uma sessão própria.** `POST /api/auth/session` continua recebendo o `id_token` do Google, mas passa a devolver também `sessionToken`. A partir daí o app usa **só** o `sessionToken` como `Bearer`; o `id_token` é usado uma vez e descartado. |
| D2 | **Token opaco**: `sess_` + 32 bytes de `crypto.getRandomValues` em base64url sem padding. O prefixo permite ao `withAuth` distinguir sessão de JWT sem parsear. D1 guarda **só o SHA-256 hex** do token. |
| D3 | **Validade de 60 dias deslizantes**: `expires_at = last_seen_at + 60 d`. Cada request autenticada renova, mas a escrita só acontece quando `last_seen_at` tem mais de 1 h (uma escrita por hora por sessão, no máximo). Quem fica 60 dias sem abrir a app entra de novo. |
| D4 | **Um login = uma sessão nova.** Multi-aparelho é natural: cada aparelho tem a sua linha. Logout revoga só a sessão do aparelho (`DELETE /api/auth/session`). «Sair de todos os aparelhos» fica fora de escopo. |
| D5 | **`withAuth` aceita os dois Bearers**: `sess_…` (lookup em D1) e JWT do Google (caminho atual). O JWT continua necessário para a própria `POST /session` e mantém o app antigo em cache funcionando durante o rollout. Handlers recebem `{ sub }` nos dois casos — hoje nenhum usa `email`/`name`/`picture` fora de `upsertUser`. |
| D6 | **Web guarda em `localStorage`** (`plpcg_auth_session`, mesmo JSON de hoje com `sessionToken` no lugar de `idToken`). **Nativo guarda em `SharedPreferences`** (mesma chave). Revoga a decisão S2 da spec de auth para a sessão — trade-off aceito: o token é opaco, de alta entropia, revogável e só o hash fica no servidor. O `nonce`/`csrf` do redirect OIDC **continua** em `sessionStorage` (uso único, mesma aba). |
| D7 | **Boot não verifica a sessão no Worker.** `AuthNotifier.build()` devolve o usuário guardado direto; a primeira request autenticada é quem descobre um `401`. Boot offline continua logado. |
| D8 | **`401` em request com `Bearer sess_…` = sessão revogada ou vencida** → `AuthNotifier.onUnauthorized()` limpa a store e volta a `null`. Sem renovação, sem retry, sem banner: a UI já reage a `authStateProvider == null` mostrando o botão de entrar. `401` sem `Authorization` (rota pública) ou com JWT (só a `POST /session`) não dispara isso. |
| D9 | **Removidos**: `AuthRefreshInterceptor`, `AuthNotifier.refreshIdToken`/`_refreshInFlight`, `googleSilentIdTokenRefresherProvider`, `sessionExpiredProvider`, `_SessionExpiredBanner` do perfil e a extensão `AuthUserExpiry` (token opaco não tem `exp`). As chaves l10n `sessionExpiredBanner`/`sessionExpiredSignInAgain` saem; `errorSessionExpired` fica (ainda é a mensagem do `userMessageFor` para 401/403). |
| D10 | **`AuthUser.idToken` vira `AuthUser.sessionToken`** — rename mecânico em todos os consumidores (datasources de playlists, social, audio_flags, material_kind_prefs, links e seus usecases/providers). O nome antigo mentiria sobre o que o campo carrega. |
| D11 | **`GoogleSignIn` fica só para o login nativo e para `signOut`.** `AuthNotifier.build()` deixa de chamar `ensureGoogleInitialized()`; ela passa a ser chamada só por `signInWithGoogle()` (nativo). `googleSignInUnavailableProvider` sai se ficar sem consumidor. |
| D12 | **Migração da sessão antiga (web), uma vez**: se `localStorage` não tem sessão e `sessionStorage['plpcg_auth_session']` tem (formato antigo, com `idToken`), o `build()` tenta `establishSession(idToken)`; sucesso → grava a sessão nova no `localStorage`; falha → `null` (o usuário entra de novo). Em qualquer caso apaga a chave do `sessionStorage`. Removível na release seguinte. |
| D13 | **Purga oportunista**: cada `POST /api/auth/session` apaga `user_sessions` com `expires_at < now` antes de inserir. Sem cron. |
| D14 | **Ordem de rollout**: Worker primeiro (aceita os dois Bearers), app depois. Nunca o contrário. |

## 3. Worker `plpcg-catalog`

### 3.1 Migration `0012_create_user_sessions.sql`

```sql
CREATE TABLE user_sessions (
  token_hash   TEXT PRIMARY KEY NOT NULL,          -- SHA-256 hex do token; o token cru nunca é gravado
  google_sub   TEXT NOT NULL REFERENCES users(google_sub) ON DELETE CASCADE,
  created_at   TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  expires_at   TEXT NOT NULL                        -- ISO 8601, last_seen_at + 60 d
);
CREATE INDEX idx_user_sessions_sub ON user_sessions(google_sub);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
```

### 3.2 `src/auth/session_token.ts` (novo, puro)

```ts
export const SESSION_TOKEN_PREFIX = 'sess_';
export const SESSION_TTL_MS = 60 * 24 * 60 * 60 * 1000;
export const SESSION_TOUCH_INTERVAL_MS = 60 * 60 * 1000;

export function generateSessionToken(): string;            // sess_ + base64url(32 bytes aleatórios)
export function isSessionToken(bearer: string): boolean;    // startsWith(prefix)
export async function hashSessionToken(token: string): Promise<string>; // SHA-256 hex via crypto.subtle
```

### 3.3 `src/auth/user_sessions.ts` (novo, D1)

```ts
export async function createSession(db, googleSub, now: Date): Promise<string>;      // purga vencidas (D13), insere, devolve o token cru
export async function findSession(db, token, now: Date): Promise<{ sub: string } | null>; // hash → SELECT com expires_at > now; renova se last_seen_at + 1 h < now (D3)
export async function revokeSession(db, token): Promise<void>;                        // DELETE por hash; idempotente
```

### 3.4 `src/auth/with_auth.ts`

```ts
const token = bearerToken(request);
if (!token) return 401;
if (isSessionToken(token)) {
  const session = await findSession(env.DB, token, new Date());
  if (!session) return 401;
  return handler(request, env, { sub: session.sub });
}
// caminho atual: verifyGoogleIdToken → handler(request, env, claims)
```

`GoogleClaims` continua sendo o tipo do terceiro argumento (`sub` obrigatório; o resto opcional) — nenhum handler muda.

### 3.5 `src/index.ts` — `handleAuthSession`

- `POST`: como hoje (`verifyGoogleIdToken` → `upsertUser`) **+** `createSession` → `200 { ...user, sessionToken }`.
- `DELETE`: `Bearer sess_…` → `revokeSession` → `204`. Token ausente/não-sessão → `401`. Token desconhecido → `204` (idempotente).
- Modo CORS `auth`: `Access-Control-Allow-Methods: POST, PUT, DELETE, OPTIONS`.

### 3.6 Testes (`node --test`, mesmo harness dos handlers existentes)

- `session_token.test.ts`: prefixo, tamanho, dois tokens diferem, hash determinístico e diferente do token.
- `user_sessions.test.ts` (D1 em memória como os outros testes de handler): criar grava hash e não o token; `findSession` acha válida, recusa vencida e desconhecida; renova `expires_at` só após 1 h; `revokeSession` faz o próximo `find` devolver `null`; `createSession` purga vencidas.
- `with_auth.test.ts`: `sess_` válida chama o handler com `{ sub }`; `sess_` inválida → `401`; JWT continua pelo caminho antigo; `DELETE /api/auth/session` idempotente; `POST /api/auth/session` devolve `sessionToken`.

## 4. App Flutter

### 4.1 `domain/entities/auth_user.dart`

- `idToken` → `sessionToken` (campo, `copyWith`, `toJson`/`fromJson` com chave `sessionToken`).
- Remove a extensão `AuthUserExpiry` e `_idTokenExpiry`.
- `fromJson` de um documento antigo (chave `idToken`) devolve `null` — quem trata é a migração de D12, que lê o JSON cru.

### 4.2 `data/auth_session_store.dart` (+ `_web.dart` / `_stub.dart`)

- Web: `localStorage` em vez de `sessionStorage`; mesma API (`read`/`write`/`clear`) + `String? takeLegacySessionStorage()` que lê **e apaga** `sessionStorage['plpcg_auth_session']` (D12).
- Nativo (`_stub.dart` deixa de ser só memória): recebe `SharedPreferences` no construtor e persiste na mesma chave. `takeLegacySessionStorage()` devolve `null`.
- `authSessionStoreProvider` constrói o store com `ref.read(sharedPreferencesProvider)` (a web ignora o argumento). O stub é o que roda nos testes VM e `sharedPreferencesProvider` lança sem override: os testes que exercitam o `AuthNotifier` real (`auth_state_provider_test` e afins) passam a fazer `SharedPreferences.setMockInitialValues({})` + override, como os testes de `material_kind_prefs` já fazem. Testes que sobrescrevem `authStateProvider` com notifier fake não tocam no store e não mudam. Nenhum código tolerante ao provider ausente — quem quebrar ganha o override.

### 4.3 `data/auth_remote_datasource.dart`

- `establishSession(idToken)` lê `sessionToken` da resposta (ausente → `StateError('auth_session_missing_token')`).
- `revokeSession(sessionToken)` → `DELETE /api/auth/session`; `204`/`401` são sucesso do ponto de vista do app (a sessão local vai ser apagada de qualquer jeito); 5xx/rede lança para o chamador logar.
- `setUsername(sessionToken:, username:)` — só o rename.

### 4.4 `presentation/providers/auth_state_provider.dart`

`build()`:
1. Callback OIDC pendente → `establishSession` (inalterado, spec D9 do login).
2. Sessão guardada → devolve direto (D7).
3. Sem sessão guardada e `takeLegacySessionStorage()` devolve JSON antigo com `idToken` → `establishSession(idToken)`; sucesso grava e devolve; qualquer falha → `null` (D12).
4. Senão → `null`.

- `onUnauthorized()`: limpa a store e `state = AsyncData(null)` (D8). Idempotente.
- `signOut()`: `revokeSession` (erro vira `debugPrint`), limpa store, `state = null`, `GoogleSignIn.signOut()` em try/catch como hoje.
- `signInWithGoogle()` (nativo): chama `ensureGoogleInitialized()` ela mesma (D11); `_completeSignIn` → `_establishAndStore` inalterados.
- Removidos: `refreshIdToken`, `_refreshInFlight`, `googleSilentIdTokenRefresherProvider`, `sessionExpiredProvider`/`SessionExpiredNotifier`, `googleSignInUnavailableProvider` (D9/D11).

### 4.5 `core/network/auth_unauthorized_interceptor.dart` (substitui `auth_refresh_interceptor.dart`)

```dart
class AuthUnauthorizedInterceptor extends Interceptor {
  AuthUnauthorizedInterceptor({required this.onUnauthorized});
  final void Function() onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final auth = err.requestOptions.headers['Authorization'];
    if (err.response?.statusCode == 401 &&
        auth is String &&
        auth.startsWith('Bearer sess_')) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
```

Sem `onRequest`, sem retry. `dioProvider` instala `AuthUnauthorizedInterceptor` antes do `RetryInterceptor` (que já não repete 401).

Atenção: os datasources autenticados usam `validateStatus: status < 500`, então o `401` chega como resposta, não como `DioException`, e lançam `AuthUnauthorizedException` eles mesmos. Para o D8 valer nos dois caminhos, o interceptor também trata `onResponse` com `statusCode == 401` e o mesmo predicado do header.

### 4.6 Consumidores do token (rename, D10)

`lib/features/{playlists,social,audio_flags,material_kind_prefs}/…` e `share_link_shortener_remote.dart`: parâmetro `idToken` → `sessionToken`. Comportamento inalterado. Os usecases de sync que tratam `AuthUnauthorizedException` como `skippedAuth` continuam iguais — na rodada seguinte o usuário já é `null`.

### 4.7 `app_shell/presentation/pages/profile_screen.dart`

Remove `_SessionExpiredBanner` e o `watch` de `sessionExpiredProvider`. Nada mais muda: deslogado já mostra o `GoogleSignInButton`.

### 4.8 l10n

Remove `sessionExpiredBanner` e `sessionExpiredSignInAgain` de `app_pt.arb`/`app_en.arb` (e regenerar). `errorSessionExpired` fica.

## 5. Fluxo

```
Login (web)   botão → redirect Google → #id_token → main() captura → AuthNotifier.build()
              → POST /api/auth/session (Bearer id_token) → { user, sessionToken }
              → localStorage['plpcg_auth_session'] = { ..., sessionToken }
Login (nativo) GoogleSignIn.authenticate → idToken → mesma POST → SharedPreferences

Boot          localStorage/SharedPreferences tem sessão → AsyncData(user), sem rede (D7)
              (web, uma vez) sem sessão nova + sessionStorage antigo → POST /session com o idToken antigo (D12)

Request       Authorization: Bearer sess_… → withAuth: hash → user_sessions (expires_at > now)
              → renova last_seen/expires se passou 1 h (D3) → handler({ sub })

401           AuthUnauthorizedInterceptor (header sess_) → AuthNotifier.onUnauthorized() → null + store limpa

Logout        DELETE /api/auth/session (Bearer sess_) → 204 → store limpa → null
```

## 6. Segurança

- 256 bits de entropia por token; D1 só tem o hash — um dump do banco não dá sessões.
- Revogação real no logout; expiração deslizante de 60 d; purga oportunista (D13).
- `localStorage` amplia a janela de XSS em relação ao `sessionStorage` — trade-off aceito ao escolher bearer opaco (uniforme entre web, nativo e previews `*.pages.dev`, sem cookies/CORS credenciados). Mitigação futura já prevista na spec de auth (W2): CSP restritiva. Fora deste escopo.
- O `id_token` do Google continua transitando só no fragmento e sendo consumido uma vez; depois do `POST /session` não fica guardado em lugar nenhum.
- O `withAuth` continua aceitando JWT do Google: superfície igual à de hoje, não maior.

## 7. Testes (app)

- **Unit** `auth_user_test`: `toJson`/`fromJson` com `sessionToken`; JSON antigo com `idToken` → `null`.
- **Unit** `auth_session_store_test` (stub com `SharedPreferences` mock): round-trip, `clear`, `takeLegacySessionStorage` devolve `null`.
- **Unit** `auth_remote_datasource_test`: `establishSession` lê `sessionToken`; resposta sem ele lança; `revokeSession` 204/401 ok, 5xx lança.
- **Unit** `auth_state_provider_test`: boot com sessão guardada não chama o Worker; `onUnauthorized` → `null` + store limpa; `signOut` chama `revokeSession` e limpa mesmo se ele falhar; migração D12 (sucesso grava; falha → `null`; `sessionStorage` apagado nos dois casos); callback OIDC continua tendo precedência.
- **Unit** `auth_unauthorized_interceptor_test`: 401 com `Bearer sess_` dispara; 401 sem `Authorization` não; 401 com JWT não; 403 não; caminho `onResponse` (validateStatus < 500) também dispara.
- **Unit** `dio_interceptors_wiring_test`: ordem `AuthUnauthorizedInterceptor` → `RetryInterceptor`.
- **Widget** `profile_screen_*`: sem banner de sessão expirada; após `onUnauthorized` aparece o botão de entrar.
- **Remover**: `auth_refresh_interceptor_test`, `auth_refresh_id_token_test`, `auth_user_expiry_test` e os casos de `sessionExpiredProvider`/`googleSignInUnavailableProvider` em `auth_state_provider_test`/`profile_screen_errors_test`.
- Rename mecânico nos testes dos datasources/usecases que passam `idToken`.

## 8. Checklist manual (prod, depois do rollout D14)

1. Login na web → fechar o PWA → reabrir: continua logado, sem request ao Worker no boot (Network).
2. Favoritos de material ordenam o sheet e o «+»/long-press respeitam o favorito **depois** de reabrir.
3. Logout → reabrir: deslogado; a linha sumiu de `user_sessions`.
4. Apagar a linha no D1 com o app aberto → próxima ação autenticada desloga sem erro na tela.
5. App antigo (cache) durante o rollout: continua funcionando contra o Worker novo.
6. Sessão antiga em `sessionStorage` na primeira carga do app novo: migra sem pedir login (se o `id_token` ainda vale).

## 9. Documentação

- `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md`: nota em S2/§ tokens apontando para esta spec (sessão do Worker em `localStorage`; `id_token` não é mais guardado).
- `docs/superpowers/specs/2026-09-13-google-login-redirect-coop-design.md`: nota em D10 (renovação silenciosa não existe mais).
- `docs/features/FEATURE_INDEX.md`: entrada de auth atualizada.
- `workers/plpcg-catalog/README.md`: rotas de sessão e a tabela.

## 10. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| App novo no ar antes do Worker novo → todo request autenticado dá 401 | D14: ordem de rollout obrigatória; `web_deploy.sh` não muda, mas o plano coloca o deploy do Worker como passo anterior e verificado. |
| Um `401` transitório (Worker fora, D1 indisponível) desloga o usuário | Worker devolve 5xx nesses casos, não 401; `withAuth` só responde 401 para token ausente/inválido/vencido. O `RetryInterceptor` cuida dos 5xx. |
| Escrita de `last_seen_at` a cada request | D3: só quando passou 1 h. |
| `SharedPreferences` no nativo não é armazenamento seguro | Mesmo nível do que outras preferências da conta já usam; `flutter_secure_storage` fica como melhoria futura se o nativo ganhar peso. |

## 11. Fora de escopo

«Sair de todos os aparelhos» / listagem de sessões; CSP; refresh token do Google (code + PKCE); cookies `HttpOnly`; `flutter_secure_storage`; remoção do `google_sign_in` da web.
