# Offline Coldigom — Parte 1: Catálogo local — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O catálogo Coldigom inteiro (1690 louvores: metadados, letra e lista de materiais) passa a viver em Isar (`ColdigomPraiseCache`), sincronizado por ETag a partir do endpoint novo `GET /api/plpcg/catalog`. No boot os caches em memória são hidratados do Isar, a pesquisa da Home ganha resultados Coldigom locais (índice em memória, mesmo ranking do PLPCG) e a letra vira um material `MaterialKind.lyrics` com leitor próprio em `/letra`.

**Architecture:** Patch no Worker `coldigom-api` (dump compacto + `ETag`/`304`). No Flutter, `ColdigomRemoteDatasource.fetchCatalog` → `ColdigomCatalogDto` (parse tolerante, `r2Key` derivado) → `SyncColdigomCatalog` grava linhas `ColdigomPraiseCache` numa transação (`replaceAll`) e o ETag em prefs. `coldigomCatalogHydrationProvider` lê o Isar uma vez, converte com `ColdigomLouvorAdapter` (agora com `toLyricsMaterial`) e entrega tudo ao `ColdigomCacheWriter` (`mergeCatalog`) — único escritor dos caches em memória — e ao `ColdigomSearchIndex`. `ColdigomCatalogSource.searchLocal` deixa de devolver `[]`; `CompositeCatalogSource.searchLocal` e `homeLocalSearchProvider` concatenam PLPCG + Coldigom. Letra: `LyricsMaterial` na `sealed class CatalogMaterial`, aba «Letra» no sheet, rota `/letra` com `LyricsReaderScreen` lendo do Isar.

**Tech Stack:** Flutter 3 + Riverpod 3 (`Notifier`/`AsyncNotifier`/`FutureProvider`), `isar_plus` (`@Collection()` + `part 'x.g.dart'` + `dart run build_runner build --delete-conflicting-outputs`), Dio, SharedPreferences, go_router, `flutter gen-l10n` (`app_pt.arb` template + `app_en.arb`; os `app_localizations*.dart` gerados são versionados). Worker Cloudflare em TypeScript (Hono + D1) com testes `vitest`.

**Spec:** `docs/superpowers/specs/2026-09-14-offline-coldigom-design.md` (secções §3 patch do coldigom-api, §4 catálogo local, hidratação, índice de pesquisa local, letra + leitor `/letra`; decisões O1–O6, O16)

**Depende de:** nada (é a primeira das três partes). Os planos 2 e 3 consomem daqui: `ColdigomPraiseCache`, `ColdigomCatalogLocalDatasource` (`findAllSync`, `findByPraiseIdSync`, `upsertMany`, `replaceAll`, `count`), `ColdigomPraiseCacheMapper` (`fromCatalogPraise`, `toPraiseDetail`, `decodeMaterials`), `ColdigomCatalogMaterialEntry`, `coldigomCatalogLocalDatasourceProvider`, `coldigomCatalogSyncProvider` (`sync()`, `requestSyncIfStale()`), `coldigomCatalogHydrationProvider`, `coldigomSearchIndexProvider`, `ColdigomCatalogSyncMetadataStore` (`readEtag`, `readSyncedAt`, `readCount`), `LyricsMaterial`, `MaterialKind.lyrics`, `coldigomLyricsCacheProvider`, `ColdigomCacheWriter.mergeCatalog`, `RoutePaths.lyrics`.

## Global Constraints

- Todos os comandos rodam a partir da raiz da worktree `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/offline-coldigom`.
- Nunca migrar/alterar `OfflinePdfIndex`, `LouvorCache`, `ChordContentCache`, `GestureDocumentCache` (decisões O7/O8) — só collections novas (`ColdigomPraiseCache` aqui; `OfflineAudioIndex` no plano 2).
- `r2Key` é derivado: `assets/praises/<praiseId>/<materialId>.<ext>` (O2), com `ext` por `type` (`pdf→pdf`, `mp3|audio→mp3`, `chord→chord`, `gestures→gestures`); YouTube usa `url`. O dump pode mandar `r2` explícito quando o Worker detecta divergência — o parser dá precedência a `r2`.
- Letra: `MaterialKind.lyrics`, id `lyrics:<praiseId>`, sem download, sem favoritos (O6) — `materialKindId == null`, `canAddMaterialToPlaylist` devolve `false`.
- Download só logado (O9); seleção local em prefs `offlineColdigomKindIds` (O11); idempotente sem checkpoint (O12); usa `offlineMaintenanceLockProvider` e `wakelock_plus` — tudo isto é do plano 2, nada aqui pode contrariar.
- Pesquisa: lista única, PLPCG primeiro e Coldigom depois; remoto só valida a página 1; novos entram no fim (O15/O16) — aqui só a parte local (concatenação); a validação remota é o plano 3.
- Os caches em memória (`coldigomLouvoresCacheProvider` etc.) só são escritos pelo `ColdigomCacheWriter` (O4). A hidratação faz **um** merge em lote (`mergeCatalog`), nunca 1690 `mergePraiseDetail` (cada merge copia o mapa inteiro).
- Sync é best-effort: `SyncColdigomCatalog.run()` nunca lança; devolve `ColdigomCatalogSyncResult` com `cause` para a UI do `/offline` (plano 2).
- Sem Isar (modo degradado): leituras do `ColdigomCatalogLocalDatasource` devolvem vazio/`null`; escritas lançam `StorageUnavailableException('coldigom_catalog.<op>')`.
- Comentários de código e strings em português, no tom do código vizinho (explicam o porquê).
- Antes de cada commit: `dart format` nos ficheiros tocados, `flutter analyze` sem erros novos, testes da task verdes (`flutter gen-l10n` antes do `analyze` quando a task mexe nos `.arb`).
- Commits terminam com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP
  ```
- Baseline conhecido: `pdfrx_viewer_adapter_test` e `reconcile_offline_index_benchmark_test` falham por timeout sob carga — pré-existente, não corrigir.

---

## File map

**Worker (patch, fora do repo)**
- Create `patches/coldigom-api-plpcg-catalog.patch` — handler `GET /api/plpcg/catalog` (dump + ETag/304) e testes vitest.

**Flutter — DTO, endpoint, datasource remoto**
- Create `test/fixtures/coldigom_catalog_sample.json` — três praises de amostra (PDF/áudio/cifra/gestos/YouTube, letra presente e ausente, `r2` explícito).
- Modify `lib/features/coldigom/data/constants/coldigom_endpoints.dart` — `plpcgCatalog`.
- Create `lib/features/coldigom/data/models/coldigom_catalog_dto.dart` — `ColdigomCatalogDto`, `ColdigomCatalogPraiseDto`, `ColdigomCatalogMaterialDto`, `coldigomCatalogExtensionForType`.
- Modify `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart` — `fetchCatalog({ifNoneMatch})` → `ColdigomCatalogFetchResult`.

**Flutter — Isar + sync**
- Create `lib/core/database/collections/coldigom_praise_cache.dart` (+ `.g.dart` gerado).
- Modify `lib/core/database/isar_app_schemas.dart` — `ColdigomPraiseCacheSchema`.
- Modify `lib/core/constants/storage_keys.dart` — `coldigomCatalogEtag`, `coldigomCatalogSyncedAt`, `coldigomCatalogCount`, `lyricsReaderFontSize`.
- Create `lib/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart`.
- Create `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart` — DTO → linha Isar (tokens de busca, JSON de materiais) e linha → `PraiseDetailDto`.
- Create `lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart` — ETag/`syncedAt`/`count` em prefs.
- Create `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart` — `SyncColdigomCatalog` + `ColdigomCatalogSyncResult`.
- Create `lib/features/coldigom/data/providers/coldigom_catalog_data_providers.dart` — DI do datasource local, metadata store e use case.

**Flutter — letra (entidade)**
- Modify `lib/core/utils/material_id_kind.dart` — `MaterialKind.lyrics`, `materialKindOfRawType('lyrics')`, prefixo `lyrics:` em `materialIdKindOf`.
- Modify `lib/features/catalog/domain/entities/catalog_material.dart` — `LyricsMaterial`.
- Modify `lib/features/catalog/domain/entities/louvor_group.dart` — parâmetro `lyrics` no construtor e em `fromLouvores`; `isColdigom`.
- Modify `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart` — `toLyricsMaterial`.
- Modify `lib/features/catalog/domain/utils/louvor_material_icons.dart`, `lib/features/catalog/presentation/widgets/home_empty_state.dart`, `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart`, `lib/features/material_kind_prefs/presentation/widgets/material_type_preference_control.dart`, `lib/features/catalog/presentation/widgets/material_sheet.dart`, `lib/features/catalog/presentation/providers/open_material_provider.dart` — `switch` exaustivos.
- Modify `lib/features/coldigom/data/providers/coldigom_providers.dart` — `coldigomLyricsCacheProvider`.
- Modify `lib/features/coldigom/data/coldigom_cache_writer.dart` — `mergeCatalog`, `mergeLyrics`.
- Modify `lib/features/coldigom/data/sources/coldigom_catalog_source.dart` — mapa `lyrics`, `index`, `searchLocal`, caso `lyrics` em `findMaterialById`.
- Modify `lib/features/coldigom/data/providers/coldigom_catalog_source_provider.dart` — injeta `lyrics` e `index`.

**Flutter — hidratação, índice, pesquisa local**
- Create `lib/features/coldigom/domain/search/coldigom_search_index.dart` — `ColdigomIndexedPraise`, `ColdigomSearchIndex` (`build`, `search`).
- Create `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart` — `coldigomCatalogHydrationProvider`, `coldigomSearchIndexProvider`, `coldigomCatalogSyncProvider`.
- Modify `lib/features/catalog/data/sources/composite_catalog_source.dart` — `searchLocal` concatena.
- Modify `lib/features/catalog/presentation/providers/home_search_provider.dart` — `homeLocalSearchProvider` concatena.
- Modify `lib/features/app_shell/presentation/shell_scaffold.dart` — `ref.watch` da hidratação e do sync no boot.
- Modify `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart` — sync no foreground (≥ 30 min).

**Flutter — leitor `/letra`**
- Modify `lib/core/routing/route_paths.dart` — `lyrics = '/letra'`.
- Modify `lib/core/routing/app_router.dart` — rota `letra` na branch Home.
- Modify `lib/core/utils/url_sync_params.dart` — `praiseId`.
- Modify `lib/features/app_shell/presentation/shell_scaffold.dart` — `/letra` em `_isImmersiveMediaRoute`.
- Create `lib/features/lyrics/domain/entities/lyrics_reader_font_size.dart`, `lib/features/lyrics/data/datasources/lyrics_reader_preferences_datasource.dart`, `lib/features/lyrics/presentation/providers/lyrics_reader_font_size_provider.dart`, `lib/features/lyrics/presentation/utils/lyrics_reader_url_builder.dart`, `lib/features/lyrics/presentation/pages/lyrics_reader_screen.dart`.
- Modify `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` — `lyricsTitle`, `lyricsTab`, `lyricsReaderEmpty`, `lyricsReaderIncreaseFont`, `lyricsReaderDecreaseFont`.

**Docs**
- Modify `docs/use-cases/UC-01-search-louvor-home.md`, `docs/use-cases/UC-09-configure-offline.md`, `docs/use-cases/UC-10-offline-maintenance.md`, `docs/features/FEATURE_INDEX.md`, `workers/plpcg-catalog/README.md`.

---

### Task 1: Patch do coldigom-api — `GET /api/plpcg/catalog`

**Files:**
- Create: `patches/coldigom-api-plpcg-catalog.patch`

**Interfaces:**
- Produces (contrato HTTP consumido pela Task 2/3):
  - `GET /api/plpcg/catalog` → `200` JSON `{ generatedAt, kinds: [{id,name}], praises: [{id, number, name, author, rhythm, tonality, category, tags: string[], lyrics?: string, materials: [{id, kind: string|null, type, size?: number, url?: string, r2?: string}]}] }`, cabeçalhos `ETag: "<32 hex>"` e `Cache-Control: public, max-age=300`.
  - `GET /api/plpcg/catalog` com `If-None-Match` igual ao `ETag` → `304` sem corpo (mesmos cabeçalhos).
  - `500 {"error": "Failed to build catalog"}` em falha de D1.
- Regras: ordenação estável `ORDER BY p.number, p.name`; `lyrics` omitida quando vazia/só espaços; `r2` só quando o `r2_key` real diverge do padrão derivado (teste de contrato O2); `size` não é emitido (a tabela `praise_materials` não tem tamanho — o app estima, O13); o ETag é o SHA-256 (32 hex) de `JSON.stringify({kinds, praises})` — **sem** `generatedAt`, senão mudaria a cada chamada.

- [ ] **Step 1: Ler o patch anterior para copiar o estilo**

Leia `patches/coldigom-api-plpcg-praises.patch` inteiro: mostra como o Worker é um app Hono (`app.get(path, async (c) => …)`), como o D1 é lido (`c.env.DB.prepare(query).bind(...).all()`), os helpers que já existem no `api/src/index.ts` do coldigom (`loadMaterialKindLabels(db)`, `labelFor(labels, kindId)`, tipo `PraiseResult` com `lyrics`), e como os testes vitest montam `mockDB`/`createMockR2()` e chamam `app.request(path, init, env)`. Os fixtures `mockPraises`, `mockMaterials`, `mockMaterialKindLabels` já existem em `api/src/__tests__/index.test.ts` do coldigom (o patch anterior os usa).

- [ ] **Step 2: Escrever o ficheiro de patch**

Crie `patches/coldigom-api-plpcg-catalog.patch` com o conteúdo abaixo. Os números das linhas dos hunks são os da árvore do coldigom **depois** de aplicado `coldigom-api-plpcg-praises.patch` (o handler `/api/praises/filters` fica em torno da linha 798 do `index.ts`; o `describe('GET /api/praises/filters'` em torno da 689 do teste). Se `git apply` recusar por contexto, o dono aplica com `git apply --3way` ou `patch -p1 --fuzz=3`; os dois blocos são auto-contidos.

```diff
diff --git a/api/src/__tests__/index.test.ts b/api/src/__tests__/index.test.ts
--- a/api/src/__tests__/index.test.ts
+++ b/api/src/__tests__/index.test.ts
@@ -686,6 +686,153 @@ describe('API Routes', () => {
     });
   });
 
