# Contribuições da comunidade — Backend (plpcg-catalog + coldigom-api) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Receber contribuições (bug, informação errada, conteúdo, melhoria) de usuários logados da app, com anexos em quarentena no R2, scan assíncrono (estrutural + Safe Browsing + VirusTotal) e rotas admin de leitura/decisão.

**Architecture:** O `plpcg-catalog` ganha um endpoint de introspecção do token `sess_…`. O `coldigom-api` é dono dos dados: middleware `requireAppUser` chama o introspect; `POST /api/contributions` valida, grava em `quarantine/` do R2 e em D1, e enfileira na Queue `contrib-scan`; o consumer aplica os passos de scan e move para `contributions/` ou bloqueia. Rotas admin lêem a fila e gravam decisão.

**Tech Stack:** Cloudflare Workers, Hono (coldigom-api), D1, R2, Queues, cron trigger; vitest (coldigom-api) e `node --test` (plpcg-catalog). TypeScript.

**Spec:** `docs/superpowers/specs/2026-09-17-contribuicoes-comunidade-design.md` (no repo `coldigui`). Os executores lêem o spec e este plano.

## Global Constraints

- Dois repositórios: `coldigui` (`workers/plpcg-catalog`) e `../coldigom` (`api/`). Cada task diz em qual repo trabalha. **Git sempre como comando plano** (`git add …`, `git commit …`), nunca `cd X && git …` nem `git -C`.
- Comentários e mensagens de commit em português, no estilo dos arquivos vizinhos (explicar o **porquê**, não o quê).
- coldigom-api: testes em `api/src/__tests__/*.test.ts`, rodar com `cd api && npx vitest run --pool=threads <arquivo>`; cobertura tem catraca (`vitest.config.ts`) — não baixar thresholds. `npx tsc --noEmit` deve passar. ESLint: `npm run lint` em `api/`.
- plpcg-catalog: testes `*.test.ts` ao lado do código, rodar com `npm test` em `workers/plpcg-catalog`; `npm run typecheck`.
- Limites (spec §4.2): 5 arquivos, 32 MiB cada (`33554432` bytes), extensões `pdf|mp3|jpg|jpeg|png|txt|chordpro`; 5 links, hosts `youtube.com | www.youtube.com | youtu.be | drive.google.com | docs.google.com`; título ≤ 120, corpo ≤ 4000; cota 20 envios e 200 MiB (`209715200`) por usuário por dia UTC; VirusTotal ≤ 450 chamadas/dia.
- Estados (spec §3): `status ∈ recebida|bloqueada|pendente|em_analise|aceita|recusada|aplicada`; `scan_status ∈ pendente|adiado|limpa|suspeita|infectada|sem_arquivo`.
- Nada em `quarantine/` ou `contributions/` é servido fora da rota admin; a rota admin só serve `scan_status = limpa`.

---

## File Structure

**coldigui / `workers/plpcg-catalog/src`**
- Modify `auth/user_sessions.ts` — extrair `lookupSession` (sem touch) usado por `findSession`.
- Create `auth/introspect.ts` — `handleIntrospect(db, request)`.
- Create `auth/introspect.test.ts`.
- Modify `test/fake_d1.ts` — `users` com `email`; `SELECT email, name, username FROM users WHERE google_sub = ?`.
- Modify `index.ts` — rota `GET /api/auth/introspect`.
- Modify `README.md` — linha na tabela de endpoints.

**coldigom / `api`**
- Create `migrations/020_contributions.sql`.
- Modify `wrangler.toml` — `PLPCG_AUTH_URL`, queue `contrib-scan`, cron.
- Modify `src/env.ts` — `CONTRIB_SCAN`, `PLPCG_AUTH_URL`, `VIRUSTOTAL_API_KEY`, `SAFE_BROWSING_API_KEY`, variável `appUser`.
- Create `src/appUser.ts` — `requireAppUser`, cache.
- Create `src/contributions/schema.ts` — validação do `payload`.
- Create `src/contributions/sniff.ts` — magic bytes (usado pela rota e pelo scan).
- Create `src/contributions/structural.ts` — checagens sobre o objeto inteiro.
- Create `src/contributions/links.ts` — allowlist, normalização, Safe Browsing.
- Create `src/contributions/virustotal.ts` — cliente VT.
- Create `src/contributions/quota.ts` — cota diária.
- Create `src/contributions/repo.ts` — SQL de `contributions`/`contribution_files`.
- Create `src/contributions/scan.ts` — consumer da Queue + cron.
- Create `src/routes/contributions.ts` — rotas do usuário.
- Create `src/routes/contributionsAdmin.ts` — rotas admin.
- Modify `src/index.ts` — registrar rotas, `queue` por fila, `scheduled`.
- Tests em `src/__tests__/`: `appUser.test.ts`, `contributionsSchema.test.ts`, `contributionsSniff.test.ts`, `contributionsStructural.test.ts`, `contributionsLinks.test.ts`, `contributionsVirustotal.test.ts`, `contributionsRoutes.test.ts`, `contributionsScan.test.ts`, `contributionsAdmin.test.ts`.
- Modify `README.md` do coldigom (ou `api/README` se existir) — endpoints, secrets, lifecycle rule, deploy.

---

### Task 1: `GET /api/auth/introspect` no plpcg-catalog

**Repo:** `coldigui`, diretório `workers/plpcg-catalog`.

**Files:**
- Modify: `src/auth/user_sessions.ts`
- Create: `src/auth/introspect.ts`
- Create: `src/auth/introspect.test.ts`
- Modify: `src/test/fake_d1.ts` (`selectUsers`, tipo `users` em `FakeD1Options`)
- Modify: `src/index.ts` (bloco das rotas `/api/auth/…`)
- Modify: `README.md`

**Interfaces:**
- Produces: `GET /api/auth/introspect` com `Authorization: Bearer sess_…` → `200 { userId: string, email: string | null, name: string | null, username: string | null }` (`Cache-Control: no-store`) | `401 { error: 'unauthorized' }`. Consumido pela Task 2.
- Produces: `lookupSession(db, token, now?) → Promise<{ sub: string } | null>` (sem renovar a sessão).

- [ ] **Step 1: Escrever os testes**

`src/auth/introspect.test.ts`:

```ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import { handleIntrospect } from './introspect.ts';
import { hashSessionToken } from './session_token.ts';

const NOW = new Date('2026-09-17T12:00:00Z');

async function dbWithSession(token: string, opts: { expired?: boolean } = {}) {
  const db = new FakeD1Database([], {
    users: [{ google_sub: 'u1', username: 'ana', name: 'Ana', email: 'ana@b.c' }],
    sessions: [
      {
        token_hash: await hashSessionToken(token),
        google_sub: 'u1',
        created_at: '2026-09-01T00:00:00Z',
        last_seen_at: '2026-09-01T00:00:00Z',
        expires_at: opts.expired ? '2026-09-02T00:00:00Z' : '2026-11-01T00:00:00Z',
      },
    ],
  });
  return db;
}

function request(bearer?: string): Request {
  return new Request('https://example.test/api/auth/introspect', {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

test('sessão válida devolve userId, email, name, username e não renova a sessão', async () => {
  const db = await dbWithSession('sess_abc');
  const res = await handleIntrospect(fakeDb(db), request('sess_abc'), NOW);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await res.json(), {
    userId: 'u1',
    email: 'ana@b.c',
    name: 'Ana',
    username: 'ana',
  });
  // Introspecção não é uso do usuário: nada de UPDATE em user_sessions.
  assert.ok(!db.executed.some((sql) => /UPDATE user_sessions/i.test(sql)));
});

test('sessão expirada → 401', async () => {
  const db = await dbWithSession('sess_abc', { expired: true });
  const res = await handleIntrospect(fakeDb(db), request('sess_abc'), NOW);
  assert.equal(res.status, 401);
});

test('JWT (não sess_) → 401 sem consultar o banco', async () => {
  const db = await dbWithSession('sess_abc');
  const res = await handleIntrospect(fakeDb(db), request('eyJhbGciOi.jwt.token'), NOW);
  assert.equal(res.status, 401);
  assert.equal(db.executed.length, 0);
});

test('sem Bearer → 401', async () => {
  const db = await dbWithSession('sess_abc');
  const res = await handleIntrospect(fakeDb(db), request(), NOW);
  assert.equal(res.status, 401);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm test` (em `workers/plpcg-catalog`)
Expected: falha por `./introspect.ts` inexistente e por `email` não aceito em `users` do fake.

- [ ] **Step 3: Estender o fake D1**

Em `src/test/fake_d1.ts`:
- No tipo `FakeD1Options.users`, acrescentar `email?: string | null`.
- Novo mapa `readonly userEmails = new Map<string, string | null>();` preenchido no construtor (`this.userEmails.set(user.google_sub, user.email ?? null)`).
- Em `selectUsers`, o ramo `google_sub = ?` devolve também `email`:

```ts
    const sub = bindings[0] as string;
    const username = this.usernames.get(sub);
    if (username === undefined) return [];
    return [{ username, name: this.userNames.get(sub) ?? null, email: this.userEmails.get(sub) ?? null }];
```

- Adicionar na tabela de SQL suportado do cabeçalho: `SELECT email, name, username FROM users WHERE google_sub = ?` (`introspect.ts`) → `FROM users` + `google_sub = ?`.

- [ ] **Step 4: Extrair `lookupSession` sem touch**

Em `src/auth/user_sessions.ts`, dividir `findSession`:

```ts
/**
 * `{ sub }` de uma sessão válida, ou `null` — **sem** renovar nada. É o que a
 * introspecção usa: ser consultado pelo coldigom-api não é uso do usuário e
 * não pode empurrar o `expires_at`.
 */
export async function lookupSession(
  db: D1Database,
  token: string,
  now: Date = new Date(),
): Promise<{ sub: string; lastSeenAt: string } | null> {
  const hash = await hashSessionToken(token);
  const row = await db
    .prepare(
      `SELECT google_sub, last_seen_at FROM user_sessions
       WHERE token_hash = ? AND expires_at > ?`,
    )
    .bind(hash, now.toISOString())
    .first<SessionLookupRow>();
  return row ? { sub: row.google_sub, lastSeenAt: row.last_seen_at } : null;
}

export async function findSession(
  db: D1Database,
  token: string,
  now: Date = new Date(),
): Promise<{ sub: string } | null> {
  const found = await lookupSession(db, token, now);
  if (!found) return null;
  const lastSeen = Date.parse(found.lastSeenAt);
  if (now.getTime() - lastSeen > SESSION_TOUCH_INTERVAL_MS) {
    await db
      .prepare(`UPDATE user_sessions SET last_seen_at = ?, expires_at = ? WHERE token_hash = ?`)
      .bind(now.toISOString(), expiresFrom(now), await hashSessionToken(token))
      .run();
  }
  return { sub: found.sub };
}
```

- [ ] **Step 5: Implementar o handler**

`src/auth/introspect.ts`:

```ts
import { isSessionToken } from './session_token.ts';
import { lookupSession } from './user_sessions.ts';

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

export interface IntrospectJson {
  userId: string;
  email: string | null;
  name: string | null;
  username: string | null;
}

/**
 * `GET /api/auth/introspect` — servidor-a-servidor (coldigom-api). Só aceita
 * `sess_…`: um `id_token` do Google vazado não pode virar identidade aqui.
 * Não renova a sessão (spec contribuições §4.1).
 */
export async function handleIntrospect(
  db: D1Database,
  request: Request,
  now: Date = new Date(),
): Promise<Response> {
  const token = bearerToken(request);
  if (!token || !isSessionToken(token)) return json({ error: 'unauthorized' }, 401);
  const session = await lookupSession(db, token, now);
  if (!session) return json({ error: 'unauthorized' }, 401);
  const row = await db
    .prepare(`SELECT email, name, username FROM users WHERE google_sub = ?`)
    .bind(session.sub)
    .first<{ email: string | null; name: string | null; username: string | null }>();
  return json(
    {
      userId: session.sub,
      email: row?.email ?? null,
      name: row?.name ?? null,
      username: row?.username ?? null,
    } satisfies IntrospectJson,
    200,
  );
}
```

- [ ] **Step 6: Rota em `index.ts`**

Logo antes do bloco `if (url.pathname === '/api/auth/username')`:

```ts
    if (url.pathname === '/api/auth/introspect') {
      if (request.method !== 'GET') {
        return jsonResponse({ error: 'method not allowed' }, { status: 405 });
      }
      // Sem withCors: é chamado pelo coldigom-api, não por navegador.
      return handleIntrospect(env.DB, request);
    }
```

Import: `import { handleIntrospect } from './auth/introspect';`.

- [ ] **Step 7: Rodar testes e typecheck**

Run: `npm test && npm run typecheck`
Expected: todos passam (inclusive `user_sessions.test.ts` e `session_handlers.test.ts` existentes).

- [ ] **Step 8: README**

Na tabela de endpoints do `README.md`, após `DELETE /api/auth/session`:

`| \`GET\` | \`/api/auth/introspect\` | Bearer \`sess_…\` (só sessão) | Servidor-a-servidor para o coldigom-api: \`{ userId, email, name, username }\` sem renovar a sessão |`

- [ ] **Step 9: Commit**

```bash
git add workers/plpcg-catalog/src/auth/introspect.ts workers/plpcg-catalog/src/auth/introspect.test.ts workers/plpcg-catalog/src/auth/user_sessions.ts workers/plpcg-catalog/src/test/fake_d1.ts workers/plpcg-catalog/src/index.ts workers/plpcg-catalog/README.md
git commit -m "feat(worker): GET /api/auth/introspect — identidade da sessão sess_ para o coldigom-api, sem renovar"
```

---

### Task 2: `requireAppUser` no coldigom-api

**Repo:** `../coldigom`, diretório `api`.

**Files:**
- Modify: `src/env.ts`
- Modify: `wrangler.toml` (`[vars] PLPCG_AUTH_URL`)
- Create: `src/appUser.ts`
- Create: `src/__tests__/appUser.test.ts`

**Interfaces:**
- Produces: `export type AppUser = { userId: string; email: string | null; name: string | null }`.
- Produces: `export async function requireAppUser(c: AppContext, next: Next)` — grava `c.set('appUser', user)`; `401 { error: 'unauthorized' }`, `503 { error: 'auth_unavailable' }`, `500 { error: 'Auth not configured' }` sem `PLPCG_AUTH_URL`.
- Produces: `export function resetAppUserCacheForTests()`.

- [ ] **Step 1: Tipos e var**

`src/env.ts` — acrescentar ao `Env`:

```ts
  /** Base do plpcg-catalog (introspecção de `sess_…`). */
  PLPCG_AUTH_URL?: string;
  VIRUSTOTAL_API_KEY?: string;
  SAFE_BROWSING_API_KEY?: string;
  CONTRIB_SCAN?: Queue<ContribScanMessage>;
```

e a variável de contexto: `export type App = Hono<{ Bindings: Env; Variables: { user: AuthUser; appUser: AppUser } }>;` (import `AppUser` de `./appUser` e `ContribScanMessage` de `./contributions/scan` — como `scan.ts` só existe na Task 8, declare por ora em `env.ts`: `export type ContribScanMessage = { contributionId: string; phase: 'submit' | 'poll'; attempt: number };` e a Task 8 importa daqui). Em `src/middleware.ts`, o `AppContext` ganha `appUser: AppUser` nas `Variables` também.

`wrangler.toml` em `[vars]`: `PLPCG_AUTH_URL = "https://plpcg-catalog.jairofilho79.workers.dev"` (conferir a URL real do Worker com `npx wrangler deployments list` em `workers/plpcg-catalog`; se diferente, usar a real).

- [ ] **Step 2: Teste**

`src/__tests__/appUser.test.ts`:

```ts
import { afterEach, describe, expect, it, vi } from 'vitest';
import { Hono } from 'hono';

import { requireAppUser, resetAppUserCacheForTests, type AppUser } from '../appUser';
import type { Env } from '../env';

function appWith(env: Partial<Env>) {
  const app = new Hono<{ Bindings: Env; Variables: { appUser: AppUser } }>();
  app.get('/quem', requireAppUser, (c) => c.json(c.get('appUser')));
  return (bearer?: string) =>
    app.request('/quem', { headers: bearer ? { authorization: `Bearer ${bearer}` } : {} }, env as Env);
}

afterEach(() => {
  vi.unstubAllGlobals();
  resetAppUserCacheForTests();
});

describe('requireAppUser', () => {
  it('sem PLPCG_AUTH_URL → 500', async () => {
    const res = await appWith({})('sess_x');
    expect(res.status).toBe(500);
  });

  it('sem Bearer ou Bearer que não é sess_ → 401 sem chamar o introspect', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    const pedir = appWith({ PLPCG_AUTH_URL: 'https://auth.test' });
    expect((await pedir()).status).toBe(401);
    expect((await pedir('eyJ.jwt')).status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('introspect 200 → segue com appUser e cacheia por token', async () => {
    const fetchMock = vi.fn(async () =>
      new Response(JSON.stringify({ userId: 'u1', email: 'a@b.c', name: 'Ana', username: 'ana' }), { status: 200 })
    );
    vi.stubGlobal('fetch', fetchMock);
    const pedir = appWith({ PLPCG_AUTH_URL: 'https://auth.test' });
    const res = await pedir('sess_abc');
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ userId: 'u1', email: 'a@b.c', name: 'Ana' });
    await pedir('sess_abc');
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://auth.test/api/auth/introspect');
    expect((init.headers as Record<string, string>).authorization).toBe('Bearer sess_abc');
  });

  it('introspect 401 → 401 e não cacheia', async () => {
    const fetchMock = vi.fn(async () => new Response('{"error":"unauthorized"}', { status: 401 }));
    vi.stubGlobal('fetch', fetchMock);
    const pedir = appWith({ PLPCG_AUTH_URL: 'https://auth.test' });
    expect((await pedir('sess_abc')).status).toBe(401);
    expect((await pedir('sess_abc')).status).toBe(401);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('introspect fora do ar (rede ou 5xx) → 503 auth_unavailable', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => { throw new TypeError('fetch failed'); }));
    const pedir = appWith({ PLPCG_AUTH_URL: 'https://auth.test' });
    const res = await pedir('sess_abc');
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: 'auth_unavailable' });
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/appUser.test.ts`
Expected: falha — módulo `../appUser` não existe.

