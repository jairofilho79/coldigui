# Trecho da letra em dourado — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** quando a pesquisa da Home bate no louvor pela letra (não pelo título/número), o card do resultado mostra uma linha com o trecho da letra que deu match, com a parte casada em dourado.

**Architecture:** o backend `coldigom/api` calcula o trecho no servidor (função pura `buildLyricsExcerpt`, sem tocar a query FTS/LIKE existente) e devolve `lyrics_excerpt` em `GET /api/plpcg/praises`; o client `coldigui` propaga esse campo pelo canal já existente para dados extras do Coldigom (`ColdigomPraiseMetadata` → `LouvorGroup.coldigomMeta`) até `CarouselLouvorChip`, que reaproveita o widget `HighlightedText` já usado no título.

**Tech Stack:** `coldigom/api` — Cloudflare Worker, Hono, D1 (SQLite), TypeScript, Vitest. `coldigui` — Flutter, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-15-trecho-letra-pesquisa-design.md`

## Global Constraints

- Campo aditivo `lyrics_excerpt: string | null` — nunca remove nem renomeia campo existente em `GET /api/plpcg/praises`.
- Uma linha só: sem `\n` no trecho devolvido; ~120 caracteres no máximo; nunca corta uma palavra no meio.
- Só busca textual gera trecho — `parseNumericSearch` ou `extractYouTubeVideoId` verdadeiros ⇒ `lyrics_excerpt: null` sem query extra ao banco.
- **Sessão isolada no worktree `coldigui`:** este ambiente de execução só roda comandos `git` dentro de `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/lyric-search-snippet`. As Tarefas 1–3 (repo `coldigom/api`) editam arquivos e rodam `vitest` normalmente nesse repo (comandos não-`git` funcionam cross-repo), mas **não commitam** — cada uma termina com um passo manual («Entrega manual») em vez de `git commit`. Quem aplicar o plano precisa commitar essas três tarefas rodando os comandos indicados a partir de um terminal/sessão comum em `dev/coldigom` (fora deste worktree).
- Tarefas 4–7 (repo `coldigui`) commitam normalmente — este worktree já está isolado e autorizado para isso.

---

## Task 1: `coldigom/api` — helper puro `buildLyricsExcerpt`

**Files:**
- Create: `src/lyricsExcerpt.ts`
- Test: `src/__tests__/lyricsExcerpt.test.ts`

**Interfaces:**
- Produces: `export function buildLyricsExcerpt(lyrics: string, rawQuery: string): string | null` — usado pela Tarefa 2.

- [ ] **Step 1: Escrever os testes (falhando)**

Criar `src/__tests__/lyricsExcerpt.test.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { buildLyricsExcerpt } from '../lyricsExcerpt';

describe('buildLyricsExcerpt', () => {
  it('acha o termo mesmo sem o acento que a letra tem', () => {
    const lyrics = 'Ainda que a terra se abale, eu não temerei, pois Tu és comigo.';
    expect(buildLyricsExcerpt(lyrics, 'nao temerei')).toContain('não temerei');
  });

  it('acha o termo acentuado numa letra sem o mesmo acento', () => {
    const lyrics = 'e a chuva de bencaos cai sobre nos';
    expect(buildLyricsExcerpt(lyrics, 'chuva de bênçãos')).toContain('bencaos');
  });

  it('sem match nenhum devolve null', () => {
    expect(buildLyricsExcerpt('Grande é o Senhor', 'inexistente')).toBeNull();
  });

  it('letra vazia devolve null', () => {
    expect(buildLyricsExcerpt('', 'graça')).toBeNull();
  });

  it('busca vazia devolve null', () => {
    expect(buildLyricsExcerpt('Grande é o Senhor', '')).toBeNull();
  });

  it('palavra maior que a janela de contexto é omitida inteira, nunca cortada no meio', () => {
    const longWord = 'a'.repeat(70);
    const lyrics = `${longWord} termodobusca depois disso`;
    const excerpt = buildLyricsExcerpt(lyrics, 'termodobusca')!;
    expect(excerpt.startsWith('…')).toBe(true);
    expect(excerpt).not.toContain('a'.repeat(10));
    expect(excerpt).toContain('termodobusca');
  });

  it('sem conteúdo antes do match, não prefixa com reticências', () => {
    const lyrics = 'graça infinita cobre a minha vida';
    const excerpt = buildLyricsExcerpt(lyrics, 'graça')!;
    expect(excerpt.startsWith('…')).toBe(false);
  });

  it('sem conteúdo depois do match, não sufixa com reticências', () => {
    const lyrics = 'a minha vida é coberta pela graça';
    const excerpt = buildLyricsExcerpt(lyrics, 'graça')!;
    expect(excerpt.endsWith('…')).toBe(false);
  });

  it('prefere a frase completa a um token isolado', () => {
    const lyrics = 'não vou temer porque não temerei o mal';
    const excerpt = buildLyricsExcerpt(lyrics, 'não temerei')!;
    expect(excerpt).toContain('não temerei');
  });

  it('sem a frase completa, cai para o primeiro token', () => {
    const lyrics = 'eu não vou vacilar diante do inimigo';
    const excerpt = buildLyricsExcerpt(lyrics, 'não temerei')!;
    expect(excerpt).toContain('não');
  });

  it('quebras de linha da letra viram espaço — uma linha só', () => {
    const lyrics = 'Refrão:\nEu não\ntemerei\no mal';
    const excerpt = buildLyricsExcerpt(lyrics, 'não temerei')!;
    expect(excerpt).not.toMatch(/[\n\r]/);
    expect(excerpt).toContain('não temerei');
  });
});
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd "/Volumes/SSD 2TB SD/dev/coldigom/api" && npx vitest run src/__tests__/lyricsExcerpt.test.ts`
Expected: FAIL — `Cannot find module '../lyricsExcerpt'`.

- [ ] **Step 3: Implementar `src/lyricsExcerpt.ts`**

```ts
/**
 * Trecho de uma linha da letra ao redor do primeiro match de uma busca —
 * usado pelo card de resultado quando o match não está no título (D2/D3 do
 * design doc `2026-09-15-trecho-letra-pesquisa-design.md`).
 */