+  describe('GET /api/plpcg/catalog', () => {
+    /** D1 falso: despacha pelo texto da query, sem `bind` (o dump não tem parâmetros). */
+    function catalogMockDB(options: {
+      praises?: unknown[];
+      materials?: unknown[];
+      tags?: unknown[];
+    } = {}) {
+      const results = (query: string) => {
+        if (query.includes('COALESCE(t.label')) return { results: mockMaterialKindLabels };
+        if (query.includes('FROM praise_materials')) return { results: options.materials ?? mockMaterials };
+        if (query.includes('FROM praise_tags')) return { results: options.tags ?? [] };
+        if (query.includes('FROM praises p')) return { results: options.praises ?? mockPraises };
+        return { results: [] };
+      };
+      return {
+        prepare: vi.fn((query: string) => ({
+          all: vi.fn(async () => results(query)),
+          bind: vi.fn((..._args: unknown[]) => ({
+            all: vi.fn(async () => results(query)),
+            first: vi.fn().mockResolvedValue(null),
+          })),
+        })),
+      };
+    }
+
+    it('returns compact praises with derived materials, tags and ETag', async () => {
+      const res = await app.request('/api/plpcg/catalog', {}, {
+        DB: catalogMockDB({
+          tags: [{ praise_id: mockPraises[0].id, name: 'PES' }],
+        }),
+        ASSETS: createMockR2(),
+      });
+
+      expect(res.status).toBe(200);
+      expect(res.headers.get('ETag')).toMatch(/^"[0-9a-f]{32}"$/);
+      expect(res.headers.get('Cache-Control')).toBe('public, max-age=300');
+      const json = await res.json();
+      expect(typeof json.generatedAt).toBe('string');
+      expect(json.kinds).toEqual(
+        expect.arrayContaining([expect.objectContaining({ id: expect.any(String), name: expect.any(String) })]),
+      );
+      const first = json.praises.find((p: { id: string }) => p.id === mockPraises[0].id);
+      expect(first).toBeDefined();
+      expect(first.name).toBe(mockPraises[0].name);
+      expect(first.tags).toEqual(['PES']);
+      expect(first.lyrics).toBe(mockPraises[0].lyrics);
+      // Materiais só com {id, kind, type}: o r2_key é derivado no app (O2).
+      const pdf = first.materials.find((m: { id: string }) => m.id === 'mat1');
+      expect(pdf).toEqual({ id: 'mat1', kind: mockMaterials[0].material_kind, type: 'pdf' });
+      expect(first.materials.every((m: { r2_key?: unknown }) => m.r2_key === undefined)).toBe(true);
+    });
+
+    it('omits lyrics when blank', async () => {
+      const res = await app.request('/api/plpcg/catalog', {}, {
+        DB: catalogMockDB({ praises: [{ ...mockPraises[0], lyrics: '   ' }] }),
+        ASSETS: createMockR2(),
+      });
+
+      const json = await res.json();
+      expect(json.praises[0].lyrics).toBeUndefined();
+    });
+
+    it('emits youtube with url and no r2', async () => {
+      const youtube = {
+        id: 'yt1',
+        praise_id: mockPraises[0].id,
+        type: 'youtube',
+        material_kind: null,
+        url: 'https://www.youtube.com/watch?v=abc',
+        r2_key: null,
+      };
+      const res = await app.request('/api/plpcg/catalog', {}, {
+        DB: catalogMockDB({ materials: [youtube] }),
+        ASSETS: createMockR2(),
+      });
+
+      const json = await res.json();
+      expect(json.praises[0].materials).toEqual([
+        { id: 'yt1', kind: null, type: 'youtube', url: 'https://www.youtube.com/watch?v=abc' },
+      ]);
+    });
+
+    it('emits explicit r2 only when the stored r2_key diverges from the derived pattern', async () => {
+      const praiseId = mockPraises[0].id;
+      const conforming = {
+        id: 'm-ok',
+        praise_id: praiseId,
+        type: 'pdf',
+        material_kind: 'k1',
+        url: null,
+        r2_key: `assets/praises/${praiseId}/m-ok.pdf`,
+      };
+      const divergent = {
+        id: 'm-odd',
+        praise_id: praiseId,
+        type: 'audio',
+        material_kind: 'k2',
+        url: null,
+        r2_key: `assets/praises/${praiseId}/m-odd.m4a`,
+      };
+      const res = await app.request('/api/plpcg/catalog', {}, {
+        DB: catalogMockDB({ materials: [conforming, divergent] }),
+        ASSETS: createMockR2(),
+      });
+
+      const json = await res.json();
+      const materials = json.praises[0].materials;
+      expect(materials.find((m: { id: string }) => m.id === 'm-ok').r2).toBeUndefined();
+      expect(materials.find((m: { id: string }) => m.id === 'm-odd').r2).toBe(
+        `assets/praises/${praiseId}/m-odd.m4a`,
+      );
+    });
+
+    it('answers 304 without body when If-None-Match matches', async () => {
+      const env = { DB: catalogMockDB(), ASSETS: createMockR2() };
+      const first = await app.request('/api/plpcg/catalog', {}, env);
+      const etag = first.headers.get('ETag')!;
+
+      const second = await app.request(
+        '/api/plpcg/catalog',
+        { headers: { 'If-None-Match': etag } },
+        env,
+      );
+
+      expect(second.status).toBe(304);
+      expect(second.headers.get('ETag')).toBe(etag);
+      expect(await second.text()).toBe('');
+    });
+
+    it('returns 500 on database error', async () => {
+      const mockDB = {
+        prepare: vi.fn().mockReturnValue({
+          all: vi.fn().mockRejectedValue(new Error('DB Error')),
+          bind: vi.fn().mockReturnValue({
+            all: vi.fn().mockRejectedValue(new Error('DB Error')),
+            first: vi.fn().mockRejectedValue(new Error('DB Error')),
+          }),
+        }),
+      };
+
+      const res = await app.request('/api/plpcg/catalog', {}, {
+        DB: mockDB,
+        ASSETS: createMockR2(),
+      });
+
+      expect(res.status).toBe(500);
+      const json = await res.json();
+      expect(json.error).toBe('Failed to build catalog');
+    });
+  });
+
   describe('GET /api/praises/filters', () => {
     it('should return filter options', async () => {
       const mockDB = {
diff --git a/api/src/index.ts b/api/src/index.ts
--- a/api/src/index.ts
+++ b/api/src/index.ts
@@ -795,6 +795,163 @@ app.get('/api/plpcg/praises', async (c) => {
   return c.json({ error: 'Failed to fetch praises' }, 500);
 });
 
+type CatalogPraiseRow = {
+  id: string;
+  name: string;
+  number: string;
+  author: string | null;
+  rhythm: string | null;
+  tonality: string | null;
+  category: string | null;
+  lyrics: string | null;
+};
+
+type CatalogMaterialRow = {
+  id: string;
+  praise_id: string;
+  type: string;
+  material_kind: string | null;
+  url: string | null;
+  r2_key: string | null;
+};
+
+type CatalogTagRow = { praise_id: string; name: string };
+
+type PlpcgCatalogMaterial = {
+  id: string;
+  kind: string | null;
+  type: string;
+  url?: string;
+  r2?: string;
+};
+
+/** Extensão do objeto no R2 por `type` — o mesmo mapa que o app usa para derivar o r2_key (O2). */
+const CATALOG_EXT_BY_TYPE: Record<string, string> = {
+  pdf: 'pdf',
+  mp3: 'mp3',
+  audio: 'mp3',
+  chord: 'chord',
+  gestures: 'gestures',
+};
+
+/** r2_key que o app vai reconstruir para este material; `null` quando o tipo não vive no R2 (youtube). */
+export function derivedCatalogR2Key(praiseId: string, materialId: string, type: string): string | null {
+  const ext = CATALOG_EXT_BY_TYPE[type.toLowerCase()];
+  return ext ? `assets/praises/${praiseId}/${materialId}.${ext}` : null;
+}
+
+async function sha256Hex32(text: string): Promise<string> {
+  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
+  return [...new Uint8Array(digest)]
+    .map((b) => b.toString(16).padStart(2, '0'))
+    .join('')
+    .slice(0, 32);
+}
+
+/**
+ * GET /api/plpcg/catalog — dump compacto do catálogo inteiro para o app PLPCG.
+ *
+ * O app guarda tudo em Isar e revalida por ETag: `If-None-Match` igual → 304
+ * sem corpo. O ETag é o hash de `{kinds, praises}` (sem `generatedAt`, que
+ * mudaria a cada chamada). Materiais vão só como `{id, kind, type}` — o
+ * `r2_key` segue `assets/praises/<praiseId>/<materialId>.<ext>` e o app o
+ * reconstrói; quando o `r2_key` gravado foge do padrão, vai em `r2` explícito
+ * para o app não apontar para um objeto inexistente. Sem `size`: a tabela não
+ * tem o tamanho e um HEAD por objeto no R2 é caro demais para um dump.
+ */
+app.get('/api/plpcg/catalog', async (c) => {
+  try {
+    const praisesResult = await c.env.DB.prepare(
+      `SELECT p.id, p.name, p.number, p.author, p.rhythm, p.tonality, p.category, p.lyrics
+       FROM praises p
+       ORDER BY p.number, p.name`,
+    ).all();
+    const materialsResult = await c.env.DB.prepare(
+      `SELECT pm.id, pm.praise_id, pm.type, pm.material_kind, pm.url, pm.r2_key
+       FROM praise_materials pm`,
+    ).all();
+    const tagsResult = await c.env.DB.prepare(
+      `SELECT pt.praise_id, t.name
+       FROM praise_tags pt
+       JOIN tags t ON t.id = pt.tag_id
+       ORDER BY t.name`,
+    ).all();
+    const kindLabels = await loadMaterialKindLabels(c.env.DB);
+
+    const materialsByPraise = new Map<string, PlpcgCatalogMaterial[]>();
+    const kindIds = new Set<string>();
+    for (const row of (materialsResult.results ?? []) as CatalogMaterialRow[]) {
+      const material: PlpcgCatalogMaterial = {
+        id: row.id,
+        kind: row.material_kind ?? null,
+        type: row.type,
+      };
+      if (row.material_kind) kindIds.add(row.material_kind);
+      if (row.url) material.url = row.url;
+      const derived = derivedCatalogR2Key(row.praise_id, row.id, row.type);
+      if (row.r2_key && derived !== null && row.r2_key !== derived) {
+        material.r2 = row.r2_key;
+      }
+      const list = materialsByPraise.get(row.praise_id) ?? [];
+      list.push(material);
+      materialsByPraise.set(row.praise_id, list);
+    }
+
+    const tagsByPraise = new Map<string, string[]>();
+    for (const row of (tagsResult.results ?? []) as CatalogTagRow[]) {
+      const list = tagsByPraise.get(row.praise_id) ?? [];
+      list.push(row.name);
+      tagsByPraise.set(row.praise_id, list);
+    }
+
+    const kinds = [...kindIds]
+      .map((id) => ({ id, name: labelFor(kindLabels, id) }))
+      .sort((a, b) => a.name.localeCompare(b.name));
+
+    const praises = ((praisesResult.results ?? []) as CatalogPraiseRow[]).map((row) => {
+      const praise: Record<string, unknown> = {
+        id: row.id,
+        number: row.number ?? '',
+        name: row.name,
+        author: row.author ?? '',
+        rhythm: row.rhythm ?? '',
+        tonality: row.tonality ?? '',
+        category: row.category ?? '',
+        tags: tagsByPraise.get(row.id) ?? [],
+      };
+      if (typeof row.lyrics === 'string' && row.lyrics.trim().length > 0) {
+        praise.lyrics = row.lyrics;
+      }
+      praise.materials = materialsByPraise.get(row.id) ?? [];
+      return praise;
+    });
+
+    const etag = `"${await sha256Hex32(JSON.stringify({ kinds, praises }))}"`;
+    const headers = {
+      ETag: etag,
+      'Cache-Control': 'public, max-age=300',
+    };
+    if (c.req.header('If-None-Match') === etag) {
+      return new Response(null, { status: 304, headers });
+    }
+
+    const body = JSON.stringify({
+      generatedAt: new Date().toISOString(),
+      kinds,
+      praises,
+    });
+    return new Response(body, {
+      status: 200,
+      headers: { ...headers, 'Content-Type': 'application/json; charset=utf-8' },
+    });
+  } catch (error) {
+    console.error('Error building PLPCG catalog:', error);
+    return c.json({ error: 'Failed to build catalog' }, 500);
+  }
+});
+
 // GET /api/praises/filters - Get filter options
 app.get('/api/praises/filters', async (c) => {
   try {
```

- [ ] **Step 3: Verificações do dono ao aplicar (documentar no topo do patch como comentário não faz parte do diff — vai no commit e no README)**

Passo do dono (fora deste repo), a fazer **antes** de publicar a web com a Parte 1:
1. No repo do coldigom: `git apply --3way patches/coldigom-api-plpcg-catalog.patch` (ou `patch -p1 --fuzz=3 < …`).
2. Confirmar os nomes das tabelas de tags: `grep -n "tag_names" api/src/index.ts` mostra o JOIN que `GET /api/praises` usa para montar `tag_names`; se as tabelas não se chamarem `praise_tags`/`tags` ou as colunas `tag_id`/`name`, ajustar a query de `tagsResult` no handler novo para o mesmo JOIN.
3. `cd api && npm test` (vitest) — os sete testes novos verdes.
4. `npm run deploy`.
5. Validar em produção: `curl -sI https://coldigom-api.jairofilho79.workers.dev/api/plpcg/catalog | grep -i etag`, depois `curl -s -o /dev/null -w '%{http_code}' -H 'If-None-Match: <etag>' …/api/plpcg/catalog` → `304`.
6. Confirmar o conjunto real de valores de `praise_materials.type` no D1; qualquer valor fora de `{pdf, mp3, audio, chord, gestures, youtube}` chega ao app com `r2` explícito (fix round 1 — a rota não confia mais silenciosamente no padrão derivado para tipos desconhecidos).
7. Confirmar que o `cors()` global do coldigom-api aceita `If-None-Match` em `allowHeaders` (preflight) — verificar no DevTools em produção com `GET /api/gestures/dictionary`.

- [ ] **Step 4: Commit**

```bash
git add patches/coldigom-api-plpcg-catalog.patch
git commit -m "feat(coldigom): patch do coldigom-api — GET /api/plpcg/catalog (dump compacto + ETag/304)

Endpoint novo para o catálogo local (O1/O2): praises com metadados, tags,
letra e materiais {id,kind,type}; r2 explícito só quando o r2_key gravado
foge do padrão derivado. Deploy é passo do dono.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 2: `ColdigomCatalogDto` + fixture

**Files:**
- Create: `test/fixtures/coldigom_catalog_sample.json`
- Create: `lib/features/coldigom/data/models/coldigom_catalog_dto.dart`
- Test: `test/unit/features/coldigom/coldigom_catalog_dto_test.dart`

**Interfaces:**
- Produces:
  - `String? coldigomCatalogExtensionForType(String type)` — `pdf→'pdf'`, `mp3|audio→'mp3'`, `chord→'chord'`, `gestures→'gestures'`, resto `null`.
  - `class ColdigomCatalogMaterialDto { String id; String? kindId; String type; int? size; String? url; String? r2Key; }` — `r2Key` = `r2` explícito, senão derivado, senão `null`.
  - `class ColdigomCatalogPraiseDto { String id, number, name, author, rhythm, tonality, category; List<String> tags; String lyrics; List<ColdigomCatalogMaterialDto> materials; }`.
  - `class ColdigomCatalogDto { String generatedAt; Map<String, String> kindNames; List<ColdigomCatalogPraiseDto> praises; factory fromJson(Map<String, dynamic>); }`.

- [ ] **Step 1: Fixture JSON**

`test/fixtures/coldigom_catalog_sample.json`:

```json
{
  "generatedAt": "2026-09-14T12:00:00.000Z",
  "kinds": [
    { "id": "k-grade", "name": "Grade" },
    { "id": "k-playback", "name": "Playback" },
    { "id": "k-cifra", "name": "Cifra" },
    { "id": "k-gestos", "name": "Gestos" }
  ],
  "praises": [
    {
      "id": "p-001",
      "number": "001",
      "name": "Ainda há tempo",
      "author": "",
      "rhythm": "Básico",
      "tonality": "Dm",
      "category": "Dm",
      "tags": ["Avulsos", "PES"],
      "lyrics": "Ainda há tempo\nde voltar ao Senhor",
      "materials": [
        { "id": "m-pdf", "kind": "k-grade", "type": "pdf", "size": 312345 },
        { "id": "m-mp3", "kind": "k-playback", "type": "mp3" },
        { "id": "m-chord", "kind": "k-cifra", "type": "chord" },
        { "id": "m-gest", "kind": "k-gestos", "type": "gestures" },
        { "id": "yt-1", "kind": null, "type": "youtube", "url": "https://www.youtube.com/watch?v=1Pks43ceAac" }
      ]
    },
    {
      "id": "p-002",
      "number": "002",
      "name": "São João",
      "author": "Autor Dois",
      "rhythm": "Fox",
      "tonality": "G",
      "category": "G",
      "tags": [],
      "materials": [
        { "id": "m-odd", "kind": "k-playback", "type": "audio", "r2": "assets/praises/p-002/m-odd.m4a" }
      ]
    },
    {
      "id": "p-003",
      "number": "",
      "name": "Sem número",
      "author": "",
      "rhythm": "",
      "tonality": "",
      "category": "",
      "tags": ["Coro"],
      "materials": []
    }
  ]
}
```

- [ ] **Step 2: Teste que falha**

`test/unit/features/coldigom/coldigom_catalog_dto_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() => jsonDecode(
  File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test('parseia kinds e praises do dump', () {
    final dto = ColdigomCatalogDto.fromJson(_fixture());

    expect(dto.generatedAt, '2026-09-14T12:00:00.000Z');
    expect(dto.kindNames, {
      'k-grade': 'Grade',
      'k-playback': 'Playback',
      'k-cifra': 'Cifra',
      'k-gestos': 'Gestos',
    });
    expect(dto.praises, hasLength(3));
    final first = dto.praises.first;
    expect(first.id, 'p-001');
    expect(first.number, '001');
    expect(first.name, 'Ainda há tempo');
    expect(first.tags, ['Avulsos', 'PES']);
    expect(first.lyrics, 'Ainda há tempo\nde voltar ao Senhor');
  });

  test('r2Key derivado por tipo: assets/praises/<praiseId>/<materialId>.<ext>', () {
    final materials = ColdigomCatalogDto.fromJson(_fixture()).praises.first.materials;
    final byId = {for (final m in materials) m.id: m};

    expect(byId['m-pdf']!.r2Key, 'assets/praises/p-001/m-pdf.pdf');
    expect(byId['m-mp3']!.r2Key, 'assets/praises/p-001/m-mp3.mp3');
    expect(byId['m-chord']!.r2Key, 'assets/praises/p-001/m-chord.chord');
    expect(byId['m-gest']!.r2Key, 'assets/praises/p-001/m-gest.gestures');
    expect(byId['m-pdf']!.kindId, 'k-grade');
    expect(byId['m-pdf']!.size, 312345);
    expect(byId['m-mp3']!.size, isNull);
  });

  test('youtube usa url e não tem r2Key', () {
    final yt = ColdigomCatalogDto.fromJson(_fixture()).praises.first.materials.last;

    expect(yt.type, 'youtube');
    expect(yt.kindId, isNull);
    expect(yt.url, 'https://www.youtube.com/watch?v=1Pks43ceAac');
    expect(yt.r2Key, isNull);
  });

  test('r2 explícito tem precedência sobre o derivado', () {
    final odd = ColdigomCatalogDto.fromJson(_fixture()).praises[1].materials.single;

    expect(odd.type, 'audio');
    expect(odd.r2Key, 'assets/praises/p-002/m-odd.m4a');
  });

  test('lyrics ausente vira string vazia; campos ausentes viram vazios', () {
    final praises = ColdigomCatalogDto.fromJson(_fixture()).praises;

    expect(praises[1].lyrics, '');
    expect(praises[2].number, '');
    expect(praises[2].materials, isEmpty);
    expect(praises[2].tags, ['Coro']);
  });

  test('material corrompido é descartado sem derrubar o praise', () {
    final json = _fixture();
    final praise = (json['praises'] as List).first as Map<String, dynamic>;
    (praise['materials'] as List).add('não é um mapa');

    final dto = ColdigomCatalogDto.fromJson(json);

    expect(dto.praises.first.materials, hasLength(5));
  });

  test('coldigomCatalogExtensionForType cobre os quatro tipos baixáveis', () {
    expect(coldigomCatalogExtensionForType('pdf'), 'pdf');
    expect(coldigomCatalogExtensionForType('MP3'), 'mp3');
    expect(coldigomCatalogExtensionForType('audio'), 'mp3');
    expect(coldigomCatalogExtensionForType('chord'), 'chord');
    expect(coldigomCatalogExtensionForType('gestures'), 'gestures');
    expect(coldigomCatalogExtensionForType('youtube'), isNull);
    expect(coldigomCatalogExtensionForType('lyrics'), isNull);
  });
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_catalog_dto_test.dart` → falha (ficheiro `coldigom_catalog_dto.dart` não existe).

- [ ] **Step 3: Implementar o DTO**

`lib/features/coldigom/data/models/coldigom_catalog_dto.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Extensão do objeto no R2 por `type` do Worker — a outra metade da regra
/// O2: o dump só manda `{id, kind, type}` e o app reconstrói o `r2_key`.
///
/// `null` para tipos que não vivem no R2 (`youtube`, `lyrics`) ou
/// desconhecidos. Mantenha em sincronia com `CATALOG_EXT_BY_TYPE` do patch
/// `patches/coldigom-api-plpcg-catalog.patch`.
String? coldigomCatalogExtensionForType(String type) {
  return switch (type.toLowerCase()) {
    'pdf' => 'pdf',
    'mp3' || 'audio' => 'mp3',
    'chord' => 'chord',
    'gestures' => 'gestures',
    _ => null,
  };
}

/// Material de um praise no dump `GET /api/plpcg/catalog`.
class ColdigomCatalogMaterialDto {
  const ColdigomCatalogMaterialDto({
    required this.id,
    required this.type,
    required this.r2Key,
    this.kindId,
    this.size,
    this.url,
  });

  final String id;

  /// Id do `material_kind`; `null` em YouTube.
  final String? kindId;

  /// `pdf`/`mp3`/`audio`/`chord`/`gestures`/`youtube`.
  final String type;

  /// Tamanho em bytes quando o Worker o conhece (O13); senão `null` e o app
  /// estima por tipo.
  final int? size;

  /// URL externa (YouTube).
  final String? url;

  /// `r2` explícito do dump quando presente, senão o derivado por [type];
  /// `null` quando o material não vive no R2.
  final String? r2Key;

  /// [praiseId] entra aqui (e não no JSON) porque o `r2_key` é derivado.
  factory ColdigomCatalogMaterialDto.fromJson(
    Map<String, dynamic> json, {
    required String praiseId,
  }) {
    final id = json['id'] as String? ?? '';
    final type = json['type'] is String ? json['type'] as String : 'unknown';
    final explicit = json['r2'] is String ? (json['r2'] as String).trim() : '';
    final ext = coldigomCatalogExtensionForType(type);
    final String? r2Key;
    if (explicit.isNotEmpty) {
      r2Key = explicit;
    } else if (ext != null && id.isNotEmpty) {
      r2Key = 'assets/praises/$praiseId/$id.$ext';
    } else {
      r2Key = null;
    }
    return ColdigomCatalogMaterialDto(
      id: id,
      kindId: json['kind'] is String ? json['kind'] as String : null,
      type: type,
      size: (json['size'] as num?)?.toInt(),
      url: json['url'] as String?,
      r2Key: r2Key,
    );
  }
}

/// Um louvor no dump — metadados, tags, letra e materiais.
class ColdigomCatalogPraiseDto {
  const ColdigomCatalogPraiseDto({
    required this.id,
    required this.number,
    required this.name,
    required this.author,
    required this.rhythm,
    required this.tonality,
    required this.category,
    required this.tags,
    required this.lyrics,
    required this.materials,
  });

  final String id;
  final String number;
  final String name;
  final String author;
  final String rhythm;
  final String tonality;
  final String category;
  final List<String> tags;

  /// `''` quando o dump omite (letra vazia).
  final String lyrics;
  final List<ColdigomCatalogMaterialDto> materials;

  factory ColdigomCatalogPraiseDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return ColdigomCatalogPraiseDto(
      id: id,
      number: json['number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      rhythm: json['rhythm'] as String? ?? '',
      tonality: json['tonality'] as String? ?? '',
      category: json['category'] as String? ?? '',
      tags: [
        for (final tag in json['tags'] as List<dynamic>? ?? const [])
          if (tag is String && tag.trim().isNotEmpty) tag.trim(),
      ],
      lyrics: json['lyrics'] as String? ?? '',
      materials: _parseMaterials(
        json['materials'] as List<dynamic>? ?? const [],
        praiseId: id,
      ),
    );
  }

  /// Um material corrompido não derruba o louvor (mesma regra C.8 de
  /// `PraiseDetailDto._parseMaterials`).
  static List<ColdigomCatalogMaterialDto> _parseMaterials(
    List<dynamic> raw, {
    required String praiseId,
  }) {
    final materials = <ColdigomCatalogMaterialDto>[];
    for (final item in raw) {
      try {
        materials.add(
          ColdigomCatalogMaterialDto.fromJson(
            item as Map<String, dynamic>,
            praiseId: praiseId,
          ),
        );
      } on Object catch (error) {
        debugPrint('[coldigom] material do catálogo descartado: $error');
      }
    }
    return materials;
  }
}

/// Corpo de `GET /api/plpcg/catalog`.
class ColdigomCatalogDto {
  const ColdigomCatalogDto({
    required this.generatedAt,
    required this.kindNames,
    required this.praises,
  });

  final String generatedAt;

  /// `kindId → nome` — o rótulo das tiles do sheet (`materialKindName`).
  final Map<String, String> kindNames;
  final List<ColdigomCatalogPraiseDto> praises;

  factory ColdigomCatalogDto.fromJson(Map<String, dynamic> json) {
    final kinds = <String, String>{};
    for (final item in json['kinds'] as List<dynamic>? ?? const []) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final name = item['name'];
      if (id is String && name is String) kinds[id] = name;
    }
    final praises = <ColdigomCatalogPraiseDto>[];
    for (final item in json['praises'] as List<dynamic>? ?? const []) {
      try {
        praises.add(ColdigomCatalogPraiseDto.fromJson(item as Map<String, dynamic>));
      } on Object catch (error) {
        debugPrint('[coldigom] praise do catálogo descartado: $error');
      }
    }
    return ColdigomCatalogDto(
      generatedAt: json['generatedAt'] as String? ?? '',
      kindNames: Map.unmodifiable(kinds),
      praises: List.unmodifiable(praises),
    );
  }
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_catalog_dto_test.dart` → 7 testes verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib/features/coldigom/data/models/coldigom_catalog_dto.dart test/unit/features/coldigom/coldigom_catalog_dto_test.dart
flutter analyze
git add test/fixtures/coldigom_catalog_sample.json lib/features/coldigom/data/models/coldigom_catalog_dto.dart test/unit/features/coldigom/coldigom_catalog_dto_test.dart
git commit -m "feat(coldigom): ColdigomCatalogDto — parse do dump com r2Key derivado por tipo (O2)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 3: `ColdigomRemoteDatasource.fetchCatalog` com `If-None-Match`

**Files:**
- Modify: `lib/features/coldigom/data/constants/coldigom_endpoints.dart` (depois da linha 6, `plpcgPraises`)
- Modify: `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart` (imports no topo; método novo depois de `listPlpcgPraises`, ~linha 122)
- Test: `test/unit/features/coldigom/coldigom_remote_datasource_catalog_test.dart`

**Interfaces:**
- Consumes: `ColdigomCatalogDto.fromJson` (Task 2).
- Produces:
  - `ColdigomEndpoints.plpcgCatalog = '/api/plpcg/catalog'`.
  - `sealed class ColdigomCatalogFetchResult`; `final class ColdigomCatalogNotModified extends ColdigomCatalogFetchResult {}`; `final class ColdigomCatalogFresh extends ColdigomCatalogFetchResult { ColdigomCatalogDto catalog; String? etag; }`.
  - `Future<ColdigomCatalogFetchResult> ColdigomRemoteDatasource.fetchCatalog({String? ifNoneMatch})` — `304` → `ColdigomCatalogNotModified`; `200` → `ColdigomCatalogFresh`; `receiveTimeout` 60 s só neste pedido; falhas de rede propagam como `DioException`.

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/coldigom_remote_datasource_catalog_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/coldigom/data/constants/coldigom_endpoints.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter fixo: devolve [statusCode] + [body] e guarda a última request.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body, {this.etag});

  final int statusCode;
  final String body;
  final String? etag;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (etag != null) 'etag': [etag!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _fixture() =>
    File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync();

void main() {
  test('200 devolve ColdigomCatalogFresh com catálogo e etag', () async {
    final adapter = _FixedAdapter(200, _fixture(), etag: '"abc123"');
    final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
      ..httpClientAdapter = adapter;
    final datasource = ColdigomRemoteDatasource(dio);

    final result = await datasource.fetchCatalog();

    expect(result, isA<ColdigomCatalogFresh>());
    final fresh = result as ColdigomCatalogFresh;
    expect(fresh.etag, '"abc123"');
    expect(fresh.catalog.praises, hasLength(3));
    expect(adapter.lastRequest!.path, ColdigomEndpoints.plpcgCatalog);
    expect(adapter.lastRequest!.receiveTimeout, const Duration(seconds: 60));
    expect(adapter.lastRequest!.headers.containsKey('If-None-Match'), isFalse);
  });

  test('manda If-None-Match e trata 304 como não modificado', () async {
    final adapter = _FixedAdapter(304, '', etag: '"abc123"');
    final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
      ..httpClientAdapter = adapter;
    final datasource = ColdigomRemoteDatasource(dio);

    final result = await datasource.fetchCatalog(ifNoneMatch: '"abc123"');

    expect(result, isA<ColdigomCatalogNotModified>());
    expect(adapter.lastRequest!.headers['If-None-Match'], '"abc123"');
  });

  test('erro HTTP propaga como DioException', () async {
    final adapter = _FixedAdapter(500, jsonEncode({'error': 'x'}));
    final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
      ..httpClientAdapter = adapter;
    final datasource = ColdigomRemoteDatasource(dio);

    expect(datasource.fetchCatalog(), throwsA(isA<DioException>()));
  });
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_remote_datasource_catalog_test.dart` → falha de compilação (`fetchCatalog` não existe).

- [ ] **Step 2: Endpoint**

Em `lib/features/coldigom/data/constants/coldigom_endpoints.dart`, depois de `static const plpcgPraises = '/api/plpcg/praises';`:

```dart
  /// Dump compacto do catálogo inteiro para o Isar local (ETag + 304).
  static const plpcgCatalog = '/api/plpcg/catalog';
```

- [ ] **Step 3: Datasource**

Em `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart`, adicionar o import `import '../models/coldigom_catalog_dto.dart';` junto aos outros, e **antes** de `class ColdigomRemoteDatasource`:

```dart
/// Resultado de [ColdigomRemoteDatasource.fetchCatalog].
///
/// `sealed` para o use case de sync ter de tratar os dois desfechos —
/// «não mudou» não é erro, é a resposta mais comum.
sealed class ColdigomCatalogFetchResult {
  const ColdigomCatalogFetchResult();
}

/// `304` — o ETag local ainda é o do servidor; nada a gravar.
final class ColdigomCatalogNotModified extends ColdigomCatalogFetchResult {
  const ColdigomCatalogNotModified();
}

/// `200` — catálogo novo e o ETag que o acompanha (para o próximo pedido).
final class ColdigomCatalogFresh extends ColdigomCatalogFetchResult {
  const ColdigomCatalogFresh({required this.catalog, required this.etag});

  final ColdigomCatalogDto catalog;
  final String? etag;
}
```

E dentro da classe, depois de `listPlpcgPraises`:

```dart
  /// Dump do catálogo (`GET /api/plpcg/catalog`) com revalidação por ETag.
  ///
  /// [ifNoneMatch] é o ETag guardado do último sync; o Worker responde `304`
  /// sem corpo quando nada mudou. O `receiveTimeout` sobe para 60 s só aqui:
  /// o corpo tem ~2,5 MB (gzip ~500 KB) e o padrão de 30 s do
  /// `coldigomDioProvider` foi pensado para páginas de 20 itens.
  Future<ColdigomCatalogFetchResult> fetchCatalog({
    String? ifNoneMatch,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.plpcgCatalog,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        headers: {if (ifNoneMatch != null) 'If-None-Match': ifNoneMatch},
        // 304 não é erro: sem isto o Dio lança `DioException.badResponse`.
        validateStatus: (status) => status == 200 || status == 304,
      ),
    );

    if (response.statusCode == 304) return const ColdigomCatalogNotModified();

    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Resposta vazia do catálogo coldigom',
      );
    }
    return ColdigomCatalogFresh(
      catalog: ColdigomCatalogDto.fromJson(data),
      etag: response.headers.value('etag'),
    );
  }
```

Correr: `flutter test test/unit/features/coldigom/coldigom_remote_datasource_catalog_test.dart` → 3 verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib/features/coldigom/data/constants/coldigom_endpoints.dart lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart test/unit/features/coldigom/coldigom_remote_datasource_catalog_test.dart
flutter analyze
git add -A lib/features/coldigom/data test/unit/features/coldigom/coldigom_remote_datasource_catalog_test.dart
git commit -m "feat(coldigom): fetchCatalog com If-None-Match/304 e receiveTimeout de 60 s

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 4: Collection `ColdigomPraiseCache` + `ColdigomCatalogLocalDatasource`

**Files:**
- Create: `lib/core/database/collections/coldigom_praise_cache.dart` (+ `coldigom_praise_cache.g.dart` gerado)
- Modify: `lib/core/database/isar_app_schemas.dart` (import + entrada na lista, linhas 1–25)
- Modify: `lib/core/constants/storage_keys.dart` (fim da classe, depois de `audioLastPosition`)
- Create: `lib/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart`
- Test: `test/unit/features/coldigom/coldigom_catalog_local_datasource_test.dart`

**Interfaces:**
- Produces:
  - `@Collection() class ColdigomPraiseCache { int id; @Index(unique: true) String praiseId; String number, name, author, rhythm, tonality, category; List<String> tags; String lyrics; String materialsJson; String searchTokens; }`
  - `StorageKeys.coldigomCatalogEtag`, `StorageKeys.coldigomCatalogSyncedAt`, `StorageKeys.coldigomCatalogCount`, `StorageKeys.lyricsReaderFontSize`.
  - `class ColdigomCatalogLocalDatasource { const ColdigomCatalogLocalDatasource(Isar? isar); const .unavailable(); bool get isAvailable; Future<void> replaceAll(List<ColdigomPraiseCache>); Future<void> upsertMany(List<ColdigomPraiseCache>); List<ColdigomPraiseCache> findAllSync(); ColdigomPraiseCache? findByPraiseIdSync(String); int count(); }` — escritas sem Isar lançam `StorageUnavailableException('coldigom_catalog.<op>')`.

- [ ] **Step 1: Collection e schema**

`lib/core/database/collections/coldigom_praise_cache.dart`:

```dart
import 'package:isar_plus/isar_plus.dart';

part 'coldigom_praise_cache.g.dart';

/// Cache local Isar do catálogo Coldigom (~1690 louvores) — spec offline
/// Coldigom §4.1 (O3).
///
/// Uma linha por praise; os materiais vão serializados em JSON na própria
/// linha ([materialsJson]) porque são lidos sempre em bloco (hidratação no
/// boot, enumeração do download) e nunca um a um. Substituição total por
/// sync numa transação, como [LouvorCache].
@Collection()
class ColdigomPraiseCache {
  int id = 0;

  /// `praise.id` do Worker — também o `groupId` das entidades Coldigom.
  @Index(unique: true)
  late String praiseId;

  /// Número como o Worker manda (`'001'`); pode ser vazio.
  late String number;

  late String name;
  late String author;
  late String rhythm;
  late String tonality;
  late String category;

  /// Nomes das tags (`tag_names`), sem ids.
  late List<String> tags;

  /// Letra; `''` quando não há (o dump omite o campo).
  late String lyrics;

  /// JSON array de `{id, kind, kindName, type, r2, size?, url?}` — ver
  /// `ColdigomPraiseCacheMapper`.
  late String materialsJson;

  /// Tokens normalizados (nome + número + tags + autor) separados por
  /// espaço — insumo do `ColdigomSearchIndex`, calculado uma vez no sync.
  late String searchTokens;
}
```

Em `lib/core/database/isar_app_schemas.dart`: adicionar `import 'collections/coldigom_praise_cache.dart';` (ordem alfabética, depois de `chord_content_cache.dart`) e `ColdigomPraiseCacheSchema,` no fim da lista `kAppIsarSchemas`.

Correr: `dart run build_runner build --delete-conflicting-outputs` → gera `coldigom_praise_cache.g.dart`.

- [ ] **Step 2: StorageKeys**

Em `lib/core/constants/storage_keys.dart`, antes do `}` final:

```dart
  /// ETag do último dump `GET /api/plpcg/catalog` gravado no Isar.
  static const String coldigomCatalogEtag = 'coldigomCatalogEtag';

  /// Timestamp ISO-8601 do último sync do catálogo Coldigom (200 ou 304).
  static const String coldigomCatalogSyncedAt = 'coldigomCatalogSyncedAt';

  /// Quantos praises o último sync gravou — linha de estado do `/offline`.
  static const String coldigomCatalogCount = 'coldigomCatalogCount';

  /// Corpo da letra no leitor de letras `/letra` (`double`).
  static const String lyricsReaderFontSize = 'lyricsReaderFontSize';
```

- [ ] **Step 3: Teste que falha**

`test/unit/features/coldigom/coldigom_catalog_local_datasource_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

ColdigomPraiseCache _row(String praiseId, {String number = '001'}) =>
    ColdigomPraiseCache()
      ..praiseId = praiseId
      ..number = number
      ..name = 'Louvor $praiseId'
      ..author = ''
      ..rhythm = ''
      ..tonality = ''
      ..category = ''
      ..tags = const []
      ..lyrics = ''
      ..materialsJson = '[]'
      ..searchTokens = 'louvor $praiseId';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ColdigomCatalogLocalDatasource datasource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('coldigom_catalog_');
    isar = Isar.open(
      schemas: [ColdigomPraiseCacheSchema],
      directory: tempDir.path,
      name: 'coldigom_catalog_${DateTime.now().microsecondsSinceEpoch}',
    );
    datasource = ColdigomCatalogLocalDatasource(isar);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('replaceAll substitui o catálogo inteiro numa transação', () async {
    await datasource.replaceAll([_row('p1'), _row('p2', number: '002')]);
    expect(datasource.count(), 2);

    await datasource.replaceAll([_row('p3', number: '003')]);

    expect(datasource.count(), 1);
    expect(datasource.findAllSync().single.praiseId, 'p3');
  });

  test('upsertMany insere novos e substitui existentes por praiseId', () async {
    await datasource.replaceAll([_row('p1')]);

    await datasource.upsertMany([
      _row('p1')..name = 'Renomeado',
      _row('p9', number: '009'),
    ]);

    expect(datasource.count(), 2);
    expect(datasource.findByPraiseIdSync('p1')!.name, 'Renomeado');
    expect(datasource.findByPraiseIdSync('p9')!.number, '009');
    expect(datasource.findByPraiseIdSync('nope'), isNull);
  });

  test('sem Isar: leituras vazias, escritas lançam StorageUnavailableException', () async {
    const degraded = ColdigomCatalogLocalDatasource.unavailable();

    expect(degraded.isAvailable, isFalse);
    expect(degraded.findAllSync(), isEmpty);
    expect(degraded.findByPraiseIdSync('p1'), isNull);
    expect(degraded.count(), 0);
    await expectLater(
      degraded.replaceAll([_row('p1')]),
      throwsA(isA<StorageUnavailableException>()),
    );
    await expectLater(
      degraded.upsertMany([_row('p1')]),
      throwsA(isA<StorageUnavailableException>()),
    );
  });
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_catalog_local_datasource_test.dart` → falha (datasource não existe).

- [ ] **Step 4: Datasource**

`lib/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart`:

```dart
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/database/storage_unavailable_exception.dart';

/// CRUD Isar de [ColdigomPraiseCache] — o catálogo Coldigom local (O3).
///
/// Em modo degradado (`_isar == null`) as **leituras** devolvem vazio e as
/// **escritas** lançam [StorageUnavailableException] — nunca fingem sucesso
/// (mesma regra de `OfflinePdfLocalDatasource`). Dois escritores passam por
/// aqui: o sync total ([replaceAll], vence sempre) e a adoção dos «novos» da
/// pesquisa ([upsertMany]).
class ColdigomCatalogLocalDatasource {
  const ColdigomCatalogLocalDatasource(this._isar);

  const ColdigomCatalogLocalDatasource.unavailable() : _isar = null;

  final Isar? _isar;

  bool get isAvailable => _isar != null;

  /// Substitui o catálogo inteiro (clear + put) numa transação.
  Future<void> replaceAll(List<ColdigomPraiseCache> rows) async {
    final isar = _requireIsar('replaceAll');
    await isar.write((isar) {
      final coll = isar.coldigomPraiseCaches;
      coll.clear();
      for (final row in rows) {
        if (row.id == 0) row.id = coll.autoIncrement();
        coll.put(row);
      }
    });
  }

  /// Upsert por `praiseId` — os louvores que a pesquisa remota trouxe e o
  /// catálogo local ainda não tinha (§6).
  Future<void> upsertMany(List<ColdigomPraiseCache> rows) async {
    if (rows.isEmpty) return;
    final isar = _requireIsar('upsertMany');
    await isar.write((isar) {
      final coll = isar.coldigomPraiseCaches;
      for (final row in rows) {
        final existing = coll
            .where()
            .praiseIdEqualTo(row.praiseId)
            .findFirst();
        if (existing != null) {
          row.id = existing.id;
        } else if (row.id == 0) {
          row.id = coll.autoIncrement();
        }
        coll.put(row);
      }
    });
  }

  /// Catálogo inteiro, **síncrono** — o Isar Plus responde sem `await`, e é
  /// isso que deixa a hidratação e o índice serem valores derivados.
  List<ColdigomPraiseCache> findAllSync() {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.coldigomPraiseCaches.where().findAll();
  }

  /// Linha de um praise (leitor de letra), ou `null`.
  ColdigomPraiseCache? findByPraiseIdSync(String praiseId) {
    final isar = _isar;
    if (isar == null || praiseId.isEmpty) return null;
    return isar.coldigomPraiseCaches
        .where()
        .praiseIdEqualTo(praiseId)
        .findFirst();
  }

  int count() => _isar?.coldigomPraiseCaches.count() ?? 0;

  Isar _requireIsar(String operation) {
    final isar = _isar;
    if (isar == null) {
      throw StorageUnavailableException('coldigom_catalog.$operation');
    }
    return isar;
  }
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_catalog_local_datasource_test.dart` → 3 verdes. Correr também `flutter test test/unit/core/database/isar_smoke_test.dart` (schema novo abre com os outros).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database lib/core/constants/storage_keys.dart lib/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart test/unit/features/coldigom/coldigom_catalog_local_datasource_test.dart
flutter analyze
git add lib/core/database lib/core/constants/storage_keys.dart lib/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart test/unit/features/coldigom/coldigom_catalog_local_datasource_test.dart
git commit -m "feat(coldigom): collection ColdigomPraiseCache + datasource local (replaceAll/upsertMany)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 5: `ColdigomPraiseCacheMapper` — DTO ↔ linha Isar ↔ `PraiseDetailDto`

**Files:**
- Create: `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart`
- Test: `test/unit/features/coldigom/coldigom_praise_cache_mapper_test.dart`

**Interfaces:**
- Consumes: `ColdigomCatalogPraiseDto`, `ColdigomCatalogDto.kindNames` (Task 2); `ColdigomPraiseCache` (Task 4); `PraiseDetailDto`/`MaterialDto` (`praise_dto.dart`); `LouvorSearchTokens`, `LouvorNumeroNormalizer`.
- Produces:
  - `class ColdigomCatalogMaterialEntry { String id; String? kindId; String kindName; String type; String? r2Key; int? size; String? url; }` — forma decodificada de um item de `materialsJson`.
  - `abstract final class ColdigomPraiseCacheMapper { static ColdigomPraiseCache fromCatalogPraise(ColdigomCatalogPraiseDto, {required Map<String,String> kindNames}); static List<ColdigomCatalogMaterialEntry> decodeMaterials(ColdigomPraiseCache); static PraiseDetailDto toPraiseDetail(ColdigomPraiseCache); static String buildSearchTokens({name, number, author, tags}); static ColdigomPraiseCache fromPraiseDetail(PraiseDetailDto, {required Map<String,String> kindNames, String lyrics = ''}); }`

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/coldigom_praise_cache_mapper_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomCatalogDto _catalog() => ColdigomCatalogDto.fromJson(
  jsonDecode(File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test('fromCatalogPraise copia metadados, letra e serializa materiais com kindName', () {
    final catalog = _catalog();
    final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises.first,
      kindNames: catalog.kindNames,
    );

    expect(row.praiseId, 'p-001');
    expect(row.number, '001');
    expect(row.name, 'Ainda há tempo');
    expect(row.tags, ['Avulsos', 'PES']);
    expect(row.lyrics, 'Ainda há tempo\nde voltar ao Senhor');

    final materials = ColdigomPraiseCacheMapper.decodeMaterials(row);
    expect(materials, hasLength(5));
    final pdf = materials.firstWhere((m) => m.id == 'm-pdf');
    expect(pdf.kindId, 'k-grade');
    expect(pdf.kindName, 'Grade');
    expect(pdf.type, 'pdf');
    expect(pdf.r2Key, 'assets/praises/p-001/m-pdf.pdf');
    expect(pdf.size, 312345);
    final yt = materials.firstWhere((m) => m.id == 'yt-1');
    expect(yt.r2Key, isNull);
    expect(yt.url, 'https://www.youtube.com/watch?v=1Pks43ceAac');
    expect(yt.kindName, '');
  });

  test('searchTokens junta nome, número, tags e autor normalizados', () {
    final tokens = ColdigomPraiseCacheMapper.buildSearchTokens(
      name: 'São João',
      number: '2',
      author: 'Autor Dois',
      tags: const ['Coro', 'PES'],
    );

    // Tokens sem acento/stop words, número com pad 3 e cru.
    expect(tokens.split(' '), containsAll(['sao', 'joao', '002', 'autor', 'dois', 'coro', 'pes']));
  });

  test('toPraiseDetail reconstrói MaterialDto com r2Key/url/kind e acrescenta a letra sintética', () {
    final catalog = _catalog();
    final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises.first,
      kindNames: catalog.kindNames,
    );

    final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);

    expect(detail.id, 'p-001');
    expect(detail.rhythm, 'Básico');
    expect(detail.tagNames, ['Avulsos', 'PES']);
    final byId = {for (final m in detail.materials) m.id: m};
    expect(byId['m-mp3']!.r2Key, 'assets/praises/p-001/m-mp3.mp3');
    expect(byId['m-mp3']!.materialKindId, 'k-playback');
    expect(byId['m-mp3']!.materialKindName, 'Playback');
    expect(byId['yt-1']!.url, isNotNull);
    expect(byId['lyrics:p-001']!.type, 'lyrics');
  });

  test('sem letra não há material sintético; r2 explícito sobrevive à ida e volta', () {
    final catalog = _catalog();
    final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises[1],
      kindNames: catalog.kindNames,
    );

    final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);

    expect(detail.materials.map((m) => m.type), isNot(contains('lyrics')));
    expect(detail.materials.single.r2Key, 'assets/praises/p-002/m-odd.m4a');
  });

  test('fromPraiseDetail (página de busca) gera a mesma linha que o dump', () {
    final catalog = _catalog();
    final fromDump = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises.first,
      kindNames: catalog.kindNames,
    );
    final detail = PraiseDetailDto(
      id: 'p-001',
      name: 'Ainda há tempo',
      number: '001',
      rhythm: 'Básico',
      tonality: 'Dm',
      category: 'Dm',
      tagNames: const ['Avulsos', 'PES'],
      materials: const [
        MaterialDto(
          id: 'm-pdf',
          type: 'pdf',
          r2Key: 'assets/praises/p-001/m-pdf.pdf',
          materialKindId: 'k-grade',
          materialKindName: 'Grade',
        ),
      ],
    );

    final fromPage = ColdigomPraiseCacheMapper.fromPraiseDetail(
      detail,
      kindNames: catalog.kindNames,
      lyrics: 'Ainda há tempo\nde voltar ao Senhor',
    );

    expect(fromPage.praiseId, fromDump.praiseId);
    expect(fromPage.searchTokens, fromDump.searchTokens);
    expect(fromPage.lyrics, fromDump.lyrics);
    final pdf = ColdigomPraiseCacheMapper.decodeMaterials(fromPage).single;
    expect(pdf.r2Key, 'assets/praises/p-001/m-pdf.pdf');
    expect(pdf.kindName, 'Grade');
  });
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_praise_cache_mapper_test.dart` → falha (mapper não existe).

- [ ] **Step 2: Mapper**

`lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart`:

```dart
import 'dart:convert';

import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../catalog/domain/utils/louvor_numero_normalizer.dart';
import '../models/coldigom_catalog_dto.dart';
import '../models/praise_dto.dart';

/// Um item de [ColdigomPraiseCache.materialsJson], já decodificado.
///
/// É o que o download (plano 2) enumera: `type` decide se é baixável,
/// [kindId] filtra pelos kinds escolhidos, [r2Key] é o que se busca.
class ColdigomCatalogMaterialEntry {
  const ColdigomCatalogMaterialEntry({
    required this.id,
    required this.kindId,
    required this.kindName,
    required this.type,
    required this.r2Key,
    this.size,
    this.url,
  });

  final String id;
  final String? kindId;

  /// Rótulo do kind (`Grade`, `Playback`…); `''` quando não há kind.
  final String kindName;
  final String type;
  final String? r2Key;
  final int? size;
  final String? url;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kindId,
    'kindName': kindName,
    'type': type,
    'r2': r2Key,
    if (size != null) 'size': size,
    if (url != null) 'url': url,
  };

  static ColdigomCatalogMaterialEntry fromJson(Map<String, dynamic> json) {
    return ColdigomCatalogMaterialEntry(
      id: json['id'] as String? ?? '',
      kindId: json['kind'] as String?,
      kindName: json['kindName'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      r2Key: json['r2'] as String?,
      size: (json['size'] as num?)?.toInt(),
      url: json['url'] as String?,
    );
  }
}

/// Conversões entre o dump do Worker, a linha Isar e o [PraiseDetailDto] que
/// o `ColdigomLouvorAdapter` já sabe transformar em entidades.
///
/// Guardar `kindName` no JSON da linha (o dump manda só `kind`) evita uma
/// segunda tabela: é o rótulo das tiles do sheet, e o sync tem o mapa
/// `kinds` à mão nesse momento.
abstract final class ColdigomPraiseCacheMapper {
  /// Linha Isar a partir de um praise do dump.
  static ColdigomPraiseCache fromCatalogPraise(
    ColdigomCatalogPraiseDto praise, {
    required Map<String, String> kindNames,
  }) {
    return _row(
      praiseId: praise.id,
      number: praise.number,
      name: praise.name,
      author: praise.author,
      rhythm: praise.rhythm,
      tonality: praise.tonality,
      category: praise.category,
      tags: praise.tags,
      lyrics: praise.lyrics,
      materials: [
        for (final m in praise.materials)
          ColdigomCatalogMaterialEntry(
            id: m.id,
            kindId: m.kindId,
            kindName: kindNames[m.kindId] ?? '',
            type: m.type,
            r2Key: m.r2Key,
            size: m.size,
            url: m.url,
          ),
      ],
    );
  }

  /// Linha Isar a partir de um praise de `/api/plpcg/praises` (os «novos»
  /// da pesquisa, §6). A página não traz a letra; [lyrics] só vem
  /// preenchida quando quem chama a tem.
  static ColdigomPraiseCache fromPraiseDetail(
    PraiseDetailDto praise, {
    required Map<String, String> kindNames,
    String lyrics = '',
  }) {
    return _row(
      praiseId: praise.id,
      number: praise.number,
      name: praise.name,
      author: praise.author,
      rhythm: praise.rhythm,
      tonality: praise.tonality,
      category: praise.category,
      tags: praise.tagNames,
      lyrics: lyrics,
      materials: [
        for (final m in praise.materials)
          // A página já traz o material sintético de letra; a linha guarda
          // a letra no campo próprio, não como material.
          if (m.type.toLowerCase() != 'lyrics')
            ColdigomCatalogMaterialEntry(
              id: m.id,
              kindId: m.materialKindId,
              kindName:
                  m.materialKindName ?? kindNames[m.materialKindId] ?? '',
              type: m.type,
              r2Key: m.r2Key,
              url: m.url,
            ),
      ],
    );
  }

  static ColdigomPraiseCache _row({
    required String praiseId,
    required String number,
    required String name,
    required String author,
    required String rhythm,
    required String tonality,
    required String category,
    required List<String> tags,
    required String lyrics,
    required List<ColdigomCatalogMaterialEntry> materials,
  }) {
    return ColdigomPraiseCache()
      ..praiseId = praiseId
      ..number = number
      ..name = name
      ..author = author
      ..rhythm = rhythm
      ..tonality = tonality
      ..category = category
      ..tags = List<String>.from(tags)
      ..lyrics = lyrics
      ..materialsJson = jsonEncode([for (final m in materials) m.toJson()])
      ..searchTokens = buildSearchTokens(
        name: name,
        number: number,
        author: author,
        tags: tags,
      );
  }

  /// Tokens de busca — mesma normalização de `Louvor.fromManifest`
  /// ([LouvorSearchTokens.tokenize] + número normalizado), mais tags e autor
  /// (a letra fica de fora nesta entrega, §9).
  static String buildSearchTokens({
    required String name,
    required String number,
    required String author,
    required List<String> tags,
  }) {
    final tokens = <String>{
      ...LouvorSearchTokens.tokenize(name),
      ...LouvorSearchTokens.tokenize(author),
      for (final tag in tags) ...LouvorSearchTokens.tokenize(tag),
    };
    final numeroNorm = LouvorNumeroNormalizer.normalize(number);
    if (numeroNorm.isNotEmpty) tokens.add(numeroNorm);
    if (number.trim().isNotEmpty) {
      tokens.add(LouvorSearchTokens.normalize(number.trim()));
    }
    return tokens.where((t) => t.isNotEmpty).join(' ');
  }

  /// Materiais da linha, decodificados. JSON corrompido → lista vazia (a
  /// linha é regravada no próximo sync).
  static List<ColdigomCatalogMaterialEntry> decodeMaterials(
    ColdigomPraiseCache row,
  ) {
    try {
      final raw = jsonDecode(row.materialsJson);
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>)
            ColdigomCatalogMaterialEntry.fromJson(item),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// [PraiseDetailDto] equivalente à linha — o formato que
  /// `ColdigomLouvorAdapter` e `ColdigomCacheWriter` já consomem. A letra
  /// entra como material sintético `lyrics:<praiseId>` (id do Worker, O6).
  static PraiseDetailDto toPraiseDetail(ColdigomPraiseCache row) {
    final materials = [
      for (final m in decodeMaterials(row))
        MaterialDto(
          id: m.id,
          type: m.type,
          r2Key: m.r2Key,
          url: m.url,
          materialKindName: m.kindName.isEmpty ? null : m.kindName,
          materialKindId: m.kindId,
        ),
      if (row.lyrics.trim().isNotEmpty)
        MaterialDto(id: 'lyrics:${row.praiseId}', type: 'lyrics'),
    ];
    return PraiseDetailDto(
      id: row.praiseId,
      name: row.name,
      number: row.number,
      rhythm: row.rhythm,
      tonality: row.tonality,
      category: row.category,
      author: row.author,
      tagNames: List<String>.from(row.tags),
      materials: materials,
    );
  }
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_praise_cache_mapper_test.dart` → 5 verdes.

- [ ] **Step 3: Commit**

```bash
dart format lib/features/coldigom/data/mappers test/unit/features/coldigom/coldigom_praise_cache_mapper_test.dart
flutter analyze
git add lib/features/coldigom/data/mappers test/unit/features/coldigom/coldigom_praise_cache_mapper_test.dart
git commit -m "feat(coldigom): mapper dump ↔ ColdigomPraiseCache ↔ PraiseDetailDto (tokens de busca, letra sintética)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 6: `SyncColdigomCatalog` + metadata store + DI

**Files:**
- Create: `lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart`
- Create: `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart`
- Create: `lib/features/coldigom/data/providers/coldigom_catalog_data_providers.dart`
- Test: `test/unit/features/coldigom/sync_coldigom_catalog_test.dart`

**Interfaces:**
- Consumes: `ColdigomRemoteDatasource.fetchCatalog` (Task 3), `ColdigomCatalogLocalDatasource.replaceAll` (Task 4), `ColdigomPraiseCacheMapper.fromCatalogPraise` (Task 5), `sharedPreferencesProvider`, `optionalIsarProvider`, `coldigomRemoteDatasourceProvider`.
- Produces:
  - `class ColdigomCatalogSyncMetadataStore { const (SharedPreferences); String? readEtag(); DateTime? readSyncedAt(); int readCount(); Future<void> markReplaced({required String? etag, required int count, required DateTime at}); Future<void> markValidated(DateTime at); }`
  - `sealed class ColdigomCatalogSyncResult` com `ColdigomCatalogSyncReplaced(int count)`, `ColdigomCatalogSyncNoop()`, `ColdigomCatalogSyncFailed(Object cause)`.
  - `class SyncColdigomCatalog { SyncColdigomCatalog({required ColdigomRemoteDatasource remote, required ColdigomCatalogLocalDatasource local, required ColdigomCatalogSyncMetadataStore metadata, DateTime Function() now}); Future<ColdigomCatalogSyncResult> run(); }` — nunca lança.
  - Providers: `coldigomCatalogLocalDatasourceProvider` (`Provider<ColdigomCatalogLocalDatasource>`), `coldigomCatalogSyncMetadataStoreProvider`, `syncColdigomCatalogProvider` (`Provider<SyncColdigomCatalog>`).

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/sync_coldigom_catalog_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/domain/usecases/sync_coldigom_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remoto de roteiro: devolve o que o teste manda e regista o If-None-Match.
class _ScriptedRemote extends ColdigomRemoteDatasource {
  _ScriptedRemote(this._respond) : super(Dio());

  final Future<ColdigomCatalogFetchResult> Function(String? ifNoneMatch) _respond;
  final ifNoneMatches = <String?>[];

  @override
  Future<ColdigomCatalogFetchResult> fetchCatalog({String? ifNoneMatch}) {
    ifNoneMatches.add(ifNoneMatch);
    return _respond(ifNoneMatch);
  }
}

ColdigomCatalogDto _catalog() => ColdigomCatalogDto.fromJson(
  jsonDecode(File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late ColdigomCatalogLocalDatasource local;
  late ColdigomCatalogSyncMetadataStore metadata;
  final fixedNow = DateTime.utc(2026, 9, 14, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    metadata = ColdigomCatalogSyncMetadataStore(await SharedPreferences.getInstance());
    tempDir = await Directory.systemTemp.createTemp('sync_coldigom_');
    isar = Isar.open(
      schemas: [ColdigomPraiseCacheSchema],
      directory: tempDir.path,
      name: 'sync_coldigom_${DateTime.now().microsecondsSinceEpoch}',
    );
    local = ColdigomCatalogLocalDatasource(isar);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  SyncColdigomCatalog usecase(_ScriptedRemote remote) => SyncColdigomCatalog(
    remote: remote,
    local: local,
    metadata: metadata,
    now: () => fixedNow,
  );

  test('200 → replaceAll, etag, syncedAt e count gravados', () async {
    final remote = _ScriptedRemote(
      (_) async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );

    final result = await usecase(remote).run();

    expect(result, isA<ColdigomCatalogSyncReplaced>());
    expect((result as ColdigomCatalogSyncReplaced).count, 3);
    expect(local.count(), 3);
    expect(metadata.readEtag(), '"v1"');
    expect(metadata.readSyncedAt(), fixedNow);
    expect(metadata.readCount(), 3);
    expect(remote.ifNoneMatches, [null]);
  });

  test('304 → noop, manda o etag guardado, renova syncedAt sem tocar no Isar', () async {
    await metadata.markReplaced(etag: '"v1"', count: 3, at: DateTime.utc(2026, 1, 1));
    await local.replaceAll([
      ColdigomPraiseCache()
        ..praiseId = 'antigo'
        ..number = ''
        ..name = ''
        ..author = ''
        ..rhythm = ''
        ..tonality = ''
        ..category = ''
        ..tags = const []
        ..lyrics = ''
        ..materialsJson = '[]'
        ..searchTokens = '',
    ]);
    final remote = _ScriptedRemote((_) async => const ColdigomCatalogNotModified());

    final result = await usecase(remote).run();

    expect(result, isA<ColdigomCatalogSyncNoop>());
    expect(remote.ifNoneMatches, ['"v1"']);
    expect(local.findAllSync().single.praiseId, 'antigo');
    expect(metadata.readEtag(), '"v1"');
    expect(metadata.readSyncedAt(), fixedNow);
  });

  test('falha de rede → failed com a causa, Isar e etag intactos', () async {
    await metadata.markReplaced(etag: '"v1"', count: 0, at: DateTime.utc(2026, 1, 1));
    final remote = _ScriptedRemote(
      (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/api/plpcg/catalog'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await usecase(remote).run();

    expect(result, isA<ColdigomCatalogSyncFailed>());
    expect((result as ColdigomCatalogSyncFailed).cause, isA<DioException>());
    expect(local.count(), 0);
    expect(metadata.readEtag(), '"v1"');
    expect(metadata.readSyncedAt(), DateTime.utc(2026, 1, 1));
  });

  test('sem Isar → failed com StorageUnavailableException, sem gravar etag', () async {
    final remote = _ScriptedRemote(
      (_) async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );
    final degraded = SyncColdigomCatalog(
      remote: remote,
      local: const ColdigomCatalogLocalDatasource.unavailable(),
      metadata: metadata,
      now: () => fixedNow,
    );

    final result = await degraded.run();

    expect(result, isA<ColdigomCatalogSyncFailed>());
    expect(metadata.readEtag(), isNull);
  });
}
```

Correr: `flutter test test/unit/features/coldigom/sync_coldigom_catalog_test.dart` → falha (classes não existem).

- [ ] **Step 2: Metadata store**

`lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Metadados do sync do catálogo Coldigom em SharedPreferences: o ETag que
/// vai no `If-None-Match`, quando foi a última validação e quantos praises o
/// último dump trouxe (linha de estado do `/offline`).
///
/// Fora do Isar de propósito: sem Isar não há catálogo, e um ETag órfão
/// faria o próximo sync receber `304` para um banco vazio.
class ColdigomCatalogSyncMetadataStore {
  const ColdigomCatalogSyncMetadataStore(this._prefs);

  final SharedPreferences _prefs;

  String? readEtag() => _prefs.getString(StorageKeys.coldigomCatalogEtag);

  DateTime? readSyncedAt() {
    final raw = _prefs.getString(StorageKeys.coldigomCatalogSyncedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  int readCount() => _prefs.getInt(StorageKeys.coldigomCatalogCount) ?? 0;

  /// Dump novo gravado no Isar.
  Future<void> markReplaced({
    required String? etag,
    required int count,
    required DateTime at,
  }) async {
    if (etag == null) {
      await _prefs.remove(StorageKeys.coldigomCatalogEtag);
    } else {
      await _prefs.setString(StorageKeys.coldigomCatalogEtag, etag);
    }
    await _prefs.setInt(StorageKeys.coldigomCatalogCount, count);
    await markValidated(at);
  }

  /// `304`: o catálogo continua o do servidor — só a data muda.
  Future<void> markValidated(DateTime at) {
    return _prefs.setString(
      StorageKeys.coldigomCatalogSyncedAt,
      at.toUtc().toIso8601String(),
    );
  }
}
```

- [ ] **Step 3: Use case**

`lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../data/datasources/coldigom_catalog_local_datasource.dart';
import '../../data/datasources/coldigom_catalog_sync_metadata_store.dart';
import '../../data/datasources/coldigom_remote_datasource.dart';
import '../../data/mappers/coldigom_praise_cache_mapper.dart';

/// Desfecho de [SyncColdigomCatalog.run].
sealed class ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncResult();
}

/// Dump novo gravado — quem hidrata os caches em memória precisa recarregar.
final class ColdigomCatalogSyncReplaced extends ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncReplaced(this.count);

  final int count;
}

/// `304`: nada mudou.
final class ColdigomCatalogSyncNoop extends ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncNoop();
}

/// Rede ou storage falharam; o catálogo local (se houver) fica como está.
final class ColdigomCatalogSyncFailed extends ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncFailed(this.cause);

  final Object cause;
}

/// Sincroniza o catálogo Coldigom local por ETag (O3/O5).
///
/// Best-effort por contrato: nunca lança. `ColdigomCatalogSyncFailed.cause`
/// existe para a tela `/offline` explicar «não foi possível atualizar»; para
/// o boot e o foreground a falha é só um `debugPrint`. Sem Isar a escrita
/// lança [StorageUnavailableException] e o ETag **não** é gravado — senão o
/// próximo pedido receberia `304` para um banco vazio.
class SyncColdigomCatalog {
  SyncColdigomCatalog({
    required ColdigomRemoteDatasource remote,
    required ColdigomCatalogLocalDatasource local,
    required ColdigomCatalogSyncMetadataStore metadata,
    DateTime Function()? now,
  }) : _remote = remote,
       _local = local,
       _metadata = metadata,
       _now = now ?? DateTime.now;

  final ColdigomRemoteDatasource _remote;
  final ColdigomCatalogLocalDatasource _local;
  final ColdigomCatalogSyncMetadataStore _metadata;
  final DateTime Function() _now;

  Future<ColdigomCatalogSyncResult> run() async {
    try {
      // Sem catálogo gravado o ETag guardado não vale: pedir sem
      // `If-None-Match` garante o corpo inteiro.
      final etag = _local.count() == 0 ? null : _metadata.readEtag();
      final result = await _remote.fetchCatalog(ifNoneMatch: etag);
      switch (result) {
        case ColdigomCatalogNotModified():
          await _metadata.markValidated(_now());
          return const ColdigomCatalogSyncNoop();
        case ColdigomCatalogFresh(:final catalog, etag: final freshEtag):
          final rows = [
            for (final praise in catalog.praises)
              ColdigomPraiseCacheMapper.fromCatalogPraise(
                praise,
                kindNames: catalog.kindNames,
              ),
          ];
          await _local.replaceAll(rows);
          await _metadata.markReplaced(
            etag: freshEtag,
            count: rows.length,
            at: _now(),
          );
          return ColdigomCatalogSyncReplaced(rows.length);
      }
    } on Object catch (error) {
      debugPrint('[coldigom] sync do catálogo falhou: $error');
      return ColdigomCatalogSyncFailed(error);
    }
  }
}
```

- [ ] **Step 4: DI**

`lib/features/coldigom/data/providers/coldigom_catalog_data_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/usecases/sync_coldigom_catalog.dart';
import '../datasources/coldigom_catalog_local_datasource.dart';
import '../datasources/coldigom_catalog_sync_metadata_store.dart';
import 'coldigom_remote_providers.dart';

/// DI — catálogo Coldigom em Isar; `null` de Isar = modo degradado.
final coldigomCatalogLocalDatasourceProvider =
    Provider<ColdigomCatalogLocalDatasource>((ref) {
      final isar = ref.watch(optionalIsarProvider);
      if (isar == null) return const ColdigomCatalogLocalDatasource.unavailable();
      return ColdigomCatalogLocalDatasource(isar);
    });

/// DI — ETag/`syncedAt`/`count` do último sync.
final coldigomCatalogSyncMetadataStoreProvider =
    Provider<ColdigomCatalogSyncMetadataStore>((ref) {
      return ColdigomCatalogSyncMetadataStore(
        ref.watch(sharedPreferencesProvider),
      );
    });

/// DI — [SyncColdigomCatalog].
final syncColdigomCatalogProvider = Provider<SyncColdigomCatalog>((ref) {
  return SyncColdigomCatalog(
    remote: ref.watch(coldigomRemoteDatasourceProvider),
    local: ref.watch(coldigomCatalogLocalDatasourceProvider),
    metadata: ref.watch(coldigomCatalogSyncMetadataStoreProvider),
  );
});
```

Correr: `flutter test test/unit/features/coldigom/sync_coldigom_catalog_test.dart` → 4 verdes.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/coldigom test/unit/features/coldigom/sync_coldigom_catalog_test.dart
flutter analyze
git add lib/features/coldigom test/unit/features/coldigom/sync_coldigom_catalog_test.dart
git commit -m "feat(coldigom): SyncColdigomCatalog por ETag (replaced/noop/failed) + metadata em prefs + DI

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 7: `MaterialKind.lyrics` + `LyricsMaterial` + adapter + `LouvorGroup`

**Files:**
- Modify: `lib/core/utils/material_id_kind.dart` (enum linha 8; `materialIdKindOf` linhas 36–55; `materialKindOfRawType` linhas 64–73)
- Modify: `lib/features/catalog/domain/entities/catalog_material.dart` (fim do ficheiro)
- Modify: `lib/features/catalog/domain/entities/louvor_group.dart` (construtor linhas 49–68; `isColdigom` linhas 112–129; `fromLouvores` linhas 193–257; `_buildGroup` linhas 259–333)
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart` (método novo antes de `_basename`)
- Modify: `lib/features/catalog/domain/utils/louvor_material_icons.dart` (`forKind` linhas 23–30; `forMaterial` linhas 61–68)
- Modify: `lib/features/catalog/presentation/widgets/home_empty_state.dart` (`_toCarouselItem` linhas 66–98)
- Modify: `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart` (linha 161)
- Modify: `lib/features/material_kind_prefs/presentation/widgets/material_type_preference_control.dart` (linhas 95–103)
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart` (linhas 360–364 e 447–456)
- Modify: `lib/features/catalog/presentation/providers/open_material_provider.dart` (switch linhas 119–154)
- Modify: `lib/core/routing/route_paths.dart` (fim da classe)
- Modify: `lib/core/utils/url_sync_params.dart` (depois de `audioId`)
- Create: `lib/features/lyrics/presentation/utils/lyrics_reader_url_builder.dart`
- Test: `test/unit/features/coldigom/lyrics_material_test.dart`

**Interfaces:**
- Produces:
  - `MaterialKind.lyrics` (último valor antes de `unknown`); `materialKindOfRawType('lyrics') == MaterialKind.lyrics`; `materialIdKindOf('lyrics:<id>') == MaterialKind.lyrics`.
  - `final class LyricsMaterial extends CatalogMaterial { const LyricsMaterial({required String praiseId, required String nome, required String numero, required String text, String categoria = 'Letra'}); String get id => 'lyrics:$praiseId'; kind == lyrics; groupId == praiseId; materialKindId == null; }`
  - `LouvorGroup({..., LyricsMaterial? lyrics})` — quando não nulo vai para o fim de `extras`; `LouvorGroup.fromLouvores(..., Map<String, LyricsMaterial>? lyricsByGroupId)`; getter `LyricsMaterial? get lyrics`.
  - `static LyricsMaterial? ColdigomLouvorAdapter.toLyricsMaterial(PraiseDetailDto praise, String lyrics)` — `null` quando `lyrics.trim()` vazio.
  - `RoutePaths.lyrics = '/letra'`; `UrlSyncParams.praiseId = 'praiseId'`; `String buildLyricsReaderLocation({required String praiseId, String? titulo, String? subtitulo})`.
  - `OpenMaterial.openLyrics` (`LyricsMaterialOpener`) — padrão `openLyricsInReader` que faz `context.push(buildLyricsReaderLocation(...))`.

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/lyrics_material_test.dart`:

```dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/lyrics/presentation/utils/lyrics_reader_url_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _praise = PraiseDetailDto(
  id: 'p-001',
  name: 'Ainda há tempo',
  number: '001',
  rhythm: 'Básico',
  materials: [],
);

void main() {
  test('materialKindOfRawType e materialIdKindOf reconhecem letra', () {
    expect(materialKindOfRawType('lyrics'), MaterialKind.lyrics);
    expect(materialKindOfRawType('LYRICS'), MaterialKind.lyrics);
    expect(materialIdKindOf('lyrics:p-001'), MaterialKind.lyrics);
    expect(materialIdKindOf('lyrics:'), MaterialKind.unknown);
  });

  test('adapter só cria LyricsMaterial quando há texto', () {
    expect(ColdigomLouvorAdapter.toLyricsMaterial(_praise, '   '), isNull);

    final lyrics = ColdigomLouvorAdapter.toLyricsMaterial(_praise, 'Ainda há tempo\nde voltar')!;

    expect(lyrics.id, 'lyrics:p-001');
    expect(lyrics.kind, MaterialKind.lyrics);
    expect(lyrics.groupId, 'p-001');
    expect(lyrics.categoria, 'Letra');
    expect(lyrics.materialKindId, isNull);
    expect(lyrics.text, 'Ainda há tempo\nde voltar');
    expect(canAddMaterialToPlaylist(lyrics), isFalse);
    expect(LouvorMaterialIcons.forMaterial(lyrics), Icons.subject);
  });

  test('LouvorGroup põe a letra no fim de extras e conta como Coldigom', () {
    final lyrics = ColdigomLouvorAdapter.toLyricsMaterial(_praise, 'texto')!;
    final group = LouvorGroup(
      groupId: 'p-001',
      numero: '001',
      nome: 'Ainda há tempo',
      sections: const [],
      lyrics: lyrics,
    );

    expect(group.extras.last, same(lyrics));
    expect(group.lyrics, same(lyrics));
    expect(group.isColdigom, isTrue);
    expect(group.totalMaterials, 1);
  });

  test('fromLouvores anexa a letra pelo groupId', () {
    final lyrics = ColdigomLouvorAdapter.toLyricsMaterial(_praise, 'texto')!;

    final groups = LouvorGroup.fromLouvores(
      const [],
      lyricsByGroupId: {'p-001': lyrics},
    );

    expect(groups.single.groupId, 'p-001');
    expect(groups.single.nome, 'Ainda há tempo');
    expect(groups.single.numero, '001');
    expect(groups.single.lyrics, same(lyrics));
  });

  test('buildLyricsReaderLocation monta /letra?praiseId=…&titulo=…', () {
    expect(
      buildLyricsReaderLocation(praiseId: 'p 1', titulo: 'Ainda há tempo', subtitulo: '001'),
      '/letra?praiseId=p%201&titulo=Ainda%20h%C3%A1%20tempo&subtitulo=001',
    );
    expect(buildLyricsReaderLocation(praiseId: 'p1'), '/letra?praiseId=p1');
  });
}
```

Correr: `flutter test test/unit/features/coldigom/lyrics_material_test.dart` → falha de compilação.

- [ ] **Step 2: Enum e classificadores**

Em `lib/core/utils/material_id_kind.dart`:

Linha 8: `enum MaterialKind { pdf, chord, audio, youtube, gesture, lyrics, unknown }`.

Em `materialIdKindOf`, logo depois de `if (id.isEmpty) return MaterialKind.unknown;`:

```dart
  // Letra não vive no espaço Base64 dos paths: o id é `lyrics:<praiseId>`
  // (o mesmo que o Worker manda no material sintético, O6).
  if (id.startsWith('lyrics:')) {
    return id.length > 'lyrics:'.length
        ? MaterialKind.lyrics
        : MaterialKind.unknown;
  }
```

Em `materialKindOfRawType`, antes de `_ => MaterialKind.unknown,`: `'lyrics' => MaterialKind.lyrics,`. Atualize o doc-comment da função (linhas 62–63): «tipo desconhecido vira unknown» — `lyrics` já não é exemplo de desconhecido; troque o exemplo por `video`.

- [ ] **Step 3: Entidade**

No fim de `lib/features/catalog/domain/entities/catalog_material.dart`:

```dart
/// Letra do louvor (Coldigom) — abre no leitor `/letra`.
///
/// Material sintético (O6): o texto vem no dump do catálogo e vive no Isar,
/// nunca no R2. Não tem `material_kind` — logo não entra nos favoritos nem
/// nas contagens de download — e não é adicionável a playlist nesta entrega.
final class LyricsMaterial extends CatalogMaterial {
  const LyricsMaterial({
    required this.praiseId,
    required this.nome,
    required this.numero,
    required this.text,
    this.categoria = 'Letra',
  });

  final String praiseId;
  final String nome;
  final String numero;

  /// Letra completa, como veio do Worker (quebras de linha preservadas).
  final String text;

  @override
  final String categoria;

  /// Mesmo id do material sintético do Worker (`lyrics:<praiseId>`).
  @override
  String get id => 'lyrics:$praiseId';

  @override
  MaterialKind get kind => MaterialKind.lyrics;

  @override
  String get groupId => praiseId;

  @override
  String? get materialKindId => null;
}
```

Atualize o doc-comment de `CatalogMaterial` (linhas 8–17): «cinco casos» → «seis casos»; acrescente «letra» à lista.

- [ ] **Step 4: `LouvorGroup`**

Em `lib/features/catalog/domain/entities/louvor_group.dart`:

1. Construtor (linhas 49–68): adicionar o parâmetro `LyricsMaterial? lyrics,` (depois de `gestureMaterials`) e trocar o initializer de `extras` por:

```dart
  }) : extras =
           extras ??
           [
             for (final chord in chordMaterials) ChordMaterialRef(chord),
             for (final gesture in gestureMaterials) GestureMaterialRef(gesture),
             for (final track in audioTracks) AudioMaterial(track),
             for (final item in youtubeMaterials) YoutubeMaterialRef(item),
             // A letra fecha a lista: é o material «sempre presente» e o
             // menos urgente no sheet.
             ?lyrics,
           ],
       numeroSortKey = _parseNumeroSortKey(numero);
```

2. Depois do getter `gestureMaterials` (linha 106):

```dart
  /// Letra Coldigom do grupo — de [extras]; `null` no PLPCG e sem letra.
  LyricsMaterial? get lyrics {
    for (final material in extras) {
      if (material is LyricsMaterial) return material;
    }
    return null;
  }
```

3. Em `isColdigom` (linha 122): `case ChordMaterialRef() || GestureMaterialRef() || LyricsMaterial():`.

4. `fromLouvores`: adicionar `Map<String, LyricsMaterial>? lyricsByGroupId,` aos parâmetros nomeados (antes de `coldigomMetaByGroupId`); em `allGroupIds` incluir `...?lyricsByGroupId?.keys,`; na chamada a `_buildGroup` passar `lyricsByGroupId?[gid]` como último argumento posicional antes do meta:

```dart
      return _buildGroup(
        gid,
        byGroup[gid] ?? const [],
        audioByGroup[gid] ?? const [],
        youtubeByGroup[gid] ?? const [],
        chordByGroup[gid] ?? const [],
        gestureByGroup[gid] ?? const [],
        lyricsByGroupId?[gid],
        coldigomMetaByGroupId?[gid],
      );
```

5. `_buildGroup`: assinatura passa a `List<GestureMaterial> gestures, [LyricsMaterial? lyrics, ColdigomPraiseMetadata? coldigomMeta]`; no fallback de `nome`/`numero` acrescentar antes do `else` final:

```dart
    } else if (lyrics != null) {
      nome = lyrics.nome;
      numero = lyrics.numero.trim();
```

e no `return LouvorGroup(...)` passar `lyrics: lyrics,`.

- [ ] **Step 5: Adapter, rota e URL builder**

Em `coldigom_louvor_adapter.dart`, antes de `_basename`:

```dart
  /// Letra do praise como material sintético — `null` quando não há texto.
  ///
  /// O texto não está no [PraiseDetailDto] (a página de busca nunca o
  /// traz); quem tem a linha do Isar passa-o aqui.
  static LyricsMaterial? toLyricsMaterial(PraiseDetailDto praise, String lyrics) {
    if (lyrics.trim().isEmpty) return null;
    return LyricsMaterial(
      praiseId: praise.id,
      nome: praise.name,
      numero: praise.number,
      text: lyrics,
    );
  }
```

(import `package:coldigui/features/catalog/domain/entities/catalog_material.dart`.)

`route_paths.dart`, no fim da classe:

```dart
  /// Leitor de letra Coldigom ([LyricsReaderScreen]) — irmã de [chords], branch Home.
  static const String lyrics = '/letra';
```

`url_sync_params.dart`, depois de `audioId`:

```dart
  /// Identificador do praise Coldigom na rota `/letra`.
  static const String praiseId = 'praiseId';
```

`lib/features/lyrics/presentation/utils/lyrics_reader_url_builder.dart`:

```dart
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta o path do leitor de letra — espelho de `buildChordReaderLocation`.
String buildLyricsReaderLocation({
  required String praiseId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{UrlSyncParams.praiseId: praiseId};
  if (titulo != null && titulo.isNotEmpty) params[UrlSyncParams.titulo] = titulo;
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.lyrics}?$query';
}
```

- [ ] **Step 6: Switches exaustivos**

`louvor_material_icons.dart`:
- `forKind`: adicionar `MaterialKind.lyrics => Icons.subject,` antes da linha de `pdf || unknown`; acrescentar `- [MaterialKind.lyrics] → [Icons.subject]` ao doc-comment.
- `forMaterial`: `ChordMaterialRef() || GestureMaterialRef() || AudioMaterial() || YoutubeMaterialRef() || LyricsMaterial() => forKind(material.kind),`.

`home_empty_state.dart`, `_toCarouselItem` (switch linhas 67–98): novo caso

```dart
    LyricsMaterial(:final numero, :final nome) => (
      numero,
      nome,
      '',
      LouvorDataSource.coldigom,
    ),
```

`carousel_swap_material_button.dart` linha 161: `case ChordMaterialRef() || GestureMaterialRef() || YoutubeMaterialRef() || LyricsMaterial():`.

`material_type_preference_control.dart` linhas 95–103: adicionar `MaterialKind.lyrics => type,` antes de `MaterialKind.unknown => type,` (letra nunca chega aqui — não tem kind — mas o switch é exaustivo).

`material_sheet.dart`: nas duas `StateError` (linhas 362 e 454) trocar `MaterialKind.unknown =>` por `MaterialKind.lyrics || MaterialKind.unknown =>` — a aba «Letra» de verdade chega na Task 11; até lá a letra não entra em `kinds` (linhas 249–256), logo nunca cai aqui.

`open_material_provider.dart`:
1. Depois do typedef `YoutubeMaterialOpener`:

```dart
/// Abre a letra em `/letra` (`openLyricsInReader` em produção).
typedef LyricsMaterialOpener =
    Future<void> Function({
      required BuildContext context,
      required LyricsMaterial lyrics,
    });

/// Abertura padrão da letra: só navegação — o texto já está no Isar e a
/// letra não entra na lista ativa (O6).
Future<void> openLyricsInReader({
  required BuildContext context,
  required LyricsMaterial lyrics,
}) async {
  await context.push(
    buildLyricsReaderLocation(
      praiseId: lyrics.praiseId,
      titulo: lyrics.nome,
      subtitulo: lyrics.numero,
    ),
  );
}
```

(imports: `package:go_router/go_router.dart` e `../../../lyrics/presentation/utils/lyrics_reader_url_builder.dart`.)

2. Construtor: `this.openLyrics = openLyricsInReader,` + campo `final LyricsMaterialOpener openLyrics;`.
3. No `switch`, depois do caso `YoutubeMaterialRef`:

```dart
        case LyricsMaterial():
          await openLyrics(context: context, lyrics: material);
```

Correr: `flutter test test/unit/features/coldigom/lyrics_material_test.dart` → 5 verdes; `flutter analyze` → sem erros (se aparecer «missing case» noutro ficheiro, é um switch que este mapa não listou: acrescente o caso `lyrics` lá com o mesmo critério — nunca `default`).

Correr também os testes vizinhos: `flutter test test/unit/features/catalog test/unit/features/coldigom test/widget/features/catalog/material_sheet_test.dart test/widget/features/catalog/open_material_provider_test.dart`.

- [ ] **Step 7: Commit**

```bash
dart format lib test/unit/features/coldigom/lyrics_material_test.dart
flutter analyze
git add -A lib test/unit/features/coldigom/lyrics_material_test.dart
git commit -m "feat(catalog): MaterialKind.lyrics + LyricsMaterial (letra Coldigom como material sintético, O6)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 8: Cache de letras, `ColdigomCacheWriter.mergeCatalog`, `ColdigomCatalogSource` com letra

**Files:**
- Modify: `lib/features/coldigom/data/providers/coldigom_providers.dart` (depois de `coldigomYoutubeCacheProvider`, ~linha 172)
- Modify: `lib/features/coldigom/data/coldigom_cache_writer.dart` (métodos novos + `_merge` com `lyrics`)
- Modify: `lib/features/coldigom/data/sources/coldigom_catalog_source.dart` (construtor; `findGroupById` linhas 85–101; `findMaterialById` linhas 105–124)
- Modify: `lib/features/coldigom/data/providers/coldigom_catalog_source_provider.dart`
- Test: `test/unit/features/coldigom/coldigom_lyrics_cache_test.dart`

**Interfaces:**
- Produces:
  - `coldigomLyricsCacheProvider` (`NotifierProvider<ColdigomLyricsCacheNotifier, Map<String, LyricsMaterial>>`, chave `groupId`), `mergeLyrics(Iterable<LyricsMaterial>)`, `findByGroupId`.
  - `ColdigomCacheWriter.mergeLyrics(Iterable<LyricsMaterial>)` e `ColdigomCacheWriter.mergeCatalog({required List<Louvor> louvores, required List<AudioTrack> audioTracks, required List<ChordMaterial> chordMaterials, required List<GestureMaterial> gestureMaterials, required List<YoutubeMaterial> youtubeMaterials, required List<LyricsMaterial> lyrics, required Map<String, ColdigomPraiseMetadata> metaByGroupId})` — **uma** cópia de cada mapa.
  - `ColdigomCatalogSource({..., Map<String, LyricsMaterial> lyrics = const {}})`; `findGroupById` inclui a letra; `findMaterialById('lyrics:<id>')` devolve o `LyricsMaterial`.

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/coldigom_lyrics_cache_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _lyrics = LyricsMaterial(
  praiseId: 'p1',
  nome: 'Ainda há tempo',
  numero: '001',
  text: 'texto',
);

void main() {
  test('mergeCatalog escreve os seis caches de uma vez', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(coldigomCacheWriterProvider).mergeCatalog(
      louvores: const [],
      audioTracks: const [],
      chordMaterials: const [],
      gestureMaterials: const [],
      youtubeMaterials: const [],
      lyrics: const [_lyrics],
      metaByGroupId: const {'p1': ColdigomPraiseMetadata(name: 'Ainda há tempo')},
    );

    expect(container.read(coldigomLyricsCacheProvider)['p1'], same(_lyrics));
    expect(container.read(coldigomPraiseMetaCacheProvider)['p1']!.name, 'Ainda há tempo');
  });

  test('a fonte monta o grupo só com a letra e resolve o id lyrics:', () {
    const source = ColdigomCatalogSource(
      lyrics: {'p1': _lyrics},
      praiseMeta: {'p1': ColdigomPraiseMetadata(name: 'Ainda há tempo')},
    );

    final group = source.findGroupById('p1')!;
    expect(group.lyrics, same(_lyrics));
    expect(group.nome, 'Ainda há tempo');
    expect(group.coldigomMeta, isNotNull);
    expect(source.findMaterialById('lyrics:p1'), same(_lyrics));
    expect(source.findMaterialById('lyrics:zz'), isNull);
    expect(source.findGroupForMaterial('lyrics:p1')!.groupId, 'p1');
  });

  test('o provider da fonte observa o cache de letras', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(coldigomCacheWriterProvider).mergeLyrics(const [_lyrics]);

    expect(
      container.read(coldigomCatalogSourceProvider).findMaterialById('lyrics:p1'),
      same(_lyrics),
    );
  });
}
```

(import extra: `package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart`.)

Correr: `flutter test test/unit/features/coldigom/coldigom_lyrics_cache_test.dart` → falha.

- [ ] **Step 2: Cache de letras**

Em `coldigom_providers.dart`, depois de `coldigomYoutubeCacheProvider` (antes do `coldigomCacheWriterProvider`):

```dart
/// Cache de letras Coldigom indexadas por praise/`groupId` (O6).
///
/// Uma letra por praise — chave pelo `groupId`, como os metadados.
class ColdigomLyricsCacheNotifier extends Notifier<Map<String, LyricsMaterial>> {
  @override
  Map<String, LyricsMaterial> build() => const {};

  void mergeLyrics(Iterable<LyricsMaterial> lyrics) {
    if (lyrics.isEmpty) return;
    final next = Map<String, LyricsMaterial>.from(state);
    for (final item in lyrics) {
      next[item.groupId] = item;
    }
    state = next;
  }

  LyricsMaterial? findByGroupId(String groupId) => state[groupId];
}

final coldigomLyricsCacheProvider =
    NotifierProvider<ColdigomLyricsCacheNotifier, Map<String, LyricsMaterial>>(
      ColdigomLyricsCacheNotifier.new,
    );
```

(import `../../../catalog/domain/entities/catalog_material.dart`.)

- [ ] **Step 3: Writer**

Em `coldigom_cache_writer.dart`:
- import `../../catalog/domain/entities/catalog_material.dart`;
- depois de `mergeGestures`:

```dart
  /// Funde só letras — a hidratação e a adoção dos «novos» da pesquisa.
  void mergeLyrics(Iterable<LyricsMaterial> lyrics) {
    _ref.read(coldigomLyricsCacheProvider.notifier).mergeLyrics(lyrics);
  }

  /// Funde o catálogo inteiro hidratado do Isar (O4) — **uma** escrita por
  /// cache. 1690 `mergePraiseDetail` copiariam o mapa de 20 k entradas 1690
  /// vezes; aqui cada notifier copia uma vez.
  void mergeCatalog({
    required List<Louvor> louvores,
    required List<AudioTrack> audioTracks,
    required List<ChordMaterial> chordMaterials,
    required List<GestureMaterial> gestureMaterials,
    required List<YoutubeMaterial> youtubeMaterials,
    required List<LyricsMaterial> lyrics,
    required Map<String, ColdigomPraiseMetadata> metaByGroupId,
  }) {
    _merge(
      louvores: louvores,
      audioTracks: audioTracks,
      chordMaterials: chordMaterials,
      gestureMaterials: gestureMaterials,
      youtubeMaterials: youtubeMaterials,
      metaByGroupId: metaByGroupId,
    );
    mergeLyrics(lyrics);
  }
```

- [ ] **Step 4: Fonte**

Em `coldigom_catalog_source.dart`:
1. Construtor: `this.lyrics = const {},` e campo:

```dart
  /// Letras Coldigom em cache, por `groupId` (O6).
  final Map<String, LyricsMaterial> lyrics;
```

2. `findGroupById`: incluir a letra na condição de vazio e na montagem:

```dart
    final groupLyrics = lyrics[groupId];
    if (pdfs.isEmpty &&
        tracks.isEmpty &&
        groupChords.isEmpty &&
        groupGestures.isEmpty &&
        groupLyrics == null) {
      return null;
    }

    final groups = LouvorGroup.fromLouvores(
      pdfs,
      audioTracks: tracks,
      chordMaterials: groupChords,
      gestureMaterials: groupGestures,
      youtubeMaterials: youtube[groupId] ?? const [],
      lyricsByGroupId: groupLyrics == null ? null : {groupId: groupLyrics},
      coldigomMetaByGroupId: praiseMeta,
    );
```

Atualize o doc-comment do método: a letra sustenta um grupo sozinha (ao contrário do YouTube) — é o caso de um praise só com letra.

3. `findMaterialById`: caso novo antes de `youtube`:

```dart
      case MaterialKind.lyrics:
        // `lyrics:<praiseId>` — o praise é o groupId.
        return lyrics[materialId.substring('lyrics:'.length)];
```

4. `findGroupForMaterial`: antes de `coldigomPraiseIdFromPdfId`:

```dart
    if (materialIdKindOf(materialId) == MaterialKind.lyrics) {
      return findGroupById(materialId.substring('lyrics:'.length));
    }
```

Em `coldigom_catalog_source_provider.dart`: `lyrics: ref.watch(coldigomLyricsCacheProvider),`.

Correr: `flutter test test/unit/features/coldigom/coldigom_lyrics_cache_test.dart test/unit/features/catalog/catalog_source_test.dart test/unit/features/gestures/coldigom_catalog_source_gesture_test.dart` → verdes.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/coldigom test/unit/features/coldigom/coldigom_lyrics_cache_test.dart
flutter analyze
git add lib/features/coldigom test/unit/features/coldigom/coldigom_lyrics_cache_test.dart
git commit -m "feat(coldigom): cache de letras + mergeCatalog em lote + letra na fonte Coldigom

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 9: `ColdigomSearchIndex` (ranking igual ao PLPCG)

**Files:**
- Create: `lib/features/coldigom/domain/search/coldigom_search_index.dart`
- Test: `test/unit/features/coldigom/coldigom_search_index_test.dart`

**Interfaces:**
- Consumes: `LouvorSearchTokens`, `LouvorNumeroNormalizer`, `LouvorGroup`.
- Produces:
  - `final class ColdigomIndexedPraise { String praiseId; String numero; String numeroNorm; String titleNorm; String titleCompact; List<String> contentTokens; String compactContent; LouvorGroup group; factory .build({required String praiseId, required String numero, required String nome, required String searchTokens, required LouvorGroup group}); }`
  - `final class ColdigomSearchIndex { static const empty; factory .build(List<ColdigomIndexedPraise>); List<ColdigomIndexedPraise> entries; Set<String> praiseIds; bool get isEmpty; List<LouvorGroup> search(String query); }` — ranking: número exato → título exato → parcial (tokens prefixo / compacto), ordem estável dentro de cada faixa. O ranking replica `SearchLouvorByNumberOrText.callIndexed` com os mesmos helpers; não o chama porque aquele é tipado em `Louvor` e a unidade Coldigom é o praise (um grupo).

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/coldigom_search_index_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomIndexedPraise _entry(
  String id,
  String numero,
  String nome, {
  String author = '',
  List<String> tags = const [],
}) {
  return ColdigomIndexedPraise.build(
    praiseId: id,
    numero: numero,
    nome: nome,
    searchTokens: ColdigomPraiseCacheMapper.buildSearchTokens(
      name: nome,
      number: numero,
      author: author,
      tags: tags,
    ),
    group: LouvorGroup(groupId: id, numero: numero, nome: nome, sections: const []),
  );
}

void main() {
  final index = ColdigomSearchIndex.build([
    _entry('p1', '001', 'Ainda há tempo', tags: const ['PES']),
    _entry('p2', '010', 'Tempo de louvar'),
    _entry('p3', '100', 'São João', author: 'Autor Dois'),
    _entry('p4', '', 'Ainda há tempo', tags: const ['Coro']),
  ]);

  List<String> ids(String query) =>
      index.search(query).map((g) => g.groupId).toList();

  test('índice vazio devolve vazio; query vazia devolve vazio', () {
    expect(ColdigomSearchIndex.empty.search('tempo'), isEmpty);
    expect(index.search('   '), isEmpty);
    expect(index.praiseIds, {'p1', 'p2', 'p3', 'p4'});
  });

  test('número exato primeiro (com e sem pad)', () {
    expect(ids('10').first, 'p2');
    expect(ids('010').first, 'p2');
    expect(ids('1').first, 'p1');
  });

  test('título exato antes do parcial; ordem estável entre iguais', () {
    expect(ids('ainda há tempo'), ['p1', 'p4', 'p2']);
    expect(ids('Ainda ha tempo'), ['p1', 'p4', 'p2']);
  });

  test('parcial sem acento por prefixo de token e compacto', () {
    expect(ids('tem'), ['p1', 'p2', 'p4']);
    expect(ids('aindaha'), ['p1', 'p4']);
    expect(ids('joao'), ['p3']);
  });

  test('tags e autor entram na busca', () {
    expect(ids('pes'), ['p1']);
    expect(ids('coro'), ['p4']);
    expect(ids('autor dois'), ['p3']);
  });

  test('sem hit devolve vazio e nunca repete um praise', () {
    expect(ids('zzz'), isEmpty);
    final all = ids('a');
    expect(all.toSet().length, all.length);
  });
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_search_index_test.dart` → falha.

- [ ] **Step 2: Índice**

`lib/features/coldigom/domain/search/coldigom_search_index.dart`:

```dart
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/utils/louvor_numero_normalizer.dart';

/// Um praise no índice: os campos de busca pré-computados e o grupo pronto
/// para a Home — construído **uma vez por hidratação**, não por tecla.
final class ColdigomIndexedPraise {
  const ColdigomIndexedPraise._({
    required this.praiseId,
    required this.numero,
    required this.numeroNorm,
    required this.titleNorm,
    required this.titleCompact,
    required this.contentTokens,
    required this.compactContent,
    required this.group,
  });

  /// [searchTokens] é a coluna `ColdigomPraiseCache.searchTokens` (nome +
  /// número + tags + autor, já normalizados) — ver
  /// `ColdigomPraiseCacheMapper.buildSearchTokens`.
  factory ColdigomIndexedPraise.build({
    required String praiseId,
    required String numero,
    required String nome,
    required String searchTokens,
    required LouvorGroup group,
  }) {
    final tokens = searchTokens
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    return ColdigomIndexedPraise._(
      praiseId: praiseId,
      numero: numero.trim(),
      numeroNorm: LouvorNumeroNormalizer.normalize(numero),
      titleNorm: LouvorSearchTokens.normalize(nome),
      titleCompact: LouvorSearchTokens.compact(nome),
      contentTokens: tokens,
      // Compacto de tudo o que é pesquisável — é o que permite
      // `aindaha` → «Ainda há tempo», como no PLPCG.
      compactContent: tokens.join(),
      group: group,
    );
  }

  final String praiseId;
  final String numero;
  final String numeroNorm;
  final String titleNorm;
  final String titleCompact;
  final List<String> contentTokens;
  final String compactContent;
  final LouvorGroup group;
}

/// Índice de busca do acervo Coldigom — espelho de `PlpcgSearchIndex`.
///
/// Mesmo ranking de `SearchLouvorByNumberOrText.callIndexed` (número exato →
/// título exato → parcial), sobre praises em vez de `Louvor`: no Coldigom a
/// unidade da Home é o grupo, e ele já sai montado daqui.
final class ColdigomSearchIndex {
  const ColdigomSearchIndex._(this.entries, this.praiseIds);

  /// Índice vazio — antes da hidratação e em modo degradado.
  static const empty = ColdigomSearchIndex._(<ColdigomIndexedPraise>[], <String>{});

  factory ColdigomSearchIndex.build(List<ColdigomIndexedPraise> entries) {
    if (entries.isEmpty) return empty;
    return ColdigomSearchIndex._(
      List<ColdigomIndexedPraise>.unmodifiable(entries),
      Set<String>.unmodifiable({for (final e in entries) e.praiseId}),
    );
  }

  final List<ColdigomIndexedPraise> entries;

  /// Ids conhecidos localmente — é contra isto que a pesquisa remota (plano
  /// 3) decide o que é «novo».
  final Set<String> praiseIds;

  bool get isEmpty => entries.isEmpty;

  /// Grupos que casam com [query], ranqueados; vazio para query em branco.
  List<LouvorGroup> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || entries.isEmpty) return const [];

    final numeroQuery = LouvorNumeroNormalizer.normalize(trimmed);
    final queryNorm = LouvorSearchTokens.normalize(trimmed);
    final queryCompact = LouvorSearchTokens.compact(trimmed);
    final queryTokens = LouvorSearchTokens.tokenize(trimmed);

    final exactNumber = <LouvorGroup>[];
    final exactTitle = <LouvorGroup>[];
    final partial = <LouvorGroup>[];

    for (final entry in entries) {
      if (entry.numero == trimmed ||
          (numeroQuery.isNotEmpty && entry.numeroNorm == numeroQuery)) {
        exactNumber.add(entry.group);
        continue;
      }
      if (queryTokens.isEmpty) continue;
      if (entry.titleNorm == queryNorm ||
          (queryCompact.length >= 3 && entry.titleCompact == queryCompact)) {
        exactTitle.add(entry.group);
        continue;
      }
      final matches = LouvorSearchTokens.matchesText(
        contentTokens: entry.contentTokens,
        compactContent: entry.compactContent,
        query: trimmed,
        queryTokens: queryTokens,
      );
      if (matches) partial.add(entry.group);
    }

    return [...exactNumber, ...exactTitle, ...partial];
  }
}
```

Correr: `flutter test test/unit/features/coldigom/coldigom_search_index_test.dart` → 6 verdes. Se `ids('1').first` não for `p1`, confirme em `LouvorNumeroNormalizer.normalize` como `'1'` é padronizado (`001`) — o teste assume o pad de 3 dígitos que `Louvor.fromManifest` já usa.

- [ ] **Step 3: Commit**

```bash
dart format lib/features/coldigom/domain/search test/unit/features/coldigom/coldigom_search_index_test.dart
flutter analyze
git add lib/features/coldigom/domain/search test/unit/features/coldigom/coldigom_search_index_test.dart
git commit -m "feat(coldigom): ColdigomSearchIndex — número exato → título exato → parcial, um grupo por praise

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 10: Hidratação no boot, sync (boot + foreground) e pesquisa local concatenada

**Files:**
- Create: `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart`
- Modify: `lib/features/coldigom/data/sources/coldigom_catalog_source.dart` (construtor; `searchLocal` linhas 145–147)
- Modify: `lib/features/coldigom/data/providers/coldigom_catalog_source_provider.dart`
- Modify: `lib/features/catalog/data/sources/composite_catalog_source.dart` (`searchLocal` linhas 50–52)
- Modify: `lib/features/catalog/presentation/providers/home_search_provider.dart` (`homeLocalSearchProvider` linhas 44–49)
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart` (linhas 148–149)
- Modify: `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart` (`resumed`, linhas 47–49)
- Modify: `lib/core/constants/offline_config.dart` (fim da classe)
- Test: `test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`
- Test (existente, acrescentar caso): `test/unit/features/catalog/catalog_source_test.dart`

**Interfaces:**
- Consumes: `coldigomCatalogLocalDatasourceProvider`, `syncColdigomCatalogProvider`, `coldigomCatalogSyncMetadataStoreProvider` (Task 6); `ColdigomPraiseCacheMapper.toPraiseDetail` (Task 5); `ColdigomLouvorAdapter.*` + `toLyricsMaterial` (Task 7); `ColdigomCacheWriter.mergeCatalog` (Task 8); `ColdigomSearchIndex` (Task 9); `awaitIsarSettled`, `deviceConnectivityProvider`.
- Produces:
  - `OfflineConfig.coldigomCatalogSyncMinInterval = Duration(minutes: 30)` (o mesmo valor de `catalogChecksumPollMinInterval`; a spec chama-lhe `catalogChecksumMinInterval` — o nome real é este) e `OfflineConfig.coldigomHydrationChunkSize = 300`.
  - `coldigomCatalogHydrationProvider` — `FutureProvider<ColdigomSearchIndex>` (keepAlive por defeito): espera o Isar, lê `findAllSync()`, converte em chunks (cede o event loop a cada 300 praises), faz **um** `mergeCatalog`, devolve o índice. Sem Isar → `ColdigomSearchIndex.empty`.
  - `coldigomSearchIndexProvider` — `Provider<ColdigomSearchIndex>` = `hydration.value ?? empty`.
  - `coldigomCatalogSyncProvider` — `NotifierProvider<ColdigomCatalogSyncNotifier, ColdigomCatalogSyncState { bool isSyncing; ColdigomCatalogSyncResult? lastResult; DateTime? lastSyncedAt; int count; }>` com `Future<ColdigomCatalogSyncResult> sync()` (deduplica in-flight; após `Replaced` invalida a hidratação) e `Future<void> requestSyncIfStale()` (só se `syncedAt` é `null` ou ≥ 30 min e há rede). Boot: `build()` agenda `requestSyncIfStale()` num microtask.
  - `ColdigomCatalogSource({..., ColdigomSearchIndex index = ColdigomSearchIndex.empty})`; `searchLocal(query) => index.search(query.text)`.
  - `CompositeCatalogSource.searchLocal` = `[...plpcg.searchLocal(q), ...coldigom.searchLocal(q)]` (O16); `homeLocalSearchProvider` idem (PLPCG com filtros UC-02; Coldigom sem).

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_data_providers.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/usecases/sync_coldigom_catalog.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';

class _Online implements DeviceConnectivity {
  _Online(this.online);
  final bool online;
  @override
  Future<bool> hasConnection() async => online;
}

class _ScriptedRemote extends ColdigomRemoteDatasource {
  _ScriptedRemote(this._respond) : super(Dio());
  final Future<ColdigomCatalogFetchResult> Function() _respond;
  int calls = 0;
  @override
  Future<ColdigomCatalogFetchResult> fetchCatalog({String? ifNoneMatch}) {
    calls++;
    return _respond();
  }
}

ColdigomCatalogDto _catalog() => ColdigomCatalogDto.fromJson(
  jsonDecode(File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('coldigom_hydration_');
    isar = Isar.open(
      schemas: [ColdigomPraiseCacheSchema],
      directory: tempDir.path,
      name: 'coldigom_hydration_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  ProviderContainer container({
    required _ScriptedRemote remote,
    bool online = true,
    bool isarAvailable = true,
  }) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarInitializerProvider.overrideWith(
          (ref) async => isarAvailable ? isar : throw StateError('sem isar'),
        ),
        coldigomRemoteDatasourceProvider.overrideWithValue(remote),
        deviceConnectivityProvider.overrideWithValue(_Online(online)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> seed() async {
    final catalog = _catalog();
    await ColdigomCatalogLocalDatasource(isar).replaceAll([
      for (final p in catalog.praises)
        ColdigomPraiseCacheMapper.fromCatalogPraise(p, kindNames: catalog.kindNames),
    ]);
  }

  test('hidrata caches e índice a partir do Isar, sem tocar na rede', () async {
    await seed();
    final remote = _ScriptedRemote(() async => const ColdigomCatalogNotModified());
    final c = container(remote: remote, online: false);

    final index = await c.read(coldigomCatalogHydrationProvider.future);

    // p-003 não tem material nenhum (nem letra): não sustenta um grupo e
    // fica fora do índice — mas continua no Isar (`count` = 3).
    expect(index.praiseIds, {'p-001', 'p-002'});
    expect(c.read(coldigomLouvoresCacheProvider).length, 1);
    expect(c.read(coldigomAudioTracksCacheProvider).length, 2);
    expect(c.read(coldigomChordMaterialsCacheProvider).length, 1);
    expect(c.read(coldigomGestureMaterialsCacheProvider).length, 1);
    expect(c.read(coldigomYoutubeCacheProvider)['p-001'], hasLength(1));
    expect(c.read(coldigomLyricsCacheProvider).keys, ['p-001']);
    expect(c.read(coldigomPraiseMetaCacheProvider)['p-002']!.author, 'Autor Dois');
    final source = c.read(coldigomCatalogSourceProvider);
    final hits = source.searchLocal(const CatalogQuery(text: 'tempo'));
    expect(hits.single.groupId, 'p-001');
    expect(hits.single.lyrics, isNotNull);
    expect(hits.single.totalMaterials, 6);
    expect(remote.calls, 0);
  });

  test('sem Isar: índice vazio e sync falha sem gravar', () async {
    final remote = _ScriptedRemote(
      () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );
    final c = container(remote: remote, isarAvailable: false);

    final index = await c.read(coldigomCatalogHydrationProvider.future);
    final result = await c.read(coldigomCatalogSyncProvider.notifier).sync();

    expect(index.isEmpty, isTrue);
    expect(result, isA<ColdigomCatalogSyncFailed>());
  });

  test('sync com dump novo re-hidrata; in-flight é deduplicado', () async {
    final remote = _ScriptedRemote(
      () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );
    final c = container(remote: remote, online: false);
    expect((await c.read(coldigomCatalogHydrationProvider.future)).isEmpty, isTrue);

    final notifier = c.read(coldigomCatalogSyncProvider.notifier);
    final results = await Future.wait([notifier.sync(), notifier.sync()]);

    expect(results.whereType<ColdigomCatalogSyncReplaced>(), hasLength(2));
    expect(remote.calls, 1);
    final index = await c.read(coldigomCatalogHydrationProvider.future);
    expect(index.praiseIds, {'p-001', 'p-002'});
    expect(c.read(coldigomCatalogSyncProvider).count, 3);
    expect(c.read(coldigomCatalogSyncProvider).lastSyncedAt, isNotNull);
  });

  test('requestSyncIfStale respeita os 30 min e a rede', () async {
    final remote = _ScriptedRemote(() async => const ColdigomCatalogNotModified());
    await seed();
    await ColdigomCatalogSyncMetadataStore(prefs).markReplaced(
      etag: '"v1"',
      count: 3,
      at: DateTime.now().toUtc(),
    );

    // Recente → nada.
    final fresh = container(remote: remote, online: true);
    await fresh.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
    expect(remote.calls, 0);

    // Velho mas offline → nada.
    await ColdigomCatalogSyncMetadataStore(prefs).markValidated(
      DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );
    final offline = container(remote: remote, online: false);
    await offline.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
    expect(remote.calls, 0);

    // Velho e online → sync.
    final stale = container(remote: remote, online: true);
    await stale.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
    expect(remote.calls, 1);
  });
}
```

(imports extra: `package:coldigui/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart`.)

Correr: `flutter test test/unit/features/coldigom/coldigom_catalog_hydration_test.dart` → falha (providers não existem).

- [ ] **Step 2: `OfflineConfig`**

No fim de `lib/core/constants/offline_config.dart`:

```dart
  /// Intervalo mínimo entre syncs do catálogo Coldigom ao voltar ao
  /// foreground (O5) — o mesmo dos 30 min do checksum PLPCG.
  static const Duration coldigomCatalogSyncMinInterval = Duration(minutes: 30);

  /// Praises convertidos por fatia na hidratação do catálogo Coldigom; entre
  /// fatias o event loop é cedido para não travar o primeiro frame na web.
  static const int coldigomHydrationChunkSize = 300;
```

- [ ] **Step 3: Providers**

`lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/device_connectivity_provider.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/catalog_material.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/entities/youtube_material.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../data/adapters/coldigom_louvor_adapter.dart';
import '../../data/mappers/coldigom_praise_cache_mapper.dart';
import '../../data/providers/coldigom_catalog_data_providers.dart';
import '../../data/providers/coldigom_providers.dart';
import '../../domain/entities/coldigom_praise_metadata.dart';
import '../../domain/search/coldigom_search_index.dart';
import '../../domain/usecases/sync_coldigom_catalog.dart';

export '../../domain/usecases/sync_coldigom_catalog.dart'
    show
        ColdigomCatalogSyncResult,
        ColdigomCatalogSyncReplaced,
        ColdigomCatalogSyncNoop,
        ColdigomCatalogSyncFailed;

/// Hidrata os caches Coldigom em memória a partir do Isar **uma vez** (O4) e
/// devolve o índice de busca local.
///
/// Corre depois de o Isar abrir e fora do caminho crítico: a Home não espera
/// por isto (o PLPCG aparece primeiro, como hoje). A conversão é fatiada em
/// [OfflineConfig.coldigomHydrationChunkSize] praises com `await
/// Future.delayed(Duration.zero)` entre fatias — na web tudo corre na thread
/// de UI, e 1690 praises de uma vez atrasariam o primeiro frame.
///
/// Sem Isar (modo degradado) devolve [ColdigomSearchIndex.empty]. Um sync
/// que substituiu o catálogo invalida este provider ([ColdigomCatalogSyncNotifier]).
final coldigomCatalogHydrationProvider = FutureProvider<ColdigomSearchIndex>((
  ref,
) async {
  if (await awaitIsarSettled(ref) != IsarStatus.available) {
    return ColdigomSearchIndex.empty;
  }
  final rows = ref.read(coldigomCatalogLocalDatasourceProvider).findAllSync();
  if (rows.isEmpty) return ColdigomSearchIndex.empty;

  final stopwatch = Stopwatch()..start();
  final louvores = <Louvor>[];
  final audioTracks = <AudioTrack>[];
  final chords = <ChordMaterial>[];
  final gestures = <GestureMaterial>[];
  final youtube = <YoutubeMaterial>[];
  final lyrics = <LyricsMaterial>[];
  final meta = <String, ColdigomPraiseMetadata>{};
  final entries = <ColdigomIndexedPraise>[];

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);
    final praiseLouvores = ColdigomLouvorAdapter.toLouvores(detail);
    final praiseTracks = ColdigomLouvorAdapter.toAudioTracks(detail);
    final praiseChords = ColdigomLouvorAdapter.toChordMaterials(detail);
    final praiseGestures = ColdigomLouvorAdapter.toGestureMaterials(detail);
    final praiseYoutube = ColdigomLouvorAdapter.toYoutubeMaterials(detail);
    final praiseLyrics = ColdigomLouvorAdapter.toLyricsMaterial(detail, row.lyrics);
    final praiseMeta = ColdigomLouvorAdapter.toMetadata(detail);

    louvores.addAll(praiseLouvores);
    audioTracks.addAll(praiseTracks);
    chords.addAll(praiseChords);
    gestures.addAll(praiseGestures);
    youtube.addAll(praiseYoutube);
    if (praiseLyrics != null) lyrics.add(praiseLyrics);
    meta[row.praiseId] = praiseMeta;

    final groups = LouvorGroup.fromLouvores(
      praiseLouvores,
      audioTracks: praiseTracks,
      chordMaterials: praiseChords,
      gestureMaterials: praiseGestures,
      youtubeMaterials: praiseYoutube,
      lyricsByGroupId: praiseLyrics == null ? null : {row.praiseId: praiseLyrics},
      coldigomMetaByGroupId: {row.praiseId: praiseMeta},
    );
    // Um praise sem material endereçável (só YouTube, ou nada) não sustenta
    // um grupo — mesma regra de `ColdigomCatalogSource.findGroupById`.
    final group = groups.where((g) => g.groupId == row.praiseId).firstOrNull;
    if (group != null) {
      entries.add(
        ColdigomIndexedPraise.build(
          praiseId: row.praiseId,
          numero: row.number,
          nome: row.name,
          searchTokens: row.searchTokens,
          group: group,
        ),
      );
    }

    if ((i + 1) % OfflineConfig.coldigomHydrationChunkSize == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ref.read(coldigomCacheWriterProvider).mergeCatalog(
    louvores: louvores,
    audioTracks: audioTracks,
    chordMaterials: chords,
    gestureMaterials: gestures,
    youtubeMaterials: youtube,
    lyrics: lyrics,
    metaByGroupId: meta,
  );
  debugPrint(
    '[coldigom] catálogo hidratado: ${rows.length} praises em '
    '${stopwatch.elapsedMilliseconds} ms',
  );
  return ColdigomSearchIndex.build(entries);
});

/// Índice de busca local Coldigom — vazio até a hidratação terminar.
final coldigomSearchIndexProvider = Provider<ColdigomSearchIndex>((ref) {
  return ref.watch(coldigomCatalogHydrationProvider).value ??
      ColdigomSearchIndex.empty;
});

/// Estado do sync do catálogo Coldigom — a linha «Catálogo: N louvores ·
/// atualizado há …» do `/offline` lê daqui.
class ColdigomCatalogSyncState {
  const ColdigomCatalogSyncState({
    this.isSyncing = false,
    this.lastResult,
    this.lastSyncedAt,
    this.count = 0,
  });

  final bool isSyncing;
  final ColdigomCatalogSyncResult? lastResult;
  final DateTime? lastSyncedAt;
  final int count;

  ColdigomCatalogSyncState copyWith({
    bool? isSyncing,
    ColdigomCatalogSyncResult? lastResult,
    DateTime? lastSyncedAt,
    int? count,
  }) {
    return ColdigomCatalogSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      count: count ?? this.count,
    );
  }
}

/// Orquestra [SyncColdigomCatalog] (O5): boot com rede, foreground com ≥ 30
/// min, pedido explícito («Atualizar» no `/offline`, «novo» na pesquisa).
final coldigomCatalogSyncProvider =
    NotifierProvider<ColdigomCatalogSyncNotifier, ColdigomCatalogSyncState>(
      ColdigomCatalogSyncNotifier.new,
    );

class ColdigomCatalogSyncNotifier extends Notifier<ColdigomCatalogSyncState> {
  Future<ColdigomCatalogSyncResult>? _inFlight;

  @override
  ColdigomCatalogSyncState build() {
    final metadata = ref.read(coldigomCatalogSyncMetadataStoreProvider);
    // Boot: em paralelo ao PLPCG, sem bloquear ninguém — e sem repetir o
    // pedido se o último sync foi há pouco (o app pode reabrir muitas vezes).
    unawaited(Future<void>.microtask(requestSyncIfStale));
    return ColdigomCatalogSyncState(
      lastSyncedAt: metadata.readSyncedAt(),
      count: metadata.readCount(),
    );
  }

  /// Sync incondicional, deduplicado: um segundo pedido durante um em voo
  /// recebe o mesmo future.
  Future<ColdigomCatalogSyncResult> sync() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _run();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  /// Sync só quando o último foi há ≥ [OfflineConfig.coldigomCatalogSyncMinInterval]
  /// (ou nunca) **e** há rede. Sem rede fica o que está.
  Future<void> requestSyncIfStale() async {
    final syncedAt = ref.read(coldigomCatalogSyncMetadataStoreProvider).readSyncedAt();
    final hasCatalog = ref.read(coldigomCatalogLocalDatasourceProvider).count() > 0;
    if (hasCatalog &&
        syncedAt != null &&
        DateTime.now().toUtc().difference(syncedAt) <
            OfflineConfig.coldigomCatalogSyncMinInterval) {
      return;
    }
    if (!await ref.read(deviceConnectivityProvider).hasConnection()) return;
    await sync();
  }

  Future<ColdigomCatalogSyncResult> _run() async {
    state = state.copyWith(isSyncing: true);
    final result = await ref.read(syncColdigomCatalogProvider).run();
    final metadata = ref.read(coldigomCatalogSyncMetadataStoreProvider);
    state = state.copyWith(
      isSyncing: false,
      lastResult: result,
      lastSyncedAt: metadata.readSyncedAt(),
      count: metadata.readCount(),
    );
    if (result is ColdigomCatalogSyncReplaced) {
      // O Isar mudou por baixo dos caches: re-hidrata (o índice novo troca
      // a lista local na Home sem tocar em quem já leu `groupById`).
      ref.invalidate(coldigomCatalogHydrationProvider);
    }
    return result;
  }
}
```

- [ ] **Step 4: Fonte, composto e Home**

`coldigom_catalog_source.dart`: parâmetro `this.index = ColdigomSearchIndex.empty,` + campo `final ColdigomSearchIndex index;` (import `../../domain/search/coldigom_search_index.dart`), e:

```dart
  /// Resultados locais do índice hidratado — vazio antes da hidratação.
  /// Os filtros UC-02 não se aplicam ao Coldigom (O16).
  @override
  List<LouvorGroup> searchLocal(CatalogQuery query) => index.search(query.text);
```

Atualize o doc-comment da classe (linhas 22–23): já não é «sempre vazio».

`coldigom_catalog_source_provider.dart`: `index: ref.watch(coldigomSearchIndexProvider),` (import `../../presentation/providers/coldigom_catalog_providers.dart`).

`composite_catalog_source.dart`:

```dart
  /// PLPCG primeiro, Coldigom depois (O16) — cada fonte com o seu ranking.
  @override
  List<LouvorGroup> searchLocal(CatalogQuery query) => [
    ...plpcg.searchLocal(query),
    ...coldigom.searchLocal(query),
  ];
```

`home_search_provider.dart`, `homeLocalSearchProvider`:

```dart
/// Resultados locais da query + filtros correntes — **síncronos**, PLPCG
/// primeiro e Coldigom depois (O16).
///
/// Observa manifest (via [plpcgCatalogSourceProvider]), o índice Coldigom
/// hidratado (via [coldigomCatalogSourceProvider]), query e filtros: um
/// refresh de manifest, um sync do catálogo Coldigom ou um chip de material
/// re-derivam só esta lista, sem tocar a rede. Os filtros UC-02 valem só
/// para o PLPCG.
final homeLocalSearchProvider = Provider<List<LouvorGroup>>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final plpcg = ref.watch(plpcgCatalogSourceProvider);
  final coldigom = ref.watch(coldigomCatalogSourceProvider);
  final catalogQuery = CatalogQuery(text: query, filters: filters);
  return [
    ...plpcg.searchLocal(catalogQuery),
    ...coldigom.searchLocal(catalogQuery),
  ];
});
```

(import `../../../coldigom/data/providers/coldigom_catalog_source_provider.dart`.)

Em `test/unit/features/catalog/catalog_source_test.dart`, acrescente um teste no fim de `main` (adapte os fixtures existentes do ficheiro — `_plpcgPartitura` e o grupo Coldigom de `_coldigomPdf`):

```dart
  test('CompositeCatalogSource.searchLocal concatena PLPCG e Coldigom (O16)', () {
    final plpcg = PlpcgCatalogSource(
      catalog: [_plpcgPartitura],
      index: PlpcgSearchIndex.build([_plpcgPartitura]),
    );
    final coldigomGroup = LouvorGroup(
      groupId: 'p1',
      numero: '001',
      nome: 'Grande Deus',
      sections: const [],
      chordMaterials: [_coldigomChord],
    );
    final coldigom = ColdigomCatalogSource(
      index: ColdigomSearchIndex.build([
        ColdigomIndexedPraise.build(
          praiseId: 'p1',
          numero: '001',
          nome: 'Grande Deus',
          searchTokens: 'grande deus 001',
          group: coldigomGroup,
        ),
      ]),
    );
    final composite = CompositeCatalogSource(plpcg: plpcg, coldigom: coldigom);

    final hits = composite.searchLocal(const CatalogQuery(text: 'grande'));

    expect(hits.map((g) => g.groupId), [_plpcgGroupId, 'p1']);
  });
```

(`_coldigomChord` é o `ChordMaterial` já definido no ficheiro para `_coldigomChordId`; confirme o nome ao ler o ficheiro e use-o.)

- [ ] **Step 5: Boot e foreground**

`shell_scaffold.dart`, depois de `ref.watch(materialKindPrefsSyncProvider);` (linha 149):

```dart
    // Catálogo Coldigom local (O4/O5): hidrata do Isar e sincroniza no boot
    // sem bloquear o shell — a Home mostra o PLPCG primeiro, como hoje.
    ref.watch(coldigomCatalogHydrationProvider);
    ref.watch(coldigomCatalogSyncProvider);
```

(import `../../../coldigom/presentation/providers/coldigom_catalog_providers.dart`.)

`offline_lifecycle_listener.dart`, no `case AppLifecycleState.resumed:` depois do poll do checksum:

```dart
        unawaited(
          ref.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale(),
        );
```

(import `../../../coldigom/presentation/providers/coldigom_catalog_providers.dart`.)

Correr: `flutter test test/unit/features/coldigom/coldigom_catalog_hydration_test.dart test/unit/features/catalog/catalog_source_test.dart test/unit/features/catalog/home_search_provider_test.dart test/widget/features/app_shell` → verdes. Se um teste de widget do shell falhar por `sharedPreferencesProvider`/Isar não sobrescritos ao construir `coldigomCatalogSyncProvider`, o `build()` do notifier lê prefs: acrescente nesse teste `sharedPreferencesProvider.overrideWithValue(prefs)` (padrão E10 em `test/support/test_overrides.dart`) — não engula o erro no provider.

- [ ] **Step 6: Commit**

```bash
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(coldigom): hidratação do catálogo no boot, sync por ETag (boot/foreground) e busca local Coldigom na Home

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 11: Leitor `/letra` + aba «Letra» no sheet + l10n

**Files:**
- Create: `lib/features/lyrics/domain/entities/lyrics_reader_font_size.dart`
- Create: `lib/features/lyrics/data/datasources/lyrics_reader_preferences_datasource.dart`
- Create: `lib/features/lyrics/presentation/providers/lyrics_reader_font_size_provider.dart`
- Create: `lib/features/lyrics/presentation/pages/lyrics_reader_screen.dart`
- Modify: `lib/core/routing/app_router.dart` (import; rota depois de `gestos`, linhas 146–151)
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart` (`_isImmersiveMediaRoute`, linhas 63–68)
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart` (`kinds` linhas 249–256; `switch` de tiles linhas 304–365; `_kindLabel` linhas 447–456)
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (fim do ficheiro)
- Test: `test/widget/features/lyrics/lyrics_reader_screen_test.dart`
- Test: `test/widget/features/catalog/material_sheet_lyrics_test.dart`

**Interfaces:**
- Consumes: `coldigomCatalogLocalDatasourceProvider.findByPraiseIdSync` (Task 6), `LyricsMaterial`, `RoutePaths.lyrics`, `UrlSyncParams.praiseId/titulo/subtitulo` (Task 7), `sharedPreferencesProvider`, `StorageKeys.lyricsReaderFontSize` (Task 4).
- Produces:
  - `abstract final class LyricsReaderFontSize { min 14, max 28, step 2, initial 18; clamp/increase/decrease/canIncrease/canDecrease }` (cópia de `GestureReaderFontSize`; a spec permite reutilizar os controles das cifras «sem alterar o leitor de cifras» — `chordReaderFontSizeProvider` está acoplado ao modo claro/escuro e ao teclado daquele leitor, por isso a letra tem preferência própria `lyricsReaderFontSize`).
  - `lyricsReaderFontSizeProvider` (`NotifierProvider<LyricsReaderFontSizeNotifier, double>`; `increase()`/`decrease()`).
  - `class LyricsReaderScreen extends ConsumerWidget { const LyricsReaderScreen({required Map<String, String> queryParams}); }` — lê `praiseId` dos params; texto do Isar; `SelectableText` em `SingleChildScrollView`; toolbar com A−/A+; vazio → `lyricsReaderEmpty`.
  - l10n: `lyricsTitle` («Letra»), `lyricsTab` («Letra»), `lyricsReaderEmpty` («Este louvor não tem letra guardada»), `lyricsReaderIncreaseFont` («Aumentar letra»), `lyricsReaderDecreaseFont` («Diminuir letra»).
  - Sheet: aba `MaterialKind.lyrics` quando `group.lyrics != null`, com um tile (`_materialTile` com `LyricsMaterial`), sem `+` (já garantido por `canAddMaterialToPlaylist`).

- [ ] **Step 1: l10n**

`lib/l10n/app_pt.arb`, antes do `}` final (com vírgula na linha anterior):

```json
  "lyricsTitle": "Letra",
  "lyricsTab": "Letra",
  "lyricsReaderEmpty": "Este louvor não tem letra guardada",
  "lyricsReaderIncreaseFont": "Aumentar letra",
  "lyricsReaderDecreaseFont": "Diminuir letra"
```

`lib/l10n/app_en.arb`:

```json
  "lyricsTitle": "Lyrics",
  "lyricsTab": "Lyrics",
  "lyricsReaderEmpty": "No lyrics stored for this hymn",
  "lyricsReaderIncreaseFont": "Increase text size",
  "lyricsReaderDecreaseFont": "Decrease text size"
```

Correr `flutter gen-l10n`.

- [ ] **Step 2: Teste do leitor que falha**

`test/widget/features/lyrics/lyrics_reader_screen_test.dart`:

```dart
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_data_providers.dart';
import 'package:coldigui/features/lyrics/domain/entities/lyrics_reader_font_size.dart';
import 'package:coldigui/features/lyrics/presentation/pages/lyrics_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';

/// Datasource só de memória: o leitor lê por `praiseId`, nada mais.
class _MemoryCatalog extends ColdigomCatalogLocalDatasource {
  const _MemoryCatalog(this.rows) : super(null);

  final Map<String, ColdigomPraiseCache> rows;

  @override
  ColdigomPraiseCache? findByPraiseIdSync(String praiseId) => rows[praiseId];
}

ColdigomPraiseCache _row(String lyrics) => ColdigomPraiseCache()
  ..praiseId = 'p1'
  ..number = '001'
  ..name = 'Ainda há tempo'
  ..author = ''
  ..rhythm = ''
  ..tonality = ''
  ..category = ''
  ..tags = const []
  ..lyrics = lyrics
  ..materialsJson = '[]'
  ..searchTokens = '';

Future<SharedPreferences> _pump(
  WidgetTester tester, {
  required String lyrics,
  Map<String, String>? queryParams,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  await pumpApp(
    tester,
    LyricsReaderScreen(
      queryParams: queryParams ?? {'praiseId': 'p1', 'titulo': 'Ainda há tempo'},
    ),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      coldigomCatalogLocalDatasourceProvider.overrideWithValue(
        _MemoryCatalog({'p1': _row(lyrics)}),
      ),
    ],
  );
  await tester.pump();
  return prefs;
}

void main() {
  testWidgets('mostra o texto da letra lido do Isar', (tester) async {
    await _pump(tester, lyrics: 'Ainda há tempo\nde voltar ao Senhor');

    expect(find.text('Ainda há tempo'), findsOneWidget);
    expect(find.textContaining('de voltar ao Senhor'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('A+ / A− mudam o corpo e persistem a preferência', (tester) async {
    final prefs = await _pump(tester, lyrics: 'texto');

    TextStyle styleOf() =>
        tester.widget<SelectableText>(find.byType(SelectableText)).style!;
    expect(styleOf().fontSize, LyricsReaderFontSize.initial);

    await tester.tap(find.byTooltip('Aumentar letra'));
    await tester.pump();
    expect(styleOf().fontSize, LyricsReaderFontSize.initial + LyricsReaderFontSize.step);
    expect(
      prefs.getDouble(StorageKeys.lyricsReaderFontSize),
      LyricsReaderFontSize.initial + LyricsReaderFontSize.step,
    );

    await tester.tap(find.byTooltip('Diminuir letra'));
    await tester.pump();
    expect(styleOf().fontSize, LyricsReaderFontSize.initial);
  });

  testWidgets('praise sem letra ou desconhecido mostra o vazio', (tester) async {
    await _pump(tester, lyrics: '', queryParams: {'praiseId': 'zz'});

    expect(find.text('Este louvor não tem letra guardada'), findsOneWidget);
  });
}
```

Correr: `flutter test test/widget/features/lyrics/lyrics_reader_screen_test.dart` → falha.

- [ ] **Step 3: Preferência de fonte**

`lib/features/lyrics/domain/entities/lyrics_reader_font_size.dart`:

```dart
/// Faixa e passo do corpo do texto no leitor de letra.
///
/// Mesma faixa do leitor de gestos: a letra é lida a um braço de distância;
/// abaixo de 14 some, acima de 28 quase toda linha quebra no celular.
abstract final class LyricsReaderFontSize {
  static const double min = 14;
  static const double max = 28;
  static const double step = 2;
  static const double initial = 18;

  static double clamp(double size) => size.clamp(min, max);

  static double increase(double size) => clamp(size + step);

  static double decrease(double size) => clamp(size - step);

  static bool canIncrease(double size) => size < max;

  static bool canDecrease(double size) => size > min;
}
```

`lib/features/lyrics/data/datasources/lyrics_reader_preferences_datasource.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/lyrics_reader_font_size.dart';

/// Persistência do corpo do texto do leitor de letra.
class LyricsReaderPreferencesDatasource {
  const LyricsReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Corpo salvo, ou [LyricsReaderFontSize.initial]; fora da faixa é
  /// grampeado em vez de descartado.
  double getFontSize() {
    final stored = _prefs.getDouble(StorageKeys.lyricsReaderFontSize);
    if (stored == null) return LyricsReaderFontSize.initial;
    return LyricsReaderFontSize.clamp(stored);
  }

  Future<void> saveFontSize(double size) =>
      _prefs.setDouble(StorageKeys.lyricsReaderFontSize, size);
}
```

`lib/features/lyrics/presentation/providers/lyrics_reader_font_size_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/lyrics_reader_preferences_datasource.dart';
import '../../domain/entities/lyrics_reader_font_size.dart';

/// Corpo do texto no leitor de letra, persistido entre sessões.
///
/// Mesmo padrão de `GestureReaderFontSizeNotifier`: `sharedPreferencesProvider`
/// é síncrono e o `main()` já o sobrescreve.
class LyricsReaderFontSizeNotifier extends Notifier<double> {
  @override
  double build() => _datasource.getFontSize();

  LyricsReaderPreferencesDatasource get _datasource =>
      LyricsReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void increase() => _set(LyricsReaderFontSize.increase(state));

  void decrease() => _set(LyricsReaderFontSize.decrease(state));

  void _set(double next) {
    if (next == state) return;
    state = next;
    unawaited(_datasource.saveFontSize(next));
  }
}

final lyricsReaderFontSizeProvider =
    NotifierProvider<LyricsReaderFontSizeNotifier, double>(
      LyricsReaderFontSizeNotifier.new,
    );
```

- [ ] **Step 4: Ecrã**

`lib/features/lyrics/presentation/pages/lyrics_reader_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../domain/entities/lyrics_reader_font_size.dart';
import '../providers/lyrics_reader_font_size_provider.dart';

/// Leitor de letra Coldigom (`/letra?praiseId=`) — O6.
///
/// Lê o texto do Isar ([coldigomCatalogLocalDatasourceProvider]), nunca da
/// rede: a letra vem inteira no dump do catálogo e está sempre offline.
/// Filho da branch Home como `/cifra`: o shell dá o cabeçalho e a barra do
/// carousel; aqui só há a barra de A−/A+ e o texto selecionável.
class LyricsReaderScreen extends ConsumerWidget {
  const LyricsReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  String get _praiseId => queryParams[UrlSyncParams.praiseId] ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = ref.watch(lyricsReaderFontSizeProvider);
    final row = ref
        .watch(coldigomCatalogLocalDatasourceProvider)
        .findByPraiseIdSync(_praiseId);
    final title = queryParams[UrlSyncParams.titulo] ?? row?.name ?? '';
    final text = row?.lyrics.trim() ?? '';

    return ColoredBox(
      color: AppColors.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LyricsToolbar(title: title, fontSize: fontSize, l10n: l10n),
            const Divider(color: AppColors.gold, height: 1, thickness: 1.5),
            Expanded(
              child: text.isEmpty
                  ? Center(
                      child: Text(
                        l10n.lyricsReaderEmpty,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textDark.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: SelectableText(
                        text,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textDark,
                          fontSize: fontSize,
                          height: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título do louvor + A−/A+.
class _LyricsToolbar extends ConsumerWidget {
  const _LyricsToolbar({
    required this.title,
    required this.fontSize,
    required this.l10n,
  });

  final String title;
  final double fontSize;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.read(lyricsReaderFontSizeProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.isEmpty ? l10n.lyricsTitle : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headline.copyWith(
                color: AppColors.title,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.lyricsReaderDecreaseFont,
            icon: const Icon(Icons.text_decrease, color: AppColors.title),
            onPressed: LyricsReaderFontSize.canDecrease(fontSize)
                ? size.decrease
                : null,
          ),
          IconButton(
            tooltip: l10n.lyricsReaderIncreaseFont,
            icon: const Icon(Icons.text_increase, color: AppColors.title),
            onPressed: LyricsReaderFontSize.canIncrease(fontSize)
                ? size.increase
                : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rota e shell**

`app_router.dart`: import `../../features/lyrics/presentation/pages/lyrics_reader_screen.dart`; depois da `GoRoute(path: 'gestos', …)` (linha 151):

```dart
            GoRoute(
              path: 'letra',
              builder: (context, state) => LyricsReaderScreen(
                queryParams: safeQueryParameters(state.uri),
              ),
            ),
```

(o `path` relativo `'letra'` corresponde a `RoutePaths.lyrics = '/letra'` sob `RoutePaths.home`, como `'cifra'`/`'gestos'`.) Atualize o doc-comment do router (linhas 36–37): «`/audio`, `/cifra`, `/gestos` e `/letra` são irmãs».

`shell_scaffold.dart`, `_isImmersiveMediaRoute`: acrescentar `|| path == RoutePaths.lyrics`.

Correr: `flutter test test/widget/features/lyrics/lyrics_reader_screen_test.dart` → 3 verdes.

- [ ] **Step 6: Teste do sheet que falha**

`test/widget/features/catalog/material_sheet_lyrics_test.dart`:

```dart
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _lyrics = LyricsMaterial(
  praiseId: 'p1',
  nome: 'Comigo habita',
  numero: '692',
  text: 'texto',
);

final _pdf = Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '692',
  categoria: 'Partitura',
  classificacao: 'Básico',
  pdf: 'm1.pdf',
  pdfId: 'pdf-1',
  groupId: 'p1',
  source: LouvorDataSource.coldigom,
);

class _OpenSpy extends OpenMaterial {
  CatalogMaterial? opened;

  @override
  Future<void> open(
    BuildContext context,
    WidgetRef ref,
    CatalogMaterial material, {
    List<dynamic>? audioQueue,
  }) async {
    opened = material;
  }
}

Future<_OpenSpy> _pumpSheet(WidgetTester tester, LouvorGroup group) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final spy = _OpenSpy();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        activeEntriesProvider.overrideWithValue(const []),
        openMaterialProvider.overrideWithValue(spy),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMaterialSheet(context, ref, group),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return spy;
}

void main() {
  testWidgets('grupo com PDF e letra ganha a aba «Letra» com um tile sem +', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores(
      [_pdf],
      lyricsByGroupId: {'p1': _lyrics},
    ).single;
    final spy = await _pumpSheet(tester, group);

    expect(find.text('Letra'), findsOneWidget);
    await tester.tap(find.text('Letra'));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(ListTile, 'Letra');
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.byType(MaterialAddTrailing)), findsNothing);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(spy.opened, same(_lyrics));
  });

  testWidgets('grupo só com letra mostra o tile direto, sem abas', (tester) async {
    final group = LouvorGroup(
      groupId: 'p1',
      numero: '692',
      nome: 'Comigo habita',
      sections: const [],
      lyrics: _lyrics,
    );
    await _pumpSheet(tester, group);

    expect(find.widgetWithText(ListTile, 'Letra'), findsOneWidget);
  });
}
```

(Se `activeEntriesProvider` exigir outro override no seu tipo, copie o de `material_sheet_test.dart` linhas 170–176; a assinatura de `open` do spy segue a de `_OpenMaterialSpy` daquele ficheiro — use `List<AudioTrack>? audioQueue` com o import de `audio_track.dart`.)

Correr: `flutter test test/widget/features/catalog/material_sheet_lyrics_test.dart` → falha (não há aba «Letra»).

- [ ] **Step 7: Sheet**

Em `material_sheet.dart`:

1. `kinds` (linhas 249–256): acrescentar como último item `if (group.lyrics != null) MaterialKind.lyrics,`.
2. No `switch` de tiles (antes do caso `MaterialKind.unknown`):

```dart
                  MaterialKind.lyrics => [
                    _materialTile(
                      material: group.lyrics!,
                      iconColor: AppColors.title,
                      activeMaterialIds: activeMaterialIds,
                      l10n: l10n,
                    ),
                  ],
