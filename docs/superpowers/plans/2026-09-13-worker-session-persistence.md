# Sessão persistente emitida pelo Worker — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A sessão do usuário sobrevive a fechar/reabrir a app (web e nativo) porque o Worker passa a emitir um token de sessão próprio, opaco, de 60 dias deslizantes, guardado em `localStorage`/`SharedPreferences`.

**Architecture:** O Worker `plpcg-catalog` ganha a tabela `user_sessions` (hash SHA-256 do token) e `withAuth` aceita `Bearer sess_…` além do JWT do Google; `POST /api/auth/session` devolve `sessionToken` e `DELETE` revoga. No app, `AuthUser.idToken` vira `sessionToken`, o store persiste (web: `localStorage`; nativo: `SharedPreferences`), o boot não consulta o Worker, e um `401` numa request com `sess_` desloga (sem renovação, sem retry). A renovação silenciosa via GIS, o `AuthRefreshInterceptor` e o banner «Sessão expirada» são removidos.

**Tech Stack:** Cloudflare Worker (TypeScript, D1, `node --test` com `FakeD1Database`), Flutter 3.47 / Dart 3.13, Riverpod 3, Dio, `package:web`, `shared_preferences`, `google_sign_in` (só nativo + `signOut`).

**Spec:** `docs/superpowers/specs/2026-09-13-worker-session-persistence-design.md`

## Global Constraints

- Ordem de rollout obrigatória: **Worker primeiro, app depois** (spec D14). Tasks 1–5 (Worker) inteiras, deploy verificado, e só então Tasks 6–13 (app) vão para produção.
- Prefixo do token: `sess_`; 32 bytes de `crypto.getRandomValues` em base64url sem padding; D1 guarda **só** o SHA-256 hex (spec D2).
- Validade: `expires_at = last_seen_at + 60 d`; a renovação só escreve quando `last_seen_at` tem mais de 1 h (spec D3).
- Chave de armazenamento no app: `plpcg_auth_session` (web `localStorage` e nativo `SharedPreferences`); o `nonce/csrf` do OIDC continua em `sessionStorage['plpcg_oidc_request']` — não mexer (spec D6).
- `401` só dispara logout quando a request saiu com `Authorization: Bearer sess_…` (spec D8).
- Formatação: rodar `dart format` **só nos arquivos tocados** (o repo tem arquivos ainda não formatados pela versão atual do Dart — `dart format lib` inteiro suja o diff). Worker: `npm run typecheck` e `npm test` verdes antes de cada commit.
- Commits em português, no formato `tipo(escopo): resumo`, com as linhas de atribuição da sessão (`Co-Authored-By` e `Claude-Session` conforme o system-reminder da sessão).
- Comandos do app rodam de `/Volumes/SSD 2TB SD/dev/coldigui`; comandos do Worker rodam de `workers/plpcg-catalog`.

---

## Mapa de arquivos

**Worker (`workers/plpcg-catalog/`)**
- Create: `migrations/0012_create_user_sessions.sql` — tabela `user_sessions`.
- Create: `src/auth/session_token.ts` — gerar/reconhecer/hashear o token (puro).
- Create: `src/auth/user_sessions.ts` — `createSession`/`findSession`/`revokeSession` em D1.
- Create: `src/auth/session_handlers.ts` — resposta do `POST` (com `sessionToken`) e o `DELETE`.
- Modify: `src/auth/with_auth.ts` — aceita `sess_` antes do JWT.
- Modify: `src/index.ts` — `handleAuthSession` (POST/DELETE) e CORS `auth` com `DELETE`.
- Modify: `src/test/fake_d1.ts` — suporte a `user_sessions`.
- Modify: `README.md` — rotas e tabela.

**App (`lib/`)**
- Modify: `features/auth/domain/entities/auth_user.dart` — `sessionToken`, `kSessionTokenPrefix`, sem `AuthUserExpiry`.
- Modify: `features/auth/data/auth_session_store_web.dart` — `localStorage` + `takeLegacySessionStorage`.
- Modify: `features/auth/data/auth_session_store_stub.dart` — `SharedPreferences` + `legacyIdToken`.
- Modify: `features/auth/data/auth_remote_datasource.dart` — `sessionToken` na resposta, `revokeSession`.
- Modify: `features/auth/presentation/providers/auth_state_provider.dart` — boot D7/D12, `onUnauthorized`, `signOut`, remoções D9/D11.
- Create: `core/network/auth_unauthorized_interceptor.dart`; Delete: `core/network/auth_refresh_interceptor.dart`.
- Modify: `core/providers/dio_provider.dart`.
- Modify: `features/app_shell/presentation/pages/profile_screen.dart` — sem banner.
- Modify: `l10n/app_pt.arb`, `l10n/app_en.arb` (+ regenerar).
- Modify (rename `idToken` → `sessionToken`): datasources/usecases/providers de `playlists`, `social`, `audio_flags`, `material_kind_prefs` e `share_link_shortener_remote.dart`.

**Docs**
- Modify: `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md`, `docs/superpowers/specs/2026-09-13-google-login-redirect-coop-design.md`, `docs/features/FEATURE_INDEX.md`.

---

## Parte 1 — Worker

### Task 1: Token de sessão (puro) + migration

**Files:**
- Create: `workers/plpcg-catalog/migrations/0012_create_user_sessions.sql`
- Create: `workers/plpcg-catalog/src/auth/session_token.ts`
- Test: `workers/plpcg-catalog/src/auth/session_token.test.ts`

**Interfaces:**
- Produces: `SESSION_TOKEN_PREFIX = 'sess_'`, `SESSION_TTL_MS`, `SESSION_TOUCH_INTERVAL_MS`, `generateSessionToken(): string`, `isSessionToken(bearer: string): boolean`, `hashSessionToken(token: string): Promise<string>`.

- [ ] **Step 1: Migration**

```sql
-- workers/plpcg-catalog/migrations/0012_create_user_sessions.sql
-- Migration number: 0012  2026-09-13T00:00:00.000Z
-- Sessões emitidas pelo Worker (spec 2026-09-13-worker-session-persistence).
-- Uma linha por login/aparelho. Só o SHA-256 hex do token é gravado; o token
-- cru só existe na resposta do POST /api/auth/session e no aparelho.
CREATE TABLE user_sessions (
  token_hash   TEXT PRIMARY KEY NOT NULL,
  google_sub   TEXT NOT NULL REFERENCES users(google_sub) ON DELETE CASCADE,
  created_at   TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  expires_at   TEXT NOT NULL   -- ISO 8601, last_seen_at + 60 d (deslizante)
);
CREATE INDEX idx_user_sessions_sub ON user_sessions(google_sub);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
```

- [ ] **Step 2: Teste que falha**

```ts
// workers/plpcg-catalog/src/auth/session_token.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  SESSION_TOKEN_PREFIX,
  generateSessionToken,
  hashSessionToken,
  isSessionToken,
} from './session_token.ts';

test('token tem o prefixo e 43 chars de base64url (32 bytes)', () => {
  const token = generateSessionToken();
  assert.ok(token.startsWith(SESSION_TOKEN_PREFIX));
  const body = token.slice(SESSION_TOKEN_PREFIX.length);
  assert.equal(body.length, 43);
  assert.match(body, /^[A-Za-z0-9_-]+$/);
});

test('dois tokens diferem', () => {
  assert.notEqual(generateSessionToken(), generateSessionToken());
});

test('isSessionToken distingue sessão de JWT', () => {
  assert.equal(isSessionToken('sess_abc'), true);
  assert.equal(isSessionToken('eyJhbGciOi.eyJzdWIi.sig'), false);
  assert.equal(isSessionToken(''), false);
});

test('hash é SHA-256 hex, determinístico e diferente do token', async () => {
  const token = 'sess_fixo';
  const a = await hashSessionToken(token);
  const b = await hashSessionToken(token);
  assert.equal(a, b);
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.notEqual(a, token);
  assert.notEqual(a, await hashSessionToken('sess_outro'));
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd workers/plpcg-catalog && npm test -- src/auth/session_token.test.ts`
Expected: FAIL — `Cannot find module './session_token.ts'`.

- [ ] **Step 4: Implementação**

```ts
// workers/plpcg-catalog/src/auth/session_token.ts
/**
 * Token de sessão emitido pelo Worker (spec D2/D3).
 *
 * `sess_` + 32 bytes aleatórios em base64url sem padding. O prefixo é o que
 * permite ao `withAuth` distinguir sessão de JWT do Google sem parsear.
 */
export const SESSION_TOKEN_PREFIX = 'sess_';

/** 60 dias deslizantes. */
export const SESSION_TTL_MS = 60 * 24 * 60 * 60 * 1000;

/** Só reescreve `last_seen_at`/`expires_at` se passou 1 h da última vez. */
export const SESSION_TOUCH_INTERVAL_MS = 60 * 60 * 1000;

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function generateSessionToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return `${SESSION_TOKEN_PREFIX}${base64Url(bytes)}`;
}

export function isSessionToken(bearer: string): boolean {
  return bearer.startsWith(SESSION_TOKEN_PREFIX);
}

/** SHA-256 hex — é isto que vai para `user_sessions.token_hash`. */
export async function hashSessionToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(token),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd workers/plpcg-catalog && npm test -- src/auth/session_token.test.ts && npm run typecheck`
Expected: 4 pass; typecheck sem erro.

- [ ] **Step 6: Commit**

```bash
git add workers/plpcg-catalog/migrations/0012_create_user_sessions.sql workers/plpcg-catalog/src/auth/session_token.ts workers/plpcg-catalog/src/auth/session_token.test.ts
git commit -m "feat(worker): token de sessão sess_ e tabela user_sessions"
```

---

### Task 2: `user_sessions` em D1 + fake D1

