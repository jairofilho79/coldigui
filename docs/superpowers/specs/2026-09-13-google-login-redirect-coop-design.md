# Login Google por redirect + cross-origin isolation na web (P1)

**Data:** 2026-09-13
**Estado:** aprovado (brainstorm em sessão; decisões D1–D17 abaixo; pré-requisito do Console feito em 2026-09-13)
**Origem:** P1 de `docs/AUDITORIA_POLIMENTO_2026-09-12.md` — produção não está cross-origin isolated porque o popup do Google Identity Services (GIS) exige `Cross-Origin-Opener-Policy: same-origin-allow-popups`; com isso `crossOriginIsolated === false`, o skwasm roda single-thread e o preload do renderer em `web/index.html` nunca dispara.
**Escopo:** só o app Flutter web (`lib/features/auth`, `lib/main.dart`, `web/`, `scripts/`, docs). O Worker `plpcg-catalog` **não muda na entrega principal** (só na contingência §10, se ativada): continua recebendo o mesmo `id_token` do Google em `POST /api/auth/session` e validando assinatura/`aud`/`exp` com `GOOGLE_CLIENT_ID_WEB`. O app nativo (Android/iOS via loja) **não muda**.

## 1. Problema

O `google_sign_in_web` 1.1.3 só oferece o botão GIS (`renderButton`), que abre popup. O plugin não expõe `ux_mode: redirect` nem `use_fedcm_for_button`; FedCM para botão só existe em Chrome 117+/Chrome Android M128+ — Safari (iPhone/iPad, público relevante) e Firefox caem no popup. Enquanto o popup existir, COOP tem de ser `same-origin-allow-popups`, e isso desliga o isolamento cross-origin. Quem tem hardware fraco sente o renderer single-thread e desiste da app.

## 2. Decisões (fechadas)

