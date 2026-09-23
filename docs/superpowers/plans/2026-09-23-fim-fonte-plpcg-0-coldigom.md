# Fim da fonte PLPCG — plano 0: coldigom (`praises.short_id` + crosswalk) — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o Worker `coldigom-api` passa a dar a cada louvor um id curto imutável (`praises.short_id`, exposto nas três leituras do app) e ganha `POST /api/plpcg/crosswalk`, que traduz em lote os `pdfId` legados para o material atual do coldigom — as duas peças de que os planos 1–3 do app dependem.

**Architecture:** a migração 023 acrescenta a coluna, faz o backfill determinístico e cria um contador (`app_meta.short_id_next`) e três gatilhos SQLite: um atribui o id em **todo** INSERT de `praises` (qualquer porta: rota, `ingest.ts`, SQL gerado, `apply.py`), outro recusa id inventado, outro torna o id imutável. As rotas só leem a coluna. O crosswalk é uma consulta única com `json_each(?)` sobre `plpcg_crosswalk` + `praise_materials`, com o CORS global e `Cache-Control: no-store`. Os testes das duas peças correm num **SQLite de verdade** (`node:sqlite`) embrulhado na forma de `D1Database`.

**Tech Stack:** Cloudflare Workers + Hono 4 + D1 (SQLite), TypeScript 5, vitest 4 (`node:sqlite` do Node ≥ 22), `wrangler` 4.93 global, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md` (§7, §11 item 1) — no repo **coldigui**. O código mexido é o do repo **coldigom** (`/Volumes/SSD 2TB SD/dev/coldigom`, pasta `api/`). Contexto do crosswalk: `docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md` §8 no repo coldigom.

## Global Constraints

- **Repo e branch:** coldigom, branch `feat/praise-short-id` a partir de `origin/develop`, no worktree `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/praise-short-id` (secção «Preparação»). PR para `develop`. Todos os paths abaixo são relativos à raiz do repo coldigom; os comandos `npx …`/`npm …` correm em `api/`.
- **Só as duas peças de §7** do spec (mais o que elas exigem — ver «Desvios»). Nada no coldigui neste plano.
- **Contratos fixos (os planos 1–3 dependem deles, nomes exatos):**
  - **C1:** coluna `praises.short_id` (hex minúsculo, `printf('%03x', n)`, única, imutável, nunca reutilizada). O dump `GET /api/plpcg/catalog` traz `"shortId": "<hex>"` em cada praise (omitido se nulo). `GET /api/praises/:id` e os itens de `GET /api/plpcg/praises` trazem `"short_id"`.
  - **C2:** `POST /api/plpcg/crosswalk` corpo `{"pdfIds": [string, …]}` (1..500) → `200 {"items": {"<pdfId>": {"praiseId": str, "materialId": str, "url": str}}}` (desconhecidos omitidos); 400 se não for array de strings ou > 500. Público, CORS igual ao `/api/plpcg/resolve/:shortId`, `Cache-Control: no-store`. `url` = URL real atual do material (acerta materiais movidos).
- **Migração aplicada à mão**, uma vez, **antes** do deploy do Worker: `cd api && wrangler d1 execute coldigom --remote --file=migrations/023_praise_short_id.sql`. Nunca `wrangler d1 migrations apply` (a tabela `d1_migrations` remota não é usada neste repo). `wrangler` global, não `npx wrangler`.
- **`api/schema.sql` acompanha a migração** e o `schemaSync.test.ts` passa a conferir a 023.
- **Testes:** `cd api && npx vitest run <ficheiro>` por tarefa; no fim de cada tarefa `npx vitest run`, `npm run lint` (0 erros; os 2 avisos herdados ficam) e `npm run build`. A catraca de cobertura (`api/vitest.config.ts`: 78 / 73 / 80 / 81) não pode cair — `npm run test:coverage`.
- **Node ≥ 22** para correr os testes (`node:sqlite`). Local: 25. CI da API: passa a 22 (Task 1).
- **Mensagens de erro** das rotas `/api/plpcg/*` em português, como as que já existem em `api/src/routes/plpcg.ts`.
- **Commits** em português, no estilo do repo (`feat(api): …`, `test(api): …`), um por tarefa, terminando com o trailer exato:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- **Nada de push, PR, `wrangler … --remote`, merge ou deploy sem pedido do dono** (Task 5). O classificador do modo automático bloqueia `wrangler` remoto e `gh`: o dono corre esses comandos com `!`.
- **Execução:** subagentes com cwd no worktree do coldigom, tarefa a tarefa. git como comando plano (sem `cd … &&` nem `git -C`).

### Desvios do spec (decididos ao planear; ver justificativa na tarefa)

1. **§7.1 «no INSERT de praise, no mesmo `db.batch`, lê e avança o contador» → gatilho SQLite.** Praises nascem por quatro portas: `POST /api/praises` (`api/src/routes/praises.ts:484`), `api/scripts/ingest.ts:180`, o SQL gerado por `scripts/import-youtube-playlist` e o `--undo` de `scripts/validate-acervo/core/apply.py:744-750`. Mudar só a rota deixaria as outras três criando louvores sem id. O gatilho `AFTER INSERT` roda dentro do próprio statement: se o INSERT falha, ou o lote do D1 é revertido, o contador volta junto — o mesmo «falha não gasta id» do spec, provado nos testes. Task 2.
2. **O gatilho FTS `praises_au` passa a `AFTER UPDATE OF name, lyrics`** (migração e `schema.sql`). O SQLite dispara gatilhos `AFTER` na ordem **inversa** da criação: o gatilho de short_id roda antes do `praises_ai`, e o `UPDATE` dele fazia o `praises_au` antigo mandar ao FTS5 um `'delete'` de linha ainda não indexada — `database disk image is malformed` no primeiro insert (medido ao planear, com o `schema.sql` de `develop`). Com o gatilho restrito às colunas indexadas, o problema some; de quebra, editar ritmo ou tom deixa de reindexar. Task 2.
3. **INSERT com `short_id` explícito:** o spec diz «o cliente nunca escolhe o valor». A API nunca passa a coluna (o `POST` ignora `short_id` no corpo — teste na Task 3). No banco, um valor explícito só passa se **já foi emitido** (é o `--undo` do `apply.py` repondo, do snapshot, o louvor que ele mesmo apagou); valor à frente do contador colidiria com um id futuro e travaria toda criação de louvor, e por isso é recusado. Task 2.
4. **Migração 023, não 022.** A branch `feat/praise-is-reviewed` (não mesclada, em origin) já tem `api/migrations/022_praise_is_reviewed.sql`; o repo já renumerou uma migração por colisão (commit `375e6ae`). Task 2.
5. **CI da API de Node 20 para 22** (`pr-mergeable.yml`, job da API, e `deploy-api.yml`). Os testes de SQL de verdade usam `node:sqlite`, que o Node 20 não tem (medido: `No such built-in module`). O `wrangler` 4.93.1 do `package.json` já declara `engines.node >= 22`. Alternativa descartada: `sql.js` como devDependency nova. Task 1.
6. **No crosswalk, `praiseId` é o dono atual do material (`praise_materials.praise_id`)**, não o `plpcg_crosswalk.praise_id` que o `/resolve` devolve: merge e move mudam o dono e o crosswalk fica para trás. É o mesmo motivo por que `url` sai do `r2_key` real. Task 4.
7. **Brief × repo:** o pedido de redação sugeria `wrangler d1 migrations apply --remote`; a convenção do repo (cabeçalho das migrações 017–021, planos de 15/09 e 17/09) é `wrangler d1 execute --remote --file`, e a `d1_migrations` remota não é usada. O plano segue o repo. Task 5.

## Review Focus

- **Primeiro insert depois da migração com o FTS vazio ou cheio:** a busca de texto (`useFts`) tem de continuar a achar o louvor novo e o renomeado, sem corromper o índice. Testes «troca o praises_au: sem isso, o primeiro insert num FTS vazio corrompe o índice» e «o FTS acompanha…» (Task 2).
- **Lote de 500 pdfIds contra o limite de 100 parâmetros por consulta do D1:** uma consulta com um parâmetro só (`json_each(?)`); o SQLite local aceitaria 500 `?`, e por isso o teste confere o SQL. Teste «aceita 500 de uma vez…» (Task 4).
- **Material fundido ou movido depois do crosswalk:** o app tem de receber o praise que hoje é dono do material e a URL do `r2_key` real (pasta de outro praise). Teste «material movido: o praise é o dono atual e a URL é o r2_key real» (Task 4).
- **`--undo` do `apply.py` com snapshot que já tem `short_id`:** repor o louvor apagado com o próprio id e o upsert de `set_praise_field` com a linha inteira do snapshot têm de passar sem gastar id. Testes «o --undo do apply.py repõe…» e «o upsert do --undo de set_praise_field…» (Task 2).
- **Worker novo com D1 antigo, ou praise sem id:** o dump não pode mandar `"shortId": null` (o app espera ausência), e o ETag tem de mudar quando o id chega, para os clientes rebaixarem uma vez. Teste «catálogo: sem short_id a chave some, e o ETag muda quando ele chega» (Task 3).

## Mapa de ficheiros

| Tarefa | Cria | Modifica | Apaga |
|---|---|---|---|
| 1 SQLite real + CI Node 22 | `api/src/__tests__/sqliteD1.ts`, `api/src/__tests__/sqliteD1.test.ts` | `.github/workflows/pr-mergeable.yml`, `.github/workflows/deploy-api.yml` | — |
| 2 Migração 023 | `api/migrations/023_praise_short_id.sql`, `api/src/__tests__/praiseShortId.test.ts` | `api/schema.sql`, `api/src/__tests__/schemaSync.test.ts` | — |
| 3 Exposição (C1) | `api/src/__tests__/praiseShortIdRoutes.test.ts` | `api/src/praiseQuery.ts`, `api/src/routes/praises.ts`, `api/src/plpcgPraises.ts`, `docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md` | — |
| 4 Crosswalk (C2) | `api/src/__tests__/plpcgCrosswalk.test.ts` | `api/src/plpcgResolve.ts`, `api/src/routes/plpcg.ts`, `api/src/__tests__/routes.inventory.test.ts`, `api/vitest.config.ts`, `docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md` | — |
| 5 PR e deploy (só com pedido do dono) | — | — (D1 remoto e Worker) | — |

---

## Preparação (antes da Task 1)

- [ ] **Worktree e branch**

Na raiz do repo coldigom (`/Volumes/SSD 2TB SD/dev/coldigom`):

```bash
git fetch origin
git worktree add .claude/worktrees/praise-short-id -b feat/praise-short-id origin/develop
```

Daqui em diante, cwd = `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/praise-short-id`.

- [ ] **Número da migração livre**

```bash
for b in $(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes); do git ls-tree --name-only "$b" api/migrations/; done | sort -u | tail -4
```

Expected: a maior é `api/migrations/022_praise_is_reviewed.sql` (branch não mesclada) ou `021_contributions.sql`. Se já existir uma `023_*`, usar o próximo número livre e trocar `023` em todo este plano (ficheiro, cabeçalho, teste do `schemaSync`, comandos da Task 5).

- [ ] **Dependências e linha de base**

```bash
cd api && npm ci && npx vitest run
```

Expected: tudo verde (em `develop` @ `a5fbc28`: 56 ficheiros, 596 testes). `node --version` ≥ 22.

---

## Unidade 1 — Infraestrutura de teste

### Task 1: D1 de verdade nos testes (`node:sqlite`) e CI da API em Node 22

Os testes da casa usam um D1 falso que despacha pelo texto da query. Serve para o fluxo da rota e é cego para o que só o SQLite decide (gatilho, índice único, `UPDATE … FROM`, `json_each`, rollback de lote), que é exatamente o que este plano entrega.

**Files:**
- Create: `api/src/__tests__/sqliteD1.ts`
- Test: `api/src/__tests__/sqliteD1.test.ts`
- Modify: `.github/workflows/pr-mergeable.yml` (job `api_build_test_coverage`), `.github/workflows/deploy-api.yml`

**Interfaces:**
- Produces (usados nas Tasks 2–4):
  - `RAIZ_API: string` — caminho absoluto de `api/`.
  - `lerSqlDaApi(relativo: string): string` — lê um ficheiro de `api/` (ex.: `'migrations/023_praise_short_id.sql'`).
  - `sqliteComSchema(): DatabaseSync` — SQLite em memória com o `api/schema.sql` de hoje.
  - `d1DeSqlite(sqlite: DatabaseSync): D1Database` — `prepare`/`bind`/`first(col?)`/`all`/`run` e `batch` em transação (tudo ou nada, como o D1).

- [ ] **Step 1: Teste do helper**

```ts
// api/src/__tests__/sqliteD1.test.ts
import { describe, expect, it } from 'vitest';
import { d1DeSqlite, sqliteComSchema } from './sqliteD1';

describe('sqliteD1 — o D1 de verdade dos testes', () => {
  it('carrega o schema.sql inteiro, FTS5 incluído', () => {
    const sqlite = sqliteComSchema();
    const tabelas = sqlite
      .prepare("SELECT name FROM sqlite_master WHERE type IN ('table', 'trigger') ORDER BY name")
      .all()
      .map((r) => (r as { name: string }).name);
    expect(tabelas).toEqual(expect.arrayContaining(['praises', 'praises_fts', 'praises_ai', 'plpcg_crosswalk']));
  });

  it('prepare/bind/first/all/run como o D1', async () => {
    const db = d1DeSqlite(sqliteComSchema());
    const escrita = await db
      .prepare('INSERT INTO praises (id, name) VALUES (?, ?)')
      .bind('p1', 'Grande Deus')
      .run();
    expect(escrita.meta.changes).toBe(1);

    expect(await db.prepare('SELECT id, name FROM praises WHERE id = ?').bind('p1').first()).toEqual({
      id: 'p1',
      name: 'Grande Deus',
    });
    expect(await db.prepare('SELECT name FROM praises WHERE id = ?').bind('p1').first('name')).toBe('Grande Deus');
    expect(await db.prepare('SELECT id FROM praises WHERE id = ?').bind('nada').first()).toBeNull();
    expect((await db.prepare('SELECT id FROM praises').all()).results).toEqual([{ id: 'p1' }]);
  });

  it('batch é tudo ou nada, como no D1', async () => {
    const db = d1DeSqlite(sqliteComSchema());
    await expect(
      db.batch([
        db.prepare('INSERT INTO praises (id, name) VALUES (?, ?)').bind('p1', 'A'),
        db.prepare('INSERT INTO praises (id, name) VALUES (?, ?)').bind('p1', 'repetido'),
      ]),
    ).rejects.toThrow(/UNIQUE constraint failed: praises\.id/);
    expect((await db.prepare('SELECT COUNT(*) AS n FROM praises').first()) as { n: number }).toEqual({ n: 0 });
  });
});
```

- [ ] **Step 2: Correr e ver falhar**

Run: `npx vitest run src/__tests__/sqliteD1.test.ts`
Expected: FAIL — não resolve `./sqliteD1`.

- [ ] **Step 3: O helper**

```ts
// api/src/__tests__/sqliteD1.ts
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { DatabaseSync, type SQLInputValue } from 'node:sqlite';

/**
 * D1 de verdade para os testes que precisam do SQL rodando: gatilhos,
 * índices únicos, `UPDATE … FROM`, `json_each`. Os outros testes da casa
 * usam um D1 falso que despacha pelo texto da query — ótimo para o fluxo
 * da rota, cego para o que só o SQLite decide.
 *
 * Só o subconjunto da API do D1 que as rotas usam: `prepare`, `bind`,
 * `first`, `all`, `run` e `batch` (em transação, como o D1). Precisa de
 * Node ≥ 22 (`node:sqlite`); o CI da API roda em 22.
 */
