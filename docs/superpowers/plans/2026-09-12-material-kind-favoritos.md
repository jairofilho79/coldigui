# Material Kinds Favoritos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O usuário logado escolhe até 5 `material_kinds` do Coldigom em ordem de preferência numa tela do perfil; o sheet de materiais lista esses tipos primeiro. Preferência persiste por conta no Worker `plpcg-catalog` com cache local e sync offline-first.

**Architecture:** Worker ganha a tabela `user_material_kind_prefs` (um documento por usuário, last-write-wins por `updatedAt`) e `GET/PUT /api/material-kind-prefs`. No Flutter, feature nova `lib/features/material_kind_prefs/` (domain/data/presentation, espelhando `features/audio_flags`) com cache em SharedPreferences por `googleSub`, usecase `SyncMaterialKindPrefs`, providers Riverpod e a tela `FavoriteMaterialKindsScreen`. As entidades Coldigom ganham `materialKindId`; `MaterialSheet` reordena cada aba com `orderByFavoriteKinds`.

**Tech Stack:** Flutter 3 + Riverpod 3 (`Notifier`/`AsyncNotifier`), Dio, SharedPreferences, go_router, flutter gen-l10n (`app_pt.arb` é o template); Worker Cloudflare em TypeScript com testes `node --test` e o `FakeD1Database` do repo.

**Spec:** `docs/superpowers/specs/2026-09-12-material-kind-favoritos-design.md`

## Global Constraints

- Máximo **5** ids (`kMaxFavoriteMaterialKinds = 5`), sem duplicata; a ordem do array **é** a preferência.
- **Só Coldigom**: materiais PLPCG têm `materialKindId == null` e nunca mudam de posição. `LouvorCache` (Isar) **não muda**.
- **Só logado**: usuário `null` → `MaterialKindPrefs.empty` → sheet igual a hoje. Chave local por `googleSub`: `material_kind_prefs.<sub>`.
- Cache local em **SharedPreferences** (não Isar). Nunca ler `sharedPreferencesProvider` quando não há usuário (em vários testes ele não tem override e lança `UnimplementedError`).
- Worker: rotas sob `withAuth`, CORS modo `'playlists'`, `409` devolve o documento remoto, sem `DELETE`, sem validar ids contra o coldigom.
- Comentários e strings de UI em **português** (pt é o template da l10n; `en` sempre acompanha). Comentários seguem o tom do código vizinho: explicam o *porquê*, não o *o quê*.
- Antes de cada commit Flutter: `dart format` nos arquivos tocados e `flutter analyze` sem erros novos. Antes de cada commit do Worker: `npm test` verde.
- Commits terminam com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01CrXSHS498GwYgf1CMs6yHi
  ```
- Baseline conhecido: `pdfrx_viewer_adapter_test` (3 casos) e `reconcile_offline_index_benchmark_test` (1 caso) falham por **timeout** sob carga — pré-existente, não relacionado. Não tentar corrigir.
- Todos os comandos rodam a partir da raiz da worktree `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/material-kind-favoritos` (para o Worker, `cd workers/plpcg-catalog` dentro dela).

---

## File map

**Worker (`workers/plpcg-catalog/`)**
- Create `migrations/0010_create_user_material_kind_prefs.sql` — tabela.
- Create `src/material_kind_prefs/handlers.ts` — `getMaterialKindPrefs`, `putMaterialKindPrefs`, tipos e validação.
- Create `src/material_kind_prefs/handlers.test.ts`.
- Modify `src/test/fake_d1.ts` — suporte à tabela nova (chave só `user_id`).
- Modify `src/index.ts` — `handleMaterialKindPrefs` + despacho + `corsModeForPath`.
- Modify `README.md` — duas linhas na tabela de endpoints.

**Flutter — id do kind nos materiais**
- Modify `lib/features/coldigom/data/models/praise_dto.dart` (`MaterialDto.materialKindId`).
- Modify `lib/features/catalog/domain/entities/louvor.dart`, `lib/features/audio_player/domain/entities/audio_track.dart`, `lib/features/chords/domain/entities/chord_material.dart`, `lib/features/gestures/domain/entities/gesture_material.dart`, `lib/features/catalog/domain/entities/youtube_material.dart` (campo `materialKindId`).
- Modify `lib/features/catalog/domain/entities/catalog_material.dart` (getter).
- Modify `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`.

**Flutter — feature `lib/features/material_kind_prefs/`**
- `domain/entities/material_kind_prefs.dart` — entidade + `kMaxFavoriteMaterialKinds`.
- `domain/repositories/material_kind_prefs_repository.dart`.
- `domain/usecases/order_by_favorite_kinds.dart`.
- `domain/usecases/sync_material_kind_prefs.dart`.
- `data/datasources/material_kind_prefs_local_datasource.dart`.
- `data/datasources/material_kind_prefs_remote_datasource.dart` (+ `MaterialKindPrefsConflict`).
- `data/repositories/material_kind_prefs_repository_impl.dart`.
- `data/providers/material_kind_prefs_providers.dart`.
- `presentation/providers/coldigom_material_kinds_provider.dart`.
- `presentation/providers/material_kind_prefs_provider.dart` (+ `favoriteMaterialKindRankProvider`).
- `presentation/providers/material_kind_prefs_sync_provider.dart`.
- `presentation/pages/favorite_material_kinds_screen.dart`.

**Flutter — integração**
- Modify `lib/core/constants/api_endpoints.dart`, `lib/core/routing/route_paths.dart`, `lib/core/routing/app_router.dart`, `lib/features/app_shell/presentation/shell_scaffold.dart`, `lib/features/app_shell/presentation/pages/profile_screen.dart`, `lib/features/catalog/presentation/widgets/material_sheet.dart`, `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`.

---

### Task 1: Worker — tabela, handlers e rotas

**Files:**
- Create: `workers/plpcg-catalog/migrations/0010_create_user_material_kind_prefs.sql`
- Create: `workers/plpcg-catalog/src/material_kind_prefs/handlers.ts`
- Create: `workers/plpcg-catalog/src/material_kind_prefs/handlers.test.ts`
- Modify: `workers/plpcg-catalog/src/test/fake_d1.ts`
- Modify: `workers/plpcg-catalog/src/index.ts` (imports no topo; `corsModeForPath` ~linha 304; despacho ~linha 500)
- Modify: `workers/plpcg-catalog/README.md` (tabela de endpoints)

**Interfaces:**
- Produces (contrato HTTP que a Task 4 consome):
  - `GET /api/material-kind-prefs` → `200 {"kindIds": string[], "updatedAt": string, "version": number}` ou `204` sem corpo.
  - `PUT /api/material-kind-prefs` body `{"kindIds": string[], "updatedAt": string}` → `200` mesmo formato do GET; `409` com o documento remoto; `400 {"error": string}`.

- [ ] **Step 1: Migração**

```sql
-- Migration number: 0010  2026-09-12T00:00:00.000Z
-- Um documento por usuário: a lista ordenada (≤ 5) dos material_kinds Coldigom
-- favoritos. Sem tombstone — "sem favoritos" é kind_ids = '[]'.
CREATE TABLE user_material_kind_prefs (
  user_id     TEXT PRIMARY KEY,
  kind_ids    TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  version     INTEGER NOT NULL DEFAULT 1
);
```

- [ ] **Step 2: Estender o `FakeD1Database`**

Em `src/test/fake_d1.ts`:

1. Junto aos outros tipos de linha (perto de `AudioFlagRow`), adicionar:

```ts
/** Linha de `user_material_kind_prefs` (um documento por usuário). */
export interface MaterialKindPrefsRow {
  user_id: string;
  kind_ids: string;
  updated_at: string;
  version: number;
}
```

2. Em `FakeD1Options`, adicionar `materialKindPrefs?: MaterialKindPrefsRow[];`. Na classe, ao lado de `audioFlags`:

```ts
  /** Linhas de `user_material_kind_prefs`, por `user_id`. */
  readonly materialKindPrefs = new Map<string, MaterialKindPrefsRow>();
```

e no `constructor`: `for (const row of options.materialKindPrefs ?? []) this.materialKindPrefs.set(row.user_id, row);`

3. Em `runQuery`, **antes** do bloco `if (/^SELECT/i...)`, inserir o despacho da tabela nova (ela tem chave simples, então não passa pelo `tableFor` genérico):

```ts
    if (/user_material_kind_prefs/i.test(normalized)) {
      return this.runMaterialKindPrefs(normalized, bindings);
    }
```

4. Método privado na classe:

```ts
  /**
   * `user_material_kind_prefs` é a única tabela com chave só de `user_id`:
   * SELECT por usuário, INSERT com `version = 1` literal e UPDATE cujo WHERE
   * consome o último binding.
   */
  private runMaterialKindPrefs(normalized: string, bindings: unknown[]): unknown[] {
    if (/^SELECT/i.test(normalized)) {
      const row = this.materialKindPrefs.get(bindings[0] as string);
      return row ? [row] : [];
    }
    if (/^INSERT INTO/i.test(normalized)) {
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as MaterialKindPrefsRow;
      this.materialKindPrefs.set(built.user_id, built);
      return [];
    }
    if (/^UPDATE/i.test(normalized)) {
      const assignments = updatePlan(normalized);
      const cursor = { next: 0 };
      const userId = bindings[bindings.length - 1] as string;
      const current = this.materialKindPrefs.get(userId);
      if (!current) throw new Error(`fake D1: UPDATE em prefs ausente: ${userId}`);
      const next = { ...current } as Record<string, unknown>;
      for (const { column, value } of assignments) {
        next[column] = resolveToken(value, bindings, cursor, undefined);
      }
      this.materialKindPrefs.set(userId, next as unknown as MaterialKindPrefsRow);
      return [];
    }
    throw new Error(`fake D1: prefs não suportado: ${normalized}`);
  }
```

Confirme lendo `updatePlan`/`insertPlan`/`resolveToken` no próprio arquivo que as assinaturas batem (`resolveToken(token, bindings, cursor, current)`); ajuste o nome se divergir. Atualize o comentário-tabela do topo do arquivo com uma linha para `user_material_kind_prefs`.

- [ ] **Step 3: Testes do handler (falhando)**

`src/material_kind_prefs/handlers.test.ts`:

```ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import {
  getMaterialKindPrefs,
  putMaterialKindPrefs,
  type MaterialKindPrefsJson,
} from './handlers.ts';

const claims = { sub: 'u1', email: 'a@b.c' } as never;

function putRequest(body: Record<string, unknown>): Request {
  return new Request('https://example.test/api/material-kind-prefs', {
    method: 'PUT',
    body: JSON.stringify({
      kindIds: ['k1', 'k2'],
      updatedAt: '2026-09-02T10:00:00.000Z',
      ...body,
    }),
  });
}

test('GET sem linha devolve 204', async () => {
  const db = new FakeD1Database();
  const response = await getMaterialKindPrefs(fakeDb(db), claims);
  assert.equal(response.status, 204);
});

test('PUT cria com version 1 e GET devolve o documento', async () => {
  const db = new FakeD1Database();
  const created = (await (
    await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}))
  ).json()) as MaterialKindPrefsJson;
  assert.deepEqual(created, {
    kindIds: ['k1', 'k2'],
    updatedAt: '2026-09-02T10:00:00.000Z',
    version: 1,
  });

  const fetched = (await (
    await getMaterialKindPrefs(fakeDb(db), claims)
  ).json()) as MaterialKindPrefsJson;
  assert.deepEqual(fetched, created);
});

test('PUT mais novo sobrescreve e incrementa version', async () => {
  const db = new FakeD1Database();
  await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  const updated = (await (
    await putMaterialKindPrefs(
      fakeDb(db),
      claims,
      putRequest({ kindIds: ['k9'], updatedAt: '2026-09-03T10:00:00.000Z' }),
    )
  ).json()) as MaterialKindPrefsJson;
  assert.deepEqual(updated, {
    kindIds: ['k9'],
    updatedAt: '2026-09-03T10:00:00.000Z',
    version: 2,
  });
});

test('PUT mais velho devolve 409 com o documento remoto', async () => {
  const db = new FakeD1Database({
    materialKindPrefs: [
      {
        user_id: 'u1',
        kind_ids: '["remoto"]',
        updated_at: '2026-09-05T10:00:00.000Z',
        version: 3,
      },
    ],
  });
  const response = await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  assert.equal(response.status, 409);
  const remote = (await response.json()) as MaterialKindPrefsJson;
  assert.deepEqual(remote, {
    kindIds: ['remoto'],
    updatedAt: '2026-09-05T10:00:00.000Z',
    version: 3,
  });
  // Nada foi escrito.
  assert.equal(db.materialKindPrefs.get('u1')?.kind_ids, '["remoto"]');
});

test('PUT mesmo updatedAt (idempotente) grava e devolve version + 1', async () => {
  const db = new FakeD1Database();
  await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  const again = await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  assert.equal(again.status, 200);
  assert.equal(((await again.json()) as MaterialKindPrefsJson).version, 2);
});

test('PUT rejeita 6 ids, duplicata, não-array, id vazio e updatedAt inválido', async () => {
  const db = new FakeD1Database();
  const cases: Array<Record<string, unknown>> = [
    { kindIds: ['1', '2', '3', '4', '5', '6'] },
    { kindIds: ['a', 'a'] },
    { kindIds: 'k1' },
    { kindIds: ['ok', ''] },
    { updatedAt: 'ontem' },
  ];
  for (const body of cases) {
    const response = await putMaterialKindPrefs(fakeDb(db), claims, putRequest(body));
    assert.equal(response.status, 400, JSON.stringify(body));
  }
  assert.equal(db.materialKindPrefs.size, 0);
});