**Files:**
- Create: `workers/plpcg-catalog/src/auth/user_sessions.ts`
- Modify: `workers/plpcg-catalog/src/test/fake_d1.ts`
- Test: `workers/plpcg-catalog/src/auth/user_sessions.test.ts`

**Interfaces:**
- Consumes: Task 1.
- Produces: `createSession(db, googleSub, now): Promise<string>` (token cru), `findSession(db, token, now): Promise<{ sub: string } | null>`, `revokeSession(db, token): Promise<void>`. Fake: `FakeD1Database.sessions: Map<string, SessionRow>` (chave `token_hash`) e `FakeD1Options.sessions?: SessionRow[]`.

- [ ] **Step 1: Teste que falha**

```ts
// workers/plpcg-catalog/src/auth/user_sessions.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import { SESSION_TTL_MS, hashSessionToken } from './session_token.ts';
import { createSession, findSession, revokeSession } from './user_sessions.ts';

const t0 = new Date('2026-09-13T12:00:00.000Z');
const plus = (ms: number) => new Date(t0.getTime() + ms);
const HOUR = 60 * 60 * 1000;

test('createSession grava só o hash e devolve o token cru', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  assert.ok(token.startsWith('sess_'));
  const row = db.sessions.get(await hashSessionToken(token));
  assert.ok(row);
  assert.equal(row.google_sub, 'u1');
  assert.equal(row.created_at, t0.toISOString());
  assert.equal(row.last_seen_at, t0.toISOString());
  assert.equal(row.expires_at, plus(SESSION_TTL_MS).toISOString());
  assert.ok(![...db.sessions.keys()].includes(token));
});

test('findSession devolve o sub de uma sessão válida', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  assert.deepEqual(await findSession(fakeDb(db), token, plus(HOUR / 2)), { sub: 'u1' });
});

test('findSession recusa desconhecida e vencida', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  assert.equal(await findSession(fakeDb(db), 'sess_nunca', t0), null);
  assert.equal(await findSession(fakeDb(db), token, plus(SESSION_TTL_MS + 1)), null);
});

test('findSession só renova depois de 1 h (deslizante)', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  const hash = await hashSessionToken(token);

  await findSession(fakeDb(db), token, plus(HOUR - 1));
  assert.equal(db.sessions.get(hash)!.last_seen_at, t0.toISOString());

  const later = plus(HOUR + 1);
  await findSession(fakeDb(db), token, later);
  assert.equal(db.sessions.get(hash)!.last_seen_at, later.toISOString());
  assert.equal(
    db.sessions.get(hash)!.expires_at,
    new Date(later.getTime() + SESSION_TTL_MS).toISOString(),
  );
});

test('revokeSession faz o próximo find devolver null e é idempotente', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  await revokeSession(fakeDb(db), token);
  assert.equal(await findSession(fakeDb(db), token, t0), null);
  await revokeSession(fakeDb(db), token); // não lança
});

test('createSession purga as vencidas', async () => {
  const db = new FakeD1Database();
  const old = await createSession(fakeDb(db), 'u1', t0);
  await createSession(fakeDb(db), 'u2', plus(SESSION_TTL_MS + 1));
  assert.equal(db.sessions.has(await hashSessionToken(old)), false);
  assert.equal(db.sessions.size, 1);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd workers/plpcg-catalog && npm test -- src/auth/user_sessions.test.ts`
Expected: FAIL — módulo `user_sessions.ts` não existe.

- [ ] **Step 3: Implementação do módulo D1**

```ts
// workers/plpcg-catalog/src/auth/user_sessions.ts
import {
  SESSION_TOUCH_INTERVAL_MS,
  SESSION_TTL_MS,
  generateSessionToken,
  hashSessionToken,
} from './session_token';

interface SessionLookupRow {
  google_sub: string;
  last_seen_at: string;
}

function expiresFrom(now: Date): string {
  return new Date(now.getTime() + SESSION_TTL_MS).toISOString();
}

/**
 * Cria uma sessão para `googleSub` e devolve o token **cru** (única vez que
 * ele existe no servidor). Purga antes as sessões vencidas (spec D13).
 */
export async function createSession(
  db: D1Database,
  googleSub: string,
  now: Date = new Date(),
): Promise<string> {
  const nowIso = now.toISOString();
  await db
    .prepare(`DELETE FROM user_sessions WHERE expires_at < ?`)
    .bind(nowIso)
    .run();

  const token = generateSessionToken();
  await db
    .prepare(
      `INSERT INTO user_sessions (token_hash, google_sub, created_at, last_seen_at, expires_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
    .bind(await hashSessionToken(token), googleSub, nowIso, nowIso, expiresFrom(now))
    .run();
  return token;
}

/**
 * `{ sub }` de uma sessão válida, ou `null`. Renova `last_seen_at`/`expires_at`
 * (deslizante) só quando a última renovação tem mais de 1 h (spec D3).
 */
export async function findSession(
  db: D1Database,
  token: string,
  now: Date = new Date(),
): Promise<{ sub: string } | null> {
  const hash = await hashSessionToken(token);
  const row = await db
    .prepare(
      `SELECT google_sub, last_seen_at FROM user_sessions
       WHERE token_hash = ? AND expires_at > ?`,
    )
    .bind(hash, now.toISOString())
    .first<SessionLookupRow>();
  if (!row) return null;

  const lastSeen = Date.parse(row.last_seen_at);
  if (now.getTime() - lastSeen > SESSION_TOUCH_INTERVAL_MS) {
    await db
      .prepare(
        `UPDATE user_sessions SET last_seen_at = ?, expires_at = ? WHERE token_hash = ?`,
      )
      .bind(now.toISOString(), expiresFrom(now), hash)
      .run();
  }
  return { sub: row.google_sub };
}

/** Apaga a sessão; token desconhecido é no-op (idempotente). */
export async function revokeSession(db: D1Database, token: string): Promise<void> {
  await db
    .prepare(`DELETE FROM user_sessions WHERE token_hash = ?`)
    .bind(await hashSessionToken(token))
    .run();
}
```

- [ ] **Step 4: Estender o fake D1**

Em `src/test/fake_d1.ts`:

1. Na tabela do doc-comment do topo, acrescentar as linhas:
```
 * | `DELETE FROM user_sessions WHERE expires_at < ?` (purga, `auth/user_sessions.ts`) | `user_sessions` + `expires_at < ?` |
 * | `INSERT INTO user_sessions (…) VALUES (…)` | `user_sessions` |
 * | `SELECT google_sub, last_seen_at FROM user_sessions WHERE token_hash = ? AND expires_at > ?` | `user_sessions` + `SELECT` |
 * | `UPDATE user_sessions SET last_seen_at = ?, expires_at = ? WHERE token_hash = ?` | `user_sessions` + `UPDATE` |
 * | `DELETE FROM user_sessions WHERE token_hash = ?` (revogação) | `user_sessions` + `token_hash = ?` |
```

2. Depois de `MaterialKindPrefsRow`, o tipo da linha:
```ts
/** Linha de `user_sessions` (chave `token_hash`). */
export interface SessionRow {
  token_hash: string;
  google_sub: string;
  created_at: string;
  last_seen_at: string;
  expires_at: string;
}
```

3. Em `FakeD1Options`, acrescentar `sessions?: SessionRow[];` com o comentário `/** Linhas de \`user_sessions\`. */`.

4. Na classe `FakeD1Database`, depois de `materialKindPrefs`:
```ts
  /** Linhas de `user_sessions`, por `token_hash`. */
  readonly sessions = new Map<string, SessionRow>();
```
e no construtor, depois do laço de `materialKindPrefs`:
```ts
    for (const row of options.sessions ?? []) this.sessions.set(row.token_hash, row);
```

5. Em `runQuery`, logo depois do despacho de `user_material_kind_prefs`:
```ts
    // `user_sessions` tem chave `token_hash` e é a única tabela com DELETE.
    if (/user_sessions/i.test(normalized)) {
      return this.runUserSessions(normalized, bindings);
    }
```

6. Depois de `runMaterialKindPrefs`, o método:
```ts
  /**
   * `user_sessions`: SELECT por `token_hash` com `expires_at > ?`, INSERT,
   * UPDATE de renovação (WHERE consome o último binding) e os dois DELETEs
   * (revogação por hash e purga por `expires_at < ?`).
   */
  private runUserSessions(normalized: string, bindings: unknown[]): unknown[] {
    if (/^SELECT/i.test(normalized)) {
      const row = this.sessions.get(bindings[0] as string);
      if (!row) return [];
      return row.expires_at > (bindings[1] as string) ? [row] : [];
    }
    if (/^INSERT INTO/i.test(normalized)) {
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as SessionRow;
      this.sessions.set(built.token_hash, built);
      return [];
    }
    if (/^UPDATE/i.test(normalized)) {
      const assignments = updatePlan(normalized);
      const cursor = { next: 0 };
      const hash = bindings[bindings.length - 1] as string;
      const current = this.sessions.get(hash);
      if (!current) throw new Error(`fake D1: UPDATE em sessão ausente: ${hash}`);
      const next = { ...current } as Record<string, unknown>;
      for (const { column, value } of assignments) {
        next[column] = resolveToken(value, bindings, cursor, undefined);
      }
      this.sessions.set(hash, next as unknown as SessionRow);
      return [];
    }
    if (/^DELETE/i.test(normalized)) {
      if (/expires_at < \?/i.test(normalized)) {
        const cutoff = bindings[0] as string;
        for (const [hash, row] of this.sessions) {
          if (row.expires_at < cutoff) this.sessions.delete(hash);
        }
        return [];
      }
      this.sessions.delete(bindings[0] as string);
      return [];
    }
    throw new Error(`fake D1: user_sessions não suportado: ${normalized}`);
  }
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd workers/plpcg-catalog && npm test && npm run typecheck`
Expected: todos os testes (107 anteriores + 4 + 6) passam; typecheck limpo.

- [ ] **Step 6: Commit**

```bash
git add workers/plpcg-catalog/src/auth/user_sessions.ts workers/plpcg-catalog/src/auth/user_sessions.test.ts workers/plpcg-catalog/src/test/fake_d1.ts
git commit -m "feat(worker): user_sessions — criar, achar (60 d deslizantes), revogar e purgar"
```

---

### Task 3: `withAuth` aceita `sess_`

**Files:**
- Modify: `workers/plpcg-catalog/src/auth/with_auth.ts`
- Test: `workers/plpcg-catalog/src/auth/with_auth.test.ts`

**Interfaces:**
- Consumes: `isSessionToken`, `findSession` (Tasks 1–2).
- Produces: `withAuth(request, env, handler)` inalterado na assinatura; handler recebe `{ sub }` para sessões.

- [ ] **Step 1: Teste que falha**

```ts
// workers/plpcg-catalog/src/auth/with_auth.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import { createSession, revokeSession } from './user_sessions.ts';
import { withAuth } from './with_auth.ts';