```

e o caso de erro volta a ser só `MaterialKind.unknown => throw StateError(...)`.
3. `_kindLabel`: `MaterialKind.lyrics => l10n.lyricsTab,` e o erro só para `unknown`.
4. Doc-comment da classe (linha 33): «uma aba por tipo presente (PDF, cifras, gestos, áudio, YouTube, letra)».

Correr: `flutter test test/widget/features/catalog/material_sheet_lyrics_test.dart test/widget/features/catalog/material_sheet_test.dart test/widget/features/catalog/material_sheet_favorites_test.dart` → verdes.

- [ ] **Step 8: Commit**

```bash
flutter gen-l10n
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(lyrics): leitor /letra (texto do Isar, A−/A+) e aba «Letra» no sheet de materiais

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 12: Docs (UC-01, UC-09, UC-10, FEATURE_INDEX, README do Worker)

**Files:**
- Modify: `docs/use-cases/UC-01-search-louvor-home.md`
- Modify: `docs/use-cases/UC-09-configure-offline.md`
- Modify: `docs/use-cases/UC-10-offline-maintenance.md`
- Modify: `docs/features/FEATURE_INDEX.md` (linha da feature `catalog` e da `offline`; nova linha `lyrics`)
- Modify: `workers/plpcg-catalog/README.md` (secção de endpoints — nota de referência)

