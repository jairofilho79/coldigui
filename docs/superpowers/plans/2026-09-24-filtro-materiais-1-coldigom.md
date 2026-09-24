# Filtro Materiais — plano 1: coldigom (classes e famílias de material kind)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar a cada `material_kind` uma classe, um pai (família de um nível) e uma ordem, e publicar isso no dump `GET /api/plpcg/catalog`.

**Architecture:**
- Uma migration cria `material_kind_classes`, acrescenta `class_id`, `parent_id` e `sort_order` em `material_kinds` e classifica os 104 kinds de produção por id.
- `buildPlpcgCatalog` lê a taxonomia e manda, em cada item de `kinds`, as chaves `class`, `parent` e `order`, além da lista `kindClasses`. O ETag cobre as duas coisas.
- Nenhuma rota nova e nenhuma tela no admin.

**Tech Stack:** Cloudflare Worker (Hono), D1/SQLite, TypeScript, vitest; `node:sqlite` nos testes de SQL de verdade (`api/src/__tests__/sqliteD1.ts`).

**Spec:** `coldigui/docs/superpowers/specs/2026-09-24-filtro-materiais-classes-design.md` (§1, §2, §3, §7, §8). O plano 2 (app) é `coldigui/docs/superpowers/plans/2026-09-24-filtro-materiais-2-app.md`.

## Global Constraints

- **Repo e branch:** `coldigom`, branch `feat/material-kind-classes` criada a partir de `origin/main` (@ `e614d43` em 2026-09-24), **num worktree próprio**. Outra sessão (`coldigom-36`) trabalha no checkout principal; não mexa nele.
- **Número da migration:** `origin/main` vai até a `023`, e a `022` já foi usada em outra branch. Antes de criar o arquivo, rode `git fetch origin && git ls-tree --name-only origin/main api/migrations/` e use o próximo número livre. O plano chama o arquivo de `024_material_kind_classes.sql`; troque o número em **todos** os lugares se precisar.
- **Hierarquia:** um nível só; o pai é raiz; pai e filho têm a mesma classe; `parent_id` com `ON DELETE RESTRICT`. **Não** copie do modelo de tags o resolver `byParent.get(id) ?? [id]` nem a trava «Cannot attach a parent tag».
- **Chave:** o app filtra por **id** de kind. O rótulo de exibição continua saindo de `material_kind_translations` (`loadMaterialKindLabels`).
- **Chaves nulas ficam de fora** do JSON do dump, como `shortId`.
- **Testes:** `cd api && npx vitest run <arquivo>`. Precisa de Node ≥ 22 (`node:sqlite`).
- **Commits:** mensagens em português, terminando com `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- **Nada de deploy neste plano.** Migration remota e deploy do Worker só com ok explícito do dono (seção «Depois do merge»).

## Review Focus

1. **Worker novo em D1 sem a migration:** as consultas novas falham com «no such column/table» e o dump inteiro vira 500. O deploy exige migration antes. O teste de 500 existente cobre a falha genérica; o risco real é a **ordem do deploy**, repetida na seção «Depois do merge».
2. **Pai sem material com filho que tem material:** o pai tem que entrar em `kinds`, senão o app não monta a família (Task 2, teste próprio).
3. **Kind sem classe (novo, ou «Desconhecido»):** sai sem `class`, `parent` e `order`, sem quebrar nada (Task 2, teste próprio).
4. **ETag estável:** a mesma classificação gera o mesmo ETag, e mudar só a classe de um kind muda o ETag (Task 2, testes próprios).
5. **Id de produção errado na migration:** um `UPDATE` com id inexistente não falha, só não classifica. O teste com o fixture dos 104 kinds exige que todos, menos «Desconhecido», fiquem com classe (Task 1).

---

## File Structure

| Arquivo | Papel |
|---|---|
| `api/migrations/024_material_kind_classes.sql` (novo) | Tabela de classes, colunas novas, seed das 10 classes, classificação dos 103 kinds e consulta de verificação comentada. |
| `api/schema.sql` (modificar) | Bootstrap de D1 novo com as mesmas definições e o seed das classes (sem os `UPDATE` por id: D1 novo não tem kinds). |
| `api/src/__tests__/fixtures/materialKinds.prod-2026-09-24.json` (novo) | Os 104 kinds de produção `{id, name}`, para o teste da migration. |
| `api/src/__tests__/materialKindClassesMigration.test.ts` (novo) | Migration e schema em SQLite de verdade. |
| `api/src/plpcgPraises.ts` (modificar) | `buildPlpcgCatalog` lê a taxonomia e emite `kindClasses` e `class`/`parent`/`order`. |
| `api/src/__tests__/index.test.ts` (modificar) | Casos novos em `describe('GET /api/plpcg/catalog')`. |

---

### Task 1: Migration de classes e famílias

**Files:**
- Create: `api/migrations/024_material_kind_classes.sql`
- Create: `api/src/__tests__/fixtures/materialKinds.prod-2026-09-24.json`
- Create: `api/src/__tests__/materialKindClassesMigration.test.ts`
- Modify: `api/schema.sql` (bloco `-- Table: material_kinds`, perto da linha 62)

**Interfaces:**
- Consumes: `d1DeSqlite`, `lerSqlDaApi`, `sqliteComSchema` de `api/src/__tests__/sqliteD1.ts`.
- Produces (usado pela Task 2):
  - tabela `material_kind_classes(id TEXT PK, label TEXT NOT NULL, sort_order INTEGER NOT NULL UNIQUE)`;
  - colunas `material_kinds.class_id TEXT`, `material_kinds.parent_id TEXT`, `material_kinds.sort_order INTEGER`.

- [ ] **Step 1: Criar o worktree e a branch**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom"
git fetch origin
git worktree add ../coldigom-material-kind-classes -b feat/material-kind-classes origin/main
cd ../coldigom-material-kind-classes/api
npm ci
git ls-tree --name-only origin/main migrations/
```

Expected: a última migration listada é `023_praise_short_id.sql`. Se houver `024_*`, use o próximo número livre em todo o plano.

- [ ] **Step 2: Gravar o fixture dos kinds de produção**

