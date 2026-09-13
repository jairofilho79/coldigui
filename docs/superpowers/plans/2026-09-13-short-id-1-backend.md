# shortId — Plano 1/3: backend (Worker `plpcg-catalog` + `plpcg-admin`)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o `shortId` nascer no D1 `plpcg-catalog` (migration + backfill), ser atribuído pelo admin a cada PDF novo, e sair nas duas projeções que os clientes leem: `/api/catalog/louvores` (Worker do coldigui) e `louvores-manifest.json` (publicado pelo admin no R2).

**Architecture:** Coluna `short_id TEXT` (UNIQUE, anulável na transição) em `louvores`; backfill determinístico na própria migration; contador `catalog_meta('short_id_next')` que o admin lê e avança dentro do mesmo `batch` do `INSERT`. Os SELECTs de ambos os Workers projetam a coluna; `mapRow` emite `shortId` só quando não nulo. O `shortId` entra no checksum canônico do catálogo para que a ETag do Worker mude e o v2 rebaixe o catálogo.

**Tech Stack:** Cloudflare Workers + D1 (SQLite), TypeScript. coldigui Worker: `node --test` com `--experimental-strip-types`. Admin: Hono + vitest; UI Vite/TS vanilla.

**Spec:** `docs/superpowers/specs/2026-09-13-short-id-share-design.md` (§0 D1–D5, §2, §4.1, §5 passos 1–2)

## Global Constraints

- `shortId` é **string** hex minúscula, `[0-9a-f]{4,8}`; `"0000"` é válido. Conversão para número só dentro de `plpcg-admin/worker/src/services/short-id.ts` (para incrementar); todo retorno/armazenamento é string.
- Imutável, único, nunca reutilizado. `deleteLouvor` não devolve id ao contador.
- Migration canônica: `coldigui/workers/plpcg-catalog/migrations/0011_add_louvores_short_id.sql`. Espelho para D1 local do admin: `plpcg-admin/worker/migrations/0003_add_short_id.sql` (mesmo SQL, cabeçalho de aviso). **Remoto só via coldigui** (`npm run db:migrate:remote`).
- Backfill: `ROW_NUMBER() OVER (ORDER BY numero, nome, categoria, pdf_id) - 1` → `printf('%04x', …)`; `short_id_next = printf('%04x', COUNT(*))`.
- JSON: campo `shortId` **omitido** quando `short_id IS NULL` (nunca `"shortId": null`).
- Repositórios: coldigui (worktree `.claude/worktrees/short-id-share`, branch `feat/short-id-share`); `plpcg-admin` em `/Volumes/SSD 2TB SD/dev/plpcg-admin` — criar branch `feat/short-id-share` a partir de `main` na Task 4.
- Commits terminam com as duas linhas de atribuição da sessão (ver system-reminder do harness).

---

## Mapa de arquivos

**coldigui (`workers/plpcg-catalog/`)**
- Create: `migrations/0011_add_louvores_short_id.sql`
- Create: `src/catalog/louvor_row.ts` — `LouvorRow`, `LouvorJson`, `LOUVOR_SELECT_COLUMNS`, `mapRow` (extraídos de `src/index.ts`)
- Create: `src/catalog/louvor_row.test.ts`
- Modify: `src/index.ts:41-59` (remover tipos duplicados), `:180-191` (remover `mapRow`), `:225-232` (SELECT)
- Modify: `../../scripts/seed_d1_louvores.py:25-80`
- Modify: `README.md` (tabela de endpoints + nota da migration compartilhada)

**plpcg-admin**
- Create: `worker/migrations/0003_add_short_id.sql`
- Create: `worker/src/services/short-id.ts`, `worker/src/services/short-id.test.ts`
- Create: `worker/src/test/fake-d1.ts` (D1 falso mínimo, grava SQL + binds)
- Create: `worker/src/services/d1-catalog.test.ts`
- Modify: `worker/src/types.ts` (`LouvorRow.short_id`, `LouvorJson.shortId?`, `LOUVOR_COLUMNS`)
- Modify: `worker/src/domain/checksum.ts` (`mapRow`, `canonicalEntry`, `CANONICAL_FIELDS`, `fetchAllLouvores`)
- Modify: `worker/src/domain/manifest.ts` + `manifest.test.ts`
- Modify: `worker/src/services/d1-catalog.ts` (todos os SELECT; `insertLouvor`; `updateLouvor`)
- Modify: `worker/src/routes/louvores.ts:119-160` (POST devolve `shortId`), `worker/src/routes/manifest.ts:21-27` (`updateCatalogMeta` antes de publicar)
- Modify: `ui/src/api/client.ts:1-10`, `ui/src/app.ts:390-406, 676-680`, `ui/src/styles/main.css`
- Modify: `README.md` (nota da migration)

---

### Task 1: Migration canônica no coldigui + validação local

**Files:**
- Create: `workers/plpcg-catalog/migrations/0011_add_louvores_short_id.sql`

**Interfaces:**
- Produces: coluna `louvores.short_id TEXT` (UNIQUE via `idx_louvores_short_id`), linha `catalog_meta('short_id_next')`.

- [ ] **Step 1: Escrever a migration**

