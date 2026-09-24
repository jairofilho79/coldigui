# Seções da Coletânea — Plano 1: API do coldigom

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a API do coldigom passa a (1) filtrar por tag pai trazendo os louvores ligados ao pai **e** às subtags, (2) aceitar ligar um louvor a uma tag raiz que tem subtags (criação, `POST /tags` e merge) e (3) aceitar o merge sem `metadata.category`, caso em que a categoria do keeper não muda. É o passo 1 da entrega (spec §6.1), independente do script, do admin web e do app.

**Architecture:** três mudanças pequenas no Worker `coldigom-api`.
- **Resolver:** `resolveTagFilterGroups` (`api/src/praiseQuery.ts`) devolve `[id, ...filhos]` em vez de `filhos ?? [id]`. As três rotas que o usam herdam a correção sem mudar: `GET /api/praises`, `GET /api/praises/filters` e `GET /api/plpcg/praises` (por injeção, `plpcgPraises.ts:139`).
- **Trava de tag pai:** sai das três rotas de escrita em `api/src/routes/praises.ts`. `tagHasChildren` fica sem chamador e é apagado.
- **Merge:** o laço de `metadata` pula a chave `category` ausente, e o `UPDATE` só inclui `category = ?` quando a chave veio.

Os testes novos rodam num **SQLite de verdade** (`src/__tests__/sqliteD1.ts`, `node:sqlite`), como `praiseShortIdRoutes.test.ts`. Os testes de mock que verificavam a recusa passam a verificar a aceitação.

**Tech Stack:** Cloudflare Workers, Hono 4, D1 (SQLite), TypeScript 5, vitest 4 (Node ≥ 22 por causa de `node:sqlite`; local: Node 25).

**Spec:** `/Volumes/SSD 2TB SD/dev/coldigui/docs/superpowers/specs/2026-09-24-secoes-coletanea-subtags-design.md` (§3.1–3.3 e os testes de API de §8).

**Worktree/branch:** repo coldigom, worktree `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea`, branch `feat/secoes-coletanea-subtags`.
- A branch saiu de `origin/develop` @ `5d0f728`. O spec pede `origin/main` @ `e614d43`, mas as duas árvores são idênticas (mesmo tree `8ef3837`), então não há diferença de conteúdo.
- Todos os comandos deste plano rodam com cwd em `<worktree>/api`. Os paths de `git add` são relativos a `api/`.

## Global Constraints

- Resolver: `resolveTagFilterGroups` devolve `[id, ...filhos]` em vez de `filhos ?? [id]` (spec §3.1).
- Ligar praise a tag raiz com filhos passa a ser permitido em `POST /api/praises`, `POST /api/praises/:id/tags` e `POST /api/praises/:keeperId/merge` (spec §3.2).
- A raiz ligada diretamente significa «sem subtag específica» (spec §3.2).
- «Os testes que verificam a recusa passam a verificar a aceitação» (spec §3.2).
- `metadata.category` deixa de ser obrigatório no merge. Ausente significa «não mexe na categoria» (spec §3.3).
- Nada muda em `METADATA_FIELDS` (`api/src/contributions/schema.ts:17`), na chave `categories` de `GET /api/praises/filters`, no `category` emitido pelas leituras, em `sort=category` nem no LIKE por category (spec §3.4).
- Fora deste plano: admin web (`web/src`), `scripts/validate-acervo` e o app coldigui.
- Testes: `npx vitest run <arquivo>` por passo. No fim, `npx vitest run`, `npm run test:coverage` (catraca em `api/vitest.config.ts`: 79 / 75 / 82 / 82), `npx tsc --noEmit` e `npm run lint` (0 erros; os 2 avisos `no-explicit-any` herdados continuam).
- **git como comando plano, com cwd dentro do worktree.** O guard do ambiente recusa `cd <path> && git …` e `git -C <path> …`. Se o cwd não for o worktree, peça ao orquestrador para despachar o subagente com esse cwd.
- **Nunca relate sucesso sem ter rodado os testes** e lido a saída (contagem de `Tests … passed`, sem `×`). O «Expected FAIL» de cada passo 2 também precisa ser observado de verdade.
- Commits em português, um por tarefa, terminando com a linha exata `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Sem push, PR, merge, `wrangler … --remote` ou deploy. Isso fica com o dono.

## Review Focus

1. **Chave `category` ausente × `null` no merge.** `null` continua significando «apagar a categoria». Só a chave **ausente** preserva o valor. Um `COALESCE(?, category)` ou `metaObj.category ?? …` confundiria os dois casos. Testes: Task 3, «com null: apaga a categoria» e «sem a chave: … não mexe».
2. **Louvor ligado ao pai e ao filho ao mesmo tempo** (o caso de `Coletânea` + `Coletânea · Clamor` durante a migração) não pode sair duplicado na lista nem no `total`. Teste: Task 1, «traz os louvores da raiz e os da subtag, sem duplicar» (`nos-dois`, total 4).
3. **Filtro com várias tags continua sendo E entre grupos.** Isso inclui pai e filho juntos, caso em que o filho restringe. A ordem dos grupos se mantém. Testes: Task 1, «duas tags continuam sendo E», «pai e filho juntos: o filho restringe» e `praiseListResilience` «preserva a ordem».
4. **A contagem da faceta e a lista precisam concordar.** `GET /api/praises/filters` já somava pai e filhos (`routes/praises.ts:233-236`); a lista não somava. Também entra aqui a lista legada `/api/plpcg/praises`, que recebe o resolver por injeção. Testes: Task 1, «a contagem da faceta PES é igual ao total filtrado por PES» e «usa o mesmo resolver».
5. **Posição dos binds do `UPDATE` do merge.** O mock de `index.test.ts` (`createMergeMockD1`, «UPDATE praises SET») lê `args[5]` como category e `args[7]` como id. Com a chave presente, o SQL e os binds precisam sair **idênticos** aos de hoje. Além disso, tag inexistente continua barrando o merge antes de qualquer escrita. Testes: Task 3, o `index.test.ts` «merges source into keeper and deletes source» continua verde e «com string: grava a categoria»; Task 2, «tag inexistente continua barrando, antes de qualquer escrita».

---

### Task 1: Resolver de tags devolve o pai e os filhos (§3.1)

**Files:**
- Modify: `api/src/praiseQuery.ts:34-63` (doc e `return` de `resolveTagFilterGroups`)
- Modify: `api/src/__tests__/praiseListResilience.test.ts:88-97` (dois testes do resolver)
- Create: `api/src/__tests__/tagFilterParentUnion.test.ts`

**Interfaces:**
- Consumes: `resolveTagFilterGroups(db, tagIds): Promise<string[][]>`, usado em `routes/praises.ts:59` (`GET /api/praises`), `:150` (injeção em `listPlpcgPraises`) e `:195` (`GET /api/praises/filters`). Também `buildWhereClause` (`praiseQuery.ts:314-321`), que faz um `p.id IN (SELECT praise_id FROM praise_tags WHERE tag_id IN (…))` por grupo, com os grupos ligados por AND.
- Produces: a mesma assinatura. Cada grupo agora é `[id, ...filhos]` e começa sempre pela tag pedida.

- [ ] **Step 1: Write the failing test**

Em `api/src/__tests__/praiseListResilience.test.ts`, troque os dois testes atuais (linhas 88-97):

```ts
  it('troca a tag pelos filhos, e mantém a própria tag quando não tem filho', async () => {
    const { db } = dbTags({ a: ['a1', 'a2'], b: ['b1'], c: [] });
    const grupos = await resolveTagFilterGroups(db, ['a', 'b', 'c']);
    expect(grupos).toEqual([['a1', 'a2'], ['b1'], ['c']]);
  });

  it('preserva a ordem das tags pedidas', async () => {
    const { db } = dbTags({ z: ['z1'], a: ['a1'] });
    expect(await resolveTagFilterGroups(db, ['z', 'a'])).toEqual([['z1'], ['a1']]);
  });