export const RAIZ_API = resolve(__dirname, '..', '..');

export function lerSqlDaApi(relativo: string): string {
  return readFileSync(resolve(RAIZ_API, relativo), 'utf8');
}

/** SQLite em memória com o `schema.sql` de hoje — o bootstrap de um D1 novo. */
export function sqliteComSchema(): DatabaseSync {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(lerSqlDaApi('schema.sql'));
  return sqlite;
}

type Linha = Record<string, unknown>;

/** O node:sqlite devolve linhas de protótipo nulo; a rota e o `toEqual` querem objeto comum. */
function plano(linha: unknown): Linha | null {
  return linha ? { ...(linha as Linha) } : null;
}

function statement(sqlite: DatabaseSync, sql: string, args: SQLInputValue[] = []) {
  const executar = () => {
    const r = sqlite.prepare(sql).run(...args);
    return {
      success: true,
      results: [],
      meta: { changes: Number(r.changes), last_row_id: Number(r.lastInsertRowid) },
    };
  };
  return {
    bind: (...novos: unknown[]) => statement(sqlite, sql, novos as SQLInputValue[]),
    all: async () => ({
      success: true,
      results: sqlite.prepare(sql).all(...args).map(plano),
      meta: {},
    }),
    first: async (coluna?: string) => {
      const linha = plano(sqlite.prepare(sql).get(...args));
      if (!linha) return null;
      return coluna ? (linha[coluna] ?? null) : linha;
    },
    run: async () => executar(),
    executar,
  };
}

/** Embrulha o SQLite na forma de `D1Database` que as rotas esperam. */
export function d1DeSqlite(sqlite: DatabaseSync): D1Database {
  return {
    prepare: (sql: string) => statement(sqlite, sql),
    batch: async (lote: Array<ReturnType<typeof statement>>) => {
      sqlite.exec('BEGIN');
      try {
        const resultados = lote.map((s) => s.executar());
        sqlite.exec('COMMIT');
        return resultados;
      } catch (erro) {
        sqlite.exec('ROLLBACK');
        throw erro;
      }
    },
  } as unknown as D1Database;
}
```

O ficheiro fica em `src/__tests__/` sem o sufixo `.test.ts`: o vitest não o corre como suíte, o `tsc` do build e a cobertura já excluem a pasta.

- [ ] **Step 4: Correr e ver passar — no Node local e no 22 do CI**

Run: `npx vitest run src/__tests__/sqliteD1.test.ts`
Expected: PASS, 3 testes.

Run: `npx -y node@22 node_modules/vitest/vitest.mjs run src/__tests__/sqliteD1.test.ts`
Expected: PASS, 3 testes (o Node 22 avisa `ExperimentalWarning: SQLite is an experimental feature` — é esperado). Isto prova que o SQLite do Node 22 tem FTS5.

- [ ] **Step 5: CI da API em Node 22**

Em `.github/workflows/pr-mergeable.yml`, **só** no job `api_build_test_coverage` (o job `web_build_test_coverage` fica em 20), trocar:

```yaml
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: api/package-lock.json
```

por:

```yaml
      # 22: os testes de SQL de verdade usam node:sqlite (não existe no 20), e o
      # wrangler 4.93 do package.json já declara engines.node >= 22.
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: api/package-lock.json
```

Em `.github/workflows/deploy-api.yml`, no passo `Setup Node.js`, trocar `node-version: '20'` por `node-version: '22'` e pôr acima do passo o mesmo comentário de duas linhas.

- [ ] **Step 6: Suíte, lint, build**

Run: `npx vitest run && npm run lint && npm run build`
Expected: verde; lint com 0 erros (2 avisos herdados); `tsc` sem erros.

- [ ] **Step 7: Commit**

```bash
git add api/src/__tests__/sqliteD1.ts api/src/__tests__/sqliteD1.test.ts .github/workflows/pr-mergeable.yml .github/workflows/deploy-api.yml
git commit -m "test(api): D1 de verdade nos testes (node:sqlite) e CI da API em Node 22

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 2 — `praises.short_id` (C1)

### Task 2: Migração 023 — coluna, backfill, contador e gatilhos

**Files:**
- Create: `api/migrations/023_praise_short_id.sql`
- Modify: `api/schema.sql` (coluna no `CREATE TABLE praises`, `praises_au`, bloco novo no fim)
- Test: `api/src/__tests__/praiseShortId.test.ts` (criar), `api/src/__tests__/schemaSync.test.ts` (caso `023`)

**Interfaces:**
- Consumes: `sqliteComSchema`, `lerSqlDaApi`, `d1DeSqlite` (Task 1).
- Produces:
  - coluna `praises.short_id TEXT` com `UNIQUE INDEX idx_praises_short_id`;
  - tabela `app_meta(key TEXT PRIMARY KEY, value INTEGER NOT NULL)` com a linha `('short_id_next', <próximo n>)`;
  - gatilhos `praises_short_id_ai` (atribui), `praises_short_id_bi` (recusa valor não emitido), `praises_short_id_bu` (imutável);
  - `praises_au` restrito a `AFTER UPDATE OF name, lyrics`.
  Nenhum código TypeScript muda nesta tarefa; a Task 3 lê a coluna.

- [ ] **Step 1: Testes da migração e das invariantes**

```ts
// api/src/__tests__/praiseShortId.test.ts
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it } from 'vitest';
import { d1DeSqlite, lerSqlDaApi, sqliteComSchema } from './sqliteD1';

/**
 * praises.short_id (migração 023): o banco atribui, nunca repete, nunca muda.
 * SQLite de verdade — gatilho, índice único e rollback não existem no D1 falso.
 */

/** praises como estava antes da 023, com o FTS e os três gatilhos dele (como em produção). */
const PRE_023 = `
CREATE TABLE praises (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, number TEXT, author TEXT, rhythm TEXT,
  tonality TEXT, category TEXT, lyrics TEXT, group_id TEXT,
  created_at TEXT DEFAULT (datetime('now')), updated_at TEXT DEFAULT (datetime('now'))
);
CREATE VIRTUAL TABLE praises_fts USING fts5(name, lyrics, content='praises', content_rowid='rowid');
CREATE TRIGGER praises_ai AFTER INSERT ON praises BEGIN
  INSERT INTO praises_fts(rowid, name, lyrics) VALUES (new.rowid, new.name, new.lyrics);