```sql
-- Migration number: 0011  2026-09-13T00:00:00.000Z
-- shortId por material PDF (spec 2026-09-13-short-id-share-design §0 D1–D5).
-- String hex minúscula, 4 chars hoje; UNIQUE; nunca reutilizado.
-- Backfill determinístico: ordem (numero, nome, categoria, pdf_id) a partir de '0000'.
-- Este arquivo é a versão CANÔNICA. plpcg-admin/worker/migrations/0003_add_short_id.sql
-- é um espelho só para o D1 local do admin — no remoto, aplicar SOMENTE daqui.
ALTER TABLE louvores ADD COLUMN short_id TEXT;

UPDATE louvores
SET short_id = numbered.short_id
FROM (
  SELECT
    pdf_id,
    printf('%04x', ROW_NUMBER() OVER (ORDER BY numero, nome, categoria, pdf_id) - 1) AS short_id
  FROM louvores
) AS numbered
WHERE louvores.pdf_id = numbered.pdf_id;

CREATE UNIQUE INDEX idx_louvores_short_id ON louvores(short_id);

INSERT OR REPLACE INTO catalog_meta (key, value)
VALUES ('short_id_next', (SELECT printf('%04x', COUNT(*)) FROM louvores));
```

- [ ] **Step 2: Preparar D1 local com catálogo real e aplicar**

Run (na raiz do worktree; o manifest de produção alimenta o seed):
```bash
mkdir -p tmp && curl -s https://plpcg.com/louvores-manifest.json -o tmp/louvores-manifest-grouped.json
python3 scripts/seed_d1_louvores.py --input tmp/louvores-manifest-grouped.json
cd workers/plpcg-catalog
npx wrangler d1 migrations apply plpcg-catalog --local
npx wrangler d1 execute plpcg-catalog --local --file seed/001_louvores.sql
```
Expected: a lista de migrations aplicadas termina em `0011_add_louvores_short_id.sql` sem erro. Se `0011` já constava aplicada antes do seed (banco local zerado), tudo bem — o seed usa `INSERT OR REPLACE` e **não** preenche `short_id`; nesse caso rode o passo abaixo para refazer o backfill:

```bash
npx wrangler d1 execute plpcg-catalog --local --command "UPDATE louvores SET short_id = numbered.short_id FROM (SELECT pdf_id, printf('%04x', ROW_NUMBER() OVER (ORDER BY numero, nome, categoria, pdf_id) - 1) AS short_id FROM louvores) AS numbered WHERE louvores.pdf_id = numbered.pdf_id; INSERT OR REPLACE INTO catalog_meta (key, value) VALUES ('short_id_next', (SELECT printf('%04x', COUNT(*)) FROM louvores));"
```

- [ ] **Step 3: Verificar invariantes**

Run:
```bash
npx wrangler d1 execute plpcg-catalog --local --json --command "SELECT COUNT(*) AS total, COUNT(DISTINCT short_id) AS distintos, MIN(short_id) AS menor, MAX(short_id) AS maior, SUM(short_id IS NULL) AS nulos FROM louvores; SELECT value FROM catalog_meta WHERE key = 'short_id_next';"
```
Expected: `total == distintos`, `menor == "0000"`, `nulos == 0`, `maior == printf('%04x', total-1)` (para 4627 linhas: `"1212"`), e `short_id_next == "1213"`. Confirme também que os valores vêm como **strings** com zeros à esquerda no JSON.

- [ ] **Step 4: Commit**

```bash
git add workers/plpcg-catalog/migrations/0011_add_louvores_short_id.sql
git commit -m "feat(worker): migration 0011 — louvores.short_id com backfill determinístico"
```

---

### Task 2: Worker `plpcg-catalog` emite `shortId`

**Files:**
- Create: `workers/plpcg-catalog/src/catalog/louvor_row.ts`
- Create: `workers/plpcg-catalog/src/catalog/louvor_row.test.ts`
- Modify: `workers/plpcg-catalog/src/index.ts:41-59, 180-191, 225-232`

**Interfaces:**
- Produces: `export interface LouvorRow { …; short_id: string | null }`, `export interface LouvorJson { …; shortId?: string }`, `export const LOUVOR_SELECT_COLUMNS = 'nome, numero, classificacao, categoria, pdf, pdf_id, group_id, short_id'`, `export function mapRow(row: LouvorRow): LouvorJson`.
- `GET /api/catalog/louvores` passa a incluir `"shortId": "1a2f"` por item quando preenchido.

- [ ] **Step 1: Teste que falha**

`src/catalog/louvor_row.test.ts`:
```ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { LOUVOR_SELECT_COLUMNS, mapRow } from './louvor_row.ts';

const base = {
  nome: 'Teste',
  numero: '001',
  classificacao: 'ColAdultos',
  categoria: 'Partitura',
  pdf: '001.pdf',
  pdf_id: 'Q29sQWR1bHRvcy8wMDEucGRm',
  group_id: '001:teste',
};

test('mapRow emite shortId como string quando preenchido', () => {
  const json = mapRow({ ...base, short_id: '0000' });
  assert.equal(json.shortId, '0000');
  assert.equal(typeof json.shortId, 'string');
});

test('mapRow omite a chave shortId quando short_id é null', () => {
  const json = mapRow({ ...base, short_id: null });
  assert.equal('shortId' in json, false);
  assert.deepEqual(Object.keys(json), [
    'nome', 'numero', 'classificacao', 'categoria', 'pdf', 'pdfId', 'groupId',
  ]);
});

test('SELECT projeta short_id', () => {
  assert.match(LOUVOR_SELECT_COLUMNS, /\bshort_id\b/);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd workers/plpcg-catalog && npm test`
Expected: FAIL — `Cannot find module './louvor_row.ts'`.

- [ ] **Step 3: Criar o módulo e mover os tipos**

