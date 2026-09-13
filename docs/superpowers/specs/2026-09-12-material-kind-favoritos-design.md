# Material Kinds favoritos — escolha no perfil e ordenação no sheet

**Data:** 2026-09-12
**Estado:** aprovado (brainstorm em sessão; decisões D1–D12 abaixo)
**Escopo:** tela nova no perfil (usuário logado) para escolher até **5** tipos de material Coldigom (`material_kinds`) em ordem de preferência; o sheet de materiais passa a listar esses tipos primeiro. Persistência por conta no Worker `plpcg-catalog` + cache local; sync offline-first.
**Repos:** só `coldigui` (Flutter + `workers/plpcg-catalog`). O coldigom **não muda**: o id do kind (`material_kind`) já sai em `GET /api/plpcg/praises` e no detalhe do praise, e a lista de kinds já existe em `GET /api/materials/kinds` (público, 104 tipos em pt-BR).

## 1. Problema

Um louvor Coldigom pode ter dezenas de materiais (17 PDFs, 14 áudios…). Quem toca trompete quer o "Trompete em Si bemol"; quem canta contralto quer a "Voz contralto" — e hoje cada um rola a aba do sheet toda vez. Não há preferência por pessoa: a ordem é a do servidor.

## 2. Decisões (fechadas)

| # | Decisão |
|---|---|
| D1 | **Só Coldigom.** Favoritos são ids de `material_kinds` do coldigom. Materiais do acervo PLPCG (`categoria` "Partitura", "Cifra nível I"…) **não** participam — `materialKindId` é `null` neles e nada muda. |
| D2 | **Persistência no Worker `plpcg-catalog`** (quem já autentica o Flutter e guarda playlists/audio-flags), não no coldigom. |
| D3 | **Documento único por usuário**, last-write-wins por `updatedAt`. Sem tombstone: "sem favoritos" é `kindIds: []`. |
| D4 | **Máximo 5** ids, sem duplicata, a ordem do array **é** a preferência (índice 0 = favorito nº 1). |
| D5 | **Somente usuário logado.** O provider lê a preferência do `googleSub` atual; deslogado → prefs vazias → sheet como hoje. Sessão persistida offline continua valendo. Trocar de conta troca a chave — sem "adoção" de dados sem dono. |
| D6 | **Cache local em SharedPreferences** (`material_kind_prefs.<googleSub>` → JSON do documento). Não Isar: é um documento de 5 ids; Isar exigiria collection, codegen e `StorageUnavailableException` para nada. |
| D7 | **Sync offline-first**: pull → adota remoto se mais novo (ou local ausente); senão push se `pendingPush`; `409` → adota o remoto. Dispara no login, na volta da conectividade (debounce 2 s) e após cada `save`. |
| D8 | **Tela própria** «Materiais favoritos» (rota `/materiais-favoritos` no branch de perfil), aberta por um tile no perfil visível só logado. Lista dos escolhidos com arrastar-para-reordenar e `×`; busca + lista dos restantes com `+`. **Salva automaticamente** a cada mudança. |
| D9 | **Ordenação no sheet: dentro de cada aba** (PDF por seção; Cifras, Gestos, Áudio, YouTube pela lista da aba). Favoritos sobem na ordem do rank; os demais mantêm a ordem atual (sort **estável**). Abas, aba inicial, `+`/`×`, rótulos: inalterados. Sem marcação visual de "favorito" no tile. |
| D10 | Rota acessível deslogado: mostra aviso + botão «Entrar com Google» em vez da lista. Isso mantém a tela testável e alcançável por URL na web em dev. |
| D11 | O Worker **não valida** os ids contra o catálogo do coldigom (não o conhece). O app só oferece ids vindos de `/api/materials/kinds`. |
| D12 | Rótulos dos kinds vêm do coldigom em pt-BR (não há `en` no endpoint). Não inventar tradução; strings **da tela** são l10n `pt`/`en` normalmente. |

## 3. Worker `plpcg-catalog`

### 3.1 Migração `migrations/0010_create_user_material_kind_prefs.sql`

```sql
CREATE TABLE user_material_kind_prefs (
  user_id     TEXT PRIMARY KEY,   -- users.google_sub
  kind_ids    TEXT NOT NULL,      -- JSON array de até 5 UUIDs; ordem = preferência
  updated_at  TEXT NOT NULL,      -- ISO 8601, vem do cliente (last-write-wins)
  version     INTEGER NOT NULL DEFAULT 1
);
```

### 3.2 Rotas (`src/material_kind_prefs/handlers.ts`)