test('PUT com JSON inválido devolve 400', async () => {
  const db = new FakeD1Database();
  const request = new Request('https://example.test/api/material-kind-prefs', {
    method: 'PUT',
    body: '{nope',
  });
  const response = await putMaterialKindPrefs(fakeDb(db), claims, request);
  assert.equal(response.status, 400);
});

test('lista vazia é aceita — "sem favoritos" não é tombstone', async () => {
  const db = new FakeD1Database();
  const response = await putMaterialKindPrefs(
    fakeDb(db),
    claims,
    putRequest({ kindIds: [] }),
  );
  assert.equal(response.status, 200);
  assert.deepEqual(((await response.json()) as MaterialKindPrefsJson).kindIds, []);
});
```

Se o construtor do `FakeD1Database` for `(rows: PlaylistRow[] = [], options = {})`, use `new FakeD1Database([], { materialKindPrefs: [...] })` no teste do 409.

- [ ] **Step 4: Rodar e ver falhar**

Run: `cd workers/plpcg-catalog && npm test 2>&1 | tail -15`
Expected: falha de import (`./handlers.ts` não existe).

- [ ] **Step 5: Handler**

`src/material_kind_prefs/handlers.ts`:

```ts
import type { GoogleClaims } from '../auth/verify_google_token';
import { json } from '../playlists/wire.ts';

/** Teto da lista — o mesmo `kMaxFavoriteMaterialKinds` do app. */
export const MAX_KIND_IDS = 5;
const MAX_KIND_ID_LENGTH = 128;

interface MaterialKindPrefsRow {
  user_id: string;
  kind_ids: string;
  updated_at: string;
  version: number;
}

export interface MaterialKindPrefsJson {
  /** Ordem = preferência (índice 0 é o favorito nº 1). */
  kindIds: string[];
  updatedAt: string;
  version: number;
}

const SELECT_SQL = `SELECT user_id, kind_ids, updated_at, version
       FROM user_material_kind_prefs WHERE user_id = ?`;

function rowToJson(row: MaterialKindPrefsRow): MaterialKindPrefsJson {
  let kindIds: string[] = [];
  try {
    const parsed = JSON.parse(row.kind_ids) as unknown;
    if (Array.isArray(parsed)) {
      kindIds = parsed.filter((v): v is string => typeof v === 'string');
    }
  } catch {
    // Linha corrompida não derruba o GET: devolve vazio e o próximo PUT conserta.
  }
  return { kindIds, updatedAt: row.updated_at, version: row.version };
}

function isIsoDate(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.length > 0 &&
    !Number.isNaN(Date.parse(value))
  );
}

interface PutBody {
  kindIds?: unknown;
  updatedAt?: unknown;
}

/** Mensagem de erro, ou `null` quando o corpo é válido. */
function validatePutBody(body: PutBody): string | null {
  if (!Array.isArray(body.kindIds)) return 'kindIds must be an array';
  if (body.kindIds.length > MAX_KIND_IDS) {
    return `kindIds must have at most ${MAX_KIND_IDS} items`;
  }
  const seen = new Set<string>();
  for (const id of body.kindIds) {
    if (typeof id !== 'string' || id.trim().length === 0) {
      return 'kindIds must be non-empty strings';
    }
    if (id.length > MAX_KIND_ID_LENGTH) return 'kindId too long';
    if (seen.has(id)) return 'kindIds must be unique';
    seen.add(id);
  }
  if (!isIsoDate(body.updatedAt)) return 'updatedAt required';
  return null;
}

export async function getMaterialKindPrefs(
  db: D1Database,
  claims: GoogleClaims,
): Promise<Response> {
  const row = await db.prepare(SELECT_SQL).bind(claims.sub).first<MaterialKindPrefsRow>();
  if (!row) return new Response(null, { status: 204 });
  return json(rowToJson(row));
}

/**
 * Upsert do documento inteiro, last-write-wins por `updatedAt`.
 *
 * `409` devolve a linha remota quando ela é mais nova que o `updatedAt`
 * enviado — o cliente adota a remota. Mesmo `updatedAt` grava (o cliente
 * repete o PUT depois de uma falha de rede sem saber se chegou).
 */
export async function putMaterialKindPrefs(
  db: D1Database,
  claims: GoogleClaims,
  request: Request,
): Promise<Response> {
  let body: PutBody;
  try {
    body = (await request.json()) as PutBody;
  } catch {
    return json({ error: 'invalid json' }, 400);
  }
  const validationError = validatePutBody(body);
  if (validationError) return json({ error: validationError }, 400);

  const kindIds = body.kindIds as string[];
  const updatedAt = body.updatedAt as string;
  const serialized = JSON.stringify(kindIds);

  const existing = await db
    .prepare(SELECT_SQL)
    .bind(claims.sub)
    .first<MaterialKindPrefsRow>();

  if (!existing) {
    await db
      .prepare(
        `INSERT INTO user_material_kind_prefs (user_id, kind_ids, updated_at, version)
         VALUES (?, ?, ?, 1)`,
      )
      .bind(claims.sub, serialized, updatedAt)
      .run();
    return json({ kindIds, updatedAt, version: 1 } satisfies MaterialKindPrefsJson);
  }

  if (updatedAt < existing.updated_at) {
    return json(rowToJson(existing), 409);
  }

  const version = existing.version + 1;
  await db
    .prepare(
      `UPDATE user_material_kind_prefs SET kind_ids = ?, updated_at = ?, version = ?
       WHERE user_id = ?`,
    )
    .bind(serialized, updatedAt, version, claims.sub)
    .run();
  return json({ kindIds, updatedAt, version } satisfies MaterialKindPrefsJson);
}
```

- [ ] **Step 6: Rodar os testes**

Run: `cd workers/plpcg-catalog && npm test 2>&1 | tail -15`
Expected: todos passando (96 anteriores + 8 novos). Se o fake reclamar de token não reconhecido no `INSERT ... VALUES (?, ?, ?, 1)`, o `resolveToken` já trata número literal (`Number(token)`); se reclamar do `UPDATE`, confira que `updatePlan` lê `kind_ids = ?, updated_at = ?, version = ?` e que o WHERE final consome o último binding.

- [ ] **Step 7: Despacho em `index.ts`**

1. Import no topo:

```ts
import {
  getMaterialKindPrefs,
  putMaterialKindPrefs,
} from './material_kind_prefs/handlers';
```

2. Em `corsModeForPath`, logo abaixo da linha de `/api/audio-flags`:

```ts
  if (pathname.startsWith('/api/material-kind-prefs')) return 'playlists';
```

3. Função ao lado de `handleAudioFlags`:

```ts
async function handleMaterialKindPrefs(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (pathname !== '/api/material-kind-prefs') {
    return jsonResponse({ error: 'not found' }, { status: 404 });
  }
  if (request.method === 'GET') {
    return withAuth(request, env, (_req, e, claims) =>
      getMaterialKindPrefs(e.DB, claims),
    );
  }
  if (request.method === 'PUT') {
    return withAuth(request, env, (req, e, claims) =>
      putMaterialKindPrefs(e.DB, claims, req),
    );
  }
  return jsonResponse({ error: 'method not allowed' }, { status: 405 });
}
```

4. No `fetch`, logo após o bloco de `/api/audio-flags`:

```ts
    if (url.pathname.startsWith('/api/material-kind-prefs')) {
      return withCors(
        await handleMaterialKindPrefs(request, env, url.pathname),
        request,
        'playlists',
      );
    }
```

- [ ] **Step 8: README + checagem**

Na tabela de endpoints do `README.md`, após as linhas de `audio-flags`:

```
| `GET` | `/api/material-kind-prefs` | Bearer | Material kinds favoritos do usuário (`204` se nunca salvou) |
| `PUT` | `/api/material-kind-prefs` | Bearer | Upsert do documento (`{ kindIds ≤ 5, updatedAt }`; `409` devolve o remoto mais novo) |
```

Run: `cd workers/plpcg-catalog && npm test 2>&1 | tail -6 && npx tsc --noEmit -p tsconfig.json 2>&1 | tail -5`
Expected: testes verdes; `tsc` sem erros (se o projeto não tiver `tsc` configurado assim, use `npm run check`).

- [ ] **Step 9: Commit**

```bash
git add workers/plpcg-catalog/migrations/0010_create_user_material_kind_prefs.sql workers/plpcg-catalog/src/material_kind_prefs workers/plpcg-catalog/src/test/fake_d1.ts workers/plpcg-catalog/src/index.ts workers/plpcg-catalog/README.md
git commit -m "feat(worker): material kinds favoritos por usuário — GET/PUT /api/material-kind-prefs"
```

---

### Task 2: `materialKindId` nas entidades Coldigom

**Files:**
- Modify: `lib/features/coldigom/data/models/praise_dto.dart` (classe `MaterialDto`, linhas 1–33)
- Modify: `lib/features/catalog/domain/entities/louvor.dart`
- Modify: `lib/features/audio_player/domain/entities/audio_track.dart`
- Modify: `lib/features/chords/domain/entities/chord_material.dart`
- Modify: `lib/features/gestures/domain/entities/gesture_material.dart`
- Modify: `lib/features/catalog/domain/entities/youtube_material.dart`
- Modify: `lib/features/catalog/domain/entities/catalog_material.dart`
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`
- Test: `test/unit/features/coldigom/praise_dto_test.dart`, `test/unit/features/coldigom/coldigom_louvor_adapter_test.dart`

**Interfaces:**
- Produces: `String? materialKindId` em `Louvor`, `AudioTrack`, `ChordMaterial`, `GestureMaterial`, `YoutubeMaterial` (parâmetro nomeado opcional, default `null`; `Louvor.fromManifest({... String? materialKindId})`), `String? get materialKindId` em `CatalogMaterial`, `MaterialDto.materialKindId`.

- [ ] **Step 1: Testes (falhando)**

Em `test/unit/features/coldigom/praise_dto_test.dart`, adicionar no grupo de `MaterialDto` (crie o grupo se não existir):

```dart
    test('lê material_kind como materialKindId e tolera ausência', () {
      final withKind = MaterialDto.fromJson({
        'id': 'm1',
        'type': 'pdf',
        'material_kind': 'kind-uuid',
        'material_kind_name': 'Partitura',
      });
      expect(withKind.materialKindId, 'kind-uuid');

      final without = MaterialDto.fromJson({'id': 'm2', 'type': 'pdf'});
      expect(without.materialKindId, isNull);
    });
```

Em `coldigom_louvor_adapter_test.dart`, novo teste no grupo `ColdigomLouvorAdapter`:

```dart
    test('propaga materialKindId para as cinco famílias', () {
      const praise = PraiseDetailDto(
        id: 'praise-1',
        name: 'Grande Deus',
        number: '001',
        rhythm: 'Coletânea',
        materials: [
          MaterialDto(id: 'p', type: 'pdf', r2Key: 'a/p.pdf', materialKindId: 'k-pdf'),
          MaterialDto(id: 'a', type: 'mp3', r2Key: 'a/a.mp3', materialKindId: 'k-audio'),
          MaterialDto(id: 'c', type: 'chord', r2Key: 'a/c.chord', materialKindId: 'k-chord'),
          MaterialDto(id: 'g', type: 'gestures', r2Key: 'a/g.gestures', materialKindId: 'k-gesture'),
          MaterialDto(
            id: 'y',
            type: 'youtube',
            url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
            materialKindId: 'k-yt',
          ),
        ],
      );

      expect(ColdigomLouvorAdapter.toLouvores(praise).single.materialKindId, 'k-pdf');
      expect(ColdigomLouvorAdapter.toAudioTracks(praise).single.materialKindId, 'k-audio');
      expect(ColdigomLouvorAdapter.toChordMaterials(praise).single.materialKindId, 'k-chord');
      expect(ColdigomLouvorAdapter.toGestureMaterials(praise).single.materialKindId, 'k-gesture');
      expect(ColdigomLouvorAdapter.toYoutubeMaterials(praise).single.materialKindId, 'k-yt');
    });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/coldigom/praise_dto_test.dart test/unit/features/coldigom/coldigom_louvor_adapter_test.dart 2>&1 | tail -5`
Expected: erro de compilação (`materialKindId` não existe).

- [ ] **Step 3: DTO**

Em `MaterialDto`: adicionar `this.materialKindId,` ao construtor, campo

```dart
  /// Id do `material_kind` Coldigom (UUID) — chave dos favoritos do usuário.
  /// Null no placeholder de letra e em respostas antigas.
  final String? materialKindId;
```

e em `fromJson`: `materialKindId: json['material_kind'] is String ? json['material_kind'] as String : null,`.

- [ ] **Step 4: Entidades**

Em cada uma das cinco entidades, adicionar ao construtor `this.materialKindId,` (nomeado, opcional) e o campo:

```dart
  /// Id do `material_kind` Coldigom; `null` no acervo PLPCG.
  final String? materialKindId;
```