```bash
curl -s https://coldigom-api.jairofilho79.workers.dev/api/materials/kinds \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const d=JSON.parse(s).data.map(({id,name})=>({id,name}));process.stdout.write(JSON.stringify(d,null,2)+"\n")})' \
  > src/__tests__/fixtures/materialKinds.prod-2026-09-24.json
node -e 'console.log(require("./src/__tests__/fixtures/materialKinds.prod-2026-09-24.json").length)'
```

Expected: `104`. Se vier outro número, pare e avise: a classificação da spec (§2.2) foi feita sobre 104 kinds.

- [ ] **Step 3: Escrever o teste que falha**

`api/src/__tests__/materialKindClassesMigration.test.ts`:

```ts
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it } from 'vitest';
import { lerSqlDaApi, sqliteComSchema } from './sqliteD1';

/**
 * Classes e famílias de material kind (migração 024; spec coldigui
 * 2026-09-24-filtro-materiais-classes §2 e §3.1). SQLite de verdade: FK,
 * índice único e ALTER não existem no D1 falso.
 */

/** material_kinds como está em produção antes da 024. */
const PRE_024 = `
CREATE TABLE material_kinds (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE);`;

const MIGRACAO = lerSqlDaApi('migrations/024_material_kind_classes.sql');

/** Os 104 kinds de produção em 2026-09-24 (`GET /api/materials/kinds`). */
const kindsDeProducao = JSON.parse(
  lerSqlDaApi('src/__tests__/fixtures/materialKinds.prod-2026-09-24.json'),
) as { id: string; name: string }[];

/** Pai que não é raiz, pai de outra classe, ou kind pai de si mesmo — deve voltar vazio. */
const VIOLACOES = `
SELECT c.id FROM material_kinds c
JOIN material_kinds p ON p.id = c.parent_id
WHERE p.parent_id IS NOT NULL OR c.class_id IS NOT p.class_id OR c.id = c.parent_id`;

function producaoMigrada(): DatabaseSync {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec('PRAGMA foreign_keys = ON;');
  sqlite.exec(PRE_024);
  const inserir = sqlite.prepare('INSERT INTO material_kinds (id, name) VALUES (?, ?)');
  for (const k of kindsDeProducao) inserir.run(k.id, k.name);
  sqlite.exec(MIGRACAO);
  return sqlite;
}

function kind(sqlite: DatabaseSync, nome: string) {
  return sqlite
    .prepare(
      `SELECT k.class_id, p.name AS pai, k.sort_order FROM material_kinds k
       LEFT JOIN material_kinds p ON p.id = k.parent_id WHERE k.name = ?`
    )
    .get(nome) as { class_id: string | null; pai: string | null; sort_order: number | null };
}

describe('migração 024 — classes e famílias de material kind', () => {
  it('cria as 10 classes na ordem da grade', () => {
    const sqlite = producaoMigrada();
    const classes = sqlite
      .prepare('SELECT id, label FROM material_kind_classes ORDER BY sort_order')
      .all()
      .map((r) => ({ ...(r as object) }));
    expect(classes).toEqual([
      { id: 'regencia', label: 'Regência e geral' },
      { id: 'letra', label: 'Letra e projeção' },
      { id: 'vozes', label: 'Vozes' },
      { id: 'madeiras', label: 'Madeiras' },
      { id: 'metais', label: 'Metais' },
      { id: 'percussao', label: 'Percussão' },
      { id: 'banda', label: 'Banda' },
      { id: 'cordas', label: 'Cordas' },
      { id: 'audio', label: 'Áudio e acompanhamento' },
      { id: 'midi', label: 'MIDI de ensaio' },
    ]);
  });

  it('classifica todos os kinds de produção, menos «Desconhecido»', () => {
    const sqlite = producaoMigrada();
    const semClasse = sqlite
      .prepare('SELECT name FROM material_kinds WHERE class_id IS NULL ORDER BY name')
      .all()
      .map((r) => (r as { name: string }).name);
    expect(semClasse).toEqual(['Desconhecido']);
    const semOrdem = sqlite
      .prepare('SELECT COUNT(*) AS n FROM material_kinds WHERE class_id IS NOT NULL AND sort_order IS NULL')
      .get() as { n: number };
    expect(semOrdem.n).toBe(0);
  });

  it('respeita as decisões do dono (spec §2.2)', () => {
    const sqlite = producaoMigrada();
    expect(kind(sqlite, 'Harmonia')).toMatchObject({ class_id: 'metais', pai: null });
    expect(kind(sqlite, 'Saxofone')).toMatchObject({ class_id: 'metais', pai: null });
    expect(kind(sqlite, 'Saxofone alto')).toMatchObject({ class_id: 'metais', pai: 'Saxofone' });
    expect(kind(sqlite, 'Cifra II')).toMatchObject({ class_id: 'banda', pai: 'Cifra' });
    expect(kind(sqlite, 'Base')).toMatchObject({ class_id: 'banda', pai: null });
    expect(kind(sqlite, 'Coro e piano')).toMatchObject({ class_id: 'banda', pai: null });
    expect(kind(sqlite, 'Coro')).toMatchObject({ class_id: 'vozes', pai: null });
    expect(kind(sqlite, 'MIDI tenor I')).toMatchObject({ class_id: 'midi', pai: 'MIDI tenor' });
    expect(kind(sqlite, 'MIDI')).toMatchObject({ class_id: 'midi', pai: null });
    // Ordem de grade, não alfabética: Flautim antes de Fagote.
    expect(kind(sqlite, 'Flautim').sort_order!).toBeLessThan(kind(sqlite, 'Fagote').sort_order!);
  });

  it('não viola as regras de família', () => {
    const sqlite = producaoMigrada();
    expect(sqlite.prepare(VIOLACOES).all()).toEqual([]);
  });

  it('não deixa apagar um pai que ainda tem filhos', () => {
    const sqlite = producaoMigrada();
    expect(() => sqlite.prepare("DELETE FROM material_kinds WHERE name = 'Saxofone'").run()).toThrow(
      /FOREIGN KEY constraint failed/,
    );
  });

  it('o schema.sql de um D1 novo já traz as classes e as colunas', () => {
    const sqlite = sqliteComSchema();
    const n = sqlite.prepare('SELECT COUNT(*) AS n FROM material_kind_classes').get() as { n: number };
    expect(n.n).toBe(10);
    sqlite
      .prepare("INSERT INTO material_kinds (id, name, class_id, sort_order) VALUES ('k1', 'Tuba', 'metais', 10)")
      .run();
    expect(
      sqlite.prepare("SELECT class_id FROM material_kinds WHERE id = 'k1'").get(),
    ).toMatchObject({ class_id: 'metais' });
  });
});
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `npx vitest run src/__tests__/materialKindClassesMigration.test.ts`
Expected: FAIL com `ENOENT` em `migrations/024_material_kind_classes.sql`.

- [ ] **Step 5: Escrever a migration**

`api/migrations/024_material_kind_classes.sql`:

```sql
-- api/migrations/024_material_kind_classes.sql
-- Classe, família e ordem dos material kinds (spec coldigui
-- docs/superpowers/specs/2026-09-24-filtro-materiais-classes-design.md §2 e §3.1).
--
-- O filtro «Materiais» do app agrupa os kinds por classe (Metais, Banda…) e
-- recolhe as variantes numa família (Saxofone → Saxofone alto…). A família tem
-- um nível só, como as tags (migração 010): o pai é raiz e da mesma classe do
-- filho; apagar um pai com filhos é barrado (RESTRICT). Kind sem classe (um
-- kind novo, ou «Desconhecido») aparece em «Outros» no app.
--
-- Sem tela de edição: um kind novo se classifica com um UPDATE como os abaixo.
-- Depois de qualquer UPDATE manual, rode a verificação do fim do arquivo.
--
-- Aplicar UMA vez (o ALTER não se repete), ANTES do deploy do Worker que lê as colunas:
--   cd api && wrangler d1 execute coldigom --remote --file=migrations/024_material_kind_classes.sql