Ambas via `withAuth` (Bearer Google `id_token`), CORS modo `playlists` em `corsModeForPath`, despacho em `index.ts` ao lado de `/api/audio-flags`.

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| `GET` | `/api/material-kind-prefs` | — | `200 { kindIds, updatedAt, version }`; `204` sem linha |
| `PUT` | `/api/material-kind-prefs` | `{ kindIds: string[], updatedAt: string }` | `200` documento gravado; `409` documento remoto (quando `remote.updated_at > body.updatedAt`); `400` inválido |

Validação do `PUT`: `kindIds` é array de 0–5 strings não vazias (≤ 128 chars cada), sem duplicata; `updatedAt` ISO válido (`isIsoDate` já existe nos audio-flags). Upsert: cria com `version = 1`; atualiza com `version + 1`. Sem `DELETE`.

Documentar as duas rotas na tabela do `workers/plpcg-catalog/README.md` e o endpoint em `ApiEndpoints`.

### 3.3 Testes (`handlers.test.ts`, `node --test`)

- PUT cria → `version 1`, ecoa `kindIds` e `updatedAt`.
- PUT mais novo → sobrescreve, `version 2`.
- PUT mais velho → `409` com o documento remoto.
- PUT com 6 ids / duplicata / não-array / `updatedAt` inválido → `400`.
- GET sem linha → `204`; com linha → documento.

## 4. App — feature `lib/features/material_kind_prefs/`

Layout domain/data/presentation, espelhando `features/audio_flags`.

### 4.1 Domínio

- `MaterialKindPrefs { List<String> kindIds; DateTime updatedAt; bool pendingPush }` — imutável, `copyWith`, `toJson`/`fromJson`, `static const empty`. Invariante: `kindIds.length <= kMaxFavoriteMaterialKinds (5)`, sem duplicata; construtor de fábrica `MaterialKindPrefs.validated(...)` lança `ArgumentError` fora disso.
- `MaterialKindPrefsRepository` (abstract): `Future<MaterialKindPrefs?> read(String sub)`, `Future<void> write(String sub, MaterialKindPrefs prefs)`.
- `orderByFavoriteKinds<T>(List<T> items, Map<String, int> rank, {required String? Function(T) kindIdOf}) → List<T>` — função pura, sort estável: itens cujo `kindIdOf(item)` está em `rank` primeiro (ordenados pelo rank), demais na ordem original; `rank` vazio devolve a própria lista. Genérica por seletor para servir tanto `CatalogMaterial` quanto `LouvorMaterialEntry` (aba PDF).
- `SyncMaterialKindPrefs` (usecase) — recebe repository + remote; `run({required String idToken, required String sub})`:
  1. `remote.fetch(idToken)`; falha de rede → registra `pullError`, segue.
  2. Se remoto existe e (`local == null` ou `remote.updatedAt > local.updatedAt`) → grava remoto localmente com `pendingPush: false` → `pulled`.
  3. Senão, se `local.pendingPush` → `remote.put(idToken, local)`; sucesso → grava com `pendingPush: false` → `pushed`; `MaterialKindPrefsConflict(remote)` → grava remoto → `conflictAdopted`; outra falha → `pushError`, local segue pendente.
  4. Resultado `MaterialKindPrefsSyncResult { outcome: pulled|pushed|conflictAdopted|noop|skipped, pullError, pushError }`.

### 4.2 Dados

- `MaterialKindPrefsLocalDatasource` (SharedPreferences): chave `material_kind_prefs.<sub>`; JSON `{kindIds, updatedAt, pendingPush}`. Leitura tolerante: JSON ilegível → `null` + `debugPrint`.
- `MaterialKindPrefsRemoteDatasource` (Dio do `dioProvider` + Bearer): `fetch` → `MaterialKindPrefs?` (`204` → `null`); `put` → documento, `409` → lança `MaterialKindPrefsConflict(remote)`; `401/403` → `AuthUnauthorizedException` (mesma classe do auth).
- `ApiEndpoints.materialKindPrefs = '/api/material-kind-prefs'`.
- Providers em `data/providers/material_kind_prefs_providers.dart`: local, repository, remote, `syncMaterialKindPrefsProvider`.

### 4.3 Id do kind nos materiais Coldigom