Detalhes:
- `Louvor`: campo `final String? materialKindId;` no construtor `const Louvor({..., this.source = ..., this.materialKindId})`; `Louvor.fromManifest` ganha `String? materialKindId` e repassa. **Não** tocar em `LouvorCache`.
- `AudioTrack`: também em `copyWith` (`materialKindId: materialKindId,`).
- `ChordMaterial`, `GestureMaterial`, `YoutubeMaterial`: só construtor + campo.

Em `CatalogMaterial` (sealed): adicionar

```dart
  /// Id do `material_kind` Coldigom; `null` quando o acervo não o conhece.
  String? get materialKindId;
```

e em cada invólucro: `PdfMaterial` → `louvor.materialKindId`; `ChordMaterialRef` → `chord.materialKindId`; `GestureMaterialRef` → `gesture.materialKindId`; `AudioMaterial` → `track.materialKindId`; `YoutubeMaterialRef` → `material.materialKindId`.

- [ ] **Step 5: Adapter**

Em `ColdigomLouvorAdapter`, nas cinco construções, acrescentar `materialKindId: material.materialKindId,`.

- [ ] **Step 6: Rodar testes + analyze**

Run: `flutter test test/unit/features/coldigom test/unit/features/catalog 2>&1 | tail -3 && flutter analyze lib/features/coldigom lib/features/catalog lib/features/audio_player lib/features/chords lib/features/gestures 2>&1 | tail -3`
Expected: passa; analyze sem issues. Procure outros lugares que constroem essas entidades com listas posicionais (`grep -rn "AudioTrack(" lib test | head`) — como o parâmetro é nomeado e opcional, nada quebra.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/coldigom lib/features/catalog/domain lib/features/audio_player/domain lib/features/chords/domain lib/features/gestures/domain test/unit/features/coldigom
git add -A lib/features/coldigom lib/features/catalog/domain/entities lib/features/audio_player/domain/entities lib/features/chords/domain/entities lib/features/gestures/domain/entities test/unit/features/coldigom
git commit -m "feat(coldigom): materialKindId nas entidades e no CatalogMaterial"
```

---

### Task 3: Domínio — `MaterialKindPrefs` e `orderByFavoriteKinds`

**Files:**
- Create: `lib/features/material_kind_prefs/domain/entities/material_kind_prefs.dart`
- Create: `lib/features/material_kind_prefs/domain/repositories/material_kind_prefs_repository.dart`
- Create: `lib/features/material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart`
- Test: `test/unit/features/material_kind_prefs/material_kind_prefs_test.dart`, `test/unit/features/material_kind_prefs/order_by_favorite_kinds_test.dart`

**Interfaces:**
- Produces:
  - `const int kMaxFavoriteMaterialKinds = 5;`
  - `class MaterialKindPrefs { final List<String> kindIds; final DateTime updatedAt; final bool pendingPush; static const empty; factory validated({required List<String> kindIds, required DateTime updatedAt, bool pendingPush}); MaterialKindPrefs copyWith({List<String>? kindIds, DateTime? updatedAt, bool? pendingPush}); Map<String, Object?> toJson(); static MaterialKindPrefs? fromJson(Map<String, Object?>? json); Map<String, int> get rank; }`
  - `abstract class MaterialKindPrefsRepository { Future<MaterialKindPrefs?> read(String sub); Future<void> write(String sub, MaterialKindPrefs prefs); }`
  - `List<T> orderByFavoriteKinds<T>(List<T> items, Map<String, int> rank, {required String? Function(T) kindIdOf})`

- [ ] **Step 1: Testes (falhando)**

`test/unit/features/material_kind_prefs/material_kind_prefs_test.dart`:

```dart
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 12, 10);

  test('validated aceita até 5 ids únicos e preserva a ordem', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['a', 'b', 'c', 'd', 'e'],
      updatedAt: at,
    );
    expect(prefs.kindIds, ['a', 'b', 'c', 'd', 'e']);
    expect(prefs.rank, {'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4});
    expect(prefs.pendingPush, isFalse);
  });

  test('validated rejeita 6 ids, duplicata e id vazio', () {
    expect(
      () => MaterialKindPrefs.validated(
        kindIds: const ['1', '2', '3', '4', '5', '6'],
        updatedAt: at,
      ),
      throwsArgumentError,
    );
    expect(
      () => MaterialKindPrefs.validated(kindIds: const ['a', 'a'], updatedAt: at),
      throwsArgumentError,
    );
    expect(
      () => MaterialKindPrefs.validated(kindIds: const ['a', ''], updatedAt: at),
      throwsArgumentError,
    );
  });

  test('round-trip JSON com pendingPush e updatedAt em UTC', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['x'],
      updatedAt: at,
      pendingPush: true,
    );
    final restored = MaterialKindPrefs.fromJson(prefs.toJson());
    expect(restored, isNotNull);
    expect(restored!.kindIds, ['x']);
    expect(restored.updatedAt, at);
    expect(restored.pendingPush, isTrue);
  });

  test('fromJson tolera lixo: null, sem kindIds, data inválida', () {
    expect(MaterialKindPrefs.fromJson(null), isNull);
    expect(MaterialKindPrefs.fromJson({'updatedAt': '2026-01-01T00:00:00Z'}), isNull);
    expect(MaterialKindPrefs.fromJson({'kindIds': ['a'], 'updatedAt': 'ontem'}), isNull);
    // Mais de 5 ids ou duplicatas gravados por outra versão: corta em vez de
    // recusar o documento inteiro.
    final over = MaterialKindPrefs.fromJson({
      'kindIds': ['1', '2', '2', '3', '4', '5', '6'],
      'updatedAt': '2026-01-01T00:00:00.000Z',
    });
    expect(over!.kindIds, ['1', '2', '3', '4', '5']);
  });

  test('empty não tem ids, rank vazio e updatedAt na época', () {
    expect(MaterialKindPrefs.empty.kindIds, isEmpty);
    expect(MaterialKindPrefs.empty.rank, isEmpty);
    expect(MaterialKindPrefs.empty.updatedAt.millisecondsSinceEpoch, 0);
  });
}
```

`test/unit/features/material_kind_prefs/order_by_favorite_kinds_test.dart`:

```dart
import 'package:coldigui/features/material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Item = ({String id, String? kind});

_Item _i(String id, [String? kind]) => (id: id, kind: kind);

void main() {
  final items = <_Item>[
    _i('1', 'coro'),
    _i('2'),
    _i('3', 'soprano'),
    _i('4', 'coro'),
    _i('5', 'tenor'),
  ];

  test('rank vazio devolve a própria lista, na mesma ordem', () {
    final out = orderByFavoriteKinds(items, const {}, kindIdOf: (i) => i.kind);
    expect(identical(out, items), isTrue);
  });

  test('favoritos sobem na ordem do rank; o resto mantém a ordem original', () {
    final out = orderByFavoriteKinds(
      items,
      const {'soprano': 0, 'coro': 1},
      kindIdOf: (i) => i.kind,
    );
    expect(out.map((i) => i.id), ['3', '1', '4', '2', '5']);
  });

  test('é estável entre itens do mesmo kind favorito', () {
    final out = orderByFavoriteKinds(
      [_i('b', 'x'), _i('a', 'x'), _i('c', 'y')],
      const {'x': 0},
      kindIdOf: (i) => i.kind,
    );
    expect(out.map((i) => i.id), ['b', 'a', 'c']);
  });

  test('kind null nunca sobe', () {
    final out = orderByFavoriteKinds(
      [_i('n'), _i('f', 'fav')],
      const {'fav': 0},
      kindIdOf: (i) => i.kind,
    );
    expect(out.map((i) => i.id), ['f', 'n']);
  });

  test('não muta a lista de entrada', () {
    final input = [_i('a', 'z'), _i('b', 'fav')];
    orderByFavoriteKinds(input, const {'fav': 0}, kindIdOf: (i) => i.kind);
    expect(input.map((i) => i.id), ['a', 'b']);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/material_kind_prefs 2>&1 | tail -5`
Expected: erro de import.

- [ ] **Step 3: Entidade**

`lib/features/material_kind_prefs/domain/entities/material_kind_prefs.dart`:

```dart
/// Teto da lista de favoritos — o Worker aplica o mesmo número.
const int kMaxFavoriteMaterialKinds = 5;

/// Preferência de material kinds Coldigom de uma conta: lista ordenada de
/// até [kMaxFavoriteMaterialKinds] ids, o instante da última edição e se ela
/// ainda não subiu para o Worker.
///
/// É um documento inteiro, não N linhas: reordenar cinco itens é uma edição,
/// e o conflito entre aparelhos resolve por `updatedAt` (last-write-wins).
class MaterialKindPrefs {
  const MaterialKindPrefs._({
    required this.kindIds,
    required this.updatedAt,
    required this.pendingPush,
  });

  /// Ids de `material_kinds`; índice 0 é o favorito nº 1.
  final List<String> kindIds;

  /// Última edição (UTC). Vai no PUT e decide quem ganha no sync.
  final DateTime updatedAt;

  /// `true` entre o `save` local e o PUT bem-sucedido.
  final bool pendingPush;

  /// Sem favoritos — o estado de quem nunca escolheu ou está deslogado.
  ///
  /// `final`, não `const`: `DateTime` não tem construtor const.
  static final MaterialKindPrefs empty = MaterialKindPrefs._(
    kindIds: const <String>[],
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    pendingPush: false,
  );

  /// Constrói validando o invariante; lança [ArgumentError] fora dele.
  factory MaterialKindPrefs.validated({
    required List<String> kindIds,
    required DateTime updatedAt,
    bool pendingPush = false,
  }) {
    if (kindIds.length > kMaxFavoriteMaterialKinds) {
      throw ArgumentError.value(kindIds, 'kindIds', 'máximo $kMaxFavoriteMaterialKinds');
    }
    if (kindIds.any((id) => id.isEmpty)) {
      throw ArgumentError.value(kindIds, 'kindIds', 'id vazio');
    }
    if (kindIds.toSet().length != kindIds.length) {
      throw ArgumentError.value(kindIds, 'kindIds', 'duplicata');
    }
    return MaterialKindPrefs._(
      kindIds: List.unmodifiable(kindIds),
      updatedAt: updatedAt.toUtc(),
      pendingPush: pendingPush,
    );
  }

  /// `kindId → posição` para o sheet ordenar.
  Map<String, int> get rank => {
    for (var i = 0; i < kindIds.length; i++) kindIds[i]: i,
  };

  MaterialKindPrefs copyWith({
    List<String>? kindIds,
    DateTime? updatedAt,
    bool? pendingPush,
  }) {
    return MaterialKindPrefs.validated(
      kindIds: kindIds ?? this.kindIds,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingPush: pendingPush ?? this.pendingPush,
    );
  }

  Map<String, Object?> toJson() => {
    'kindIds': kindIds,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'pendingPush': pendingPush,
  };

  /// Leitura tolerante: `null` quando faltam campos obrigatórios ou a data é
  /// ilegível; ids repetidos ou além do teto são cortados (outra versão do
  /// app pode ter gravado mais) em vez de perder o documento.
  static MaterialKindPrefs? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final rawIds = json['kindIds'];
    final rawUpdated = json['updatedAt'];
    if (rawIds is! List || rawUpdated is! String) return null;
    final updatedAt = DateTime.tryParse(rawUpdated);
    if (updatedAt == null) return null;
    final ids = <String>[];
    for (final id in rawIds) {
      if (id is! String || id.isEmpty || ids.contains(id)) continue;
      ids.add(id);
      if (ids.length == kMaxFavoriteMaterialKinds) break;
    }
    return MaterialKindPrefs._(
      kindIds: List.unmodifiable(ids),
      updatedAt: updatedAt.toUtc(),
      pendingPush: json['pendingPush'] == true,
    );
  }
}
```

- [ ] **Step 4: Repositório**

`lib/features/material_kind_prefs/domain/repositories/material_kind_prefs_repository.dart`:

```dart
import '../entities/material_kind_prefs.dart';

/// Persistência local do documento de favoritos, por conta (`sub` Google).
abstract class MaterialKindPrefsRepository {
  /// `null` quando a conta nunca salvou neste aparelho.
  Future<MaterialKindPrefs?> read(String sub);

  Future<void> write(String sub, MaterialKindPrefs prefs);
}
```

- [ ] **Step 5: Ordenação**

`lib/features/material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart`:

```dart
/// Sobe os itens cujo kind é favorito, na ordem do [rank]; os demais mantêm
/// a ordem de entrada. Sort **estável** — dois itens do mesmo kind favorito
/// continuam na ordem em que vieram.
///
/// Genérica por seletor porque o sheet ordena tanto `CatalogMaterial` quanto
/// as `LouvorMaterialEntry` da aba PDF. [rank] vazio devolve a própria lista:
/// deslogado e acervo PLPCG não pagam nada.
List<T> orderByFavoriteKinds<T>(
  List<T> items,
  Map<String, int> rank, {
  required String? Function(T item) kindIdOf,
}) {
  if (rank.isEmpty || items.length < 2) return items;
  final favorites = <(int, T)>[];
  final others = <T>[];
  for (final item in items) {
    final kind = kindIdOf(item);
    final position = kind == null ? null : rank[kind];
    if (position == null) {
      others.add(item);
    } else {
      favorites.add((position, item));
    }
  }
  if (favorites.isEmpty) return items;
  // `List.sort` não é estável; o índice de entrada desempata.
  final indexed = [for (var i = 0; i < favorites.length; i++) (favorites[i].$1, i, favorites[i].$2)];
  indexed.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final entry in indexed) entry.$3, ...others];
}
```

- [ ] **Step 6: Rodar testes**

Run: `flutter test test/unit/features/material_kind_prefs 2>&1 | tail -3`
Expected: todos passando.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/material_kind_prefs test/unit/features/material_kind_prefs
git add lib/features/material_kind_prefs test/unit/features/material_kind_prefs
git commit -m "feat(prefs): entidade MaterialKindPrefs e orderByFavoriteKinds"
```