`src/catalog/louvor_row.ts`:
```ts
/**
 * Linha de `louvores` e sua projeção JSON pública (`/api/catalog/louvores`).
 *
 * `short_id` (spec short-id-share D1) é string hex — nunca converter em
 * número. Omitido do JSON enquanto for NULL (transição), para o cliente não
 * ver `"shortId": null`.
 */
export interface LouvorRow {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdf_id: string;
  group_id: string;
  short_id: string | null;
}

export interface LouvorJson {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdfId: string;
  groupId: string;
  shortId?: string;
}

export const LOUVOR_SELECT_COLUMNS =
  'nome, numero, classificacao, categoria, pdf, pdf_id, group_id, short_id';

export function mapRow(row: LouvorRow): LouvorJson {
  const json: LouvorJson = {
    nome: row.nome,
    numero: row.numero,
    classificacao: row.classificacao,
    categoria: row.categoria,
    pdf: row.pdf,
    pdfId: row.pdf_id,
    groupId: row.group_id,
  };
  if (row.short_id) {
    json.shortId = row.short_id;
  }
  return json;
}
```

Em `src/index.ts`:
- apagar `interface LouvorRow` e `interface LouvorJson` (linhas 41–59) e a função `mapRow` (180–191);
- adicionar `import { LOUVOR_SELECT_COLUMNS, mapRow, type LouvorRow } from './catalog/louvor_row';`
- em `fetchLouvores`, trocar o SELECT por:
```ts
  const result = await db
    .prepare(
      `SELECT ${LOUVOR_SELECT_COLUMNS}
       FROM louvores
       ORDER BY numero, nome`,
    )
    .all<LouvorRow>();
```

- [ ] **Step 4: Rodar testes + typecheck**

Run: `cd workers/plpcg-catalog && npm test && npx tsc --noEmit`
Expected: `pass 107`, `fail 0`; `tsc` sem erros.

- [ ] **Step 5: Smoke local**

Run: `cd workers/plpcg-catalog && (npm run dev &) ; sleep 6; curl -s http://127.0.0.1:8787/api/catalog/louvores | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d), d[0].get('shortId'), sum('shortId' in x for x in d))"; kill %1`
Expected: `4627 <hex de 4 chars> 4627`.

- [ ] **Step 6: Commit**

```bash
git add workers/plpcg-catalog/src
git commit -m "feat(worker): /api/catalog/louvores emite shortId; mapRow extraído para catalog/louvor_row"
```

---

### Task 3: Seed script e README do Worker

**Files:**
- Modify: `scripts/seed_d1_louvores.py:25-80`
- Modify: `workers/plpcg-catalog/README.md`

- [ ] **Step 1: Seed passa `shortId` → `short_id` e o inclui no checksum canônico**

Em `CANONICAL_FIELDS` acrescentar `"shortId"` no fim da tupla. Em `build_insert`:
```python
def build_insert(entry: dict) -> str:
    nome = sql_escape(str(entry.get("nome", "")))
    numero = sql_escape(str(entry.get("numero", "") or ""))
    classificacao = sql_escape(str(entry.get("classificacao", "")))
    categoria = sql_escape(str(entry.get("categoria", "")))
    pdf = sql_escape(str(entry.get("pdf", "")))
    pdf_id = sql_escape(str(entry["pdfId"]))
    group_id = sql_escape(str(entry.get("groupId", "") or ""))
    short_id = entry.get("shortId")
    # shortId é string hex ("0000" é válido) — nunca int(); NULL quando o
    # manifest ainda não traz o campo (o backfill da migration 0011 preenche).
    short_id_sql = f"'{sql_escape(str(short_id))}'" if isinstance(short_id, str) and short_id else "NULL"
    return (
        f"INSERT OR REPLACE INTO louvores "
        f"(pdf_id, nome, numero, classificacao, categoria, pdf, group_id, short_id) "
        f"VALUES ('{pdf_id}', '{nome}', '{numero}', '{classificacao}', "
        f"'{categoria}', '{pdf}', '{group_id}', {short_id_sql});"
    )
```

- [ ] **Step 2: Verificar rapidamente**

Run: `python3 - <<'EOF'
import importlib.util, json
spec = importlib.util.spec_from_file_location("seed", "scripts/seed_d1_louvores.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.build_insert({"pdfId":"x","shortId":"0000"}))
print(m.build_insert({"pdfId":"x"}))
print("shortId" in m.CANONICAL_FIELDS)
EOF`
Expected: primeira linha termina em `'', '0000');`, segunda em `'', NULL);`, terceira `True`.

- [ ] **Step 3: README**

Na tabela de endpoints, linha de `/api/catalog/louvores`: `Array JSON de louvores (\`groupId\` e \`shortId\` incluídos)`. Após a seção «Deploy remoto», acrescentar:

```markdown
## Migrations e o D1 compartilhado

O D1 `plpcg-catalog` também é usado pelo `plpcg-admin` (mesmo `database_id`). **Este Worker é o dono das migrations remotas** (`npm run db:migrate:remote`). O admin mantém em `worker/migrations/` só o que precisa para o D1 local dele; a `0011_add_louvores_short_id.sql` daqui tem um espelho lá (`0003_add_short_id.sql`) que **não** deve ser aplicado no remoto.
```

- [ ] **Step 4: Commit**

```bash
git add scripts/seed_d1_louvores.py workers/plpcg-catalog/README.md
git commit -m "chore(worker): seed grava short_id; README documenta dono da migration"
```

---

### Task 4: `plpcg-admin` — branch, migration espelho, tipos e colunas