```

por:

```ts
  it('devolve a própria tag e os filhos; sem filho, só ela', async () => {
    // Era `filhos ?? [id]`: o pai sumia do grupo, e filtrar por PES ignorava
    // os louvores ligados direto à raiz (spec seções da Coletânea, F6).
    const { db } = dbTags({ a: ['a1', 'a2'], b: ['b1'], c: [] });
    const grupos = await resolveTagFilterGroups(db, ['a', 'b', 'c']);
    expect(grupos).toEqual([['a', 'a1', 'a2'], ['b', 'b1'], ['c']]);
  });

  it('preserva a ordem das tags pedidas', async () => {
    const { db } = dbTags({ z: ['z1'], a: ['a1'] });
    expect(await resolveTagFilterGroups(db, ['z', 'a'])).toEqual([['z', 'z1'], ['a', 'a1']]);
  });
```

Crie `api/src/__tests__/tagFilterParentUnion.test.ts`:

```ts
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it, vi } from 'vitest';
import { app } from '../index';
import { d1DeSqlite, sqliteComSchema } from './sqliteD1';

/**
 * Filtrar por tag pai traz os louvores ligados ao pai E às subtags
 * (spec 2026-09-24 seções da Coletânea, §3.1 / fato F6).
 *
 * O bug de produção: filtrar por PES trazia só os 8 louvores de «PES · 9.2026»
 * e ignorava os ~237 ligados direto à raiz. SQLite de verdade, porque o que
 * importa aqui é o resultado da consulta, não o texto dela.
 */
function ambiente() {
  const sqlite = sqliteComSchema();
  const env = {
    DB: d1DeSqlite(sqlite),
    ASSETS: { head: vi.fn(async () => null), put: vi.fn(), delete: vi.fn() },
  };
  return { sqlite, env };
}

function tag(sqlite: DatabaseSync, id: string, nome: string, pai: string | null = null) {
  sqlite.prepare('INSERT INTO tags (id, name, parent_id) VALUES (?, ?, ?)').run(id, nome, pai);
}

function louvor(sqlite: DatabaseSync, id: string, numero: string, tags: string[]) {
  sqlite.prepare('INSERT INTO praises (id, name, number) VALUES (?, ?, ?)').run(id, `Louvor ${id}`, numero);
  for (const t of tags) {
    sqlite.prepare('INSERT INTO praise_tags (praise_id, tag_id) VALUES (?, ?)').run(id, t);
  }
}

/**
 * pes (raiz) ─ pes-9 («PES · 9.2026»); avulsos (raiz, sem filho).
 * - na-raiz: só PES
 * - na-sub: só PES · 9.2026
 * - nos-dois: PES e PES · 9.2026 (não pode sair duplicado)
 * - avulso-pes: Avulsos e PES
 * - fora: só Avulsos
 */
function acervo() {
  const { sqlite, env } = ambiente();
  tag(sqlite, 'pes', 'PES');
  tag(sqlite, 'pes-9', '9.2026', 'pes');
  tag(sqlite, 'avulsos', 'Avulsos');
  louvor(sqlite, 'na-raiz', '001', ['pes']);
  louvor(sqlite, 'na-sub', '002', ['pes-9']);
  louvor(sqlite, 'nos-dois', '003', ['pes', 'pes-9']);
  louvor(sqlite, 'avulso-pes', '004', ['avulsos', 'pes']);
  louvor(sqlite, 'fora', '005', ['avulsos']);
  return { sqlite, env };
}

type Lista = { data: { id: string }[]; pagination: { total: number } };

async function listar(env: object, rota: string): Promise<Lista> {
  const res = await app.request(rota, {}, env as never);
  expect(res.status).toBe(200);
  return (await res.json()) as Lista;
}

const ids = (lista: Lista) => lista.data.map((p) => p.id).sort();