CREATE TABLE IF NOT EXISTS material_kind_classes (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    sort_order INTEGER NOT NULL UNIQUE
);

ALTER TABLE material_kinds ADD COLUMN class_id TEXT REFERENCES material_kind_classes(id) ON DELETE SET NULL;
ALTER TABLE material_kinds ADD COLUMN parent_id TEXT REFERENCES material_kinds(id) ON DELETE RESTRICT;
ALTER TABLE material_kinds ADD COLUMN sort_order INTEGER;
CREATE INDEX IF NOT EXISTS idx_material_kinds_parent_id ON material_kinds(parent_id);

INSERT OR IGNORE INTO material_kind_classes (id, label, sort_order) VALUES
    ('regencia', 'Regência e geral', 10),
    ('letra', 'Letra e projeção', 20),
    ('vozes', 'Vozes', 30),
    ('madeiras', 'Madeiras', 40),
    ('metais', 'Metais', 50),
    ('percussao', 'Percussão', 60),
    ('banda', 'Banda', 70),
    ('cordas', 'Cordas', 80),
    ('audio', 'Áudio e acompanhamento', 90),
    ('midi', 'MIDI de ensaio', 100);

-- Classificação dos kinds de produção (2026-09-24), por id. Pais antes dos filhos.
UPDATE material_kinds SET class_id = 'regencia', parent_id = NULL, sort_order = 10 WHERE id = '36fa6e60-37d6-40a4-87e4-aa099839ad25'; -- Partitura
UPDATE material_kinds SET class_id = 'regencia', parent_id = NULL, sort_order = 20 WHERE id = 'a19e9baa-596d-4d11-87a4-f0ccecdebca3'; -- Grade
UPDATE material_kinds SET class_id = 'regencia', parent_id = NULL, sort_order = 30 WHERE id = '316d120c-527f-4a66-aa25-88c1b19f4714'; -- Instrumental
UPDATE material_kinds SET class_id = 'regencia', parent_id = NULL, sort_order = 40 WHERE id = 'e1a12c9e-ef1a-4ec9-9289-799479bc2e9b'; -- Experiência
UPDATE material_kinds SET class_id = 'letra', parent_id = NULL, sort_order = 10 WHERE id = '3b55c854-aa8e-43cf-9433-ba49a0161d90'; -- Letra
UPDATE material_kinds SET class_id = 'letra', parent_id = NULL, sort_order = 20 WHERE id = '8320af91-584c-4108-9cb9-6f23087a3a60'; -- Slide
UPDATE material_kinds SET class_id = 'letra', parent_id = NULL, sort_order = 30 WHERE id = '4a21d073-1726-41a3-bca7-77550f91e02a'; -- Gestos CIAs
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 10 WHERE id = 'c2fb644f-697c-4d43-9d5f-22319fa0ce79'; -- Coro
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 20 WHERE id = 'b324adec-924d-4a6b-9c2c-b3ef59eb1f6c'; -- Primeira voz
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 30 WHERE id = '32f70923-fbe8-4e39-893e-fc30824f749e'; -- Segunda voz
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 40 WHERE id = '261d020a-1c04-4196-89ba-2bef4e090019'; -- Voz cantada
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 50 WHERE id = 'e60c9cf5-37d4-4f93-9459-0f1d4625d395'; -- Voz mulheres
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 60 WHERE id = 'e559526d-1064-401b-9a34-e4c39a302143'; -- Voz homens
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 70 WHERE id = '3723a55b-a0bb-49b1-be0e-2914915c51af'; -- Voz soprano
UPDATE material_kinds SET class_id = 'vozes', parent_id = '3723a55b-a0bb-49b1-be0e-2914915c51af', sort_order = 80 WHERE id = 'cf15647d-eaab-47ec-b313-95deec1d04e8'; -- Voz soprano I
UPDATE material_kinds SET class_id = 'vozes', parent_id = '3723a55b-a0bb-49b1-be0e-2914915c51af', sort_order = 90 WHERE id = 'e3e43744-492b-41a1-9f84-92f9e7d983dd'; -- Voz soprano II
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 100 WHERE id = '8ddc2fed-5298-4ead-bc71-e529921c00ac'; -- Voz contralto
UPDATE material_kinds SET class_id = 'vozes', parent_id = '8ddc2fed-5298-4ead-bc71-e529921c00ac', sort_order = 110 WHERE id = 'a185dd50-a5f4-46be-a364-d4d609cadcca'; -- Voz contralto I
UPDATE material_kinds SET class_id = 'vozes', parent_id = '8ddc2fed-5298-4ead-bc71-e529921c00ac', sort_order = 120 WHERE id = '6db799b5-20ea-4c9a-8d0d-18840c593ff4'; -- Voz contralto II
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 130 WHERE id = '9125e159-3fd8-492d-952d-f8887e57d59f'; -- Voz tenor
UPDATE material_kinds SET class_id = 'vozes', parent_id = '9125e159-3fd8-492d-952d-f8887e57d59f', sort_order = 140 WHERE id = '6b0c073a-f6f7-414c-9859-7c2d4a0a94c6'; -- Voz tenor I
UPDATE material_kinds SET class_id = 'vozes', parent_id = '9125e159-3fd8-492d-952d-f8887e57d59f', sort_order = 150 WHERE id = '481a43df-dd03-4a0a-a333-7ca0aa99fdf7'; -- Voz tenor II
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 160 WHERE id = 'ad27aa1a-7da8-41da-a8bc-71676acdc63d'; -- Voz barítono
UPDATE material_kinds SET class_id = 'vozes', parent_id = NULL, sort_order = 170 WHERE id = 'c4ddecbd-ef4d-4e20-bece-4261201bccc8'; -- Voz baixo
UPDATE material_kinds SET class_id = 'madeiras', parent_id = NULL, sort_order = 10 WHERE id = '5605546e-b832-4b47-a141-13eed9d1a644'; -- Madeiras
UPDATE material_kinds SET class_id = 'madeiras', parent_id = NULL, sort_order = 20 WHERE id = '8601426e-d1e8-4cb6-889e-17a1c116cdf5'; -- Flautim
UPDATE material_kinds SET class_id = 'madeiras', parent_id = NULL, sort_order = 30 WHERE id = '11e3c9eb-c022-48c4-82a4-91f09bf089b0'; -- Flauta
UPDATE material_kinds SET class_id = 'madeiras', parent_id = NULL, sort_order = 40 WHERE id = '5181c85f-7f24-4002-b4e0-74cdcea9de4b'; -- Oboé
UPDATE material_kinds SET class_id = 'madeiras', parent_id = NULL, sort_order = 50 WHERE id = '12f9ac21-4bec-40e0-9411-d39a129f2c7b'; -- Clarinete
UPDATE material_kinds SET class_id = 'madeiras', parent_id = '12f9ac21-4bec-40e0-9411-d39a129f2c7b', sort_order = 60 WHERE id = '59df1962-d245-41eb-9fdc-ca79d69a34ab'; -- Clarinete em Si bemol
UPDATE material_kinds SET class_id = 'madeiras', parent_id = NULL, sort_order = 70 WHERE id = '4930d355-80ce-4192-8bab-c09d00f82c3c'; -- Fagote
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 10 WHERE id = '1427517d-7991-4fad-a023-4b0ec3f46166'; -- Metais
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 20 WHERE id = '495a10f3-204b-4fdd-9cea-755cda0fcff8'; -- Harmonia
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 30 WHERE id = 'a3f9d722-b43c-4639-beb0-48a75757ab00'; -- Saxofone
UPDATE material_kinds SET class_id = 'metais', parent_id = 'a3f9d722-b43c-4639-beb0-48a75757ab00', sort_order = 40 WHERE id = 'e1f16ebc-20af-4d12-b95f-80f3608df128'; -- Saxofone soprano
UPDATE material_kinds SET class_id = 'metais', parent_id = 'a3f9d722-b43c-4639-beb0-48a75757ab00', sort_order = 50 WHERE id = '6d35011f-b98b-436f-b4f7-92c3cff413c5'; -- Saxofone alto
UPDATE material_kinds SET class_id = 'metais', parent_id = 'a3f9d722-b43c-4639-beb0-48a75757ab00', sort_order = 60 WHERE id = '68915148-9029-4c2b-bb35-c89338240f0a'; -- Saxofone tenor
UPDATE material_kinds SET class_id = 'metais', parent_id = 'a3f9d722-b43c-4639-beb0-48a75757ab00', sort_order = 70 WHERE id = '40f562c0-c506-4044-a598-cccea7500fc4'; -- Saxofone barítono
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 80 WHERE id = 'ef814b88-2562-4785-98a1-5fca88c11824'; -- Trompa
UPDATE material_kinds SET class_id = 'metais', parent_id = 'ef814b88-2562-4785-98a1-5fca88c11824', sort_order = 90 WHERE id = '4243223d-c2a0-433c-b385-1994dcfe4e46'; -- Trompa em Fá
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 100 WHERE id = 'b2d08b24-26b7-4bf6-970d-eb84e29833ea'; -- Trompete
UPDATE material_kinds SET class_id = 'metais', parent_id = 'b2d08b24-26b7-4bf6-970d-eb84e29833ea', sort_order = 110 WHERE id = '22997832-30fe-48e1-bdc0-3493b39814fb'; -- Trompete em Si bemol
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 120 WHERE id = 'a3d013e7-790b-4e4e-a254-aefb14185b51'; -- Corneta
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 130 WHERE id = 'd65e6267-372e-4377-80ed-8a02a6bed47f'; -- Flugelhorn
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 140 WHERE id = '93ea287b-d712-4452-8ec6-84478ecb6c22'; -- Trombone
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 150 WHERE id = 'fb57aa8d-ba2d-4854-b3b5-41107b7240a0'; -- Eufônio
UPDATE material_kinds SET class_id = 'metais', parent_id = NULL, sort_order = 160 WHERE id = '27c1d204-c45f-4d6c-8f0f-90df3700e82a'; -- Tuba
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 10 WHERE id = 'f04c2dbe-8152-430c-8120-5a51f3b2fac5'; -- Percussão
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 20 WHERE id = '8146609a-659e-4787-9e7e-64f19d21a132'; -- Bateria
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 30 WHERE id = '541a5d3e-e788-4de2-98ea-18b0317b0c33'; -- Bumbo
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 40 WHERE id = 'c1187df7-8d86-4865-bef8-1911dd82cfba'; -- Caixa
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 50 WHERE id = '04c80f74-0348-43af-8eb5-67699826e758'; -- Prato
UPDATE material_kinds SET class_id = 'percussao', parent_id = '04c80f74-0348-43af-8eb5-67699826e758', sort_order = 60 WHERE id = '8c548fbb-7c9b-4563-aea9-5b7cfb9f9244'; -- Prato suspenso
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 70 WHERE id = '9b0099ff-dc7a-48c2-a3be-6d02b5c2340c'; -- Tímpanos
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 80 WHERE id = 'b6a296c6-f1f5-4b4d-a5db-1a63021b9c3a'; -- Glockenspiel
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 90 WHERE id = '9854d697-97cc-4c27-9d66-996cf38ebf10'; -- Vibrafone
UPDATE material_kinds SET class_id = 'percussao', parent_id = NULL, sort_order = 100 WHERE id = '6e373b8f-61cc-4046-8f3a-17254b5672f4'; -- Sinos de orquestra
UPDATE material_kinds SET class_id = 'banda', parent_id = NULL, sort_order = 10 WHERE id = 'e2274af6-a19f-4186-93cd-e3810ce75e2c'; -- Cifra
UPDATE material_kinds SET class_id = 'banda', parent_id = 'e2274af6-a19f-4186-93cd-e3810ce75e2c', sort_order = 20 WHERE id = '27e39659-b4a0-4ef2-87f4-546fe292298d'; -- Cifra I
UPDATE material_kinds SET class_id = 'banda', parent_id = 'e2274af6-a19f-4186-93cd-e3810ce75e2c', sort_order = 30 WHERE id = '5a9d9ced-a5e3-4848-adac-f02a14b56038'; -- Cifra II
UPDATE material_kinds SET class_id = 'banda', parent_id = NULL, sort_order = 40 WHERE id = '38d1bb43-0959-435d-b845-754ebec83a87'; -- Violão
UPDATE material_kinds SET class_id = 'banda', parent_id = NULL, sort_order = 50 WHERE id = 'f10ab9ff-a44e-4b4d-ad93-9203527d74e1'; -- Teclado
UPDATE material_kinds SET class_id = 'banda', parent_id = NULL, sort_order = 60 WHERE id = '09d5120b-2dd2-4408-8982-68bee197ce6a'; -- Piano
UPDATE material_kinds SET class_id = 'banda', parent_id = NULL, sort_order = 70 WHERE id = 'e3a4ae9d-fce7-4d00-ba07-0068121e811c'; -- Baixo elétrico
UPDATE material_kinds SET class_id = 'banda', parent_id = NULL, sort_order = 80 WHERE id = '4a3be8c6-9e6a-42d6-9181-0cd19e2d1096'; -- Base
UPDATE material_kinds SET class_id = 'banda', parent_id = NULL, sort_order = 90 WHERE id = '835cdb0c-8920-4a69-a067-a31c5afb6560'; -- Coro e piano
UPDATE material_kinds SET class_id = 'cordas', parent_id = NULL, sort_order = 10 WHERE id = 'ac66b2d8-814c-42a0-8210-1b767ac609f7'; -- Cordas
UPDATE material_kinds SET class_id = 'cordas', parent_id = NULL, sort_order = 20 WHERE id = 'b30b17c4-3d57-459c-a50c-9561b98ecedb'; -- Violino
UPDATE material_kinds SET class_id = 'cordas', parent_id = 'b30b17c4-3d57-459c-a50c-9561b98ecedb', sort_order = 30 WHERE id = '02e5d7fc-640d-4a22-ae31-20556f19fc63'; -- Violino I
UPDATE material_kinds SET class_id = 'cordas', parent_id = 'b30b17c4-3d57-459c-a50c-9561b98ecedb', sort_order = 40 WHERE id = '858d8a00-e4f3-4679-9e33-4026c87df8f4'; -- Violino II
UPDATE material_kinds SET class_id = 'cordas', parent_id = NULL, sort_order = 50 WHERE id = '5d491559-6298-419d-a2d5-399675386a40'; -- Viola
UPDATE material_kinds SET class_id = 'cordas', parent_id = NULL, sort_order = 60 WHERE id = '8cd30965-53c2-4317-bf24-52c8a430005b'; -- Violoncelo
UPDATE material_kinds SET class_id = 'cordas', parent_id = NULL, sort_order = 70 WHERE id = '71128210-90f0-447d-b201-aabd62a025bc'; -- Contrabaixo
UPDATE material_kinds SET class_id = 'audio', parent_id = NULL, sort_order = 10 WHERE id = '8860ed67-6b33-4e08-9064-adb93a5f5c2a'; -- Áudio
UPDATE material_kinds SET class_id = 'audio', parent_id = '8860ed67-6b33-4e08-9064-adb93a5f5c2a', sort_order = 20 WHERE id = '649b3ef6-60f3-4956-b0dc-b3a8b73ca1d2'; -- Áudio (grupo)
UPDATE material_kinds SET class_id = 'audio', parent_id = '8860ed67-6b33-4e08-9064-adb93a5f5c2a', sort_order = 30 WHERE id = 'e27f4585-f1ec-43fe-98ed-6fc4405447e0'; -- Áudio (solo)
UPDATE material_kinds SET class_id = 'audio', parent_id = NULL, sort_order = 40 WHERE id = '64be7569-0246-4334-96c4-cb3cfb3ae5b2'; -- Playback
UPDATE material_kinds SET class_id = 'audio', parent_id = NULL, sort_order = 50 WHERE id = '7c589108-7ab9-45cb-bcaa-2bff7e109ba5'; -- Versão de ensaio
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 10 WHERE id = 'a7d5270a-652c-4f88-afb4-3dccf5cb89e1'; -- MIDI
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 20 WHERE id = '9641ba0d-0ccd-4f51-8747-7e6c002e461e'; -- MIDI geral
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 30 WHERE id = 'bfcc4a22-e9ae-4cab-946c-f4c6199f1feb'; -- MIDI grade
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 40 WHERE id = '56c252f4-bcbe-47b9-99f6-f996de79ec32'; -- MIDI coro
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 50 WHERE id = '578fa489-d31e-4a0e-8883-5e2c8a2b8957'; -- MIDI instrumentos
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 60 WHERE id = 'da800c21-8078-4c3b-9fc5-ff66d53858d3'; -- MIDI voz
UPDATE material_kinds SET class_id = 'midi', parent_id = 'da800c21-8078-4c3b-9fc5-ff66d53858d3', sort_order = 70 WHERE id = '4120bf94-6ef9-4c94-be8f-97d088f0d9d4'; -- MIDI voz mulheres
UPDATE material_kinds SET class_id = 'midi', parent_id = 'da800c21-8078-4c3b-9fc5-ff66d53858d3', sort_order = 80 WHERE id = '4b880911-32df-4b86-aae2-78c6e467de60'; -- MIDI voz homens
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 90 WHERE id = '69b7a7c4-27e6-42a4-855c-1f0c9fd21940'; -- MIDI mulheres
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 100 WHERE id = 'fedcb814-e0b4-4bf9-9cb3-81898333d224'; -- MIDI homens
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 110 WHERE id = '9bc574f7-fc96-427d-84c4-b060ef1a20cf'; -- MIDI primeira voz
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 120 WHERE id = 'c518686d-3919-45bd-8aac-314d7f30d7cc'; -- MIDI segunda voz
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 130 WHERE id = 'b33a159b-955e-4e93-bdce-3f9dfeb811b2'; -- MIDI soprano
UPDATE material_kinds SET class_id = 'midi', parent_id = 'b33a159b-955e-4e93-bdce-3f9dfeb811b2', sort_order = 140 WHERE id = '8040b04a-d09b-46af-add6-32958c719369'; -- MIDI soprano I
UPDATE material_kinds SET class_id = 'midi', parent_id = 'b33a159b-955e-4e93-bdce-3f9dfeb811b2', sort_order = 150 WHERE id = '48a0529d-f6c4-455c-b83b-19a99c0285ae'; -- MIDI soprano II
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 160 WHERE id = 'ab76454d-6876-433b-932c-6b4bb88075ac'; -- MIDI contralto
UPDATE material_kinds SET class_id = 'midi', parent_id = 'ab76454d-6876-433b-932c-6b4bb88075ac', sort_order = 170 WHERE id = '23d92c83-1bad-4c4a-a741-3306ce491bb5'; -- MIDI contralto I
UPDATE material_kinds SET class_id = 'midi', parent_id = 'ab76454d-6876-433b-932c-6b4bb88075ac', sort_order = 180 WHERE id = '251cc51f-5208-4b8c-a23c-657694a08997'; -- MIDI contralto II
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 190 WHERE id = '4bbf1331-b13e-4029-bbb7-bf5eda568409'; -- MIDI tenor
UPDATE material_kinds SET class_id = 'midi', parent_id = '4bbf1331-b13e-4029-bbb7-bf5eda568409', sort_order = 200 WHERE id = '76dd9e81-3b5a-4cad-b9c1-a688bdd60fbc'; -- MIDI tenor I
UPDATE material_kinds SET class_id = 'midi', parent_id = '4bbf1331-b13e-4029-bbb7-bf5eda568409', sort_order = 210 WHERE id = '06e50eca-b05d-4a69-8ce3-d4a3179bd11e'; -- MIDI tenor II
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 220 WHERE id = '02e00e67-ada7-4ac3-a8c5-7d9a2ab2465b'; -- MIDI barítono
UPDATE material_kinds SET class_id = 'midi', parent_id = NULL, sort_order = 230 WHERE id = '82977793-e6e3-404c-bc22-cec6d4834151'; -- MIDI baixo
UPDATE material_kinds SET class_id = 'midi', parent_id = '82977793-e6e3-404c-bc22-cec6d4834151', sort_order = 240 WHERE id = '2f7c63fc-c6f2-4357-86e7-77c7605f7eca'; -- MIDI baixo I
UPDATE material_kinds SET class_id = 'midi', parent_id = '82977793-e6e3-404c-bc22-cec6d4834151', sort_order = 250 WHERE id = '35ab281e-8aab-4be4-ba74-ef6ce771c46b'; -- MIDI baixo II
-- Verificação (deve voltar vazia):
--   SELECT c.id FROM material_kinds c JOIN material_kinds p ON p.id = c.parent_id
--   WHERE p.parent_id IS NOT NULL OR c.class_id IS NOT p.class_id OR c.id = c.parent_id;
```

- [ ] **Step 6: Atualizar o `schema.sql`**

Em `api/schema.sql`, troque o bloco da tabela `material_kinds` (hoje só `id` e `name`) por:

```sql
-- Table: material_kind_classes
-- Classes do filtro «Materiais» do app (migração 024): Metais, Banda…
CREATE TABLE IF NOT EXISTS material_kind_classes (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    sort_order INTEGER NOT NULL UNIQUE
);