**Files (repo `/Volumes/SSD 2TB SD/dev/plpcg-admin`):**
- Create: `worker/migrations/0003_add_short_id.sql`
- Modify: `worker/src/types.ts:11-29`
- Modify: `worker/src/domain/checksum.ts` (tudo)
- Modify: `worker/src/services/d1-catalog.ts` (os 7 SELECTs com a lista de colunas: linhas 57, 78, 145, 193, 226 e as demais que projetam `nome, numero, …, group_id`)

**Interfaces:**
- Produces: `LouvorRow.short_id: string | null`; `LouvorJson.shortId?: string`; `export const LOUVOR_COLUMNS = 'nome, numero, classificacao, categoria, pdf, pdf_id, group_id, short_id'` em `types.ts`; `mapRow` omite `shortId` nulo; `CANONICAL_FIELDS` inclui `'shortId'`.

- [ ] **Step 1: Branch**

Run: `cd "/Volumes/SSD 2TB SD/dev/plpcg-admin" && git status --short && git checkout -b feat/short-id-share main`
Expected: árvore limpa, branch criada.

- [ ] **Step 2: Migration espelho**

`worker/migrations/0003_add_short_id.sql` — **mesmo SQL** da Task 1, com este cabeçalho no lugar do original:
```sql
-- Migration number: 0003  2026-09-13T00:00:00.000Z
-- ESPELHO de coldigui/workers/plpcg-catalog/migrations/0011_add_louvores_short_id.sql.
-- Serve SÓ para o D1 local deste repo (`npm run db:migrate:local`).
-- No D1 remoto compartilhado, esta migration é aplicada pelo coldigui — NÃO rodar aqui.
```
(seguido de `ALTER TABLE … ; UPDATE … FROM … ; CREATE UNIQUE INDEX … ; INSERT OR REPLACE INTO catalog_meta …` idênticos.)

- [ ] **Step 3: Teste que falha — `mapRow`/`canonicalEntry`**

Acrescentar a `worker/src/domain/domain.test.ts`:
```ts
import { CANONICAL_FIELDS, canonicalEntry, mapRow } from './checksum';

describe('short-id no mapRow/checksum', () => {
  const row = {
    nome: 'T', numero: '1', classificacao: 'C', categoria: 'Partitura',
    pdf: '1.pdf', pdf_id: 'abc', group_id: '1:t', short_id: '0000',
  };
  it('mapRow copia short_id como shortId (string)', () => {
    expect(mapRow(row).shortId).toBe('0000');
  });
  it('mapRow omite shortId quando null', () => {
    expect('shortId' in mapRow({ ...row, short_id: null })).toBe(false);
  });
  it('shortId entra no canônico do checksum (vazio quando ausente)', () => {
    expect(CANONICAL_FIELDS).toContain('shortId');
    expect(canonicalEntry(mapRow(row)).shortId).toBe('0000');
    expect(canonicalEntry(mapRow({ ...row, short_id: null })).shortId).toBe('');
  });
});
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `cd worker && npx vitest run src/domain/domain.test.ts`
Expected: FAIL (tipo `short_id` inexistente / `shortId` undefined).

- [ ] **Step 5: Implementar tipos e checksum**

`worker/src/types.ts` — substituir `LouvorRow`/`LouvorJson` e adicionar a constante:
```ts
export interface LouvorRow {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdf_id: string;
  group_id: string;
  /** Hex minúsculo, string. NULL só durante a transição (antes do backfill). */
  short_id: string | null;
}

export interface LouvorJson {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdfId: string;
  groupId: string;
  /** Ausente quando ainda não atribuído. Nunca `null` no JSON. */
  shortId?: string;
}

/** Projeção padrão de `louvores` — única lista de colunas para todos os SELECTs. */
export const LOUVOR_COLUMNS =
  'nome, numero, classificacao, categoria, pdf, pdf_id, group_id, short_id';
```

`worker/src/domain/checksum.ts`:
```ts
const CANONICAL_FIELDS = [
  'nome', 'numero', 'classificacao', 'categoria', 'pdf', 'pdfId', 'groupId', 'shortId',
] as const;

function mapRow(row: LouvorRow): LouvorJson {
  const json: LouvorJson = {
    nome: row.nome,
    numero: row.numero,
    classificacao: row.classificacao,
    categoria: row.categoria,
    pdf: row.pdf,
    pdfId: row.pdf_id,
    groupId: row.group_id,
  };
  if (row.short_id) json.shortId = row.short_id;
  return json;
}

function canonicalEntry(entry: LouvorJson): Record<string, string> {
  return {
    nome: entry.nome ?? '',
    numero: entry.numero ?? '',
    classificacao: entry.classificacao ?? '',
    categoria: entry.categoria ?? '',
    pdf: entry.pdf ?? '',
    pdfId: entry.pdfId ?? '',
    groupId: entry.groupId ?? '',
    shortId: entry.shortId ?? '',
  };
}
```
e em `fetchAllLouvores` usar `` `SELECT ${LOUVOR_COLUMNS} FROM louvores ORDER BY pdf_id` `` (importar `LOUVOR_COLUMNS` de `../types`).

`worker/src/services/d1-catalog.ts`: importar `LOUVOR_COLUMNS` e trocar **cada** `SELECT nome, numero, classificacao, categoria, pdf, pdf_id, group_id` por `` SELECT ${LOUVOR_COLUMNS} `` (template string). Confirme com `grep -n "SELECT nome" src/services/d1-catalog.ts` que não sobrou nenhum.

- [ ] **Step 6: Rodar tudo**

Run: `cd worker && npx vitest run && npx tsc --noEmit`
Expected: verde; `tsc` limpo.

- [ ] **Step 7: Commit**

```bash
git add worker/migrations/0003_add_short_id.sql worker/src/types.ts worker/src/domain/checksum.ts worker/src/domain/domain.test.ts worker/src/services/d1-catalog.ts
git commit -m "feat(catalog): coluna short_id — tipos, projeção única e checksum canônico; migration espelho local"
```

---

### Task 5: `plpcg-admin` — alocação do `shortId` (`services/short-id.ts`)

**Files:**
- Create: `worker/src/services/short-id.ts`
- Create: `worker/src/services/short-id.test.ts`

**Interfaces:**
- Produces: `export function incrementShortId(current: string): string`; `export function isShortId(value: unknown): value is string`; `export async function readNextShortId(db: D1Database): Promise<string>`; `export function advanceShortIdStatement(db: D1Database, current: string): D1PreparedStatement`.

- [ ] **Step 1: Teste que falha**

`worker/src/services/short-id.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { incrementShortId, isShortId } from './short-id';