describe('GET /api/praises?tags= — tag pai', () => {
  it('traz os louvores da raiz e os da subtag, sem duplicar', async () => {
    const { env } = acervo();
    const lista = await listar(env, '/api/praises?tags=pes');
    expect(ids(lista)).toEqual(['avulso-pes', 'na-raiz', 'na-sub', 'nos-dois']);
    expect(lista.pagination.total).toBe(4);
  });

  it('subtag continua trazendo só a subtag', async () => {
    const { env } = acervo();
    expect(ids(await listar(env, '/api/praises?tags=pes-9'))).toEqual(['na-sub', 'nos-dois']);
  });

  it('tag raiz sem filho continua trazendo só ela', async () => {
    const { env } = acervo();
    expect(ids(await listar(env, '/api/praises?tags=avulsos'))).toEqual(['avulso-pes', 'fora']);
  });

  it('duas tags continuam sendo E: pai (com filhos) E outra raiz', async () => {
    const { env } = acervo();
    expect(ids(await listar(env, '/api/praises?tags=pes,avulsos'))).toEqual(['avulso-pes']);
  });

  it('pai e filho juntos: o filho restringe', async () => {
    const { env } = acervo();
    expect(ids(await listar(env, '/api/praises?tags=pes,pes-9'))).toEqual(['na-sub', 'nos-dois']);
  });
});

describe('GET /api/plpcg/praises?tags= — tag pai', () => {
  it('usa o mesmo resolver: raiz e subtag', async () => {
    const { env } = acervo();
    const lista = await listar(env, '/api/plpcg/praises?tags=pes');
    expect(ids(lista)).toEqual(['avulso-pes', 'na-raiz', 'na-sub', 'nos-dois']);
    expect(lista.pagination.total).toBe(4);
  });
});

describe('GET /api/praises/filters — contagem do pai bate com a lista', () => {
  it('a contagem da faceta PES é igual ao total filtrado por PES', async () => {
    // A faceta já somava pai + filhos; a lista trazia só os filhos. Os dois
    // números precisam concordar, senão o chip promete 4 e a lista mostra 2.
    const { env } = acervo();
    const res = await app.request('/api/praises/filters', {}, env as never);
    expect(res.status).toBe(200);
    const facetas = (await res.json()) as { tags: { id: string; count: number }[] };
    const pes = facetas.tags.find((t) => t.id === 'pes');

    const lista = await listar(env, '/api/praises?tags=pes');
    expect(pes?.count).toBe(lista.pagination.total);
  });
});
```

- [ ] **Step 2: Run it, expect FAIL**

```
npx vitest run src/__tests__/tagFilterParentUnion.test.ts src/__tests__/praiseListResilience.test.ts
```

Esperado: `Tests  6 failed | 9 passed (15)`. Falham:
- em `tagFilterParentUnion`:
  - «traz os louvores da raiz e os da subtag, sem duplicar»: `expected [ 'na-sub', 'nos-dois' ] to deeply equal [ 'avulso-pes', 'na-raiz', …(2) ]`;
  - «duas tags continuam sendo E…»: `expected [] to deeply equal [ 'avulso-pes' ]`;
  - «usa o mesmo resolver…»: mesma mensagem do primeiro;
  - «a contagem da faceta PES…»: `expected 4 to be 2`;
- em `praiseListResilience`: «devolve a própria tag e os filhos…» e «preserva a ordem…».

Os testes «subtag continua…», «tag raiz sem filho…» e «pai e filho juntos…» já passam; eles são guarda de regressão.

- [ ] **Step 3: Minimal implementation**

Em `api/src/praiseQuery.ts`, troque o início do comentário de `resolveTagFilterGroups` (linhas 34-36):

```ts
/**
 * Para cada tag pedida, o grupo de tags que o filtro deve considerar: as
 * subtags dela, ou ela mesma quando não tem subtag.
 *
```

por:

```ts
/**
 * Para cada tag pedida, o grupo de tags que o filtro deve considerar: ela
 * mesma e as subtags dela. Filtrar pelo pai traz os louvores ligados ao pai e
 * aos filhos — a mesma semântica de `catalogTagMatches` no app. Antes o pai era
 * TROCADO pelos filhos, e filtrar por PES ignorava os louvores ligados direto à
 * raiz (spec seções da Coletânea, F6 / §3.1).
 *
```

No mesmo arquivo, troque a linha 62:

```ts
  return tagIds.map((id) => byParent.get(id) ?? [id]);
```

por:

```ts
  return tagIds.map((id) => [id, ...(byParent.get(id) ?? [])]);
```

A consulta (`SELECT id, parent_id FROM tags WHERE parent_id IN (…)`) e o comentário da ordem dos grupos não mudam.

- [ ] **Step 4: Run, expect PASS**

```
npx vitest run src/__tests__/tagFilterParentUnion.test.ts src/__tests__/praiseListResilience.test.ts
```

Esperado: `Tests  15 passed (15)`.

Depois rode a suíte inteira, porque outros testes de mock filtram por tag (`index.test.ts` «should handle tag filter», `tagsAndFilters`, `filtersFacet`):

```
npx vitest run
```

Esperado: `Test Files  61 passed (61)`, sem nenhum `×`.

- [ ] **Step 5: Commit**

```
git add src/praiseQuery.ts src/__tests__/praiseListResilience.test.ts src/__tests__/tagFilterParentUnion.test.ts
```

```
git commit -m "fix(api): filtro por tag pai traz a raiz e as subtags" -m "resolveTagFilterGroups devolvia só os filhos de uma tag pai, e filtrar por PES ignorava os louvores ligados direto à raiz. Agora cada grupo é [pai, ...filhos], a mesma semântica do app e da contagem da faceta." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Fim da trava «parent tag» na criação, no POST /tags e no merge (§3.2)

**Files:**
- Modify: `api/src/routes/praises.ts:23` (import), `:500-502` (POST `/api/praises`), `:678-680` (POST `/api/praises/:id/tags`), `:820-849` (merge: `jaNoKeeper` e a trava)
- Modify: `api/src/praiseQuery.ts:78-81` (apagar `tagHasChildren`, que fica sem chamador)
- Modify: `api/src/__tests__/index.test.ts:2017-2059` (describe `POST /api/praises/:id/tags leaf-only`)
- Modify: `api/src/__tests__/mergeParentTag.test.ts:99-125`
- Create: `api/src/__tests__/parentTagAttach.test.ts`

**Interfaces:**
- Consumes: as tabelas `tags` e `praise_tags` do `schema.sql`. A PK `(praise_id, tag_id)` e o `INSERT OR IGNORE` evitam ligação duplicada.
- Produces: as três rotas aceitam qualquer tag existente, raiz com filhos incluída. Tag inexistente continua recusada, com o mesmo código de hoje: 400 na criação, 404 no `POST /tags`, 400 no merge, sempre antes do lote de escrita. A mensagem `Cannot attach a parent tag; use a subtag` deixa de existir na API. O admin web ainda mapeia essa mensagem em `web/src/services/mensagensDeErro.ts:23`; isso fica para o plano do admin.

- [ ] **Step 1: Write the failing test**

Crie `api/src/__tests__/parentTagAttach.test.ts`:

```ts
import { SignJWT } from 'jose';
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it, vi } from 'vitest';
import { app } from '../index';
import { d1DeSqlite, sqliteComSchema } from './sqliteD1';

/**
 * Ligar um louvor a uma tag raiz é permitido mesmo que ela tenha subtags
 * (spec 2026-09-24 seções da Coletânea, §3.2). A raiz ligada direto quer dizer
 * «sem subtag específica». Sem isso, `Avulsos` deixaria de poder ser marcada
 * depois de ganhar a subtag `Avulsos · GLTM`.
 */