INSERT OR IGNORE INTO material_kind_classes (id, label, sort_order) VALUES
    ('regencia', 'Regência e geral', 10),
    ('letra', 'Letra e projeção', 20),
    ('vozes', 'Vozes', 30),
    ('madeiras', 'Madeiras', 40),
    ('metais', 'Metais', 50),
    ('percussao', 'Percussão', 60),
    ('banda', 'Banda', 70),
    ('cordas', 'Cordas', 80),
    ('audio', 'Áudio e acompanhamento', 90),
    ('midi', 'MIDI de ensaio', 100);

-- Table: material_kinds
-- Lookup table for material types (Audio, Score, MIDI, Lyrics, Chord Chart, Vozes, Instrumentos, etc.)
-- class_id/parent_id/sort_order (migração 024): classe, família de um nível (pai raiz,
-- mesma classe) e ordem de grade dentro da classe.
CREATE TABLE IF NOT EXISTS material_kinds (
    id TEXT PRIMARY KEY,           -- UUID
    name TEXT NOT NULL UNIQUE,     -- Canonical kind name (ingestion source language)
    class_id TEXT REFERENCES material_kind_classes(id) ON DELETE SET NULL,
    parent_id TEXT REFERENCES material_kinds(id) ON DELETE RESTRICT,
    sort_order INTEGER
);
CREATE INDEX IF NOT EXISTS idx_material_kinds_parent_id ON material_kinds(parent_id);
```

A tabela `material_kind_classes` tem que vir **antes** de `material_kinds`, por causa da FK.

- [ ] **Step 7: Rodar e ver passar**

Run: `npx vitest run src/__tests__/materialKindClassesMigration.test.ts src/__tests__/sqliteD1.test.ts`
Expected: PASS (6 + 3 testes).

- [ ] **Step 8: Commit**

```bash
git add migrations/024_material_kind_classes.sql schema.sql \
  src/__tests__/fixtures/materialKinds.prod-2026-09-24.json \
  src/__tests__/materialKindClassesMigration.test.ts