const MAX_CONTEXT_CHARS = 55;
const MAX_EXCERPT_CHARS = 120;

function stripDiacritics(text: string): string {
  return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

/** Mesma tokenização de `buildFtsMatchQuery` em `praiseQuery.ts`, sem a
 * parte específica de sintaxe FTS5. */
function tokenize(query: string): string[] {
  return query
    .trim()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter(Boolean);
}

/**
 * Acento-insensível, case-insensível, qualquer espaço em branco (inclusive
 * quebra de linha) vira um espaço — preservando 1 caractere de saída por
 * caractere de entrada, para que os índices da string normalizada valham
 * também para [input] original.
 */
function normalizeKeepingIndex(
  input: string
): { normalized: string; indexMap: number[] } {
  let normalized = '';
  const indexMap: number[] = [];
  for (let i = 0; i < input.length; i++) {
    const raw = input[i];
    const piece = /\s/.test(raw) ? ' ' : stripDiacritics(raw).toLowerCase();
    for (const ch of piece) {
      normalized += ch;
      indexMap.push(i);
    }
  }
  return { normalized, indexMap };
}

/**
 * Expande [matchStart, matchEnd) até a borda de palavra mais próxima (~55
 * caracteres de cada lado), troca espaços em branco por um espaço só e
 * corta em ~120 caracteres — sempre uma linha, nunca no meio de uma palavra.
 */
function extractWindow(text: string, matchStart: number, matchEnd: number): string {
  let left = matchStart - MAX_CONTEXT_CHARS;
  if (left <= 0) {
    left = 0;
  } else {
    while (left < matchStart && !/\s/.test(text[left])) left++;
    while (left < matchStart && /\s/.test(text[left])) left++;
  }

  let right = matchEnd + MAX_CONTEXT_CHARS;
  if (right >= text.length) {
    right = text.length;
  } else {
    while (right > matchEnd && !/\s/.test(text[right])) right--;
  }

  const prefix = left > 0 ? '…' : '';
  const suffix = right < text.length ? '…' : '';
  const collapsed = text.slice(left, right).replace(/\s+/g, ' ').trim();
  const excerpt = `${prefix}${collapsed}${suffix}`;

  return excerpt.length > MAX_EXCERPT_CHARS
    ? `${excerpt.slice(0, MAX_EXCERPT_CHARS - 1).trimEnd()}…`
    : excerpt;
}

export function buildLyricsExcerpt(lyrics: string, rawQuery: string): string | null {
  const trimmedLyrics = lyrics.trim();
  const tokens = tokenize(rawQuery);
  if (!trimmedLyrics || tokens.length === 0) return null;

  const { normalized, indexMap } = normalizeKeepingIndex(trimmedLyrics);
  const normTokens = tokens.map((t) => stripDiacritics(t).toLowerCase());

  const phraseMatch = new RegExp(normTokens.join('\\s+')).exec(normalized);
  const match = phraseMatch ?? new RegExp(normTokens[0]).exec(normalized);
  if (!match) return null;

  const matchStart = indexMap[match.index];
  const matchEnd = indexMap[match.index + match[0].length - 1] + 1;

  return extractWindow(trimmedLyrics, matchStart, matchEnd);
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd "/Volumes/SSD 2TB SD/dev/coldigom/api" && npx vitest run src/__tests__/lyricsExcerpt.test.ts`
Expected: PASS — 10 testes.

- [ ] **Step 5: Entrega manual (git bloqueado nesta sessão)**

Esta sessão está isolada no worktree `coldigui` e não pode rodar `git` em `dev/coldigom`. Os arquivos `src/lyricsExcerpt.ts` e `src/__tests__/lyricsExcerpt.test.ts` já estão escritos no working tree do repo `coldigom`. A partir de um terminal comum em `dev/coldigom` (ou outra sessão Claude Code aberta ali, fora deste worktree):

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom"
git checkout -b feat/trecho-letra-pesquisa
git add api/src/lyricsExcerpt.ts api/src/__tests__/lyricsExcerpt.test.ts
git commit -m "feat(api): helper de trecho da letra para o match da busca"
```

---

## Task 2: `coldigom/api` — `lyrics_excerpt` em `listPlpcgPraises`

**Files:**
- Modify: `src/plpcgPraises.ts:1-2` (imports), `src/plpcgPraises.ts:119-127` (assinatura/retorno), `src/plpcgPraises.ts:177-243` (corpo)
- Modify: `src/routes/praises.ts:139` (comentário da rota)
- Test: `src/__tests__/plpcgPraisesLyricsExcerpt.test.ts`

**Interfaces:**
- Consumes: `buildLyricsExcerpt(lyrics: string, rawQuery: string): string | null` (Tarefa 1); `parseNumericSearch`, `extractYouTubeVideoId` (já existem em `src/praiseQuery.ts`).
- Produces: cada item de `listPlpcgPraises(...).data` ganha `lyrics_excerpt: string | null` — consumido pela Tarefa 4 (client).

- [ ] **Step 1: Escrever o teste de integração (falhando)**

Criar `src/__tests__/plpcgPraisesLyricsExcerpt.test.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { listPlpcgPraises } from '../plpcgPraises';
import {
  buildOrderClause,
  buildWhereClause,
  resolveTagFilterGroups,
  TAG_LABEL_SQL,
  VALID_SORT_FIELDS,
  type SortField,
} from '../praiseQuery';

type Row = {
  id: string;
  name: string;
  number: string | null;
  author: string | null;
  rhythm: string | null;
  tonality: string | null;
  category: string | null;
  group_id: string | null;
  tag_ids: string | null;
  tag_names: string | null;
  has_lyrics: number;
};

function fakeDb(rows: Row[], lyricsById: Record<string, string>) {
  return {
    prepare: (sql: string) => {
      if (sql.includes('FROM material_kinds')) {
        return { bind: () => ({ all: async () => ({ results: [] }) }) };
      }
      if (sql.trim().startsWith('SELECT COUNT(*)')) {
        return { bind: (..._b: unknown[]) => ({ first: async () => ({ total: rows.length }) }) };
      }
      if (sql.includes('FROM praise_materials')) {
        return { bind: () => ({ all: async () => ({ results: [] }) }) };
      }
      if (sql.includes('SELECT id, lyrics FROM praises')) {
        return {
          bind: (...ids: string[]) => ({
            all: async () => ({
              results: ids
                .filter((id) => id in lyricsById)
                .map((id) => ({ id, lyrics: lyricsById[id] })),
            }),
          }),
        };
      }
      return { bind: () => ({ all: async () => ({ results: rows }) }) };
    },
  } as unknown as D1Database;
}

const deps = {
  buildWhereClause,
  buildOrderClause: (sort: string, order: 'ASC' | 'DESC', search?: string) =>
    buildOrderClause(sort as SortField, order, search),
  validSortFields: VALID_SORT_FIELDS,
  resolveTagFilterGroups,
  tagLabelSql: TAG_LABEL_SQL,
};

function row(over: Partial<Row>): Row {
  return {
    id: 'p1',
    name: 'Refúgio e Fortaleza',
    number: '087',
    author: null,
    rhythm: null,
    tonality: null,
    category: null,
    group_id: null,
    tag_ids: null,
    tag_names: null,
    has_lyrics: 1,
    ...over,
  };
}

describe('listPlpcgPraises — lyrics_excerpt', () => {
  it('preenche lyrics_excerpt quando a busca textual bate na letra', async () => {
    const db = fakeDb(
      [row({})],
      { p1: 'Ainda que a terra se abale, eu não temerei, pois Tu és comigo.' }
    );

    const result = await listPlpcgPraises(
      db,
      { search: 'não temerei', page: 1, limit: 20, offset: 0, order: 'ASC' },
      deps
    );

    expect(result.data[0].lyrics_excerpt).toContain('não temerei');
  });

  it('não busca letra nem preenche lyrics_excerpt em busca numérica', async () => {
    const db = fakeDb([row({})], { p1: 'letra que contém 87 em algum lugar' });
    let lyricsQueryCalled = false;
    const original = db.prepare.bind(db);
    (db as unknown as { prepare: typeof db.prepare }).prepare = (sql: string) => {
      if (sql.includes('SELECT id, lyrics FROM praises')) lyricsQueryCalled = true;
      return original(sql);
    };

    const result = await listPlpcgPraises(
      db,
      { search: '87', page: 1, limit: 20, offset: 0, order: 'ASC' },
      deps
    );

    expect(result.data[0].lyrics_excerpt).toBeNull();
    expect(lyricsQueryCalled).toBe(false);
  });

  it('sem busca, nenhuma linha ganha lyrics_excerpt e não há query extra', async () => {
    const db = fakeDb([row({})], { p1: 'não temerei' });
    let lyricsQueryCalled = false;
    const original = db.prepare.bind(db);
    (db as unknown as { prepare: typeof db.prepare }).prepare = (sql: string) => {
      if (sql.includes('SELECT id, lyrics FROM praises')) lyricsQueryCalled = true;
      return original(sql);
    };

    const result = await listPlpcgPraises(
      db,
      { search: '', page: 1, limit: 20, offset: 0, order: 'ASC' },
      deps
    );

    expect(result.data[0].lyrics_excerpt).toBeNull();
    expect(lyricsQueryCalled).toBe(false);
  });

  it('linha sem letra (has_lyrics=0) não entra na busca de trecho', async () => {
    const db = fakeDb([row({ has_lyrics: 0 })], { p1: 'não temerei' });

    const result = await listPlpcgPraises(
      db,
      { search: 'não temerei', page: 1, limit: 20, offset: 0, order: 'ASC' },
      deps
    );

    expect(result.data[0].lyrics_excerpt).toBeNull();
  });
});
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd "/Volumes/SSD 2TB SD/dev/coldigom/api" && npx vitest run src/__tests__/plpcgPraisesLyricsExcerpt.test.ts`
Expected: FAIL — `result.data[0].lyrics_excerpt` é `undefined`, não presente no tipo/retorno.

- [ ] **Step 3: Editar `src/plpcgPraises.ts`**

No topo do arquivo, adicionar aos imports existentes (linha 1-2 hoje são só `parseListNumbers`/`materialKindLabels`):

```ts
import { parseListNumbers } from './queryParams';
import { labelFor, loadMaterialKindLabels } from './materialKindLabels';
import { buildLyricsExcerpt } from './lyricsExcerpt';
import { extractYouTubeVideoId, parseNumericSearch } from './praiseQuery';
```

No tipo de retorno de `listPlpcgPraises` (hoje `Array<Omit<ListRow, 'has_lyrics'> & { materials: SlimMaterial[] }>`), acrescentar o novo campo:

```ts
export async function listPlpcgPraises(
  db: D1Database,
  query: PlpcgListQuery,
  deps: PlpcgListDeps
): Promise<{
  data: Array<
    Omit<ListRow, 'has_lyrics'> & { materials: SlimMaterial[]; lyrics_excerpt: string | null }
  >;
  pagination: { page: number; limit: number; total: number; totalPages: number };
}> {
```

Logo depois de `const rows = (result.results ?? []) as ListRow[];` (dentro do `try`, antes do bloco de `countQuery`), inserir:

```ts
      const isTextSearch =
        Boolean(query.search) &&
        !parseNumericSearch(query.search) &&
        !extractYouTubeVideoId(query.search);
      const excerptByPraiseId = new Map<string, string>();
      if (isTextSearch) {
        const lyricsCandidateIds = rows.filter((r) => r.has_lyrics === 1).map((r) => r.id);
        if (lyricsCandidateIds.length > 0) {
          const placeholders = lyricsCandidateIds.map(() => '?').join(',');
          const lyricsResult = await db
            .prepare(`SELECT id, lyrics FROM praises WHERE id IN (${placeholders})`)
            .bind(...lyricsCandidateIds)
            .all();
          for (const lyricsRow of (lyricsResult.results ?? []) as {
            id: string;
            lyrics: string | null;
          }[]) {
            const excerpt = buildLyricsExcerpt(lyricsRow.lyrics ?? '', query.search);
            if (excerpt) excerptByPraiseId.set(lyricsRow.id, excerpt);
          }
        }
      }
```

E no `data = rows.map(...)` final, acrescentar o campo ao objeto devolvido:

```ts
      const data = rows.map(({ has_lyrics, ...row }) => {
        const materials = materialsByPraise.get(row.id) ?? [];
        if (has_lyrics) {
          materials.push({
            id: null,
            praise_id: row.id,
            material_kind: null,
            type: 'lyrics',
            r2_key: null,
            url: null,
            material_kind_name: 'Letra',
          });
        }
        return { ...row, materials, lyrics_excerpt: excerptByPraiseId.get(row.id) ?? null };
      });
```

- [ ] **Step 4: Atualizar o comentário da rota**

Em `src/routes/praises.ts:139`, trocar:

```ts
  // GET /api/plpcg/praises - Lightweight list for PLPCG (no lyrics text; slim materials)
```

por:

```ts
  // GET /api/plpcg/praises - Lightweight list for PLPCG (slim materials; lyrics_excerpt
  // when the search matches the lyrics — no full lyrics text)
```

- [ ] **Step 5: Rodar e confirmar que passa (e que nada quebrou)**

Run: `cd "/Volumes/SSD 2TB SD/dev/coldigom/api" && npx vitest run src/__tests__/plpcgPraisesLyricsExcerpt.test.ts src/__tests__/praisesQueryParams.test.ts src/__tests__/praiseListResilience.test.ts`
Expected: PASS em todos — a suíte pré-existente (`praisesQueryParams`, `praiseListResilience`) continua verde, confirmando que a mudança não afetou o fallback FTS/LIKE nem a validação de parâmetros.

Run também a suíte inteira para garantir que nada mais quebrou: `cd "/Volumes/SSD 2TB SD/dev/coldigom/api" && npx vitest run`
Expected: PASS.

- [ ] **Step 6: Entrega manual (git bloqueado nesta sessão)**

A partir de um terminal comum em `dev/coldigom` (mesma branch `feat/trecho-letra-pesquisa` criada na Tarefa 1):

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom"
git add api/src/plpcgPraises.ts api/src/routes/praises.ts api/src/__tests__/plpcgPraisesLyricsExcerpt.test.ts
git commit -m "feat(api): devolve lyrics_excerpt em GET /api/plpcg/praises"
```

---

## Task 3: `coldigom/api` — publicar o backend antes do client depender dele

**Files:** nenhum arquivo novo — só a entrega manual.

- [ ] **Step 1: Entrega manual (fora desta sessão)**

O `lyrics_excerpt` só chega ao app depois que o Worker `coldigom-api.jairofilho79.workers.dev` for atualizado. A partir de `dev/coldigom/api`, fora deste worktree:

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/api"
npm run deploy
```

Isso não bloqueia as Tarefas 4–7 (client): o campo é aditivo e, até o deploy acontecer, `lyrics_excerpt` simplesmente não vem na resposta — `PraiseDetailDto.fromJson` (Tarefa 4) trata ausência como `null` normalmente.

---

## Task 4: `coldigui` — `PraiseDetailDto.lyricsExcerpt`

**Files:**
- Modify: `lib/features/coldigom/data/models/praise_dto.dart:93-129`
- Test: `test/unit/features/coldigom/praise_dto_test.dart`

**Interfaces:**
- Produces: `PraiseDetailDto.lyricsExcerpt` (`String?`) — consumido pela Tarefa 5.

- [ ] **Step 1: Escrever o teste (falhando)**

Em `test/unit/features/coldigom/praise_dto_test.dart`, acrescentar dentro do `group('PraiseDetailDto.fromJson', ...)` existente:

```dart
    test('lê lyrics_excerpt quando presente e tolera ausência', () {
      final comTrecho = PraiseDetailDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'number': '001',
        'rhythm': 'Fox',
        'lyrics_excerpt': '…e a chuva de bênçãos cai sobre nós…',
        'materials': const [],
      });
      expect(comTrecho.lyricsExcerpt, '…e a chuva de bênçãos cai sobre nós…');

      final semTrecho = PraiseDetailDto.fromJson({
        'id': 'p2',
        'name': 'Hino',
        'number': '002',
        'rhythm': 'Fox',
        'materials': const [],
      });
      expect(semTrecho.lyricsExcerpt, isNull);
    });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/unit/features/coldigom/praise_dto_test.dart`
Expected: FAIL — `The getter 'lyricsExcerpt' isn't defined for the type 'PraiseDetailDto'`.

- [ ] **Step 3: Editar `PraiseDetailDto`**

Em `lib/features/coldigom/data/models/praise_dto.dart`, no construtor (linha ~94-104):

```dart
class PraiseDetailDto {
  const PraiseDetailDto({
    required this.id,
    required this.name,
    required this.number,
    required this.rhythm,
    required this.materials,
    this.tonality = '',
    this.category = '',
    this.author = '',
    this.tagNames = const [],
    this.lyricsExcerpt,
  });

  final String id;
  final String name;
  final String number;
  final String rhythm;
  final String tonality;
  final String category;
  final String author;
  final List<String> tagNames;
  final List<MaterialDto> materials;

  /// Trecho de uma linha da letra ao redor do match da busca — só quando a
  /// busca bateu na letra; `null` no browse comum ou match só no título.
  final String? lyricsExcerpt;
```

No `fromJson` (linha ~116-129):

```dart
  factory PraiseDetailDto.fromJson(Map<String, dynamic> json) {
    final materialsJson = json['materials'] as List<dynamic>? ?? const [];
    return PraiseDetailDto(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String? ?? '',
      rhythm: json['rhythm'] as String? ?? '',
      tonality: json['tonality'] as String? ?? '',
      category: json['category'] as String? ?? '',
      author: json['author'] as String? ?? '',
      tagNames: splitColdigomCsv(json['tag_names']),
      lyricsExcerpt: json['lyrics_excerpt'] as String?,
      materials: _parseMaterials(materialsJson),
    );
  }
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/unit/features/coldigom/praise_dto_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/coldigom/data/models/praise_dto.dart test/unit/features/coldigom/praise_dto_test.dart
git commit -m "feat(coldigom): PraiseDetailDto lê lyrics_excerpt"
```

---

## Task 5: `coldigui` — `ColdigomPraiseMetadata` + adapter

**Files:**
- Modify: `lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart`
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart:17-26`
- Test: `test/unit/features/coldigom/coldigom_louvor_adapter_test.dart`

**Interfaces:**
- Consumes: `PraiseDetailDto.lyricsExcerpt` (Tarefa 4).
- Produces: `ColdigomPraiseMetadata.lyricsExcerpt` (`String?`), populado por `ColdigomLouvorAdapter.toMetadata` — consumido pela Tarefa 6 via `LouvorGroup.coldigomMeta`.

- [ ] **Step 1: Escrever o teste (falhando)**

Em `test/unit/features/coldigom/coldigom_louvor_adapter_test.dart`, acrescentar ao final do `main()`, depois do teste `'toMetadata e DetailDto parseiam tag_names'`:

```dart
  test('toMetadata propaga lyricsExcerpt', () {
    final detail = PraiseDetailDto.fromJson({
      'id': 'p1',
      'name': 'Hino',
      'number': '001',
      'rhythm': 'Fox',
      'lyrics_excerpt': '…e a chuva de bênçãos cai sobre nós…',
      'materials': const [],
    });

    final meta = ColdigomLouvorAdapter.toMetadata(detail);
    expect(meta.lyricsExcerpt, '…e a chuva de bênçãos cai sobre nós…');
  });

  test('toMetadata sem lyrics_excerpt no JSON devolve null', () {
    final detail = PraiseDetailDto.fromJson({
      'id': 'p1',
      'name': 'Hino',
      'number': '001',
      'rhythm': 'Fox',
      'materials': const [],
    });

    expect(ColdigomLouvorAdapter.toMetadata(detail).lyricsExcerpt, isNull);
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/unit/features/coldigom/coldigom_louvor_adapter_test.dart`
Expected: FAIL — `The getter 'lyricsExcerpt' isn't defined for the type 'ColdigomPraiseMetadata'`.

- [ ] **Step 3: Editar `ColdigomPraiseMetadata`**

```dart
/// Metadados de um praise Coldigom para o sheet de materiais e para o
/// trecho da letra no card de resultado de busca (C5.1).
class ColdigomPraiseMetadata {
  const ColdigomPraiseMetadata({
    required this.name,
    this.tonality = '',
    this.author = '',
    this.rhythm = '',
    this.category = '',
    this.tagNames = const [],
    this.lyricsExcerpt,
  });

  final String name;
  final String tonality;
  final String author;
  final String rhythm;
  final String category;
  final List<String> tagNames;

  /// Trecho da letra ao redor do match da busca — `null` fora de uma busca
  /// que bateu na letra.
  final String? lyricsExcerpt;

  bool get hasAnyField =>
      tonality.trim().isNotEmpty ||
      author.trim().isNotEmpty ||
      rhythm.trim().isNotEmpty ||
      category.trim().isNotEmpty ||
      tagNames.isNotEmpty;
}
```

- [ ] **Step 4: Editar `ColdigomLouvorAdapter.toMetadata`**

Em `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart:17-26`:

```dart
  static ColdigomPraiseMetadata toMetadata(PraiseDetailDto praise) {
    return ColdigomPraiseMetadata(
      name: praise.name,
      tonality: praise.tonality,
      author: praise.author,
      rhythm: praise.rhythm,
      category: praise.category,
      tagNames: praise.tagNames,
      lyricsExcerpt: praise.lyricsExcerpt,
    );
  }
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `flutter test test/unit/features/coldigom/coldigom_louvor_adapter_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart test/unit/features/coldigom/coldigom_louvor_adapter_test.dart
git commit -m "feat(coldigom): ColdigomPraiseMetadata carrega o trecho da letra"
```

---

## Task 6: `coldigui` — `CarouselLouvorChip` exibe o trecho (opção A)

**Files:**
- Modify: `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart:86-260`
- Test: `test/widget/features/carousel/carousel_louvor_chip_test.dart`

**Interfaces:**
- Consumes: nenhuma interface nova de outra tarefa — parâmetro de entrada simples (`String?`).
- Produces: `CarouselLouvorChip({..., String? lyricsSnippet})` — consumido pela Tarefa 7.

- [ ] **Step 1: Escrever os testes (falhando)**

Em `test/widget/features/carousel/carousel_louvor_chip_test.dart`, ajustar `_wrapChip` para aceitar o novo parâmetro e acrescentar os testes:

```dart
Widget _wrapChip(
  double width, {
  CarouselLouvorChipVariant variant = CarouselLouvorChipVariant.modal,
  bool showDragHandle = false,
  VoidCallback? onRemove,
  VoidCallback? onTap,
  String? highlightQuery,
  String? lyricsSnippet,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: CarouselLouvorChip(
            item: _item,
            variant: variant,
            showDragHandle: showDragHandle,
            onTap: onTap,
            onRemove: onRemove,
            highlightQuery: highlightQuery,
            lyricsSnippet: lyricsSnippet,
          ),
        ),
      ),
    ),
  );
}
```

E, no `main()`, os novos casos:

```dart
  testWidgets('sem lyricsSnippet, nenhum trecho aparece', (tester) async {
    await tester.pumpWidget(_wrapChip(320));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('chuva de bênçãos'),
      findsNothing,
    );
  });

  testWidgets('com lyricsSnippet, o trecho aparece abaixo do título', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapChip(
        320,
        lyricsSnippet: '…e a chuva de bênçãos cai sobre nós…',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('chuva de bênçãos'),
      findsOneWidget,
    );
  });

  testWidgets('lyricsSnippet vazio não desenha a linha do trecho', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapChip(320, lyricsSnippet: '   '));
    await tester.pumpAndSettle();

    // Sem trecho visível: só o título e a linha de metadados (2 Text.rich/Text
    // diretos do chip) — nenhum terceiro texto de conteúdo variável.
    expect(find.textContaining('…'), findsNothing);
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/widget/features/carousel/carousel_louvor_chip_test.dart`
Expected: FAIL — `The named parameter 'lyricsSnippet' isn't defined`.