- [ ] **Step 4: Implementar**

`src/appUser.ts`:

```ts
import type { Context, Next } from 'hono';

import type { Env } from './env';

export type AppUser = { userId: string; email: string | null; name: string | null };

type Ctx = Context<{ Bindings: Env; Variables: { appUser: AppUser } }>;

const CACHE_TTL_MS = 5 * 60 * 1000;
const SESSION_PREFIX = 'sess_';

/** Cache por isolate: cada pedido da app não pode custar uma ida ao plpcg-catalog. */
let cache = new Map<string, { user: AppUser; exp: number }>();

export function resetAppUserCacheForTests(): void {
  cache = new Map();
}

async function cacheKey(token: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Autentica o usuário da app PLPCG (token `sess_…` do plpcg-catalog).
 * Só sessão: um id_token do Google vazado não abre contribuição.
 * Introspect indisponível é 503, não 401 — a app mostra «tente de novo»
 * mantendo o formulário, em vez de deslogar a pessoa.
 */
export async function requireAppUser(c: Ctx, next: Next) {
  const base = c.env.PLPCG_AUTH_URL?.trim();
  if (!base) return c.json({ error: 'Auth not configured' }, 500);

  const header = c.req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token.startsWith(SESSION_PREFIX)) return c.json({ error: 'unauthorized' }, 401);

  const key = await cacheKey(token);
  const hit = cache.get(key);
  if (hit && hit.exp > Date.now()) {
    c.set('appUser', hit.user);
    return await next();
  }

  let res: Response;
  try {
    res = await fetch(`${base.replace(/\/$/, '')}/api/auth/introspect`, {
      headers: { authorization: `Bearer ${token}` },
    });
  } catch {
    return c.json({ error: 'auth_unavailable' }, 503);
  }
  if (res.status === 401) return c.json({ error: 'unauthorized' }, 401);
  if (!res.ok) return c.json({ error: 'auth_unavailable' }, 503);

  const body = (await res.json()) as { userId?: string; email?: string | null; name?: string | null };
  if (typeof body.userId !== 'string' || !body.userId) return c.json({ error: 'auth_unavailable' }, 503);
  const user: AppUser = { userId: body.userId, email: body.email ?? null, name: body.name ?? null };
  cache.set(key, { user, exp: Date.now() + CACHE_TTL_MS });
  c.set('appUser', user);
  return await next();
}
```

- [ ] **Step 5: Rodar testes e tsc**

Run: `npx vitest run --pool=threads src/__tests__/appUser.test.ts && npx tsc --noEmit`
Expected: 5 testes passam; tsc limpo.

- [ ] **Step 6: Commit**

```bash
git add api/src/appUser.ts api/src/__tests__/appUser.test.ts api/src/env.ts api/src/middleware.ts api/wrangler.toml
git commit -m "feat(api): requireAppUser — autentica o usuário da app via introspect do plpcg-catalog"
```

---

### Task 3: Schema do payload (`contributions/schema.ts`)

**Repo:** `../coldigom`, `api`.

**Files:**
- Create: `src/contributions/schema.ts`
- Create: `src/__tests__/contributionsSchema.test.ts`

**Interfaces:**
- Produces:

```ts
export const KINDS = ['bug', 'wrong_info', 'content', 'improvement', 'other'] as const;
export type Kind = (typeof KINDS)[number];
export const SUBKINDS: Record<Kind, readonly string[]>;
export const LINK_HOSTS = ['youtube.com', 'www.youtube.com', 'youtu.be', 'drive.google.com', 'docs.google.com'] as const;
export type ContributionPayload = {
  kind: Kind; subkind: string | null;
  target: { source: 'coldigom' | 'plpcg'; praiseId: string | null; materialId: string | null } | null;
  title: string; body: string;
  fields: Record<string, unknown>;
  links: string[];              // já normalizados (https, host permitido)
  device: Record<string, unknown> | null;   // inclui same_device: boolean quando bug
  appRoute: string | null; appVersion: string | null;
};
export type SchemaResult = { ok: true; payload: ContributionPayload } | { ok: false; error: string; detail?: string };
export function parsePayload(raw: unknown): SchemaResult;
export function normalizeLink(url: string): string | null;   // null se host/esquema não permitidos
```

- [ ] **Step 1: Teste**

`src/__tests__/contributionsSchema.test.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { normalizeLink, parsePayload } from '../contributions/schema';

const base = { kind: 'improvement', subkind: 'feature', title: 'Modo escuro', body: 'Seria bom.' };

describe('parsePayload', () => {
  it('aceita o mínimo e preenche defaults', () => {
    const r = parsePayload(base);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.payload).toMatchObject({ kind: 'improvement', subkind: 'feature', links: [], fields: {}, target: null, device: null });
  });

  it('recusa kind, subkind e tamanhos fora do contrato', () => {
    expect(parsePayload({ ...base, kind: 'praise' })).toMatchObject({ ok: false, error: 'invalid_kind' });
    expect(parsePayload({ ...base, subkind: 'ui' })).toMatchObject({ ok: false, error: 'invalid_subkind' });
    expect(parsePayload({ ...base, title: 'x'.repeat(121) })).toMatchObject({ ok: false, error: 'title_too_long' });
    expect(parsePayload({ ...base, body: 'x'.repeat(4001) })).toMatchObject({ ok: false, error: 'body_too_long' });
    expect(parsePayload({ ...base, title: '  ' })).toMatchObject({ ok: false, error: 'title_required' });
  });

  it('bug exige device.same_device booleano', () => {
    const bug = { ...base, kind: 'bug', subkind: 'reader' };
    expect(parsePayload(bug)).toMatchObject({ ok: false, error: 'device_required' });
    expect(parsePayload({ ...bug, device: { platform: 'web' } })).toMatchObject({ ok: false, error: 'device_required' });
    expect(parsePayload({ ...bug, device: { platform: 'web', same_device: false, other_device_note: 'iPad da igreja' } }).ok).toBe(true);
  });

  it('wrong_info/metadata exige field da lista e proposed', () => {
    const wi = { ...base, kind: 'wrong_info', subkind: 'metadata', target: { source: 'coldigom', praiseId: 'p1' } };
    expect(parsePayload({ ...wi, fields: { field: 'cor', current: 'a', proposed: 'b' } })).toMatchObject({ ok: false, error: 'invalid_fields' });
    expect(parsePayload({ ...wi, fields: { field: 'tonality', current: 'Dm', proposed: 'Em' } }).ok).toBe(true);
  });

  it('duplicate exige otherPraiseId e otherSource', () => {
    const d = { ...base, kind: 'wrong_info', subkind: 'duplicate' };
    expect(parsePayload({ ...d, fields: { otherPraiseId: 'p2' } })).toMatchObject({ ok: false, error: 'invalid_fields' });
    expect(parsePayload({ ...d, fields: { otherPraiseId: 'p2', otherSource: 'plpcg' } }).ok).toBe(true);
  });

  it('links: até 5, só hosts permitidos, normalizados', () => {
    const ok = parsePayload({ ...base, links: ['https://youtu.be/abc?si=xyz', 'https://drive.google.com/file/d/1/view?usp=sharing'] });
    expect(ok.ok).toBe(true);
    if (ok.ok) expect(ok.payload.links).toEqual(['https://youtu.be/abc', 'https://drive.google.com/file/d/1/view?usp=sharing']);
    expect(parsePayload({ ...base, links: ['https://evil.example/x'] })).toMatchObject({ ok: false, error: 'link_host_not_allowed' });
    expect(parsePayload({ ...base, links: ['http://youtu.be/abc'] })).toMatchObject({ ok: false, error: 'link_host_not_allowed' });
    expect(parsePayload({ ...base, links: Array(6).fill('https://youtu.be/a') })).toMatchObject({ ok: false, error: 'too_many_links' });
  });

  it('target precisa de source válida', () => {
    expect(parsePayload({ ...base, target: { source: 'x', praiseId: 'p' } })).toMatchObject({ ok: false, error: 'invalid_target' });
  });
});

describe('normalizeLink', () => {
  it('remove utm_* e si, mantém o resto', () => {
    expect(normalizeLink('https://www.youtube.com/watch?v=abc&utm_source=x&t=10')).toBe('https://www.youtube.com/watch?v=abc&t=10');
  });
  it('rejeita esquema e host fora da lista', () => {
    expect(normalizeLink('ftp://youtu.be/a')).toBeNull();
    expect(normalizeLink('https://youtube.com.evil.example/a')).toBeNull();
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsSchema.test.ts`
Expected: módulo inexistente.

- [ ] **Step 3: Implementar**

`src/contributions/schema.ts`:

```ts
/**
 * Contrato do `payload` de POST /api/contributions (spec §3.1 e §4.2).
 * Validação por forma: o servidor não confia em nada que o formulário já
 * checou — o formulário é só conveniência.
 */
export const KINDS = ['bug', 'wrong_info', 'content', 'improvement', 'other'] as const;
export type Kind = (typeof KINDS)[number];

export const SUBKINDS: Record<Kind, readonly string[]> = {
  bug: ['screen', 'reader', 'audio', 'search', 'offline', 'login', 'playlist_live', 'other'],
  wrong_info: ['metadata', 'lyrics', 'wrong_material', 'wrong_kind', 'duplicate'],
  content: ['add_material', 'add_praise', 'replace_material', 'remove'],
  improvement: ['feature', 'behavior'],
  other: [],
};

export const METADATA_FIELDS = ['title', 'number', 'author', 'tonality', 'rhythm', 'category', 'tags'] as const;
export const LINK_HOSTS = ['youtube.com', 'www.youtube.com', 'youtu.be', 'drive.google.com', 'docs.google.com'] as const;
export const SOURCES = ['coldigom', 'plpcg'] as const;

export const MAX_TITLE = 120;
export const MAX_BODY = 4000;
export const MAX_LINKS = 5;

const TRACKING_PARAMS = new Set(['si', 'feature']);

export type ContributionPayload = {
  kind: Kind;
  subkind: string | null;
  target: { source: (typeof SOURCES)[number]; praiseId: string | null; materialId: string | null } | null;
  title: string;
  body: string;
  fields: Record<string, unknown>;
  links: string[];
  device: Record<string, unknown> | null;
  appRoute: string | null;
  appVersion: string | null;
};

export type SchemaResult =
  | { ok: true; payload: ContributionPayload }
  | { ok: false; error: string; detail?: string };

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function optString(v: unknown, max = 512): string | null {
  return typeof v === 'string' && v.trim() && v.length <= max ? v.trim() : null;
}

/** `https` + host permitido; tira parâmetros de rastreio para o hash/dedupe ser estável. */
export function normalizeLink(raw: string): string | null {
  let url: URL;
  try { url = new URL(raw.trim()); } catch { return null; }
  if (url.protocol !== 'https:') return null;
  if (!(LINK_HOSTS as readonly string[]).includes(url.hostname)) return null;
  for (const key of Array.from(url.searchParams.keys())) {
    if (key.startsWith('utm_') || TRACKING_PARAMS.has(key)) url.searchParams.delete(key);
  }
  url.hash = '';
  return url.toString();
}

function validFields(kind: Kind, subkind: string | null, fields: Record<string, unknown>): boolean {
  if (kind === 'wrong_info' && subkind === 'metadata') {
    return (
      typeof fields.field === 'string' &&
      (METADATA_FIELDS as readonly string[]).includes(fields.field) &&
      typeof fields.proposed === 'string' && fields.proposed.trim().length > 0 &&
      (fields.current === undefined || typeof fields.current === 'string')
    );
  }
  if (kind === 'wrong_info' && subkind === 'duplicate') {
    return (
      typeof fields.otherPraiseId === 'string' && fields.otherPraiseId.length > 0 &&
      typeof fields.otherSource === 'string' && (SOURCES as readonly string[]).includes(fields.otherSource)
    );
  }
  if (kind === 'content') {
    return (
      (fields.suggestedKindId === undefined || typeof fields.suggestedKindId === 'string') &&
      (fields.suggestedType === undefined || (typeof fields.suggestedType === 'string' && /^[a-z0-9]{1,16}$/.test(fields.suggestedType)))
    );
  }
  return true;
}

export function parsePayload(raw: unknown): SchemaResult {
  if (!isRecord(raw)) return { ok: false, error: 'invalid_payload' };

  const kind = raw.kind;
  if (typeof kind !== 'string' || !(KINDS as readonly string[]).includes(kind)) return { ok: false, error: 'invalid_kind' };
  const k = kind as Kind;

  let subkind: string | null = null;
  if (raw.subkind != null) {
    if (typeof raw.subkind !== 'string' || !SUBKINDS[k].includes(raw.subkind)) return { ok: false, error: 'invalid_subkind' };
    subkind = raw.subkind;
  } else if (SUBKINDS[k].length > 0) {
    return { ok: false, error: 'invalid_subkind' };
  }

  const title = typeof raw.title === 'string' ? raw.title.trim() : '';
  if (!title) return { ok: false, error: 'title_required' };
  if (title.length > MAX_TITLE) return { ok: false, error: 'title_too_long' };
  const body = typeof raw.body === 'string' ? raw.body.trim() : '';
  if (!body) return { ok: false, error: 'body_required' };
  if (body.length > MAX_BODY) return { ok: false, error: 'body_too_long' };

  let target: ContributionPayload['target'] = null;
  if (raw.target != null) {
    if (!isRecord(raw.target) || typeof raw.target.source !== 'string' || !(SOURCES as readonly string[]).includes(raw.target.source)) {
      return { ok: false, error: 'invalid_target' };
    }
    target = {
      source: raw.target.source as (typeof SOURCES)[number],
      praiseId: optString(raw.target.praiseId),
      materialId: optString(raw.target.materialId),
    };
  }

  const fields = isRecord(raw.fields) ? raw.fields : {};
  if (!validFields(k, subkind, fields)) return { ok: false, error: 'invalid_fields' };

  const links: string[] = [];
  if (raw.links != null) {
    if (!Array.isArray(raw.links)) return { ok: false, error: 'invalid_links' };
    if (raw.links.length > MAX_LINKS) return { ok: false, error: 'too_many_links' };
    for (const item of raw.links) {
      if (typeof item !== 'string') return { ok: false, error: 'invalid_links' };
      const normalized = normalizeLink(item);
      if (!normalized) return { ok: false, error: 'link_host_not_allowed', detail: item };
      links.push(normalized);
    }
  }

  let device: Record<string, unknown> | null = null;
  if (k === 'bug') {
    if (!isRecord(raw.device) || typeof raw.device.same_device !== 'boolean') return { ok: false, error: 'device_required' };
    if (raw.device.same_device === false && !optString(raw.device.other_device_note)) return { ok: false, error: 'device_required' };
    device = raw.device;
  } else if (isRecord(raw.device)) {
    device = raw.device;
  }

  return {
    ok: true,
    payload: {
      kind: k, subkind, target, title, body, fields, links, device,
      appRoute: optString(raw.appRoute, 1024),
      appVersion: optString(raw.appVersion, 64),
    },
  };
}
```

- [ ] **Step 4: Rodar e passar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsSchema.test.ts && npx tsc --noEmit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/src/contributions/schema.ts api/src/__tests__/contributionsSchema.test.ts
git commit -m "feat(api): schema do payload de contribuições — kinds, subkinds, fields, links e device"
```

---

### Task 4: Magic bytes (`sniff.ts`) e checagem estrutural (`structural.ts`)

**Repo:** `../coldigom`, `api`.

**Files:**
- Create: `src/contributions/sniff.ts`
- Create: `src/contributions/structural.ts`
- Create: `src/__tests__/contributionsSniff.test.ts`
- Create: `src/__tests__/contributionsStructural.test.ts`

**Interfaces:**
- Produces (`sniff.ts`):

```ts
export const ALLOWED_TYPES = ['pdf', 'mp3', 'jpg', 'png', 'txt', 'chordpro'] as const;
export type DeclaredType = (typeof ALLOWED_TYPES)[number];
export const IMAGE_TYPES: readonly DeclaredType[] = ['jpg', 'png'];
export function declaredTypeFromName(name: string): DeclaredType | null;   // 'jpeg' → 'jpg'
export function sniffType(head: Uint8Array): DeclaredType | 'text' | null;  // 16 bytes bastam; 'text' = UTF-8 sem assinatura binária
export function headMatchesDeclared(head: Uint8Array, declared: DeclaredType): boolean;
export function safeOriginalName(name: string): string;   // sem / \ nem controle, ≤ 200
```

- Produces (`structural.ts`):

```ts
export type StructuralVerdict = { status: 'limpa' | 'suspeita'; detectedType: DeclaredType | null; tokens: string[]; reason?: string };
export function checkStructural(bytes: Uint8Array, declared: DeclaredType): StructuralVerdict;
```

- [ ] **Step 1: Testes**

`src/__tests__/contributionsSniff.test.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { declaredTypeFromName, headMatchesDeclared, safeOriginalName, sniffType } from '../contributions/sniff';