git commit -m "feat(api): classes e famílias de material kind (migração 024)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Dump do catálogo com a taxonomia

**Files:**
- Modify: `api/src/plpcgPraises.ts` (`buildPlpcgCatalog`, a partir de `export async function buildPlpcgCatalog`)
- Test: `api/src/__tests__/index.test.ts` (`describe('GET /api/plpcg/catalog')`, perto da linha 860)

**Interfaces:**
- Consumes: as colunas e a tabela da Task 1.
- Produces (contrato lido pelo plano 2, `ColdigomCatalogDto`):

```ts
// corpo 200 de GET /api/plpcg/catalog
{
  generatedAt: string;
  kindClasses: { id: string; label: string }[];   // ordem de sort_order; só classes usadas por algum kind do dump
  kinds: { id: string; name: string; class?: string; parent?: string; order?: number }[];
  praises: [...];                                 // sem mudança
}
```

- [ ] **Step 1: Escrever os testes que falham**

No `index.test.ts`, dentro de `describe('GET /api/plpcg/catalog')`, troque o `catalogMockDB` para aceitar a taxonomia. A consulta nova de kinds **tem** que ser testada antes da de rótulos, porque as duas têm `FROM material_kinds`:

```ts
    /** D1 falso: despacha pelo texto da query, sem `bind` (o dump não tem parâmetros). */
    function catalogMockDB(options: {
      praises?: unknown[];
      materials?: unknown[];
      tags?: unknown[];
      kindTaxonomy?: unknown[];
      kindClasses?: unknown[];
    } = {}) {
      const results = (query: string) => {
        if (query.includes('FROM material_kind_classes')) return { results: options.kindClasses ?? [] };
        if (query.includes('parent_id, sort_order FROM material_kinds')) return { results: options.kindTaxonomy ?? [] };
        if (query.includes('COALESCE(t.label')) return { results: mockMaterialKindLabels };
        if (query.includes('FROM praise_materials')) return { results: options.materials ?? mockMaterials };
        if (query.includes('FROM praise_tags')) return { results: options.tags ?? [] };
        if (query.includes('FROM praises p')) return { results: options.praises ?? mockPraises };
        return { results: [] };
      };
      return {
        prepare: vi.fn((query: string) => ({
          all: vi.fn(async () => results(query)),
          bind: vi.fn((..._args: unknown[]) => ({
            all: vi.fn(async () => results(query)),
            first: vi.fn().mockResolvedValue(null),
          })),
        })),
      };
    }
```