const SEGREDO = '0123456789abcdef0123456789abcdef';
const ORIGEM = 'https://web.example';

async function escrita(method: string, body: object): Promise<RequestInit> {
  const jwt = await new SignJWT({ email: 'admin@test.com', jti: 'j-tag-pai' })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject('sub-admin')
    .setIssuedAt()
    .setExpirationTime('2h')
    .sign(new TextEncoder().encode(SEGREDO));
  return {
    method,
    headers: {
      'content-type': 'application/json',
      origin: ORIGEM,
      cookie: `coldigom_access=${encodeURIComponent(jwt)}`,
    },
    body: JSON.stringify(body),
  };
}

/** Coletânea (raiz) ─ Clamor (subtag); Avulsos (raiz) ─ GLTM (subtag). */
function ambiente() {
  const sqlite = sqliteComSchema();
  const tag = (id: string, nome: string, pai: string | null = null) =>
    sqlite.prepare('INSERT INTO tags (id, name, parent_id) VALUES (?, ?, ?)').run(id, nome, pai);
  tag('coletanea', 'Coletânea');
  tag('clamor', 'Clamor', 'coletanea');
  tag('avulsos', 'Avulsos');
  tag('avulsos-gltm', 'GLTM', 'avulsos');
  const env = {
    DB: d1DeSqlite(sqlite),
    ASSETS: { head: vi.fn(async () => null), put: vi.fn(), delete: vi.fn() },
    AUTH_JWT_SECRET: SEGREDO,
    AUTH_ALLOWED_EMAILS: '*',
    WEB_ORIGIN: ORIGEM,
  };
  return { sqlite, env };
}

function louvor(sqlite: DatabaseSync, id: string, tags: string[] = []) {
  sqlite.prepare('INSERT INTO praises (id, name, number) VALUES (?, ?, ?)').run(id, `Louvor ${id}`, '001');
  for (const t of tags) {
    sqlite.prepare('INSERT INTO praise_tags (praise_id, tag_id) VALUES (?, ?)').run(id, t);
  }
}

function tagsDe(sqlite: DatabaseSync, id: string): string[] {
  return (
    sqlite.prepare('SELECT tag_id FROM praise_tags WHERE praise_id = ? ORDER BY tag_id').all(id) as {
      tag_id: string;
    }[]
  ).map((l) => l.tag_id);
}