| # | Decisão |
|---|---|
| D1 | **Login web por redirect OIDC (fluxo implícito)**, para todos os navegadores: `accounts.google.com/o/oauth2/v2/auth` com `response_type=id_token`. Sem popup, sem FedCM, sem `window.opener` → COOP pode ser `same-origin`. |
| D2 | **Botão próprio** (Material) «Entrar com o Google» substitui `gis.renderButton` na web. Mesmo lugar nas três telas que já o usam (perfil, listas públicas, materiais favoritos). |
| D3 | `redirect_uri = <origin>/` (barra final), derivado de `window.location.origin`. Só funciona em origens cadastradas no Google Cloud Console — hoje produção e `localhost:8080`. Previews `*.pages.dev` com hash continuam sem login (já era assim). |
| D4 | O Google devolve `#id_token=…&state=…` (ou `#error=…&state=…`) no **fragmento** — nunca chega ao servidor/Cloudflare. |
| D5 | **Captura em Dart, no início de `main()`**, antes de `configureGoRouterGlobals()` e de `runApp`: lê `location.hash`, valida, guarda o resultado em memória e faz `history.replaceState` para `#<returnTo>`. O go_router nunca vê o fragmento do Google. (Substitui o script inline em `index.html` cogitado no brainstorm: mesma garantia — o router ainda não existe — e é testável em VM sem infra de teste JS. O token fica na barra de endereço só durante o boot; o histórico do navegador já registra a URL do commit da navegação em qualquer das duas abordagens.) |
| D6 | `nonce` e `csrf` (32 bytes de `Random.secure()`, base64url) são gerados no clique e gravados em `sessionStorage['plpcg_oidc_request']` (mesma política da sessão: nunca `localStorage`). Consumo único — apagados na captura. |
| D7 | `state` = base64url sem padding de `{"csrf": "...", "returnTo": "/perfil"}`. `returnTo` é a rota atual do go_router (`GoRouterState.of(context).uri.toString()`), validada na volta (D8). |
| D8 | `returnTo` só é aceito se casar `^/[A-Za-z0-9/_\-?=&%.]*$` e não começar por `//`; senão vale `/`. É um caminho do hash router da própria app — não há open redirect. |
| D9 | O resultado da captura é um `OidcCallbackResult` consumido **uma vez** pelo `AuthNotifier.build()` via `OidcCallbackInbox.take()`. Sucesso → `establishSession(idToken)` **antes** de olhar a sessão armazenada. Cancelamento (`error=…`) → estado `null`, sem UI de erro. Inválido por adulteração (`nonce_mismatch`, `jwt_malformed`) ou Worker recusou → `AsyncError` → UI de erro existente («Login indisponível» + «Tentar novamente»); o retry invalida o provider, o inbox já está vazio, e o botão volta ao normal. Inválido por **contexto** (`request_missing`, `csrf_mismatch`) → D15. |
| D10 | O plugin `google_sign_in` **fica**, só para `attemptLightweightAuthentication` (renovação silenciosa do `id_token`) e `signOut`. `AuthNotifier.build` continua tentando `ensureGoogleInitialized()`, mas a falha do SDK **não bloqueia** o login por redirect nem o processamento do callback. |
| D11 | O botão web deixa de depender de `googleSignInUnavailableProvider` (o redirect não usa o SDK). Continua escondido só se `AppConfig.isGoogleClientIdMissing`. Se o botão era o único consumidor do provider, remover o provider e seus testes; senão, manter. |
| D12 | `web/_headers` e `scripts/web_frontend_server.py`: `Cross-Origin-Opener-Policy: same-origin`. COEP `require-corp` inalterado. |
| D13 | `scripts/validate_web_coop_coep.sh` e `scripts/verify_web_headers_artifact.sh` passam a aceitar **só** `same-origin` — `same-origin-allow-popups` volta a falhar o CI. |
| D14 | Dev local: o redirect só volta para a origem exata; usar `http://localhost:8080` (ou `127.0.0.1:8080`, se cadastrado). `scripts/web_local_dev.py` já serve em 8080. |
| D15 | **Fallback de contexto (obrigatório).** `request_missing`/`csrf_mismatch` significam «o Google respondeu num contexto que não iniciou o login» (aba restaurada, recarga no meio, navegador embutido do PWA iOS). `AuthNotifier` lança `OidcContextMismatchException`; o botão web renderiza um estado próprio — título «Não conseguimos concluir o login», texto «O Google respondeu em outra janela. Toque para tentar novamente.» e o **mesmo botão «Entrar com o Google»**, que reinicia o redirect neste contexto em um toque (sem `invalidate`, sem fechar a app). Em modo standalone (D16) acrescenta a linha «Se continuar, abra v2.plpcg.com no Safari». |
| D16 | `OidcBrowser.isStandaloneDisplay`: `matchMedia('(display-mode: standalone)').matches || navigator.standalone == true`. Usado só para a dica de D15 e para o diagnóstico do checklist. |
| D17 | **Contingência «handoff» (§10) só é implementada se o item 3 do checklist falhar no PWA do iPhone** (cenário (b) de §8). Hoje o login funciona no PWA iOS instalado, então (b) seria regressão e a contingência é obrigatória nesse caso — por isso já está desenhada aqui, com Worker incluído. |

## 3. Componentes

Tudo em `lib/features/auth/`, salvo indicado. Dart puro onde possível; o que toca `package:web` fica em arquivo `_web.dart` com `_stub.dart` por export condicional (padrão de `auth_session_store.dart`).

### 3.1 `data/oidc/oidc_redirect_request.dart` (Dart puro)

```dart
class OidcRedirectRequest {
  const OidcRedirectRequest({required this.nonce, required this.csrf});
  final String nonce;
  final String csrf;

  static OidcRedirectRequest generate([Random? random]); // Random.secure() por padrão
  String encodeState(String returnTo);                    // base64url({"csrf","returnTo"}) sem '='
  Uri authorizationUri({required String clientId, required Uri origin, required String returnTo});
  String toJson(); static OidcRedirectRequest? fromJson(String? raw);
}
```

`authorizationUri` monta `https://accounts.google.com/o/oauth2/v2/auth` com `client_id`, `redirect_uri=<origin>/`, `response_type=id_token`, `scope=openid email profile`, `nonce`, `state`, `prompt=select_account`.