const enc = (s: string) => new TextEncoder().encode(s);

describe('declaredTypeFromName', () => {
  it('mapeia extensões permitidas e normaliza jpeg', () => {
    expect(declaredTypeFromName('a.PDF')).toBe('pdf');
    expect(declaredTypeFromName('foto.jpeg')).toBe('jpg');
    expect(declaredTypeFromName('cifra.chordpro')).toBe('chordpro');
    expect(declaredTypeFromName('x.exe')).toBeNull();
    expect(declaredTypeFromName('semext')).toBeNull();
  });
});

describe('sniffType', () => {
  it('reconhece as assinaturas', () => {
    expect(sniffType(enc('%PDF-1.7\n'))).toBe('pdf');
    expect(sniffType(enc('ID3\x03\x00'))).toBe('mp3');
    expect(sniffType(new Uint8Array([0xff, 0xfb, 0x90, 0x00]))).toBe('mp3');
    expect(sniffType(new Uint8Array([0xff, 0xd8, 0xff, 0xe0]))).toBe('jpg');
    expect(sniffType(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))).toBe('png');
    expect(sniffType(enc('{title: Ainda há tempo}\n'))).toBe('text');
    expect(sniffType(new Uint8Array([0x4d, 0x5a, 0x90, 0x00]))).toBeNull();   // MZ (exe)
    expect(sniffType(enc('<html>'))).toBe('text');
  });
});

describe('headMatchesDeclared', () => {
  it('txt/chordpro aceitam texto; binários exigem a própria assinatura', () => {
    expect(headMatchesDeclared(enc('%PDF-1.4'), 'pdf')).toBe(true);
    expect(headMatchesDeclared(enc('<html>'), 'pdf')).toBe(false);
    expect(headMatchesDeclared(enc('{t: x}'), 'chordpro')).toBe(true);
    expect(headMatchesDeclared(new Uint8Array([0x4d, 0x5a]), 'txt')).toBe(false);
    expect(headMatchesDeclared(enc('a\u0000b'), 'txt')).toBe(false);
  });
});

describe('safeOriginalName', () => {
  it('tira separadores e controle, limita a 200', () => {
    expect(safeOriginalName('../x/\\y.pdf')).toBe('..xy.pdf');
    expect(safeOriginalName('a'.repeat(300) + '.pdf').length).toBe(200);
    expect(safeOriginalName('   ')).toBe('arquivo');
  });
});
```

`src/__tests__/contributionsStructural.test.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { checkStructural } from '../contributions/structural';

const enc = (s: string) => new TextEncoder().encode(s);
const cat = (...parts: Uint8Array[]) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
};

const PDF_LIMPO = enc('%PDF-1.4\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n%%EOF\n');

describe('checkStructural — pdf', () => {
  it('pdf simples é limpo', () => {
    expect(checkStructural(PDF_LIMPO, 'pdf')).toEqual({ status: 'limpa', detectedType: 'pdf', tokens: [] });
  });
  it('tokens perigosos viram suspeita com a lista', () => {
    const v = checkStructural(enc('%PDF-1.4\n<< /OpenAction << /S /JavaScript /JS (app.alert(1)) >> >>'), 'pdf');
    expect(v.status).toBe('suspeita');
    expect(v.tokens).toEqual(['/JavaScript', '/JS', '/OpenAction']);
  });
  it('/Encrypt é suspeita (não dá para inspecionar)', () => {
    expect(checkStructural(enc('%PDF-1.4\n/Encrypt 5 0 R'), 'pdf').tokens).toEqual(['/Encrypt']);
  });
  it('"pdf" que é HTML: assinatura errada', () => {
    const v = checkStructural(enc('<html><script>'), 'pdf');
    expect(v).toMatchObject({ status: 'suspeita', detectedType: null, reason: 'signature_mismatch' });
  });
});

describe('checkStructural — mp3', () => {
  it('ID3 e frame sync são limpos', () => {
    expect(checkStructural(cat(enc('ID3\x03\x00\x00\x00\x00\x00\x0a'), new Uint8Array(10)), 'mp3').status).toBe('limpa');
    expect(checkStructural(new Uint8Array([0xff, 0xfb, 0x90, 0x00, 0, 0]), 'mp3').status).toBe('limpa');
  });
  it('APIC acima de 2 MB é suspeita', () => {
    // Frame ID3v2.3: 'APIC' + tamanho (4 bytes big-endian) + flags(2)
    const size = 3 * 1024 * 1024;
    const header = enc('ID3\x03\x00\x00\x00\x00\x00\x0a');
    const apic = cat(enc('APIC'), new Uint8Array([(size >>> 24) & 0xff, (size >>> 16) & 0xff, (size >>> 8) & 0xff, size & 0xff]), new Uint8Array(2));
    expect(checkStructural(cat(header, apic), 'mp3')).toMatchObject({ status: 'suspeita', reason: 'apic_too_large' });
  });
});

describe('checkStructural — imagens', () => {
  it('png com IEND é limpo; truncado é suspeita', () => {
    const png = cat(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), enc('....IHDR....IEND'), new Uint8Array(4));
    expect(checkStructural(png, 'png').status).toBe('limpa');
    expect(checkStructural(png.slice(0, 12), 'png')).toMatchObject({ status: 'suspeita', reason: 'truncated' });
  });
  it('jpg precisa de FF D9 no fim', () => {
    expect(checkStructural(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0xff, 0xd9]), 'jpg').status).toBe('limpa');
    expect(checkStructural(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00]), 'jpg')).toMatchObject({ status: 'suspeita', reason: 'truncated' });
  });
});

describe('checkStructural — texto', () => {
  it('utf-8 válido é limpo; byte nulo e > 256 KB são suspeita', () => {
    expect(checkStructural(enc('{t: Louvor}\n[C]Ainda'), 'chordpro').status).toBe('limpa');
    expect(checkStructural(enc('a\u0000b'), 'txt')).toMatchObject({ status: 'suspeita', reason: 'binary_in_text' });
    expect(checkStructural(new Uint8Array(256 * 1024 + 1).fill(0x61), 'txt')).toMatchObject({ status: 'suspeita', reason: 'text_too_large' });
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsSniff.test.ts src/__tests__/contributionsStructural.test.ts`
Expected: módulos inexistentes.

- [ ] **Step 3: Implementar `sniff.ts`**

```ts
/**
 * Assinaturas de arquivo. A extensão do nome é só o que a pessoa declarou; a
 * chave do R2 e o Content-Type que o admin vai receber saem daqui.
 */
export const ALLOWED_TYPES = ['pdf', 'mp3', 'jpg', 'png', 'txt', 'chordpro'] as const;
export type DeclaredType = (typeof ALLOWED_TYPES)[number];
export const IMAGE_TYPES: readonly DeclaredType[] = ['jpg', 'png'];

export const CONTENT_TYPES: Record<DeclaredType, string> = {
  pdf: 'application/pdf',
  mp3: 'audio/mpeg',
  jpg: 'image/jpeg',
  png: 'image/png',
  txt: 'text/plain; charset=utf-8',
  chordpro: 'text/plain; charset=utf-8',
};

export function declaredTypeFromName(name: string): DeclaredType | null {
  const ext = name.toLowerCase().match(/\.([a-z0-9]+)$/)?.[1];
  if (!ext) return null;
  if (ext === 'jpeg') return 'jpg';
  return (ALLOWED_TYPES as readonly string[]).includes(ext) ? (ext as DeclaredType) : null;
}

function startsWith(head: Uint8Array, bytes: number[]): boolean {
  return bytes.every((b, i) => head[i] === b);
}

export function looksLikeText(head: Uint8Array): boolean {
  for (const b of head) if (b === 0) return false;
  try {
    new TextDecoder('utf-8', { fatal: true }).decode(head);
    return true;
  } catch {
    return false;
  }
}

/** `null` = assinatura binária desconhecida (exe, zip, office…). */
export function sniffType(head: Uint8Array): DeclaredType | 'text' | null {
  if (startsWith(head, [0x25, 0x50, 0x44, 0x46, 0x2d])) return 'pdf';               // %PDF-
  if (startsWith(head, [0x49, 0x44, 0x33])) return 'mp3';                           // ID3
  if (head[0] === 0xff && (head[1] & 0xe0) === 0xe0 && (head[1] & 0x06) !== 0) return 'mp3'; // frame sync
  if (startsWith(head, [0xff, 0xd8, 0xff])) return 'jpg';
  if (startsWith(head, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'png';
  return looksLikeText(head) ? 'text' : null;
}

export function headMatchesDeclared(head: Uint8Array, declared: DeclaredType): boolean {
  const sniffed = sniffType(head);
  if (declared === 'txt' || declared === 'chordpro') return sniffed === 'text';
  return sniffed === declared;
}

/** Vai para Content-Disposition e para a tela do admin: nada de caminho nem controle. */
export function safeOriginalName(name: string): string {
  // eslint-disable-next-line no-control-regex
  const cleaned = name.replace(/[\\/\u0000-"]/g, '').trim();
  return (cleaned || 'arquivo').slice(0, 200);
}
```

Nota sobre o frame sync: o segundo byte precisa de `111` nos bits altos e `layer ≠ 00` (bits 1–2) — `(b & 0x06) !== 0`. O teste usa `0xfb`.

- [ ] **Step 4: Implementar `structural.ts`**

```ts
import { looksLikeText, sniffType, type DeclaredType } from './sniff';

export type StructuralVerdict = {
  status: 'limpa' | 'suspeita';
  detectedType: DeclaredType | null;
  tokens: string[];
  reason?: string;
};

/**
 * Tokens que uma partitura nunca precisa. `/Encrypt` entra porque um PDF
 * cifrado não dá para inspecionar. Limitação: objetos dentro de `/ObjStm`
 * comprimido não aparecem aqui — o VirusTotal cobre.
 */
const PDF_TOKENS = ['/JavaScript', '/JS', '/Launch', '/OpenAction', '/AA', '/EmbeddedFile', '/RichMedia', '/XFA', '/Encrypt'];
const MAX_TEXT = 256 * 1024;
const MAX_APIC = 2 * 1024 * 1024;

function latin1(bytes: Uint8Array): string {
  // PDF é ASCII/latin-1 na estrutura; decodificar como latin1 nunca lança.
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    s += String.fromCharCode.apply(null, Array.from(bytes.subarray(i, i + 0x8000)));
  }
  return s;
}

function pdfTokens(bytes: Uint8Array): string[] {
  const text = latin1(bytes);
  // `/JS` sozinho não pode casar `/JSx`: exige fronteira (não-letra) depois.
  return PDF_TOKENS.filter((t) => new RegExp(t.replace('/', '\\/') + '(?![A-Za-z])').test(text));
}

function endsWith(bytes: Uint8Array, tail: number[]): boolean {
  if (bytes.length < tail.length) return false;
  return tail.every((b, i) => bytes[bytes.length - tail.length + i] === b);
}

function id3ApicTooLarge(bytes: Uint8Array): boolean {
  if (!(bytes[0] === 0x49 && bytes[1] === 0x44 && bytes[2] === 0x33)) return false;
  const text = latin1(bytes.subarray(0, Math.min(bytes.length, 64 * 1024)));
  let at = text.indexOf('APIC');
  while (at >= 0 && at + 8 <= bytes.length) {
    const size = ((bytes[at + 4] << 24) | (bytes[at + 5] << 16) | (bytes[at + 6] << 8) | bytes[at + 7]) >>> 0;
    if (size > MAX_APIC) return true;
    at = text.indexOf('APIC', at + 4);
  }
  return false;
}

export function checkStructural(bytes: Uint8Array, declared: DeclaredType): StructuralVerdict {
  const head = bytes.subarray(0, 16);
  const sniffed = sniffType(head);
  const detectedType: DeclaredType | null = sniffed === 'text' ? (declared === 'txt' || declared === 'chordpro' ? declared : null) : sniffed;

  const expectText = declared === 'txt' || declared === 'chordpro';
  if ((expectText && sniffed !== 'text') || (!expectText && sniffed !== declared)) {
    return { status: 'suspeita', detectedType, tokens: [], reason: 'signature_mismatch' };
  }

  switch (declared) {
    case 'pdf': {
      const tokens = pdfTokens(bytes);
      return tokens.length ? { status: 'suspeita', detectedType, tokens } : { status: 'limpa', detectedType, tokens: [] };
    }
    case 'mp3':
      if (id3ApicTooLarge(bytes)) return { status: 'suspeita', detectedType, tokens: [], reason: 'apic_too_large' };
      return { status: 'limpa', detectedType, tokens: [] };
    case 'png': {
      const hasIend = latin1(bytes.subarray(Math.max(0, bytes.length - 16))).includes('IEND');
      return hasIend ? { status: 'limpa', detectedType, tokens: [] } : { status: 'suspeita', detectedType, tokens: [], reason: 'truncated' };
    }
    case 'jpg':
      return endsWith(bytes, [0xff, 0xd9]) ? { status: 'limpa', detectedType, tokens: [] } : { status: 'suspeita', detectedType, tokens: [], reason: 'truncated' };
    case 'txt':
    case 'chordpro':
      if (bytes.length > MAX_TEXT) return { status: 'suspeita', detectedType, tokens: [], reason: 'text_too_large' };
      if (!looksLikeText(bytes)) return { status: 'suspeita', detectedType, tokens: [], reason: 'binary_in_text' };
      return { status: 'limpa', detectedType, tokens: [] };
  }
}
```

- [ ] **Step 5: Rodar e passar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsSniff.test.ts src/__tests__/contributionsStructural.test.ts && npx tsc --noEmit`
Expected: PASS. Se o teste de tokens devolver ordem diferente, a ordem esperada é a de `PDF_TOKENS` (filter preserva).

- [ ] **Step 6: Commit**

```bash
git add api/src/contributions/sniff.ts api/src/contributions/structural.ts api/src/__tests__/contributionsSniff.test.ts api/src/__tests__/contributionsStructural.test.ts
git commit -m "feat(api): assinaturas e checagem estrutural dos anexos de contribuição"
```

---

### Task 5: Links + Safe Browsing (`links.ts`)

**Repo:** `../coldigom`, `api`.

**Files:**
- Create: `src/contributions/links.ts`
- Create: `src/__tests__/contributionsLinks.test.ts`

**Interfaces:**
- Consumes: `normalizeLink` da Task 3 (só para reafirmar allowlist).
- Produces:

```ts
export type LinkVerdict = 'clean' | 'unsafe' | 'adiado';
export type LinkChecker = (urls: string[]) => Promise<Record<string, LinkVerdict>>;
export function safeBrowsingChecker(apiKey: string | undefined, fetchFn?: typeof fetch): LinkChecker;
```

- [ ] **Step 1: Teste**

`src/__tests__/contributionsLinks.test.ts`:

```ts
import { describe, expect, it, vi } from 'vitest';

import { safeBrowsingChecker } from '../contributions/links';

const URLS = ['https://youtu.be/a', 'https://drive.google.com/file/d/1/view'];

function fetchWith(status: number, body: unknown) {
  return vi.fn(async () => new Response(JSON.stringify(body), { status })) as unknown as typeof fetch;
}

describe('safeBrowsingChecker', () => {
  it('sem chave → tudo adiado, sem chamar a rede', async () => {
    const f = fetchWith(200, {});
    const out = await safeBrowsingChecker(undefined, f)(URLS);
    expect(out).toEqual({ 'https://youtu.be/a': 'adiado', 'https://drive.google.com/file/d/1/view': 'adiado' });
    expect(f).not.toHaveBeenCalled();
  });

  it('resposta vazia → clean; manda threatTypes e as URLs', async () => {
    const f = fetchWith(200, {});
    const out = await safeBrowsingChecker('k', f)(URLS);
    expect(out).toEqual({ 'https://youtu.be/a': 'clean', 'https://drive.google.com/file/d/1/view': 'clean' });
    const [url, init] = (f as unknown as { mock: { calls: [string, RequestInit][] } }).mock.calls[0];
    expect(url).toBe('https://safebrowsing.googleapis.com/v4/threatMatches:find?key=k');
    const body = JSON.parse(init.body as string);
    expect(body.threatInfo.threatTypes).toEqual(['MALWARE', 'SOCIAL_ENGINEERING', 'UNWANTED_SOFTWARE']);
    expect(body.threatInfo.threatEntries).toEqual(URLS.map((u) => ({ url: u })));
  });

  it('match marca só a URL citada', async () => {
    const f = fetchWith(200, { matches: [{ threatType: 'MALWARE', threat: { url: 'https://youtu.be/a' } }] });
    const out = await safeBrowsingChecker('k', f)(URLS);
    expect(out['https://youtu.be/a']).toBe('unsafe');
    expect(out['https://drive.google.com/file/d/1/view']).toBe('clean');
  });

  it('429/5xx/rede → adiado', async () => {
    expect(await safeBrowsingChecker('k', fetchWith(429, {}))(URLS)).toEqual({ 'https://youtu.be/a': 'adiado', 'https://drive.google.com/file/d/1/view': 'adiado' });
    const boom = vi.fn(async () => { throw new TypeError('fetch failed'); }) as unknown as typeof fetch;
    expect((await safeBrowsingChecker('k', boom)(URLS))['https://youtu.be/a']).toBe('adiado');
  });

  it('lista vazia não chama a rede', async () => {
    const f = fetchWith(200, {});
    expect(await safeBrowsingChecker('k', f)([])).toEqual({});
    expect(f).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsLinks.test.ts`

- [ ] **Step 3: Implementar**

```ts
/**
 * Google Safe Browsing Lookup v4 para os links (YouTube/Drive) de uma
 * contribuição. É a única checagem de link além da allowlist de hosts —
 * o Drive só é baixado na peça D, depois da aprovação.
 */
export type LinkVerdict = 'clean' | 'unsafe' | 'adiado';
export type LinkChecker = (urls: string[]) => Promise<Record<string, LinkVerdict>>;

const ENDPOINT = 'https://safebrowsing.googleapis.com/v4/threatMatches:find';

function all(urls: string[], verdict: LinkVerdict): Record<string, LinkVerdict> {
  return Object.fromEntries(urls.map((u) => [u, verdict]));
}

export function safeBrowsingChecker(apiKey: string | undefined, fetchFn: typeof fetch = fetch): LinkChecker {
  return async (urls) => {
    if (urls.length === 0) return {};
    // Sem chave: em dev é normal; em produção o consumer loga e adia — nunca libera.
    if (!apiKey) return all(urls, 'adiado');
    let res: Response;
    try {
      res = await fetchFn(`${ENDPOINT}?key=${encodeURIComponent(apiKey)}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          client: { clientId: 'coldigom', clientVersion: '1.0' },
          threatInfo: {
            threatTypes: ['MALWARE', 'SOCIAL_ENGINEERING', 'UNWANTED_SOFTWARE'],
            platformTypes: ['ANY_PLATFORM'],
            threatEntryTypes: ['URL'],
            threatEntries: urls.map((url) => ({ url })),
          },
        }),
      });
    } catch {
      return all(urls, 'adiado');
    }
    if (!res.ok) return all(urls, 'adiado');
    const body = (await res.json()) as { matches?: { threat?: { url?: string } }[] };
    const unsafe = new Set((body.matches ?? []).map((m) => m.threat?.url).filter((u): u is string => !!u));
    return Object.fromEntries(urls.map((u) => [u, unsafe.has(u) ? 'unsafe' : 'clean']));
  };
}
```

- [ ] **Step 4: Rodar e passar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsLinks.test.ts && npx tsc --noEmit`

