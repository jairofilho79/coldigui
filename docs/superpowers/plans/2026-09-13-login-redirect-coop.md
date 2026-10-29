# Login Google por redirect + COOP same-origin (P1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar o botão popup do Google Identity Services por um login web via redirect OIDC (fluxo implícito), de modo que `Cross-Origin-Opener-Policy` possa virar `same-origin`, a produção fique cross-origin isolated e o skwasm rode multi-thread.

**Architecture:** Botão Material próprio chama `AuthNotifier.startGoogleRedirect(returnTo)`, que gera `nonce`/`csrf`, guarda-os em `sessionStorage` e navega para `accounts.google.com/o/oauth2/v2/auth` (`response_type=id_token`). O Google volta para `<origin>/#id_token=…&state=…`. No início de `main()`, antes de o go_router existir, `captureOidcRedirectCallback` parseia o fragmento, valida `csrf`/`nonce`, limpa a URL (`replaceState('#<returnTo>')`) e entrega um `OidcCallbackResult` ao `OidcCallbackInbox`; `AuthNotifier.build()` consome o inbox uma vez e chama o Worker (`establishSession`) como hoje. Erros de contexto (`request_missing`/`csrf_mismatch`) têm UI própria que reinicia o login em um toque. Toda a lógica é Dart puro testável em VM; só `OidcBrowser` toca `package:web`.

**Tech Stack:** Flutter 3.44.4 / Dart 3.12, Riverpod 3, go_router 17.3, `package:web` ^1.1.1, `flutter_test`. Sem dependências novas.

**Spec:** `docs/superpowers/specs/2026-09-13-google-login-redirect-coop-design.md` (D1–D17; §10 é contingência e **não** faz parte deste plano — só será planejada se o item 3 do checklist falhar no PWA iOS).

## Global Constraints

- **Worktree próprio:** branch `feat/login-redirect-coop` criada a partir de `web/integration` em `.claude/worktrees/login-redirect-coop`. Nunca commitar direto em `web/integration`. Nunca `git stash` sem nome.
- **Worker `plpcg-catalog` não muda.** Nada em `workers/`.
- **Não tocar** em `lib/features/auth/data/auth_remote_datasource.dart`, `auth_session_store*.dart`, `google_sign_in_button_stub.dart` (exceto a troca de string por l10n na Task 5), nem nas telas que usam o botão (`profile_screen.dart`, `public_playlists_screen.dart`, `favorite_material_kinds_screen.dart`).
- Nomes exatos da spec: chaves `sessionStorage` `plpcg_oidc_request`; endpoint `https://accounts.google.com/o/oauth2/v2/auth`; `scope=openid email profile`; `prompt=select_account`; `redirect_uri = <origin>/`; regex de `returnTo` `^/[A-Za-z0-9/_\-?=&%.]*$` e não começar por `//`; razões `state_missing | csrf_mismatch | nonce_mismatch | jwt_malformed | request_missing`.
- l10n: chaves `authSignInWithGoogle`, `authSignInContextMismatchTitle`, `authSignInContextMismatchBody`, `authSignInOpenInBrowserHint` em `app_pt.arb` **e** `app_en.arb`; depois `flutter gen-l10n` e commitar os `lib/l10n/app_localizations*.dart` gerados.
- Comentários e docs em português, estilo dos arquivos vizinhos (`///` explicando o *porquê*, com referência «spec D9» etc. quando ajudar).
- Antes de cada commit: `dart format` só nos arquivos tocados, `flutter analyze lib test` sem erros nos arquivos tocados, e os testes da task passando (`flutter test <arquivo>`). Na última task: `./scripts/test_all.sh --vm-only` verde.
- Commits com prefixo `feat|fix|refactor|test|docs|chore(escopo):` em português, imperativo, uma linha de assunto. Todo commit termina com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc
  ```
- Não adicionar dependências. Não alterar `pubspec.yaml`.
- `String.fromEnvironment('GOOGLE_CLIENT_ID_WEB')` é vazio no `flutter test`: toda lógica que precisa do client id lê `googleClientIdProvider` (Task 4), nunca `AppConfig` diretamente.

---

## Mapa de arquivos

**Criar**
- `lib/features/auth/data/oidc/oidc_redirect_request.dart` — `OidcRedirectRequest`: nonce/csrf, `state`, URL de autorização, JSON (Dart puro).
- `lib/features/auth/data/oidc/oidc_callback.dart` — `OidcCallbackResult` (+ `Success`/`Cancelled`/`Invalid`), `OidcCallbackParser`, `OidcContextMismatchException` (Dart puro).
- `lib/features/auth/data/oidc/oidc_callback_inbox.dart` — `OidcCallbackInbox.take()` (Dart puro).
- `lib/features/auth/data/oidc/oidc_browser.dart` — interface `OidcBrowser` (Dart puro).
- `lib/features/auth/data/oidc/oidc_browser_factory.dart` — export condicional de `createOidcBrowser()`.
- `lib/features/auth/data/oidc/oidc_browser_stub.dart`, `oidc_browser_web.dart` — implementações.
- `lib/features/auth/data/oidc/oidc_redirect_capture.dart` — `captureOidcRedirectCallback(OidcBrowser)`.
- `lib/features/auth/presentation/widgets/google_logo.dart` — `GoogleLogo` (`CustomPainter`).
- `test/support/fakes/fake_oidc_browser.dart`, `test/support/oidc_test_tokens.dart`.
- `test/unit/features/auth/oidc/oidc_redirect_request_test.dart`, `oidc_callback_test.dart`, `oidc_redirect_capture_test.dart`.
- `test/widget/features/auth/google_sign_in_button_web_test.dart`.
- `test/web/web_headers_test.dart` (VM; lê `web/_headers`).

**Modificar**
- `lib/features/auth/presentation/providers/auth_state_provider.dart` — providers novos, consumo do inbox em `build()`, `startGoogleRedirect`, `_establishAndStore`.
- `lib/features/auth/presentation/widgets/google_sign_in_button_web.dart` — reescrito (sem GIS).
- `lib/features/auth/presentation/widgets/google_sign_in_button_stub.dart` — só rótulo via l10n.
- `lib/main.dart` — captura + override do inbox.
- `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados).
- `web/_headers`, `scripts/web_frontend_server.py`, `scripts/validate_web_coop_coep.sh`, `scripts/verify_web_headers_artifact.sh`.
- `test/unit/features/auth/auth_state_provider_test.dart` — grupo novo.
- `docs/GOOGLE_OAUTH_SETUP.md`, `docs/AUDITORIA_POLIMENTO_2026-09-12.md`, `docs/WEB_PERFORMANCE_RELIABILITY_AUDIT.md`, `docs/web_phase_d_coop_coep_validation.md`.

---

### Task 1: `OidcRedirectRequest` — nonce, csrf, state e URL de autorização

**Files:**
- Create: `lib/features/auth/data/oidc/oidc_redirect_request.dart`
- Test: `test/unit/features/auth/oidc/oidc_redirect_request_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class OidcRedirectRequest {
    const OidcRedirectRequest({required this.nonce, required this.csrf});
    final String nonce; final String csrf;
    static OidcRedirectRequest generate([Random? random]);
    static String encodeState({required String csrf, required String returnTo});
    static Map<String, String>? decodeState(String? raw); // {'csrf','returnTo'} ou null
    String toJson(); static OidcRedirectRequest? fromJson(String? raw);
    Uri authorizationUri({required String clientId, required Uri origin, required String returnTo});
  }
  const String kOidcRequestStorageKey = 'plpcg_oidc_request';
  ```

- [ ] **Step 1: Escrever o teste que falha**