- [ ] **Step 3: Editar `CarouselLouvorChip`**

No construtor (perto de `highlightQuery`, linha ~93-132):

```dart
  const CarouselLouvorChip({
    required this.item,
    this.variant = CarouselLouvorChipVariant.modal,
    this.metadataSummary,
    this.materialKindsGroup,
    this.onMaterialKindTap,
    this.highlightQuery,
    this.lyricsSnippet,
    this.showDragHandle = false,
    this.onTap,
    this.onLongPress,
    this.onRemove,
    this.onAdd,
    this.onShare,
    this.isAdded = false,
    this.loading = false,
    this.shareLoading = false,
    this.offlineAvailability = PdfOfflineAvailability.notAvailable,
    this.showNavArrows = false,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.onPrevious,
    this.onNext,
    super.key,
  });
```

```dart
  /// Termo buscado (Home) a destacar no título — cor ouro do tema (C5). Sem
  /// termo ou sem match, o título renderiza normal.
  final String? highlightQuery;

  /// Trecho de uma linha da letra ao redor do match da busca (C5.1) — vem de
  /// `LouvorGroup.coldigomMeta?.lyricsExcerpt`. `null`/vazio não desenha
  /// linha nenhuma; o card fica igual ao de hoje.
  final String? lyricsSnippet;
```