- `MaterialDto.materialKindId` ← `json['material_kind']` (String?, tolerante a null).
- `Louvor`, `AudioTrack`, `ChordMaterial`, `GestureMaterial`, `YoutubeMaterial`: campo `String? materialKindId` (default `null`; `Louvor.fromManifest` ganha o parâmetro opcional). `LouvorCache` (Isar) **não muda** — só cacheia PLPCG.
- `ColdigomLouvorAdapter` preenche o campo nas cinco conversões.
- `CatalogMaterial` ganha `String? get materialKindId`, implementado em cada invólucro.

### 4.4 Presentation — providers

- `coldigomMaterialKindsProvider` — `FutureProvider<List<ColdigomMaterialKindDto>>` sobre `fetchMaterialKinds()` (já existe no datasource). `keepAlive`: a lista muda raramente.
- `materialKindPrefsProvider` — `AsyncNotifier<MaterialKindPrefs>`: observa `authStateProvider`; usuário `null` → `MaterialKindPrefs.empty`; senão `repository.read(sub) ?? empty`. `save(List<String> kindIds)`: valida, grava com `updatedAt = now (UTC)`, `pendingPush = true`, atualiza o estado, e pede `materialKindPrefsSyncProvider.notifier.sync()` (não aguarda o resultado para devolver).
- `favoriteMaterialKindRankProvider` — `Provider<Map<String, int>>` derivado de `materialKindPrefsProvider` (`{}` enquanto carrega ou deslogado).
- `materialKindPrefsSyncProvider` — `Notifier<MaterialKindPrefsSyncState { isSyncing, lastResult, lastErrorCause }>`, cópia enxuta do `AudioFlagSyncNotifier`: `ref.listen(authStateProvider, fireImmediately: true)` dispara sync ao entrar um `sub` novo; `connectivityStreamProvider` offline→online dispara com `reconnectDebounce` 2 s; `sync()` deduplica in-flight; após sync que altera o local, `ref.invalidate(materialKindPrefsProvider)`.

### 4.5 Presentation — tela `FavoriteMaterialKindsScreen`

Rota `RoutePaths.favoriteMaterialKinds = '/materiais-favoritos'`, `GoRoute` no branch `AppTab.profile`. Largura máxima 896 como o perfil; `AppBar` com título l10n.

Deslogado (D10): card com texto «Entre com Google para escolher seus materiais favoritos» + `GoogleSignInButton`.

Logado:
1. Texto de ajuda: «Escolha até 5 tipos de material. Eles aparecem primeiro ao abrir um louvor.»
2. **Seus favoritos (N de 5)** — `ReorderableListView` (`buildDefaultDragHandles: false`, handle `Icons.drag_handle` à direita): posição, rótulo do kind, `×` (`Icons.close`). Vazio → «Nenhum favorito ainda». Rótulo desconhecido (id fora da lista carregada) → «Desconhecido».
3. **Adicionar** — `TextField` de busca (filtra por nome, sem acento/caixa via `LouvorSearchTokens.normalize`), lista dos kinds não escolhidos com `+` (`Icons.add_circle_outline`); com 5 escolhidos os `+` ficam desabilitados e aparece «Limite de 5 — remova um para trocar».
4. Cada ação chama `save` com a lista nova; sem botão «Salvar».
5. Estado do sync: se `lastErrorCause != null` ou `pendingPush`, linha discreta «Sincronização pendente» (`userMessageFor(l10n, cause)` quando há causa). Nunca bloqueia a edição.
6. Kinds: carregando → `CircularProgressIndicator`; erro → linha com retry (`ref.invalidate(coldigomMaterialKindsProvider)`); os favoritos já salvos continuam listados pelo id.

Perfil (`ProfileScreen`): `_ProfilePageTile(icon: Icons.star_outline, title: l10n.favoriteMaterialKindsTitle)` entre «Listas» e «Offline», **só** quando `auth.asData?.value != null`. Sem subtítulo nesta entrega.

### 4.6 Sheet de materiais (`MaterialSheet`)

`final rank = ref.watch(favoriteMaterialKindRankProvider);` e:

- `_pdfTiles`: por seção, `orderByFavoriteKinds(section.materials, rank, kindIdOf: (e) => e.louvor.materialKindId)` — reordena as `entries` (o ícone do PDF vem de `LouvorMaterialIcons.forEntry(entry)`, então é a entry que se ordena, não o invólucro).
- `_chordTiles`: `orderByFavoriteKinds(availableChords, rank, kindIdOf: (c) => c.materialKindId)`.
- Gestos, Áudio, YouTube: idem sobre as listas da aba.

Nada mais muda no sheet.

## 5. l10n (pt / en)