END;
CREATE TRIGGER praises_ad AFTER DELETE ON praises BEGIN
  INSERT INTO praises_fts(praises_fts, rowid, name, lyrics) VALUES('delete', old.rowid, old.name, old.lyrics);
END;
CREATE TRIGGER praises_au AFTER UPDATE ON praises BEGIN
  INSERT INTO praises_fts(praises_fts, rowid, name, lyrics) VALUES('delete', old.rowid, old.name, old.lyrics);
  INSERT INTO praises_fts(rowid, name, lyrics) VALUES (new.rowid, new.name, new.lyrics);
END;`;

const MIGRACAO = lerSqlDaApi('migrations/023_praise_short_id.sql');

function shortIds(sqlite: DatabaseSync): Record<string, string | null> {
  const linhas = sqlite.prepare('SELECT id, short_id FROM praises ORDER BY id').all() as {
    id: string;
    short_id: string | null;
  }[];
  return Object.fromEntries(linhas.map((l) => [l.id, l.short_id]));
}

function contador(sqlite: DatabaseSync): number {
  return (sqlite.prepare("SELECT value FROM app_meta WHERE key = 'short_id_next'").get() as { value: number }).value;
}

function inserir(sqlite: DatabaseSync, id: string, shortId?: string) {
  if (shortId === undefined) {
    sqlite.prepare('INSERT INTO praises (id, name) VALUES (?, ?)').run(id, `Louvor ${id}`);
  } else {
    sqlite.prepare('INSERT INTO praises (id, name, short_id) VALUES (?, ?, ?)').run(id, `Louvor ${id}`, shortId);
  }
}

/** FTS5 externo desalinhado corrompe a busca em silêncio; o integrity-check acusa. */
function ftsIntegro(sqlite: DatabaseSync) {
  sqlite.exec("INSERT INTO praises_fts(praises_fts, rank) VALUES('integrity-check', 1)");
}

/** Ids achados pela busca de texto, como o `useFts` de praiseQuery.ts faz. */
function achados(sqlite: DatabaseSync, termo: string): string[] {
  return (
    sqlite
      .prepare(
        'SELECT p.id FROM praises_fts f JOIN praises p ON p.rowid = f.rowid WHERE praises_fts MATCH ? ORDER BY p.id',
      )
      .all(termo) as { id: string }[]
  ).map((r) => r.id);
}

describe('migração 023 — backfill', () => {
  function migrado() {
    const sqlite = new DatabaseSync(':memory:');
    sqlite.exec(PRE_023);
    const ins = sqlite.prepare('INSERT INTO praises (id, name, lyrics, created_at) VALUES (?, ?, ?, ?)');
    ins.run('b', 'B', 'letra b', '2024-01-02 10:00:00');
    ins.run('a', 'A', 'letra a', '2024-01-02 10:00:00'); // empate: o id desempata
    ins.run('c', 'C', 'letra c', '2024-01-01 09:00:00');
    ins.run('d', 'D', null, null); // created_at nulo vem primeiro, como no ORDER BY do SQLite
    sqlite.exec(MIGRACAO);
    return sqlite;
  }

  it('único e contíguo, na ordem de criação com o id de desempate', () => {
    const sqlite = migrado();
    expect(shortIds(sqlite)).toEqual({ d: '000', c: '001', a: '002', b: '003' });
  });

  it('o contador começa em COUNT(*): o próximo praise ganha o id seguinte', () => {
    const sqlite = migrado();
    expect(contador(sqlite)).toBe(4);
    inserir(sqlite, 'e');
    expect(shortIds(sqlite).e).toBe('004');
  });

  it('troca o praises_au: sem isso, o primeiro insert num FTS vazio corrompe o índice', () => {
    const sqlite = new DatabaseSync(':memory:');
    sqlite.exec(PRE_023);
    sqlite.exec(MIGRACAO);
    inserir(sqlite, 'p1');
    inserir(sqlite, 'p2');
    expect(shortIds(sqlite)).toEqual({ p1: '000', p2: '001' });
    expect(() => ftsIntegro(sqlite)).not.toThrow();
    expect(achados(sqlite, 'p2')).toEqual(['p2']);
  });

  it('o FTS continua íntegro e achando depois do backfill e de inserts', () => {
    const sqlite = migrado();
    for (const id of ['e', 'f', 'g']) inserir(sqlite, id);
    expect(() => ftsIntegro(sqlite)).not.toThrow();
    expect(achados(sqlite, 'f')).toEqual(['f']);
    expect(achados(sqlite, 'letra')).toEqual(['a', 'b', 'c']);
  });
});

describe('praises.short_id — atribuição e invariantes (schema.sql)', () => {
  it('cada insert gasta um id, em sequência', () => {
    const sqlite = sqliteComSchema();
    inserir(sqlite, 'p1');
    inserir(sqlite, 'p2');
    expect(shortIds(sqlite)).toEqual({ p1: '000', p2: '001' });
    expect(contador(sqlite)).toBe(2);
    expect(() => ftsIntegro(sqlite)).not.toThrow();
  });

  it('insert que falha não gasta id', () => {
    const sqlite = sqliteComSchema();
    inserir(sqlite, 'p1');
    expect(() => inserir(sqlite, 'p1')).toThrow(/UNIQUE constraint failed: praises\.id/);
    expect(() => sqlite.prepare('INSERT INTO praises (id, name) VALUES (?, NULL)').run('p2')).toThrow(/NOT NULL/);
    expect(contador(sqlite)).toBe(1);
    inserir(sqlite, 'p3');
    expect(shortIds(sqlite).p3).toBe('001');
  });

  it('lote do D1 revertido devolve o id', async () => {
    const sqlite = sqliteComSchema();
    const db = d1DeSqlite(sqlite);
    await expect(
      db.batch([
        db.prepare('INSERT INTO praises (id, name) VALUES (?, ?)').bind('p1', 'A'),
        db.prepare('INSERT INTO praise_tags (praise_id, tag_id) VALUES (?, ?)').bind('p1', 'tag-que-nao-existe'),
      ]),
    ).rejects.toThrow(/FOREIGN KEY/);
    expect(contador(sqlite)).toBe(0);
    inserir(sqlite, 'p2');
    expect(shortIds(sqlite)).toEqual({ p2: '000' });
  });

  it('o cliente não escolhe: valor ainda não emitido é recusado', () => {
    const sqlite = sqliteComSchema();
    expect(() => inserir(sqlite, 'p1', '000')).toThrow(/só um valor já emitido/);
    inserir(sqlite, 'p1');
    for (const ruim of ['001', '0ff', 'fff', '1000', '00', '0000', 'ABC', '-01', 'zz1']) {
      expect(() => inserir(sqlite, 'x', ruim), ruim).toThrow(/só um valor já emitido/);
    }
    expect(contador(sqlite)).toBe(1);
  });

  it('imutável: nem trocar, nem apagar; editar o resto não mexe nele', () => {
    const sqlite = sqliteComSchema();
    inserir(sqlite, 'p1');
    expect(() => sqlite.prepare("UPDATE praises SET short_id = 'fff' WHERE id = 'p1'").run()).toThrow(/imutável/);
    expect(() => sqlite.prepare("UPDATE praises SET short_id = NULL WHERE id = 'p1'").run()).toThrow(/imutável/);
    sqlite.prepare("UPDATE praises SET name = 'Outro', short_id = short_id WHERE id = 'p1'").run();
    expect(shortIds(sqlite).p1).toBe('000');
  });

  it('apagado queima o id: o próximo não o reutiliza', () => {
    const sqlite = sqliteComSchema();
    inserir(sqlite, 'p1');
    inserir(sqlite, 'p2');
    sqlite.prepare("DELETE FROM praises WHERE id = 'p1'").run();
    inserir(sqlite, 'p3');
    expect(shortIds(sqlite)).toEqual({ p2: '001', p3: '002' });
  });

  it('o --undo do apply.py repõe o louvor apagado com o próprio id; um id vivo não se repete', () => {
    const sqlite = sqliteComSchema();
    inserir(sqlite, 'p1');
    inserir(sqlite, 'p2');
    sqlite.prepare("DELETE FROM praises WHERE id = 'p1'").run();
    inserir(sqlite, 'p1', '000');
    expect(shortIds(sqlite)).toEqual({ p1: '000', p2: '001' });
    expect(() => inserir(sqlite, 'p9', '001')).toThrow(/UNIQUE constraint failed: praises\.short_id/);
    expect(contador(sqlite)).toBe(2);
  });

  it('o upsert do --undo de set_praise_field (linha inteira do snapshot) passa e não gasta id', () => {
    const sqlite = sqliteComSchema();
    inserir(sqlite, 'p1');
    sqlite
      .prepare(
        `INSERT INTO praises (id, name, short_id) VALUES ('p1', 'Nome antigo', '000')
         ON CONFLICT(id) DO UPDATE SET name = excluded.name, short_id = excluded.short_id`,
      )
      .run();
    expect(sqlite.prepare("SELECT name, short_id FROM praises WHERE id = 'p1'").get()).toEqual({
      name: 'Nome antigo',
      short_id: '000',
    });
    expect(contador(sqlite)).toBe(1);
    expect(() => ftsIntegro(sqlite)).not.toThrow();
  });

  it('o FTS acompanha: novo e renomeado são achados, índice íntegro', () => {
    const sqlite = sqliteComSchema();
    inserir(sqlite, 'p1');
    inserir(sqlite, 'p2');
    sqlite.prepare("UPDATE praises SET name = 'Aleluia' WHERE id = 'p2'").run();
    sqlite.prepare("UPDATE praises SET rhythm = 'Valsa' WHERE id = 'p1'").run();
    expect(achados(sqlite, 'p1')).toEqual(['p1']);
    expect(achados(sqlite, 'aleluia')).toEqual(['p2']);
    expect(achados(sqlite, 'p2')).toEqual([]);
    expect(() => ftsIntegro(sqlite)).not.toThrow();
  });

  it('largura dinâmica: fff e depois 1000', () => {
    const sqlite = sqliteComSchema();
    sqlite.prepare("UPDATE app_meta SET value = 4095 WHERE key = 'short_id_next'").run();
    inserir(sqlite, 'p1');
    inserir(sqlite, 'p2');
    expect(shortIds(sqlite)).toEqual({ p1: 'fff', p2: '1000' });
  });
});
```