### 3.2 `data/oidc/oidc_callback.dart` (Dart puro)

```dart
sealed class OidcCallbackResult { String get returnTo; }
final class OidcCallbackSuccess   extends OidcCallbackResult { final String idToken; }
final class OidcCallbackCancelled extends OidcCallbackResult { final String error; }
final class OidcCallbackInvalid   extends OidcCallbackResult {
  final String reason; // 'state_missing' | 'csrf_mismatch' | 'nonce_mismatch' | 'jwt_malformed' | 'request_missing'
  bool get isContextMismatch => reason == 'request_missing' || reason == 'csrf_mismatch';
}

abstract final class OidcCallbackParser {
  /// `null` quando o fragmento não é um callback do Google (ex.: rota `#/leitor?...`).
  static OidcCallbackResult? parse({required String fragment, required OidcRedirectRequest? request});
  static String sanitizeReturnTo(String? raw); // D8
}
```

Regras de `parse`: fragmento sem `state=` ou começando por `/` → `null`. Com `state`: decodifica; `csrf` ≠ do `request` (ou `request == null`) → `Invalid`. `error=` presente → `Cancelled`. `id_token=` presente → decodifica o payload (2º segmento, base64url) e compara `nonce`; diverge/malformado → `Invalid`; igual → `Success`. `returnTo` sempre passa por `sanitizeReturnTo`. **A assinatura não é verificada no cliente** — é papel do Worker.

### 3.3 `data/oidc/oidc_callback_inbox.dart` (Dart puro)

```dart
class OidcCallbackInbox {
  OidcCallbackInbox([OidcCallbackResult? pending]);
  OidcCallbackResult? take(); // devolve e esvazia
}
```

### 3.4 `data/oidc/oidc_browser.dart` (+ `_web.dart` / `_stub.dart`)

```dart
abstract interface class OidcBrowser {
  Uri get origin;                      // window.location.origin
  String get fragment;                 // window.location.hash sem '#'
  String? readRequest(); void writeRequest(String json); void clearRequest(); // sessionStorage['plpcg_oidc_request']
  void navigate(Uri uri);              // window.location.assign
  void replaceHash(String path);       // history.replaceState(null, '', '#$path')
  bool get isStandaloneDisplay;        // D16
}
```

Stub (não-web): lança `UnsupportedError` em tudo — nunca é chamado porque o botão nativo usa o plugin.

### 3.5 `data/oidc/oidc_redirect_capture.dart`

```dart
/// Chamado no início de `main()`. Web: lê o fragmento, consome o request pendente,
/// limpa a URL e devolve o resultado (ou null). Não-web: devolve null.
OidcCallbackResult? captureOidcRedirectCallback(OidcBrowser browser);
```

Ordem: `fragment` → `readRequest()` → `parse` → se resultado ≠ `null`: `clearRequest()` + `replaceHash(result.returnTo)`. Se `null`: não toca em nada (o hash é uma rota normal).

### 3.6 `presentation/providers/auth_state_provider.dart`

- Novos providers: `oidcBrowserProvider` (`Provider<OidcBrowser>`, impl web por default), `oidcCallbackInboxProvider` (`Provider<OidcCallbackInbox>`, default vazio; `main.dart` sobrescreve com o capturado) e `googleClientIdProvider` (`Provider<String>`, default `AppConfig.googleClientIdWeb`) — costura para testes, já que `String.fromEnvironment` é vazio no `flutter test`.
- `AuthNotifier.build()`: após a tentativa de `ensureGoogleInitialized()` (mantida, D10), `final pending = ref.read(oidcCallbackInboxProvider).take();`
  - `OidcCallbackSuccess` → `_establishAndStore(idToken)` (extraído de `_completeSignIn`, que passa a delegar a ele); em `AuthUnauthorizedException` ou qualquer outro erro: `store.clear()` e `rethrow` (vira `AsyncError`, D9). Não cai para a sessão armazenada.
  - `OidcCallbackCancelled` → segue para a sessão armazenada como hoje.
  - `OidcCallbackInvalid` com `isContextMismatch` → `throw OidcContextMismatchException(reason)` (classe em `data/oidc/oidc_callback.dart`); demais → `throw StateError('oidc_${reason}')`.
  - `null` → comportamento atual.
- Novo método `void startGoogleRedirect({required String returnTo})`: lança `StateError('google_client_id_missing')` se `ref.read(googleClientIdProvider)` for vazio; gera `OidcRedirectRequest`, `browser.writeRequest(json)`, `browser.navigate(authorizationUri(...))`. Sem `AsyncLoading` — a página inteira vai embora.
- `signInWithGoogle()`, `refreshIdToken()`, `signOut()`, `setUsername()`: inalterados.

### 3.7 `presentation/widgets/google_sign_in_button_web.dart`

Remove `google_sign_in_web/web_only.dart`. Estrutura:

- `ref.watch(googleClientIdProvider).isEmpty` → `Text(authSignInUnavailable)` (mesmo comportamento de hoje com `isGoogleClientIdMissing`, agora sobrescrevível em teste).
- `auth.when(loading → spinner 40px; error → se `error is OidcContextMismatchException`: título + texto de D15 + o botão de login (mesmo `onPressed`) + dica standalone quando `ref.read(oidcBrowserProvider).isStandaloneDisplay`; senão texto + «Tentar novamente» (como hoje); data → OutlinedButton.icon)`.
- Botão: `OutlinedButton.icon(icon: GoogleLogo(size: 18), label: Text(l10n.authSignInWithGoogle), onPressed: () => ref.read(authStateProvider.notifier).startGoogleRedirect(returnTo: GoRouterState.of(context).uri.toString()))`. Altura 40, cantos retangulares suaves, texto `bodyLarge` — visual próximo ao botão GIS `outline/large`.
- `GoogleLogo`: `CustomPainter` com o «G» de quatro cores (sem asset novo, sem dependência).

`google_sign_in_button_stub.dart` (nativo) não muda.

### 3.8 `lib/main.dart`

```dart
final oidcCallback = captureOidcRedirectCallback(createOidcBrowser()); // antes de configureGoRouterGlobals()
...
overrides: [
  sharedPreferencesProvider.overrideWithValue(prefs),
  oidcCallbackInboxProvider.overrideWithValue(OidcCallbackInbox(oidcCallback)),
],
```

### 3.9 l10n (`app_pt.arb` / `app_en.arb`)

`authSignInWithGoogle`: «Entrar com o Google» / "Sign in with Google". (O stub nativo hoje usa string literal; passa a usar a mesma chave.)
`authSignInContextMismatchTitle`: «Não conseguimos concluir o login» / "We couldn't finish signing you in".
`authSignInContextMismatchBody`: «O Google respondeu em outra janela. Toque para tentar novamente.» / "Google answered in another window. Tap to try again."
`authSignInOpenInBrowserHint`: «Se continuar, abra v2.plpcg.com no Safari.» / "If this keeps happening, open v2.plpcg.com in Safari."

### 3.10 Headers e scripts

- `web/_headers` linha 2 e `scripts/web_frontend_server.py:27` → `same-origin`.
- `scripts/validate_web_coop_coep.sh` (bloco COOP) → aceita só `same-origin`; mensagem de FAIL ajustada.
- `scripts/verify_web_headers_artifact.sh:8` → `grep -qx '  Cross-Origin-Opener-Policy: same-origin'` (linha exata, para `allow-popups` não passar por prefixo).

## 4. Fluxo

```
[botão web] startGoogleRedirect(returnTo)
   → gera nonce/csrf → sessionStorage['plpcg_oidc_request'] → location.assign(accounts.google.com/...)