---

### Task 4: Dados — datasources local (SharedPreferences) e remoto (Dio)

**Files:**
- Create: `lib/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart`
- Create: `lib/features/material_kind_prefs/data/repositories/material_kind_prefs_repository_impl.dart`
- Create: `lib/features/material_kind_prefs/data/datasources/material_kind_prefs_remote_datasource.dart`
- Modify: `lib/core/constants/api_endpoints.dart` (após `audioFlag`)
- Test: `test/unit/features/material_kind_prefs/material_kind_prefs_local_datasource_test.dart`, `test/unit/features/material_kind_prefs/material_kind_prefs_remote_datasource_test.dart`

**Interfaces:**
- Consumes: `MaterialKindPrefs`, `MaterialKindPrefsRepository` (Task 3); contrato HTTP (Task 1).
- Produces:
  - `class MaterialKindPrefsLocalDatasource { MaterialKindPrefsLocalDatasource(SharedPreferences prefs); static String keyFor(String sub); MaterialKindPrefs? read(String sub); Future<void> write(String sub, MaterialKindPrefs prefs); }`
  - `class MaterialKindPrefsRepositoryImpl implements MaterialKindPrefsRepository { MaterialKindPrefsRepositoryImpl(MaterialKindPrefsLocalDatasource local); }`
  - `class MaterialKindPrefsRemoteDatasource { MaterialKindPrefsRemoteDatasource(Dio dio); Future<MaterialKindPrefs?> fetch(String idToken); Future<MaterialKindPrefs> put({required String idToken, required MaterialKindPrefs prefs}); }`
  - `class MaterialKindPrefsConflict implements Exception { final MaterialKindPrefs remote; }`
  - `ApiEndpoints.materialKindPrefs = '/api/material-kind-prefs'`

- [ ] **Step 1: Testes (falhando)**

`material_kind_prefs_local_datasource_test.dart`:

```dart
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final at = DateTime.utc(2026, 9, 12);

  test('write/read por sub — outra conta não enxerga', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = MaterialKindPrefsLocalDatasource(prefs);

    await local.write(
      'sub-1',
      MaterialKindPrefs.validated(kindIds: const ['a'], updatedAt: at, pendingPush: true),
    );

    final mine = local.read('sub-1');
    expect(mine!.kindIds, ['a']);
    expect(mine.pendingPush, isTrue);
    expect(mine.updatedAt, at);
    expect(local.read('sub-2'), isNull);
    expect(prefs.getString(MaterialKindPrefsLocalDatasource.keyFor('sub-1')), isNotNull);
  });

  test('JSON corrompido lê como null', () async {
    SharedPreferences.setMockInitialValues({
      MaterialKindPrefsLocalDatasource.keyFor('sub-1'): '{nope',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(MaterialKindPrefsLocalDatasource(prefs).read('sub-1'), isNull);
  });
}
```

`material_kind_prefs_remote_datasource_test.dart` (mesmo `_FixedAdapter` de `test/unit/features/audio_flags/audio_flag_remote_datasource_test.dart` — copie a classe, ela é privada lá):

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/core/constants/api_endpoints.dart';
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_remote_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(MaterialKindPrefsRemoteDatasource, _FixedAdapter) _make(int status, Object? body) {
  final adapter = _FixedAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return (MaterialKindPrefsRemoteDatasource(dio), adapter);
}