```dart
// test/unit/features/auth/oidc/oidc_redirect_request_test.dart
import 'dart:convert';
import 'dart:math';

import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = OidcRedirectRequest(nonce: 'nonce-1', csrf: 'csrf-1');
  final origin = Uri.parse('https://v2.plpcg.com');

  group('authorizationUri', () {
    final uri = request.authorizationUri(
      clientId: 'cid.apps.googleusercontent.com',
      origin: origin,
      returnTo: '/perfil',
    );

    test('aponta para o endpoint OIDC do Google', () {
      expect(uri.scheme, 'https');
      expect(uri.host, 'accounts.google.com');
      expect(uri.path, '/o/oauth2/v2/auth');
    });

    test('carrega todos os parâmetros do fluxo implícito', () {
      final q = uri.queryParameters;
      expect(q['client_id'], 'cid.apps.googleusercontent.com');
      expect(q['redirect_uri'], 'https://v2.plpcg.com/');
      expect(q['response_type'], 'id_token');
      expect(q['scope'], 'openid email profile');
      expect(q['prompt'], 'select_account');
      expect(q['nonce'], 'nonce-1');
    });

    test('state decodifica para csrf + returnTo', () {
      final state = OidcRedirectRequest.decodeState(uri.queryParameters['state']);
      expect(state, {'csrf': 'csrf-1', 'returnTo': '/perfil'});
    });

    test('redirect_uri termina em barra mesmo com origem sem barra', () {
      final u = request.authorizationUri(
        clientId: 'x',
        origin: Uri.parse('http://localhost:8080'),
        returnTo: '/',
      );
      expect(u.queryParameters['redirect_uri'], 'http://localhost:8080/');
    });
  });

  group('encodeState/decodeState', () {
    test('é base64url sem padding', () {
      final s = OidcRedirectRequest.encodeState(csrf: 'a', returnTo: '/listas/publicas?x=1');
      expect(s, isNot(contains('=')));
      expect(s, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(OidcRedirectRequest.decodeState(s), {'csrf': 'a', 'returnTo': '/listas/publicas?x=1'});
    });

    test('lixo devolve null', () {
      expect(OidcRedirectRequest.decodeState(null), isNull);
      expect(OidcRedirectRequest.decodeState(''), isNull);
      expect(OidcRedirectRequest.decodeState('%%%'), isNull);
      expect(OidcRedirectRequest.decodeState(base64Url.encode(utf8.encode('[1]'))), isNull);
      expect(OidcRedirectRequest.decodeState(base64Url.encode(utf8.encode('{"csrf":1}'))), isNull);
    });
  });

  group('generate', () {
    test('nonce e csrf são base64url de 32 bytes, distintos', () {
      final r = OidcRedirectRequest.generate(Random(7));
      expect(r.nonce, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(r.csrf, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(r.nonce, isNot(r.csrf));
    });

    test('duas gerações não repetem', () {
      expect(OidcRedirectRequest.generate().nonce, isNot(OidcRedirectRequest.generate().nonce));
    });
  });

  group('toJson/fromJson', () {
    test('round-trip', () {
      final back = OidcRedirectRequest.fromJson(request.toJson());
      expect(back?.nonce, 'nonce-1');
      expect(back?.csrf, 'csrf-1');
    });

    test('lixo devolve null', () {
      expect(OidcRedirectRequest.fromJson(null), isNull);
      expect(OidcRedirectRequest.fromJson('nope'), isNull);
      expect(OidcRedirectRequest.fromJson('{"nonce":"a"}'), isNull);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/oidc/oidc_redirect_request_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implementar**

```dart
// lib/features/auth/data/oidc/oidc_redirect_request.dart
import 'dart:convert';
import 'dart:math';

/// Chave em `sessionStorage` com o [OidcRedirectRequest] pendente (spec D6).
const String kOidcRequestStorageKey = 'plpcg_oidc_request';

/// Pedido de login por redirect OIDC (fluxo implícito, spec D1/D6/D7).
///
/// `nonce` vai no JWT devolvido pelo Google (anti-replay); `csrf` vai no
/// `state` e é conferido com o que ficou em `sessionStorage`. Os dois nascem
/// aqui, no clique, e morrem na captura do callback.
class OidcRedirectRequest {
  const OidcRedirectRequest({required this.nonce, required this.csrf});

  final String nonce;
  final String csrf;

  static final Uri _endpoint = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );

  /// 32 bytes aleatórios cada, base64url sem padding (43 chars).
  static OidcRedirectRequest generate([Random? random]) {
    final rng = random ?? Random.secure();
    return OidcRedirectRequest(nonce: _token(rng), csrf: _token(rng));
  }

  static String _token(Random rng) {
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return _b64(bytes);
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// `state` = base64url(`{"csrf","returnTo"}`) sem padding (spec D7).
  static String encodeState({required String csrf, required String returnTo}) {
    return _b64(utf8.encode(jsonEncode({'csrf': csrf, 'returnTo': returnTo})));
  }

  /// Inverso de [encodeState]; `null` para qualquer coisa que não seja um
  /// objeto com `csrf` e `returnTo` strings.
  static Map<String, String>? decodeState(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(raw))),
      );
      if (decoded is! Map) return null;
      final csrf = decoded['csrf'];
      final returnTo = decoded['returnTo'];
      if (csrf is! String || returnTo is! String) return null;
      return {'csrf': csrf, 'returnTo': returnTo};
    } on Object {
      return null;
    }
  }

  /// URL de autorização do Google. `redirect_uri` é sempre `<origin>/` —
  /// só origens cadastradas no Console funcionam (spec D3).
  Uri authorizationUri({
    required String clientId,
    required Uri origin,
    required String returnTo,
  }) {
    final redirectUri = origin.replace(path: '/').toString();
    return _endpoint.replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'id_token',
        'scope': 'openid email profile',
        'prompt': 'select_account',
        'nonce': nonce,
        'state': encodeState(csrf: csrf, returnTo: returnTo),
      },
    );
  }

  String toJson() => jsonEncode({'nonce': nonce, 'csrf': csrf});

  static OidcRedirectRequest? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final nonce = decoded['nonce'];
      final csrf = decoded['csrf'];
      if (nonce is! String || csrf is! String) return null;
      return OidcRedirectRequest(nonce: nonce, csrf: csrf);
    } on Object {
      return null;
    }
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/auth/oidc/oidc_redirect_request_test.dart`
Expected: PASS (11 testes).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/auth/data/oidc test/unit/features/auth/oidc
flutter analyze lib test
git add lib/features/auth/data/oidc/oidc_redirect_request.dart test/unit/features/auth/oidc/oidc_redirect_request_test.dart
git commit -m "feat(auth): OidcRedirectRequest — nonce/csrf, state e URL de autorização do Google"
```

---

### Task 2: `OidcCallbackParser` — parse e validação do fragmento

**Files:**
- Create: `lib/features/auth/data/oidc/oidc_callback.dart`
- Create: `test/support/oidc_test_tokens.dart`
- Test: `test/unit/features/auth/oidc/oidc_callback_test.dart`

**Interfaces:**
- Consumes: `OidcRedirectRequest.decodeState` (Task 1).
- Produces:
  ```dart
  sealed class OidcCallbackResult { String get returnTo; }
  final class OidcCallbackSuccess extends OidcCallbackResult { final String idToken; }
  final class OidcCallbackCancelled extends OidcCallbackResult { final String error; }
  final class OidcCallbackInvalid extends OidcCallbackResult { final String reason; bool get isContextMismatch; }
  abstract final class OidcCallbackParser {
    static OidcCallbackResult? parse({required String fragment, required OidcRedirectRequest? request});
    static String sanitizeReturnTo(String? raw);
  }
  class OidcContextMismatchException implements Exception { final String reason; }
  // test/support/oidc_test_tokens.dart
  String fakeIdToken({required String nonce, Map<String, Object?> extra = const {}});
  ```

- [ ] **Step 1: Helper de token fake**

```dart
// test/support/oidc_test_tokens.dart
//
// JWT "de mentira" para os testes do fluxo OIDC: header + payload base64url
// + assinatura fixa. O cliente só lê o payload (nonce); a assinatura é papel
// do Worker (spec §5), então aqui ela é lixo de propósito.
import 'dart:convert';

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

String fakeIdToken({
  required String nonce,
  Map<String, Object?> extra = const {},
}) {
  final header = _b64({'alg': 'RS256', 'typ': 'JWT'});
  final payload = _b64({'sub': 'sub-1', 'nonce': nonce, ...extra});
  return '$header.$payload.assinatura-fake';
}
```

- [ ] **Step 2: Escrever o teste que falha**