- [ ] **Step 1: UC-01**

Em «Pré-condições»: `Manifest carregado; app online ou offline com catálogo cacheado (PLPCG em LouvorCache; Coldigom em ColdigomPraiseCache, hidratado no boot)`.

Em «Fluxo principal», passo 5: `5. Resultados como LouvorGroupCard — PLPCG primeiro (com filtros UC-02), Coldigom depois (índice local ColdigomSearchIndex, mesmo ranking).`

Em «Regras de negócio»: acrescentar `Coldigom local: número exato → título exato → parcial sobre nome + número + tags + autor (letra fora); sem rede continua a responder do índice.`

Em «Componentes Flutter alvo»: acrescentar `ColdigomSearchIndex, coldigomCatalogHydrationProvider, CompositeCatalogSource.searchLocal`.

- [ ] **Step 2: UC-09 e UC-10**

UC-09, «Pós-condições»: acrescentar `Catálogo Coldigom local (ColdigomPraiseCache) sincronizado por ETag no boot com rede — metadados, lista de materiais e letra disponíveis offline; materiais binários Coldigom são o plano 2.`

UC-10, «Fluxo principal»: acrescentar item `6. Catálogo Coldigom: sync por ETag ao voltar ao foreground (≥ 30 min, coldigomCatalogSyncProvider.requestSyncIfStale) — 304 não toca no Isar; 200 substitui numa transação e re-hidrata.`