Chaves novas: `favoriteMaterialKindsTitle`, `favoriteMaterialKindsHelp`, `favoriteMaterialKindsYours(count, max)`, `favoriteMaterialKindsEmpty`, `favoriteMaterialKindsAdd`, `favoriteMaterialKindsSearchHint`, `favoriteMaterialKindsLimitReached`, `favoriteMaterialKindsSignInPrompt`, `favoriteMaterialKindsSyncPending`, `favoriteMaterialKindsRemoveTooltip`, `favoriteMaterialKindsAddTooltip`, `favoriteMaterialKindsUnknownKind`, `favoriteMaterialKindsLoadError`.

## 6. Fora do escopo

- `LouvorGroup.primaryLouvor` (atalho `+` do card) e a fila `group.audioTracks` continuam ignorando favoritos.
- Aba inicial do sheet pela família do favorito nº 1.
- Marcação visual de favorito no tile.
- Favoritos para o acervo PLPCG (mapeamento de rótulos).
- Tradução `en` dos nomes dos kinds (depende do coldigom).
- Mais de 5 favoritos / favoritos por instrumento com fallback.

## 7. Testes

**Worker:** ver 3.3.

**Flutter unit** (`test/unit/features/material_kind_prefs/`):
- `order_by_favorite_kinds_test.dart` — rank vazio devolve a mesma lista; favoritos sobem por rank; sort estável entre não-favoritos e entre favoritos de mesmo kind; `materialKindId` null fica na ordem.
- `material_kind_prefs_test.dart` — `validated` rejeita 6 ids e duplicata; round-trip JSON.
- `material_kind_prefs_local_datasource_test.dart` — `SharedPreferences.setMockInitialValues`; chave por `sub`; JSON corrompido → `null`.
- `material_kind_prefs_remote_datasource_test.dart` — Dio adapter fake: `200`, `204` → null, `409` → `MaterialKindPrefsConflict`, `401` → `AuthUnauthorizedException`.
- `sync_material_kind_prefs_test.dart` — remoto mais novo adota; local pendente faz PUT; `409` adota o remoto; pull falha e push segue; nada pendente e remoto igual → `noop`.
- `material_kind_prefs_provider_test.dart` — deslogado → `empty`; logado lê a chave do `sub`; `save` grava `pendingPush` e dispara sync; `favoriteMaterialKindRankProvider` deriva o rank.
- `material_kind_prefs_sync_provider_test.dart` — login dispara sync uma vez por `sub`; reconexão dispara com debounce; deslogado não toca a rede.
- `coldigom_louvor_adapter_test.dart` (existente) — `materialKindId` preenchido nas cinco famílias.

**Flutter widget:**
- `test/widget/features/material_kind_prefs/favorite_material_kinds_screen_test.dart` — `ProviderScope` com `authStateProvider` (usuário fake) e `coldigomMaterialKindsProvider` (kinds fixos): adiciona até 5 e o 6º `+` fica desabilitado; remove; reordena (`drag` do handle) e a ordem salva reflete; busca filtra sem acento; deslogado mostra aviso + botão.
- `test/widget/features/app_shell/profile_screen_test.dart` (existente ou novo) — tile aparece só logado.
- `test/widget/features/catalog/material_sheet_favorites_test.dart` — com rank `{sopranoId: 0, partituraId: 1}` os tiles sobem na ordem em cada aba; sem rank a ordem atual permanece; grupo PLPCG intacto.

**Manual (web dev):** `npm run dev` + `npm run db:migrate:local` no Worker; `dart_defines/plpcg.dev.json` com `PLPCG_API_BASE_URL=http://127.0.0.1:8787`; login Google real; abrir `/materiais-favoritos`; escolher; abrir um louvor Coldigom e conferir o sheet; segundo navegador para ver o pull.

## 8. Entrega

- Branch `feat/material-kind-favoritos` (worktree `.claude/worktrees/material-kind-favoritos`) a partir de `web/integration`.
- Passos que ficam com o dono do deploy: `npm run db:migrate:remote` e `npm run deploy` do Worker antes de publicar a web.

## 9. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Kind renomeado/removido no coldigom | O app guarda ids; rótulo cai em «Desconhecido» e o item pode ser removido na tela. |
| Dois aparelhos editando offline | Last-write-wins por `updatedAt` (documento inteiro) — aceitável para uma preferência de 5 itens. |
| `updatedAt` do cliente com relógio errado | Mesmo risco já aceito em playlists/audio-flags; documento único torna o dano trivial (re-salvar). |
| Sheet mais lento | `orderByFavoriteKinds` é O(n log n) sobre dezenas de itens e curto-circuita com rank vazio. |