```dart
// test/unit/features/auth/oidc/oidc_callback_test.dart
import 'package:coldigui/features/auth/data/oidc/oidc_callback.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/oidc_test_tokens.dart';

void main() {
  const request = OidcRedirectRequest(nonce: 'n-1', csrf: 'c-1');
  final goodState = OidcRedirectRequest.encodeState(csrf: 'c-1', returnTo: '/perfil');
  final wrongCsrfState = OidcRedirectRequest.encodeState(csrf: 'c-X', returnTo: '/perfil');

  OidcCallbackResult? parse(String fragment, {OidcRedirectRequest? req = request}) =>
      OidcCallbackParser.parse(fragment: fragment, request: req);

  group('não é callback', () {
    test('fragmento vazio', () => expect(parse(''), isNull));
    test('rota do go_router', () => expect(parse('/leitor?id=1'), isNull));
    test('rota com state na query', () => expect(parse('/x?state=abc'), isNull));
    test('sem state', () => expect(parse('foo=bar'), isNull));
    test('sem state com id_token', () => expect(parse('id_token=abc'), isNull));
  });

  group('sucesso', () {
    test('id_token com nonce certo e csrf certo', () {
      final token = fakeIdToken(nonce: 'n-1');
      final r = parse('id_token=$token&state=$goodState');
      expect(r, isA<OidcCallbackSuccess>());
      expect((r! as OidcCallbackSuccess).idToken, token);
      expect(r.returnTo, '/perfil');
    });

    test('ordem dos parâmetros não importa', () {
      final token = fakeIdToken(nonce: 'n-1');
      final r = parse('state=$goodState&authuser=0&id_token=$token&prompt=none');
      expect(r, isA<OidcCallbackSuccess>());
    });
  });

  group('cancelamento', () {
    test('error=access_denied', () {
      final r = parse('error=access_denied&state=$goodState');
      expect(r, isA<OidcCallbackCancelled>());
      expect((r! as OidcCallbackCancelled).error, 'access_denied');
      expect(r.returnTo, '/perfil');
    });
  });

  group('inválido', () {
    OidcCallbackInvalid invalid(OidcCallbackResult? r) {
      expect(r, isA<OidcCallbackInvalid>());
      return r! as OidcCallbackInvalid;
    }

    test('request ausente → request_missing (contexto)', () {
      final r = invalid(parse('id_token=${fakeIdToken(nonce: 'n-1')}&state=$goodState', req: null));
      expect(r.reason, 'request_missing');
      expect(r.isContextMismatch, isTrue);
      expect(r.returnTo, '/perfil');
    });

    test('csrf diferente → csrf_mismatch (contexto)', () {
      final r = invalid(parse('id_token=${fakeIdToken(nonce: 'n-1')}&state=$wrongCsrfState'));
      expect(r.reason, 'csrf_mismatch');
      expect(r.isContextMismatch, isTrue);
    });

    test('state indecifrável → state_missing', () {
      final r = invalid(parse('id_token=${fakeIdToken(nonce: 'n-1')}&state=@@@'));
      expect(r.reason, 'state_missing');
      expect(r.isContextMismatch, isFalse);
      expect(r.returnTo, '/');
    });

    test('nonce diferente → nonce_mismatch', () {
      final r = invalid(parse('id_token=${fakeIdToken(nonce: 'outro')}&state=$goodState'));
      expect(r.reason, 'nonce_mismatch');
      expect(r.isContextMismatch, isFalse);
    });

    test('JWT com 2 segmentos → jwt_malformed', () {
      expect(invalid(parse('id_token=a.b&state=$goodState')).reason, 'jwt_malformed');
    });

    test('payload não-JSON → jwt_malformed', () {
      expect(invalid(parse('id_token=a.bm90LWpzb24.c&state=$goodState')).reason, 'jwt_malformed');
    });

    test('state ok mas sem id_token nem error → jwt_malformed', () {
      expect(invalid(parse('state=$goodState')).reason, 'jwt_malformed');
    });
  });

  group('sanitizeReturnTo', () {
    test('aceita caminhos da app', () {
      expect(OidcCallbackParser.sanitizeReturnTo('/perfil'), '/perfil');
      expect(OidcCallbackParser.sanitizeReturnTo('/listas/publicas?x=1&y=2'), '/listas/publicas?x=1&y=2');
      expect(OidcCallbackParser.sanitizeReturnTo('/materiais-favoritos'), '/materiais-favoritos');
    });

    test('rejeita o resto', () {
      expect(OidcCallbackParser.sanitizeReturnTo(null), '/');
      expect(OidcCallbackParser.sanitizeReturnTo(''), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('//evil.com'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('https://x'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('perfil'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('/a b'), '/');
      expect(OidcCallbackParser.sanitizeReturnTo('/a#b'), '/');
    });
  });

  test('OidcContextMismatchException carrega a razão', () {
    expect(OidcContextMismatchException('csrf_mismatch').toString(), contains('csrf_mismatch'));
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/oidc/oidc_callback_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 4: Implementar**

```dart
// lib/features/auth/data/oidc/oidc_callback.dart
import 'dart:convert';

import 'oidc_redirect_request.dart';

/// Resultado da volta do Google (spec §3.2). `returnTo` já saneado (D8).
sealed class OidcCallbackResult {
  const OidcCallbackResult(this.returnTo);
  final String returnTo;
}

/// `id_token` com `nonce` e `csrf` conferidos — falta só o Worker validar.
final class OidcCallbackSuccess extends OidcCallbackResult {
  const OidcCallbackSuccess({required this.idToken, required String returnTo})
    : super(returnTo);
  final String idToken;
}

/// Usuário cancelou (ou Google recusou): `error=access_denied` etc.
final class OidcCallbackCancelled extends OidcCallbackResult {
  const OidcCallbackCancelled({required this.error, required String returnTo})
    : super(returnTo);
  final String error;
}

/// Callback que não pode ser aceito. `isContextMismatch` separa «o Google
/// respondeu num contexto que não iniciou o login» (aba restaurada, navegador
/// embutido do PWA iOS — spec D15) de adulteração/lixo.
final class OidcCallbackInvalid extends OidcCallbackResult {
  const OidcCallbackInvalid({required this.reason, required String returnTo})
    : super(returnTo);

  /// `state_missing | csrf_mismatch | nonce_mismatch | jwt_malformed | request_missing`
  final String reason;

  bool get isContextMismatch =>
      reason == 'request_missing' || reason == 'csrf_mismatch';
}

/// Lançada pelo `AuthNotifier` para o botão mostrar a UI de D15.
class OidcContextMismatchException implements Exception {
  const OidcContextMismatchException(this.reason);
  final String reason;

  @override
  String toString() => 'OidcContextMismatchException($reason)';
}

abstract final class OidcCallbackParser {
  static final RegExp _returnToPattern = RegExp(r'^/[A-Za-z0-9/_\-?=&%.]*$');

  /// `fragment` é `location.hash` sem o `#`. Devolve `null` quando não é um
  /// callback do Google — rota normal do hash router (`/leitor?...`), vazio
  /// ou qualquer coisa sem `state`.
  ///
  /// A assinatura do JWT **não** é verificada aqui (papel do Worker, spec §5);
  /// só o `nonce` do payload é comparado com o do [request].
  static OidcCallbackResult? parse({
    required String fragment,
    required OidcRedirectRequest? request,
  }) {
    if (fragment.isEmpty || fragment.startsWith('/')) return null;
    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(fragment);
    } on Object {
      return null;
    }
    final rawState = params['state'];
    if (rawState == null) return null;

    final state = OidcRedirectRequest.decodeState(rawState);
    if (state == null) {
      return const OidcCallbackInvalid(reason: 'state_missing', returnTo: '/');
    }
    final returnTo = sanitizeReturnTo(state['returnTo']);

    if (request == null) {
      return OidcCallbackInvalid(reason: 'request_missing', returnTo: returnTo);
    }
    if (state['csrf'] != request.csrf) {
      return OidcCallbackInvalid(reason: 'csrf_mismatch', returnTo: returnTo);
    }

    final error = params['error'];
    if (error != null && error.isNotEmpty) {
      return OidcCallbackCancelled(error: error, returnTo: returnTo);
    }