- [ ] **Step 3: FEATURE_INDEX**

Na tabela «Status por feature»:
- Linha `catalog`: acrescentar ao fim da coluna «Use cases»: `; **catálogo Coldigom local set/2026** — [ColdigomPraiseCache] + [SyncColdigomCatalog] (ETag/304, `GET /api/plpcg/catalog` via `patches/coldigom-api-plpcg-catalog.patch`), [coldigomCatalogHydrationProvider], [ColdigomSearchIndex] (busca local Coldigom na Home, O16); spec [offline Coldigom](../superpowers/specs/2026-09-14-offline-coldigom-design.md)`.
- Linha nova depois de `gestures`: `| \`lyrics\` | UC-01 (variante) | Média | **Concluído** (letra Coldigom set/2026) | Rota \`/letra\` ([LyricsReaderScreen]); [LyricsMaterial] (\`MaterialKind.lyrics\`, id \`lyrics:<praiseId>\`, sem download/favoritos — O6); texto do Isar; aba «Letra» no [MaterialSheet] |`.
- Atualize a linha «Última atualização» do topo com `**offline Coldigom parte 1 set/2026** — catálogo Coldigom em Isar + busca local + letra`.

- [ ] **Step 4: README do Worker plpcg-catalog**

Em `workers/plpcg-catalog/README.md`, na secção de endpoints, acrescentar uma nota final: `> O catálogo Coldigom não passa por este Worker: o app lê \`GET https://coldigom-api.jairofilho79.workers.dev/api/plpcg/catalog\` (ETag/304) diretamente — ver \`patches/coldigom-api-plpcg-catalog.patch\`.`