void main() {
  const doc = {
    'kindIds': ['a', 'b'],
    'updatedAt': '2026-09-12T10:00:00.000Z',
    'version': 2,
  };

  test('fetch 200 devolve o documento com pendingPush false e Bearer', () async {
    final (remote, adapter) = _make(200, doc);
    final prefs = await remote.fetch('tok');
    expect(prefs!.kindIds, ['a', 'b']);
    expect(prefs.pendingPush, isFalse);
    expect(prefs.updatedAt, DateTime.utc(2026, 9, 12, 10));
    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer tok');
    expect(adapter.lastRequest!.path, ApiEndpoints.materialKindPrefs);
  });

  test('fetch 204 devolve null', () async {
    final (remote, _) = _make(204, null);
    expect(await remote.fetch('tok'), isNull);
  });

  test('put envia kindIds + updatedAt e devolve o documento gravado', () async {
    final (remote, adapter) = _make(200, doc);
    final result = await remote.put(
      idToken: 'tok',
      prefs: MaterialKindPrefs.validated(
        kindIds: const ['a', 'b'],
        updatedAt: DateTime.utc(2026, 9, 12, 10),
        pendingPush: true,
      ),
    );
    expect(result.kindIds, ['a', 'b']);
    expect(result.pendingPush, isFalse);
    final sent = adapter.lastRequest!.data as Map;
    expect(sent.keys.toSet(), {'kindIds', 'updatedAt'});
    expect(sent['updatedAt'], '2026-09-12T10:00:00.000Z');
    expect(adapter.lastRequest!.method, 'PUT');
  });

  test('put 409 vira MaterialKindPrefsConflict com o remoto', () async {
    final (remote, _) = _make(409, doc);
    await expectLater(
      remote.put(idToken: 'tok', prefs: MaterialKindPrefs.empty),
      throwsA(
        isA<MaterialKindPrefsConflict>().having((c) => c.remote.kindIds, 'remote', ['a', 'b']),
      ),
    );
  });

  test('401 vira AuthUnauthorizedException', () async {
    final (remote, _) = _make(401, {'error': 'unauthorized'});
    await expectLater(remote.fetch('tok'), throwsA(isA<AuthUnauthorizedException>()));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/material_kind_prefs 2>&1 | tail -5`
Expected: erro de import.

- [ ] **Step 3: Endpoint**

Em `ApiEndpoints`, após `audioFlag`:

```dart
  /// Material kinds favoritos do usuário — Worker + D1
  /// `user_material_kind_prefs`. `GET` (`204` se nunca salvou) e `PUT`
  /// (`409` devolve o documento remoto mais novo).
  static const String materialKindPrefs = '/api/material-kind-prefs';
```

- [ ] **Step 4: Local datasource + repositório**

`material_kind_prefs_local_datasource.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/material_kind_prefs.dart';

/// Documento de favoritos em SharedPreferences, uma chave por conta.
///
/// Não é Isar de propósito: são cinco ids por conta, e a coleção Isar
/// custaria codegen e mais um caminho de `StorageUnavailableException`.
class MaterialKindPrefsLocalDatasource {
  MaterialKindPrefsLocalDatasource(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'material_kind_prefs.';

  static String keyFor(String sub) => '$_keyPrefix$sub';

  MaterialKindPrefs? read(String sub) {
    final raw = _prefs.getString(keyFor(sub));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MaterialKindPrefs.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException catch (e) {
      debugPrint('[material-kind-prefs] JSON local ilegível: $e');
      return null;
    }
  }

  Future<void> write(String sub, MaterialKindPrefs prefs) async {
    await _prefs.setString(keyFor(sub), jsonEncode(prefs.toJson()));
  }
}
```

`material_kind_prefs_repository_impl.dart`:

```dart
import '../../domain/entities/material_kind_prefs.dart';
import '../../domain/repositories/material_kind_prefs_repository.dart';
import '../datasources/material_kind_prefs_local_datasource.dart';

class MaterialKindPrefsRepositoryImpl implements MaterialKindPrefsRepository {
  MaterialKindPrefsRepositoryImpl(this._local);

  final MaterialKindPrefsLocalDatasource _local;

  @override
  Future<MaterialKindPrefs?> read(String sub) async => _local.read(sub);

  @override
  Future<void> write(String sub, MaterialKindPrefs prefs) => _local.write(sub, prefs);
}
```

- [ ] **Step 5: Remote datasource**

`material_kind_prefs_remote_datasource.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../auth/data/auth_remote_datasource.dart';
import '../../domain/entities/material_kind_prefs.dart';

/// `409` do PUT: o Worker tem um documento mais novo — o chamador o adota.
class MaterialKindPrefsConflict implements Exception {
  MaterialKindPrefsConflict(this.remote);

  final MaterialKindPrefs remote;

  @override
  String toString() => 'MaterialKindPrefsConflict(${remote.updatedAt})';
}

/// `GET`/`PUT /api/material-kind-prefs` com Bearer do `id_token`.
class MaterialKindPrefsRemoteDatasource {
  MaterialKindPrefsRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String idToken) => Options(
    headers: {'Authorization': 'Bearer $idToken'},
    // 401/403/409 são respostas do contrato, não falhas de transporte.
    validateStatus: (status) => status != null && status < 500,
  );

  /// `null` quando a conta nunca salvou (`204`).
  Future<MaterialKindPrefs?> fetch(String idToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.materialKindPrefs,
      options: _auth(idToken),
    );
    _throwIfUnauthorized(response.statusCode);
    if (response.statusCode == 204 || response.data == null) return null;
    if (response.statusCode != 200) {
      throw StateError('material_kind_prefs_fetch_${response.statusCode}');
    }
    return _parse(response.data!);
  }

  Future<MaterialKindPrefs> put({
    required String idToken,
    required MaterialKindPrefs prefs,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.materialKindPrefs,
      data: {
        'kindIds': prefs.kindIds,
        'updatedAt': prefs.updatedAt.toUtc().toIso8601String(),
      },
      options: _auth(idToken),
    );
    _throwIfUnauthorized(response.statusCode);
    final data = response.data;
    if (response.statusCode == 409 && data != null) {
      throw MaterialKindPrefsConflict(_parse(data));
    }
    if (response.statusCode != 200 || data == null) {
      throw StateError('material_kind_prefs_put_${response.statusCode}');
    }
    return _parse(data);
  }

  void _throwIfUnauthorized(int? status) {
    if (status == 401 || status == 403) throw AuthUnauthorizedException(status!);
  }

  /// O documento do Worker nunca tem `pendingPush`: o que veio da nuvem já
  /// está lá.
  MaterialKindPrefs _parse(Map<String, dynamic> data) {
    final parsed = MaterialKindPrefs.fromJson({
      'kindIds': data['kindIds'],
      'updatedAt': data['updatedAt'],
      'pendingPush': false,
    });
    if (parsed == null) {
      debugPrint('[material-kind-prefs] documento remoto ilegível: $data');
      throw const FormatException('material_kind_prefs_invalid');
    }
    return parsed;
  }
}
```

- [ ] **Step 6: Rodar testes**

Run: `flutter test test/unit/features/material_kind_prefs 2>&1 | tail -3`
Expected: passando.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/material_kind_prefs lib/core/constants/api_endpoints.dart test/unit/features/material_kind_prefs
git add lib/features/material_kind_prefs lib/core/constants/api_endpoints.dart test/unit/features/material_kind_prefs
git commit -m "feat(prefs): datasources local (SharedPreferences) e remoto (/api/material-kind-prefs)"
```

---

### Task 5: Usecase `SyncMaterialKindPrefs`

**Files:**
- Create: `lib/features/material_kind_prefs/domain/usecases/sync_material_kind_prefs.dart`
- Test: `test/unit/features/material_kind_prefs/sync_material_kind_prefs_test.dart`

**Interfaces:**
- Consumes: `MaterialKindPrefsRepository` (Task 3), `MaterialKindPrefsRemoteDatasource` + `MaterialKindPrefsConflict` (Task 4).
- Produces:
  - `enum MaterialKindPrefsSyncOutcome { pulled, pushed, conflictAdopted, noop, skipped }`
  - `class MaterialKindPrefsSyncResult { final MaterialKindPrefsSyncOutcome outcome; final Object? pullError; final Object? pushError; Object? get error; bool get changedLocal; static const skippedAuth; }`
  - `class SyncMaterialKindPrefs { SyncMaterialKindPrefs(MaterialKindPrefsRepository repository, MaterialKindPrefsRemoteDatasource remote); Future<MaterialKindPrefsSyncResult> call({required String? idToken, required String sub}); }`

O usecase depende da classe concreta `MaterialKindPrefsRemoteDatasource` (como `SyncAudioFlags` recebe funções). Para testar sem rede, o teste passa um `Dio` com adapter programável — **ou**, mais simples, o usecase recebe duas funções: `Future<MaterialKindPrefs?> Function(String idToken) fetch` e `Future<MaterialKindPrefs> Function({required String idToken, required MaterialKindPrefs prefs}) put`. **Use as duas funções** (é o padrão de `SyncAudioFlags`).

- [ ] **Step 1: Testes (falhando)**

```dart
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_remote_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/domain/repositories/material_kind_prefs_repository.dart';
import 'package:coldigui/features/material_kind_prefs/domain/usecases/sync_material_kind_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository implements MaterialKindPrefsRepository {
  final map = <String, MaterialKindPrefs>{};

  @override
  Future<MaterialKindPrefs?> read(String sub) async => map[sub];

  @override
  Future<void> write(String sub, MaterialKindPrefs prefs) async => map[sub] = prefs;
}

MaterialKindPrefs _doc(List<String> ids, int day, {bool pending = false}) =>
    MaterialKindPrefs.validated(
      kindIds: ids,
      updatedAt: DateTime.utc(2026, 9, day),
      pendingPush: pending,
    );

void main() {
  late _MemoryRepository repo;
  final putCalls = <MaterialKindPrefs>[];

  setUp(() {
    repo = _MemoryRepository();
    putCalls.clear();
  });

  SyncMaterialKindPrefs make({
    MaterialKindPrefs? remote,
    Object? fetchError,
    Object? putError,
  }) {
    return SyncMaterialKindPrefs(
      repo,
      (_) async {
        if (fetchError != null) throw fetchError;
        return remote;
      },
      ({required idToken, required prefs}) async {
        putCalls.add(prefs);
        if (putError != null) throw putError;
        return prefs.copyWith(pendingPush: false);
      },
    );
  }

  test('sem token: skipped, sem tocar nada', () async {
    final result = await make()(idToken: null, sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.skipped);
    expect(putCalls, isEmpty);
  });

  test('remoto mais novo é adotado (pulled)', () async {
    repo.map['s'] = _doc(['local'], 1, pending: true);
    final result = await make(remote: _doc(['remoto'], 5))(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.pulled);
    expect(repo.map['s']!.kindIds, ['remoto']);
    expect(repo.map['s']!.pendingPush, isFalse);
    expect(putCalls, isEmpty);
  });

  test('sem local e com remoto: adota (pulled)', () async {
    final result = await make(remote: _doc(['remoto'], 5))(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.pulled);
    expect(repo.map['s']!.kindIds, ['remoto']);
  });

  test('local pendente e mais novo faz PUT (pushed) e limpa pendingPush', () async {
    repo.map['s'] = _doc(['local'], 9, pending: true);
    final result = await make(remote: _doc(['remoto'], 5))(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.pushed);
    expect(putCalls.single.kindIds, ['local']);
    expect(repo.map['s']!.pendingPush, isFalse);
  });

  test('409 no PUT adota o remoto (conflictAdopted)', () async {
    repo.map['s'] = _doc(['local'], 9, pending: true);
    final result = await make(
      remote: null,
      putError: MaterialKindPrefsConflict(_doc(['ganhou'], 10)),
    )(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.conflictAdopted);
    expect(repo.map['s']!.kindIds, ['ganhou']);
    expect(repo.map['s']!.pendingPush, isFalse);
  });

  test('pull falha mas push pendente segue; pullError fica no resultado', () async {
    repo.map['s'] = _doc(['local'], 9, pending: true);
    final result = await make(fetchError: StateError('rede'))(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.pushed);
    expect(result.pullError, isA<StateError>());
    expect(result.error, isA<StateError>());
  });

  test('push falha por rede: local continua pendente, pushError no resultado', () async {
    repo.map['s'] = _doc(['local'], 9, pending: true);
    final result = await make(putError: StateError('rede'))(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.noop);
    expect(result.pushError, isA<StateError>());
    expect(repo.map['s']!.pendingPush, isTrue);
  });

  test('nada pendente e remoto igual ou mais velho: noop', () async {
    repo.map['s'] = _doc(['local'], 9);
    final result = await make(remote: _doc(['local'], 9))(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.noop);
    expect(result.changedLocal, isFalse);
    expect(putCalls, isEmpty);
  });

  test('sem local nem remoto: noop', () async {
    final result = await make(remote: null)(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.noop);
    expect(repo.map, isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/material_kind_prefs/sync_material_kind_prefs_test.dart 2>&1 | tail -5`
Expected: erro de import.

- [ ] **Step 3: Usecase**

```dart
import 'package:flutter/foundation.dart';

import '../../data/datasources/material_kind_prefs_remote_datasource.dart';
import '../entities/material_kind_prefs.dart';
import '../repositories/material_kind_prefs_repository.dart';

enum MaterialKindPrefsSyncOutcome { pulled, pushed, conflictAdopted, noop, skipped }

/// Resultado de [SyncMaterialKindPrefs]. Erros ficam **crus**: quem traduz é a
/// UI com `userMessageFor`.
class MaterialKindPrefsSyncResult {
  const MaterialKindPrefsSyncResult(this.outcome, {this.pullError, this.pushError});

  final MaterialKindPrefsSyncOutcome outcome;
  final Object? pullError;
  final Object? pushError;

  /// Primeiro erro a mostrar — pull é o mais cedo.
  Object? get error => pullError ?? pushError;

  /// O documento local mudou nesta rodada (quem observa deve recarregar).
  bool get changedLocal =>
      outcome == MaterialKindPrefsSyncOutcome.pulled ||
      outcome == MaterialKindPrefsSyncOutcome.pushed ||
      outcome == MaterialKindPrefsSyncOutcome.conflictAdopted;

  static const skippedAuth = MaterialKindPrefsSyncResult(MaterialKindPrefsSyncOutcome.skipped);
}

typedef FetchMaterialKindPrefs = Future<MaterialKindPrefs?> Function(String idToken);
typedef PutMaterialKindPrefs =
    Future<MaterialKindPrefs> Function({
      required String idToken,
      required MaterialKindPrefs prefs,
    });

/// Sync de um documento só: pull → push, last-write-wins por `updatedAt`.
///
/// 1. Se o remoto existe e é mais novo que o local (ou não há local), adota.
/// 2. Senão, se o local está `pendingPush`, faz PUT; `409` adota o remoto.
/// Um pull que falha não impede o push — o erro volta no resultado.
class SyncMaterialKindPrefs {
  SyncMaterialKindPrefs(this._repository, this._fetch, this._put);

  final MaterialKindPrefsRepository _repository;
  final FetchMaterialKindPrefs _fetch;
  final PutMaterialKindPrefs _put;

  Future<MaterialKindPrefsSyncResult> call({
    required String? idToken,
    required String sub,
  }) async {
    if (idToken == null) return MaterialKindPrefsSyncResult.skippedAuth;

    final local = await _repository.read(sub);

    Object? pullError;
    MaterialKindPrefs? remote;
    try {
      remote = await _fetch(idToken);
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] pull falhou: $e');
      pullError = e;
    }

    if (remote != null && (local == null || remote.updatedAt.isAfter(local.updatedAt))) {
      await _repository.write(sub, remote.copyWith(pendingPush: false));
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.pulled,
        pullError: pullError,
      );
    }

    if (local == null || !local.pendingPush) {
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.noop,
        pullError: pullError,
      );
    }

    try {
      final saved = await _put(idToken: idToken, prefs: local);
      await _repository.write(sub, saved.copyWith(pendingPush: false));
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.pushed,
        pullError: pullError,
      );
    } on MaterialKindPrefsConflict catch (conflict) {
      await _repository.write(sub, conflict.remote.copyWith(pendingPush: false));
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.conflictAdopted,
        pullError: pullError,
      );
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] push falhou: $e');
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.noop,
        pullError: pullError,
        pushError: e,
      );
    }
  }
}
```

- [ ] **Step 4: Rodar testes**

Run: `flutter test test/unit/features/material_kind_prefs 2>&1 | tail -3`
Expected: passando.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/material_kind_prefs test/unit/features/material_kind_prefs
git add lib/features/material_kind_prefs test/unit/features/material_kind_prefs
git commit -m "feat(prefs): usecase SyncMaterialKindPrefs (pull → push, last-write-wins)"
```

---

### Task 6: Providers — prefs, rank, kinds e sync (+ ativação no shell)

**Files:**
- Create: `lib/features/material_kind_prefs/data/providers/material_kind_prefs_providers.dart`
- Create: `lib/features/material_kind_prefs/presentation/providers/coldigom_material_kinds_provider.dart`
- Create: `lib/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart`
- Create: `lib/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart`
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart` (linha ~153, ao lado de `ref.watch(playlistSyncProvider);`)
- Test: `test/unit/features/material_kind_prefs/material_kind_prefs_provider_test.dart`, `test/unit/features/material_kind_prefs/material_kind_prefs_sync_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 3–5; `authStateProvider`/`AuthNotifier` (`lib/features/auth/presentation/providers/auth_state_provider.dart`); `sharedPreferencesProvider`; `dioProvider` (`lib/core/providers/dio_provider.dart`); `connectivityStreamProvider` (`lib/core/network/connectivity_stream_provider.dart`); `coldigomRemoteDatasourceProvider` (`lib/features/coldigom/data/providers/coldigom_remote_providers.dart`) e `ColdigomMaterialKindDto`.
- Produces:
  - `materialKindPrefsLocalDatasourceProvider`, `materialKindPrefsRepositoryProvider`, `materialKindPrefsRemoteDatasourceProvider`, `syncMaterialKindPrefsProvider` (`Provider<SyncMaterialKindPrefs>`).
  - `coldigomMaterialKindsProvider: FutureProvider<List<ColdigomMaterialKindDto>>`.
  - `materialKindPrefsProvider: AsyncNotifierProvider<MaterialKindPrefsNotifier, MaterialKindPrefs>` com `Future<void> save(List<String> kindIds)`.
  - `favoriteMaterialKindRankProvider: Provider<Map<String, int>>`.
  - `materialKindPrefsSyncProvider: NotifierProvider<MaterialKindPrefsSyncNotifier, MaterialKindPrefsSyncState>` com `Future<MaterialKindPrefsSyncResult> sync()`; `MaterialKindPrefsSyncState { bool isSyncing; Object? lastErrorCause; MaterialKindPrefsSyncResult? lastResult; }`.

- [ ] **Step 1: Testes (falhando)**

`material_kind_prefs_provider_test.dart`:

```dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(googleSub: 'sub-1', idToken: 'tok');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

/// Sync que só conta chamadas — o provider de prefs pede sync após salvar.
class _CountingSync extends MaterialKindPrefsSyncNotifier {
  int calls = 0;

  @override
  MaterialKindPrefsSyncState build() => const MaterialKindPrefsSyncState();

  @override
  Future<MaterialKindPrefsSyncResult> sync() async {
    calls++;
    return MaterialKindPrefsSyncResult.skippedAuth;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> make({
    required AuthNotifier Function() auth,
    Map<String, Object> initial = const {},
    _CountingSync? sync,
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(auth),
        if (sync != null) materialKindPrefsSyncProvider.overrideWith(() => sync),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('deslogado → empty e rank vazio, sem ler SharedPreferences', () async {
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith(_LoggedOut.new)],
    );
    addTearDown(container.dispose);
    final prefs = await container.read(materialKindPrefsProvider.future);
    expect(prefs.kindIds, isEmpty);
    expect(container.read(favoriteMaterialKindRankProvider), isEmpty);
  });

  test('logado lê a chave do sub', () async {
    final container = await make(
      auth: _LoggedIn.new,
      initial: {
        MaterialKindPrefsLocalDatasource.keyFor('sub-1'):
            '{"kindIds":["a","b"],"updatedAt":"2026-09-01T00:00:00.000Z","pendingPush":false}',
        MaterialKindPrefsLocalDatasource.keyFor('sub-2'):
            '{"kindIds":["z"],"updatedAt":"2026-09-01T00:00:00.000Z","pendingPush":false}',
      },
    );
    final prefs = await container.read(materialKindPrefsProvider.future);
    expect(prefs.kindIds, ['a', 'b']);
    container.listen(favoriteMaterialKindRankProvider, (_, _) {});
    await container.pump();
    expect(container.read(favoriteMaterialKindRankProvider), {'a': 0, 'b': 1});
  });

  test('save grava pendingPush, atualiza o estado e dispara sync', () async {
    final sync = _CountingSync();
    final container = await make(auth: _LoggedIn.new, sync: sync);
    await container.read(materialKindPrefsProvider.future);
    final before = DateTime.now().toUtc();

    await container.read(materialKindPrefsProvider.notifier).save(['x', 'y']);

    final state = container.read(materialKindPrefsProvider).requireValue;
    expect(state.kindIds, ['x', 'y']);
    expect(state.pendingPush, isTrue);
    expect(state.updatedAt.isBefore(before), isFalse);
    final stored = container
        .read(materialKindPrefsLocalDatasourceProvider)
        .read('sub-1');
    expect(stored!.kindIds, ['x', 'y']);
    expect(sync.calls, 1);
  });

  test('save rejeita mais de 5 e duplicata sem tocar o estado', () async {
    final container = await make(auth: _LoggedIn.new, sync: _CountingSync());
    await container.read(materialKindPrefsProvider.future);
    await expectLater(
      container.read(materialKindPrefsProvider.notifier).save(['1', '2', '3', '4', '5', '6']),
      throwsArgumentError,
    );
    expect(container.read(materialKindPrefsProvider).requireValue.kindIds, isEmpty);
  });

  test('save deslogado é ignorado', () async {
    final sync = _CountingSync();
    final container = await make(auth: _LoggedOut.new, sync: sync);
    await container.read(materialKindPrefsProvider.future);
    await container.read(materialKindPrefsProvider.notifier).save(['x']);
    expect(container.read(materialKindPrefsProvider).requireValue.kindIds, isEmpty);
    expect(sync.calls, 0);
  });
}
```

(`materialKindPrefsLocalDatasourceProvider` vem de `lib/features/material_kind_prefs/data/providers/material_kind_prefs_providers.dart` — adicione o import.)

`material_kind_prefs_sync_provider_test.dart`:

```dart
import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/material_kind_prefs/data/providers/material_kind_prefs_providers.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/domain/usecases/sync_material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(googleSub: 'sub-1', idToken: 'tok');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, List<String>)> make({
    required AuthNotifier Function() auth,
    MaterialKindPrefs? remote,
    StreamController<bool>? connectivity,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(auth),
        if (connectivity != null)
          connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
        syncMaterialKindPrefsProvider.overrideWith((ref) {
          return SyncMaterialKindPrefs(
            ref.watch(materialKindPrefsRepositoryProvider),
            (_) async {
              calls.add('fetch');
              return remote;
            },
            ({required idToken, required prefs}) async {
              calls.add('put');
              return prefs.copyWith(pendingPush: false);
            },
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    return (container, calls);
  }

  test('login dispara uma sync e o pull recarrega materialKindPrefsProvider', () async {
    final remote = MaterialKindPrefs.validated(
      kindIds: const ['remoto'],
      updatedAt: DateTime.utc(2026, 9, 10),
    );
    final (container, calls) = await make(auth: _LoggedIn.new, remote: remote);
    container.listen(materialKindPrefsSyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['fetch']);
    final prefs = await container.read(materialKindPrefsProvider.future);
    expect(prefs.kindIds, ['remoto']);
  });

  test('deslogado não toca a rede', () async {
    final (container, calls) = await make(auth: _LoggedOut.new);
    container.listen(materialKindPrefsSyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    expect((await container.read(materialKindPrefsSyncProvider.notifier).sync()).outcome,
        MaterialKindPrefsSyncOutcome.skipped);
  });

  test('voltar a ficar online dispara sync com debounce', () async {
    MaterialKindPrefsSyncNotifier.reconnectDebounce = const Duration(milliseconds: 10);
    addTearDown(() => MaterialKindPrefsSyncNotifier.reconnectDebounce = const Duration(seconds: 2));
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);
    final (container, calls) = await make(auth: _LoggedIn.new, connectivity: connectivity);
    container.listen(materialKindPrefsSyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    calls.clear();

    connectivity.add(false);
    await Future<void>.delayed(Duration.zero);
    connectivity.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(calls, ['fetch']);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/material_kind_prefs 2>&1 | tail -5`
Expected: erro de import.

- [ ] **Step 3: Providers de dados**

`data/providers/material_kind_prefs_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/repositories/material_kind_prefs_repository.dart';
import '../../domain/usecases/sync_material_kind_prefs.dart';
import '../datasources/material_kind_prefs_local_datasource.dart';
import '../datasources/material_kind_prefs_remote_datasource.dart';
import '../repositories/material_kind_prefs_repository_impl.dart';

/// Lê `sharedPreferencesProvider` — só resolva quando há usuário logado (em
/// testes sem override ele lança).
final materialKindPrefsLocalDatasourceProvider =
    Provider<MaterialKindPrefsLocalDatasource>((ref) {
      return MaterialKindPrefsLocalDatasource(ref.watch(sharedPreferencesProvider));
    });

final materialKindPrefsRepositoryProvider = Provider<MaterialKindPrefsRepository>((
  ref,
) {
  return MaterialKindPrefsRepositoryImpl(
    ref.watch(materialKindPrefsLocalDatasourceProvider),
  );
});

final materialKindPrefsRemoteDatasourceProvider =
    Provider<MaterialKindPrefsRemoteDatasource>((ref) {
      return MaterialKindPrefsRemoteDatasource(ref.watch(dioProvider));
    });

final syncMaterialKindPrefsProvider = Provider<SyncMaterialKindPrefs>((ref) {
  final remote = ref.watch(materialKindPrefsRemoteDatasourceProvider);
  return SyncMaterialKindPrefs(
    ref.watch(materialKindPrefsRepositoryProvider),
    remote.fetch,
    remote.put,
  );
});
```

- [ ] **Step 4: Kinds do Coldigom**

`presentation/providers/coldigom_material_kinds_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/models/praise_dto.dart';
import '../../../coldigom/data/providers/coldigom_remote_providers.dart';

/// Catálogo de material kinds do Coldigom (`GET /api/materials/kinds`),
/// já ordenado por rótulo pelo Worker. Fica vivo: a lista muda raramente e
/// a tela de favoritos e o rótulo dos escolhidos leem dela.
final coldigomMaterialKindsProvider = FutureProvider<List<ColdigomMaterialKindDto>>((
  ref,
) {
  return ref.watch(coldigomRemoteDatasourceProvider).fetchMaterialKinds();
});
```

- [ ] **Step 5: Prefs + rank**

`presentation/providers/material_kind_prefs_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/material_kind_prefs_providers.dart';
import '../../domain/entities/material_kind_prefs.dart';
import 'material_kind_prefs_sync_provider.dart';

/// Documento de favoritos da conta logada; [MaterialKindPrefs.empty] para
/// quem está deslogado (a preferência é da conta — spec D5).
final materialKindPrefsProvider =
    AsyncNotifierProvider<MaterialKindPrefsNotifier, MaterialKindPrefs>(
      MaterialKindPrefsNotifier.new,
    );

class MaterialKindPrefsNotifier extends AsyncNotifier<MaterialKindPrefs> {
  @override
  Future<MaterialKindPrefs> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return MaterialKindPrefs.empty;
    // O repositório só é resolvido com usuário: ele lê SharedPreferences,
    // que em vários testes não tem override.
    final stored = await ref
        .read(materialKindPrefsRepositoryProvider)
        .read(user.googleSub);
    return stored ?? MaterialKindPrefs.empty;
  }

  /// Grava localmente com `updatedAt = agora`, marca `pendingPush` e pede
  /// sync. Deslogado: no-op. Lista inválida (>5, duplicata) lança
  /// [ArgumentError] antes de tocar o estado.
  Future<void> save(List<String> kindIds) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final next = MaterialKindPrefs.validated(
      kindIds: kindIds,
      updatedAt: DateTime.now().toUtc(),
      pendingPush: true,
    );
    await ref.read(materialKindPrefsRepositoryProvider).write(user.googleSub, next);
    if (!ref.mounted) return;
    state = AsyncData(next);
    unawaited(_syncQuietly());
  }

  /// A sync após o save é oportunista: falha vira log, nunca erro na tela —
  /// o documento já está local com `pendingPush` e sobe na próxima rodada.
  Future<void> _syncQuietly() async {
    try {
      await ref.read(materialKindPrefsSyncProvider.notifier).sync();
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] sync após save falhou: $e');
    }
  }
}

/// `kindId → posição` que o sheet consome. Vazio enquanto carrega ou deslogado.
final favoriteMaterialKindRankProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(materialKindPrefsProvider).asData?.value.rank ?? const {};
});
```

- [ ] **Step 6: Sync notifier**

`presentation/providers/material_kind_prefs_sync_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/material_kind_prefs_providers.dart';
import '../../domain/usecases/sync_material_kind_prefs.dart';
import 'material_kind_prefs_provider.dart';

class MaterialKindPrefsSyncState {
  const MaterialKindPrefsSyncState({
    this.isSyncing = false,
    this.lastResult,
    this.lastErrorCause,
  });

  final bool isSyncing;
  final MaterialKindPrefsSyncResult? lastResult;

  /// Erro cru da última tentativa; quem traduz é a tela (`userMessageFor`).
  final Object? lastErrorCause;

  MaterialKindPrefsSyncState copyWith({
    bool? isSyncing,
    MaterialKindPrefsSyncResult? lastResult,
    Object? lastErrorCause,
  }) {
    return MaterialKindPrefsSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      lastErrorCause: lastErrorCause ?? this.lastErrorCause,
    );
  }
}

/// Orquestra a sync dos favoritos: login com `sub` novo, volta da rede
/// (debounce) e `sync()` explícito após cada `save`.
///
/// Versão enxuta do `AudioFlagSyncNotifier`: sem adoção/purga porque o
/// documento já é por conta (chave = `sub`).
final materialKindPrefsSyncProvider =
    NotifierProvider<MaterialKindPrefsSyncNotifier, MaterialKindPrefsSyncState>(
      MaterialKindPrefsSyncNotifier.new,
    );

class MaterialKindPrefsSyncNotifier extends Notifier<MaterialKindPrefsSyncState> {
  static Duration reconnectDebounce = const Duration(seconds: 2);

  Future<MaterialKindPrefsSyncResult>? _inFlight;
  String? _lastSyncedSub;
  Timer? _reconnectTimer;

  @override
  MaterialKindPrefsSyncState build() {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    });

    ref.listen(authStateProvider, (prev, next) {
      final user = next.asData?.value;
      if (user == null) {
        _lastSyncedSub = null;
        return;
      }
      if (_lastSyncedSub == user.googleSub) return;
      _lastSyncedSub = user.googleSub;
      unawaited(Future<void>.microtask(() => sync()));
    }, fireImmediately: true);

    ref.listen(connectivityStreamProvider, (prev, next) {
      final online = next.asData?.value ?? false;
      final wasOnline = prev?.asData?.value ?? false;
      if (!online || wasOnline) return;
      if (ref.read(authStateProvider).asData?.value == null) return;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(reconnectDebounce, () {
        if (!ref.mounted) return;
        unawaited(sync());
      });
    });

    return const MaterialKindPrefsSyncState();
  }

  Future<MaterialKindPrefsSyncResult> sync() async {
    if (!ref.mounted) return MaterialKindPrefsSyncResult.skippedAuth;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return MaterialKindPrefsSyncResult.skippedAuth;

    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _run(user.idToken, user.googleSub);
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<MaterialKindPrefsSyncResult> _run(String idToken, String sub) async {
    state = state.copyWith(isSyncing: true);
    try {
      final result = await ref.read(syncMaterialKindPrefsProvider)(
        idToken: idToken,
        sub: sub,
      );
      if (!ref.mounted) return result;
      state = MaterialKindPrefsSyncState(
        isSyncing: false,
        lastResult: result,
        lastErrorCause: result.error,
      );
      if (result.changedLocal) ref.invalidate(materialKindPrefsProvider);
      return result;
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] sync falhou: $e');
      if (ref.mounted) {
        state = MaterialKindPrefsSyncState(isSyncing: false, lastErrorCause: e);
      }
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.noop,
        pushError: e,
      );
    }
  }
}
```

Atenção ao ciclo de imports `material_kind_prefs_provider.dart` ↔ `material_kind_prefs_sync_provider.dart`: Dart aceita imports circulares entre bibliotecas; se o analyzer reclamar de algo, mova `favoriteMaterialKindRankProvider` e o notifier de prefs para o mesmo arquivo que o sync. Preferível manter separados.

- [ ] **Step 7: Ativar no shell**

Em `shell_scaffold.dart`, logo após `ref.watch(playlistSyncProvider);`:

```dart
    ref.watch(materialKindPrefsSyncProvider);