describe('tag pai — ligação aceita', () => {
  it('POST /api/praises aceita tag raiz que tem subtag', async () => {
    const { sqlite, env } = ambiente();
    const res = await app.request(
      '/api/praises',
      await escrita('POST', { name: 'Novo', tag_ids: ['coletanea', 'avulsos-gltm'] }),
      env as never,
    );
    expect(res.status).toBe(201);
    const { data } = (await res.json()) as { data: { id: string } };
    expect(tagsDe(sqlite, data.id)).toEqual(['avulsos-gltm', 'coletanea']);
  });

  it('POST /api/praises/:id/tags aceita tag raiz que tem subtag', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'p1', ['avulsos-gltm']);
    const res = await app.request('/api/praises/p1/tags', await escrita('POST', { tag_id: 'avulsos' }), env as never);
    expect(res.status).toBe(200);
    expect(tagsDe(sqlite, 'p1')).toEqual(['avulsos', 'avulsos-gltm']);
  });

  it('POST /api/praises/:id/tags com raiz e subtag da mesma raiz: as duas ficam', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'p1', ['clamor']);
    const res = await app.request('/api/praises/p1/tags', await escrita('POST', { tag_id: 'coletanea' }), env as never);
    expect(res.status).toBe(200);
    expect(tagsDe(sqlite, 'p1')).toEqual(['clamor', 'coletanea']);
  });

  it('merge aceita tag raiz com subtag vinda só do louvor fonte', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'keeper', ['clamor']);
    louvor(sqlite, 'fonte', ['avulsos']);
    const res = await app.request(
      '/api/praises/keeper/merge',
      await escrita('POST', {
        source_praise_id: 'fonte',
        metadata: { name: 'Keeper', number: '001', author: null, rhythm: null, tonality: null, category: null, lyrics: null },
        tag_ids: ['clamor', 'avulsos'],
        material_ids_to_import: [],
      }),
      env as never,
    );
    expect(res.status).toBe(200);
    expect(tagsDe(sqlite, 'keeper')).toEqual(['avulsos', 'clamor']);
    expect(sqlite.prepare('SELECT id FROM praises WHERE id = ?').get('fonte')).toBeUndefined();
  });

  it('tag inexistente continua recusada nas três rotas', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'p1');
    louvor(sqlite, 'fonte');

    const criar = await app.request('/api/praises', await escrita('POST', { name: 'X', tag_ids: ['nao-existe'] }), env as never);
    expect(criar.status).toBe(400);

    const ligar = await app.request('/api/praises/p1/tags', await escrita('POST', { tag_id: 'nao-existe' }), env as never);
    expect(ligar.status).toBe(404);

    const mesclar = await app.request(
      '/api/praises/p1/merge',
      await escrita('POST', {
        source_praise_id: 'fonte',
        metadata: { name: 'P1', number: '001', author: null, rhythm: null, tonality: null, category: null, lyrics: null },
        tag_ids: ['nao-existe'],
        material_ids_to_import: [],
      }),
      env as never,
    );
    expect(mesclar.status).toBe(400);
    expect(sqlite.prepare('SELECT id FROM praises WHERE id = ?').get('fonte')).toBeTruthy();
  });
});
```

Em `api/src/__tests__/index.test.ts`, troque o bloco inteiro das linhas 2017-2059 (de `describe('POST /api/praises/:id/tags leaf-only', () => {` até o `});` que fecha esse describe, logo antes de `describe('POST /api/praises/:keeperId/merge', () => {`). O bloco atual é:

```ts
  describe('POST /api/praises/:id/tags leaf-only', () => {
    const envBase = {
      AUTH_JWT_SECRET: TEST_JWT_SECRET,
      AUTH_ALLOWED_EMAILS: '*',
      WEB_ORIGIN: TEST_WEB_ORIGIN,
    };

    it('rejects attaching a parent that has children', async () => {
      const tags = [
        ...mockTags,
        { id: 'child1', name: '4.2026', parent_id: 'tag1' },
      ];
      const mockDB = {
        prepare: vi.fn((query: string) => ({
          bind: vi.fn((...args: unknown[]) => ({
            run: vi.fn(),
            first: vi.fn(async () => {
              if (query.includes('SELECT id FROM praises')) {
                return { id: mockPraises[0].id };
              }
              if (query.includes('FROM tags WHERE parent_id')) {
                return tags.find((t) => t.parent_id === args[0]) ?? null;
              }
              if (query.includes('FROM tags')) {
                return tags.find((t) => t.id === args[0]) ?? null;
              }
              return null;
            }),
            all: vi.fn(async () => ({ results: [] })),
          })),
        })),
      };

      const res = await app.request(
        `/api/praises/${mockPraises[0].id}/tags`,
        await authRequestInit({ tag_id: 'tag1' }),
        { DB: mockDB, ASSETS: createMockR2(), ...envBase }
      );
      expect(res.status).toBe(400);
      const json = await res.json();
      expect(json.error).toContain('subtag');
    });
  });
```

O novo bloco:

```ts
  describe('POST /api/praises/:id/tags — tag pai', () => {
    const envBase = {
      AUTH_JWT_SECRET: TEST_JWT_SECRET,
      AUTH_ALLOWED_EMAILS: '*',
      WEB_ORIGIN: TEST_WEB_ORIGIN,
    };

    it('accepts attaching a parent that has children', async () => {
      // Era recusado ('Cannot attach a parent tag; use a subtag'). Desde as
      // seções da Coletânea (spec 2026-09-24 §3.2) a raiz ligada direto vale:
      // quer dizer «sem subtag específica».
      const tags = [
        ...mockTags,
        { id: 'child1', name: '4.2026', parent_id: 'tag1' },
      ];
      const inseridas: unknown[][] = [];
      const mockDB = {
        prepare: vi.fn((query: string) => ({
          bind: vi.fn((...args: unknown[]) => ({
            run: vi.fn(async () => {
              if (query.includes('INSERT OR IGNORE INTO praise_tags')) inseridas.push(args);
            }),
            first: vi.fn(async () => {
              if (query.includes('SELECT id FROM praises')) {
                return { id: mockPraises[0].id };
              }
              if (query.includes('FROM praises p') && query.includes('WHERE p.id')) {
                return { ...mockPraises[0], tag_ids: 'tag1' };
              }
              if (query.includes('FROM tags WHERE parent_id')) {
                return tags.find((t) => t.parent_id === args[0]) ?? null;
              }
              if (query.includes('FROM tags')) {
                return tags.find((t) => t.id === args[0]) ?? null;
              }
              return null;
            }),
            all: vi.fn(async () => ({ results: [] })),
          })),
        })),
      };

      const res = await app.request(
        `/api/praises/${mockPraises[0].id}/tags`,
        await authRequestInit({ tag_id: 'tag1' }),
        { DB: mockDB, ASSETS: createMockR2(), ...envBase }
      );
      expect(res.status).toBe(200);
      expect(inseridas).toEqual([[mockPraises[0].id, 'tag1']]);
    });
  });
```

Em `api/src/__tests__/mergeParentTag.test.ts`, troque a linha 99:

```ts
describe('merge — tag pai preexistente', () => {
```

por:

```ts
describe('merge — tag pai', () => {
```

No mesmo arquivo, troque os dois testes das linhas 110-125:

```ts
  it('continua recusando tag pai que ainda não estava no keeper', async () => {
    // Vinda só do louvor fonte, é associação NOVA de tag pai: o merge não pode
    // ser a porta dos fundos para espalhar tag pai em louvor que não tinha.
    const { res, lotes } = await mesclar(['coral'], ['avulsos']);

    expect(res.status).toBe(400);
    expect(lotes).toHaveLength(0);
  });

  it('diz qual tag é a culpada', async () => {
    // 'Cannot attach a parent tag' sem nome nenhum não dava para agir.
    const { res } = await mesclar(['avulsos', 'coral'], ['avulsos']);
    const corpo = (await res.json()) as { error?: string };

    expect(corpo.error).toContain('Coral');
  });
```

por:

```ts
  it('aceita tag pai que ainda não estava no keeper', async () => {
    // Era recusada. Desde as seções da Coletânea (spec 2026-09-24 §3.2), a
    // raiz ligada direto é legítima: quer dizer «sem subtag específica».
    const { res, lotes } = await mesclar(['coral'], ['avulsos']);

    expect(res.status).toBe(200);
    expect(lotes).toHaveLength(1);
    expect(lotes[0]).toContain('INSERT OR IGNORE INTO praise_tags (praise_id, tag_id) VALUES (?, ?)');
  });

  it('tag inexistente continua barrando, antes de qualquer escrita', async () => {
    const { res, lotes } = await mesclar(['avulsos', 'nao-existe'], ['avulsos']);
    const corpo = (await res.json()) as { error?: string };

    expect(res.status).toBe(400);
    expect(corpo.error).toBe('Tag not found');
    expect(lotes).toHaveLength(0);
  });
```

Os testes «não aborta por causa de tag pai que o keeper já tinha» e «deixa passar subtag como sempre» ficam como estão.

- [ ] **Step 2: Run it, expect FAIL**

```
npx vitest run src/__tests__/parentTagAttach.test.ts src/__tests__/index.test.ts src/__tests__/mergeParentTag.test.ts
```

Esperado: `Tests  6 failed | 111 passed (117)`, todos com `AssertionError: expected 400 to be 200` (ou `… to be 201` na criação). Falham:
- em `parentTagAttach`: «POST /api/praises aceita…», os dois «POST /api/praises/:id/tags…» e «merge aceita…»;
- em `index.test`: «accepts attaching a parent that has children»;
- em `mergeParentTag`: «aceita tag pai que ainda não estava no keeper».

Os testes de «tag inexistente» já passam; eles são guarda de regressão.

- [ ] **Step 3: Minimal implementation**

Em `api/src/routes/praises.ts`, faça estas mudanças.

(a) Import (linhas 22-24). Troque:

```ts
  resolveTagFilterGroups,
  tagHasChildren,
  type PraiseResult,
```

por:

```ts
  resolveTagFilterGroups,
  type PraiseResult,
```

(b) `POST /api/praises` (linhas 498-506). Troque:

```ts
        const tag = await c.env.DB.prepare('SELECT id FROM tags WHERE id = ?').bind(tagId).first();
        if (!tag) return c.json({ error: 'Tag not found' }, 400);
        if (await tagHasChildren(c.env.DB, tagId)) {
          return c.json({ error: 'Cannot attach a parent tag; use a subtag' }, 400);
        }

        await c.env.DB.prepare(
```

por:

```ts
        const tag = await c.env.DB.prepare('SELECT id FROM tags WHERE id = ?').bind(tagId).first();
        if (!tag) return c.json({ error: 'Tag not found' }, 400);

        await c.env.DB.prepare(
```

(c) `POST /api/praises/:id/tags` (linhas 676-681). Troque:

```ts
      const tag = await c.env.DB.prepare('SELECT id FROM tags WHERE id = ?').bind(tagId).first();
      if (!tag) return c.json({ error: 'Tag not found' }, 404);
      if (await tagHasChildren(c.env.DB, tagId)) {
        return c.json({ error: 'Cannot attach a parent tag; use a subtag' }, 400);
      }

```

por:

```ts
      const tag = await c.env.DB.prepare('SELECT id FROM tags WHERE id = ?').bind(tagId).first();
      if (!tag) return c.json({ error: 'Tag not found' }, 404);

```

(d) Merge (linhas 820-849). Troque o bloco inteiro:

```ts
      // A lista que chega é a união das tags dos dois louvores, então as tags
      // que o keeper JÁ tinha voltam aqui. Uma delas virar tag pai (alguém criou
      // uma subtag depois) não é tentativa nova de associar tag pai: é dado
      // preexistente, e recusar matava toda mesclagem daquele louvor. Tag pai
      // vinda só do louvor fonte continua barrada — aí a associação é nova.
      const jaNoKeeper = new Set(
        (
          (
            await c.env.DB.prepare('SELECT tag_id FROM praise_tags WHERE praise_id = ?')
              .bind(keeperId)
              .all<{ tag_id: string }>()
          ).results ?? []
        ).map((linha) => linha.tag_id)
      );

      for (const tagId of tagIds) {
        const tag = await c.env.DB.prepare('SELECT id FROM tags WHERE id = ?').bind(tagId).first();
        if (!tag) return c.json({ error: 'Tag not found' }, 400);
        if (jaNoKeeper.has(tagId)) continue;
        if (await tagHasChildren(c.env.DB, tagId)) {
          // Sem o nome não havia como saber qual das tags do lote era a culpada.
          const nome = await c.env.DB.prepare('SELECT name FROM tags WHERE id = ?')
            .bind(tagId)
            .first<{ name: string }>();
          return c.json(
            { error: `Cannot attach a parent tag; use a subtag: ${nome?.name ?? tagId}` },
            400
          );
        }
      }
```

por:

```ts
      // Tag pai (raiz com subtags) é aceita: ligada direto, quer dizer «sem
      // subtag específica» (spec seções da Coletânea, §3.2). Só tag que não
      // existe barra o merge, antes de qualquer escrita.
      for (const tagId of tagIds) {
        const tag = await c.env.DB.prepare('SELECT id FROM tags WHERE id = ?').bind(tagId).first();
        if (!tag) return c.json({ error: 'Tag not found' }, 400);
      }
```

(e) Em `api/src/praiseQuery.ts`, apague a função que ficou sem chamador (linhas 78-82, com a linha em branco seguinte):

```ts
export async function tagHasChildren(db: D1Database, tagId: string): Promise<boolean> {
  const row = await db.prepare('SELECT id FROM tags WHERE parent_id = ? LIMIT 1').bind(tagId).first();
  return Boolean(row);
}

```

Antes de seguir, confirme que não sobrou chamador:

```
grep -rn "tagHasChildren\|Cannot attach a parent" src
```

Esperado: nenhuma linha.

- [ ] **Step 4: Run, expect PASS**

```
npx vitest run src/__tests__/parentTagAttach.test.ts src/__tests__/index.test.ts src/__tests__/mergeParentTag.test.ts
```

Esperado: `Tests  117 passed (117)`.

```
npx vitest run
```

Esperado: `Test Files  62 passed (62)`, sem `×`.

```
npx tsc --noEmit
```

Esperado: sai sem saída e com código 0. Um import esquecido de `tagHasChildren` aparece aqui.

- [ ] **Step 5: Commit**

```
git add src/routes/praises.ts src/praiseQuery.ts src/__tests__/parentTagAttach.test.ts src/__tests__/index.test.ts src/__tests__/mergeParentTag.test.ts
```

```
git commit -m "feat(api): aceita ligar louvor a tag raiz que tem subtags" -m "Criação, POST /tags e merge deixam de recusar tag pai: a raiz ligada direto quer dizer sem subtag específica (spec seções da Coletânea §3.2). Sem isso, Avulsos deixaria de poder ser marcada depois de ganhar a subtag GLTM. tagHasChildren fica sem chamador e sai." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Merge sem `metadata.category` não mexe na categoria (§3.3)

**Files:**
- Modify: `api/src/routes/praises.ts`, no handler `POST /api/praises/:keeperId/merge`. As linhas são as de **depois** da Task 2: o laço de `metadata` (~766-795) e o `UPDATE praises SET` do lote (~846-861).
- Create: `api/src/__tests__/mergeCategoryOptional.test.ts`

**Interfaces:**
- Consumes: o corpo do merge `{ source_praise_id, metadata: { name, number, author, rhythm, tonality, category?, lyrics }, tag_ids, material_ids_to_import }`.
- Produces: `metadata.category` passa a ser opcional.
  - Ausente: o `UPDATE` não toca `category`.
  - `null`: grava NULL.
  - String: grava a string.
  - Outro tipo: `400 Field 'metadata.category' must be a string`.

  Os outros seis campos continuam obrigatórios, com as mesmas mensagens. Com a chave presente, o SQL e a ordem dos binds ficam idênticos aos de hoje.

- [ ] **Step 1: Write the failing test**

Crie `api/src/__tests__/mergeCategoryOptional.test.ts`:

```ts
import { SignJWT } from 'jose';
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it, vi } from 'vitest';
import { app } from '../index';
import { d1DeSqlite, sqliteComSchema } from './sqliteD1';

/**
 * `metadata.category` deixa de ser obrigatório no merge (spec 2026-09-24 seções
 * da Coletânea, §3.3). Sem a chave: a categoria do keeper fica como está. Com a
 * chave, o comportamento de antes: string grava, `null` apaga.
 */
const SEGREDO = '0123456789abcdef0123456789abcdef';
const ORIGEM = 'https://web.example';

async function escrita(body: object): Promise<RequestInit> {
  const jwt = await new SignJWT({ email: 'admin@test.com', jti: 'j-merge-categoria' })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject('sub-admin')
    .setIssuedAt()
    .setExpirationTime('2h')
    .sign(new TextEncoder().encode(SEGREDO));
  return {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      origin: ORIGEM,
      cookie: `coldigom_access=${encodeURIComponent(jwt)}`,
    },
    body: JSON.stringify(body),
  };
}

function ambiente() {
  const sqlite = sqliteComSchema();
  const louvor = (id: string, categoria: string | null) =>
    sqlite
      .prepare('INSERT INTO praises (id, name, number, author, category) VALUES (?, ?, ?, ?, ?)')
      .run(id, `Louvor ${id}`, '001', 'Autor antigo', categoria);
  louvor('keeper', 'Clamor');
  louvor('fonte', 'Avulsos');
  const env = {
    DB: d1DeSqlite(sqlite),
    ASSETS: { head: vi.fn(async () => null), put: vi.fn(), delete: vi.fn() },
    AUTH_JWT_SECRET: SEGREDO,
    AUTH_ALLOWED_EMAILS: '*',
    WEB_ORIGIN: ORIGEM,
  };
  return { sqlite, env };
}

type Linha = { name: string; number: string | null; author: string | null; category: string | null; lyrics: string | null };

function keeper(sqlite: DatabaseSync): Linha {
  return sqlite
    .prepare('SELECT name, number, author, category, lyrics FROM praises WHERE id = ?')
    .get('keeper') as Linha;
}

/** Os seis campos que continuam obrigatórios, sem `category`. */
const SEM_CATEGORIA = {
  name: 'Nome novo',
  number: '002',
  author: null,
  rhythm: null,
  tonality: null,
  lyrics: 'Letra nova',
};

async function mesclar(env: object, metadata: Record<string, unknown>) {
  return app.request(
    '/api/praises/keeper/merge',
    await escrita({ source_praise_id: 'fonte', metadata, tag_ids: [], material_ids_to_import: [] }),
    env as never,
  );
}

describe('merge — metadata.category opcional', () => {
  it('sem a chave: aceita e não mexe na categoria do keeper', async () => {
    const { sqlite, env } = ambiente();
    const res = await mesclar(env, SEM_CATEGORIA);

    expect(res.status).toBe(200);
    expect(keeper(sqlite)).toEqual({
      name: 'Nome novo',
      number: '002',
      author: null,
      category: 'Clamor',
      lyrics: 'Letra nova',
    });
    expect(sqlite.prepare('SELECT id FROM praises WHERE id = ?').get('fonte')).toBeUndefined();
  });

  it('com string: grava a categoria, como antes', async () => {
    const { sqlite, env } = ambiente();
    const res = await mesclar(env, { ...SEM_CATEGORIA, category: 'Louvor' });

    expect(res.status).toBe(200);
    expect(keeper(sqlite).category).toBe('Louvor');
    expect(keeper(sqlite).lyrics).toBe('Letra nova');
  });

  it('com null: apaga a categoria, como antes — null não é «ausente»', async () => {
    const { sqlite, env } = ambiente();
    const res = await mesclar(env, { ...SEM_CATEGORIA, category: null });

    expect(res.status).toBe(200);
    expect(keeper(sqlite).category).toBeNull();
  });

  it('com tipo errado: continua 400 e não escreve nada', async () => {
    const { sqlite, env } = ambiente();
    const res = await mesclar(env, { ...SEM_CATEGORIA, category: 7 });

    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: string }).error).toBe("Field 'metadata.category' must be a string");
    expect(keeper(sqlite).category).toBe('Clamor');
    expect(keeper(sqlite).name).toBe('Louvor keeper');
  });

  it('os outros campos continuam obrigatórios', async () => {
    const { sqlite, env } = ambiente();
    const semLetra: Record<string, unknown> = { ...SEM_CATEGORIA };
    delete semLetra.lyrics;
    const res = await mesclar(env, semLetra);

    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: string }).error).toBe("Field 'metadata.lyrics' is required");
    expect(sqlite.prepare('SELECT id FROM praises WHERE id = ?').get('fonte')).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run it, expect FAIL**

```
npx vitest run src/__tests__/mergeCategoryOptional.test.ts
```

Esperado: `Tests  2 failed | 3 passed (5)`.
- «sem a chave: …» falha com `expected 400 to be 200`.
- «os outros campos continuam obrigatórios» falha com `expected 'Field \'metadata.category\' is requir…' to be 'Field \'metadata.lyrics\' is required'`, porque hoje a falta de `category` é acusada antes da falta de `lyrics`.

- [ ] **Step 3: Minimal implementation**

Em `api/src/routes/praises.ts`, no handler do merge, faça duas mudanças.

(a) O laço de `metadata`. Troque:

```ts
    for (const key of updatable) {
      if (!(key in metaObj)) {
        return c.json({ error: `Field 'metadata.${key}' is required` }, 400);
      }
      const val = metaObj[key];
      if (key === 'name') {
```

por:

```ts
    // Sem a chave `category`, a categoria do keeper fica como está (spec seções
    // da Coletânea, §3.3): o admin parou de mandá-la. `null` continua
    // significando «apagar» — ausente e nulo não são a mesma coisa.
    const mexeNaCategoria = 'category' in metaObj;

    for (const key of updatable) {
      if (!(key in metaObj)) {
        if (key === 'category') continue;
        return c.json({ error: `Field 'metadata.${key}' is required` }, 400);
      }
      const val = metaObj[key];
      if (key === 'name') {
```

O mesmo trecho `for (const key of updatable)` também existe no PATCH (~linha 540), mas lá não há `if (!(key in metaObj))`. Por isso a string acima só casa no merge. Confira que o Edit caiu no handler `/api/praises/:keeperId/merge`.

(b) O `UPDATE` do lote. Troque:

```ts
        c.env.DB.prepare(
          `UPDATE praises SET name = ?, number = ?, author = ?, rhythm = ?, tonality = ?, category = ?, lyrics = ?,
           updated_at = datetime('now') WHERE id = ?`
        ).bind(
          metaValues.name,
          metaValues.number,
          metaValues.author,
          metaValues.rhythm,
          metaValues.tonality,
          metaValues.category,
          metaValues.lyrics,
          keeperId
        ),
```

por:

```ts
        c.env.DB.prepare(
          `UPDATE praises SET name = ?, number = ?, author = ?, rhythm = ?, tonality = ?,${
            mexeNaCategoria ? ' category = ?,' : ''
          } lyrics = ?,
           updated_at = datetime('now') WHERE id = ?`
        ).bind(
          metaValues.name,
          metaValues.number,
          metaValues.author,
          metaValues.rhythm,
          metaValues.tonality,
          ...(mexeNaCategoria ? [metaValues.category] : []),
          metaValues.lyrics,
          keeperId
        ),
```

Com a chave presente, o texto gerado é `tonality = ?, category = ?, lyrics = ?`, igual ao de hoje, e os binds ficam na mesma ordem. O mock de `index.test.ts` («merges source into keeper and deletes source», que lê `args[5]`/`args[7]`) continua valendo.

- [ ] **Step 4: Run, expect PASS**

```
npx vitest run src/__tests__/mergeCategoryOptional.test.ts src/__tests__/index.test.ts src/__tests__/mergeAtomicity.test.ts src/__tests__/mergeParentTag.test.ts src/__tests__/praiseShortIdRoutes.test.ts
```

Esperado: todos passam, sem `×`. `index.test.ts` e `mergeAtomicity` mandam `category` e cobrem o caminho «com a chave»; `praiseShortIdRoutes` cobre o merge com SQLite real.

- [ ] **Step 5: Commit**

```
git add src/routes/praises.ts src/__tests__/mergeCategoryOptional.test.ts
```

```
git commit -m "feat(api): merge sem metadata.category não mexe na categoria" -m "A chave deixa de ser obrigatória (spec seções da Coletânea §3.3): ausente, o UPDATE não toca category; null continua apagando; string continua gravando. Os outros campos de metadata seguem obrigatórios." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Verificação final da API

**Files:** nenhum. A tarefa só verifica. Se algum passo falhar, corrija na tarefa dona e faça um commit de correção.

**Interfaces:**
- Consumes: as Tasks 1–3 commitadas.
- Produces: a evidência de que a branch está pronta para o passo 1 do spec §6 (deploy, que fica com o dono).

- [ ] **Step 1: Suíte inteira**

```
npx vitest run
```

Esperado: `Test Files  63 passed (63)` (os 60 atuais mais os 3 novos), sem `×`. No ensaio deste plano, a contagem foi `Tests  648 passed (648)`.

- [ ] **Step 2: Catraca de cobertura (a mesma do CI, `pr-mergeable.yml`)**

```
npm run test:coverage
```

Esperado: código 0, sem `ERROR: Coverage for … does not meet global threshold`. No ensaio: `All files | 80.13 | 75.73 | 82.32 | 82.48`, contra a catraca 79 / 75 / 82 / 82.

- [ ] **Step 3: Tipos**

```
npx tsc --noEmit
```

Esperado: nenhuma saída, código 0.

- [ ] **Step 4: Lint**

```
npm run lint
```

Esperado: `0 errors`. Os 2 avisos `no-explicit-any` herdados podem aparecer.

- [ ] **Step 5: Varredura do que deveria ter sumido**

```
grep -rn "tagHasChildren\|Cannot attach a parent\|jaNoKeeper" src
```

Esperado: nenhuma linha.

```
git status --short
```

Esperado: árvore limpa.

```
git log --oneline -4
```

Esperado: os três commits deste plano sobre `5d0f728`.

Não faça push nem abra PR. Relate ao orquestrador a saída real dos passos 1–4.

---

## Notas para os próximos planos (fora deste)

- **Admin web (plano do §3.5):** `web/src/services/mensagensDeErro.ts:7` e `:23` traduzem `Cannot attach a parent tag; use a subtag`, mensagem que a API deixa de emitir. A regex vira código morto e deve sair junto com a mudança de `tagSelectOptions`.
- **Criação não atômica (preexistente, não muda aqui):** `POST /api/praises` grava o louvor antes de validar as tags. Hoje, com `tag_ids` contendo uma tag inexistente, a resposta é 400 e o louvor fica criado sem as tags. Antes deste plano o mesmo acontecia com tag pai. O caso só diminui, não piora.
- **Validação em produção (spec §6.1):** depois do deploy, `GET /api/praises?tags=<id de PES>` precisa trazer a união de `PES` e `PES · 9.2026`, com `pagination.total` igual ao `count` de PES em `/api/praises/filters`.