[Google] usuário escolhe conta (ou cancela)
   → https://v2.plpcg.com/#id_token=…&state=…   |   #error=access_denied&state=…
[index.html] splash; flutter_bootstrap.js; main()
   → captureOidcRedirectCallback: parse + valida csrf/nonce → replaceState('#/perfil') → inbox
   → runApp(ProviderScope(overrides: inbox))
[AuthNotifier.build] inbox.take()
   → Success: POST /api/auth/session (Bearer id_token) → store.write → AsyncData(user)
   → Cancelled: sessão armazenada / null
   → Invalid (adulteração) ou Worker 401: AsyncError → «Login indisponível» + «Tentar novamente»
   → Invalid (contexto): AsyncError(OidcContextMismatchException) → «Não conseguimos concluir o login» + botão que reinicia o redirect (D15)
[go_router] abre em #/perfil (ou a rota de origem) — usuário já logado
```

Renovação silenciosa, logout e expiração de sessão: fluxo atual, sem alteração.

## 5. Segurança

- `id_token` só transita no fragmento (não vai ao servidor) e é removido da URL antes de o router subir. Fica no histórico local do navegador até expirar (1 h) — propriedade inerente ao fluxo implícito, aceita.
- `nonce` (anti-replay, conferido no payload do JWT) e `csrf` (no `state`) vivem em `sessionStorage` da mesma aba, uso único. Um callback sem request pendente correspondente é rejeitado (`request_missing`/`csrf_mismatch`).
- Verificação criptográfica (assinatura, `iss`, `aud`, `exp`) continua exclusivamente no Worker — o cliente só lê o payload para o `nonce`.
- `returnTo` saneado (D8). `redirect_uri` sempre da origem atual; o Console limita as origens válidas.
- Sem Client Secret em lugar nenhum (fluxo implícito público, como hoje).

## 6. Testes

**Unitários (VM, `test/unit/features/auth/oidc/`):**
- `oidc_redirect_request_test.dart`: URL com todos os parâmetros e valores exatos; `redirect_uri` = origem + `/`; `state` decodifica para `{csrf, returnTo}`; `generate()` produz nonce ≠ csrf, base64url; round-trip `toJson/fromJson`.
- `oidc_callback_test.dart`: `parse` → `null` para `''`, `/leitor?id=1`, `foo=bar`; `Success` com JWT fake cujo payload tem o nonce certo; `Cancelled` com `error=access_denied`; `Invalid` para csrf errado, nonce errado, JWT com 2 segmentos, payload não-JSON, request ausente; `sanitizeReturnTo` para `null`, `''`, `//evil`, `https://x`, `/perfil`, `/listas/publicas?x=1`.
- `oidc_redirect_capture_test.dart` com `FakeOidcBrowser`: fragmento normal → não toca em storage nem URL; callback válido → `clearRequest` chamado e `replaceHash('/perfil')`; callback inválido → idem, com `Invalid`.
- `auth_state_provider_test.dart` (novo grupo «callback OIDC pendente»): `Success` → `establishSession` recebe o token e a sessão é gravada, mesmo com sessão armazenada antiga; `Success` + Worker 401 → `AsyncError`, store limpo, inbox vazio; `Cancelled` → usa sessão armazenada; `Invalid(nonce_mismatch)` → `AsyncError` com `StateError`; `Invalid(request_missing)` e `Invalid(csrf_mismatch)` → `AsyncError` com `OidcContextMismatchException`; `startGoogleRedirect` (com `googleClientIdProvider` sobrescrito) grava request no `FakeOidcBrowser` e navega para URL cujo `state` decodifica para o `returnTo` pedido; client id vazio → `StateError`.