E acrescente, no mesmo `describe`:

```ts
    describe('taxonomia dos kinds (spec filtro-materiais §3.2)', () => {
      const praiseId = () => mockPraises[0].id;
      const material = (id: string, kind: string) => ({
        id,
        praise_id: praiseId(),
        type: 'pdf',
        material_kind: kind,
        url: null,
        r2_key: `assets/praises/${praiseId()}/${id}.pdf`,
      });
      const classes = [
        { id: 'metais', label: 'Metais' },
        { id: 'banda', label: 'Banda' },
        { id: 'cordas', label: 'Cordas' },
      ];
      const taxonomia = [
        { id: 'sax', class_id: 'metais', parent_id: null, sort_order: 30 },
        { id: 'sax-alto', class_id: 'metais', parent_id: 'sax', sort_order: 50 },
        { id: 'cifra', class_id: 'banda', parent_id: null, sort_order: 10 },
        { id: 'novo', class_id: null, parent_id: null, sort_order: null },
      ];

      async function dump(env: unknown) {
        const res = await app.request('/api/plpcg/catalog', {}, env as never);
        return { res, json: await res.json() };
      }

      it('manda class/parent/order nos kinds e omite as chaves nulas', async () => {
        const { json } = await dump({
          DB: catalogMockDB({
            materials: [material('m1', 'sax'), material('m2', 'sax-alto'), material('m3', 'novo')],
            kindTaxonomy: taxonomia,
            kindClasses: classes,
          }),
          ASSETS: createMockR2(),
        });
        const porId = Object.fromEntries(json.kinds.map((k: { id: string }) => [k.id, k]));
        expect(porId['sax']).toEqual({ id: 'sax', name: expect.any(String), class: 'metais', order: 30 });
        expect(porId['sax-alto']).toEqual({
          id: 'sax-alto',
          name: expect.any(String),
          class: 'metais',
          parent: 'sax',
          order: 50,
        });
        expect(porId['novo']).toEqual({ id: 'novo', name: expect.any(String) });
      });

      it('kindClasses vem na ordem e só com classes usadas no dump', async () => {
        const { json } = await dump({
          DB: catalogMockDB({
            materials: [material('m1', 'sax'), material('m2', 'cifra')],
            kindTaxonomy: taxonomia,
            kindClasses: classes,
          }),
          ASSETS: createMockR2(),
        });
        expect(json.kindClasses).toEqual([
          { id: 'metais', label: 'Metais' },
          { id: 'banda', label: 'Banda' },
        ]);
      });

      it('um pai sem material entra em kinds quando um filho tem material', async () => {
        const { json } = await dump({
          DB: catalogMockDB({
            materials: [material('m2', 'sax-alto')],
            kindTaxonomy: taxonomia,
            kindClasses: classes,
          }),
          ASSETS: createMockR2(),
        });
        expect(json.kinds.map((k: { id: string }) => k.id).sort()).toEqual(['sax', 'sax-alto']);
      });

      it('sem taxonomia (tabela vazia) o dump sai como antes, com kindClasses vazio', async () => {
        const { json } = await dump({ DB: catalogMockDB(), ASSETS: createMockR2() });
        expect(json.kindClasses).toEqual([]);
        for (const k of json.kinds) expect(Object.keys(k).sort()).toEqual(['id', 'name']);
      });

      it('mesma taxonomia, mesmo ETag; mudar a classe de um kind muda o ETag', async () => {
        const env = (tax: unknown[]) => ({
          DB: catalogMockDB({ materials: [material('m1', 'sax')], kindTaxonomy: tax, kindClasses: classes }),
          ASSETS: createMockR2(),
        });
        const a = (await dump(env(taxonomia))).res.headers.get('ETag');
        const b = (await dump(env(taxonomia))).res.headers.get('ETag');
        const outra = taxonomia.map((k) => (k.id === 'sax' ? { ...k, class_id: 'banda' } : k));
        const c = (await dump(env(outra))).res.headers.get('ETag');
        expect(a).toBe(b);
        expect(c).not.toBe(a);
      });
    });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run src/__tests__/index.test.ts -t "taxonomia dos kinds"`