- [ ] **Step 5: Commit**

```bash
git add docs workers/plpcg-catalog/README.md
git commit -m "docs(offline): UC-01/09/10 e FEATURE_INDEX — catálogo Coldigom local, busca local e letra

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

## Checklist manual (§8 da spec — Parte 1)

**Pré-requisito:** patch aplicado e deployado no coldigom-api (Task 1, passo do dono), ou `--dart-define=COLDIGOM_API_BASE_URL=<preview>` a apontar para um Worker com o patch.

**Web dev (`flutter run -d chrome --dart-define-from-file=dart_defines/dev.json`):**
- [ ] Boot com rede: no console aparece `[coldigom] catálogo hidratado: 0 praises` (primeira vez) e, segundos depois, o sync grava; recarregar a página mostra `[coldigom] catálogo hidratado: 1690 praises em N ms` — anote N (meta: < 150 ms no iPhone; na web dev < 300 ms).
- [ ] DevTools → Application → IndexedDB/OPFS: a collection `ColdigomPraiseCache` tem 1690 linhas; `localStorage`/prefs com `coldigomCatalogEtag`.
- [ ] Recarregar de novo: Network mostra `GET /api/plpcg/catalog` a responder `304` (só quando passaram ≥ 30 min; forçar limpando `coldigomCatalogSyncedAt` nas prefs).
- [ ] Home: pesquisar `tempo` — resultados PLPCG primeiro, depois cards Coldigom (preto) vindos do índice local, **antes** de a página remota chegar; pesquisar um número (`10`) mostra o Coldigom com número exato no topo do bloco Coldigom.
- [ ] Card Coldigom → sheet: aba «Letra» presente quando o praise tem letra; tocar abre `/letra?praiseId=…` com o texto e o título; A−/A+ mudam o corpo e sobrevivem a um reload.
- [ ] Modo offline (DevTools → Network → Offline) + reload (só válido com o shell offline da spec `2026-09-14-pwa-shell-offline-design.md`; sem ele, testar no nativo): pesquisa Coldigom continua a responder; sheet mostra metadados e lista de materiais; letra abre.

**iPhone real (build homolog):**
- [ ] Primeiro boot com rede: pesquisa Coldigom local funciona após ~2 s (hidratação + sync); anotar `[coldigom] catálogo hidratado … ms` no console do Xcode — deve ficar abaixo de 150 ms.
- [ ] Modo de avião → reabrir o app: pesquisa devolve Coldigom do índice; abrir sheet de um praise; abrir a letra.
- [ ] Voltar online, deixar o app em background ≥ 30 min (ou apagar `coldigomCatalogSyncedAt`), voltar: sync no foreground sem travar a UI.