**Widget (VM, `test/widget/features/auth/google_sign_in_button_web_test.dart`):** importa `google_sign_in_button_web.dart` diretamente (depois de D2 o arquivo não usa `package:web` nem o plugin), com `googleClientIdProvider`, `oidcBrowserProvider` (fake) e `authRemoteDatasourceProvider` sobrescritos e um `GoRouter` de teste em `/perfil`: renderiza o rótulo l10n; tap → `FakeOidcBrowser.navigated` é a URL do Google com `state.returnTo == '/perfil'`; client id vazio → texto «indisponível»; estado de erro genérico → «Tentar novamente»; erro `OidcContextMismatchException` → título/texto de D15 e o tap no botão navega de novo para o Google (novo request gravado); com `isStandaloneDisplay == true` a dica do Safari aparece, com `false` não.

**index.html/headers (VM):** `test/web/web_index_perf_test.dart` ganha asserção de que `web/_headers` contém `Cross-Origin-Opener-Policy: same-origin` exato; `verify_web_headers_artifact.sh` roda no CI como hoje.

**Manual em produção (checklist da entrega):**
1. `curl -sI https://v2.plpcg.com/ | grep -i cross-origin` → `same-origin` + `require-corp`; `./scripts/validate_web_coop_coep.sh https://v2.plpcg.com` OK.
2. Console do navegador: `crossOriginIsolated === true`; `window.__plpcgPerf.rendererPreload` indica preload do skwasm.
3. Login e retorno à tela de origem em: Chrome desktop, Chrome Android, Safari iOS (aba), **PWA instalado no iOS** — observar se, ao voltar do Google, a página abre no PWA (cenário (a)) ou fica no navegador embutido (cenário (b), gatilho de §10 por D17). PWA instalado no Android (Chrome).
   3b. Forçar o fallback D15: abrir `https://v2.plpcg.com/#id_token=x.y.z&state=<state qualquer>` numa aba nova → tela «Não conseguimos concluir o login», botão reinicia o login e o segundo redirect conclui normalmente.