```

com o import `../../material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart`.

- [ ] **Step 8: Rodar testes**

Run: `flutter test test/unit/features/material_kind_prefs test/widget/features/app_shell/shell_scaffold_test.dart 2>&1 | tail -3 && flutter analyze lib/features/material_kind_prefs lib/features/app_shell 2>&1 | tail -3`
Expected: passando. Se o teste de "login dispara sync" precisar de mais ticks para o microtask + `await` do repositório, troque os `Duration.zero` por `await container.pump()` repetido ou por `await Future<void>.delayed(const Duration(milliseconds: 20))`.

- [ ] **Step 9: Commit**

```bash
dart format lib/features/material_kind_prefs lib/features/app_shell/presentation/shell_scaffold.dart test/unit/features/material_kind_prefs
git add lib/features/material_kind_prefs lib/features/app_shell/presentation/shell_scaffold.dart test/unit/features/material_kind_prefs
git commit -m "feat(prefs): providers de favoritos, rank, kinds Coldigom e sync ativada no shell"
```

---

### Task 7: l10n, tela «Materiais favoritos», rota e tile no perfil

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (adicionar chaves no fim, antes do `}` final)
- Modify: `lib/core/routing/route_paths.dart` (após `about`)
- Modify: `lib/core/routing/app_router.dart` (branch `AppTab.profile`, ~linha 157)
- Modify: `lib/features/app_shell/presentation/pages/profile_screen.dart` (tiles, ~linhas 63–80)
- Create: `lib/features/material_kind_prefs/presentation/pages/favorite_material_kinds_screen.dart`
- Test: `test/widget/features/material_kind_prefs/favorite_material_kinds_screen_test.dart`, `test/widget/features/app_shell/profile_screen_favorites_tile_test.dart`

**Interfaces:**
- Consumes: `materialKindPrefsProvider` (`save`), `coldigomMaterialKindsProvider`, `materialKindPrefsSyncProvider`, `kMaxFavoriteMaterialKinds`, `GoogleSignInButton` (`lib/features/auth/presentation/widgets/google_sign_in_button.dart`), `userMessageFor` (`lib/core/errors/user_message_for.dart`), `LouvorSearchTokens.normalize` (`lib/core/utils/louvor_search_tokens.dart`), `AppColors`/`AppTypography` (`lib/core/theme/color_extensions.dart`, `lib/core/theme/app_typography.dart`), `goToShellDestination`.
- Produces: `RoutePaths.favoriteMaterialKinds = '/materiais-favoritos'`; `class FavoriteMaterialKindsScreen extends ConsumerStatefulWidget`; chaves l10n abaixo.

- [ ] **Step 1: l10n**

Em `app_pt.arb` (antes do `}` final; respeite a vírgula da entrada anterior):

```json
  "favoriteMaterialKindsTitle": "Materiais favoritos",
  "favoriteMaterialKindsHelp": "Escolha até {max} tipos de material. Eles aparecem primeiro ao abrir um louvor.",
  "@favoriteMaterialKindsHelp": {
    "placeholders": {
      "max": { "type": "int" }
    }
  },
  "favoriteMaterialKindsYours": "Seus favoritos ({count} de {max})",
  "@favoriteMaterialKindsYours": {
    "placeholders": {
      "count": { "type": "int" },
      "max": { "type": "int" }
    }
  },
  "favoriteMaterialKindsEmpty": "Nenhum favorito ainda",
  "favoriteMaterialKindsAdd": "Adicionar",
  "favoriteMaterialKindsSearchHint": "Buscar tipo de material",
  "favoriteMaterialKindsLimitReached": "Limite de {max} — remova um para trocar",
  "@favoriteMaterialKindsLimitReached": {
    "placeholders": {
      "max": { "type": "int" }
    }
  },
  "favoriteMaterialKindsSignInPrompt": "Entre com Google para escolher seus materiais favoritos.",
  "favoriteMaterialKindsSyncPending": "Sincronização pendente",
  "favoriteMaterialKindsRemoveTooltip": "Remover dos favoritos",
  "favoriteMaterialKindsAddTooltip": "Adicionar aos favoritos",
  "favoriteMaterialKindsUnknownKind": "Desconhecido",
  "favoriteMaterialKindsLoadError": "Não foi possível carregar os tipos de material",
  "favoriteMaterialKindsRetry": "Tentar de novo",
  "favoriteMaterialKindsNoMatch": "Nenhum tipo com esse nome"