No `build()`, entre o `HighlightedText` do título e o `ChipMetadataRow` (hoje linhas ~246-259: `HighlightedText(...)`, depois `const SizedBox(height: 2)`, depois `ChipMetadataRow(...)`):

```dart
                      HighlightedText(
                        text: _titleLine(item, _isTopBar),
                        query: highlightQuery ?? '',
                        style: AppTypography.headline.copyWith(
                          fontSize: width < _compactWidth ? 12 : 14,
                          height: 1.1,
                          color: AppColors.textLight,
                          shadows: const [],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((lyricsSnippet ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        HighlightedText(
                          text: lyricsSnippet!,
                          query: highlightQuery ?? '',
                          style: AppTypography.body.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: width < _compactWidth ? 11 : 12.5,
                            height: 1.2,
                            color: AppColors.textLight.withValues(alpha: 0.64),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      ChipMetadataRow(
```

(O restante do `ChipMetadataRow(...)` continua idêntico.)

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/widget/features/carousel/carousel_louvor_chip_test.dart`
Expected: PASS — inclusive os testes pré-existentes do arquivo (nenhum outro comportamento muda).

- [ ] **Step 5: Commit**

```bash
git add lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart test/widget/features/carousel/carousel_louvor_chip_test.dart
git commit -m "feat(carousel): CarouselLouvorChip exibe o trecho da letra em dourado"
```

---

## Task 7: `coldigui` — `LouvorGroupCard` propaga `lyricsSnippet`

**Files:**
- Modify: `lib/features/catalog/presentation/widgets/louvor_group_card.dart:300-371`
- Modify: `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart:94-96` (comentário desatualizado)
- Test: `test/widget/features/catalog/louvor_group_card_lyrics_snippet_test.dart`

**Interfaces:**
- Consumes: `CarouselLouvorChip({..., String? lyricsSnippet})` (Tarefa 6); `LouvorGroup.coldigomMeta?.lyricsExcerpt` (Tarefa 5, já flui por `LouvorGroup` sem mudança nela).

- [ ] **Step 1: Escrever o teste (falhando)**

Criar `test/widget/features/catalog/louvor_group_card_lyrics_snippet_test.dart`, seguindo o padrão de `louvor_group_card_offline_badge_test.dart` (`ProviderScope` com `sharedPreferencesProvider` mockado):

```dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvorFixture(String pdfId) => Louvor(
  nome: 'Refúgio e Fortaleza',
  numero: '087',
  categoria: 'ColAdultos',
  classificacao: 'Partitura',
  pdf: 'ColAdultos/087.pdf',
  pdfId: pdfId,
  groupId: '087:refugio',
  searchTitleNorm: 'refugio e fortaleza',
  searchContentTokens: const [],
  searchCompactContent: '',
);