4. Cancelar na tela do Google → volta deslogado, sem erro.
5. Login a partir de `/listas/publicas` e `/materiais-favoritos` → volta para a mesma tela.
6. Logout; login de novo; renovação silenciosa (deixar a sessão passar de 1 h ou forçar 401) ainda funciona ou cai no fluxo «sessão expirada» já existente.
7. Leitor PDF: scroll/virada de página perceptivelmente melhores num Android fraco (validação subjetiva do P1).

## 7. Documentação

- `docs/GOOGLE_OAUTH_SETUP.md`: redirect deixa de ser «se usar»; listar `https://v2.plpcg.com/`, `http://localhost:8080/` (e `http://127.0.0.1:8080/` se quiser usar esse host) como obrigatórios; explicar o fluxo implícito e por quê (COOP).
- `docs/AUDITORIA_POLIMENTO_2026-09-12.md`: P1 → «resolvido (redirect OIDC, COOP same-origin)» com link para esta spec.
- `docs/WEB_PERFORMANCE_RELIABILITY_AUDIT.md` e `docs/web_phase_d_coop_coep_validation.md`: alinhar menções a `allow-popups`.
- Memória do agente `web-coop-isolation-off` deve ser atualizada quando entrar em produção.

## 8. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| PWA iOS em modo standalone: a navegação para `accounts.google.com` abre um navegador embutido por cima do PWA (que continua vivo). Desde o iOS 16.4 a Apple documenta que a volta para o escopo do app fecha o embutido e carrega no PWA — cenário (a), funciona sem mais nada. Se em algum iOS ficar no embutido — cenário (b) — o callback chega sem `request` (`request_missing`) e o PWA continua deslogado; «tentar de novo» ali loga o embutido, não o PWA. | D15 dá recuperação em um toque para todos os casos «quase deu certo» e orienta o Safari. Para (b) de verdade, §10 (handoff) — decisão por D17 após o item 3 do checklist. |
| `attemptLightweightAuthentication` (One Tap) depois de um login sem GIS pode não renovar o token. | Já existe o fluxo `sessionExpiredProvider`; o usuário entra de novo por redirect. Item 6 do checklist. |
| Google não aceitar `redirect_uri` (não cadastrado) → erro `redirect_uri_mismatch` na tela do Google. | Pré-requisito antes do deploy: cadastrar URIs no Console (D3, §7). |
| Algum recurso da app depender de `window.opener` / popup. | Auditoria no plano: `grep` por `window.open`, `opener`, `url_launcher` com `webOnlyWindowName`. Links externos em nova aba não dependem de COOP. |

## 9. Fora de escopo

Híbrido FedCM/popup; mudanças no Worker; troca do plugin nativo; login em previews `*.pages.dev`; refresh token / fluxo com code + PKCE; remoção do `google_sign_in` da web.