function env(db: FakeD1Database) {
  return { DB: fakeDb(db), GOOGLE_CLIENT_ID_WEB: 'cid' };
}

function request(bearer?: string): Request {
  return new Request('https://example.test/api/playlists', {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

test('sessão válida chama o handler com { sub }', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1');
  let seen: unknown;
  const response = await withAuth(request(token), env(db), async (_r, _e, claims) => {
    seen = claims;
    return new Response('ok');
  });
  assert.equal(response.status, 200);
  assert.deepEqual(seen, { sub: 'u1' });
});

test('sessão revogada/desconhecida → 401 sem chamar o handler', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1');
  await revokeSession(fakeDb(db), token);
  let called = false;
  const response = await withAuth(request(token), env(db), async () => {
    called = true;
    return new Response('ok');
  });
  assert.equal(response.status, 401);
  assert.equal(called, false);
});

test('sem Authorization → 401', async () => {
  const db = new FakeD1Database();
  const response = await withAuth(request(), env(db), async () => new Response('ok'));
  assert.equal(response.status, 401);
});

test('Bearer que não é sessão segue pelo JWT e um JWT inválido dá 401', async () => {
  // `jwtVerify` rejeita um token malformado antes de buscar o JWKS — roda
  // offline. É o caminho antigo, mantido para a POST /session e para o app em
  // cache durante o rollout (spec D5).
  const db = new FakeD1Database();
  const response = await withAuth(request('nao-e-jwt'), env(db), async () => new Response('ok'));
  assert.equal(response.status, 401);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd workers/plpcg-catalog && npm test -- src/auth/with_auth.test.ts`
Expected: o primeiro teste FAIL com 401 (o `sess_` cai no `jwtVerify`).

- [ ] **Step 3: Implementação**

Substituir o corpo de `withAuth` em `src/auth/with_auth.ts`:

```ts
import type { GoogleClaims } from './verify_google_token';
import { verifyGoogleIdToken } from './verify_google_token';
import { isSessionToken } from './session_token';
import { findSession } from './user_sessions';

// (AuthedHandler, bearerToken e json ficam como estão)

export async function withAuth(
  request: Request,
  env: { DB: D1Database; GOOGLE_CLIENT_ID_WEB: string },
  handler: AuthedHandler,
): Promise<Response> {
  const token = bearerToken(request);
  if (!token) {
    return json({ error: 'unauthorized' }, 401);
  }

  // Sessão emitida pelo Worker (spec D5): lookup em D1, sem JWT.
  if (isSessionToken(token)) {
    const session = await findSession(env.DB, token);
    if (!session) {
      return json({ error: 'unauthorized' }, 401);
    }
    return handler(request, env, { sub: session.sub });
  }

  const clientId = env.GOOGLE_CLIENT_ID_WEB;
  if (!clientId) {
    return json({ error: 'auth not configured' }, 503);
  }

  try {
    const claims = await verifyGoogleIdToken(token, clientId);
    return handler(request, env, claims);
  } catch {
    return json({ error: 'unauthorized' }, 401);
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd workers/plpcg-catalog && npm test && npm run typecheck`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add workers/plpcg-catalog/src/auth/with_auth.ts workers/plpcg-catalog/src/auth/with_auth.test.ts
git commit -m "feat(worker): withAuth aceita Bearer sess_ além do JWT do Google"
```

---

### Task 4: `POST` devolve `sessionToken`, `DELETE` revoga, CORS

**Files:**
- Create: `workers/plpcg-catalog/src/auth/session_handlers.ts`
- Modify: `workers/plpcg-catalog/src/index.ts` (`handleAuthSession`, `corsHeaders` modo `auth`)
- Test: `workers/plpcg-catalog/src/auth/session_handlers.test.ts`

**Interfaces:**
- Consumes: `SessionUserJson` (`session.ts`), `createSession`/`revokeSession` (Task 2), `isSessionToken` (Task 1).
- Produces: `sessionResponse(db, user, now?): Promise<Response>` → `200 { ...user, sessionToken }`; `handleDeleteSession(db, request): Promise<Response>` → `204` / `401`.

- [ ] **Step 1: Teste que falha**

```ts
// workers/plpcg-catalog/src/auth/session_handlers.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import type { SessionUserJson } from './session.ts';
import { handleDeleteSession, sessionResponse } from './session_handlers.ts';
import { hashSessionToken } from './session_token.ts';
import { findSession } from './user_sessions.ts';

const user: SessionUserJson = {
  googleSub: 'u1',
  email: 'a@b.c',
  name: 'Ana',
  pictureUrl: null,
  username: 'ana',
};

function deleteRequest(bearer?: string): Request {
  return new Request('https://example.test/api/auth/session', {
    method: 'DELETE',
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

test('sessionResponse devolve o perfil + sessionToken e grava o hash', async () => {
  const db = new FakeD1Database();
  const response = await sessionResponse(fakeDb(db), user);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  const body = (await response.json()) as SessionUserJson & { sessionToken: string };
  assert.equal(body.googleSub, 'u1');
  assert.equal(body.username, 'ana');
  assert.ok(body.sessionToken.startsWith('sess_'));
  assert.ok(db.sessions.has(await hashSessionToken(body.sessionToken)));
});

test('DELETE com sessão válida revoga e devolve 204', async () => {
  const db = new FakeD1Database();
  const { sessionToken } = (await (await sessionResponse(fakeDb(db), user)).json()) as {
    sessionToken: string;
  };
  const response = await handleDeleteSession(fakeDb(db), deleteRequest(sessionToken));
  assert.equal(response.status, 204);
  assert.equal(await findSession(fakeDb(db), sessionToken), null);
});

test('DELETE de sessão desconhecida é 204 (idempotente)', async () => {
  const db = new FakeD1Database();
  const response = await handleDeleteSession(fakeDb(db), deleteRequest('sess_nunca'));
  assert.equal(response.status, 204);
});

test('DELETE sem Bearer ou com Bearer que não é sessão → 401', async () => {
  const db = new FakeD1Database();
  assert.equal((await handleDeleteSession(fakeDb(db), deleteRequest())).status, 401);
  assert.equal(
    (await handleDeleteSession(fakeDb(db), deleteRequest('eyJ.jwt.x'))).status,
    401,
  );
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd workers/plpcg-catalog && npm test -- src/auth/session_handlers.test.ts`
Expected: FAIL — módulo não existe.

- [ ] **Step 3: Implementação do módulo**

```ts
// workers/plpcg-catalog/src/auth/session_handlers.ts
import type { SessionUserJson } from './session';
import { isSessionToken } from './session_token';
import { createSession, revokeSession } from './user_sessions';

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

/**
 * Resposta do `POST /api/auth/session` (spec D1): o perfil já upsertado mais
 * um `sessionToken` novo. Um login = uma sessão (spec D4).
 */
export async function sessionResponse(
  db: D1Database,
  user: SessionUserJson,
  now: Date = new Date(),
): Promise<Response> {
  const sessionToken = await createSession(db, user.googleSub, now);
  return json({ ...user, sessionToken }, 200);
}

/**
 * `DELETE /api/auth/session`: revoga a sessão do Bearer. Token desconhecido
 * também é `204` — o app vai apagar a sessão local de qualquer jeito.
 */
export async function handleDeleteSession(
  db: D1Database,
  request: Request,
): Promise<Response> {
  const token = bearerToken(request);
  if (!token || !isSessionToken(token)) {
    return json({ error: 'unauthorized' }, 401);
  }
  await revokeSession(db, token);
  return new Response(null, { status: 204 });
}
```

- [ ] **Step 4: Ligar em `index.ts`**

Imports no topo (junto dos de `./auth/…`):
```ts
import { handleDeleteSession, sessionResponse } from './auth/session_handlers';
```

Substituir `handleAuthSession` inteira:
```ts
async function handleAuthSession(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method === 'DELETE') {
    return handleDeleteSession(env.DB, request);
  }
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method not allowed' }, { status: 405 });
  }

  const clientId = env.GOOGLE_CLIENT_ID_WEB;
  if (!clientId) {
    return jsonResponse({ error: 'auth not configured' }, { status: 503 });
  }

  const token = bearerToken(request);
  if (!token) {
    return jsonResponse({ error: 'unauthorized' }, { status: 401 });
  }

  try {
    const claims = await verifyGoogleIdToken(token, clientId);
    const user = await upsertUser(env.DB, claims);
    // Troca o id_token (1 h) por uma sessão do Worker (spec D1).
    return await sessionResponse(env.DB, user);
  } catch {
    return jsonResponse({ error: 'unauthorized' }, { status: 401 });
  }
}
```

No `corsHeaders`, ramo `mode === 'auth'`, trocar a linha de métodos por:
```ts
      headers.set('Access-Control-Allow-Methods', 'POST, PUT, DELETE, OPTIONS');
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd workers/plpcg-catalog && npm test && npm run typecheck && npm run check`
Expected: tudo verde; `wrangler check` sem erro.

- [ ] **Step 6: README**

Em `workers/plpcg-catalog/README.md`, na tabela de endpoints, trocar a linha do `POST /api/auth/session` e acrescentar o `DELETE`:
```
| `POST` | `/api/auth/session` | Bearer Google `id_token` | Valida JWT, UPSERT em `users`, cria linha em `user_sessions` e devolve perfil + `sessionToken` (60 d deslizantes) |
| `DELETE` | `/api/auth/session` | Bearer `sess_…` | Revoga a sessão (204, idempotente) |
```
E uma frase logo abaixo da tabela: «Todas as rotas com Bearer aceitam `sess_…` (sessão do Worker, `user_sessions`) ou o `id_token` do Google. Spec: `docs/superpowers/specs/2026-09-13-worker-session-persistence-design.md`.»

- [ ] **Step 7: Commit**

```bash
git add workers/plpcg-catalog/src/auth/session_handlers.ts workers/plpcg-catalog/src/auth/session_handlers.test.ts workers/plpcg-catalog/src/index.ts workers/plpcg-catalog/README.md
git commit -m "feat(worker): POST /api/auth/session devolve sessionToken; DELETE revoga"
```

---

### Task 5: Deploy do Worker (antes de qualquer deploy do app — spec D14)

**Files:** nenhum (operacional).

- [ ] **Step 1: Migration remota**

Run: `cd workers/plpcg-catalog && npm run db:migrate:remote`
Expected: `0012_create_user_sessions.sql ✅`.

- [ ] **Step 2: Deploy**

Run: `cd workers/plpcg-catalog && npm run deploy`
Expected: `Deployed plpcg-catalog triggers` com as 9 rotas e um `Current Version ID`.

- [ ] **Step 3: Verificar em produção**

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://plpcg.com/api/catalog/checksum                       # 200
curl -s -o /dev/null -w "%{http_code}\n" -H 'Authorization: Bearer sess_nada' https://plpcg.com/api/playlists   # 401
curl -s -o /dev/null -w "%{http_code}\n" -X DELETE -H 'Authorization: Bearer sess_nada' https://plpcg.com/api/auth/session  # 204
curl -s -o /dev/null -w "%{http_code}\n" -X OPTIONS -H 'Origin: https://v2.plpcg.com' -H 'Access-Control-Request-Method: DELETE' https://plpcg.com/api/auth/session  # 204
```
Expected: `200`, `401`, `204`, `204`. Abrir `https://v2.plpcg.com` (app antigo, ainda com JWT), entrar e conferir que playlists/favoritos sincronizam — o caminho JWT continua vivo.

---

## Parte 2 — App

### Task 6: `AuthUser.sessionToken` + rename mecânico + sem `AuthUserExpiry`

**Files:**
- Modify: `lib/features/auth/domain/entities/auth_user.dart`
- Modify (rename): 14 arquivos em `lib/features/{playlists,social,audio_flags,material_kind_prefs}` listados abaixo e seus testes
- Modify: `lib/features/auth/data/auth_remote_datasource.dart` (só `setUsername`), `lib/features/auth/presentation/providers/auth_state_provider.dart` (só os usos de `.idToken` e `copyWith(idToken:)`)
- Delete: `test/unit/features/auth/auth_user_expiry_test.dart`
- Create: `test/unit/features/auth/auth_user_test.dart`

**Interfaces:**
- Produces: `AuthUser.sessionToken` (String, obrigatório), `AuthUser.copyWith({sessionToken})`, JSON com chave `sessionToken`, `const String kSessionTokenPrefix = 'sess_'`.

- [ ] **Step 1: Teste que falha**

```dart
// test/unit/features/auth/auth_user_test.dart
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    googleSub: 'sub-1',
    sessionToken: 'sess_abc',
    email: 'a@b.com',
    name: 'Ana',
    username: 'ana',
  );

  test('toJson/fromJson fazem round-trip com sessionToken', () {
    final decoded = AuthUser.fromJson(user.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.googleSub, 'sub-1');
    expect(decoded.sessionToken, 'sess_abc');
    expect(decoded.email, 'a@b.com');
    expect(decoded.username, 'ana');
  });

  test('JSON antigo (idToken) não vira AuthUser', () {
    // A migração da sessão antiga (spec D12) lê esse JSON por fora.
    expect(
      AuthUser.fromJson({'googleSub': 'sub-1', 'idToken': 'eyJ.x.y'}),
      isNull,
    );
  });

  test('sessionToken vazio não vira AuthUser', () {
    expect(AuthUser.fromJson({'googleSub': 'sub-1', 'sessionToken': ''}), isNull);
  });

  test('kSessionTokenPrefix é o prefixo do Worker', () {
    expect(kSessionTokenPrefix, 'sess_');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/auth_user_test.dart`
Expected: erro de compilação — `sessionToken` não existe.

- [ ] **Step 3: Entidade**

Reescrever `lib/features/auth/domain/entities/auth_user.dart` (sem `dart:convert`, sem `foundation`):

```dart
/// Prefixo do token de sessão emitido pelo Worker (`user_sessions`). É o que
/// o `AuthUnauthorizedInterceptor` usa para saber que um 401 é «sessão
/// revogada/vencida» e não uma rota pública.
const String kSessionTokenPrefix = 'sess_';

/// Usuário autenticado (sessão local + registro D1).
class AuthUser {
  const AuthUser({
    required this.googleSub,
    required this.sessionToken,
    this.email,
    this.name,
    this.pictureUrl,
    this.username,
  });

  /// Claim `sub` do JWT Google — PK em D1 `users.google_sub`.
  final String googleSub;

  final String? email;
  final String? name;
  final String? pictureUrl;

  /// Handle público único (`users.username`). Null até o usuário cadastrar.
  final String? username;

  /// Token de sessão do Worker (`sess_…`), Bearer de toda rota autenticada.
  /// Opaco: não tem `exp` legível — quem decide se ainda vale é o Worker.
  final String sessionToken;

  bool get hasUsername => username != null && username!.isNotEmpty;

  /// Primeiro nome para a bottom bar (fallback: `Perfil`).
  String get displayFirstName {
    final full = name?.trim();
    if (full == null || full.isEmpty) return 'Perfil';
    return full.split(RegExp(r'\s+')).first;
  }

  AuthUser copyWith({
    String? googleSub,
    String? email,
    String? name,
    String? pictureUrl,
    String? username,
    String? sessionToken,
  }) {
    return AuthUser(
      googleSub: googleSub ?? this.googleSub,
      email: email ?? this.email,
      name: name ?? this.name,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      username: username ?? this.username,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }

  Map<String, Object?> toJson() => {
    'googleSub': googleSub,
    'email': email,
    'name': name,
    'pictureUrl': pictureUrl,
    'username': username,
    'sessionToken': sessionToken,
  };

  /// `null` para JSON sem `googleSub`/`sessionToken` — inclusive o formato
  /// antigo com `idToken`, que a migração (spec D12) trata por fora.
  static AuthUser? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final sub = json['googleSub'];
    final token = json['sessionToken'];
    if (sub is! String || sub.isEmpty || token is! String || token.isEmpty) {
      return null;
    }
    return AuthUser(
      googleSub: sub,
      email: json['email'] as String?,
      name: json['name'] as String?,
      pictureUrl: json['pictureUrl'] as String?,
      username: json['username'] as String?,
      sessionToken: token,
    );
  }
}
```

- [ ] **Step 4: Rename mecânico fora de `features/auth`**

Todos os `idToken` destes arquivos são o Bearer (nenhum é o `id_token` do Google):

```bash
perl -pi -e 's/\bidToken\b/sessionToken/g' \
  lib/features/audio_flags/data/datasources/audio_flag_remote_datasource.dart \
  lib/features/audio_flags/data/providers/audio_flag_providers.dart \
  lib/features/audio_flags/domain/usecases/sync_audio_flags.dart \
  lib/features/audio_flags/presentation/providers/audio_flag_sync_provider.dart \
  lib/features/material_kind_prefs/data/datasources/material_kind_prefs_remote_datasource.dart \
  lib/features/material_kind_prefs/domain/usecases/sync_material_kind_prefs.dart \
  lib/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart \
  lib/features/playlists/data/datasources/playlist_remote_datasource.dart \
  lib/features/playlists/data/datasources/share_link_shortener_remote.dart \
  lib/features/playlists/data/providers/playlist_providers.dart \
  lib/features/playlists/domain/usecases/sync_playlists.dart \
  lib/features/playlists/presentation/providers/playlist_sync_provider.dart \
  lib/features/social/data/datasources/social_remote_datasource.dart \
  lib/features/social/presentation/providers/social_search_provider.dart \
  test/unit/features/audio_flags/audio_flag_remote_datasource_test.dart \
  test/unit/features/audio_flags/audio_flag_sync_provider_test.dart \
  test/unit/features/audio_flags/sync_audio_flags_test.dart \
  test/unit/features/material_kind_prefs/material_kind_prefs_provider_test.dart \
  test/unit/features/material_kind_prefs/material_kind_prefs_remote_datasource_test.dart \
  test/unit/features/material_kind_prefs/material_kind_prefs_sync_provider_test.dart \
  test/unit/features/material_kind_prefs/sync_material_kind_prefs_test.dart \
  test/unit/features/playlists/playlist_remote_datasource_test.dart \
  test/unit/features/playlists/playlist_sync_provider_test.dart \
  test/unit/features/playlists/playlists_provider_delete_with_undo_test.dart \
  test/unit/features/playlists/share_link_shortener_remote_test.dart \
  test/unit/features/playlists/sync_playlists_test.dart \
  test/unit/features/social/social_remote_datasource_test.dart \
  test/widget/features/app_shell/profile_screen_favorites_tile_test.dart \
  test/widget/features/material_kind_prefs/favorite_material_kinds_screen_test.dart \
  test/unit/features/auth/username_rules_test.dart
```

Depois, `grep -rn "idToken" lib/features/{playlists,social,audio_flags,material_kind_prefs}` tem de devolver vazio. Nos doc-comments que digam «`id_token`» junto de Bearer nesses arquivos (ex.: «`GET`/`PUT … com Bearer do `id_token`» em `material_kind_prefs_remote_datasource.dart`), trocar por «Bearer do `sessionToken`».

- [ ] **Step 5: Edições à mão em `features/auth`**

`lib/features/auth/data/auth_remote_datasource.dart` — só em `setUsername`: parâmetro `required String idToken` → `required String sessionToken`, e o header `'Bearer $idToken'` → `'Bearer $sessionToken'`. **`establishSession(String idToken)` fica** (é o `id_token` do Google).

`lib/features/auth/presentation/providers/auth_state_provider.dart` — trocar:
- em `_refreshIdToken`: `idToken == current.idToken` → `idToken == current.sessionToken` e `current.copyWith(idToken: idToken)` → `current.copyWith(sessionToken: idToken)` (o método inteiro some na Task 9; aqui é só compilar);
- em `setUsername`: `.setUsername(idToken: current.idToken, …)` → `.setUsername(sessionToken: current.sessionToken, …)`.

`lib/core/providers/dio_provider.dart` — `user.expiresSoon` deixa de existir: trocar o argumento inteiro por `tokenExpiresSoon: () => false,` (provisório; a Task 10 remove o interceptor).

Testes em `test/unit/features/auth/` e `test/unit/core/network/`, `test/widget/features/app_shell/profile_screen_errors_test.dart`, `test/support/fakes/fake_auth_remote_datasource.dart`: trocar só os `AuthUser(… idToken: …)` por `sessionToken:` (o parâmetro `idToken` de `establishSession` fica). Comando seguro para esses arquivos:

```bash
perl -pi -e 's/\bidToken:\s*/sessionToken: /g' \
  test/unit/features/auth/auth_state_provider_test.dart \
  test/unit/features/auth/auth_refresh_id_token_test.dart \
  test/unit/core/network/dio_interceptors_wiring_test.dart \
  test/unit/core/network/auth_refresh_interceptor_test.dart \
  test/widget/features/app_shell/profile_screen_errors_test.dart
```
e revisar à mão as ocorrências restantes de `.idToken` nesses testes (`grep -n "\.idToken" test/unit/features/auth test/unit/core/network`), trocando por `.sessionToken`.

Apagar `test/unit/features/auth/auth_user_expiry_test.dart` (`git rm`). Em `test/unit/features/auth/auth_refresh_id_token_test.dart` e `test/unit/core/network/dio_interceptors_wiring_test.dart`, os testes que dependem de `expiresSoon`/JWT com `exp` («token expirando é renovado antes da request», «token ainda longe do vencimento não é renovado») passam a falhar — **apagar só esses dois testes** agora (a Task 10 apaga os arquivos inteiros).

- [ ] **Step 6: Rodar tudo**

Run: `flutter analyze lib test && flutter test`
Expected: analyze limpo; suíte verde.

- [ ] **Step 7: Commit**

```bash
git add -A lib test
git commit -m "refactor(auth): AuthUser.idToken vira sessionToken; sai AuthUserExpiry"
```

---

### Task 7: `AuthSessionStore` persistente (web `localStorage`, nativo `SharedPreferences`)

**Files:**
- Modify: `lib/features/auth/data/auth_session_store_web.dart`
- Modify: `lib/features/auth/data/auth_session_store_stub.dart`
- Modify: `lib/features/auth/presentation/providers/auth_state_provider.dart` (`authSessionStoreProvider`)
- Test: `test/unit/features/auth/auth_session_store_test.dart`

**Interfaces:**
- Produces: `AuthSessionStore({SharedPreferences? prefs})` (as duas variantes), `read()/write()/clear()` como hoje, `String? takeLegacySessionStorage()` (web: lê **e apaga** `sessionStorage['plpcg_auth_session']`; nativo: `null`), `static String? legacyIdToken(String? raw)` (extrai `idToken` do JSON antigo).

- [ ] **Step 1: Teste que falha**

```dart
// test/unit/features/auth/auth_session_store_test.dart
//
// Roda na VM → é a variante stub (nativo). A web só muda o backend
// (`localStorage`) e o `takeLegacySessionStorage`; a lógica de (de)serialização
// é a mesma, estática, no stub.
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const user = AuthUser(googleSub: 'sub-1', sessionToken: 'sess_a', name: 'Ana');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('write persiste em SharedPreferences e um store novo lê de volta', () async {
    final prefs = await SharedPreferences.getInstance();
    AuthSessionStore(prefs: prefs).write(user);

    final again = AuthSessionStore(prefs: prefs).read();
    expect(again?.googleSub, 'sub-1');
    expect(again?.sessionToken, 'sess_a');
    expect(prefs.getString('plpcg_auth_session'), isNotNull);
  });

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

  test('takeLegacySessionStorage no nativo é null', () {
    expect(AuthSessionStore().takeLegacySessionStorage(), isNull);
  });

  test('legacyIdToken extrai o id_token do JSON antigo', () {
    expect(
      AuthSessionStore.legacyIdToken('{"googleSub":"s","idToken":"eyJ.a.b"}'),
      'eyJ.a.b',
    );
    expect(AuthSessionStore.legacyIdToken('{"googleSub":"s"}'), isNull);
    expect(AuthSessionStore.legacyIdToken('nao é json'), isNull);
    expect(AuthSessionStore.legacyIdToken(null), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/auth_session_store_test.dart`
Expected: erro de compilação — `prefs` não é parâmetro; `takeLegacySessionStorage`/`legacyIdToken` não existem.

- [ ] **Step 3: Stub (nativo / VM)**

```dart
// lib/features/auth/data/auth_session_store_stub.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/auth_user.dart';

/// Sessão em memória + `SharedPreferences` (nativo / testes).
/// Web: [auth_session_store_web] — mesma API sobre `localStorage`.
///
/// Sem [prefs] fica só em memória — costura para testes que não querem
/// `SharedPreferences`; em produção o provider sempre passa a instância.
class AuthSessionStore {
  AuthSessionStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const String key = 'plpcg_auth_session';

  final SharedPreferences? _prefs;
  AuthUser? _cached;

  AuthUser? read() {
    if (_cached != null) return _cached;
    _cached = decode(_prefs?.getString(key));
    return _cached;
  }

  void write(AuthUser user) {
    _cached = user;
    // `setString` é assíncrono só no disco; a leitura seguinte já vê o valor.
    _prefs?.setString(key, encode(user));
  }

  void clear() {
    _cached = null;
    _prefs?.remove(key);
  }

  /// Sessão do formato antigo (web, `sessionStorage`) — não existe no nativo.
  String? takeLegacySessionStorage() => null;

  /// Serializa para JSON (usado pela implementação web).
  static String encode(AuthUser user) => jsonEncode(user.toJson());

  static AuthUser? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AuthUser.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return null;
    }
  }

  /// `idToken` de um documento no formato anterior a esta spec (spec D12).
  static String? legacyIdToken(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final token = decoded['idToken'];
      return token is String && token.isNotEmpty ? token : null;
    } on Object {
      return null;
    }
  }
}
```

- [ ] **Step 4: Web**

```dart
// lib/features/auth/data/auth_session_store_web.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../domain/entities/auth_user.dart';
import 'auth_session_store_stub.dart' as stub;

/// Sessão em memória + `localStorage` (spec D6): o token é opaco, revogável
/// e só o hash fica no Worker — por isso pode sobreviver a fechar a aba/PWA.
///
/// [prefs] é ignorado na web (assinatura comum com o stub).
class AuthSessionStore {
  AuthSessionStore({SharedPreferences? prefs});

  static const String key = stub.AuthSessionStore.key;

  AuthUser? _cached;

  AuthUser? read() {
    if (_cached != null) return _cached;
    _cached = stub.AuthSessionStore.decode(web.window.localStorage.getItem(key));
    return _cached;
  }

  void write(AuthUser user) {
    _cached = user;
    web.window.localStorage.setItem(key, stub.AuthSessionStore.encode(user));
  }

  void clear() {
    _cached = null;
    web.window.localStorage.removeItem(key);
  }

  /// Lê **e apaga** a sessão do formato antigo em `sessionStorage` (spec D12).
  /// Uma vez só: na carga seguinte já não existe.
  String? takeLegacySessionStorage() {
    final raw = web.window.sessionStorage.getItem(key);
    if (raw != null) web.window.sessionStorage.removeItem(key);
    return raw;
  }

  static String? legacyIdToken(String? raw) =>
      stub.AuthSessionStore.legacyIdToken(raw);
}
```

- [ ] **Step 5: Provider**

Em `auth_state_provider.dart`, adicionar `import '../../../../core/providers/shared_prefs_provider.dart';` e trocar o provider:

```dart
/// Persistência da sessão: `localStorage` na web, `SharedPreferences` no
/// nativo. Testes que exercitam o `AuthNotifier` real sobrescrevem este
/// provider com `AuthSessionStore()` (só memória).
final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(prefs: ref.read(sharedPreferencesProvider));
});
```

- [ ] **Step 6: Rodar**

Run: `flutter analyze lib test && flutter test test/unit/features/auth test/unit/core/network test/widget/features/app_shell`
Expected: verde (os testes existentes usam `AuthSessionStore()` sem argumento — continua válido).

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/data/auth_session_store_stub.dart lib/features/auth/data/auth_session_store_web.dart lib/features/auth/presentation/providers/auth_state_provider.dart test/unit/features/auth/auth_session_store_test.dart
git commit -m "feat(auth): sessão persiste em localStorage (web) e SharedPreferences (nativo)"
```

---

### Task 8: `AuthRemoteDatasource` — `sessionToken` na resposta e `revokeSession`

**Files:**
- Modify: `lib/features/auth/data/auth_remote_datasource.dart`
- Modify: `test/support/fakes/fake_auth_remote_datasource.dart`
- Test: `test/unit/features/auth/auth_remote_datasource_test.dart`

**Interfaces:**
- Produces: `establishSession(String idToken): Future<AuthUser>` (agora com `sessionToken` vindo do body), `revokeSession(String sessionToken): Future<void>`. Fake: `FakeAuthRemoteDatasource(behavior, {onRevoke})`, `revoked: List<String>`.

- [ ] **Step 1: Testes que falham** (acrescentar em `auth_remote_datasource_test.dart`, reaproveitando `_dioWith`)

```dart
  test('200 devolve AuthUser com o sessionToken do Worker', () async {
    final datasource = AuthRemoteDatasource(
      _dioWith(200, {
        'googleSub': 'sub-1',
        'email': 'a@b.com',
        'username': 'ana',
        'sessionToken': 'sess_abc',
      }),
    );
    final user = await datasource.establishSession('id-token-google');
    expect(user.googleSub, 'sub-1');
    expect(user.sessionToken, 'sess_abc');
    expect(user.username, 'ana');
  });

  test('200 sem sessionToken é erro (Worker antigo)', () async {
    final datasource = AuthRemoteDatasource(_dioWith(200, {'googleSub': 'sub-1'}));
    await expectLater(
      datasource.establishSession('id-token-google'),
      throwsA(isA<StateError>().having(
        (e) => e.message, 'message', 'auth_session_missing_token',
      )),
    );
  });

  test('revokeSession: 204 e 401 são sucesso; 5xx lança', () async {
    await AuthRemoteDatasource(_dioWith(204)).revokeSession('sess_a');
    await AuthRemoteDatasource(_dioWith(401)).revokeSession('sess_a');
    await expectLater(
      AuthRemoteDatasource(_dioWith(503)).revokeSession('sess_a'),
      throwsA(isA<DioException>()),
    );
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/auth_remote_datasource_test.dart`
Expected: os 3 novos falham (`sessionToken` vem do parâmetro; `revokeSession` não existe).

- [ ] **Step 3: Implementação**

Em `establishSession`, trocar o final (a partir de `final sub = data['googleSub'];`):

```dart
    final data = response.data!;
    final sub = data['googleSub'];
    if (sub is! String || sub.isEmpty) {
      throw StateError('auth_session_missing_sub');
    }
    // Sessão do Worker (spec D1): o id_token do Google foi consumido aqui e
    // não é guardado em lugar nenhum.
    final sessionToken = data['sessionToken'];
    if (sessionToken is! String || sessionToken.isEmpty) {
      throw StateError('auth_session_missing_token');
    }

    return AuthUser(
      googleSub: sub,
      email: data['email'] as String?,
      name: data['name'] as String?,
      pictureUrl: data['pictureUrl'] as String?,
      username: data['username'] as String?,
      sessionToken: sessionToken,
    );
```

Atualizar o doc-comment da classe para «`POST /api/auth/session` — troca o `id_token` do Google por uma sessão do Worker; `DELETE` a revoga.» e acrescentar o método:

```dart
  /// `DELETE /api/auth/session` — revoga a sessão no Worker.
  ///
  /// `204` e `401` (sessão já não existia) são sucesso: a sessão local vai
  /// ser apagada de qualquer jeito. 5xx/rede propagam para o chamador logar.
  Future<void> revokeSession(String sessionToken) async {
    await _dio.delete<void>(
      ApiEndpoints.authSession,
      options: Options(
        headers: {'Authorization': 'Bearer $sessionToken'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }
```

Fake compartilhada (`test/support/fakes/fake_auth_remote_datasource.dart`):

```dart
class FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  FakeAuthRemoteDatasource(this._behavior, {Future<void> Function(String)? onRevoke})
      : _onRevoke = onRevoke,
        super(Dio());

  factory FakeAuthRemoteDatasource.returning(AuthUser user) =>
      FakeAuthRemoteDatasource((_) async => user);

  final Future<AuthUser> Function(String idToken) _behavior;
  final Future<void> Function(String sessionToken)? _onRevoke;

  /// Tokens passados a [revokeSession], na ordem.
  final List<String> revoked = [];

  @override
  Future<AuthUser> establishSession(String idToken) => _behavior(idToken);

  @override
  Future<void> revokeSession(String sessionToken) async {
    revoked.add(sessionToken);
    await _onRevoke?.call(sessionToken);
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/auth/auth_remote_datasource_test.dart && flutter analyze lib test`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/auth_remote_datasource.dart test/support/fakes/fake_auth_remote_datasource.dart test/unit/features/auth/auth_remote_datasource_test.dart
git commit -m "feat(auth): datasource lê sessionToken do Worker e revoga no logout"
```

---

### Task 9: `AuthNotifier` — boot sem rede, migração, `onUnauthorized`, `signOut`, remoções

**Files:**
- Modify: `lib/features/auth/presentation/providers/auth_state_provider.dart`
- Modify: `test/unit/features/auth/auth_state_provider_test.dart`
- Delete: `test/unit/features/auth/auth_refresh_id_token_test.dart`

**Interfaces:**
- Consumes: Tasks 7–8.
- Produces: `AuthNotifier.onUnauthorized(): void`; `signOut()` revoga; `build()` conforme D7/D12. Removidos: `refreshIdToken`, `googleSilentIdTokenRefresherProvider`, `GoogleSilentIdTokenRefresher`, `sessionExpiredProvider`, `SessionExpiredNotifier`, `googleSignInUnavailableProvider`, `GoogleSignInUnavailableNotifier`.

- [ ] **Step 1: Testes que falham** — em `auth_state_provider_test.dart`:

1. `buildContainer`: remover os parâmetros `initializer`/`refresher` e as duas linhas de override correspondentes (o `build()` já não inicializa o SDK). Manter `inbox`/`browser`.
2. Apagar os grupos «resiliência de sessão (B1)» (o boot já não chama a rede), «SDK do Google indisponível (A5)» e «refreshIdToken — transitório vs conclusivo (D.4)» inteiros.
3. Acrescentar:

```dart
  group('AuthNotifier.build — boot sem rede (spec D7)', () {
    test('sessão guardada é devolvida sem chamar o Worker', () async {
      final store = seededStore();
      var calls = 0;
      final container = buildContainer(
        store: store,
        behavior: (_) async {
          calls++;
          return storedUser;
        },
      );
      addTearDown(container.dispose);

      expect(await container.read(authStateProvider.future), same(storedUser));
      expect(calls, 0);
    });

    test('sem sessão guardada retorna null sem chamar a rede', () async {
      var calls = 0;
      final container = buildContainer(
        store: AuthSessionStore(),
        behavior: (_) async {
          calls++;
          return storedUser;
        },
      );
      addTearDown(container.dispose);

      expect(await container.read(authStateProvider.future), isNull);
      expect(calls, 0);
    });
  });

  group('AuthNotifier.build — migração da sessão antiga (spec D12)', () {
    test('sessionStorage antigo com id_token vira sessão nova gravada', () async {
      final store = _LegacyStore('{"googleSub":"sub-1","idToken":"eyJ.a.b"}');
      String? received;
      final container = buildContainer(
        store: store,
        behavior: (idToken) async {
          received = idToken;
          return storedUser;
        },
      );
      addTearDown(container.dispose);

      expect(await container.read(authStateProvider.future), same(storedUser));
      expect(received, 'eyJ.a.b');
      expect(store.read(), same(storedUser));
      expect(store.legacyTaken, isTrue);
    });

    test('id_token antigo recusado → null, e o sessionStorage foi consumido', () async {
      final store = _LegacyStore('{"googleSub":"sub-1","idToken":"eyJ.a.b"}');
      final container = buildContainer(
        store: store,
        behavior: (_) async => throw AuthUnauthorizedException(401),
      );
      addTearDown(container.dispose);

      expect(await container.read(authStateProvider.future), isNull);
      expect(store.read(), isNull);
      expect(store.legacyTaken, isTrue);
    });
  });

  group('AuthNotifier.onUnauthorized / signOut (spec D8)', () {
    test('onUnauthorized limpa a store e o estado vira null', () async {
      final store = seededStore();
      final container = buildContainer(store: store, behavior: (_) async => storedUser);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      container.read(authStateProvider.notifier).onUnauthorized();

      expect(container.read(authStateProvider).asData?.value, isNull);
      expect(store.read(), isNull);
    });

    test('signOut revoga a sessão no Worker e limpa mesmo se a revogação falhar', () async {
      final store = seededStore();
      final remote = FakeAuthRemoteDatasource(
        (_) async => storedUser,
        onRevoke: (_) async => throw DioException(
          requestOptions: RequestOptions(path: '/api/auth/session'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authSessionStoreProvider.overrideWithValue(store),
          authRemoteDatasourceProvider.overrideWithValue(remote),
          googleClientIdProvider.overrideWithValue('cid-test'),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      await container.read(authStateProvider.notifier).signOut();

      expect(remote.revoked, ['token-1']);
      expect(container.read(authStateProvider).asData?.value, isNull);
      expect(store.read(), isNull);
    });
  });
```

4. No topo do arquivo (depois dos imports), a store de teste que simula o `sessionStorage` antigo:

```dart
/// Store só-memória que finge ter uma sessão no formato antigo em
/// `sessionStorage` — o stub nativo devolve sempre `null` ali.
class _LegacyStore extends AuthSessionStore {
  _LegacyStore(this._legacyRaw);

  String? _legacyRaw;
  bool legacyTaken = false;

  @override
  String? takeLegacySessionStorage() {
    legacyTaken = true;
    final raw = _legacyRaw;
    _legacyRaw = null;
    return raw;
  }
}
```

(`storedUser` do arquivo já usa `sessionToken: 'token-1'` desde a Task 6 — o `revoked` acima confere isso.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/auth/auth_state_provider_test.dart`
Expected: erro de compilação (`onUnauthorized` não existe) — bom sinal.

- [ ] **Step 3: Implementação do notifier**

Em `auth_state_provider.dart`:

1. **Apagar**: `googleSignInUnavailableProvider` + `GoogleSignInUnavailableNotifier` (e seus doc-comments), `GoogleSilentIdTokenRefresher` + `googleSilentIdTokenRefresherProvider`, `sessionExpiredProvider` + `SessionExpiredNotifier`, e na classe `AuthNotifier`: `_refreshInFlight`, `refreshIdToken`, `_refreshIdToken`.

2. **`build()`** inteiro:

```dart
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
```

3. **`ensureGoogleInitialized`** fica como está (chamada só por `signInWithGoogle`). Atualizar o doc-comment de `googleSignInInitializerProvider` removendo a menção a A5, e o de `ensureGoogleInitialized` para «Chamada só pelo login nativo ([signInWithGoogle]); a web entra por redirect e não precisa do SDK.»

4. **Novo método** (depois de `startGoogleRedirect`):

```dart
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
```

5. **`_establishAndStore`**: remover a linha `ref.read(sessionExpiredProvider.notifier).clear();`. **`_onGoogleAuthEvent`** (caso `SignOut`): idem.

6. **`signOut()`**:

```dart
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
```

7. Provisórios para compilar (a Task 10 reescreve/apaga estes arquivos):
   - `git rm test/unit/features/auth/auth_refresh_id_token_test.dart`.
   - `lib/core/providers/dio_provider.dart`: trocar `refreshIdToken: () => ref.read(authStateProvider.notifier).refreshIdToken(),` por `refreshIdToken: () async => null,` e `isSessionExpired: () => ref.read(sessionExpiredProvider),` / `markSessionExpired: () => ref.read(sessionExpiredProvider.notifier).markExpired(),` por `isSessionExpired: () => false,` / `markSessionExpired: () {},`.
   - `test/unit/core/network/dio_interceptors_wiring_test.dart`: apagar todos os `test(...)` exceto os dois primeiros («dioProvider tem AuthRefreshInterceptor antes do RetryInterceptor» e «coldigomDioProvider tem retry mas não refresh»); em `buildContainer`, remover o parâmetro `refresher` e os overrides de `googleSignInInitializerProvider`/`googleSilentIdTokenRefresherProvider`; apagar `noopInitializer`, `_jwtExpiringIn`, `_b64` e os imports que ficarem sem uso.
   - `test/widget/features/app_shell/profile_screen_errors_test.dart`: remover o override de `googleSignInInitializerProvider` de `baseOverrides` (e `noopInitializer`, e o import de `google_sign_in`) e os dois testes de banner («sessão expirada mostra banner…», «sem sessão expirada não mostra banner») — a Task 11 acrescenta o teste novo.
   - `lib/features/app_shell/presentation/pages/profile_screen.dart`: trocar `final sessionExpired = ref.watch(sessionExpiredProvider);` por `const sessionExpired = false;` (a Task 11 remove o banner de vez).

- [ ] **Step 4: Rodar**

Run: `flutter analyze lib test && flutter test test/unit/features/auth test/unit/core/network test/widget/features/app_shell test/widget/features/auth`
Expected: analyze limpo (`AuthRefreshInterceptor` ainda existe, só ficou inerte) e testes verdes.

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat(auth): boot sem rede, migração do sessionStorage, 401 desloga, logout revoga"
```

---

### Task 10: `AuthUnauthorizedInterceptor` no lugar do `AuthRefreshInterceptor`

**Files:**
- Create: `lib/core/network/auth_unauthorized_interceptor.dart`
- Delete: `lib/core/network/auth_refresh_interceptor.dart`, `test/unit/core/network/auth_refresh_interceptor_test.dart`
- Modify: `lib/core/providers/dio_provider.dart`, `lib/core/network/retry_interceptor.dart` (só o doc-comment da linha 10)
- Create: `test/unit/core/network/auth_unauthorized_interceptor_test.dart`
- Modify: `test/unit/core/network/dio_interceptors_wiring_test.dart`

**Interfaces:**
- Produces: `AuthUnauthorizedInterceptor({required void Function() onUnauthorized})`.

- [ ] **Step 1: Teste que falha**

```dart
// test/unit/core/network/auth_unauthorized_interceptor_test.dart
import 'dart:typed_data';

import 'package:coldigui/core/network/auth_unauthorized_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString('{}', status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  late int calls;
  late Dio dio;

  Dio build(int status) {
    calls = 0;
    return Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StatusAdapter(status)
      ..interceptors.add(AuthUnauthorizedInterceptor(onUnauthorized: () => calls++));
  }

  Future<void> get(String? bearer, {bool tolerate401 = false}) async {
    try {
      await dio.get<Object?>(
        '/api/playlists',
        options: Options(
          headers: bearer == null ? null : {'Authorization': 'Bearer $bearer'},
          validateStatus: tolerate401 ? (s) => s != null && s < 500 : null,
        ),
      );
    } on DioException {
      // O 401 continua chegando ao chamador — o interceptor não o engole.
    }
  }

  test('401 com Bearer sess_ dispara onUnauthorized (caminho onError)', () async {
    dio = build(401);
    await get('sess_abc');
    expect(calls, 1);
  });

  test('401 com Bearer sess_ dispara também quando validateStatus tolera 401 (onResponse)', () async {
    dio = build(401);
    await get('sess_abc', tolerate401: true);
    expect(calls, 1);
  });

  test('401 sem Authorization (rota pública) não dispara', () async {
    dio = build(401);
    await get(null);
    expect(calls, 0);
  });

  test('401 com JWT do Google (POST /session) não dispara', () async {
    dio = build(401);
    await get('eyJhbGciOi.eyJzdWIi.sig');
    expect(calls, 0);
  });

  test('403 e 200 não disparam', () async {
    dio = build(403);
    await get('sess_abc');
    dio = build(200);
    await get('sess_abc');
    expect(calls, 0);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/core/network/auth_unauthorized_interceptor_test.dart`
Expected: erro de compilação — arquivo não existe.

- [ ] **Step 3: Implementação**

```dart
// lib/core/network/auth_unauthorized_interceptor.dart
import 'package:dio/dio.dart';

import '../../features/auth/domain/entities/auth_user.dart';

/// `401` numa request que saiu com `Authorization: Bearer sess_…` significa
/// «o Worker não reconhece mais esta sessão» (revogada ou vencida — spec D8).
/// Avisa o `AuthNotifier` e deixa o 401 seguir para o chamador.
///
/// Não age em rota pública (sem `Authorization`) nem no JWT do Google (só a
/// `POST /api/auth/session` o manda — um 401 ali é «login falhou», não
/// «sessão morreu»). 403 é permissão, não sessão.
///
/// Trata as duas pontas porque os datasources autenticados usam
/// `validateStatus: < 500` — para eles o 401 chega como **resposta**
/// (`onResponse`), não como `DioException` (`onError`).
class AuthUnauthorizedInterceptor extends Interceptor {
  AuthUnauthorizedInterceptor({required this.onUnauthorized});

  final void Function() onUnauthorized;

  static bool _isSessionRequest(RequestOptions options) {
    final auth = options.headers['Authorization'];
    return auth is String && auth.startsWith('Bearer $kSessionTokenPrefix');
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 401 && _isSessionRequest(response.requestOptions)) {
      onUnauthorized();
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 && _isSessionRequest(err.requestOptions)) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
```

- [ ] **Step 4: `dio_provider.dart`**

Substituir o import de `auth_refresh_interceptor.dart` por `'../network/auth_unauthorized_interceptor.dart'`, apagar o import de `auth_user.dart` se ficar sem uso, e trocar o doc-comment + o bloco de interceptors:

```dart
/// Cliente HTTP Dio para endpoints Cloudflare (manifest, PDFs, ZIPs).
///
/// [BaseOptions.baseUrl] vem de [AppConfig.apiBaseUrl]
/// (`--dart-define=PLPCG_API_BASE_URL`).
///
/// Interceptors (nesta ordem): [AuthUnauthorizedInterceptor] vê o 401 antes
/// de o [RetryInterceptor] ver o erro (401 não é repetido — sessão revogada
/// não volta sozinha). Todos os datasources que passam por aqui (playlists,
/// social, audio_flags, material_kind_prefs, catálogo, PDFs) herdam os dois.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.addAll([
    AuthUnauthorizedInterceptor(
      // `read` (e não `watch`) de propósito: o Dio não deve ser recriado a cada
      // mudança de sessão, e a chamada só acontece dentro de um 401.
      onUnauthorized: () =>
          ref.read(authStateProvider.notifier).onUnauthorized(),
    ),
    RetryInterceptor(dio: dio),
  ]);

  return dio;
});
```

Em `retry_interceptor.dart`, linha 10: «(401 é caso do `AuthRefreshInterceptor`)» → «(401 é caso do `AuthUnauthorizedInterceptor`)».

`git rm lib/core/network/auth_refresh_interceptor.dart test/unit/core/network/auth_refresh_interceptor_test.dart`.

- [ ] **Step 5: Reescrever `dio_interceptors_wiring_test.dart`**

```dart
import '../../../support/fakes/fake_auth_remote_datasource.dart';
import 'dart:typed_data';
import 'package:coldigui/core/network/auth_unauthorized_interceptor.dart';
import 'package:coldigui/core/network/retry_interceptor.dart';
import 'package:coldigui/core/providers/dio_provider.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_dio_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statuses);

  final List<int> statuses;
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statuses[authHeaders.length.clamp(0, statuses.length - 1)];
    authHeaders.add(options.headers['Authorization'] as String?);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const storedUser = AuthUser(googleSub: 'sub-1', sessionToken: 'sess_velho');

  ProviderContainer buildContainer({AuthUser user = storedUser}) {
    final store = AuthSessionStore()..write(user);
    return ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authRemoteDatasourceProvider.overrideWithValue(
          FakeAuthRemoteDatasource.returning(user),
        ),
      ],
    );
  }

  test('dioProvider tem AuthUnauthorizedInterceptor antes do RetryInterceptor', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final interceptors = container.read(dioProvider).interceptors.toList();
    final authIndex = interceptors.indexWhere((i) => i is AuthUnauthorizedInterceptor);
    final retryIndex = interceptors.indexWhere((i) => i is RetryInterceptor);

    expect(authIndex, greaterThanOrEqualTo(0));
    expect(retryIndex, greaterThan(authIndex));
  });

  test('coldigomDioProvider tem retry mas não o interceptor de sessão (API pública)', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final interceptors = container.read(coldigomDioProvider).interceptors;
    expect(interceptors.whereType<RetryInterceptor>(), hasLength(1));
    expect(interceptors.whereType<AuthUnauthorizedInterceptor>(), isEmpty);
  });

  test('401 no dioProvider com Bearer sess_ desloga e não repete a request', () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    expect(await container.read(authStateProvider.future), same(storedUser));

    final adapter = _ScriptedAdapter([401, 200]);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await expectLater(
      dio.get<Object?>(
        '/api/playlists',
        options: Options(headers: {'Authorization': 'Bearer sess_velho'}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(adapter.authHeaders, ['Bearer sess_velho']);
    expect(container.read(authStateProvider).asData?.value, isNull);
  });

  test('401 em rota pública não mexe na sessão', () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    final dio = container.read(dioProvider)..httpClientAdapter = _ScriptedAdapter([401]);
    await expectLater(dio.get<Object?>('/api/catalog/x'), throwsA(isA<DioException>()));

    expect(container.read(authStateProvider).asData?.value, same(storedUser));
  });
}
```

- [ ] **Step 6: Rodar tudo**

Run: `flutter analyze lib test && flutter test`
Expected: verde. `grep -rn "AuthRefreshInterceptor\|refreshIdToken\|sessionExpiredProvider\|googleSignInUnavailableProvider\|googleSilentIdTokenRefresherProvider\|AuthUserExpiry" lib test` devolve vazio.

- [ ] **Step 7: Commit**

```bash
git add -A lib test
git commit -m "refactor(network): AuthUnauthorizedInterceptor substitui a renovação do id_token"
```

---

### Task 11: Perfil sem banner «Sessão expirada» + l10n

**Files:**
- Modify: `lib/features/app_shell/presentation/pages/profile_screen.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ `flutter gen-l10n`)
- Modify: `test/widget/features/app_shell/profile_screen_errors_test.dart`

- [ ] **Step 1: Teste que falha** (acrescentar em `profile_screen_errors_test.dart`, com `pt` e `pumpProfile`/`baseOverrides` já existentes)

```dart
  testWidgets('sessão revogada (onUnauthorized) volta ao botão de entrar', (
    tester,
  ) async {
    final store = AuthSessionStore()..write(user);
    final container = ProviderContainer(
      overrides: baseOverrides(behavior: (_) async => user, store: store),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jairo'), findsWidgets);

    container.read(authStateProvider.notifier).onUnauthorized();
    await tester.pumpAndSettle();

    expect(find.text(pt.authSignInWithGoogle), findsOneWidget);
    expect(find.text('Jairo'), findsNothing);
  });
```

(Se `baseOverrides` ainda passar `googleSignInInitializerProvider`, remover — o provider existe, mas o `build()` não o usa mais. Conferir que `find.text('Jairo')` bate com o que `_SignedInHeader` renderiza; se o header mostra `displayFirstName`, é «Jairo» mesmo.)

- [ ] **Step 2: Rodar e ver passar**

Run: `flutter test test/widget/features/app_shell/profile_screen_errors_test.dart`
Expected: verde — o comportamento já existe desde a Task 9; este teste fixa o contrato da tela antes de o banner sair. Se `find.text('Jairo')` não achar nada, olhar o que `_SignedInHeader` renderiza (`user.displayFirstName` ou `user.name`) e ajustar o finder — não o widget.

- [ ] **Step 3: Remover o banner**

Em `profile_screen.dart`: apagar `const sessionExpired = false;` (Task 9) e o bloco `if (sessionExpired) ...[ const _SessionExpiredBanner(), const SizedBox(height: 12), ],`; apagar a classe `_SessionExpiredBanner` inteira. Se `AppColors`/`ConsumerWidget` ficarem sem uso no arquivo, o analyze avisa — remover o import só se ficar sem uso.

- [ ] **Step 4: l10n**

Remover de `lib/l10n/app_pt.arb` as entradas `sessionExpiredBanner`, `@sessionExpiredBanner`, `sessionExpiredSignInAgain`, `@sessionExpiredSignInAgain`; de `app_en.arb`, `sessionExpiredBanner` e `sessionExpiredSignInAgain`. Rodar `flutter gen-l10n`. `grep -rn "sessionExpiredBanner\|sessionExpiredSignInAgain" lib test` tem de devolver vazio.

- [ ] **Step 5: Rodar**

Run: `flutter analyze lib test && flutter test test/widget/features/app_shell`
Expected: verde.

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "feat(perfil): sem banner de sessão expirada — 401 volta direto ao botão de entrar"
```

---

### Task 12: Documentação

**Files:**
- Modify: `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md` (tabela «Armazenamento de token por plataforma», ~linha 564)
- Modify: `docs/superpowers/specs/2026-09-13-google-login-redirect-coop-design.md` (D10)
- Modify: `docs/features/FEATURE_INDEX.md` (entrada de auth)

- [ ] **Step 1: `USER_AUTH_PLAYLIST_SYNC_SPEC.md`**

Logo acima da tabela «Armazenamento de token por plataforma», inserir:

> **Superado em 2026-09-13** por `docs/superpowers/specs/2026-09-13-worker-session-persistence-design.md`: o app guarda um **token de sessão opaco do Worker** (`sess_…`, 60 d deslizantes, só o hash em D1) em `localStorage` (web) / `SharedPreferences` (nativo). O `id_token` do Google é consumido uma vez no `POST /api/auth/session` e não é guardado. A tabela abaixo descreve o MVP anterior.

- [ ] **Step 2: Spec do login por redirect**, linha D10: acrescentar ao final da célula «**Superado (2026-09-13):** a renovação silenciosa não existe mais — a sessão é do Worker (spec `worker-session-persistence`); o plugin fica só para o login nativo e `signOut`.»

- [ ] **Step 3: `FEATURE_INDEX.md`**: localizar a entrada de autenticação (`grep -n "AuthNotifier\|authStateProvider" docs/features/FEATURE_INDEX.md`) e acrescentar uma frase: «**Sessão persistente ✅ (2026-09-13):** `POST /api/auth/session` devolve `sessionToken` (`user_sessions`, 60 d deslizantes); `AuthSessionStore` em `localStorage`/`SharedPreferences`; boot sem rede; `AuthUnauthorizedInterceptor` desloga no 401; `DELETE /api/auth/session` no logout.»

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "docs(auth): sessão do Worker substitui id_token em sessionStorage"
```

---

### Task 13: Rollout do app e checklist manual (spec §8)

**Pré-requisito:** Task 5 concluída e verificada (Worker em produção aceitando `sess_`).

- [ ] **Step 1: Suíte completa**

Run: `./scripts/test_all.sh`
Expected: analyze, VM e Chrome verdes.

- [ ] **Step 2: Deploy Pages**

Run: `./scripts/web_deploy.sh`
Expected: tabela com commit e cache tag; `curl -s https://v2.plpcg.com/version.json` mostra o `web_cache_tag` novo.

- [ ] **Step 3: Checklist em `https://v2.plpcg.com` (iPhone/PWA e desktop)**

1. Login → fechar o PWA → reabrir: continua logado; na aba Network não há `POST /api/auth/session` no boot.
2. Favoritos de material ordenam o sheet e o «+»/long-press respeitam o favorito **depois** de reabrir.
3. Logout → reabrir: deslogado. No D1: `wrangler d1 execute plpcg-catalog --remote --command "SELECT count(*) FROM user_sessions WHERE google_sub = '<sub>'"` → 0.
4. Com o app aberto e logado, apagar a linha no D1 (`DELETE FROM user_sessions WHERE google_sub = '<sub>'`) → próxima ação autenticada (salvar favorito) volta ao botão de entrar, sem erro na tela.
5. Aba que ainda tinha o app antigo em `sessionStorage`: recarregar → migra sem pedir login (se o `id_token` ainda valia) e `sessionStorage['plpcg_auth_session']` some.
6. `localStorage['plpcg_auth_session']` contém `sessionToken` começando por `sess_` e **não** contém `idToken`.

- [ ] **Step 4: Registrar o resultado** no final da spec (`## 12. Rollout` com data, versão do Worker e cache tag do Pages) e commitar: `git commit -m "docs(auth): rollout da sessão persistente verificado"`.