    final idToken = params['id_token'];
    final nonce = idToken == null ? null : _nonceOf(idToken);
    if (nonce == null) {
      return OidcCallbackInvalid(reason: 'jwt_malformed', returnTo: returnTo);
    }
    if (nonce != request.nonce) {
      return OidcCallbackInvalid(reason: 'nonce_mismatch', returnTo: returnTo);
    }
    return OidcCallbackSuccess(idToken: idToken!, returnTo: returnTo);
  }

  /// `nonce` do payload (2º segmento, base64url) ou `null` se malformado.
  static String? _nonceOf(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final nonce = payload['nonce'];
      return nonce is String ? nonce : null;
    } on Object {
      return null;
    }
  }

  /// Caminho do hash router da própria app, ou `/` (spec D8).
  static String sanitizeReturnTo(String? raw) {
    if (raw == null || raw.startsWith('//')) return '/';
    return _returnToPattern.hasMatch(raw) ? raw : '/';
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/unit/features/auth/oidc/oidc_callback_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/auth/data/oidc test/unit/features/auth/oidc test/support/oidc_test_tokens.dart
flutter analyze lib test
git add lib/features/auth/data/oidc/oidc_callback.dart test/support/oidc_test_tokens.dart test/unit/features/auth/oidc/oidc_callback_test.dart
git commit -m "feat(auth): OidcCallbackParser — parse do fragmento e validação de csrf/nonce"
```

---

### Task 3: `OidcBrowser`, `OidcCallbackInbox` e `captureOidcRedirectCallback`

**Files:**
- Create: `lib/features/auth/data/oidc/oidc_browser.dart`
- Create: `lib/features/auth/data/oidc/oidc_browser_factory.dart`
- Create: `lib/features/auth/data/oidc/oidc_browser_stub.dart`
- Create: `lib/features/auth/data/oidc/oidc_browser_web.dart`
- Create: `lib/features/auth/data/oidc/oidc_callback_inbox.dart`
- Create: `lib/features/auth/data/oidc/oidc_redirect_capture.dart`
- Create: `test/support/fakes/fake_oidc_browser.dart`
- Test: `test/unit/features/auth/oidc/oidc_redirect_capture_test.dart`

**Interfaces:**
- Consumes: `OidcCallbackParser.parse`, `OidcRedirectRequest.fromJson`, `kOidcRequestStorageKey` (Tasks 1–2).
- Produces:
  ```dart
  abstract interface class OidcBrowser {
    Uri get origin; String get fragment; bool get isStandaloneDisplay;
    String? readRequest(); void writeRequest(String json); void clearRequest();
    void navigate(Uri uri); void replaceHash(String path);
  }
  OidcBrowser createOidcBrowser(); // oidc_browser_factory.dart
  class OidcCallbackInbox { OidcCallbackInbox([OidcCallbackResult? pending]); OidcCallbackResult? take(); }
  OidcCallbackResult? captureOidcRedirectCallback(OidcBrowser browser);
  // test/support/fakes/fake_oidc_browser.dart
  class FakeOidcBrowser implements OidcBrowser {
    FakeOidcBrowser({Uri? origin, String fragment = '', String? storedRequest, bool standalone = false});
    String? storedRequest; final List<Uri> navigated; final List<String> replacedHashes; int clearRequestCalls;
  }
  ```

- [ ] **Step 1: Interface, inbox e fake**

```dart
// lib/features/auth/data/oidc/oidc_browser.dart
/// Tudo que o fluxo OIDC precisa do navegador (spec §3.4). Implementação web
/// em `oidc_browser_web.dart`; nativo lança — o botão nativo usa o plugin.
abstract interface class OidcBrowser {
  /// `window.location.origin`.
  Uri get origin;

  /// `window.location.hash` sem o `#`.
  String get fragment;

  /// PWA instalado (`display-mode: standalone` ou `navigator.standalone`) —
  /// só para a dica de D15.
  bool get isStandaloneDisplay;

  String? readRequest();
  void writeRequest(String json);
  void clearRequest();

  /// `window.location.assign` — a página inteira vai para o Google.
  void navigate(Uri uri);

  /// `history.replaceState(null, '', '#$path')` — tira o token da URL antes
  /// de o go_router ler o hash.
  void replaceHash(String path);
}
```

```dart
// lib/features/auth/data/oidc/oidc_browser_factory.dart
export 'oidc_browser_stub.dart'
    if (dart.library.js_interop) 'oidc_browser_web.dart';
```

```dart
// lib/features/auth/data/oidc/oidc_browser_stub.dart
import 'oidc_browser.dart';

/// Nativo/testes sem override: nunca deve ser chamado — o botão nativo usa o
/// plugin `google_sign_in`. Lançar deixa um uso indevido evidente.
OidcBrowser createOidcBrowser() => const _UnsupportedOidcBrowser();

class _UnsupportedOidcBrowser implements OidcBrowser {
  const _UnsupportedOidcBrowser();

  Never _unsupported() =>
      throw UnsupportedError('OIDC redirect só existe na web');

  @override
  Uri get origin => _unsupported();
  @override
  String get fragment => '';
  @override
  bool get isStandaloneDisplay => false;
  @override
  String? readRequest() => null;
  @override
  void writeRequest(String json) => _unsupported();
  @override
  void clearRequest() {}
  @override
  void navigate(Uri uri) => _unsupported();
  @override
  void replaceHash(String path) {}
}
```

```dart
// lib/features/auth/data/oidc/oidc_browser_web.dart
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'oidc_browser.dart';
import 'oidc_redirect_request.dart';

OidcBrowser createOidcBrowser() => const _WebOidcBrowser();

class _WebOidcBrowser implements OidcBrowser {
  const _WebOidcBrowser();

  @override
  Uri get origin => Uri.parse(web.window.location.origin);

  @override
  String get fragment {
    final hash = web.window.location.hash;
    return hash.startsWith('#') ? hash.substring(1) : hash;
  }

  @override
  bool get isStandaloneDisplay {
    final media = web.window.matchMedia('(display-mode: standalone)').matches;
    // `navigator.standalone` é só do Safari iOS — fora do `package:web`.
    final standalone = web.window.navigator
        .getProperty<JSBoolean?>('standalone'.toJS)
        ?.toDart;
    return media || (standalone ?? false);
  }

  @override
  String? readRequest() =>
      web.window.sessionStorage.getItem(kOidcRequestStorageKey);

  @override
  void writeRequest(String json) =>
      web.window.sessionStorage.setItem(kOidcRequestStorageKey, json);

  @override
  void clearRequest() =>
      web.window.sessionStorage.removeItem(kOidcRequestStorageKey);

  @override
  void navigate(Uri uri) => web.window.location.assign(uri.toString());

  @override
  void replaceHash(String path) =>
      web.window.history.replaceState(null, '', '#$path');
}
```

```dart
// lib/features/auth/data/oidc/oidc_callback_inbox.dart
import 'oidc_callback.dart';

/// Entrega única do callback capturado em `main()` ao `AuthNotifier`
/// (spec D9): `take()` devolve e esvazia, então um `invalidate` do provider
/// não reprocessa o mesmo token.
class OidcCallbackInbox {
  OidcCallbackInbox([this._pending]);

  OidcCallbackResult? _pending;

  OidcCallbackResult? take() {
    final result = _pending;
    _pending = null;
    return result;
  }
}
```

```dart
// test/support/fakes/fake_oidc_browser.dart
import 'package:coldigui/features/auth/data/oidc/oidc_browser.dart';

/// Navegador de mentira para o fluxo OIDC: registra navegações e
/// `replaceState`, guarda o request em memória.
class FakeOidcBrowser implements OidcBrowser {
  FakeOidcBrowser({
    Uri? origin,
    this.fragment = '',
    this.storedRequest,
    bool standalone = false,
  }) : origin = origin ?? Uri.parse('https://v2.plpcg.com'),
       isStandaloneDisplay = standalone;

  @override
  final Uri origin;
  @override
  String fragment;
  @override
  final bool isStandaloneDisplay;

  String? storedRequest;
  final List<Uri> navigated = [];
  final List<String> replacedHashes = [];
  int clearRequestCalls = 0;

  @override
  String? readRequest() => storedRequest;
  @override
  void writeRequest(String json) => storedRequest = json;
  @override
  void clearRequest() {
    clearRequestCalls++;
    storedRequest = null;
  }

  @override
  void navigate(Uri uri) => navigated.add(uri);
  @override
  void replaceHash(String path) => replacedHashes.add(path);
}
```

- [ ] **Step 2: Escrever o teste da captura que falha**

```dart
// test/unit/features/auth/oidc/oidc_redirect_capture_test.dart
import 'package:coldigui/features/auth/data/oidc/oidc_callback.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_callback_inbox.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_capture.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fakes/fake_oidc_browser.dart';
import '../../../../support/oidc_test_tokens.dart';

void main() {
  const request = OidcRedirectRequest(nonce: 'n-1', csrf: 'c-1');
  final state = OidcRedirectRequest.encodeState(csrf: 'c-1', returnTo: '/perfil');

  test('hash de rota normal: não toca em storage nem URL', () {
    final browser = FakeOidcBrowser(fragment: '/leitor?id=1', storedRequest: request.toJson());
    expect(captureOidcRedirectCallback(browser), isNull);
    expect(browser.storedRequest, isNotNull);
    expect(browser.clearRequestCalls, 0);
    expect(browser.replacedHashes, isEmpty);
  });

  test('callback válido: consome request e reescreve o hash para returnTo', () {
    final token = fakeIdToken(nonce: 'n-1');
    final browser = FakeOidcBrowser(fragment: 'id_token=$token&state=$state', storedRequest: request.toJson());

    final result = captureOidcRedirectCallback(browser);

    expect(result, isA<OidcCallbackSuccess>());
    expect((result! as OidcCallbackSuccess).idToken, token);
    expect(browser.clearRequestCalls, 1);
    expect(browser.storedRequest, isNull);
    expect(browser.replacedHashes, ['/perfil']);
  });

  test('cancelamento: idem, com Cancelled', () {
    final browser = FakeOidcBrowser(fragment: 'error=access_denied&state=$state', storedRequest: request.toJson());
    expect(captureOidcRedirectCallback(browser), isA<OidcCallbackCancelled>());
    expect(browser.clearRequestCalls, 1);
    expect(browser.replacedHashes, ['/perfil']);
  });

  test('sem request no storage: Invalid(request_missing) e URL limpa', () {
    final browser = FakeOidcBrowser(fragment: 'id_token=${fakeIdToken(nonce: 'n-1')}&state=$state');
    final result = captureOidcRedirectCallback(browser);
    expect(result, isA<OidcCallbackInvalid>());
    expect((result! as OidcCallbackInvalid).reason, 'request_missing');
    expect(browser.replacedHashes, ['/perfil']);
  });

  test('request ilegível no storage conta como ausente', () {
    final browser = FakeOidcBrowser(fragment: 'id_token=${fakeIdToken(nonce: 'n-1')}&state=$state', storedRequest: 'lixo');
    final result = captureOidcRedirectCallback(browser);
    expect((result! as OidcCallbackInvalid).reason, 'request_missing');
    expect(browser.clearRequestCalls, 1);
  });

  test('OidcCallbackInbox.take entrega uma vez', () {
    final inbox = OidcCallbackInbox(const OidcCallbackCancelled(error: 'x', returnTo: '/'));
    expect(inbox.take(), isA<OidcCallbackCancelled>());
    expect(inbox.take(), isNull);
    expect(OidcCallbackInbox().take(), isNull);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/oidc/oidc_redirect_capture_test.dart`
Expected: FAIL — `oidc_redirect_capture.dart` não existe.

- [ ] **Step 4: Implementar a captura**

```dart
// lib/features/auth/data/oidc/oidc_redirect_capture.dart
import 'oidc_browser.dart';
import 'oidc_callback.dart';
import 'oidc_redirect_request.dart';

/// Chamado no início de `main()`, **antes** de o go_router existir (spec D5):
/// se o hash é um callback do Google, consome o request pendente, tira o
/// token da URL e devolve o resultado. Hash de rota normal → `null`, sem
/// tocar em nada.
OidcCallbackResult? captureOidcRedirectCallback(OidcBrowser browser) {
  final fragment = browser.fragment;
  if (fragment.isEmpty || fragment.startsWith('/')) return null;

  final request = OidcRedirectRequest.fromJson(browser.readRequest());
  final result = OidcCallbackParser.parse(fragment: fragment, request: request);
  if (result == null) return null;

  browser.clearRequest();
  browser.replaceHash(result.returnTo);
  return result;
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/unit/features/auth/oidc/`
Expected: PASS (todos os arquivos da pasta).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/auth/data/oidc test/unit/features/auth/oidc test/support/fakes/fake_oidc_browser.dart
flutter analyze lib test
git add lib/features/auth/data/oidc test/support/fakes/fake_oidc_browser.dart test/unit/features/auth/oidc/oidc_redirect_capture_test.dart
git commit -m "feat(auth): OidcBrowser (web/stub), inbox e captura do callback antes do router"
```

---

### Task 4: `AuthNotifier` — consumir o callback e iniciar o redirect

**Files:**
- Modify: `lib/features/auth/presentation/providers/auth_state_provider.dart` (imports; providers após `authRemoteDatasourceProvider`; `build()` linhas 118-162; `_completeSignIn` linhas 252-270; método novo)
- Test: `test/unit/features/auth/auth_state_provider_test.dart` (grupo novo no fim do `main`)

**Interfaces:**
- Consumes: `OidcCallbackInbox`, `OidcBrowser`, `createOidcBrowser`, `OidcRedirectRequest`, `OidcCallbackResult`s, `OidcContextMismatchException` (Tasks 1–3).
- Produces:
  ```dart
  final googleClientIdProvider = Provider<String>(...);          // default AppConfig.googleClientIdWeb
  final oidcBrowserProvider = Provider<OidcBrowser>(...);         // default createOidcBrowser()
  final oidcCallbackInboxProvider = Provider<OidcCallbackInbox>(...); // default vazio
  // AuthNotifier
  void startGoogleRedirect({required String returnTo});
  ```

- [ ] **Step 1: Escrever os testes que falham**

Adicionar ao fim de `main()` em `test/unit/features/auth/auth_state_provider_test.dart` (e os imports novos no topo: `oidc_callback.dart`, `oidc_callback_inbox.dart`, `oidc_redirect_request.dart`, `../../../support/fakes/fake_oidc_browser.dart`). O `buildContainer` existente ganha dois parâmetros opcionais — `OidcCallbackInbox? inbox` e `FakeOidcBrowser? browser` — que, quando não nulos, entram em `overrides` como `oidcCallbackInboxProvider.overrideWithValue(inbox)` e `oidcBrowserProvider.overrideWithValue(browser)`; e sempre adiciona `googleClientIdProvider.overrideWithValue('cid-test')`.

```dart
  group('AuthNotifier.build — callback OIDC pendente (spec D9/D15)', () {
    const oidcUser = AuthUser(googleSub: 'sub-oidc', idToken: 'tok-oidc', email: 'o@b.com');

    test('Success: establishSession recebe o id_token e a sessão é gravada, ignorando a armazenada', () async {
      final store = seededStore(); // sessão antiga 'token-1'
      final received = <String>[];
      final container = buildContainer(
        store: store,
        behavior: (token) async {
          received.add(token);
          return oidcUser;
        },
        inbox: OidcCallbackInbox(const OidcCallbackSuccess(idToken: 'tok-oidc', returnTo: '/perfil')),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(received, ['tok-oidc']);
      expect(result?.googleSub, 'sub-oidc');
      expect(store.read()?.idToken, 'tok-oidc');
    });

    test('Success + Worker 401: AsyncError, store limpo, inbox vazio', () async {
      final store = seededStore();
      final inbox = OidcCallbackInbox(const OidcCallbackSuccess(idToken: 'tok-oidc', returnTo: '/'));
      final container = buildContainer(
        store: store,
        behavior: (_) async => throw AuthUnauthorizedException(401),
        inbox: inbox,
      );
      addTearDown(container.dispose);

      await expectLater(container.read(authStateProvider.future), throwsA(isA<AuthUnauthorizedException>()));
      expect(store.read(), isNull);
      expect(inbox.take(), isNull);
    });

    test('Cancelled: segue para a sessão armazenada', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async => storedUser,
        inbox: OidcCallbackInbox(const OidcCallbackCancelled(error: 'access_denied', returnTo: '/')),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);
      expect(result?.googleSub, 'sub-1');
    });

    test('Invalid(nonce_mismatch): AsyncError com StateError', () async {
      final container = buildContainer(
        store: AuthSessionStore(),
        behavior: (_) async => storedUser,
        inbox: OidcCallbackInbox(const OidcCallbackInvalid(reason: 'nonce_mismatch', returnTo: '/')),
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(authStateProvider.future),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'oidc_nonce_mismatch')),
      );
    });

    for (final reason in ['request_missing', 'csrf_mismatch']) {
      test('Invalid($reason): AsyncError com OidcContextMismatchException', () async {
        final container = buildContainer(
          store: AuthSessionStore(),
          behavior: (_) async => storedUser,
          inbox: OidcCallbackInbox(OidcCallbackInvalid(reason: reason, returnTo: '/')),
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(authStateProvider.future),
          throwsA(isA<OidcContextMismatchException>().having((e) => e.reason, 'reason', reason)),
        );
      });
    }

    test('inbox vazio: comportamento atual (sessão armazenada)', () async {
      final container = buildContainer(
        store: seededStore(),
        behavior: (_) async => storedUser,
        inbox: OidcCallbackInbox(),
      );
      addTearDown(container.dispose);
      expect((await container.read(authStateProvider.future))?.googleSub, 'sub-1');
    });
  });

  group('AuthNotifier.startGoogleRedirect (spec §3.6)', () {
    test('grava o request e navega para o Google com state.returnTo', () async {
      final browser = FakeOidcBrowser();
      final container = buildContainer(
        store: AuthSessionStore(),
        behavior: (_) async => storedUser,
        browser: browser,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      container.read(authStateProvider.notifier).startGoogleRedirect(returnTo: '/listas/publicas');

      final request = OidcRedirectRequest.fromJson(browser.storedRequest);
      expect(request, isNotNull);
      expect(browser.navigated, hasLength(1));
      final q = browser.navigated.single.queryParameters;
      expect(browser.navigated.single.host, 'accounts.google.com');
      expect(q['client_id'], 'cid-test');
      expect(q['redirect_uri'], 'https://v2.plpcg.com/');
      expect(q['nonce'], request!.nonce);
      expect(OidcRedirectRequest.decodeState(q['state']), {'csrf': request.csrf, 'returnTo': '/listas/publicas'});
    });

    test('client id vazio: StateError e nada navega', () async {
      final browser = FakeOidcBrowser();
      final container = ProviderContainer(
        overrides: [
          authSessionStoreProvider.overrideWithValue(AuthSessionStore()),
          authRemoteDatasourceProvider.overrideWithValue(FakeAuthRemoteDatasource.returning(storedUser)),
          googleClientIdProvider.overrideWithValue(''),
          oidcBrowserProvider.overrideWithValue(browser),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(authStateProvider.notifier).startGoogleRedirect(returnTo: '/'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'google_client_id_missing')),
      );
      expect(browser.navigated, isEmpty);
      expect(browser.storedRequest, isNull);
    });
  });
```

Nota: os testes existentes do arquivo passam `initializer` para simular o SDK; nos grupos novos, sem `initializer`, o default tenta `GoogleSignIn.instance.initialize` — na VM isso lança `MissingPluginException`, que `build()` já captura (`unavailable=true`). Isso é o comportamento desejado por D10: o callback é processado mesmo com o SDK indisponível. Se algum teste novo travar nesse ponto, passe `initializer: () async => const Stream.empty()` — mas primeiro confirme que os testes antigos do arquivo continuam passando sem mudanças.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/auth_state_provider_test.dart`
Expected: FAIL — `oidcCallbackInboxProvider`/`startGoogleRedirect` não definidos.

- [ ] **Step 3: Implementar**

Imports novos em `auth_state_provider.dart`:

```dart
import '../../data/oidc/oidc_browser.dart';
import '../../data/oidc/oidc_browser_factory.dart';
import '../../data/oidc/oidc_callback.dart';
import '../../data/oidc/oidc_callback_inbox.dart';
import '../../data/oidc/oidc_redirect_request.dart';
```

Providers (logo após `authRemoteDatasourceProvider`):

```dart
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
```

Em `build()`, substituir o trecho a partir de `final stored = ...` por:

```dart
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
        if (isContextMismatch) throw OidcContextMismatchException(reason);
        throw StateError('oidc_$reason');
      case OidcCallbackCancelled() || null:
        break;
    }

    final stored = ref.read(authSessionStoreProvider).read();
    if (stored == null) return null;
    // ... (restante inalterado)
```

Método novo (junto de `signInWithGoogle`):

```dart
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
```

Refatorar `_completeSignIn` para delegar:

```dart
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
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/auth/`
Expected: PASS — grupos novos e antigos.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/auth/presentation/providers/auth_state_provider.dart test/unit/features/auth/auth_state_provider_test.dart
flutter analyze lib test
git add lib/features/auth/presentation/providers/auth_state_provider.dart test/unit/features/auth/auth_state_provider_test.dart
git commit -m "feat(auth): AuthNotifier consome o callback OIDC e inicia o login por redirect"
```

---

### Task 5: `main.dart`, l10n e rótulo do botão nativo

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/l10n/app_pt.arb` (após `authSignInRetry`, linha 683), `lib/l10n/app_en.arb` (após linha 668) + gerados via `flutter gen-l10n`
- Modify: `lib/features/auth/presentation/widgets/google_sign_in_button_stub.dart`

**Interfaces:**
- Consumes: `captureOidcRedirectCallback`, `createOidcBrowser`, `OidcCallbackInbox`, `oidcCallbackInboxProvider` (Tasks 3–4).
- Produces: `l10n.authSignInWithGoogle`, `l10n.authSignInContextMismatchTitle`, `l10n.authSignInContextMismatchBody`, `l10n.authSignInOpenInBrowserHint`.

- [ ] **Step 1: Chaves l10n**

`app_pt.arb` (depois de `"authSignInRetry"`):

```json
  "authSignInWithGoogle": "Entrar com o Google",
  "authSignInContextMismatchTitle": "Não conseguimos concluir o login",
  "authSignInContextMismatchBody": "O Google respondeu em outra janela. Toque para tentar novamente.",
  "authSignInOpenInBrowserHint": "Se continuar, abra v2.plpcg.com no Safari.",
```

`app_en.arb`:

```json
  "authSignInWithGoogle": "Sign in with Google",
  "authSignInContextMismatchTitle": "We couldn't finish signing you in",
  "authSignInContextMismatchBody": "Google answered in another window. Tap to try again.",
  "authSignInOpenInBrowserHint": "If this keeps happening, open v2.plpcg.com in Safari.",
```

Run: `flutter gen-l10n` → confirmar que `lib/l10n/app_localizations_pt.dart` ganhou `authSignInWithGoogle`.

- [ ] **Step 2: Botão nativo usa a chave**

Em `google_sign_in_button_stub.dart`, importar `../../../../l10n/app_localizations.dart`, e trocar `label: Text(busy ? 'Entrando…' : 'Entrar com o Google')` por:

```dart
      label: Text(
        busy ? 'Entrando…' : AppLocalizations.of(context)!.authSignInWithGoogle,
      ),
```

(«Entrando…» fica literal: é transitório e já era assim; não é objetivo deste plano traduzir o stub inteiro.)

- [ ] **Step 3: `main.dart`**

Imports:

```dart
import 'features/auth/data/oidc/oidc_browser_factory.dart';
import 'features/auth/data/oidc/oidc_callback_inbox.dart';
import 'features/auth/data/oidc/oidc_redirect_capture.dart';
import 'features/auth/presentation/providers/auth_state_provider.dart';
```

Dentro do `runZonedGuarded`, logo após `installErrorHandlers(_errorReporter);` e **antes** de `configureGoRouterGlobals();`:

```dart
      // Callback do login Google por redirect: tem de sair da URL antes de o
      // go_router ler o hash (spec D5). Nativo devolve null.
      final oidcCallback = captureOidcRedirectCallback(createOidcBrowser());
```

E em `overrides`:

```dart
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            oidcCallbackInboxProvider.overrideWithValue(
              OidcCallbackInbox(oidcCallback),
            ),
          ],
```

- [ ] **Step 4: Verificar**

Run: `flutter analyze lib test && flutter test test/widget/bootstrap_app_test.dart test/widget/features/app_shell test/unit/features/auth`
Expected: PASS. (`main.dart` não tem teste próprio; `bootstrap_app_test` cobre a árvore abaixo.)

- [ ] **Step 5: Commit**

```bash
dart format lib/main.dart lib/features/auth/presentation/widgets/google_sign_in_button_stub.dart
git add lib/main.dart lib/l10n lib/features/auth/presentation/widgets/google_sign_in_button_stub.dart
git commit -m "feat(auth): captura do callback OIDC em main() e chaves l10n do login"
```

---

### Task 6: Botão web próprio + `GoogleLogo`

**Files:**
- Create: `lib/features/auth/presentation/widgets/google_logo.dart`
- Modify: `lib/features/auth/presentation/widgets/google_sign_in_button_web.dart` (reescrever)
- Test: `test/widget/features/auth/google_sign_in_button_web_test.dart`

**Interfaces:**
- Consumes: `googleClientIdProvider`, `oidcBrowserProvider`, `authStateProvider.notifier.startGoogleRedirect`, `OidcContextMismatchException`, chaves l10n (Tasks 2, 4, 5), `FakeOidcBrowser`.
- Produces: `GoogleLogo({double size = 18})`; `GoogleSignInButton` (web) — mesmo nome/constructor de antes.

- [ ] **Step 1: Escrever o teste que falha**

```dart
// test/widget/features/auth/google_sign_in_button_web_test.dart
//
// Importa a variante web diretamente: depois da spec D2 ela não usa
// `package:web` nem o plugin, então roda na VM com o navegador fake.
import 'package:coldigui/features/auth/data/oidc/oidc_callback.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/auth/presentation/widgets/google_sign_in_button_web.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes/fake_oidc_browser.dart';

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _ContextMismatch extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      throw const OidcContextMismatchException('request_missing');
}

class _GenericError extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => throw StateError('boom');
}

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  Future<void> pump(
    WidgetTester tester, {
    required FakeOidcBrowser browser,
    AuthNotifier Function() auth = _LoggedOut.new,
    String clientId = 'cid-test',
    String location = '/perfil',
  }) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/perfil', builder: (_, __) => const Scaffold(body: GoogleSignInButton())),
        GoRoute(path: '/listas/publicas', builder: (_, __) => const Scaffold(body: GoogleSignInButton())),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authStateProvider.overrideWith(auth),
          googleClientIdProvider.overrideWithValue(clientId),
          oidcBrowserProvider.overrideWithValue(browser),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deslogado: botão com rótulo l10n e logo', (tester) async {
    await pump(tester, browser: FakeOidcBrowser());
    expect(find.text(pt.authSignInWithGoogle), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('tap navega para o Google com a rota atual no state', (tester) async {
    final browser = FakeOidcBrowser();
    await pump(tester, browser: browser, location: '/listas/publicas');

    await tester.tap(find.text(pt.authSignInWithGoogle));
    await tester.pump();

    expect(browser.navigated, hasLength(1));
    final uri = browser.navigated.single;
    expect(uri.host, 'accounts.google.com');
    final request = OidcRedirectRequest.fromJson(browser.storedRequest)!;
    expect(OidcRedirectRequest.decodeState(uri.queryParameters['state']),
        {'csrf': request.csrf, 'returnTo': '/listas/publicas'});
  });

  testWidgets('client id vazio: texto de indisponível, sem botão', (tester) async {
    await pump(tester, browser: FakeOidcBrowser(), clientId: '');
    expect(find.text(pt.authSignInUnavailable), findsOneWidget);
    expect(find.text(pt.authSignInWithGoogle), findsNothing);
  });

  testWidgets('erro genérico: «Tentar novamente»', (tester) async {
    await pump(tester, browser: FakeOidcBrowser(), auth: _GenericError.new);
    expect(find.text(pt.authSignInUnavailable), findsOneWidget);
    expect(find.text(pt.authSignInRetry), findsOneWidget);
  });

  testWidgets('erro de contexto: título, texto e botão que reinicia o login', (tester) async {
    final browser = FakeOidcBrowser();
    await pump(tester, browser: browser, auth: _ContextMismatch.new);

    expect(find.text(pt.authSignInContextMismatchTitle), findsOneWidget);
    expect(find.text(pt.authSignInContextMismatchBody), findsOneWidget);
    expect(find.text(pt.authSignInOpenInBrowserHint), findsNothing);
    expect(find.text(pt.authSignInRetry), findsNothing);

    await tester.tap(find.text(pt.authSignInWithGoogle));
    await tester.pump();
    expect(browser.navigated, hasLength(1));
    expect(browser.storedRequest, isNotNull);
  });

  testWidgets('erro de contexto em standalone: mostra a dica do Safari', (tester) async {
    await pump(tester, browser: FakeOidcBrowser(standalone: true), auth: _ContextMismatch.new);
    expect(find.text(pt.authSignInOpenInBrowserHint), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/auth/google_sign_in_button_web_test.dart`
Expected: FAIL — o arquivo web ainda importa `google_sign_in_web/web_only.dart` (não compila na VM) / rótulos ausentes.

- [ ] **Step 3: `GoogleLogo`**

```dart
// lib/features/auth/presentation/widgets/google_logo.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// «G» do Google em quatro cores, desenhado — sem asset nem dependência.
/// Substitui o logo que vinha embutido no botão GIS (spec §3.7).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    void arc(Color color, double startDeg, double sweepDeg) {
      canvas.drawArc(
        ring,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        paint..color = color,
      );
    }

    arc(_red, -150, 105); // topo/esquerda
    arc(_yellow, 150, 60); // esquerda/baixo
    arc(_green, 45, 105); // baixo/direita
    arc(_blue, 0, 45); // direita, até a abertura do G

    // Barra horizontal do G: do centro até a borda direita.
    final barTop = size.height / 2 - stroke / 2;
    canvas.drawRect(
      Rect.fromLTRB(size.width / 2, barTop, size.width, barTop + stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 4: Reescrever o botão web**

```dart
// lib/features/auth/presentation/widgets/google_sign_in_button_web.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/oidc/oidc_callback.dart';
import '../providers/auth_state_provider.dart';
import 'google_logo.dart';

/// Botão de login web: redirect OIDC em vez do popup do GIS (spec D1/D2),
/// para a página poder viver sob `Cross-Origin-Opener-Policy: same-origin`.
///
/// Não depende do SDK do Google ter carregado (D11) — só do Client ID.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    if (ref.watch(googleClientIdProvider).isEmpty) {
      return Text(l10n.authSignInUnavailable, style: textStyle);
    }

    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) {
        debugPrint('[auth] estado de login em erro: $error');
        if (error is OidcContextMismatchException) {
          return _ContextMismatch(
            onSignIn: () => _startRedirect(context, ref),
            showBrowserHint: ref.read(oidcBrowserProvider).isStandaloneDisplay,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.authSignInUnavailable, style: textStyle),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(authStateProvider),
              child: Text(l10n.authSignInRetry),
            ),
          ],
        );
      },
      data: (_) => _SignInButton(onPressed: () => _startRedirect(context, ref)),
    );
  }

  /// `returnTo` é a rota atual — sem router (testes de tela isolada) cai em `/`.
  void _startRedirect(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    final returnTo = router == null
        ? '/'
        : GoRouterState.of(context).uri.toString();
    ref.read(authStateProvider.notifier).startGoogleRedirect(returnTo: returnTo);
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: const GoogleLogo(),
        label: Text(l10n.authSignInWithGoogle),
      ),
    );
  }
}

/// Estado de D15: o Google respondeu num contexto que não iniciou o login.
class _ContextMismatch extends StatelessWidget {
  const _ContextMismatch({
    required this.onSignIn,
    required this.showBrowserHint,
  });

  final VoidCallback onSignIn;
  final bool showBrowserHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.authSignInContextMismatchTitle, style: theme.titleSmall, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(l10n.authSignInContextMismatchBody, style: theme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _SignInButton(onPressed: onSignIn),
        if (showBrowserHint) ...[
          const SizedBox(height: 8),
          Text(l10n.authSignInOpenInBrowserHint, style: theme.bodySmall, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/widget/features/auth/google_sign_in_button_web_test.dart test/widget/features/app_shell test/widget/features/social test/widget/features/material_kind_prefs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/auth/presentation/widgets test/widget/features/auth
flutter analyze lib test
git add lib/features/auth/presentation/widgets/google_logo.dart lib/features/auth/presentation/widgets/google_sign_in_button_web.dart test/widget/features/auth/google_sign_in_button_web_test.dart
git commit -m "feat(auth): botão web próprio «Entrar com o Google» via redirect OIDC, com fallback de contexto"
```

---

### Task 7: COOP `same-origin` — headers, servidor local e validadores

**Files:**
- Modify: `web/_headers:2`
- Modify: `scripts/web_frontend_server.py:27`
- Modify: `scripts/validate_web_coop_coep.sh:48-52`
- Modify: `scripts/verify_web_headers_artifact.sh:8`
- Create: `test/web/web_headers_test.dart`

- [ ] **Step 1: Teste que falha**

```dart
// test/web/web_headers_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `web/_headers` é o que o Cloudflare Pages serve. Com o login por redirect
/// (spec D12) o COOP tem de ser `same-origin` exato: `same-origin-allow-popups`
/// desliga `crossOriginIsolated` e volta o skwasm para single-thread (P1).
void main() {
  late List<String> lines;

  setUp(() {
    lines = File('web/_headers').readAsLinesSync().map((l) => l.trim()).toList();
  });

  test('COOP same-origin exato', () {
    expect(lines, contains('Cross-Origin-Opener-Policy: same-origin'));
    expect(lines.where((l) => l.contains('allow-popups')), isEmpty);
  });

  test('COEP require-corp', () {
    expect(lines, contains('Cross-Origin-Embedder-Policy: require-corp'));
  });

  test('servidor local envia o mesmo COOP', () {
    final py = File('scripts/web_frontend_server.py').readAsStringSync();
    expect(py, contains('"Cross-Origin-Opener-Policy", "same-origin"'));
    expect(py, isNot(contains('allow-popups')));
  });
}
```

Run: `flutter test test/web/web_headers_test.dart` → Expected: FAIL (ainda `allow-popups`).

- [ ] **Step 2: Aplicar**

`web/_headers` linha 2: `  Cross-Origin-Opener-Policy: same-origin`

`scripts/web_frontend_server.py:27`: `self.send_header("Cross-Origin-Opener-Policy", "same-origin")`

`scripts/validate_web_coop_coep.sh` linhas 48-52:

```bash
  if [[ "$coop" == "same-origin" ]]; then
    echo "  OK  COOP: $coop"
  else
    echo "  FAIL COOP: esperado 'same-origin' (login web é por redirect, sem popup), obtido '${coop:-<ausente>}'" >&2
    failures=$((failures + 1))
  fi
```

`scripts/verify_web_headers_artifact.sh:8`:

```bash
grep -qx '  Cross-Origin-Opener-Policy: same-origin' "$HEADERS_FILE"
```

- [ ] **Step 3: Verificar**

```bash
flutter test test/web/web_headers_test.dart test/web/web_index_perf_test.dart
./scripts/verify_web_headers_artifact.sh web/_headers
bash -n scripts/validate_web_coop_coep.sh
```
Expected: testes PASS; script imprime `OK: web/_headers contém COOP/COEP…`.

- [ ] **Step 4: Commit**

```bash
git add web/_headers scripts/web_frontend_server.py scripts/validate_web_coop_coep.sh scripts/verify_web_headers_artifact.sh test/web/web_headers_test.dart
git commit -m "chore(web): COOP same-origin — headers, servidor local e validadores só aceitam o valor isolado"
```

---

### Task 8: Auditoria de `window.opener`, docs e verificação final

**Files:**
- Modify: `docs/GOOGLE_OAUTH_SETUP.md` (bloco «URIs de redirecionamento», linha ~21, e nova seção)
- Modify: `docs/AUDITORIA_POLIMENTO_2026-09-12.md` (linha 31 tabela; §P1 linha 44; item 4 linha 146)
- Modify: `docs/WEB_PERFORMANCE_RELIABILITY_AUDIT.md`, `docs/web_phase_d_coop_coep_validation.md` (menções a `allow-popups`)

- [ ] **Step 1: Auditoria de popups (spec §8)**

Run: `grep -rn "window.open\|\.opener\|webOnlyWindowName\|same-origin-allow-popups" lib web docs scripts --include='*.dart' --include='*.html' --include='*.js' --include='*.md' --include='*.sh' --include='*.py' | grep -v "docs/superpowers/"`

Expected: nenhum uso de `window.open`/`opener` em `lib/` ou `web/` (links externos usam `url_launcher` em nova aba, que não depende de COOP). Cada menção a `allow-popups` em `docs/` é ajustada no Step 2. Se aparecer um uso real de `window.opener` em código, reportar `BLOCKED` com o arquivo — não «consertar» por conta própria.

- [ ] **Step 2: Docs**

`docs/GOOGLE_OAUTH_SETUP.md` — trocar «URIs de redirecionamento (se usar redirect):» por «URIs de redirecionamento autorizados (**obrigatórios** — o login web é por redirect OIDC):» listando `https://v2.plpcg.com/`, `http://localhost:8080/` e `http://127.0.0.1:8080/` (barra final obrigatória: `redirect_uri` é `<origin>/`). Acrescentar ao fim a seção:

```markdown
## Fluxo web: redirect OIDC (fluxo implícito)

Desde 2026-09 o botão web não usa o popup do Google Identity Services: ele
navega para `https://accounts.google.com/o/oauth2/v2/auth` com
`response_type=id_token`, `scope=openid email profile`, `nonce` e `state`
(csrf + rota de retorno). O Google volta para `<origem>/#id_token=…&state=…`;
o app captura o fragmento em `main()`, confere `csrf`/`nonce` e chama
`POST /api/auth/session` como antes. O Worker continua validando assinatura,
`aud` e `exp` — nada muda do lado dele.

Motivo: o popup exigia `Cross-Origin-Opener-Policy: same-origin-allow-popups`,
que desliga o isolamento cross-origin e deixa o skwasm single-thread. Com o
redirect, COOP é `same-origin` (ver `web/_headers`).

Consequências práticas:
- Dev local só funciona na origem cadastrada (`http://localhost:8080`).
- Previews `*.pages.dev` não têm login (origem não cadastrada — já era assim).
- Se o Google devolver o token numa janela que não iniciou o login (aba
  restaurada, navegador embutido do PWA iOS), o app mostra «Não conseguimos
  concluir o login» com o botão para tentar de novo naquele contexto.

Spec: `docs/superpowers/specs/2026-09-13-google-login-redirect-coop-design.md`.
```

`docs/AUDITORIA_POLIMENTO_2026-09-12.md`:
- Linha 31 (tabela), coluna de estado: `✅ resolvido 2026-09-13 — login web por redirect OIDC; COOP same-origin (spec 2026-09-13-google-login-redirect-coop-design.md)`.
- §P1 (linha 44 em diante): acrescentar um parágrafo «**Resolução (2026-09-13):** opção 1 — login por redirect OIDC para todos os navegadores, COOP `same-origin`. Validação em produção pendente do checklist da spec (crossOriginIsolated, PWA iOS).»
- Item 4 da lista de próximos passos (linha 146): marcar como feito com a mesma referência.

`docs/WEB_PERFORMANCE_RELIABILITY_AUDIT.md` e `docs/web_phase_d_coop_coep_validation.md`: onde disserem que COOP é/pode ser `same-origin-allow-popups`, corrigir para `same-origin` com uma nota «(desde 2026-09-13; o login web é por redirect)». Não reescrever seções — só as frases afetadas.

- [ ] **Step 3: Verificação final da branch**

```bash
./scripts/test_all.sh --vm-only
./scripts/web_build.sh 2>&1 | tail -5
./scripts/verify_web_headers_artifact.sh
```
Expected: analyze limpo, testes verdes, build ok, `OK: build/web/_headers…`. (`dart_defines/private.json` é gitignored e não existe num worktree novo — o script avisa e segue; o build precisa compilar, não logar.)

- [ ] **Step 4: Commit**

```bash
git add docs/GOOGLE_OAUTH_SETUP.md docs/AUDITORIA_POLIMENTO_2026-09-12.md docs/WEB_PERFORMANCE_RELIABILITY_AUDIT.md docs/web_phase_d_coop_coep_validation.md
git commit -m "docs(auth): login web por redirect OIDC — setup do Console, P1 resolvido, COOP same-origin"
```

---

## Entrega (fora das tasks — controlador + usuário)

1. `superpowers:finishing-a-development-branch` → merge em `web/integration` só com escolha do usuário.
2. Deploy (`scripts/web_deploy.sh`, como nas entregas anteriores) e checklist manual da spec §6 em produção: `curl -sI https://v2.plpcg.com/ | grep -i cross-origin`; `./scripts/validate_web_coop_coep.sh https://v2.plpcg.com`; `crossOriginIsolated === true` no console; login/retorno em Chrome desktop, Chrome Android, Safari iOS, **PWA iOS** (item 3 — decide D17), PWA Android; cancelar; item 3b (URL forjada → tela D15); logout; renovação silenciosa.
3. Se o PWA iOS ficar no navegador embutido (cenário (b)): abrir plano da contingência §10 da spec.
4. Atualizar a memória `web-coop-isolation-off` quando `crossOriginIsolated` estiver `true` em produção.