## 10. Contingência — «handoff» pelo Worker (só por D17)

Resolve o cenário (b): o PWA fica vivo embaixo do navegador embutido, então ele pode **esperar o token pelo Worker** em vez de esperar o navegador devolvê-lo.

### 10.1 Fluxo

1. `startGoogleRedirect` passa a gerar também `handoff` (16 bytes `Random.secure()`, base64url, 22 chars) e a incluí-lo no `state` (`{"csrf","returnTo","handoff"}`). Depois de `navigate(...)`, o `AuthNotifier` começa a **consultar** `GET /api/auth/handoff/<handoff>` a cada 2 s por até 5 min (para no primeiro `200`, no `unload` da página ou no fim do prazo; consulta imediata também em `visibilitychange` → visível, para pegar a volta do «Concluído» do iOS). Num navegador comum a página navega para o Google e a consulta morre sozinha — sem efeito.
2. O contexto que recebe o callback com `request_missing`/`csrf_mismatch` **e** `state.handoff` presente produz `OidcCallbackHandoff(idToken, handoff, returnTo)`. O `AuthNotifier` faz `POST /api/auth/handoff` `{handoff, idToken}` e lança `OidcHandoffDeliveredException`; o botão renderiza «Login concluído. Volte para o app PLPCG.» (l10n `authSignInHandoffDone`). **Não** abre sessão local nesse contexto — aceitar um `id_token` sem `nonce`/`csrf` conferidos seria login-CSRF (um link forjado logaria a vítima na conta do atacante).
3. O PWA recebe `{idToken}` na consulta, chama `establishSession` e grava a sessão — logado, na tela de origem (ele nunca saiu dela).

### 10.2 Worker `plpcg-catalog`

Migração `migrations/0011_create_auth_handoffs.sql`:

```sql
CREATE TABLE auth_handoffs (
  id         TEXT PRIMARY KEY,   -- 22 chars base64url gerados pelo PWA
  id_token   TEXT NOT NULL,
  expires_at TEXT NOT NULL       -- ISO 8601, now + 5 min
);
```

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| `POST` | `/api/auth/handoff` | `{ handoff: string, idToken: string }` | `204` gravado; `400` `handoff` fora de `^[A-Za-z0-9_-]{22}$` ou `idToken` inválido (mesma verificação de assinatura/`aud`/`exp` de `/api/auth/session`); `409` id já existe |
| `GET` | `/api/auth/handoff/:id` | — | `200 { idToken }` e apaga a linha (uso único); `404` inexistente/expirado |

Sem `withAuth` nas duas (o segredo é o próprio `id`). CORS igual a `/api/auth/session`. Cada `POST` apaga antes as linhas com `expires_at < now`. Testes `node --test`: POST válido → 204 e GET → 200 uma vez, 404 na segunda; POST com token inválido → 400; `id` malformado → 400; expirado → 404; `409` em id repetido.

### 10.3 App

- `OidcRedirectRequest`: campo `handoff`, incluído no `state`; `OidcCallbackParser`: `request_missing`/`csrf_mismatch` + `handoff` válido no `state` → `OidcCallbackHandoff`; sem `handoff` → `Invalid` como antes.
- `AuthRemoteDatasource`: `postHandoff(handoff, idToken)` e `pollHandoff(handoff) → String?` (`ApiEndpoints.authHandoff`).
- `AuthNotifier`: `_awaitHandoff(handoff)` (timer 2 s, prazo 5 min, cancelado em `onDispose`); consumo de `OidcCallbackHandoff` conforme 10.1.
- Testes: parser com/sem `handoff`; notifier — `Handoff` → `postHandoff` chamado, `AsyncError(OidcHandoffDeliveredException)`, store intocado; `startGoogleRedirect` → consulta até `200` e grava sessão; prazo esgotado → para sem erro. Widget: estado «Login concluído».
- Docs: `workers/plpcg-catalog/README.md` (rotas), `docs/GOOGLE_OAUTH_SETUP.md` (seção PWA iOS).