describe('incrementShortId', () => {
  it('avança mantendo 4 chars e zeros à esquerda', () => {
    expect(incrementShortId('0000')).toBe('0001');
    expect(incrementShortId('00ff')).toBe('0100');
    expect(incrementShortId('0fff')).toBe('1000');
  });
  it('cruza ffff → 10000 sem padding artificial', () => {
    expect(incrementShortId('ffff')).toBe('10000');
    expect(incrementShortId('10000')).toBe('10001');
  });
  it('devolve sempre string minúscula', () => {
    expect(incrementShortId('00AB')).toBe('00ac');
  });
  it('rejeita entrada fora do padrão', () => {
    expect(() => incrementShortId('')).toThrow();
    expect(() => incrementShortId('zz')).toThrow();
    expect(() => incrementShortId('123456789')).toThrow();
  });
});

describe('isShortId', () => {
  it('aceita [0-9a-f]{4,8}', () => {
    expect(isShortId('0000')).toBe(true);
    expect(isShortId('1a2f')).toBe(true);
    expect(isShortId('10000')).toBe(true);
  });
  it('recusa número, maiúscula, curto, longo', () => {
    expect(isShortId(0)).toBe(false);
    expect(isShortId('1A2F')).toBe(false);
    expect(isShortId('abc')).toBe(false);
    expect(isShortId('123456789')).toBe(false);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd worker && npx vitest run src/services/short-id.test.ts`
Expected: FAIL — módulo inexistente.

- [ ] **Step 3: Implementar**

`worker/src/services/short-id.ts`:
```ts
/**
 * Alocação de `shortId` (spec short-id-share §0 D1, D4, D5; §2.1).
 *
 * O contador vive em `catalog_meta('short_id_next')` como **string hex**. A
 * única conversão para número do sistema inteiro acontece em
 * `incrementShortId`, e o resultado volta a ser string antes de sair daqui.
 * Ids nunca são reutilizados: `deleteLouvor` não mexe no contador.
 */
const SHORT_ID_PATTERN = /^[0-9a-f]{4,8}$/;
export const SHORT_ID_NEXT_KEY = 'short_id_next';

export function isShortId(value: unknown): value is string {
  return typeof value === 'string' && SHORT_ID_PATTERN.test(value);
}

export function incrementShortId(current: string): string {
  const normalized = current.toLowerCase();
  if (!isShortId(normalized)) {
    throw new Error(`short_id_next inválido: ${JSON.stringify(current)}`);
  }
  // Passar de 'ffff' dá '10000' naturalmente — sem truque de padding (D5).
  return (parseInt(normalized, 16) + 1).toString(16).padStart(4, '0');
}

/** Lê o próximo id livre. Lança se o contador não existir (migration 0011/0003 não aplicada). */
export async function readNextShortId(db: D1Database): Promise<string> {
  const row = await db
    .prepare('SELECT value FROM catalog_meta WHERE key = ?')
    .bind(SHORT_ID_NEXT_KEY)
    .first<{ value: string }>();
  if (!row || !isShortId(row.value)) {
    throw new Error('catalog_meta.short_id_next ausente ou inválido — aplique a migration de short_id');
  }
  return row.value;
}

/**
 * Statement que avança o contador de `current` para o seguinte. Vai no mesmo
 * `db.batch` do INSERT que consome `current`, para um INSERT que falha não
 * gastar id. O `AND value = ?` protege contra dois admins simultâneos: o
 * segundo não avança (0 linhas) — situação que o único admin nunca produz.
 */
export function advanceShortIdStatement(db: D1Database, current: string): D1PreparedStatement {
  return db
    .prepare('UPDATE catalog_meta SET value = ? WHERE key = ? AND value = ?')
    .bind(incrementShortId(current), SHORT_ID_NEXT_KEY, current);
}
```

- [ ] **Step 4: Rodar**

Run: `cd worker && npx vitest run src/services/short-id.test.ts`
Expected: PASS (8 testes).

- [ ] **Step 5: Commit**

```bash
git add worker/src/services/short-id.ts worker/src/services/short-id.test.ts
git commit -m "feat(catalog): alocação de shortId — incremento hex como string e contador em catalog_meta"
```

---

### Task 6: `plpcg-admin` — `insertLouvor` consome id; `updateLouvor` preserva no rename

**Files:**
- Create: `worker/src/test/fake-d1.ts`
- Create: `worker/src/services/d1-catalog.test.ts`
- Modify: `worker/src/services/d1-catalog.ts:236-290` (`insertLouvor`, `updateLouvor`)
- Modify: `worker/src/routes/louvores.ts:150-153` (POST devolve `shortId`)

**Interfaces:**
- Produces: `insertLouvor(db, entry: LouvorJson): Promise<LouvorJson>` — devolve `entry` com `shortId` atribuído. `updateLouvor(db, oldPdfId, entry)` mantém assinatura; ignora `entry.shortId`.

- [ ] **Step 1: D1 falso mínimo**

`worker/src/test/fake-d1.ts`:
```ts
/**
 * D1 falso para testar a forma dos statements (SQL + binds) e o uso de
 * `batch`. Não interpreta SQL: `first()` devolve o que `onFirst` decidir
 * pelo texto da consulta.
 */
export interface Executed {
  sql: string;
  binds: unknown[];
  via: 'run' | 'first' | 'all' | 'batch';
}

export function fakeD1(onFirst: (sql: string, binds: unknown[]) => unknown = () => null) {
  const executed: Executed[] = [];
  const stmt = (sql: string, binds: unknown[] = []) => ({
    bind: (...args: unknown[]) => stmt(sql, args),
    first: async <T>() => {
      executed.push({ sql, binds, via: 'first' });
      return onFirst(sql, binds) as T | null;
    },
    run: async () => {
      executed.push({ sql, binds, via: 'run' });
      return { meta: { changes: 1 } };
    },
    all: async <T>() => {
      executed.push({ sql, binds, via: 'all' });
      return { results: [] as T[] };
    },
    __sql: sql,
    __binds: binds,
  });
  const db = {
    prepare: (sql: string) => stmt(sql),
    batch: async (stmts: Array<{ __sql: string; __binds: unknown[] }>) => {
      for (const s of stmts) executed.push({ sql: s.__sql, binds: s.__binds, via: 'batch' });
      return stmts.map(() => ({ meta: { changes: 1 } }));
    },
  } as unknown as D1Database;
  return { db, executed };
}
```

- [ ] **Step 2: Teste que falha**

`worker/src/services/d1-catalog.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { fakeD1 } from '../test/fake-d1';
import { insertLouvor, updateLouvor } from './d1-catalog';
import type { LouvorJson } from '../types';

const entry: LouvorJson = {
  nome: 'T', numero: '1', classificacao: 'C', categoria: 'Partitura',
  pdf: '1.pdf', pdfId: 'novo', groupId: '1:t',
};

describe('insertLouvor', () => {
  it('lê short_id_next, insere com ele e avança o contador no mesmo batch', async () => {
    const { db, executed } = fakeD1((sql) =>
      sql.includes('catalog_meta') ? { value: '00ff' } : null,
    );
    const saved = await insertLouvor(db, entry);
    expect(saved.shortId).toBe('00ff');

    const batch = executed.filter((e) => e.via === 'batch');
    expect(batch).toHaveLength(2);
    expect(batch[0].sql).toMatch(/INSERT INTO louvores/);
    expect(batch[0].sql).toMatch(/short_id/);
    expect(batch[0].binds).toContain('00ff');
    expect(batch[1].sql).toMatch(/UPDATE catalog_meta SET value = \?/);
    expect(batch[1].binds).toEqual(['0100', 'short_id_next', '00ff']);
  });

  it('ignora shortId vindo do cliente', async () => {
    const { db, executed } = fakeD1((sql) =>
      sql.includes('catalog_meta') ? { value: '0000' } : null,
    );
    const saved = await insertLouvor(db, { ...entry, shortId: 'ffff' });
    expect(saved.shortId).toBe('0000');
    expect(executed.find((e) => e.via === 'batch')!.binds).not.toContain('ffff');
  });

  it('falha antes de inserir se o contador não existe', async () => {
    const { db, executed } = fakeD1(() => null);
    await expect(insertLouvor(db, entry)).rejects.toThrow(/short_id_next/);
    expect(executed.some((e) => e.via === 'batch')).toBe(false);
  });
});

describe('updateLouvor', () => {
  it('mesmo pdfId: UPDATE sem tocar em short_id', async () => {
    const { db, executed } = fakeD1();
    await updateLouvor(db, 'novo', entry);
    const upd = executed.find((e) => e.sql.startsWith('UPDATE louvores'))!;
    expect(upd.sql).not.toMatch(/short_id/);
  });

  it('rename de pdfId: carrega o short_id antigo e o grava na linha nova', async () => {
    const { db, executed } = fakeD1((sql) =>
      sql.includes('SELECT short_id') ? { short_id: '0a0a' } : null,
    );
    await updateLouvor(db, 'antigo', entry);
    const batch = executed.filter((e) => e.via === 'batch');
    expect(batch[0].sql).toMatch(/DELETE FROM louvores/);
    expect(batch[1].sql).toMatch(/INSERT INTO louvores/);
    expect(batch[1].binds).toContain('0a0a');
    expect(batch[1].binds).not.toContain(null);
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd worker && npx vitest run src/services/d1-catalog.test.ts`
Expected: FAIL (`saved` é `undefined`; batch sem `short_id`).

- [ ] **Step 4: Implementar**

Em `worker/src/services/d1-catalog.ts`, importar `advanceShortIdStatement, readNextShortId` de `./short-id` e substituir `insertLouvor`/`updateLouvor`:
```ts
const INSERT_SQL = `INSERT INTO louvores (pdf_id, nome, numero, classificacao, categoria, pdf, group_id, short_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;

function insertBinds(entry: LouvorJson, shortId: string): unknown[] {
  return [
    entry.pdfId, entry.nome, entry.numero, entry.classificacao,
    entry.categoria, entry.pdf, entry.groupId, shortId,
  ];
}

/**
 * Insere consumindo o próximo `shortId` (spec §2.1). O cliente não escolhe o
 * id: `entry.shortId` é ignorado. INSERT e avanço do contador vão no mesmo
 * batch — INSERT que falha não gasta id.
 */
export async function insertLouvor(db: D1Database, entry: LouvorJson): Promise<LouvorJson> {
  const shortId = await readNextShortId(db);
  await db.batch([
    db.prepare(INSERT_SQL).bind(...insertBinds(entry, shortId)),
    advanceShortIdStatement(db, shortId),
  ]);
  return { ...entry, shortId };
}

/**
 * Invariante: `short_id` nunca muda. No rename de `pdf_id` (delete+insert) o
 * id da linha antiga é lido antes e gravado na nova.
 */
export async function updateLouvor(
  db: D1Database,
  oldPdfId: string,
  entry: LouvorJson,
): Promise<void> {
  if (oldPdfId === entry.pdfId) {
    await db
      .prepare(
        `UPDATE louvores SET nome = ?, numero = ?, classificacao = ?, categoria = ?, pdf = ?, group_id = ?
         WHERE pdf_id = ?`,
      )
      .bind(entry.nome, entry.numero, entry.classificacao, entry.categoria, entry.pdf, entry.groupId, oldPdfId)
      .run();
    return;
  }

  const current = await db
    .prepare('SELECT short_id FROM louvores WHERE pdf_id = ?')
    .bind(oldPdfId)
    .first<{ short_id: string | null }>();
  // Linha ainda sem short_id (transição pré-backfill): aloca um agora, para
  // a nova linha nunca nascer sem id.
  const shortId = current?.short_id ?? (await readNextShortId(db));
  const statements = [
    db.prepare('DELETE FROM louvores WHERE pdf_id = ?').bind(oldPdfId),
    db.prepare(INSERT_SQL).bind(...insertBinds(entry, shortId)),
  ];
  if (!current?.short_id) statements.push(advanceShortIdStatement(db, shortId));
  await db.batch(statements);
}
```

Em `worker/src/routes/louvores.ts` (POST, linhas ~150–153):
```ts
    const entry = toLouvorJson(parsed.data, pdfId);
    const saved = await insertLouvor(c.env.DB, entry);
    const meta = await updateCatalogMeta(c.env.DB);
    return c.json({ louvor: saved, publicUrl: publicPdfUrl(pdfId), meta }, 201);
```

- [ ] **Step 5: Rodar tudo**

Run: `cd worker && npx vitest run && npx tsc --noEmit`
Expected: verde.

- [ ] **Step 6: Commit**

```bash
git add worker/src/test/fake-d1.ts worker/src/services/d1-catalog.test.ts worker/src/services/d1-catalog.ts worker/src/routes/louvores.ts
git commit -m "feat(catalog): insert consome shortId no batch; rename de pdfId preserva short_id"
```

---

### Task 7: `plpcg-admin` — manifest com `shortId` e publicar atualiza `catalog_meta`

**Files:**
- Modify: `worker/src/domain/manifest.ts:5-18`
- Modify: `worker/src/domain/manifest.test.ts`
- Modify: `worker/src/routes/manifest.ts:21-27`

- [ ] **Step 1: Teste que falha**

Em `worker/src/domain/manifest.test.ts`, dentro de `describe('manifest')`:
```ts
  it('inclui shortId como string quando presente, depois de groupId', () => {
    const entry = toManifestEntry({ ...sample, shortId: '0000' });
    expect(entry.shortId).toBe('0000');
    expect(Object.keys(entry).slice(-2)).toEqual(['groupId', 'shortId']);
  });

  it('omite shortId quando ausente', () => {
    expect('shortId' in toManifestEntry(sample)).toBe(false);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd worker && npx vitest run src/domain/manifest.test.ts`
Expected: FAIL no primeiro teste novo.

- [ ] **Step 3: Implementar**

`worker/src/domain/manifest.ts`, em `toManifestEntry`, após o bloco do `groupId`:
```ts
  // String hex — o plpcjf e o v2 comparam textualmente, nunca como número.
  if (louvor.shortId) {
    entry.shortId = louvor.shortId;
  }
```

`worker/src/routes/manifest.ts`: importar `updateCatalogMeta` de `../domain/checksum` e, no início do handler:
```ts
app.post('/api/admin/manifest/publish', async (c) => {
  // «Publicar» atualiza as duas projeções: o checksum/ETag que o Worker do v2
  // serve (catalog_meta) e o manifest do plpcjf (R2). Sem isto, um backfill
  // feito por migration não mudaria o checksum e o v2 nunca rebaixaria.
  await updateCatalogMeta(c.env.DB);
  const louvores = await fetchAllLouvores(c.env.DB);
```

- [ ] **Step 4: Rodar**

Run: `cd worker && npx vitest run && npx tsc --noEmit`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add worker/src/domain/manifest.ts worker/src/domain/manifest.test.ts worker/src/routes/manifest.ts
git commit -m "feat(manifest): publica shortId e recalcula catalog_meta ao publicar"
```

---

### Task 8: `plpcg-admin` — UI mostra `shortId` (somente leitura) e README

**Files:**
- Modify: `ui/src/api/client.ts:1-10`
- Modify: `ui/src/app.ts:390-406` (`buildPdfRow`), `:676-680` (form de edição)
- Modify: `ui/src/styles/main.css` (junto de `.pdf-classif`, linha ~259)
- Modify: `README.md`

- [ ] **Step 1: Tipo**

`ui/src/api/client.ts`, em `interface Louvor`, após `groupId: string;`:
```ts
  /** Id curto de share (hex, string). Ausente enquanto não atribuído. */
  shortId?: string;
```

- [ ] **Step 2: Linha da lista**

Em `buildPdfRow`, depois de `body.append(filename, classif);`:
```ts
  const shortId = el('code', 'pdf-short-id', item.shortId ?? '—');
  shortId.title = 'shortId (link curto)';
  body.append(shortId);
```

Em `renderForm`, junto do hint do `pdfId` (linha ~679):
```ts
  if (isEdit) {
    form.append(el('p', 'hint', `pdfId: ${e.pdfId}`));
    form.append(el('p', 'hint', `shortId: ${e.shortId ?? '— (não atribuído)'} · imutável, gerado pelo servidor`));
  }
```

`ui/src/styles/main.css`, após a regra `.pdf-classif`:
```css
.pdf-short-id {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.75rem;
  opacity: 0.7;
  margin-left: 0.5rem;
}
```

- [ ] **Step 3: Build**

Run: `cd "/Volumes/SSD 2TB SD/dev/plpcg-admin" && npm run build`
Expected: build da UI sem erro de tipo.

- [ ] **Step 4: README**

Após a seção «Deploy manual», acrescentar:
```markdown
## Migrations e o D1 compartilhado

O D1 `plpcg-catalog` é compartilhado com o Worker `plpcg-catalog` do repositório `coldigui`, que é o **dono das migrations remotas**. As migrations em `worker/migrations/` deste repo existem para o D1 local (`npm run db:migrate:local`); a `0003_add_short_id.sql` é um espelho da `0011` do coldigui e **não deve ser aplicada no remoto**.

### `shortId`

Cada PDF tem um `shortId` (hex minúsculo, string — `"0000"` é válido), gerado pelo servidor na criação a partir de `catalog_meta.short_id_next`, imutável e nunca reutilizado. Sai no manifest e em `/api/catalog/louvores`; é o que os links curtos de lista (`?s=…&n=…`) carregam.
```

- [ ] **Step 5: Commit**

```bash
git add ui/src/api/client.ts ui/src/app.ts ui/src/styles/main.css README.md
git commit -m "feat(ui): shortId somente leitura na lista e no formulário; README do D1 compartilhado"
```

---

### Task 9: Rollout (passos 1–2 do §5 da spec)

Só depois de os Planos 2 e 3 estarem **prontos para deploy** (os leitores precisam existir antes de o backfill ir ao ar? Não — o backfill só adiciona um campo que clientes atuais ignoram; o que precisa de ordem é a *emissão* de links, que fica nos Planos 2 e 3). Portanto este rollout pode ir assim que as Tasks 1–8 estiverem revisadas.

- [ ] **Step 1: coldigui Worker — migration remota e deploy**

Run (no worktree, `workers/plpcg-catalog`):
```bash
npm run db:migrate:remote
npm run deploy
npx wrangler d1 execute plpcg-catalog --remote --json --command "SELECT COUNT(*) AS total, COUNT(DISTINCT short_id) AS distintos, SUM(short_id IS NULL) AS nulos FROM louvores; SELECT value FROM catalog_meta WHERE key='short_id_next';"
curl -s https://plpcg.com/api/catalog/louvores | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d), sum('shortId' in x for x in d))"
```
Expected: `total == distintos`, `nulos == 0`; o `curl` mostra `4627 4627` (o ETag ainda é o antigo até a Task 9.2 — clientes só rebaixam depois dela).

- [ ] **Step 2: plpcg-admin — deploy e publicar**

Run: `cd "/Volumes/SSD 2TB SD/dev/plpcg-admin" && npm run deploy`, depois em `https://admin.plpcg.com` clicar **Publicar manifest**.
Verificar:
```bash
curl -s https://plpcg.com/louvores-manifest.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d), sum('shortId' in x for x in d), d[0].get('shortId'))"
curl -s https://plpcg.com/api/catalog/checksum
```
Expected: `4627 4627 <hex>`; o checksum é **diferente** do valor anterior à publicação (anote-o antes).

- [ ] **Step 3: Merge**

`plpcg-admin`: `git checkout main && git merge --no-ff feat/short-id-share && git push`. coldigui: o worktree segue aberto para os Planos 2–3 (o Plano 3 vive no mesmo branch); o merge em `web/integration` acontece no fim do Plano 3.

---

## Self-review

- **Cobertura da spec §2 e §4.1:** 2.1 (Tasks 4–6), 2.2 incl. checksum (Tasks 4, 7), 2.3 (Task 8), 2.4 (Tasks 4–7 + verificação de backfill na Task 1), 4.1 (Tasks 1–3), §5 passos 1–2 (Task 9). D3 espelho (Task 4). D5 crescimento (Task 5). D1 «string, não número» (Tasks 2, 5; seed na Task 3).
- **Tipos entre tasks:** `LOUVOR_COLUMNS` (admin, `types.ts`) ≠ `LOUVOR_SELECT_COLUMNS` (coldigui, `catalog/louvor_row.ts`) — nomes distintos de propósito, são repositórios diferentes. `insertLouvor` passa a devolver `Promise<LouvorJson>` e o único chamador (POST) é atualizado na Task 6. `readNextShortId`/`advanceShortIdStatement` definidos na Task 5, usados na 6.
- **Sem placeholders:** todos os passos têm código ou comando com saída esperada.