- [ ] **Step 5: Commit**

```bash
git add api/src/contributions/links.ts api/src/__tests__/contributionsLinks.test.ts
git commit -m "feat(api): Safe Browsing para os links das contribuições"
```

---

### Task 6: Cliente VirusTotal (`virustotal.ts`)

**Repo:** `../coldigom`, `api`.

**Files:**
- Create: `src/contributions/virustotal.ts`
- Create: `src/__tests__/contributionsVirustotal.test.ts`

**Interfaces:**
- Produces:

```ts
export type VtStats = { malicious: number; suspicious: number; harmless: number; undetected: number };
export type VtLookup =
  | { kind: 'known'; stats: VtStats }
  | { kind: 'unknown' }
  | { kind: 'adiado'; reason: 'no_api_key' | 'rate_limited' | 'error' };
export type VtSubmit = { kind: 'submitted'; analysisId: string } | { kind: 'adiado'; reason: 'rate_limited' | 'error' };
export type VtPoll = { kind: 'completed'; stats: VtStats } | { kind: 'queued' } | { kind: 'adiado'; reason: 'rate_limited' | 'error' };
export type VirusTotalClient = {
  lookupHash(sha256: string): Promise<VtLookup>;
  submitFile(bytes: Uint8Array, name: string): Promise<VtSubmit>;
  pollAnalysis(analysisId: string): Promise<VtPoll>;
};
export function virusTotalClient(apiKey: string | undefined, fetchFn?: typeof fetch): VirusTotalClient;
export function verdictFromStats(stats: VtStats): 'limpa' | 'suspeita' | 'infectada';
```

- [ ] **Step 1: Teste**

`src/__tests__/contributionsVirustotal.test.ts`:

```ts
import { describe, expect, it, vi } from 'vitest';

import { verdictFromStats, virusTotalClient } from '../contributions/virustotal';

type Call = [string, RequestInit | undefined];
function fetchSeq(responses: { status: number; body?: unknown }[]) {
  const calls: Call[] = [];
  let i = 0;
  const f = vi.fn(async (url: string, init?: RequestInit) => {
    calls.push([url, init]);
    const r = responses[Math.min(i++, responses.length - 1)];
    return new Response(r.body === undefined ? '' : JSON.stringify(r.body), { status: r.status });
  }) as unknown as typeof fetch;
  return { f, calls };
}

const STATS = { malicious: 0, suspicious: 0, harmless: 60, undetected: 10 };

describe('virusTotalClient', () => {
  it('sem chave → adiado no_api_key sem rede', async () => {
    const { f, calls } = fetchSeq([{ status: 200 }]);
    expect(await virusTotalClient(undefined, f).lookupHash('ab')).toEqual({ kind: 'adiado', reason: 'no_api_key' });
    expect(calls.length).toBe(0);
  });

  it('lookupHash: 200 devolve stats; 404 é unknown; 429 é adiado', async () => {
    const known = fetchSeq([{ status: 200, body: { data: { attributes: { last_analysis_stats: STATS } } } }]);
    expect(await virusTotalClient('k', known.f).lookupHash('abc')).toEqual({ kind: 'known', stats: STATS });
    expect(known.calls[0][0]).toBe('https://www.virustotal.com/api/v3/files/abc');
    expect((known.calls[0][1]!.headers as Record<string, string>)['x-apikey']).toBe('k');
    expect(await virusTotalClient('k', fetchSeq([{ status: 404 }]).f).lookupHash('abc')).toEqual({ kind: 'unknown' });
    expect(await virusTotalClient('k', fetchSeq([{ status: 429 }]).f).lookupHash('abc')).toEqual({ kind: 'adiado', reason: 'rate_limited' });
  });

  it('submitFile manda multipart e devolve o analysisId', async () => {
    const { f, calls } = fetchSeq([{ status: 200, body: { data: { type: 'analysis', id: 'an-1' } } }]);
    const out = await virusTotalClient('k', f).submitFile(new Uint8Array([1, 2, 3]), 'x.pdf');
    expect(out).toEqual({ kind: 'submitted', analysisId: 'an-1' });
    expect(calls[0][0]).toBe('https://www.virustotal.com/api/v3/files');
    expect(calls[0][1]!.method).toBe('POST');
    expect(calls[0][1]!.body).toBeInstanceOf(FormData);
  });

  it('pollAnalysis: queued, completed, erro', async () => {
    const c = virusTotalClient('k', fetchSeq([{ status: 200, body: { data: { attributes: { status: 'queued' } } } }]).f);
    expect(await c.pollAnalysis('an-1')).toEqual({ kind: 'queued' });
    const done = virusTotalClient('k', fetchSeq([{ status: 200, body: { data: { attributes: { status: 'completed', stats: STATS } } } }]).f);
    expect(await done.pollAnalysis('an-1')).toEqual({ kind: 'completed', stats: STATS });
    const boom = vi.fn(async () => { throw new TypeError('x'); }) as unknown as typeof fetch;
    expect(await virusTotalClient('k', boom).pollAnalysis('an-1')).toEqual({ kind: 'adiado', reason: 'error' });
  });
});

describe('verdictFromStats', () => {
  it('malicious ≥ 1 infectada; só suspicious suspeita; senão limpa', () => {
    expect(verdictFromStats({ ...STATS, malicious: 1 })).toBe('infectada');
    expect(verdictFromStats({ ...STATS, suspicious: 2 })).toBe('suspeita');
    expect(verdictFromStats(STATS)).toBe('limpa');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsVirustotal.test.ts`

- [ ] **Step 3: Implementar**

```ts
/**
 * VirusTotal API v3 (plano gratuito: 4 req/min, 500/dia, upload ≤ 32 MB).
 * Estratégia: hash primeiro — um PDF que o VT já viu custa um lookup em vez
 * de upload + polling. O contador diário fica no consumer (quota.ts).
 */
const BASE = 'https://www.virustotal.com/api/v3';

export type VtStats = { malicious: number; suspicious: number; harmless: number; undetected: number };
export type VtLookup =
  | { kind: 'known'; stats: VtStats }
  | { kind: 'unknown' }
  | { kind: 'adiado'; reason: 'no_api_key' | 'rate_limited' | 'error' };
export type VtSubmit = { kind: 'submitted'; analysisId: string } | { kind: 'adiado'; reason: 'rate_limited' | 'error' };
export type VtPoll = { kind: 'completed'; stats: VtStats } | { kind: 'queued' } | { kind: 'adiado'; reason: 'rate_limited' | 'error' };

export type VirusTotalClient = {
  lookupHash(sha256: string): Promise<VtLookup>;
  submitFile(bytes: Uint8Array, name: string): Promise<VtSubmit>;
  pollAnalysis(analysisId: string): Promise<VtPoll>;
};

function stats(raw: unknown): VtStats {
  const s = (raw ?? {}) as Partial<VtStats>;
  return { malicious: s.malicious ?? 0, suspicious: s.suspicious ?? 0, harmless: s.harmless ?? 0, undetected: s.undetected ?? 0 };
}

export function verdictFromStats(s: VtStats): 'limpa' | 'suspeita' | 'infectada' {
  if (s.malicious >= 1) return 'infectada';
  if (s.suspicious >= 1) return 'suspeita';
  return 'limpa';
}

export function virusTotalClient(apiKey: string | undefined, fetchFn: typeof fetch = fetch): VirusTotalClient {
  const headers = { 'x-apikey': apiKey ?? '' };
  const adiadoDe = (res: Response): { kind: 'adiado'; reason: 'rate_limited' | 'error' } =>
    ({ kind: 'adiado', reason: res.status === 429 ? 'rate_limited' : 'error' });

  return {
    async lookupHash(sha256) {
      if (!apiKey) return { kind: 'adiado', reason: 'no_api_key' };
      let res: Response;
      try { res = await fetchFn(`${BASE}/files/${sha256}`, { headers }); } catch { return { kind: 'adiado', reason: 'error' }; }
      if (res.status === 404) return { kind: 'unknown' };
      if (!res.ok) return adiadoDe(res);
      const body = (await res.json()) as { data?: { attributes?: { last_analysis_stats?: unknown } } };
      return { kind: 'known', stats: stats(body.data?.attributes?.last_analysis_stats) };
    },
    async submitFile(bytes, name) {
      if (!apiKey) return { kind: 'adiado', reason: 'error' };
      const form = new FormData();
      form.append('file', new Blob([bytes]), name);
      let res: Response;
      try { res = await fetchFn(`${BASE}/files`, { method: 'POST', headers, body: form }); } catch { return { kind: 'adiado', reason: 'error' }; }
      if (!res.ok) return adiadoDe(res);
      const body = (await res.json()) as { data?: { id?: string } };
      return body.data?.id ? { kind: 'submitted', analysisId: body.data.id } : { kind: 'adiado', reason: 'error' };
    },
    async pollAnalysis(analysisId) {
      if (!apiKey) return { kind: 'adiado', reason: 'error' };
      let res: Response;
      try { res = await fetchFn(`${BASE}/analyses/${encodeURIComponent(analysisId)}`, { headers }); } catch { return { kind: 'adiado', reason: 'error' }; }
      if (!res.ok) return adiadoDe(res);
      const body = (await res.json()) as { data?: { attributes?: { status?: string; stats?: unknown } } };
      const attrs = body.data?.attributes;
      if (attrs?.status === 'completed') return { kind: 'completed', stats: stats(attrs.stats) };
      return { kind: 'queued' };
    },
  };
}
```