LouvorGroup _groupWith(ColdigomPraiseMetadata? meta, String pdfId) => LouvorGroup(
  groupId: '087:refugio',
  numero: '087',
  nome: 'Refúgio e Fortaleza',
  sections: [
    LouvorMaterialSection(
      classificacao: 'Partitura',
      displayLabel: 'Partitura',
      materials: [
        LouvorMaterialEntry(
          categoria: 'ColAdultos',
          pdfId: pdfId,
          louvor: _louvorFixture(pdfId),
        ),
      ],
    ),
  ],
).withColdigomMeta(meta);

Future<void> _pumpCard(WidgetTester tester, LouvorGroup group) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(body: LouvorGroupCard(group: group)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final pdfId = encodePdfId('ColAdultos/087.pdf');

  testWidgets('coldigomMeta com lyricsExcerpt chega até o chip', (tester) async {
    await _pumpCard(
      tester,
      _groupWith(
        const ColdigomPraiseMetadata(
          name: 'Refúgio e Fortaleza',
          lyricsExcerpt: '…caiam ao mar, eu não temerei, pois Tu…',
        ),
        pdfId,
      ),
    );

    expect(find.textContaining('não temerei'), findsOneWidget);
  });

  testWidgets('sem coldigomMeta, nenhum trecho aparece', (tester) async {
    await _pumpCard(tester, _groupWith(null, pdfId));

    expect(find.textContaining('não temerei'), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/widget/features/catalog/louvor_group_card_lyrics_snippet_test.dart`
Expected: FAIL — o primeiro teste não encontra o texto (o chip ainda não recebe `lyricsSnippet`).

- [ ] **Step 3: Editar `LouvorGroupCard.build()`**

Em `lib/features/catalog/presentation/widgets/louvor_group_card.dart`, logo após a linha `final highlightQuery = ref.watch(homeSearchDebouncedQueryProvider);` (linha ~300):

```dart
    final highlightQuery = ref.watch(homeSearchDebouncedQueryProvider);
    final lyricsSnippet = widget.group.coldigomMeta?.lyricsExcerpt;
```

E no `CarouselLouvorChip(...)` retornado (linha ~356-370), acrescentar o parâmetro:

```dart
      child: CarouselLouvorChip(
        item: chipItem,
        metadataSummary: metadataSummary,
        materialKindsGroup: widget.group,
        onMaterialKindTap: (_) => unawaited(_openMaterialSheet()),
        highlightQuery: highlightQuery,
        lyricsSnippet: lyricsSnippet,
        onTap: isLoading ? null : _handleTap,
        onLongPress: isLoading
            ? null
            : () => unawaited(_handleLongPress(preferredMaterial)),
        onAdd: onAdd,
        isAdded: isMultiMaterial ? false : isAdded,
        loading: isLoading,
        offlineAvailability: offlineAvailability,
      ),
```

- [ ] **Step 4: Atualizar o comentário desatualizado**

Em `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart:94-96`, trocar:

```dart
  /// Listagem PLPCG com materials slim (`GET /api/plpcg/praises`).
  ///
  /// Busca `q` ainda encontra por letra no servidor; a resposta não inclui
  /// o texto da letra. [cancelToken] aborta a requisição de verdade ...
```

por:

```dart
  /// Listagem PLPCG com materials slim (`GET /api/plpcg/praises`).
  ///
  /// Busca `q` ainda encontra por letra no servidor; a resposta traz um
  /// trecho curto (`lyrics_excerpt`, uma linha) quando o match foi na letra
  /// — nunca o texto completo. [cancelToken] aborta a requisição de verdade ...
```

(Manter o restante do comentário original após "...".)

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `flutter test test/widget/features/catalog/louvor_group_card_lyrics_snippet_test.dart`
Expected: PASS.

Rodar também a suíte de widgets do card e do chip inteira, para garantir que nada quebrou:

Run: `flutter test test/widget/features/catalog/ test/widget/features/carousel/`
Expected: PASS em tudo.

- [ ] **Step 6: Commit**

```bash
git add lib/features/catalog/presentation/widgets/louvor_group_card.dart lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart test/widget/features/catalog/louvor_group_card_lyrics_snippet_test.dart
git commit -m "feat(catalog): LouvorGroupCard propaga o trecho da letra para o chip"
```

---

## Task 8: Verificação manual fim a fim

**Files:** nenhum.

- [ ] **Step 1: Rodar a suíte completa do client**

Run: `flutter test`
Expected: PASS em tudo (nenhuma regressão nas Tarefas 4-7).

- [ ] **Step 2: Rodar a suíte completa do backend**

Run: `cd "/Volumes/SSD 2TB SD/dev/coldigom/api" && npx vitest run`
Expected: PASS em tudo.

- [ ] **Step 3: Teste manual (depois do deploy da Tarefa 3)**

Com `coldigom-api` já publicado (Tarefa 3) e o app rodando local (`flutter run -d chrome` ou dispositivo, apontando pro `dart_defines` de dev/prod que já tem `COLDIGOM_API_BASE_URL`): na Home, buscar um trecho presente só na letra de um louvor Coldigom conhecido (não no título) e conferir a linha dourada abaixo do título, uma linha só, com "…" quando truncada. Buscar por um termo que só existe no título continua sem a linha (a menos que a letra também contenha o termo).

- [ ] **Step 4: Atualizar o estado da spec**

Em `docs/superpowers/specs/2026-09-15-trecho-letra-pesquisa-design.md`, trocar a linha `**Estado:** aprovado (...)` para `**Estado:** implementado — 2026-09-15` (ou a data real de conclusão), e commitar:

```bash
git add docs/superpowers/specs/2026-09-15-trecho-letra-pesquisa-design.md
git commit -m "docs(spec): marca trecho da letra como implementado"
```