```

Em `app_en.arb`, as mesmas chaves (os `@` de placeholders só são obrigatórios no template, mas repita para clareza):

```json
  "favoriteMaterialKindsTitle": "Favorite materials",
  "favoriteMaterialKindsHelp": "Pick up to {max} material types. They show first when you open a hymn.",
  "favoriteMaterialKindsYours": "Your favorites ({count} of {max})",
  "favoriteMaterialKindsEmpty": "No favorites yet",
  "favoriteMaterialKindsAdd": "Add",
  "favoriteMaterialKindsSearchHint": "Search material type",
  "favoriteMaterialKindsLimitReached": "Limit of {max} — remove one to swap",
  "favoriteMaterialKindsSignInPrompt": "Sign in with Google to pick your favorite materials.",
  "favoriteMaterialKindsSyncPending": "Sync pending",
  "favoriteMaterialKindsRemoveTooltip": "Remove from favorites",
  "favoriteMaterialKindsAddTooltip": "Add to favorites",
  "favoriteMaterialKindsUnknownKind": "Unknown",
  "favoriteMaterialKindsLoadError": "Couldn't load material types",
  "favoriteMaterialKindsRetry": "Try again",
  "favoriteMaterialKindsNoMatch": "No type with that name"
```

Run: `flutter gen-l10n 2>&1 | tail -3` (ou `flutter pub get`, que dispara a geração). Expected: sem erro; `lib/l10n/app_localizations.dart` ganha os getters.

- [ ] **Step 2: Testes de widget (falhando)**

`test/widget/features/material_kind_prefs/favorite_material_kinds_screen_test.dart`:

```dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/pages/favorite_material_kinds_screen.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/coldigom_material_kinds_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(googleSub: 'sub-1', idToken: 'tok');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

/// Sync inerte: a tela só precisa que `sync()` exista.
class _NoopSync extends MaterialKindPrefsSyncNotifier {
  @override
  MaterialKindPrefsSyncState build() => const MaterialKindPrefsSyncState();

  @override
  Future<MaterialKindPrefsSyncResult> sync() async => MaterialKindPrefsSyncResult.skippedAuth;
}

const _kinds = [
  ColdigomMaterialKindDto(id: 'k-partitura', name: 'Partitura'),
  ColdigomMaterialKindDto(id: 'k-soprano', name: 'Voz soprano'),
  ColdigomMaterialKindDto(id: 'k-tenor', name: 'Voz tenor'),
  ColdigomMaterialKindDto(id: 'k-baixo', name: 'Voz baixo'),
  ColdigomMaterialKindDto(id: 'k-coro', name: 'Coro'),
  ColdigomMaterialKindDto(id: 'k-trompete', name: 'Trompete'),
  ColdigomMaterialKindDto(id: 'k-violao', name: 'Violão'),
];

void main() {
  late AppLocalizations pt;
  late SharedPreferences prefs;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(
    WidgetTester tester, {
    AuthNotifier Function() auth = _LoggedIn.new,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const FavoriteMaterialKindsScreen(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(auth),
        materialKindPrefsSyncProvider.overrideWith(_NoopSync.new),
        coldigomMaterialKindsProvider.overrideWith((ref) async => _kinds),
        ...extra,
      ],
    );
    await tester.pumpAndSettle();
  }

  /// O `IconButton` de `+` na linha do kind [name]. `find.byTooltip` acharia
  /// o `Tooltip` interno, não o botão — por isso o predicado.
  Finder addButtonFor(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
    matching: find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == pt.favoriteMaterialKindsAddTooltip,
    ),
  );

  Finder removeButtons() => find.byWidgetPredicate(
    (w) => w is IconButton && w.tooltip == pt.favoriteMaterialKindsRemoveTooltip,
  );

  testWidgets('deslogado mostra aviso e botão de login, sem lista', (tester) async {
    await pump(tester, auth: _LoggedOut.new);
    expect(find.text(pt.favoriteMaterialKindsSignInPrompt), findsOneWidget);
    expect(find.text('Partitura'), findsNothing);
  });

  testWidgets('adiciona até 5; o 6º + fica desabilitado e o limite aparece', (tester) async {
    await pump(tester);
    expect(find.text(pt.favoriteMaterialKindsEmpty), findsOneWidget);

    for (final name in ['Partitura', 'Voz soprano', 'Voz tenor', 'Voz baixo', 'Coro']) {
      await tester.tap(addButtonFor(name));
      await tester.pumpAndSettle();
    }

    expect(find.text(pt.favoriteMaterialKindsYours(5, 5)), findsOneWidget);
    expect(find.text(pt.favoriteMaterialKindsLimitReached(5)), findsOneWidget);
    final sixth = tester.widget<IconButton>(addButtonFor('Trompete'));
    expect(sixth.onPressed, isNull);

    final stored = MaterialKindPrefsLocalDatasource(prefs).read('sub-1');
    expect(stored!.kindIds, ['k-partitura', 'k-soprano', 'k-tenor', 'k-baixo', 'k-coro']);
    expect(stored.pendingPush, isTrue);
  });

  testWidgets('remover pelo × tira da lista e salva', (tester) async {
    await pump(tester);
    await tester.tap(addButtonFor('Coro'));
    await tester.pumpAndSettle();
    await tester.tap(removeButtons());
    await tester.pumpAndSettle();

    expect(find.text(pt.favoriteMaterialKindsEmpty), findsOneWidget);
    expect(MaterialKindPrefsLocalDatasource(prefs).read('sub-1')!.kindIds, isEmpty);
  });

  testWidgets('arrastar reordena e salva a ordem nova', (tester) async {
    await pump(tester);
    await tester.tap(addButtonFor('Partitura'));
    await tester.pumpAndSettle();
    await tester.tap(addButtonFor('Coro'));
    await tester.pumpAndSettle();

    // Handle do segundo item (Coro) arrastado para cima do primeiro.
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    final drag = await tester.startGesture(tester.getCenter(handles.at(1)));
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveBy(const Offset(0, -80));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(MaterialKindPrefsLocalDatasource(prefs).read('sub-1')!.kindIds, [
      'k-coro',
      'k-partitura',
    ]);
  });

  testWidgets('busca filtra sem acento e some do restante o que já é favorito', (tester) async {
    await pump(tester);
    await tester.tap(addButtonFor('Violão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'violao');
    await tester.pumpAndSettle();
    // "Violão" já é favorito: aparece só na lista de cima, não na de adicionar.
    expect(addButtonFor('Violão'), findsNothing);
    expect(find.text(pt.favoriteMaterialKindsNoMatch), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'voz');
    await tester.pumpAndSettle();
    expect(addButtonFor('Voz soprano'), findsOneWidget);
    expect(addButtonFor('Partitura'), findsNothing);
  });

  testWidgets('erro ao carregar kinds mostra retry, favoritos salvos ficam pelo id', (tester) async {
    await prefs.setString(
      MaterialKindPrefsLocalDatasource.keyFor('sub-1'),
      '{"kindIds":["k-x"],"updatedAt":"2026-09-01T00:00:00.000Z","pendingPush":false}',
    );
    await pump(
      tester,
      extra: [
        coldigomMaterialKindsProvider.overrideWith((ref) async => throw StateError('rede')),
      ],
    );
    expect(find.text(pt.favoriteMaterialKindsLoadError), findsOneWidget);
    expect(find.text(pt.favoriteMaterialKindsRetry), findsOneWidget);
    expect(find.text(pt.favoriteMaterialKindsUnknownKind), findsOneWidget);
  });
}
```

`test/widget/features/app_shell/profile_screen_favorites_tile_test.dart`:

```dart
import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'tok', name: 'Jairo');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  testWidgets('tile de favoritos aparece só logado', (tester) async {
    await pumpApp(
      tester,
      const ProfileScreen(),
      overrides: [authStateProvider.overrideWith(_LoggedIn.new)],
    );
    await tester.pumpAndSettle();
    expect(find.text(pt.favoriteMaterialKindsTitle), findsOneWidget);
  });

  testWidgets('deslogado não mostra o tile', (tester) async {
    await pumpApp(
      tester,
      const ProfileScreen(),
      overrides: [authStateProvider.overrideWith(_LoggedOut.new)],
    );
    await tester.pumpAndSettle();
    expect(find.text(pt.favoriteMaterialKindsTitle), findsNothing);
  });
}
```

Se `ProfileScreen` logado precisar de mais overrides (ex.: `googleSignInUnavailableProvider`), copie o `baseOverrides` de `profile_screen_errors_test.dart`.

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/material_kind_prefs test/widget/features/app_shell/profile_screen_favorites_tile_test.dart 2>&1 | tail -5`
Expected: erro de import / tile ausente.

- [ ] **Step 4: Rota**

`route_paths.dart`, após `about`:

```dart
  /// Material kinds favoritos ([FavoriteMaterialKindsScreen]) — branch Perfil.
  static const String favoriteMaterialKinds = '/materiais-favoritos';
```

`app_router.dart`, no branch `AppTab.profile`, após a rota `about`:

```dart
        GoRoute(
          path: RoutePaths.favoriteMaterialKinds,
          builder: (context, state) => const FavoriteMaterialKindsScreen(),
        ),
```

com import `../../features/material_kind_prefs/presentation/pages/favorite_material_kinds_screen.dart`. Se houver um teste de inventário de rotas (`test/unit/core/app_router_test.dart`), rode-o e acrescente a rota nova à lista esperada.

- [ ] **Step 5: Tile no perfil**

Em `ProfileScreen.build`, entre o tile «Listas» e o «Offline»:

```dart
            if (auth.asData?.value != null) ...[
              const SizedBox(height: 10),
              _ProfilePageTile(
                icon: Icons.star_outline,
                title: l10n.favoriteMaterialKindsTitle,
                onTap: () => goToShellDestination(
                  context,
                  RoutePaths.favoriteMaterialKinds,
                ),
              ),
            ],
```

- [ ] **Step 6: Tela**