- [ ] **Step 4: Rodar e passar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsVirustotal.test.ts && npx tsc --noEmit`

- [ ] **Step 5: Commit**

```bash
git add api/src/contributions/virustotal.ts api/src/__tests__/contributionsVirustotal.test.ts
git commit -m "feat(api): cliente VirusTotal v3 — hash primeiro, upload e polling"
```

---

### Task 7: Migration 020, cota, repositório e rotas do usuário

**Repo:** `../coldigom`, `api`.

**Files:**
- Create: `migrations/020_contributions.sql` (SQL exato do spec §3, com o cabeçalho de comentário no estilo da 017 e a linha «Aplicar: `cd api && npx wrangler d1 execute coldigom --remote --file=migrations/020_contributions.sql`»)
- Create: `src/contributions/quota.ts`
- Create: `src/contributions/repo.ts`
- Create: `src/routes/contributions.ts`
- Modify: `src/index.ts` (registrar `registerContributionsRoutes(app)` antes de `registerAssetsRoutes`)
- Create: `src/__tests__/contributionsRoutes.test.ts`

**Interfaces:**
- Consumes: `requireAppUser`/`AppUser` (Task 2), `parsePayload` (Task 3), `declaredTypeFromName`, `headMatchesDeclared`, `safeOriginalName`, `IMAGE_TYPES` (Task 4), `ContribScanMessage` (env.ts).
- Produces (`quota.ts`):

```ts
export const MAX_DAILY_COUNT = 20;
export const MAX_DAILY_BYTES = 200 * 1024 * 1024;
export const VT_DAILY_LIMIT = 450;
export const VT_USER = '_vt';
export function dayUtc(now?: Date): string;                  // 'YYYY-MM-DD'
export function resetAtUtc(now?: Date): string;              // ISO da próxima meia-noite UTC
export async function readQuota(db: D1Database, userId: string, day: string): Promise<{ count: number; bytes: number }>;
export function bumpQuotaStmt(db: D1Database, userId: string, day: string, count: number, bytes: number): D1PreparedStatement;   // INSERT … ON CONFLICT DO UPDATE
```

- Produces (`repo.ts`):

```ts
export type ContributionRow = { id: string; user_id: string; user_email: string; user_name: string | null; kind: string; subkind: string | null; target_source: string | null; target_praise_id: string | null; target_material_id: string | null; title: string; body: string; fields: string | null; links: string | null; device: string | null; app_route: string | null; app_version: string | null; status: string; scan_status: string; scan_report: string | null; decided_at: string | null; decided_by: string | null; decision_note: string | null; created_at: string; updated_at: string };
export type ContributionFileRow = { id: string; contribution_id: string; original_name: string; declared_type: string; detected_type: string | null; size: number; sha256: string; r2_key: string; scan_status: string; scan_detail: string | null; created_at: string };
export function insertContributionStmt(db, row: Omit<ContributionRow, 'created_at' | 'updated_at' | 'decided_at' | 'decided_by' | 'decision_note' | 'scan_report'>): D1PreparedStatement;
export function insertFileStmt(db, row: Omit<ContributionFileRow, 'created_at' | 'detected_type' | 'scan_detail'>): D1PreparedStatement;
export async function getContribution(db, id: string): Promise<ContributionRow | null>;
export async function getContributionForUser(db, id: string, userId: string): Promise<ContributionRow | null>;
export async function listFiles(db, contributionId: string): Promise<ContributionFileRow[]>;
export async function listMine(db, userId: string, cursor: string | null, limit: number): Promise<{ rows: ContributionRow[]; nextCursor: string | null }>;
export function encodeCursor(createdAt: string, id: string): string;   // base64url de `${createdAt}|${id}`
export function decodeCursor(s: string): { createdAt: string; id: string } | null;
export function toUserJson(row: ContributionRow, files: ContributionFileRow[]): object;   // sem device cru, scan_detail, r2_key; links só url
```

- Produces (rotas): `POST /api/contributions`, `GET /api/contributions/mine`, `GET /api/contributions/:id` (spec §4.2).

- [ ] **Step 1: Migration**

Criar `migrations/020_contributions.sql` com o SQL de spec §3 (as três tabelas e os índices, `CREATE TABLE IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`). Cabeçalho:

```sql
-- Contribuições da comunidade (spec coldigui/docs/superpowers/specs/2026-09-17-contribuicoes-comunidade-design.md §3).
--
-- Quem escreve em `status` é o consumer da Queue (recebida → pendente|bloqueada)
-- e o admin (em_analise|aceita|recusada|aplicada). O usuário só insere.
-- Arquivos ficam em quarantine/ no R2 até `scan_status = limpa`.
--
-- Aplicar: cd api && npx wrangler d1 execute coldigom --remote --file=migrations/020_contributions.sql
```

- [ ] **Step 2: Teste das rotas**

`src/__tests__/contributionsRoutes.test.ts` (o fake D1 segue o padrão de `validationFindings.test.ts`; o R2 é um `Map`):

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { resetAppUserCacheForTests } from '../appUser';
import { app } from '../index';

type Linha = Record<string, unknown>;

function fakeDb(opts: { quota?: { count: number; bytes: number }; linhas?: Linha[]; primeira?: Linha | null } = {}) {
  const chamadas: { sql: string; bindings: unknown[] }[] = [];
  const stmt = (sql: string) => ({
    all: vi.fn(async () => ({ results: opts.linhas ?? [] })),
    first: vi.fn(async () => {
      if (/contribution_quota/i.test(sql)) return opts.quota ?? null;
      return opts.primeira === undefined ? (opts.linhas?.[0] ?? null) : opts.primeira;
    }),
    run: vi.fn(async () => ({ meta: { changes: 1 } })),
  });
  const db = {
    prepare: vi.fn((sql: string) => ({ bind: vi.fn((...bindings: unknown[]) => { chamadas.push({ sql, bindings }); return stmt(sql); }), ...stmt(sql) })),
    batch: vi.fn(async (stmts: unknown[]) => stmts.map(() => ({ meta: { changes: 1 } }))),
  };
  return { db, chamadas };
}

function fakeR2() {
  const objetos = new Map<string, Uint8Array>();
  return {
    objetos,
    put: vi.fn(async (key: string, body: ArrayBuffer | Uint8Array | ReadableStream) => {
      const bytes = body instanceof Uint8Array ? body : body instanceof ArrayBuffer ? new Uint8Array(body) : new Uint8Array(await new Response(body).arrayBuffer());
      objetos.set(key, bytes);
    }),
    delete: vi.fn(async (key: string) => { objetos.delete(key); }),
    get: vi.fn(async (key: string) => (objetos.has(key) ? { body: new Blob([objetos.get(key)!]).stream(), arrayBuffer: async () => objetos.get(key)!.buffer } : null)),
  };
}

const enviados: unknown[] = [];
const fila = { send: vi.fn(async (m: unknown) => { enviados.push(m); }) };

function env(db: unknown, r2: unknown) {
  return { DB: db, ASSETS: r2, CONTRIB_SCAN: fila, PLPCG_AUTH_URL: 'https://auth.test', AUTH_JWT_SECRET: '0123456789abcdef0123456789abcdef', AUTH_ALLOWED_EMAILS: '*', WEB_ORIGIN: 'https://web.example' } as never;
}

function multipart(payload: unknown, files: { name: string; bytes: Uint8Array }[] = []) {
  const form = new FormData();
  form.append('payload', JSON.stringify(payload));
  for (const f of files) form.append('file', new Blob([f.bytes]), f.name);
  return form;
}

const BASE = { kind: 'improvement', subkind: 'feature', title: 'Modo escuro', body: 'Seria bom.' };
const PDF = new TextEncoder().encode('%PDF-1.4\n%%EOF');

beforeEach(() => {
  resetAppUserCacheForTests();
  enviados.length = 0;
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ userId: 'u1', email: 'a@b.c', name: 'Ana' }), { status: 200 })));
});
afterEach(() => vi.unstubAllGlobals());

describe('POST /api/contributions', () => {
  it('sem Bearer sess_ → 401', async () => {
    const { db } = fakeDb();
    const res = await app.request('/api/contributions', { method: 'POST', body: multipart(BASE) }, env(db, fakeR2()));
    expect(res.status).toBe(401);
  });

  it('sem arquivo nem link: grava pendente/sem_arquivo e não enfileira', async () => {
    const { db, chamadas } = fakeDb();
    const res = await app.request('/api/contributions', { method: 'POST', headers: { authorization: 'Bearer sess_a' }, body: multipart(BASE) }, env(db, fakeR2()));
    expect(res.status).toBe(201);
    const corpo = (await res.json()) as { id: string; status: string };
    expect(corpo.status).toBe('pendente');
    const insert = chamadas.find((c) => c.sql.startsWith('INSERT INTO contributions'))!;
    expect(insert.bindings).toContain('sem_arquivo');
    expect(insert.bindings).toContain('u1');
    expect(enviados).toEqual([]);
    expect(db.batch).toHaveBeenCalledTimes(1);
  });

  it('com pdf válido: grava em quarantine/, recebida/pendente e enfileira submit', async () => {
    const { db, chamadas } = fakeDb();
    const r2 = fakeR2();
    const res = await app.request('/api/contributions', { method: 'POST', headers: { authorization: 'Bearer sess_a' }, body: multipart({ ...BASE, kind: 'content', subkind: 'add_material' }, [{ name: 'grade.pdf', bytes: PDF }]) }, env(db, r2));
    expect(res.status).toBe(201);
    const { id, status } = (await res.json()) as { id: string; status: string };
    expect(status).toBe('recebida');
    const chaves = Array.from(r2.objetos.keys());
    expect(chaves).toHaveLength(1);
    expect(chaves[0]).toMatch(new RegExp(`^quarantine/${id}/[0-9a-f-]+\\.pdf$`));
    const file = chamadas.find((c) => c.sql.startsWith('INSERT INTO contribution_files'))!;
    expect(file.bindings).toContain('grade.pdf');
    expect(file.bindings).toContain(PDF.length);
    expect(enviados).toEqual([{ contributionId: id, phase: 'submit', attempt: 0 }]);
  });

  it('extensão fora da lista → 400 file_type_not_allowed; assinatura errada → 400 file_type_mismatch', async () => {
    const { db } = fakeDb();
    const h = { authorization: 'Bearer sess_a' };
    let res = await app.request('/api/contributions', { method: 'POST', headers: h, body: multipart(BASE, [{ name: 'x.exe', bytes: PDF }]) }, env(db, fakeR2()));
    expect(res.status).toBe(400);
    expect(await res.json()).toMatchObject({ error: 'file_type_not_allowed' });
    res = await app.request('/api/contributions', { method: 'POST', headers: h, body: multipart(BASE, [{ name: 'x.pdf', bytes: new TextEncoder().encode('<html>') }]) }, env(db, fakeR2()));
    expect(res.status).toBe(400);
    expect(await res.json()).toMatchObject({ error: 'file_type_mismatch', file: 'x.pdf' });
  });

  it('bug só aceita imagens', async () => {
    const { db } = fakeDb();
    const bug = { ...BASE, kind: 'bug', subkind: 'reader', device: { platform: 'web', same_device: true } };
    const res = await app.request('/api/contributions', { method: 'POST', headers: { authorization: 'Bearer sess_a' }, body: multipart(bug, [{ name: 'x.pdf', bytes: PDF }]) }, env(db, fakeR2()));
    expect(res.status).toBe(400);
    expect(await res.json()).toMatchObject({ error: 'file_type_not_allowed' });
  });

  it('mais de 5 arquivos → 400; arquivo > 32 MiB → 413', async () => {
    const { db } = fakeDb();
    const h = { authorization: 'Bearer sess_a' };
    const seis = Array.from({ length: 6 }, (_, i) => ({ name: `a${i}.pdf`, bytes: PDF }));
    expect((await app.request('/api/contributions', { method: 'POST', headers: h, body: multipart(BASE, seis) }, env(db, fakeR2()))).status).toBe(400);
    const grande = new Uint8Array(32 * 1024 * 1024 + 1);
    grande.set(PDF, 0);
    const res = await app.request('/api/contributions', { method: 'POST', headers: h, body: multipart(BASE, [{ name: 'g.pdf', bytes: grande }]) }, env(db, fakeR2()));
    expect(res.status).toBe(413);
  });

  it('cota estourada → 429 com resetAt', async () => {
    const { db } = fakeDb({ quota: { count: 20, bytes: 0 } });
    const res = await app.request('/api/contributions', { method: 'POST', headers: { authorization: 'Bearer sess_a' }, body: multipart(BASE) }, env(db, fakeR2()));
    expect(res.status).toBe(429);
    expect(await res.json()).toMatchObject({ error: 'quota_exceeded', resetAt: expect.stringMatching(/T00:00:00/) });
  });

  it('payload inválido → 400 com o erro do schema', async () => {
    const { db } = fakeDb();
    const res = await app.request('/api/contributions', { method: 'POST', headers: { authorization: 'Bearer sess_a' }, body: multipart({ ...BASE, kind: 'nope' }) }, env(db, fakeR2()));
    expect(res.status).toBe(400);
    expect(await res.json()).toMatchObject({ error: 'invalid_kind' });
  });

  it('falha no R2 apaga o que já subiu e responde 500', async () => {
    const { db } = fakeDb();
    const r2 = fakeR2();
    r2.put.mockImplementationOnce(async (key: string, body: Uint8Array) => { r2.objetos.set(key, body); }).mockImplementationOnce(async () => { throw new Error('r2 down'); });
    const res = await app.request('/api/contributions', { method: 'POST', headers: { authorization: 'Bearer sess_a' }, body: multipart(BASE, [{ name: 'a.pdf', bytes: PDF }, { name: 'b.pdf', bytes: PDF }]) }, env(db, r2));
    expect(res.status).toBe(500);
    expect(r2.objetos.size).toBe(0);
    expect(db.batch).not.toHaveBeenCalled();
  });
});

const ROW = { id: 'c1', user_id: 'u1', user_email: 'a@b.c', user_name: 'Ana', kind: 'improvement', subkind: 'feature', target_source: null, target_praise_id: null, target_material_id: null, title: 'T', body: 'B', fields: '{}', links: '[{"url":"https://youtu.be/a","host":"youtu.be","safe_browsing":"clean"}]', device: '{"platform":"web"}', app_route: '/', app_version: '1.0', status: 'pendente', scan_status: 'limpa', scan_report: null, decided_at: null, decided_by: null, decision_note: null, created_at: '2026-09-17 10:00:00', updated_at: '2026-09-17 10:00:00' };

describe('GET /api/contributions/mine e /:id', () => {
  it('mine lista só do usuário, com files e sem campos internos', async () => {
    const { db, chamadas } = fakeDb({ linhas: [ROW] });
    const res = await app.request('/api/contributions/mine', { headers: { authorization: 'Bearer sess_a' } }, env(db, fakeR2()));
    expect(res.status).toBe(200);
    const corpo = (await res.json()) as { data: Linha[]; nextCursor: string | null };
    expect(corpo.data[0]).toMatchObject({ id: 'c1', status: 'pendente', links: ['https://youtu.be/a'] });
    expect(corpo.data[0]).not.toHaveProperty('device');
    expect(corpo.data[0]).not.toHaveProperty('scan_report');
    const lista = chamadas.find((c) => c.sql.includes('FROM contributions') && c.sql.includes('ORDER BY'))!;
    expect(lista.sql).toContain('user_id = ?');
    expect(lista.bindings[0]).toBe('u1');
  });

  it(':id de outro usuário → 404', async () => {
    const { db } = fakeDb({ primeira: null });
    const res = await app.request('/api/contributions/c1', { headers: { authorization: 'Bearer sess_a' } }, env(db, fakeR2()));
    expect(res.status).toBe(404);
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsRoutes.test.ts`
Expected: 404 nas rotas (não registradas) / módulos inexistentes.

- [ ] **Step 4: `quota.ts`**

```ts
export const MAX_DAILY_COUNT = 20;
export const MAX_DAILY_BYTES = 200 * 1024 * 1024;
export const VT_DAILY_LIMIT = 450;
/** Linha reservada de contribution_quota para o contador global do VirusTotal. */
export const VT_USER = '_vt';

export function dayUtc(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}

export function resetAtUtc(now: Date = new Date()): string {
  const next = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
  return next.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export async function readQuota(db: D1Database, userId: string, day: string): Promise<{ count: number; bytes: number }> {
  const row = await db
    .prepare(`SELECT count, bytes FROM contribution_quota WHERE user_id = ? AND day = ?`)
    .bind(userId, day)
    .first<{ count: number; bytes: number }>();
  return row ?? { count: 0, bytes: 0 };
}

export function bumpQuotaStmt(db: D1Database, userId: string, day: string, count: number, bytes: number): D1PreparedStatement {
  return db
    .prepare(
      `INSERT INTO contribution_quota (user_id, day, count, bytes) VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, day) DO UPDATE SET count = count + excluded.count, bytes = bytes + excluded.bytes`
    )
    .bind(userId, day, count, bytes);
}
```

- [ ] **Step 5: `repo.ts`**

```ts
import type { ContributionPayload } from './schema';

export type ContributionRow = { /* … campos da spec §3, todos snake_case, como no Interfaces desta task … */ };
export type ContributionFileRow = { /* idem */ };

export const CONTRIBUTION_COLS = `id, user_id, user_email, user_name, kind, subkind, target_source, target_praise_id, target_material_id, title, body, fields, links, device, app_route, app_version, status, scan_status, scan_report, decided_at, decided_by, decision_note, created_at, updated_at`;

export function insertContributionStmt(db: D1Database, r: { id: string; userId: string; userEmail: string; userName: string | null; payload: ContributionPayload; status: 'recebida' | 'pendente'; scanStatus: 'pendente' | 'sem_arquivo' }): D1PreparedStatement {
  const p = r.payload;
  const links = p.links.map((url) => ({ url, host: new URL(url).hostname, safe_browsing: 'pending' }));
  return db
    .prepare(
      `INSERT INTO contributions (id, user_id, user_email, user_name, kind, subkind, target_source, target_praise_id, target_material_id, title, body, fields, links, device, app_route, app_version, status, scan_status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(r.id, r.userId, r.userEmail, r.userName, p.kind, p.subkind, p.target?.source ?? null, p.target?.praiseId ?? null, p.target?.materialId ?? null, p.title, p.body, JSON.stringify(p.fields), JSON.stringify(links), p.device ? JSON.stringify(p.device) : null, p.appRoute, p.appVersion, r.status, r.scanStatus);
}