Em `api/src/__tests__/schemaSync.test.ts`, acrescentar como último `it` do `describe` (antes do `});` final):

```ts
  it('023: short_id, índice único, app_meta, gatilhos de short_id e o praises_au novo estão nos dois', () => {
    const schema = normal(readFileSync(resolve(RAIZ, 'schema.sql'), 'utf8'));
    const mig = normal(readFileSync(resolve(RAIZ, 'migrations', '023_praise_short_id.sql'), 'utf8'));
    expect(mig).toContain('ALTER TABLE praises ADD COLUMN short_id TEXT');
    expect(schema).toMatch(/CREATE TABLE IF NOT EXISTS praises \([^;]* short_id TEXT,/);
    expect(schema).toContain("INSERT OR IGNORE INTO app_meta (key, value) VALUES ('short_id_next', 0)");
    const gatilhos = mig.match(/CREATE TRIGGER IF NOT EXISTS praises_(?:au|short_id_\w+) .*? END;/g) ?? [];
    expect(gatilhos).toHaveLength(4);
    for (const trecho of [
      'CREATE TABLE IF NOT EXISTS app_meta ( key TEXT PRIMARY KEY, value INTEGER NOT NULL );',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_praises_short_id ON praises(short_id);',
      'CREATE TRIGGER IF NOT EXISTS praises_au AFTER UPDATE OF name, lyrics ON praises BEGIN',
      ...gatilhos,
    ]) {
      expect(mig, `migração sem: ${trecho}`).toContain(trecho);
      expect(schema, `schema.sql sem: ${trecho}`).toContain(trecho);
    }
  });
```

- [ ] **Step 2: Correr e ver falhar**

Run: `npx vitest run src/__tests__/praiseShortId.test.ts src/__tests__/schemaSync.test.ts`
Expected: FAIL — `ENOENT … migrations/023_praise_short_id.sql` (o ficheiro de teste inteiro não carrega; o caso `023` do schemaSync falha pelo mesmo motivo).

- [ ] **Step 3: A migração**

```sql
-- api/migrations/023_praise_short_id.sql
-- short_id do praise (spec coldigui docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md §7.1).
--
-- Id curto do LOUVOR, para o link de lista do app PLPCG (`?p=1a2-0c3`):
-- hex minúsculo `printf('%03x', n)` — 000…fff e depois 1000… sozinho —,
-- único, imutável e nunca reutilizado (louvor apagado ou fundido queima o id).
--
-- Quem atribui é o banco, não a rota: praises nascem por POST /api/praises,
-- por scripts/ingest.ts, pelo SQL gerado em scripts/import-youtube-playlist e
-- pelo apply.py do validate-acervo. Um gatilho cobre todas as portas. Ele roda
-- dentro do INSERT: se o INSERT falha, ou o lote do D1 em que ele está é
-- revertido, o contador volta junto — falha não gasta id.
--
-- Um INSERT com short_id explícito só passa se o valor já foi emitido (é o
-- --undo do apply.py repondo o louvor que ele mesmo apagou); valor à frente do
-- contador colidiria com um id futuro e travaria toda criação de louvor.
--
-- Aplicar UMA vez (o ALTER não se repete), ANTES do deploy do Worker que lê a coluna:
--   cd api && wrangler d1 execute coldigom --remote --file=migrations/023_praise_short_id.sql

CREATE TABLE IF NOT EXISTS app_meta (
  key   TEXT PRIMARY KEY,
  value INTEGER NOT NULL
);

ALTER TABLE praises ADD COLUMN short_id TEXT;

-- O gatilho de short_id faz um UPDATE dentro do INSERT, e o SQLite dispara os
-- gatilhos AFTER na ordem inversa da criação: o nosso roda ANTES do praises_ai.
-- Com o praises_au antigo (qualquer UPDATE), esse UPDATE mandava ao FTS um
-- 'delete' de uma linha ainda não indexada, e o FTS5 de conteúdo externo
-- corrompe ("database disk image is malformed"). O praises_au passa a olhar só
-- as colunas indexadas — de quebra, editar ritmo ou tom deixa de reindexar.
DROP TRIGGER IF EXISTS praises_au;
CREATE TRIGGER IF NOT EXISTS praises_au AFTER UPDATE OF name, lyrics ON praises BEGIN
    INSERT INTO praises_fts(praises_fts, rowid, name, lyrics) VALUES('delete', old.rowid, old.name, old.lyrics);
    INSERT INTO praises_fts(rowid, name, lyrics) VALUES (new.rowid, new.name, new.lyrics);
END;

-- Backfill determinístico: ordem de criação, id como desempate.
UPDATE praises
SET short_id = r.sid
FROM (
  SELECT id, printf('%03x', ROW_NUMBER() OVER (ORDER BY created_at, id) - 1) AS sid
  FROM praises
) AS r
WHERE praises.id = r.id AND praises.short_id IS NULL;

INSERT OR IGNORE INTO app_meta (key, value)
SELECT 'short_id_next', COUNT(*) FROM praises;

CREATE UNIQUE INDEX IF NOT EXISTS idx_praises_short_id ON praises(short_id);

CREATE TRIGGER IF NOT EXISTS praises_short_id_ai AFTER INSERT ON praises
WHEN NEW.short_id IS NULL
BEGIN
  UPDATE praises
  SET short_id = (SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next')
  WHERE id = NEW.id;
  UPDATE app_meta SET value = value + 1 WHERE key = 'short_id_next';
END;

CREATE TRIGGER IF NOT EXISTS praises_short_id_bi BEFORE INSERT ON praises
WHEN NEW.short_id IS NOT NULL AND (
  NEW.short_id GLOB '*[^0-9a-f]*'
  OR length(NEW.short_id) < 3
  OR (length(NEW.short_id) > 3 AND substr(NEW.short_id, 1, 1) = '0')
  OR length(NEW.short_id) > length((SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next'))
  OR (
    length(NEW.short_id) = length((SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next'))
    AND NEW.short_id >= (SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next')
  )
)
BEGIN
  SELECT RAISE(ABORT, 'praises.short_id: só um valor já emitido pode ser reposto');
END;

CREATE TRIGGER IF NOT EXISTS praises_short_id_bu BEFORE UPDATE OF short_id ON praises
WHEN OLD.short_id IS NOT NULL AND NEW.short_id IS NOT OLD.short_id
BEGIN
  SELECT RAISE(ABORT, 'praises.short_id é imutável');
END;
```

Por que o `praises_short_id_bi` compara texto: com a largura `%03x`, dois hex bem formados (minúsculos, sem zero à esquerda além dos 3 dígitos) comparam como números quando se compara primeiro o comprimento e, em empate, a ordem lexicográfica. Isso evita converter hex em número dentro do SQLite.

- [ ] **Step 4: O `schema.sql`**

Três mudanças em `api/schema.sql`:

(a) No `CREATE TABLE IF NOT EXISTS praises`, entre `group_id` e `created_at`:

```sql
    group_id TEXT,                 -- Shared id for same song / different arrangements
    short_id TEXT,                 -- Id curto do louvor (migração 023): hex, único, imutável, atribuído pelo gatilho
    created_at TEXT DEFAULT (datetime('now')),
```

(b) Trocar a primeira linha do gatilho `praises_au`:

```sql
CREATE TRIGGER IF NOT EXISTS praises_au AFTER UPDATE ON praises BEGIN
```

por:

```sql
-- Só as colunas indexadas: o UPDATE do gatilho de short_id (migração 023) roda
-- antes do praises_ai e não pode mandar ao FTS um 'delete' de linha não indexada.
CREATE TRIGGER IF NOT EXISTS praises_au AFTER UPDATE OF name, lyrics ON praises BEGIN
```

(o corpo do gatilho, as duas linhas `INSERT INTO praises_fts…` e o `END;`, fica igual).

(c) Acrescentar no fim do ficheiro, depois dos índices de `plpcg_crosswalk`:

```sql

-- short_id do praise (migração 023; spec coldigui 2026-09-23-fim-fonte-plpcg §7.1).
-- A coluna está no CREATE TABLE praises acima. O contador começa em 0 num D1 novo;
-- quem atribui é o gatilho praises_short_id_ai, em todo INSERT, por qualquer porta.
CREATE TABLE IF NOT EXISTS app_meta (
  key   TEXT PRIMARY KEY,
  value INTEGER NOT NULL
);
INSERT OR IGNORE INTO app_meta (key, value) VALUES ('short_id_next', 0);

CREATE UNIQUE INDEX IF NOT EXISTS idx_praises_short_id ON praises(short_id);

CREATE TRIGGER IF NOT EXISTS praises_short_id_ai AFTER INSERT ON praises
WHEN NEW.short_id IS NULL
BEGIN
  UPDATE praises
  SET short_id = (SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next')
  WHERE id = NEW.id;
  UPDATE app_meta SET value = value + 1 WHERE key = 'short_id_next';
END;

CREATE TRIGGER IF NOT EXISTS praises_short_id_bi BEFORE INSERT ON praises
WHEN NEW.short_id IS NOT NULL AND (
  NEW.short_id GLOB '*[^0-9a-f]*'
  OR length(NEW.short_id) < 3
  OR (length(NEW.short_id) > 3 AND substr(NEW.short_id, 1, 1) = '0')
  OR length(NEW.short_id) > length((SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next'))
  OR (
    length(NEW.short_id) = length((SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next'))
    AND NEW.short_id >= (SELECT printf('%03x', value) FROM app_meta WHERE key = 'short_id_next')
  )
)
BEGIN
  SELECT RAISE(ABORT, 'praises.short_id: só um valor já emitido pode ser reposto');
END;

CREATE TRIGGER IF NOT EXISTS praises_short_id_bu BEFORE UPDATE OF short_id ON praises
WHEN OLD.short_id IS NOT NULL AND NEW.short_id IS NOT OLD.short_id
BEGIN
  SELECT RAISE(ABORT, 'praises.short_id é imutável');
END;
```

A ordem importa: no `schema.sql` os gatilhos de short_id são criados **depois** dos de FTS, como vai acontecer em produção.

- [ ] **Step 5: Correr e ver passar**

Run: `npx vitest run src/__tests__/praiseShortId.test.ts src/__tests__/schemaSync.test.ts src/__tests__/sqliteD1.test.ts`
Expected: PASS (14 + 4 + 3).

- [ ] **Step 6: Suíte, lint, build**

Run: `npx vitest run && npm run lint && npm run build`
Expected: verde. Nenhum teste de rota antigo muda: o D1 falso não vê gatilhos, e nenhuma rota lê a coluna ainda.

- [ ] **Step 7: Commit**