`favorite_material_kinds_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/presentation/widgets/google_sign_in_button.dart';
import '../../../coldigom/data/models/praise_dto.dart';
import '../../domain/entities/material_kind_prefs.dart';
import '../providers/coldigom_material_kinds_provider.dart';
import '../providers/material_kind_prefs_provider.dart';
import '../providers/material_kind_prefs_sync_provider.dart';

/// «Materiais favoritos»: até [kMaxFavoriteMaterialKinds] material kinds
/// Coldigom em ordem de preferência. Salva a cada mudança — sem botão.
///
/// Deslogado vê só o convite para entrar (a preferência é da conta), mas a
/// rota existe para quem chega por URL.
class FavoriteMaterialKindsScreen extends ConsumerStatefulWidget {
  const FavoriteMaterialKindsScreen({super.key});

  static const double _maxContentWidth = 896;

  @override
  ConsumerState<FavoriteMaterialKindsScreen> createState() =>
      _FavoriteMaterialKindsScreenState();
}

class _FavoriteMaterialKindsScreenState
    extends ConsumerState<FavoriteMaterialKindsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> kindIds) {
    return ref.read(materialKindPrefsProvider.notifier).save(kindIds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoriteMaterialKindsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FavoriteMaterialKindsScreen._maxContentWidth,
          ),
          child: user == null ? _signedOut(l10n) : _signedIn(l10n),
        ),
      ),
    );
  }

  Widget _signedOut(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            l10n.favoriteMaterialKindsSignInPrompt,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          const GoogleSignInButton(),
        ],
      ),
    );
  }

  Widget _signedIn(AppLocalizations l10n) {
    final prefsAsync = ref.watch(materialKindPrefsProvider);
    final kindsAsync = ref.watch(coldigomMaterialKindsProvider);
    final syncState = ref.watch(materialKindPrefsSyncProvider);
    final prefs = prefsAsync.asData?.value ?? MaterialKindPrefs.empty;
    final kinds = kindsAsync.asData?.value ?? const <ColdigomMaterialKindDto>[];
    final labels = {for (final kind in kinds) kind.id: kind.name};
    final chosen = prefs.kindIds;
    final full = chosen.length >= kMaxFavoriteMaterialKinds;
    final normalizedQuery = LouvorSearchTokens.normalize(_query);
    final candidates = [
      for (final kind in kinds)
        if (!chosen.contains(kind.id) &&
            (normalizedQuery.isEmpty ||
                LouvorSearchTokens.normalize(kind.name).contains(normalizedQuery)))
          kind,
    ];
    final showSyncPending =
        prefs.pendingPush || syncState.lastErrorCause != null;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList.list(
            children: [
              Text(
                l10n.favoriteMaterialKindsHelp(kMaxFavoriteMaterialKinds),
                style: AppTypography.body.copyWith(color: AppColors.textDark),
              ),
              if (showSyncPending) ...[
                const SizedBox(height: 8),
                Text(
                  syncState.lastErrorCause == null
                      ? l10n.favoriteMaterialKindsSyncPending
                      : '${l10n.favoriteMaterialKindsSyncPending} — '
                            '${userMessageFor(l10n, syncState.lastErrorCause!)}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textDark.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _sectionLabel(
                l10n.favoriteMaterialKindsYours(chosen.length, kMaxFavoriteMaterialKinds),
              ),
              if (chosen.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.favoriteMaterialKindsEmpty,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textDark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverReorderableList(
            itemCount: chosen.length,
            onReorder: (oldIndex, newIndex) {
              final next = [...chosen];
              final moved = next.removeAt(oldIndex);
              next.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
              _save(next);
            },
            itemBuilder: (context, index) {
              final id = chosen[index];
              return ListTile(
                key: ValueKey('fav-$id'),
                leading: Text(
                  '${index + 1}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                title: Text(
                  labels[id] ?? l10n.favoriteMaterialKindsUnknownKind,
                  style: AppTypography.body.copyWith(color: AppColors.textDark),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.favoriteMaterialKindsRemoveTooltip,
                      color: AppColors.title,
                      onPressed: () => _save([...chosen]..removeAt(index)),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: AppColors.title),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList.list(
            children: [
              _sectionLabel(l10n.favoriteMaterialKindsAdd),
              if (full)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.favoriteMaterialKindsLimitReached(kMaxFavoriteMaterialKinds),
                    style: AppTypography.label.copyWith(color: AppColors.title),
                  ),
                ),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.favoriteMaterialKindsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              if (kindsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (kindsAsync.hasError)
                ListTile(
                  leading: const Icon(Icons.refresh, color: AppColors.title),
                  title: Text(l10n.favoriteMaterialKindsLoadError),
                  subtitle: Text(l10n.favoriteMaterialKindsRetry),
                  onTap: () => ref.invalidate(coldigomMaterialKindsProvider),
                ),
              if (kindsAsync.hasValue && candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.favoriteMaterialKindsNoMatch,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textDark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final kind = candidates[index];
              return ListTile(
                key: ValueKey('cand-${kind.id}'),
                title: Text(
                  kind.name,
                  style: AppTypography.body.copyWith(color: AppColors.textDark),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: l10n.favoriteMaterialKindsAddTooltip,
                  color: AppColors.title,
                  onPressed: full ? null : () => _save([...chosen, kind.id]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.title,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

Notas para quem implementa:
- `AppTypography.body`/`label` e `AppColors.title`/`textDark`/`gold` são os usados em `material_sheet.dart`; confirme os nomes lá.
- `GoogleSignInButton` é `const`? Verifique o construtor em `google_sign_in_button.dart` e ajuste.
- Se `LouvorSearchTokens.normalize` não remover acentos de "ã" (veja `_regA` no arquivo), o teste "busca sem acento" precisa de outro exemplo; ajuste o teste, não a função.
- Se `SliverReorderableList` não disparar `onReorder` no teste de arrastar, aumente a distância de `moveBy` para `Offset(0, -120)` — o item tem ~56 px.

- [ ] **Step 7: Rodar testes**

Run: `flutter test test/widget/features/material_kind_prefs test/widget/features/app_shell test/unit/core/app_router_test.dart 2>&1 | tail -3 && flutter analyze lib/features/material_kind_prefs lib/features/app_shell lib/core/routing 2>&1 | tail -3`
Expected: passando; analyze limpo.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/material_kind_prefs lib/features/app_shell lib/core/routing test/widget/features/material_kind_prefs test/widget/features/app_shell
git add lib/l10n lib/features/material_kind_prefs lib/features/app_shell lib/core/routing test/widget/features/material_kind_prefs test/widget/features/app_shell test/unit/core
git commit -m "feat(perfil): tela Materiais favoritos — escolha, ordem e rota /materiais-favoritos"
```

---

### Task 8: `MaterialSheet` — favoritos primeiro em cada aba

**Files:**
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart` (`build` ~linhas 215–330, `_pdfTiles` ~332–360, `_chordTiles` ~362–390)
- Test: `test/widget/features/catalog/material_sheet_favorites_test.dart`

**Interfaces:**
- Consumes: `favoriteMaterialKindRankProvider` (Task 6), `orderByFavoriteKinds` (Task 3), `materialKindId` nas entidades (Task 2).

- [ ] **Step 1: Teste (falhando)**

Reaproveite os fixtures/fakes de `material_sheet_test.dart` copiando o que precisar (`_pumpSheet` é privado). Versão mínima:

```dart
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _pdf(String categoria, String pdfId, {String? kind}) => Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '692',
  categoria: categoria,
  classificacao: 'Coletânea',
  pdf: '$pdfId.pdf',
  pdfId: pdfId,
  groupId: 'g1',
  source: LouvorDataSource.coldigom,
  materialKindId: kind,
);

AudioTrack _audio(String categoria, String id, {String? kind}) => AudioTrack(
  audioId: id,
  r2Key: '$id.mp3',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: categoria,
  classificacao: 'Coletânea',
  materialKindId: kind,
);

LouvorGroup _group() => LouvorGroup(
  groupId: 'g1',
  numero: '692',
  nome: 'Comigo habita',
  sections: [
    LouvorMaterialSection(
      classificacao: 'Coletânea',
      displayLabel: 'Coletânea',
      materials: [
        LouvorMaterialEntry(categoria: 'Grade', pdfId: 'p1', louvor: _pdf('Grade', 'p1', kind: 'k-grade')),
        LouvorMaterialEntry(categoria: 'Trompete', pdfId: 'p2', louvor: _pdf('Trompete', 'p2', kind: 'k-trompete')),
        LouvorMaterialEntry(categoria: 'Partitura', pdfId: 'p3', louvor: _pdf('Partitura', 'p3', kind: 'k-partitura')),
      ],
    ),
  ],
  audioTracks: [
    _audio('Coro', 'a1', kind: 'k-coro'),
    _audio('Voz soprano', 'a2', kind: 'k-soprano'),
    _audio('Playback', 'a3'),
  ],
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Map<String, int> rank,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
        activeEntriesProvider.overrideWithValue(const []),
        favoriteMaterialKindRankProvider.overrideWithValue(rank),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMaterialSheet(context, ref, _group(), canAddToPlaylist: false),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// Ordem vertical dos textos [labels] que estão na tela.
List<String> _visibleOrder(WidgetTester tester, List<String> labels) {
  final present = labels.where((l) => find.text(l).evaluate().isNotEmpty).toList();
  present.sort((a, b) => tester.getTopLeft(find.text(a)).dy.compareTo(tester.getTopLeft(find.text(b)).dy));
  return present;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sem rank a ordem é a do grupo', (tester) async {
    await _pumpSheet(tester, rank: const {});
    expect(_visibleOrder(tester, ['Grade', 'Trompete', 'Partitura']), ['Grade', 'Trompete', 'Partitura']);
  });

  testWidgets('favoritos sobem na aba PDF na ordem do rank', (tester) async {
    await _pumpSheet(tester, rank: const {'k-partitura': 0, 'k-trompete': 1});
    expect(_visibleOrder(tester, ['Grade', 'Trompete', 'Partitura']), ['Partitura', 'Trompete', 'Grade']);
  });

  testWidgets('favoritos sobem na aba de áudio; sem kind fica onde está', (tester) async {
    await _pumpSheet(tester, rank: const {'k-soprano': 0});
    await tester.tap(find.text('Áudio'));
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester, ['Coro', 'Voz soprano', 'Playback']), ['Voz soprano', 'Coro', 'Playback']);
  });
}
```

O rótulo da aba de áudio é `l10n.audioMaterialSection` — se não for literalmente «Áudio», carregue `AppLocalizations` no `setUpAll` como nos outros testes e use a chave. Se `activeEntriesProvider` não existir com esse nome, confira o import usado em `material_sheet_test.dart` (`active_playlist_editor.dart`) e copie o override de lá.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/catalog/material_sheet_favorites_test.dart 2>&1 | tail -5`
Expected: os dois testes de rank falham (ordem inalterada); o "sem rank" passa.

- [ ] **Step 3: Sheet**

Em `material_sheet.dart`:

1. Imports:

```dart
import '../../../material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart';
import '../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
```

2. No `build`, após `final activeMaterialIds = ref.watch(activeMaterialIdsProvider);`:

```dart
    // Favoritos da conta (spec D9): sobem dentro de cada aba, o resto mantém
    // a ordem do servidor. Vazio para deslogado e para o acervo PLPCG.
    final rank = ref.watch(favoriteMaterialKindRankProvider);
```

3. Passe `rank` para `_pdfTiles(group, activeMaterialIds, l10n, rank)` e `_chordTiles(group, availableChords, chordsAsync.hasError, activeMaterialIds, l10n, rank)`; e nas abas inline:

```dart
                  MaterialKind.gesture => [
                    for (final gesture in orderByFavoriteKinds(
                      gestureMaterials,
                      rank,
                      kindIdOf: (g) => g.materialKindId,
                    ))
                      _materialTile(/* mesmos argumentos de hoje */),
                  ],
                  MaterialKind.audio => [
                    for (final track in orderByFavoriteKinds(
                      audioTracks,
                      rank,
                      kindIdOf: (t) => t.materialKindId,
                    ))
                      _materialTile(/* mesmos argumentos de hoje */),
                  ],
                  MaterialKind.youtube => [
                    for (final item in orderByFavoriteKinds(
                      youtubeMaterials,
                      rank,
                      kindIdOf: (y) => y.materialKindId,
                    ))
                      _materialTile(/* mesmos argumentos de hoje */),
                  ],
```

Só a fonte do `for` muda; cada `_materialTile(...)` fica exatamente com os argumentos que já tem no arquivo.

4. `_pdfTiles` ganha o parâmetro `Map<String, int> rank` e troca o loop interno por:

```dart
        for (final entry in orderByFavoriteKinds(
          section.materials,
          rank,
          kindIdOf: (e) => e.louvor.materialKindId,
        ))
          _materialTile(/* mesmos argumentos de hoje */),
```

5. `_chordTiles` ganha `Map<String, int> rank` e itera `orderByFavoriteKinds(availableChords, rank, kindIdOf: (c) => c.materialKindId)`.

Não mude abas, aba inicial, rótulos, `+`/`×`.

- [ ] **Step 4: Rodar testes**

Run: `flutter test test/widget/features/catalog 2>&1 | tail -3 && flutter analyze lib/features/catalog 2>&1 | tail -3`
Expected: todos passando (os antigos de `material_sheet_test.dart` inclusive — eles não têm override de rank e `authStateProvider` real resolve para `null` em teste, então o rank é vazio).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/catalog/presentation/widgets/material_sheet.dart test/widget/features/catalog/material_sheet_favorites_test.dart
git add lib/features/catalog/presentation/widgets/material_sheet.dart test/widget/features/catalog/material_sheet_favorites_test.dart
git commit -m "feat(catalog): sheet de materiais lista os material kinds favoritos primeiro em cada aba"
```

---

### Task 9: Verificação final

**Files:** nenhum novo.

- [ ] **Step 1: Suite Flutter completa**

Run: `flutter test test/unit test/widget --reporter compact 2>&1 | tail -3`
Expected: só as falhas de baseline (`pdfrx_viewer_adapter_test` por timeout, `reconcile_offline_index_benchmark_test`). Qualquer outra falha é desta feature — corrija.

- [ ] **Step 2: Analyze e format**

Run: `flutter analyze 2>&1 | tail -3 && dart format --set-exit-if-changed lib test 2>&1 | tail -2`
Expected: `No issues found!` e formatação limpa.

- [ ] **Step 3: Worker**

Run: `cd workers/plpcg-catalog && npm test 2>&1 | tail -6 && npm run check 2>&1 | tail -3`
Expected: verde.

- [ ] **Step 4: Build web (fumaça)**

Run: `flutter build web --dart-define-from-file=dart_defines/plpcg.json 2>&1 | tail -3`
Expected: build ok (garante que a rota/tela compilam para web, plataforma primária).

- [ ] **Step 5: Relatar**

Listar no relatório final: commits, resultado das suítes, e os passos que ficam com o dono do deploy — `npm run db:migrate:remote` e `npm run deploy` no Worker antes de publicar a web.