Expected: FAIL. `json.kindClasses` é `undefined`, e os kinds não têm `class`.

- [ ] **Step 3: Implementar em `buildPlpcgCatalog`**

Em `api/src/plpcgPraises.ts`, junto dos tipos do dump (perto de `type CatalogTagRow`), acrescente:

```ts
type CatalogKindTaxonomyRow = {
  id: string;
  class_id: string | null;
  parent_id: string | null;
  sort_order: number | null;
};

type CatalogKindClassRow = { id: string; label: string };

/** Item de `kinds` no dump: chaves de taxonomia só quando preenchidas (spec filtro-materiais §3.2). */
export type PlpcgCatalogKind = {
  id: string;
  name: string;
  class?: string;
  parent?: string;
  order?: number;
};
```

Em `buildPlpcgCatalog`, logo depois de `const kindLabels = await loadMaterialKindLabels(db);`:

```ts
  // Classe, família e ordem (migração 024). O Worker exige a migração aplicada
  // antes do deploy: sem as colunas esta consulta falha e o dump vira 500.
  const taxonomyResult = await db
    .prepare(`SELECT id, class_id, parent_id, sort_order FROM material_kinds`)
    .all();
  const classesResult = await db
    .prepare(`SELECT id, label FROM material_kind_classes ORDER BY sort_order`)
    .all();
  const taxonomy = new Map<string, CatalogKindTaxonomyRow>();
  for (const row of (taxonomyResult.results ?? []) as CatalogKindTaxonomyRow[]) {
    taxonomy.set(row.id, row);
  }
```