```bash
git add api/migrations/023_praise_short_id.sql api/schema.sql api/src/__tests__/praiseShortId.test.ts api/src/__tests__/schemaSync.test.ts
git commit -m "feat(api): migração 023 — praises.short_id atribuído por gatilho, imutável e sem reuso

O praises_au passa a AFTER UPDATE OF name, lyrics: o UPDATE do gatilho novo
roda antes do praises_ai e corrompia o FTS5.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 3: `short_id` nas três leituras (C1)

**Files:**
- Modify: `api/src/praiseQuery.ts` (`PraiseResult`), `api/src/routes/praises.ts` (`GET /api/praises/:id`), `api/src/plpcgPraises.ts` (`ListRow`, `listSql`, `CatalogPraiseRow`, SELECT e montagem do dump)
- Modify: `docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md` (§8.2)
- Test: `api/src/__tests__/praiseShortIdRoutes.test.ts`

**Interfaces:**
- Consumes: `d1DeSqlite`, `sqliteComSchema` (Task 1); coluna e gatilhos (Task 2).
- Produces (C1, consumido pelo plano 1 do app):
  - `GET /api/praises/:id` → `data.short_id: string | null` (e, por consequência, as respostas de `POST /api/praises`, `PATCH /api/praises/:id`, merge, grupo e tags, que refazem o GET).
  - `GET /api/plpcg/praises` → `data[i].short_id: string | null`.
  - `GET /api/plpcg/catalog` → `praises[i].shortId: string`, **ausente** quando a coluna é nula. O ETag muda (hash de `{kinds, praises}`).
  - `PraiseResult.short_id?: string | null` em `praiseQuery.ts`.

- [ ] **Step 1: Testes de rota com o SQLite de verdade**

```ts
// api/src/__tests__/praiseShortIdRoutes.test.ts
import { SignJWT } from 'jose';
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it, vi } from 'vitest';
import { app } from '../index';
import { buildPlpcgCatalog } from '../plpcgPraises';
import { TAG_LABEL_SQL } from '../praiseQuery';
import { d1DeSqlite, sqliteComSchema } from './sqliteD1';

/**
 * O short_id nas rotas (contrato C1 do spec coldigui 2026-09-23 §7.1): sai no
 * detalhe, na lista do PLPCG e no dump; nenhuma escrita da API o muda.
 * SQLite de verdade: é o gatilho da 023 que atribui.
 */
const SEGREDO = '0123456789abcdef0123456789abcdef';
const ORIGEM = 'https://web.example';

async function escrita(method: string, body: object): Promise<RequestInit> {
  const jwt = await new SignJWT({ email: 'admin@test.com', jti: 'j-short-id' })
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

function ambiente() {
  const sqlite = sqliteComSchema();
  const env = {
    DB: d1DeSqlite(sqlite),
    ASSETS: { head: vi.fn(async () => null), put: vi.fn(), delete: vi.fn() },
    AUTH_JWT_SECRET: SEGREDO,
    AUTH_ALLOWED_EMAILS: '*',
    WEB_ORIGIN: ORIGEM,
  };
  return { sqlite, env };
}

function louvor(sqlite: DatabaseSync, id: string, nome = `Louvor ${id}`) {
  sqlite.prepare('INSERT INTO praises (id, name, number) VALUES (?, ?, ?)').run(id, nome, '001');
}

function shortIdDe(sqlite: DatabaseSync, id: string): string | null {
  const linha = sqlite.prepare('SELECT short_id FROM praises WHERE id = ?').get(id) as { short_id: string | null } | undefined;
  return linha?.short_id ?? null;
}

type Detalhe = { data: { id: string; short_id: string | null } };

describe('short_id nas leituras', () => {
  it('GET /api/praises/:id traz short_id', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'p1');
    louvor(sqlite, 'p2');
    const res = await app.request('/api/praises/p2', {}, env as never);
    expect(res.status).toBe(200);
    expect(((await res.json()) as Detalhe).data.short_id).toBe('001');
  });

  it('GET /api/plpcg/praises traz short_id em cada item', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'p1');
    const res = await app.request('/api/plpcg/praises', {}, env as never);
    expect(res.status).toBe(200);
    const json = (await res.json()) as { data: { id: string; short_id: string }[] };
    expect(json.data.map((p) => [p.id, p.short_id])).toEqual([['p1', '000']]);
  });

  it('GET /api/plpcg/catalog traz shortId em cada praise', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'p1');
    const res = await app.request('/api/plpcg/catalog', {}, env as never);
    expect(res.status).toBe(200);
    const json = (await res.json()) as { praises: Record<string, unknown>[] };
    expect(json.praises[0]).toMatchObject({ id: 'p1', shortId: '000' });
  });

  it('catálogo: sem short_id a chave some, e o ETag muda quando ele chega', async () => {
    const semShortId = { id: 'p1', short_id: null, name: 'A', number: '1', author: null, rhythm: null, tonality: null, category: null, lyrics: null };
    const fake = (linha: object) =>
      ({
        prepare: (sql: string) => ({
          all: async () => ({ results: sql.includes('FROM praises p') ? [linha] : [] }),
          bind: () => ({ all: async () => ({ results: [] }) }),
        }),
      }) as unknown as D1Database;

    const antes = await buildPlpcgCatalog(fake(semShortId), { tagLabelSql: TAG_LABEL_SQL }, undefined);
    const depois = await buildPlpcgCatalog(fake({ ...semShortId, short_id: '000' }), { tagLabelSql: TAG_LABEL_SQL }, undefined);

    expect(JSON.parse(antes.body).praises[0]).not.toHaveProperty('shortId');
    expect(JSON.parse(depois.body).praises[0].shortId).toBe('000');
    expect(depois.headers.ETag).not.toBe(antes.headers.ETag);
  });
});

describe('short_id nas escritas da API', () => {
  it('POST /api/praises: o banco atribui, e a resposta já traz o id', async () => {
    const { env } = ambiente();
    const r1 = await app.request('/api/praises', await escrita('POST', { name: 'Primeiro' }), env as never);
    const r2 = await app.request('/api/praises', await escrita('POST', { name: 'Segundo', short_id: '0ff' }), env as never);
    expect(r1.status).toBe(201);
    expect(r2.status).toBe(201);
    expect(((await r1.json()) as Detalhe).data.short_id).toBe('000');
    expect(((await r2.json()) as Detalhe).data.short_id).toBe('001');
  });

  it('PATCH /api/praises/:id ignora short_id no corpo e não o muda', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'p1');
    const res = await app.request('/api/praises/p1', await escrita('PATCH', { name: 'Novo nome', short_id: 'fff' }), env as never);
    expect(res.status).toBe(200);
    expect(((await res.json()) as Detalhe).data.short_id).toBe('000');
    expect(shortIdDe(sqlite, 'p1')).toBe('000');
  });

  it('merge: o keeper fica com o dele, o da fonte é queimado', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'keeper');
    louvor(sqlite, 'fonte');
    const res = await app.request(
      '/api/praises/keeper/merge',
      await escrita('POST', {
        source_praise_id: 'fonte',
        metadata: { name: 'Keeper', number: '001', author: null, rhythm: null, tonality: null, category: null, lyrics: null },
        tag_ids: [],
        material_ids_to_import: [],
      }),
      env as never,
    );
    expect(res.status).toBe(200);
    expect(shortIdDe(sqlite, 'keeper')).toBe('000');
    expect(shortIdDe(sqlite, 'fonte')).toBeNull();

    const novo = await app.request('/api/praises', await escrita('POST', { name: 'Depois do merge' }), env as never);
    expect(((await novo.json()) as Detalhe).data.short_id).toBe('002');
  });

  it('mover material entre louvores não mexe no short_id de nenhum dos dois', async () => {
    const { sqlite, env } = ambiente();
    louvor(sqlite, 'origem');
    louvor(sqlite, 'destino');
    sqlite
      .prepare("INSERT INTO praise_materials (id, praise_id, material_kind, type, r2_key) VALUES ('m1', 'origem', 'k1', 'pdf', 'assets/praises/origem/m1.pdf')")
      .run();
    const res = await app.request('/api/materials/m1', await escrita('PATCH', { praise_id: 'destino' }), env as never);
    expect(res.status).toBe(200);
    expect(sqlite.prepare("SELECT praise_id FROM praise_materials WHERE id = 'm1'").get()).toEqual({ praise_id: 'destino' });
    expect([shortIdDe(sqlite, 'origem'), shortIdDe(sqlite, 'destino')]).toEqual(['000', '001']);
  });
});
```

- [ ] **Step 2: Correr e ver falhar**

Run: `npx vitest run src/__tests__/praiseShortIdRoutes.test.ts`
Expected: FAIL em 7 de 8 — `short_id`/`shortId` chegam `undefined`. «mover material…» já passa: é o gatilho da Task 2 que o garante, e o teste fica como guarda.

- [ ] **Step 3: `PraiseResult`**

Em `api/src/praiseQuery.ts`, na interface `PraiseResult`, entre `group_id` e o comentário de `updated_at`:

```ts
  group_id: string | null;
  /** Id curto do louvor (migração 023) — hex minúsculo, imutável; o link `?p=` do app PLPCG. */
  short_id?: string | null;
  /** Token de versão da tela: volta no PATCH como `if_updated_at`. */
```

- [ ] **Step 4: Detalhe do louvor**

Em `api/src/routes/praises.ts`, na query `praiseQuery` do `GET /api/praises/:id`, trocar:

```ts
          p.updated_at,
          GROUP_CONCAT(pt.tag_id) as tag_ids
```

por:

```ts
          p.short_id, p.updated_at,
          GROUP_CONCAT(pt.tag_id) as tag_ids
```

Nada mais nesta rota: o `...praiseResult` já espalha a coluna no `data`, e `POST`, `PATCH`, merge, grupo e tags devolvem o que este GET devolve.

- [ ] **Step 5: Lista do PLPCG e dump**

Em `api/src/plpcgPraises.ts`:

(a) Em `type ListRow`, depois de `group_id: string | null;`:

```ts
  short_id: string | null;
```

(b) No `listSql` de `listPlpcgPraises`, trocar a primeira linha do SELECT:

```ts
        p.id, p.name, p.number, p.author, p.rhythm, p.tonality, p.category, p.group_id,
```

por:

```ts
        p.id, p.name, p.number, p.author, p.rhythm, p.tonality, p.category, p.group_id, p.short_id,
```

(c) Em `type CatalogPraiseRow`, depois de `id: string;`:

```ts
  short_id?: string | null;
```

(d) Em `buildPlpcgCatalog`, trocar o SELECT de praises:

```ts
      `SELECT p.id, p.name, p.number, p.author, p.rhythm, p.tonality, p.category, p.lyrics
       FROM praises p
```

por:

```ts
      `SELECT p.id, p.short_id, p.name, p.number, p.author, p.rhythm, p.tonality, p.category, p.lyrics
       FROM praises p