export function insertFileStmt(db: D1Database, f: { id: string; contributionId: string; originalName: string; declaredType: string; size: number; sha256: string; r2Key: string }): D1PreparedStatement {
  return db
    .prepare(`INSERT INTO contribution_files (id, contribution_id, original_name, declared_type, size, sha256, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .bind(f.id, f.contributionId, f.originalName, f.declaredType, f.size, f.sha256, f.r2Key);
}

export async function getContribution(db: D1Database, id: string): Promise<ContributionRow | null> {
  return (await db.prepare(`SELECT ${CONTRIBUTION_COLS} FROM contributions WHERE id = ?`).bind(id).first<ContributionRow>()) ?? null;
}

export async function getContributionForUser(db: D1Database, id: string, userId: string): Promise<ContributionRow | null> {
  return (await db.prepare(`SELECT ${CONTRIBUTION_COLS} FROM contributions WHERE id = ? AND user_id = ?`).bind(id, userId).first<ContributionRow>()) ?? null;
}

export async function listFiles(db: D1Database, contributionId: string): Promise<ContributionFileRow[]> {
  const { results } = await db.prepare(`SELECT * FROM contribution_files WHERE contribution_id = ? ORDER BY created_at, id`).bind(contributionId).all<ContributionFileRow>();
  return results ?? [];
}

export function encodeCursor(createdAt: string, id: string): string {
  return btoa(`${createdAt}|${id}`).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function decodeCursor(s: string): { createdAt: string; id: string } | null {
  try {
    const raw = atob(s.replace(/-/g, '+').replace(/_/g, '/'));
    const at = raw.lastIndexOf('|');
    if (at <= 0) return null;
    return { createdAt: raw.slice(0, at), id: raw.slice(at + 1) };
  } catch { return null; }
}

/** Paginação por (created_at, id) desc — estável mesmo com dois envios no mesmo segundo. */
export async function listMine(db: D1Database, userId: string, cursor: string | null, limit: number): Promise<{ rows: ContributionRow[]; nextCursor: string | null }> {
  const c = cursor ? decodeCursor(cursor) : null;
  const where = c ? `user_id = ? AND (created_at < ? OR (created_at = ? AND id < ?))` : `user_id = ?`;
  const bindings = c ? [userId, c.createdAt, c.createdAt, c.id, limit + 1] : [userId, limit + 1];
  const { results } = await db.prepare(`SELECT ${CONTRIBUTION_COLS} FROM contributions WHERE ${where} ORDER BY created_at DESC, id DESC LIMIT ?`).bind(...bindings).all<ContributionRow>();
  const rows = results ?? [];
  const page = rows.slice(0, limit);
  const last = page[page.length - 1];
  return { rows: page, nextCursor: rows.length > limit && last ? encodeCursor(last.created_at, last.id) : null };
}

function parseJson<T>(s: string | null, fallback: T): T {
  if (!s) return fallback;
  try { return JSON.parse(s) as T; } catch { return fallback; }
}

/** O que o próprio usuário vê. Nunca `device` cru, `scan_report`, `scan_detail` nem `r2_key`. */
export function toUserJson(row: ContributionRow, files: ContributionFileRow[]) {
  return {
    id: row.id, kind: row.kind, subkind: row.subkind, title: row.title, body: row.body,
    target: row.target_source ? { source: row.target_source, praiseId: row.target_praise_id, materialId: row.target_material_id } : null,
    fields: parseJson<Record<string, unknown>>(row.fields, {}),
    links: parseJson<{ url: string }[]>(row.links, []).map((l) => l.url),
    status: row.status, decision_note: row.decision_note,
    created_at: row.created_at, updated_at: row.updated_at,
    files: files.map((f) => ({ id: f.id, original_name: f.original_name, size: f.size, scan_status: f.scan_status })),
  };
}
```

(Escrever os dois tipos `ContributionRow`/`ContributionFileRow` por extenso com os campos listados em **Interfaces**.)

- [ ] **Step 6: Rotas**

`src/routes/contributions.ts`:

```ts
import type { App } from '../env';
import { requireAppUser } from '../appUser';
import { declaredTypeFromName, headMatchesDeclared, IMAGE_TYPES, safeOriginalName } from '../contributions/sniff';
import { parsePayload } from '../contributions/schema';
import { bumpQuotaStmt, dayUtc, MAX_DAILY_BYTES, MAX_DAILY_COUNT, readQuota, resetAtUtc } from '../contributions/quota';
import { getContributionForUser, insertContributionStmt, insertFileStmt, listFiles, listMine, toUserJson } from '../contributions/repo';

export const MAX_FILES = 5;
export const MAX_FILE_BYTES = 32 * 1024 * 1024;
const PAGE = 20;

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(d), (b) => b.toString(16).padStart(2, '0')).join('');
}

export function registerContributionsRoutes(app: App) {
  app.post('/api/contributions', requireAppUser, async (c) => {
    const user = c.get('appUser');
    let form: FormData;
    try { form = await c.req.raw.formData(); } catch { return c.json({ error: 'invalid_multipart' }, 400); }

    const rawPayload = form.get('payload');
    if (typeof rawPayload !== 'string') return c.json({ error: 'payload_required' }, 400);
    let parsedJson: unknown;
    try { parsedJson = JSON.parse(rawPayload); } catch { return c.json({ error: 'invalid_payload' }, 400); }
    const parsed = parsePayload(parsedJson);
    if (!parsed.ok) return c.json({ error: parsed.error, detail: parsed.detail }, 400);
    const payload = parsed.payload;

    // Arquivos: validar tudo (forma, tamanho, assinatura) antes de tocar o R2.
    const files = form.getAll('file').filter((f): f is File => f instanceof File);
    if (files.length > MAX_FILES) return c.json({ error: 'too_many_files' }, 400);
    const prepared: { file: File; name: string; type: ReturnType<typeof declaredTypeFromName> & string; bytes: Uint8Array }[] = [];
    let total = 0;
    for (const file of files) {
      const name = safeOriginalName(file.name);
      const type = declaredTypeFromName(name);
      if (!type) return c.json({ error: 'file_type_not_allowed', file: name }, 400);
      if (payload.kind === 'bug' && !IMAGE_TYPES.includes(type)) return c.json({ error: 'file_type_not_allowed', file: name }, 400);
      if (file.size > MAX_FILE_BYTES) return c.json({ error: 'file_too_large', file: name }, 413);
      const bytes = new Uint8Array(await file.arrayBuffer());
      if (!headMatchesDeclared(bytes.subarray(0, 16), type)) return c.json({ error: 'file_type_mismatch', file: name }, 400);
      total += bytes.length;
      prepared.push({ file, name, type, bytes });
    }

    const day = dayUtc();
    const quota = await readQuota(c.env.DB, user.userId, day);
    if (quota.count >= MAX_DAILY_COUNT || quota.bytes + total > MAX_DAILY_BYTES) {
      return c.json({ error: 'quota_exceeded', resetAt: resetAtUtc() }, 429);
    }

    const id = crypto.randomUUID();
    const uploaded: string[] = [];
    const fileStmts = [];
    try {
      for (const p of prepared) {
        const fileId = crypto.randomUUID();
        const key = `quarantine/${id}/${fileId}.${p.type}`;
        await c.env.ASSETS.put(key, p.bytes);
        uploaded.push(key);
        fileStmts.push(insertFileStmt(c.env.DB, { id: fileId, contributionId: id, originalName: p.name, declaredType: p.type, size: p.bytes.length, sha256: await sha256Hex(p.bytes), r2Key: key }));
      }
    } catch (err) {
      // Nunca deixar objeto em quarantine/ sem linha em D1.
      await Promise.all(uploaded.map((k) => c.env.ASSETS.delete(k).catch(() => undefined)));
      console.error(JSON.stringify({ msg: 'contributions.upload_failed', id, err: String(err) }));
      return c.json({ error: 'upload_failed' }, 500);
    }

    const needsScan = prepared.length > 0 || payload.links.length > 0;
    const status = needsScan ? 'recebida' : 'pendente';
    await c.env.DB.batch([
      insertContributionStmt(c.env.DB, { id, userId: user.userId, userEmail: user.email ?? '', userName: user.name, payload, status, scanStatus: needsScan ? 'pendente' : 'sem_arquivo' }),
      ...fileStmts,
      bumpQuotaStmt(c.env.DB, user.userId, day, 1, total),
    ]);
    if (needsScan) {
      if (!c.env.CONTRIB_SCAN) console.error(JSON.stringify({ msg: 'contributions.queue_missing', id }));
      else await c.env.CONTRIB_SCAN.send({ contributionId: id, phase: 'submit', attempt: 0 });
    }
    return c.json({ id, status }, 201);
  });

  app.get('/api/contributions/mine', requireAppUser, async (c) => {
    const user = c.get('appUser');
    const { rows, nextCursor } = await listMine(c.env.DB, user.userId, c.req.query('cursor') ?? null, PAGE);
    const data = [];
    for (const row of rows) data.push(toUserJson(row, await listFiles(c.env.DB, row.id)));
    return c.json({ data, nextCursor });
  });

  app.get('/api/contributions/:id', requireAppUser, async (c) => {
    const user = c.get('appUser');
    const row = await getContributionForUser(c.env.DB, c.req.param('id'), user.userId);
    if (!row) return c.json({ error: 'not_found' }, 404);
    return c.json({ data: toUserJson(row, await listFiles(c.env.DB, row.id)) });
  });
}
```

Registrar em `src/index.ts`: `import { registerContributionsRoutes } from './routes/contributions';` e `registerContributionsRoutes(app);` antes de `registerAssetsRoutes(app)`.

Atenção à ordem das rotas: `/api/contributions/mine` precisa ser registrada **antes** de `/api/contributions/:id` (como está acima).

- [ ] **Step 7: Rodar e passar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsRoutes.test.ts && npx tsc --noEmit && npm run lint`
Expected: PASS. Se o `formData()` do `app.request` falhar por `content-type` ausente, o teste está passando `FormData` direto como `body` — o `Request` gera o boundary sozinho; não definir `content-type` à mão.

- [ ] **Step 8: Commit**

```bash
git add api/migrations/020_contributions.sql api/src/contributions/quota.ts api/src/contributions/repo.ts api/src/routes/contributions.ts api/src/index.ts api/src/__tests__/contributionsRoutes.test.ts
git commit -m "feat(api): POST/GET /api/contributions — quarentena no R2, cota diária e fila de scan"
```

---

### Task 8: Consumer de scan (`scan.ts`), Queue e cron

**Repo:** `../coldigom`, `api`.

**Files:**
- Create: `src/contributions/scan.ts`
- Modify: `src/index.ts` (`queue` despacha por `batch.queue`; `scheduled`)
- Modify: `wrangler.toml` (producer/consumer `contrib-scan`, `[triggers]`)
- Create: `src/__tests__/contributionsScan.test.ts`

**Interfaces:**
- Consumes: `checkStructural` (Task 4), `safeBrowsingChecker` (Task 5), `virusTotalClient`, `verdictFromStats` (Task 6), `readQuota`/`bumpQuotaStmt`/`VT_USER`/`VT_DAILY_LIMIT` (Task 7), `getContribution`/`listFiles` (Task 7), `ContribScanMessage` (env.ts).
- Produces:

```ts
export type ScanDeps = { db: D1Database; r2: R2Bucket; vt: VirusTotalClient; links: LinkChecker; now?: () => Date };
export type ScanOutcome = { kind: 'done'; status: 'pendente' | 'bloqueada' } | { kind: 'retry'; delaySeconds: number; message: ContribScanMessage };
export async function scanContribution(deps: ScanDeps, msg: ContribScanMessage): Promise<ScanOutcome>;
export async function handleContribScanBatch(batch: MessageBatch<ContribScanMessage>, env: Env): Promise<void>;
export async function requeueStaleContributions(env: Env, now?: Date): Promise<{ requeued: number; timedOut: number }>;
```

- [ ] **Step 1: Teste**

`src/__tests__/contributionsScan.test.ts` — usa um D1 falso **com estado** (mapas) para este módulo, já que o consumer lê e escreve várias vezes:

```ts
import { describe, expect, it, vi } from 'vitest';

import { scanContribution, type ScanDeps } from '../contributions/scan';
import type { LinkChecker } from '../contributions/links';
import type { VirusTotalClient } from '../contributions/virustotal';

type Row = Record<string, unknown>;
const enc = (s: string) => new TextEncoder().encode(s);
const PDF = enc('%PDF-1.4\n%%EOF');
const PDF_JS = enc('%PDF-1.4\n/OpenAction /JavaScript');

/** D1 falso com estado: guarda contributions/contribution_files/quota em mapas e aplica UPDATE por regex. */
function statefulDb(contrib: Row, files: Row[]) {
  const contribs = new Map<string, Row>([[contrib.id as string, { ...contrib }]]);
  const fileRows = new Map<string, Row>(files.map((f) => [f.id as string, { ...f }]));
  const quota = new Map<string, { count: number; bytes: number }>();
  const exec = (sql: string, b: unknown[]) => {
    const s = sql.replace(/\s+/g, ' ');
    if (/^SELECT .* FROM contributions WHERE id = \?/.test(s)) return [contribs.get(b[0] as string) ?? null];
    if (/FROM contribution_files WHERE contribution_id = \?/.test(s)) return Array.from(fileRows.values()).filter((f) => f.contribution_id === b[0]);
    if (/FROM contribution_files WHERE sha256 = \? AND scan_status = 'limpa'/.test(s)) return Array.from(fileRows.values()).filter((f) => f.sha256 === b[0] && f.scan_status === 'limpa' && f.id !== b[1]);
    if (/FROM contribution_quota/.test(s)) return [quota.get(`${b[0]}|${b[1]}`) ?? null];
    if (/^INSERT INTO contribution_quota/.test(s)) { const k = `${b[0]}|${b[1]}`; const q = quota.get(k) ?? { count: 0, bytes: 0 }; quota.set(k, { count: q.count + (b[2] as number), bytes: q.bytes + (b[3] as number) }); return []; }
    if (/^UPDATE contribution_files SET/.test(s)) { const id = b[b.length - 1] as string; const cols = [...s.matchAll(/(\w+) = \?/g)].map((m) => m[1]); const row = fileRows.get(id)!; cols.forEach((c, i) => { row[c] = b[i]; }); return []; }
    if (/^UPDATE contributions SET/.test(s)) { const id = b[b.length - 1] as string; const cols = [...s.matchAll(/(\w+) = \?/g)].map((m) => m[1]); const row = contribs.get(id)!; cols.forEach((c, i) => { row[c] = b[i]; }); return []; }
    throw new Error(`SQL não suportado no fake: ${s}`);
  };
  const db = {
    prepare: (sql: string) => ({
      bind: (...b: unknown[]) => ({
        first: async () => exec(sql, b)[0] ?? null,
        all: async () => ({ results: exec(sql, b) }),
        run: async () => { exec(sql, b); return { meta: { changes: 1 } }; },
      }),
    }),
    batch: async (stmts: { run: () => Promise<unknown> }[]) => { for (const st of stmts) await st.run(); return []; },
  } as unknown as D1Database;
  return { db, contribs, fileRows, quota };
}

function r2With(objs: Record<string, Uint8Array>) {
  const store = new Map(Object.entries(objs));
  return {
    store,
    get: vi.fn(async (k: string) => (store.has(k) ? { arrayBuffer: async () => store.get(k)!.buffer.slice(0) } : null)),
    put: vi.fn(async (k: string, body: ArrayBuffer | Uint8Array) => { store.set(k, body instanceof Uint8Array ? body : new Uint8Array(body)); }),
    delete: vi.fn(async (k: string) => { store.delete(k); }),
  } as unknown as R2Bucket & { store: Map<string, Uint8Array> };
}

const vtClean: VirusTotalClient = {
  lookupHash: async () => ({ kind: 'known', stats: { malicious: 0, suspicious: 0, harmless: 5, undetected: 1 } }),
  submitFile: async () => ({ kind: 'submitted', analysisId: 'an-1' }),
  pollAnalysis: async () => ({ kind: 'completed', stats: { malicious: 0, suspicious: 0, harmless: 5, undetected: 1 } }),
};
const linksClean: LinkChecker = async (urls) => Object.fromEntries(urls.map((u) => [u, 'clean' as const]));

const CONTRIB = { id: 'c1', status: 'recebida', scan_status: 'pendente', links: '[]', created_at: '2026-09-17 10:00:00', scan_report: null };
const FILE = { id: 'f1', contribution_id: 'c1', declared_type: 'pdf', sha256: 'h1', r2_key: 'quarantine/c1/f1.pdf', scan_status: 'pendente', scan_detail: null, detected_type: null };
const NOW = () => new Date('2026-09-17T11:00:00Z');

function deps(db: D1Database, r2: R2Bucket, over: Partial<ScanDeps> = {}): ScanDeps {
  return { db, r2, vt: vtClean, links: linksClean, now: NOW, ...over };
}

describe('scanContribution', () => {
  it('pdf limpo + VT conhecido: move para contributions/, pendente/limpa', async () => {
    const { db, contribs, fileRows } = statefulDb(CONTRIB, [FILE]);
    const r2 = r2With({ 'quarantine/c1/f1.pdf': PDF });
    const out = await scanContribution(deps(db, r2), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(out).toEqual({ kind: 'done', status: 'pendente' });
    expect(contribs.get('c1')).toMatchObject({ status: 'pendente', scan_status: 'limpa' });
    expect(fileRows.get('f1')).toMatchObject({ scan_status: 'limpa', detected_type: 'pdf', r2_key: 'contributions/c1/f1.pdf' });
    expect(r2.store.has('contributions/c1/f1.pdf')).toBe(true);
    expect(r2.store.has('quarantine/c1/f1.pdf')).toBe(false);
  });

  it('token perigoso: bloqueada/suspeita, fica em quarentena, VT nem é chamado', async () => {
    const { db, contribs, fileRows } = statefulDb(CONTRIB, [FILE]);
    const r2 = r2With({ 'quarantine/c1/f1.pdf': PDF_JS });
    const lookup = vi.fn(vtClean.lookupHash);
    const out = await scanContribution(deps(db, r2, { vt: { ...vtClean, lookupHash: lookup } }), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(out).toEqual({ kind: 'done', status: 'bloqueada' });
    expect(contribs.get('c1')).toMatchObject({ status: 'bloqueada', scan_status: 'suspeita' });
    expect(JSON.parse(fileRows.get('f1')!.scan_detail as string).structural.tokens).toEqual(['/JavaScript', '/OpenAction']);
    expect(r2.store.has('quarantine/c1/f1.pdf')).toBe(true);
    expect(lookup).not.toHaveBeenCalled();
  });

  it('dedupe: hash já limpo noutro arquivo pula o VT', async () => {
    const { db, fileRows } = statefulDb(CONTRIB, [FILE, { ...FILE, id: 'f0', contribution_id: 'c0', scan_status: 'limpa', detected_type: 'pdf', r2_key: 'contributions/c0/f0.pdf', scan_detail: '{"virustotal":{"sha256":"h1"}}' }]);
    const r2 = r2With({ 'quarantine/c1/f1.pdf': PDF });
    const lookup = vi.fn(vtClean.lookupHash);
    await scanContribution(deps(db, r2, { vt: { ...vtClean, lookupHash: lookup } }), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(lookup).not.toHaveBeenCalled();
    expect(fileRows.get('f1')).toMatchObject({ scan_status: 'limpa' });
  });

  it('VT desconhece o hash: envia, grava analysisId e pede retry de 60 s em poll', async () => {
    const { db, fileRows } = statefulDb(CONTRIB, [FILE]);
    const r2 = r2With({ 'quarantine/c1/f1.pdf': PDF });
    const vt = { ...vtClean, lookupHash: async () => ({ kind: 'unknown' as const }) };
    const out = await scanContribution(deps(db, r2, { vt }), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(out).toEqual({ kind: 'retry', delaySeconds: 60, message: { contributionId: 'c1', phase: 'poll', attempt: 1 } });
    expect(JSON.parse(fileRows.get('f1')!.scan_detail as string).virustotal.analysisId).toBe('an-1');
  });

  it('poll completed malicioso → bloqueada/infectada', async () => {
    const { db, contribs } = statefulDb({ ...CONTRIB, scan_status: 'adiado' }, [{ ...FILE, scan_detail: '{"structural":{"ok":true},"virustotal":{"analysisId":"an-1"}}' }]);
    const r2 = r2With({ 'quarantine/c1/f1.pdf': PDF });
    const vt = { ...vtClean, pollAnalysis: async () => ({ kind: 'completed' as const, stats: { malicious: 3, suspicious: 0, harmless: 1, undetected: 0 } }) };
    const out = await scanContribution(deps(db, r2, { vt }), { contributionId: 'c1', phase: 'poll', attempt: 1 });
    expect(out).toEqual({ kind: 'done', status: 'bloqueada' });
    expect(contribs.get('c1')).toMatchObject({ status: 'bloqueada', scan_status: 'infectada' });
  });

  it('VT 429 → adiado e retry de 15 min; cota diária ≥ 450 → adiado sem chamar', async () => {
    const { db, contribs } = statefulDb(CONTRIB, [FILE]);
    const r2 = r2With({ 'quarantine/c1/f1.pdf': PDF });
    const vt = { ...vtClean, lookupHash: async () => ({ kind: 'adiado' as const, reason: 'rate_limited' as const }) };
    const out = await scanContribution(deps(db, r2, { vt }), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(out).toMatchObject({ kind: 'retry', delaySeconds: 900 });
    expect(contribs.get('c1')).toMatchObject({ scan_status: 'adiado' });

    const s2 = statefulDb(CONTRIB, [FILE]);
    s2.quota.set('_vt|2026-09-17', { count: 450, bytes: 0 });
    const lookup = vi.fn(vtClean.lookupHash);
    const out2 = await scanContribution(deps(s2.db, r2With({ 'quarantine/c1/f1.pdf': PDF }), { vt: { ...vtClean, lookupHash: lookup } }), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(out2).toMatchObject({ kind: 'retry', delaySeconds: 900 });
    expect(lookup).not.toHaveBeenCalled();
  });

  it('link unsafe → bloqueada mesmo sem arquivo', async () => {
    const { db, contribs } = statefulDb({ ...CONTRIB, links: '[{"url":"https://youtu.be/x","host":"youtu.be","safe_browsing":"pending"}]' }, []);
    const links: LinkChecker = async () => ({ 'https://youtu.be/x': 'unsafe' });
    const out = await scanContribution(deps(db, r2With({}), { links }), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(out).toEqual({ kind: 'done', status: 'bloqueada' });
    expect(JSON.parse(contribs.get('c1')!.links as string)[0].safe_browsing).toBe('unsafe');
  });

  it('adiado há mais de 24 h → bloqueada por timeout', async () => {
    const { db, contribs } = statefulDb({ ...CONTRIB, created_at: '2026-09-15 10:00:00' }, [FILE]);
    const vt = { ...vtClean, lookupHash: async () => ({ kind: 'adiado' as const, reason: 'error' as const }) };
    const out = await scanContribution(deps(db, r2With({ 'quarantine/c1/f1.pdf': PDF }), { vt }), { contributionId: 'c1', phase: 'submit', attempt: 5 });
    expect(out).toEqual({ kind: 'done', status: 'bloqueada' });
    expect(JSON.parse(contribs.get('c1')!.scan_report as string).reason).toBe('timeout');
  });

  it('contribuição já decidida pelo scan é no-op', async () => {
    const { db } = statefulDb({ ...CONTRIB, status: 'pendente', scan_status: 'limpa' }, []);
    const out = await scanContribution(deps(db, r2With({})), { contributionId: 'c1', phase: 'submit', attempt: 0 });
    expect(out).toEqual({ kind: 'done', status: 'pendente' });
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsScan.test.ts`

- [ ] **Step 3: Implementar `scan.ts`**

```ts
import type { ContribScanMessage, Env } from '../env';
import { safeBrowsingChecker, type LinkChecker, type LinkVerdict } from './links';
import { bumpQuotaStmt, dayUtc, readQuota, VT_DAILY_LIMIT, VT_USER } from './quota';
import { getContribution, listFiles, type ContributionFileRow, type ContributionRow } from './repo';
import { checkStructural } from './structural';
import type { DeclaredType } from './sniff';
import { verdictFromStats, virusTotalClient, type VirusTotalClient } from './virustotal';

export type ScanDeps = { db: D1Database; r2: R2Bucket; vt: VirusTotalClient; links: LinkChecker; now?: () => Date };
export type ScanOutcome =
  | { kind: 'done'; status: 'pendente' | 'bloqueada' }
  | { kind: 'retry'; delaySeconds: number; message: ContribScanMessage };

const POLL_DELAY = 60;
const BACKOFF_DELAY = 15 * 60;
const MAX_POLLS = 10;
const TIMEOUT_MS = 24 * 60 * 60 * 1000;

type FileScan = { structural?: { ok: boolean; tokens: string[]; reason?: string }; virustotal?: { sha256?: string; analysisId?: string; malicious?: number; suspicious?: number; polls?: number; dedupedFrom?: string }; skipped?: string };

function parseDetail(f: ContributionFileRow): FileScan {
  try { return f.scan_detail ? (JSON.parse(f.scan_detail) as FileScan) : {}; } catch { return {}; }
}

async function updateFile(db: D1Database, id: string, patch: Partial<Pick<ContributionFileRow, 'scan_status' | 'detected_type' | 'r2_key'>> & { scan_detail?: FileScan }) {
  const cols: string[] = []; const vals: unknown[] = [];
  for (const [k, v] of Object.entries(patch)) { cols.push(`${k} = ?`); vals.push(k === 'scan_detail' ? JSON.stringify(v) : v); }
  await db.prepare(`UPDATE contribution_files SET ${cols.join(', ')} WHERE id = ?`).bind(...vals, id).run();
}

async function updateContribution(db: D1Database, id: string, patch: { status?: string; scan_status?: string; scan_report?: unknown; links?: unknown }) {
  const cols: string[] = []; const vals: unknown[] = [];
  for (const [k, v] of Object.entries(patch)) { cols.push(`${k} = ?`); vals.push(k === 'scan_report' || k === 'links' ? JSON.stringify(v) : v); }
  cols.push(`updated_at = datetime('now')`);
  await db.prepare(`UPDATE contributions SET ${cols.join(', ')} WHERE id = ?`).bind(...vals, id).run();
}

function createdAtMs(row: ContributionRow): number {
  return Date.parse(row.created_at.replace(' ', 'T') + (row.created_at.endsWith('Z') ? '' : 'Z'));
}

async function vtBudgetLeft(db: D1Database, now: Date): Promise<boolean> {
  return (await readQuota(db, VT_USER, dayUtc(now))).count < VT_DAILY_LIMIT;
}

async function spendVt(db: D1Database, now: Date) {
  await bumpQuotaStmt(db, VT_USER, dayUtc(now), 1, 0).run();
}

/** Um arquivo: estrutural → dedupe → VT. Devolve o novo scan_status do arquivo. */
async function scanFile(deps: ScanDeps, f: ContributionFileRow, phase: 'submit' | 'poll', now: Date): Promise<'limpa' | 'suspeita' | 'infectada' | 'adiado' | 'queued'> {
  const detail = parseDetail(f);
  if (f.scan_status === 'limpa' || f.scan_status === 'suspeita' || f.scan_status === 'infectada') return f.scan_status;

  if (!detail.structural) {
    const obj = await deps.r2.get(f.r2_key);
    if (!obj) { await updateFile(deps.db, f.id, { scan_status: 'suspeita', scan_detail: { ...detail, structural: { ok: false, tokens: [], reason: 'missing_object' } } }); return 'suspeita'; }
    const bytes = new Uint8Array(await obj.arrayBuffer());
    const v = checkStructural(bytes, f.declared_type as DeclaredType);
    detail.structural = { ok: v.status === 'limpa', tokens: v.tokens, reason: v.reason };
    if (v.status !== 'limpa') { await updateFile(deps.db, f.id, { scan_status: 'suspeita', detected_type: v.detectedType, scan_detail: detail }); return 'suspeita'; }
    await updateFile(deps.db, f.id, { detected_type: v.detectedType, scan_detail: detail });

    // Dedupe: mesmo hash já limpo em outra linha.
    const twin = await deps.db.prepare(`SELECT id, scan_detail FROM contribution_files WHERE sha256 = ? AND scan_status = 'limpa' AND id <> ? LIMIT 1`).bind(f.sha256, f.id).first<{ id: string; scan_detail: string | null }>();
    if (twin) {
      detail.virustotal = { sha256: f.sha256, dedupedFrom: twin.id };
      await updateFile(deps.db, f.id, { scan_status: 'limpa', scan_detail: detail });
      return 'limpa';
    }
  }

  // VirusTotal
  if (!(await vtBudgetLeft(deps.db, now))) return 'adiado';
  if (phase === 'poll' && detail.virustotal?.analysisId) {
    await spendVt(deps.db, now);
    const p = await deps.vt.pollAnalysis(detail.virustotal.analysisId);
    if (p.kind === 'adiado') return 'adiado';
    if (p.kind === 'queued') {
      detail.virustotal.polls = (detail.virustotal.polls ?? 0) + 1;
      await updateFile(deps.db, f.id, { scan_detail: detail });
      return detail.virustotal.polls >= MAX_POLLS ? 'adiado' : 'queued';
    }
    const verdict = verdictFromStats(p.stats);
    detail.virustotal = { ...detail.virustotal, malicious: p.stats.malicious, suspicious: p.stats.suspicious };
    await updateFile(deps.db, f.id, { scan_status: verdict, scan_detail: detail });
    return verdict;
  }
  await spendVt(deps.db, now);
  const l = await deps.vt.lookupHash(f.sha256);
  if (l.kind === 'adiado') { if (l.reason === 'no_api_key') detail.skipped = 'no_api_key'; await updateFile(deps.db, f.id, { scan_detail: detail }); return 'adiado'; }
  if (l.kind === 'known') {
    const verdict = verdictFromStats(l.stats);
    detail.virustotal = { sha256: f.sha256, malicious: l.stats.malicious, suspicious: l.stats.suspicious };
    await updateFile(deps.db, f.id, { scan_status: verdict, scan_detail: detail });
    return verdict;
  }
  const obj = await deps.r2.get(f.r2_key);
  if (!obj) return 'suspeita';
  await spendVt(deps.db, now);
  const s = await deps.vt.submitFile(new Uint8Array(await obj.arrayBuffer()), f.original_name);
  if (s.kind === 'adiado') return 'adiado';
  detail.virustotal = { sha256: f.sha256, analysisId: s.analysisId, polls: 0 };
  await updateFile(deps.db, f.id, { scan_detail: detail });
  return 'queued';
}

export async function scanContribution(deps: ScanDeps, msg: ContribScanMessage): Promise<ScanOutcome> {
  const now = (deps.now ?? (() => new Date()))();
  const row = await getContribution(deps.db, msg.contributionId);
  if (!row) return { kind: 'done', status: 'bloqueada' };
  if (row.status !== 'recebida') return { kind: 'done', status: row.status === 'bloqueada' ? 'bloqueada' : 'pendente' };

  // Links (só na primeira passagem que ainda tem pending).
  let links: { url: string; host: string; safe_browsing: LinkVerdict | 'pending' }[] = [];
  try { links = row.links ? JSON.parse(row.links) : []; } catch { links = []; }
  const pendingUrls = links.filter((l) => l.safe_browsing === 'pending' || l.safe_browsing === 'adiado').map((l) => l.url);
  let linksAdiado = false;
  if (pendingUrls.length) {
    const verdicts = await deps.links(pendingUrls);
    links = links.map((l) => (l.url in verdicts ? { ...l, safe_browsing: verdicts[l.url] } : l));
    linksAdiado = links.some((l) => l.safe_browsing === 'adiado');
    await updateContribution(deps.db, row.id, { links });
  }
  const linkUnsafe = links.some((l) => l.safe_browsing === 'unsafe');

  const files = await listFiles(deps.db, row.id);
  const results: Record<string, Awaited<ReturnType<typeof scanFile>>> = {};
  for (const f of files) results[f.id] = await scanFile(deps, f, msg.phase, now);
  const values = Object.values(results);

  const worst = linkUnsafe ? 'unsafe' : values.includes('infectada') ? 'infectada' : values.includes('suspeita') ? 'suspeita' : null;
  if (worst) {
    const scanStatus = worst === 'unsafe' ? 'suspeita' : worst;
    await updateContribution(deps.db, row.id, { status: 'bloqueada', scan_status: scanStatus, scan_report: { files: results, links, reason: worst === 'unsafe' ? 'link_unsafe' : worst } });
    return { kind: 'done', status: 'bloqueada' };
  }

  const stillQueued = values.includes('queued');
  const adiado = linksAdiado || values.includes('adiado');
  if (stillQueued || adiado) {
    if (now.getTime() - createdAtMs(row) > TIMEOUT_MS) {
      await updateContribution(deps.db, row.id, { status: 'bloqueada', scan_status: 'adiado', scan_report: { files: results, links, reason: 'timeout' } });
      return { kind: 'done', status: 'bloqueada' };
    }
    await updateContribution(deps.db, row.id, { scan_status: 'adiado' });
    if (adiado && !(await vtBudgetLeft(deps.db, now)) ) console.warn(JSON.stringify({ msg: 'contributions.vt_budget_exhausted', id: row.id }));
    return { kind: 'retry', delaySeconds: adiado ? BACKOFF_DELAY : POLL_DELAY, message: { contributionId: row.id, phase: 'poll', attempt: msg.attempt + 1 } };
  }

  // Tudo limpo: sai da quarentena.
  for (const f of files) {
    const dest = f.r2_key.replace(/^quarantine\//, 'contributions/');
    if (dest === f.r2_key) continue;
    const obj = await deps.r2.get(f.r2_key);
    if (obj) { await deps.r2.put(dest, await obj.arrayBuffer()); await deps.r2.delete(f.r2_key); }
    await updateFile(deps.db, f.id, { r2_key: dest });
  }
  await updateContribution(deps.db, row.id, { status: 'pendente', scan_status: 'limpa', scan_report: { files: results, links } });
  return { kind: 'done', status: 'pendente' };
}

export async function handleContribScanBatch(batch: MessageBatch<ContribScanMessage>, env: Env): Promise<void> {
  const deps: ScanDeps = {
    db: env.DB, r2: env.ASSETS,
    vt: virusTotalClient(env.VIRUSTOTAL_API_KEY),
    links: safeBrowsingChecker(env.SAFE_BROWSING_API_KEY),
  };
  if (!env.VIRUSTOTAL_API_KEY || !env.SAFE_BROWSING_API_KEY) {
    console.error(JSON.stringify({ msg: 'contributions.scan.keys_missing', vt: !!env.VIRUSTOTAL_API_KEY, sb: !!env.SAFE_BROWSING_API_KEY }));
  }
  for (const message of batch.messages) {
    try {
      const out = await scanContribution(deps, message.body);
      if (out.kind === 'retry') {
        if (env.CONTRIB_SCAN) { await env.CONTRIB_SCAN.send(out.message, { delaySeconds: out.delaySeconds }); message.ack(); }
        else message.retry({ delaySeconds: out.delaySeconds });
      } else {
        message.ack();
      }
    } catch (err) {
      console.error(JSON.stringify({ msg: 'contributions.scan.error', id: message.body.contributionId, err: String(err) }));
      message.retry({ delaySeconds: BACKOFF_DELAY });
    }
  }
}

/** Cron diário: mensagem perdida (> 6 h em `recebida` sem avanço) volta à fila; > 24 h bloqueia por timeout. */
export async function requeueStaleContributions(env: Env, now: Date = new Date()): Promise<{ requeued: number; timedOut: number }> {
  const sixH = new Date(now.getTime() - 6 * 3600_000).toISOString().replace('T', ' ').slice(0, 19);
  const dayAgo = new Date(now.getTime() - TIMEOUT_MS).toISOString().replace('T', ' ').slice(0, 19);
  const timedOut = await env.DB.prepare(`UPDATE contributions SET status = 'bloqueada', scan_report = json_object('reason', 'timeout'), updated_at = datetime('now') WHERE status = 'recebida' AND created_at < ?`).bind(dayAgo).run();
  const { results } = await env.DB.prepare(`SELECT id FROM contributions WHERE status = 'recebida' AND updated_at < ?`).bind(sixH).all<{ id: string }>();
  let requeued = 0;
  for (const r of results ?? []) {
    if (env.CONTRIB_SCAN) { await env.CONTRIB_SCAN.send({ contributionId: r.id, phase: 'submit', attempt: 0 }); requeued++; }
  }
  return { requeued, timedOut: timedOut.meta.changes ?? 0 };
}
```

Nota: o retry com delay é feito com `CONTRIB_SCAN.send(..., { delaySeconds })` + `ack()` (o `message.retry({ delaySeconds })` também existe, mas re-enviar dá controle sobre `phase`/`attempt`).

- [ ] **Step 4: `index.ts` e `wrangler.toml`**

`src/index.ts`:

```ts
import { handleContribScanBatch, requeueStaleContributions } from './contributions/scan';
import type { ContribScanMessage } from './env';
// …
const worker = {
  fetch: app.fetch.bind(app),
  async queue(batch: MessageBatch<DriveImportQueueMessage | ContribScanMessage>, env: Env) {
    if (batch.queue === 'contrib-scan') return handleContribScanBatch(batch as MessageBatch<ContribScanMessage>, env);
    await handleDriveImportQueueBatch(batch as MessageBatch<DriveImportQueueMessage>, env);
  },
  async scheduled(_event: ScheduledEvent, env: Env) {
    const r = await requeueStaleContributions(env);
    console.log(JSON.stringify({ msg: 'contributions.cron', ...r }));
  },
};
```

`wrangler.toml`:

```toml
[[queues.producers]]
binding = "CONTRIB_SCAN"
queue = "contrib-scan"

[[queues.consumers]]
queue = "contrib-scan"
max_batch_size = 1
max_retries = 10
max_concurrency = 2

[triggers]
crons = ["0 3 * * *"]
```

Conferir com `npx wrangler deploy --dry-run` que os dois consumers e o cron aparecem.

- [ ] **Step 5: Rodar e passar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsScan.test.ts && npx tsc --noEmit && npm run lint`
Expected: PASS. O `index.test.ts` existente continua verde (o `queue` do drive não mudou de comportamento).

- [ ] **Step 6: Commit**

```bash
git add api/src/contributions/scan.ts api/src/index.ts api/wrangler.toml api/src/__tests__/contributionsScan.test.ts
git commit -m "feat(api): consumer contrib-scan — estrutural, Safe Browsing, VirusTotal, quarentena e cron de resgate"
```

---

### Task 9: Rotas admin e documentação

**Repo:** `../coldigom`, `api` (+ README).

**Files:**
- Create: `src/routes/contributionsAdmin.ts`
- Modify: `src/index.ts` (registrar)
- Create: `src/__tests__/contributionsAdmin.test.ts`
- Modify: `README.md` do coldigom (seção «Contribuições da comunidade»)

**Interfaces:**
- Consumes: `requireAuth`, `assertTrustedMutationOrigin` (middleware), `getContribution`, `listFiles`, `CONTRIBUTION_COLS` (Task 7), `CONTENT_TYPES` (Task 4).
- Produces: `GET /api/admin/contributions`, `GET /api/admin/contributions/:id`, `GET /api/admin/contributions/:id/files/:fileId`, `PATCH /api/admin/contributions/:id` (spec §4.2).

- [ ] **Step 1: Teste**

`src/__tests__/contributionsAdmin.test.ts` — mesmo esqueleto de sessão admin (`sessaoValida`, `envAuth`, `pedir`) de `validationFindings.test.ts`, com `ASSETS` falso:

```ts
import { describe, expect, it, vi } from 'vitest';
import { app } from '../index';

const TEST_JWT_SECRET = '0123456789abcdef0123456789abcdef';
const TEST_WEB_ORIGIN = 'https://web.example';
async function sessaoValida() {
  const { SignJWT } = await import('jose');
  return new SignJWT({ email: 'admin@test.com', jti: 'j-c' }).setProtectedHeader({ alg: 'HS256' }).setSubject('sub-admin').setIssuedAt().setExpirationTime('2h').sign(new TextEncoder().encode(TEST_JWT_SECRET));
}
const envAuth = { AUTH_JWT_SECRET: TEST_JWT_SECRET, AUTH_ALLOWED_EMAILS: '*', WEB_ORIGIN: TEST_WEB_ORIGIN };
type Linha = Record<string, unknown>;

function db(opts: { linhas?: Linha[]; primeira?: Linha | null; arquivos?: Linha[]; total?: number } = {}) {
  const chamadas: { sql: string; bindings: unknown[] }[] = [];
  const stmt = (sql: string) => ({
    all: vi.fn(async () => ({ results: /contribution_files/.test(sql) ? (opts.arquivos ?? []) : (opts.linhas ?? []) })),
    first: vi.fn(async () => {
      if (/COUNT\(\*\)/.test(sql)) return { total: opts.total ?? (opts.linhas?.length ?? 0) };
      if (/contribution_files/.test(sql)) return opts.arquivos?.[0] ?? null;
      return opts.primeira === undefined ? (opts.linhas?.[0] ?? null) : opts.primeira;
    }),
    run: vi.fn(async () => ({ meta: { changes: 1 } })),
  });
  return { chamadas, db: { prepare: vi.fn((sql: string) => ({ bind: vi.fn((...bindings: unknown[]) => { chamadas.push({ sql, bindings }); return stmt(sql); }), ...stmt(sql) })), batch: vi.fn(async () => []) } };
}

function r2(objs: Record<string, Uint8Array> = {}) {
  return { get: vi.fn(async (k: string) => (objs[k] ? { body: new Blob([objs[k]]).stream(), size: objs[k].length } : null)) };
}

async function pedir(url: string, init: RequestInit, d: unknown, assets: unknown = r2(), comSessao = true) {
  const headers: Record<string, string> = { 'content-type': 'application/json', origin: TEST_WEB_ORIGIN };
  if (comSessao) headers.cookie = `coldigom_access=${encodeURIComponent(await sessaoValida())}`;
  return app.request(url, { ...init, headers }, { ...envAuth, DB: d, ASSETS: assets } as never);
}

const ROW = { id: 'c1', user_id: 'u1', user_email: 'a@b.c', user_name: 'Ana', kind: 'wrong_info', subkind: 'metadata', target_source: 'coldigom', target_praise_id: 'p1', target_material_id: null, title: 'Tom errado', body: 'É Em', fields: '{"field":"tonality","current":"Dm","proposed":"Em"}', links: '[]', device: null, app_route: '/', app_version: '1.0', status: 'pendente', scan_status: 'sem_arquivo', scan_report: null, decided_at: null, decided_by: null, decision_note: null, created_at: '2026-09-17 10:00:00', updated_at: '2026-09-17 10:00:00' };
const FILE = { id: 'f1', contribution_id: 'c1', original_name: 'grade.pdf', declared_type: 'pdf', detected_type: 'pdf', size: 12, sha256: 'h', r2_key: 'contributions/c1/f1.pdf', scan_status: 'limpa', scan_detail: null, created_at: '2026-09-17 10:00:00' };

describe('GET /api/admin/contributions', () => {
  it('exige sessão admin', async () => {
    expect((await pedir('/api/admin/contributions', {}, db().db, r2(), false)).status).toBe(401);
  });
  it('filtra por status/kind/praise e devolve fields como objeto', async () => {
    const { db: d, chamadas } = db({ linhas: [ROW] });
    const res = await pedir('/api/admin/contributions?status=pendente&kind=wrong_info&praise=p1', {}, d);
    expect(res.status).toBe(200);
    const corpo = (await res.json()) as { data: Linha[] };
    expect(corpo.data[0].fields).toEqual({ field: 'tonality', current: 'Dm', proposed: 'Em' });
    const lista = chamadas.find((c) => c.sql.includes('ORDER BY'))!;
    expect(lista.sql).toContain('status = ?');
    expect(lista.sql).toContain('kind = ?');
    expect(lista.sql).toContain('target_praise_id = ?');
    expect(lista.bindings.slice(0, 3)).toEqual(['pendente', 'wrong_info', 'p1']);
  });
  it('status desconhecido → 400', async () => {
    expect((await pedir('/api/admin/contributions?status=feito', {}, db().db)).status).toBe(400);
  });
});

describe('GET /api/admin/contributions/:id/files/:fileId', () => {
  it('arquivo limpo: stream com Content-Type detectado, nosniff, sandbox, inline', async () => {
    const { db: d } = db({ primeira: ROW, arquivos: [FILE] });
    const res = await pedir('/api/admin/contributions/c1/files/f1', {}, d, r2({ 'contributions/c1/f1.pdf': new TextEncoder().encode('%PDF-1.4 x') }));
    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toBe('application/pdf');
    expect(res.headers.get('x-content-type-options')).toBe('nosniff');
    expect(res.headers.get('content-security-policy')).toBe('sandbox');
    expect(res.headers.get('content-disposition')).toBe('inline; filename="grade.pdf"');
    expect(res.headers.get('cache-control')).toBe('private, no-store');
  });
  it('arquivo não limpo → 409 file_not_clean', async () => {
    const { db: d } = db({ primeira: ROW, arquivos: [{ ...FILE, scan_status: 'suspeita', r2_key: 'quarantine/c1/f1.pdf' }] });
    const res = await pedir('/api/admin/contributions/c1/files/f1', {}, d);
    expect(res.status).toBe(409);
  });
});

describe('PATCH /api/admin/contributions/:id', () => {
  it('grava status, nota, quem e quando', async () => {
    const { db: d, chamadas } = db({ primeira: { ...ROW, status: 'aceita', decision_note: 'ok', decided_by: 'admin@test.com' } });
    const res = await pedir('/api/admin/contributions/c1', { method: 'PATCH', body: JSON.stringify({ status: 'aceita', decision_note: 'ok' }) }, d);
    expect(res.status).toBe(200);
    const up = chamadas.find((c) => c.sql.startsWith('UPDATE contributions'))!;
    expect(up.sql).toContain("decided_at = datetime('now')");
    expect(up.sql).toContain("status IN ('pendente', 'em_analise', 'aceita', 'recusada', 'aplicada')");
    expect(up.bindings).toEqual(['aceita', 'ok', 'admin@test.com', 'c1']);
  });
  it('status fora da lista ou recebida/bloqueada → 400', async () => {
    expect((await pedir('/api/admin/contributions/c1', { method: 'PATCH', body: JSON.stringify({ status: 'bloqueada' }) }, db().db)).status).toBe(400);
    expect((await pedir('/api/admin/contributions/c1', { method: 'PATCH', body: JSON.stringify({ status: 'x' }) }, db().db)).status).toBe(400);
  });
  it('sem Origin confiável → 403', async () => {
    const headers: Record<string, string> = { 'content-type': 'application/json', origin: 'https://outro.example', cookie: `coldigom_access=${encodeURIComponent(await sessaoValida())}` };
    const res = await app.request('/api/admin/contributions/c1', { method: 'PATCH', headers, body: JSON.stringify({ status: 'aceita' }) }, { ...envAuth, DB: db().db, ASSETS: r2() } as never);
    expect(res.status).toBe(403);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run --pool=threads src/__tests__/contributionsAdmin.test.ts`

- [ ] **Step 3: Implementar**

`src/routes/contributionsAdmin.ts`:

```ts
import type { App } from '../env';
import { requireAuth } from '../middleware';
import { CONTENT_TYPES, type DeclaredType } from '../contributions/sniff';
import { CONTRIBUTION_COLS, getContribution, listFiles, type ContributionRow } from '../contributions/repo';
import { KINDS } from '../contributions/schema';

const STATUSES = ['recebida', 'bloqueada', 'pendente', 'em_analise', 'aceita', 'recusada', 'aplicada'] as const;
const DECIDIVEIS = ['em_analise', 'aceita', 'recusada', 'aplicada'] as const;
const PAGE = 50;

function parseJson(s: string | null): unknown {
  if (!s) return null;
  try { return JSON.parse(s); } catch { return s; }
}

/** Visão do admin: tudo, com os JSONs abertos. */
function toAdminJson(row: ContributionRow, files: unknown[]) {
  return { ...row, fields: parseJson(row.fields), links: parseJson(row.links), device: parseJson(row.device), scan_report: parseJson(row.scan_report), files };
}

export function registerContributionsAdminRoutes(app: App) {
  app.get('/api/admin/contributions', requireAuth, async (c) => {
    const status = c.req.query('status'); const kind = c.req.query('kind'); const praise = c.req.query('praise');
    if (status && !(STATUSES as readonly string[]).includes(status)) return c.json({ error: 'invalid_status' }, 400);
    if (kind && !(KINDS as readonly string[]).includes(kind)) return c.json({ error: 'invalid_kind' }, 400);
    const page = Math.max(1, Number(c.req.query('page') ?? '1') || 1);
    const where: string[] = []; const bindings: unknown[] = [];
    if (status) { where.push('status = ?'); bindings.push(status); }
    if (kind) { where.push('kind = ?'); bindings.push(kind); }
    if (praise) { where.push('target_praise_id = ?'); bindings.push(praise); }
    const sqlWhere = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const total = (await c.env.DB.prepare(`SELECT COUNT(*) AS total FROM contributions ${sqlWhere}`).bind(...bindings).first<{ total: number }>())?.total ?? 0;
    const { results } = await c.env.DB.prepare(`SELECT ${CONTRIBUTION_COLS} FROM contributions ${sqlWhere} ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?`).bind(...bindings, PAGE, (page - 1) * PAGE).all<ContributionRow>();
    const data = [];
    for (const row of results ?? []) data.push(toAdminJson(row, await listFiles(c.env.DB, row.id)));
    return c.json({ data, pagination: { page, limit: PAGE, total, totalPages: Math.max(1, Math.ceil(total / PAGE)) } });
  });

  app.get('/api/admin/contributions/:id', requireAuth, async (c) => {
    const row = await getContribution(c.env.DB, c.req.param('id'));
    if (!row) return c.json({ error: 'not_found' }, 404);
    return c.json({ data: toAdminJson(row, await listFiles(c.env.DB, row.id)) });
  });

  app.get('/api/admin/contributions/:id/files/:fileId', requireAuth, async (c) => {
    const row = await getContribution(c.env.DB, c.req.param('id'));
    if (!row) return c.json({ error: 'not_found' }, 404);
    const file = (await listFiles(c.env.DB, row.id)).find((f) => f.id === c.req.param('fileId'));
    if (!file) return c.json({ error: 'not_found' }, 404);
    // Só o que passou pelo scan sai daqui; quarentena nunca é servida.
    if (file.scan_status !== 'limpa' || file.r2_key.startsWith('quarantine/')) return c.json({ error: 'file_not_clean' }, 409);
    const obj = await c.env.ASSETS.get(file.r2_key);
    if (!obj) return c.json({ error: 'not_found' }, 404);
    const type = (file.detected_type ?? file.declared_type) as DeclaredType;
    return new Response(obj.body, {
      status: 200,
      headers: {
        'content-type': CONTENT_TYPES[type] ?? 'application/octet-stream',
        'content-disposition': `inline; filename="${file.original_name.replace(/"/g, '')}"`,
        'x-content-type-options': 'nosniff',
        'content-security-policy': 'sandbox',
        'cache-control': 'private, no-store',
      },
    });
  });

  app.patch('/api/admin/contributions/:id', requireAuth, async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const status = body.status;
    if (typeof status !== 'string' || !(DECIDIVEIS as readonly string[]).includes(status)) {
      return c.json({ error: `Field 'status' must be one of: ${DECIDIVEIS.join(', ')}` }, 400);
    }
    let note: string | null = null;
    if (body.decision_note != null) {
      if (typeof body.decision_note !== 'string') return c.json({ error: "Field 'decision_note' must be a string" }, 400);
      note = body.decision_note.trim() || null;
    }
    const user = c.get('user');
    // recebida/bloqueada são do scan: o admin não decide sobre o que ainda não foi verificado.
    const r = await c.env.DB.prepare(
      `UPDATE contributions SET status = ?, decision_note = ?, decided_by = ?, decided_at = datetime('now'), updated_at = datetime('now')
       WHERE id = ? AND status IN ('pendente', 'em_analise', 'aceita', 'recusada', 'aplicada')`
    ).bind(status, note, user.email, c.req.param('id')).run();
    if (!r.meta.changes) return c.json({ error: 'not_found_or_not_decidable' }, 404);
    const row = await getContribution(c.env.DB, c.req.param('id'));
    return c.json({ data: row ? toAdminJson(row, await listFiles(c.env.DB, row.id)) : null });
  });
}
```

`requireAuth` já chama `assertTrustedMutationOrigin` (403 sem Origin confiável). Registrar em `index.ts` logo após `registerContributionsRoutes(app)`.

- [ ] **Step 4: Rodar tudo**

Run: `npx vitest run --pool=threads --coverage && npx tsc --noEmit && npm run lint`
Expected: suíte inteira verde e thresholds de cobertura respeitados. Se a cobertura subiu, atualizar a catraca em `vitest.config.ts` com os valores medidos (comentário datado, padrão do arquivo).

- [ ] **Step 5: README**

No `README.md` do coldigom (raiz ou `api/`, onde estiverem documentados os endpoints — conferir com `grep -n "validation/findings" README.md api/README.md`), acrescentar a seção:

```markdown
## Contribuições da comunidade

Spec: `coldigui/docs/superpowers/specs/2026-09-17-contribuicoes-comunidade-design.md`.

| Método | Rota | Auth | O quê |
|---|---|---|---|
| `POST` | `/api/contributions` | `sess_…` da app (introspect no plpcg-catalog) | multipart `payload` + `file[]` (≤ 5 × 32 MiB) → quarentena + fila `contrib-scan` |
| `GET` | `/api/contributions/mine`, `/:id` | `sess_…` | Do próprio usuário |
| `GET` | `/api/admin/contributions[?status=&kind=&praise=&page=]`, `/:id` | admin | Fila de revisão |
| `GET` | `/api/admin/contributions/:id/files/:fileId` | admin | Só `scan_status = limpa`; `nosniff` + `CSP: sandbox` |
| `PATCH` | `/api/admin/contributions/:id` | admin + Origin | `{ status: em_analise\|aceita\|recusada\|aplicada, decision_note }` |

Setup (uma vez): `npx wrangler queues create contrib-scan`; `npx wrangler secret put VIRUSTOTAL_API_KEY`; `npx wrangler secret put SAFE_BROWSING_API_KEY`; `PLPCG_AUTH_URL` em `[vars]`; migration `020_contributions.sql`; **lifecycle rule** no bucket `coldigom-assets` apagando o prefixo `quarantine/` após 30 dias (dashboard → R2 → bucket → Settings → Object lifecycle rules). Cron `0 3 * * *` reenfileira `recebida` > 6 h e bloqueia > 24 h.
```

- [ ] **Step 6: Commit**

```bash
git add api/src/routes/contributionsAdmin.ts api/src/index.ts api/src/__tests__/contributionsAdmin.test.ts api/vitest.config.ts README.md
git commit -m "feat(api): rotas admin de contribuições — fila, detalhe, arquivo limpo com sandbox e decisão"
```

---

## Self-review

- **Spec coverage:** §4.1 → Task 1; `requireAppUser` → Task 2; §3.1/§4.2 validação → Tasks 3–4 e 7; §5 passos 0–4, cron, retry/timeout → Task 8; §4.2 admin + §7 headers → Task 9; migration §3 → Task 7; segredos/README/lifecycle → Task 9; deploy §10 → README (Task 9). Cobertura completa das peças A+B do lado servidor.
- **Placeholders:** os tipos `ContributionRow`/`ContributionFileRow` da Task 7 estão listados campo a campo em **Interfaces** e o passo manda escrevê-los por extenso; nenhum "TBD".
- **Type consistency:** `ContribScanMessage` vive em `env.ts` (Task 2) e é importado por Tasks 7–8; `DeclaredType`/`CONTENT_TYPES`/`IMAGE_TYPES` em `sniff.ts` (Task 4) usados por 7–9; `LinkChecker`/`LinkVerdict` (Task 5) e `VirusTotalClient`/`verdictFromStats` (Task 6) usados na 8; `getContribution`/`listFiles`/`CONTRIBUTION_COLS` (Task 7) usados na 8–9.