E troque o bloco que monta `kinds` por:

```ts
  // Um pai sem material entra quando um filho tem: sem ele o app não monta a família.
  for (const id of [...kindIds]) {
    const parent = taxonomy.get(id)?.parent_id;
    if (parent) kindIds.add(parent);
  }

  const kinds: PlpcgCatalogKind[] = [...kindIds]
    .map((id) => {
      const kind: PlpcgCatalogKind = { id, name: labelFor(kindLabels, id) };
      const row = taxonomy.get(id);
      if (row?.class_id) kind.class = row.class_id;
      if (row?.parent_id) kind.parent = row.parent_id;
      if (row?.sort_order != null) kind.order = row.sort_order;
      return kind;
    })
    .sort((a, b) => a.name.localeCompare(b.name));

  const usedClasses = new Set(kinds.map((k) => k.class).filter((c): c is string => !!c));
  const kindClasses = ((classesResult.results ?? []) as CatalogKindClassRow[])
    .filter((c) => usedClasses.has(c.id))
    .map(({ id, label }) => ({ id, label }));
```

Troque o ETag e o corpo:

```ts
  const etag = `"${await sha256Hex32(JSON.stringify({ kinds, kindClasses, praises }))}"`;
```

```ts
  const body = JSON.stringify({ generatedAt: new Date().toISOString(), kindClasses, kinds, praises });
```

Atualize o comentário do bloco `GET /api/plpcg/catalog` (acima de `PlpcgCatalogMaterial`): o ETag passa a ser o hash de `{kinds, kindClasses, praises}`.

- [ ] **Step 4: Rodar e ver passar, incluindo os testes antigos do dump**

Run: `npx vitest run src/__tests__/index.test.ts -t "plpcg/catalog"` e depois `npx vitest run src/__tests__/praiseShortIdRoutes.test.ts`
Expected: PASS em tudo. Os testes antigos continuam verdes porque o mock devolve `[]` para as consultas novas.

- [ ] **Step 5: Suíte inteira, tipos e lint**

Run: `npx vitest run && npx tsc --noEmit && npm run lint`
Expected: tudo verde.

- [ ] **Step 6: Commit**

```bash
git add src/plpcgPraises.ts src/__tests__/index.test.ts
git commit -m "feat(api): dump do catálogo com classe, família e ordem dos kinds

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Depois do merge (com ok do dono, fora das tasks)

A ordem é obrigatória: um Worker novo sobre um D1 sem a migration devolve 500 no dump.

1. Abrir a PR `feat/material-kind-classes` → `develop`/`main`, seguindo o fluxo do repo.
2. Com ok do dono, aplicar a migration no D1 remoto:
   `cd api && wrangler d1 execute coldigom --remote --file=migrations/024_material_kind_classes.sql`
3. Rodar a verificação do fim do arquivo no remoto; ela deve voltar vazia.
4. Com ok do dono, fazer o deploy do Worker.
5. Conferir: `curl -s https://coldigom-api.jairofilho79.workers.dev/api/plpcg/catalog | head -c 600` mostra `kindClasses`.