```

(e) Na montagem de cada praise do dump, trocar:

```ts
    const praise: Record<string, unknown> = {
      id: row.id,
      number: row.number ?? '',
```

por:

```ts
    const praise: Record<string, unknown> = {
      id: row.id,
      // Sem short_id (D1 ainda sem a migração 023) a chave some, em vez de ir `null`.
      ...(row.short_id ? { shortId: row.short_id } : {}),
      number: row.number ?? '',
```

- [ ] **Step 6: Correr e ver passar**

Run: `npx vitest run src/__tests__/praiseShortIdRoutes.test.ts src/__tests__/index.test.ts src/__tests__/praiseDetailResilience.test.ts src/__tests__/praiseListResilience.test.ts`
Expected: PASS. Os testes antigos do catálogo e da lista usam linhas sem `short_id` e continuam verdes (a chave some, não vira `null`).

- [ ] **Step 7: Nota no spec do coldigom**

Em `docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md`, §8.2, inserir antes do parágrafo que começa por «O que **não** está no manifest»:

```markdown
**`praises.short_id` (migração 023, 23/09 — spec coldigui `2026-09-23-fim-fonte-plpcg` §7.1).** Id curto do
*louvor* (não do material, como o `shortId` do manifest): hex minúsculo `printf('%03x', n)`, único, imutável,
nunca reutilizado, atribuído por gatilho em todo INSERT de `praises`. Sai como `shortId` em cada praise de
`/api/plpcg/catalog` (omitido se nulo) e como `short_id` em `GET /api/praises/:id` e nos itens de
`/api/plpcg/praises`.

```

- [ ] **Step 8: Suíte, lint, build**

Run: `npx vitest run && npm run lint && npm run build`
Expected: verde.

- [ ] **Step 9: Commit**

```bash
git add api/src/praiseQuery.ts api/src/routes/praises.ts api/src/plpcgPraises.ts api/src/__tests__/praiseShortIdRoutes.test.ts docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md
git commit -m "feat(api): short_id no detalhe, na lista do PLPCG e no dump do catálogo

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 3 — Crosswalk em lote (C2)

### Task 4: `POST /api/plpcg/crosswalk`

**Files:**
- Modify: `api/src/plpcgResolve.ts` (constantes, parser e resolvedor novos), `api/src/routes/plpcg.ts` (rota), `api/src/__tests__/routes.inventory.test.ts`, `api/vitest.config.ts` (catraca), `docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md` (§8.2)
- Test: `api/src/__tests__/plpcgCrosswalk.test.ts`

**Interfaces:**
- Consumes: `d1DeSqlite`, `sqliteComSchema` (Task 1); `pdfUrl(origin, praiseId, materialId, r2Key)` de `api/src/plpcgManifest.ts` (já importado em `plpcgResolve.ts`).
- Produces (C2, consumido pelo plano 3 do app e pelo script D1):
  - `export const CROSSWALK_MAX_IDS = 500`
  - `export const CROSSWALK_SQL: string` (um só `?`, via `json_each`)
  - `export type PlpcgCrosswalkItem = { praiseId: string; materialId: string; url: string }`
  - `export function parseCrosswalkBody(body: unknown): { ok: true; pdfIds: string[] } | { ok: false; error: string }`
  - `export async function resolvePlpcgCrosswalk(db: D1Database, pdfIds: string[], origin: string): Promise<Record<string, PlpcgCrosswalkItem>>`
  - Rota `POST /api/plpcg/crosswalk` → `200 {"items": {...}}` com `Cache-Control: no-store`; `400 {"error": "pdfIds: …"}`; `500 {"error": "Failed to resolve crosswalk"}`.

- [ ] **Step 1: Testes**

```ts
// api/src/__tests__/plpcgCrosswalk.test.ts
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it, vi } from 'vitest';
import { app } from '../index';
import { CROSSWALK_MAX_IDS, CROSSWALK_SQL, parseCrosswalkBody } from '../plpcgResolve';
import { d1DeSqlite, sqliteComSchema } from './sqliteD1';

/**
 * POST /api/plpcg/crosswalk (contrato C2 do spec coldigui 2026-09-23 §7.2):
 * o normalizador do app troca, uma vez, cada pdf_id legado pelo material do
 * coldigom. SQLite de verdade: o `json_each` e o JOIN são o que importa aqui.
 */
const PDF_CONHECIDO = 'TG91dm9yZXMgQ29sZXTDom5lYSBDSUFzLzAwMSAtIE1ldSBEZXVzLCBtZXUgcGFpL0NpZnJhIEkucGRm';
const PDF_MOVIDO = 'QXZ1bHNvcy8wMTcucGRm';
const PDF_APAGADO = 'QXZ1bHNvcy8wOTkucGRm';
const WEB_ORIGIN = 'https://coldigom-web.pages.dev,https://*plpcg.com,https://plpcjf.org';

function crosswalk(sqlite: DatabaseSync, pdfId: string, praiseId: string, materialId: string) {
  sqlite
    .prepare(
      `INSERT INTO plpcg_crosswalk (pdf_id, short_id, group_id, praise_id, praise_material_id, evidencia, confianca, decidido_por, run_id)
       VALUES (?, '0453', '001:x', ?, ?, 'teste', 'alta', 'detector', 'run-1')`,
    )
    .run(pdfId, praiseId, materialId);
}

/**
 * p1 com m1 (caso comum); m2 nasceu em `fonte`, que foi fundida em `keeper`:
 * o material está no keeper, o r2_key continua na pasta da fonte e o
 * crosswalk ainda aponta a fonte; m3 foi apagado no app.
 */
function ambiente() {
  const sqlite = sqliteComSchema();
  for (const id of ['p1', 'keeper']) sqlite.prepare('INSERT INTO praises (id, name) VALUES (?, ?)').run(id, id);
  const material = sqlite.prepare(
    'INSERT INTO praise_materials (id, praise_id, material_kind, type, r2_key, merged_from_praise_id) VALUES (?, ?, ?, ?, ?, ?)',
  );
  material.run('m1', 'p1', 'k1', 'pdf', 'assets/praises/p1/m1.pdf', null);
  material.run('m2', 'keeper', 'k1', 'pdf', 'assets/praises/fonte/m2.pdf', 'fonte');
  crosswalk(sqlite, PDF_CONHECIDO, 'p1', 'm1');
  crosswalk(sqlite, PDF_MOVIDO, 'fonte', 'm2');
  crosswalk(sqlite, PDF_APAGADO, 'p1', 'm3');
  return { DB: d1DeSqlite(sqlite) };
}

function post(body: unknown, headers: Record<string, string> = {}): RequestInit {
  return {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  };
}

describe('POST /api/plpcg/crosswalk', () => {
  it('lote misto: só os conhecidos voltam, com praise, material e URL absoluta; no-store', async () => {
    const res = await app.request(
      '/api/plpcg/crosswalk',
      post({ pdfIds: [PDF_CONHECIDO, 'desconhecido', PDF_APAGADO, PDF_CONHECIDO] }),
      ambiente(),
    );
    expect(res.status).toBe(200);
    expect(res.headers.get('cache-control')).toBe('no-store');
    expect(await res.json()).toEqual({
      items: {
        [PDF_CONHECIDO]: { praiseId: 'p1', materialId: 'm1', url: 'http://localhost/assets/praises/p1/m1.pdf' },
      },
    });
  });

  it('material movido: o praise é o dono atual e a URL é o r2_key real', async () => {
    const res = await app.request('/api/plpcg/crosswalk', post({ pdfIds: [PDF_MOVIDO] }), ambiente());
    expect(await res.json()).toEqual({
      items: {
        [PDF_MOVIDO]: { praiseId: 'keeper', materialId: 'm2', url: 'http://localhost/assets/praises/fonte/m2.pdf' },
      },
    });
  });

  it('aceita 500 de uma vez (um parâmetro só: o D1 recusa mais de 100 por consulta)', async () => {
    const pdfIds = [PDF_CONHECIDO, ...Array.from({ length: CROSSWALK_MAX_IDS - 1 }, (_, i) => `x${i}`)];
    const res = await app.request('/api/plpcg/crosswalk', post({ pdfIds }), ambiente());
    expect(res.status).toBe(200);
    expect(Object.keys(((await res.json()) as { items: object }).items)).toEqual([PDF_CONHECIDO]);
    expect(CROSSWALK_SQL).toMatch(/json_each\(\?\)/);
    expect(CROSSWALK_SQL.match(/\?/g)).toHaveLength(1);
  });

  it('corpo fora do contrato → 400 sem tocar no D1', async () => {
    const db = { prepare: vi.fn() } as unknown as D1Database;
    const ruins: unknown[] = [
      '{não é json',
      {},
      { pdfIds: 'abc' },
      { pdfIds: [] },
      { pdfIds: ['a', 1] },
      { pdfIds: Array.from({ length: CROSSWALK_MAX_IDS + 1 }, (_, i) => `x${i}`) },
    ];
    for (const corpo of ruins) {
      const res = await app.request('/api/plpcg/crosswalk', post(corpo), { DB: db });
      expect(res.status, JSON.stringify(corpo).slice(0, 40)).toBe(400);
      expect(((await res.json()) as { error: string }).error).toMatch(/^pdfIds: /);
    }
    expect(db.prepare).not.toHaveBeenCalled();
  });

  it('CORS igual ao /resolve: v2.plpcg.com lê, e o preflight do POST passa', async () => {
    const env = { ...ambiente(), WEB_ORIGIN };
    const res = await app.request(
      '/api/plpcg/crosswalk',
      post({ pdfIds: [PDF_CONHECIDO] }, { origin: 'https://v2.plpcg.com' }),
      env,
    );
    expect(res.headers.get('access-control-allow-origin')).toBe('https://v2.plpcg.com');

    const preflight = await app.request(
      '/api/plpcg/crosswalk',
      {
        method: 'OPTIONS',
        headers: {
          origin: 'https://v2.plpcg.com',
          'access-control-request-method': 'POST',
          'access-control-request-headers': 'content-type',
        },
      },
      env,
    );
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get('access-control-allow-origin')).toBe('https://v2.plpcg.com');
    expect(preflight.headers.get('access-control-allow-methods')).toContain('POST');
  });

  it('D1 fora do ar → 500 genérico', async () => {
    const db = {
      prepare: () => ({
        bind: () => ({
          all: async () => {
            throw new Error('D1_ERROR: no such table: plpcg_crosswalk');
          },
        }),
      }),
    } as unknown as D1Database;
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const res = await app.request('/api/plpcg/crosswalk', post({ pdfIds: [PDF_CONHECIDO] }), { DB: db });
    expect(res.status).toBe(500);
    expect(await res.json()).toEqual({ error: 'Failed to resolve crosswalk' });
    spy.mockRestore();
  });
});

describe('parseCrosswalkBody', () => {
  it('tira repetidos e mantém a ordem', () => {
    expect(parseCrosswalkBody({ pdfIds: ['b', 'a', 'b'] })).toEqual({ ok: true, pdfIds: ['b', 'a'] });
  });

  it('null e array na raiz são recusados', () => {
    expect(parseCrosswalkBody(null).ok).toBe(false);
    expect(parseCrosswalkBody([['a']]).ok).toBe(false);
  });
});
```

Em `api/src/__tests__/routes.inventory.test.ts`, em `ROTAS_ESPERADAS`, logo depois de `'GET /api/plpcg/resolve/:shortId',`:

```ts
  'POST /api/plpcg/crosswalk',
```

- [ ] **Step 2: Correr e ver falhar**

Run: `npx vitest run src/__tests__/plpcgCrosswalk.test.ts src/__tests__/routes.inventory.test.ts`
Expected: FAIL — a rota responde 404, `parseCrosswalkBody`/`CROSSWALK_SQL` não existem, e o inventário não tem a rota nova.

- [ ] **Step 3: Parser e resolvedor**

Acrescentar ao fim de `api/src/plpcgResolve.ts`:

```ts

/** POST /api/plpcg/crosswalk — teto do lote (contrato C2 do spec coldigui 2026-09-23-fim-fonte-plpcg §7.2). */
export const CROSSWALK_MAX_IDS = 500;

/**
 * Lote de pdf_id legados → material do coldigom, para o normalizador do app
 * trocar de uma vez os ids que as listas e o offline ainda guardam.
 *
 * Um parâmetro só (`json_each`): o D1 recusa mais de 100 parâmetros por
 * consulta, e o lote vai até 500. O praise é o DONO ATUAL do material
 * (`pm.praise_id`), não o `cw.praise_id`: merge e move mudam o dono e o
 * crosswalk fica para trás. JOIN interno como no /resolve: material apagado
 * no app fica de fora em vez de virar uma URL para um 404.
 */
export const CROSSWALK_SQL = `
  SELECT cw.pdf_id, pm.praise_id, pm.id AS material_id, pm.r2_key
  FROM plpcg_crosswalk cw
  JOIN praise_materials pm ON pm.id = cw.praise_material_id
  WHERE cw.pdf_id IN (SELECT value FROM json_each(?))`;

type CrosswalkRow = { pdf_id: string; praise_id: string; material_id: string; r2_key: string | null };

export type PlpcgCrosswalkItem = { praiseId: string; materialId: string; url: string };

/** `{"pdfIds": [string, …]}` com 1 a 500 itens; repetidos saem, a ordem fica. */
export function parseCrosswalkBody(
  body: unknown,
): { ok: true; pdfIds: string[] } | { ok: false; error: string } {
  const pdfIds =
    body && typeof body === 'object' && !Array.isArray(body) ? (body as { pdfIds?: unknown }).pdfIds : undefined;
  if (!Array.isArray(pdfIds) || pdfIds.length === 0 || !pdfIds.every((id) => typeof id === 'string')) {
    return { ok: false, error: `pdfIds: lista de 1 a ${CROSSWALK_MAX_IDS} strings` };
  }
  if (pdfIds.length > CROSSWALK_MAX_IDS) {
    return { ok: false, error: `pdfIds: no máximo ${CROSSWALK_MAX_IDS} por lote` };
  }
  return { ok: true, pdfIds: [...new Set(pdfIds as string[])] };
}

/** Os conhecidos, por pdf_id; os desconhecidos simplesmente não aparecem. */
export async function resolvePlpcgCrosswalk(
  db: D1Database,
  pdfIds: string[],
  origin: string,
): Promise<Record<string, PlpcgCrosswalkItem>> {
  const { results } = await db.prepare(CROSSWALK_SQL).bind(JSON.stringify(pdfIds)).all<CrosswalkRow>();
  const items: Record<string, PlpcgCrosswalkItem> = {};
  for (const r of results ?? []) {
    items[r.pdf_id] = {
      praiseId: r.praise_id,
      materialId: r.material_id,
      url: pdfUrl(origin, r.praise_id, r.material_id, r.r2_key),
    };
  }
  return items;
}
```

- [ ] **Step 4: A rota**

Em `api/src/routes/plpcg.ts`, trocar o import:

```ts
import { normalizarShortId, resolvePlpcgShortId } from '../plpcgResolve';
```

por:

```ts
import {
  normalizarShortId,
  parseCrosswalkBody,
  resolvePlpcgCrosswalk,
  resolvePlpcgShortId,
} from '../plpcgResolve';
```

e registar a rota no fim de `registerPlpcgRoutes`, depois do `app.get('/api/plpcg/resolve/:shortId', …)` (antes do `}` que fecha a função):

```ts

  // POST /api/plpcg/crosswalk — lote de pdf_id legados → praise, material e URL atuais.
  // Público como o /resolve (o CORS é o middleware de index.ts); POST só porque
  // 500 ids não cabem numa URL. Nada de cache: o normalizador do app pergunta
  // uma vez por id, e a resposta muda com merge/move.
  app.post('/api/plpcg/crosswalk', async (c) => {
    const parsed = parseCrosswalkBody(await c.req.json().catch(() => null));
    if (!parsed.ok) {
      return c.json({ error: parsed.error }, 400);
    }
    try {
      const items = await resolvePlpcgCrosswalk(c.env.DB, parsed.pdfIds, new URL(c.req.url).origin);
      c.header('Cache-Control', 'no-store');
      return c.json({ items });
    } catch (error) {
      console.error('Error resolving PLPCG crosswalk:', error);
      return c.json({ error: 'Failed to resolve crosswalk' }, 500);
    }
  });
```

O CORS não precisa de nada: o middleware `app.use('/*', cors(...))` de `api/src/index.ts` já responde ao preflight com `POST` e `Content-Type` permitidos, e é o mesmo que serve o `/resolve`.

- [ ] **Step 5: Correr e ver passar**

Run: `npx vitest run src/__tests__/plpcgCrosswalk.test.ts src/__tests__/routes.inventory.test.ts src/__tests__/plpcgRoutes.test.ts`
Expected: PASS.

- [ ] **Step 6: Contrato no spec do coldigom**

Em `docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md`, §8.2, acrescentar um item à lista de rotas, logo depois do item `GET /api/plpcg/resolve/:shortId` (antes do parágrafo `**praises.short_id**` que a Task 3 inseriu):

```markdown
- `POST /api/plpcg/crosswalk` *(23/09, spec coldigui `2026-09-23-fim-fonte-plpcg` §7.2)* → corpo
  `{"pdfIds": [string, …]}` (1 a 500; repetidos contam uma vez) → `200 {"items": {"<pdfId>": {praiseId,
  materialId, url}}}`. Desconhecidos e materiais apagados ficam de fora. `praiseId` é o dono **atual** do
  material e `url` sai do `r2_key` real (acerta fundidos e movidos). `400` fora do contrato;
  `Cache-Control: no-store`. É o que o app usa para normalizar, uma vez, os ids legados que guardou.
```

- [ ] **Step 7: Suíte completa, cobertura no Node do CI, catraca**

Run: `npm run lint && npm run build && npx -y node@22 node_modules/vitest/vitest.mjs run --coverage`
Expected: lint 0 erros, build ok, todos os testes verdes, a linha `All files` acima de 78 / 73 / 80 / 81 (ao planear, com `develop` @ `a5fbc28`: 79.9 / 75.33 / 82.4 / 82.27).

Em `api/vitest.config.ts`, subir a catraca para o piso inteiro do que foi medido e registar a medição, no estilo das linhas anteriores. Com os números de planeamento ficaria:

```ts
      // Contribuições, onda final de revisão (2026-09-17): 78.58 / 73.87 / 80.93 / 81.04
      // short_id + crosswalk (2026-09-23): 79.9 / 75.33 / 82.4 / 82.27
      thresholds: {
        // short_id + crosswalk: medido 79.9 / 75.33 / 82.4 / 82.27
        statements: 79,
        branches: 75,
        functions: 82,
        lines: 82,
      },
```

Usar os números que o comando imprimiu (se diferirem dos de cima, é porque `develop` andou): cada limiar = parte inteira do medido. Voltar a correr `npx -y node@22 node_modules/vitest/vitest.mjs run --coverage` e confirmar que passa.

- [ ] **Step 8: Commit**

```bash
git add api/src/plpcgResolve.ts api/src/routes/plpcg.ts api/src/__tests__/plpcgCrosswalk.test.ts api/src/__tests__/routes.inventory.test.ts api/vitest.config.ts docs/superpowers/specs/2026-09-15-migracao-plpcg-design.md
git commit -m "feat(api): POST /api/plpcg/crosswalk — lote de pdf_id legados para o material atual

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 4 — Entrega

### Task 5: PR, migração remota, deploy e verificação — **só com pedido do dono**

Nenhum passo desta tarefa corre sem o dono pedir. `wrangler … --remote`, `git push` e `gh` são corridos **pelo dono** com `!` (o classificador bloqueia-os para o agente). O agente prepara os comandos, confere as saídas e decide o passo seguinte.

**Ordem obrigatória:** migração 023 no D1 **antes** do Worker novo. O Worker novo lê `p.short_id` no detalhe, na lista e no dump — sem a coluna, as três respondem 500. O Worker antigo convive com o D1 migrado (não lê a coluna, e os INSERTs dele ganham id pelo gatilho).

**Files:** nenhum no repo (D1 remoto `coldigom` e Worker `coldigom-api`).

**Interfaces:**
- Consumes: tudo das Tasks 1–4 mesclado em `develop`.
- Produces: C1 e C2 em produção (`https://coldigom-api.jairofilho79.workers.dev`) — pré-requisito dos planos 1–3 do app (spec §11, unidade 1).

- [ ] **Step 1: PR da feature para `develop`**

```bash
git push -u origin feat/praise-short-id
gh pr create --base develop --title "praises.short_id e POST /api/plpcg/crosswalk (fim da fonte PLPCG, plano 0)" --body "$(cat <<'EOF'
## Resumo
- migração 023: `praises.short_id` (hex `%03x`, único, imutável, sem reuso) atribuído por gatilho em todo INSERT; backfill por `created_at, id`; contador em `app_meta.short_id_next`
- `praises_au` passa a `AFTER UPDATE OF name, lyrics` (o gatilho novo roda antes do `praises_ai` e corrompia o FTS5)
- `short_id` em `GET /api/praises/:id` e `/api/plpcg/praises`; `shortId` no dump `/api/plpcg/catalog` (o ETag muda uma vez)
- `POST /api/plpcg/crosswalk`: lote de até 500 pdf_id legados → praise dono atual, material e URL real; `no-store`
- testes com SQLite de verdade (`node:sqlite`); CI da API em Node 22

Spec: coldigui `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md` §7 · Plano: coldigui `docs/superpowers/plans/2026-09-23-fim-fonte-plpcg-0-coldigom.md`

## Deploy
Migração **antes** do Worker: `cd api && wrangler d1 execute coldigom --remote --file=migrations/023_praise_short_id.sql`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: o portão `PR Mergeable` verde (build, testes com cobertura em Node 22, lint). O dono mescla.

- [ ] **Step 2: Pré-voo no D1 remoto (só leitura)**

```bash
cd api
wrangler d1 execute coldigom --remote --json --command "SELECT sqlite_version() AS v"
wrangler d1 execute coldigom --remote --json --command "SELECT name FROM pragma_table_info('praises') WHERE name = 'short_id'"
wrangler d1 execute coldigom --remote --json --command "SELECT type, name, sql FROM sqlite_master WHERE name IN ('praises_fts', 'praises_ai', 'praises_ad', 'praises_au', 'app_meta')"
wrangler d1 execute coldigom --remote --json --command "SELECT COUNT(*) AS n FROM praises"
wrangler d1 execute coldigom --remote --json --command "INSERT INTO praises_fts(praises_fts, rank) VALUES('integrity-check', 1)"
curl -sI https://coldigom-api.jairofilho79.workers.dev/api/plpcg/catalog | grep -i '^etag'
```

Expected:
- `sqlite_version` ≥ 3.33 (`UPDATE … FROM`).
- Nenhuma coluna `short_id` em `praises`.
- `praises_fts`, `praises_ai`, `praises_ad` e `praises_au` presentes; o `sql` do `praises_au` contém `AFTER UPDATE ON praises` e as duas linhas `INSERT INTO praises_fts…` do `schema.sql`; **nenhuma** linha `app_meta`.
- `n` ≈ 2063 (medido a 23/09).
- O integrity-check termina sem erro. **Se falhar, parar:** o FTS já estava corrompido antes desta migração, e isso é outro problema.
- Anotar o ETag do catálogo (para o Step 7).

Se qualquer expectativa falhar, parar e reportar ao dono antes de migrar.

- [ ] **Step 3: Ponto de restauro**

```bash
wrangler d1 time-travel info coldigom
```

Anotar o `bookmark` impresso. Restauro, só se algo der errado nos Steps 4–5: `wrangler d1 time-travel restore coldigom --bookmark=<bookmark>` (desfaz também qualquer escrita posterior no D1).

- [ ] **Step 4: Aplicar a migração 023**

```bash
wrangler d1 execute coldigom --remote --file=migrations/023_praise_short_id.sql
```

Expected: sucesso, sem erro. **Não repetir** (o `ALTER TABLE` falha na segunda vez).

- [ ] **Step 5: Conferir o D1 migrado**

```bash
wrangler d1 execute coldigom --remote --json --command "SELECT COUNT(*) AS n, COUNT(short_id) AS com_id, COUNT(DISTINCT short_id) AS distintos, MIN(short_id) AS primeiro FROM praises"
wrangler d1 execute coldigom --remote --json --command "SELECT value FROM app_meta WHERE key = 'short_id_next'"
wrangler d1 execute coldigom --remote --json --command "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'praises_%' ORDER BY name"
wrangler d1 execute coldigom --remote --json --command "SELECT id, short_id FROM praises WHERE id = 'c6bd51a8-6a7a-435f-9ca4-4d2968377dbc'"
wrangler d1 execute coldigom --remote --json --command "INSERT INTO praises_fts(praises_fts, rank) VALUES('integrity-check', 1)"
curl -s -o /dev/null -w '%{http_code}\n' https://coldigom-api.jairofilho79.workers.dev/api/plpcg/catalog
```

Expected: `n = com_id = distintos`, `primeiro = 000`; `short_id_next = n`; seis gatilhos (`praises_ad`, `praises_ai`, `praises_au`, `praises_short_id_ai`, `praises_short_id_bi`, `praises_short_id_bu`); o louvor `c6bd51a8…` com um `short_id` hex de 3 dígitos; integrity-check sem erro; o Worker **antigo** ainda responde `200` no catálogo.

- [ ] **Step 6: Deploy do Worker**

O deploy da API é o workflow `deploy-api.yml`, disparado por push em `main` que toque `api/**`. Caminho normal: PR `develop` → `main` (o portão exige `main` ancestral do head — `develop` já inclui `main`), o dono mescla e o workflow corre build, testes com cobertura (Node 22) e `wrangler deploy`.

```bash
gh pr create --base main --head develop --title "develop → main: praises.short_id e crosswalk" --body "$(cat <<'EOF'
Leva para produção o plano 0 do fim da fonte PLPCG (short_id do praise e POST /api/plpcg/crosswalk). A migração 023 já foi aplicada no D1.

Atenção: este PR leva tudo o que está em `develop` e ainda não está em `main`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Antes de o dono mesclar, listar o que vai junto: `git log --oneline origin/main..origin/develop`. Se houver lá coisa que o dono não quer em produção, parar e perguntar. Alternativa manual, só se o dono a escolher: `./deploy-backend.sh` num checkout de `develop` atualizado (faz `npm run build` e `wrangler deploy` em `api/`).

Acompanhar o workflow até ao fim: `gh run list --workflow=deploy-api.yml --limit 1`, depois `gh run watch <id>`.

- [ ] **Step 7: Verificação em produção**

```bash
B=https://coldigom-api.jairofilho79.workers.dev

# C1 — dump: shortId em todos, único, hex; ETag diferente do anotado no Step 2
curl -s -D /tmp/catalog.h -o /tmp/catalog.json "$B/api/plpcg/catalog" && grep -i '^etag' /tmp/catalog.h
python3 - <<'EOF'
import json, re
ps = json.load(open('/tmp/catalog.json'))['praises']
ids = [p.get('shortId') for p in ps]
assert all(i and re.fullmatch(r'[0-9a-f]{3,8}', i) for i in ids), 'praise sem shortId ou fora do formato'
assert len(set(ids)) == len(ids), 'shortId repetido'
print(len(ps), 'praises, todos com shortId único')
EOF

# C1 — detalhe e lista
curl -s "$B/api/praises/c6bd51a8-6a7a-435f-9ca4-4d2968377dbc" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['short_id'])"
curl -s "$B/api/plpcg/praises?limit=1" | python3 -c "import json,sys; print(json.load(sys.stdin)['data'][0]['short_id'])"

# C2 — crosswalk com o pdfId conhecido + um desconhecido
curl -s -D - -X POST "$B/api/plpcg/crosswalk" \
  -H 'content-type: application/json' -H 'origin: https://v2.plpcg.com' \
  -d '{"pdfIds":["TG91dm9yZXMgQ29sZXTDom5lYSBDSUFzLzAwMSAtIE1ldSBEZXVzLCBtZXUgcGFpL0NpZnJhIEkucGRm","nao-existe"]}'

# C2 — preflight e limite
curl -s -o /dev/null -w '%{http_code}\n' -X OPTIONS "$B/api/plpcg/crosswalk" \
  -H 'origin: https://v2.plpcg.com' -H 'access-control-request-method: POST' -H 'access-control-request-headers: content-type'
python3 -c "import json; print(json.dumps({'pdfIds': ['x%d' % i for i in range(501)]}))" \
  | curl -s -o /dev/null -w '%{http_code}\n' -X POST "$B/api/plpcg/crosswalk" -H 'content-type: application/json' -d @-
```

Expected:
- ETag do catálogo **diferente** do anotado no Step 2; o script imprime `≈2063 praises, todos com shortId único`.
- Detalhe e lista imprimem um hex de 3 dígitos (o mesmo `short_id` do Step 5 para `c6bd51a8…`).
- Crosswalk: `HTTP/2 200`, `access-control-allow-origin: https://v2.plpcg.com`, `cache-control: no-store` e o corpo:
  ```json
  {"items":{"TG91dm9yZXMgQ29sZXTDom5lYSBDSUFzLzAwMSAtIE1ldSBEZXVzLCBtZXUgcGFpL0NpZnJhIEkucGRm":{"praiseId":"c6bd51a8-6a7a-435f-9ca4-4d2968377dbc","materialId":"882cb3f9-a10d-450a-a84d-34c19d63f46c","url":"https://coldigom-api.jairofilho79.workers.dev/assets/praises/c6bd51a8-6a7a-435f-9ca4-4d2968377dbc/882cb3f9-a10d-450a-a84d-34c19d63f46c.pdf"}}}
  ```
  (medido a 23/09 pelo `/api/plpcg/manifest`; se o material tiver sido mexido desde então, conferir contra `curl -s "$B/api/plpcg/manifest" | python3 -c "import json,sys; print([e for e in json.load(sys.stdin) if e['pdfId'].startswith('TG91dm9yZXMgQ29sZXTDom5lYSBDSUFzLzAwMSAt')])"`).
- Preflight `204`; lote de 501 → `400`.

- [ ] **Step 8: Se algo falhar depois do deploy**

- Worker com erro e D1 bom: `wrangler rollback` (volta à versão anterior do Worker; o antigo convive com o D1 migrado).
- D1 com problema (integrity-check a falhar, criação de louvor a dar 500): primeiro `wrangler rollback` do Worker (o novo lê a coluna e daria 500 sem ela), depois `wrangler d1 time-travel restore coldigom --bookmark=<bookmark do Step 3>`.

Reportar ao dono o resultado de cada step (saídas coladas), o `short_id_next` final e o ETag novo. Com isto em produção, os planos 1–3 do app podem executar.

---

## Cobertura do spec (self-review)

| Spec | Onde |
|---|---|
| §7.1 migração: coluna + índice único | Task 2 (migração + `schema.sql`) |
| §7.1 backfill `ROW_NUMBER() OVER (ORDER BY created_at, id)` → `printf('%03x', rn - 1)` | Task 2, teste «único e contíguo…» |
| §7.1 contador numa tabela de meta (`app_meta`, não havia genérica; a `gesture_dictionary_meta` é só do dicionário) | Task 2 |
| §7.1 atribuição no INSERT; cliente não escolhe | Task 2 (gatilho — desvio 1 e 3), Task 3 (`POST` ignora `short_id` do corpo) |
| §7.1 imutável em UPDATE, merge e move; nunca reutilizado | Task 2 (SQL), Task 3 (PATCH, merge, move pelas rotas) |
| §7.1 largura dinâmica | Task 2, teste «fff e depois 1000» |
| §7.1 exposição nos três endpoints; ETag muda | Task 3 |
| §7.1 testes: backfill, insert gasta, falha não avança, merge/delete não reutilizam, dump traz `shortId` | Tasks 2 e 3 |
| §7.2 corpo, limite 500, resposta, desconhecidos omitidos | Task 4 |
| §7.2 `url` real (material movido) | Task 4, teste «material movido…» (desvio 6 para o `praiseId`) |
| §7.2 público, CORS do `/resolve`, `no-store` | Task 4 (testes de CORS e preflight) |
| §7.2 testes: lote misto, limite, movido | Task 4 |
| §11 unidade 1: PR e deploy no coldigom antes do app | Task 5 |
