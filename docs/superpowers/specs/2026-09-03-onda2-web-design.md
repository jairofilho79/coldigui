# Onda 2 — web: ordem única de ponta a ponta, material unificado e estabilidade

**Criado em:** 2026-09-03 · **Branch:** `web/integration` @ `6ffcdb3` (onda 1 integrada)
**Origem:** seção H.4 de `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md` (próxima onda recomendada), aprovada pelo dono do produto ("Pode seguir com os recomendados").
**Autoridade:** `PRODUCT.md` (princípios 1–4), `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md` (§6–§7).

Este spec decompõe a onda em três subprojetos com contratos próprios. As decisões de desenho foram tomadas pelo executor e estão marcadas **[decisão]**; as duas marcadas **[decisão — revisar]** mudam formato de dados que sai do dispositivo e merecem o olhar do dono do produto antes de publicar.

---

## Subprojeto A — D2 fatia 2: ordem única com `kind`, do Isar ao Worker

### A.0 Problema

A fatia 1 (onda 1) deu à playlist uma ordem única `items: List<String>`, mas:
- o **tipo** de cada entrada ainda é inferido pela extensão do id (`materialIdKindOf`), com o remendo `declaredAudioIds`;
- o Worker **descarta** `items`/`schemaVersion` no PUT e responde v1 em todo GET, então qualquer pull achata a ordem;
- a URL de compartilhamento leva duas CSVs (`sharepdfs`, `shareaudios`) e perde a ordem intercalada.

### A.1 Modelo de domínio

**[decisão]** `PlaylistEntry { String id; MaterialKind kind; }` em `lib/features/playlists/domain/entities/playlist_entry.dart` (value object, `==`/`hashCode`, `toJson`/`fromJson`).

- `SavedPlaylist.entries: List<PlaylistEntry>` é a **única** fonte de verdade de conteúdo e ordem.
- Derivados: `items` (`entries.map(id)`), `pdfIds` (`kind != audio`), `audioIds` (`kind == audio`). `declaredAudioIds`, `warnIfNotAudio`, `isPdfFaceItem` e `isAudioFaceItem` **saem**.
- Construtores de compatibilidade continuam: `SavedPlaylist(pdfIds:, audioIds:)` monta `entries` com `kind` = `materialIdKindOf(id)` para `pdfIds` e `MaterialKind.audio` para `audioIds`; `SavedPlaylist(items:)` classifica cada id por extensão. Novo construtor canônico recebe `entries`.
- Regra de faces: face de partituras = `kind ∈ {pdf, chord, gesture, unknown, youtube}`; face de áudio = `kind == audio`. `youtube` fica na face de partituras até existir "face de vídeo" (fora de escopo).
- `replaceSubset`/`nextItemsWith` passam a operar sobre `entries` com o predicado `belongs = (e) => e.kind == audio` (ou `!= audio`). Um id que chega por `audioIds:` entra com `kind: audio`; por `pdfIds:` entra com `materialIdKindOf(id)` (nunca `audio`). Sem `assert` vazio: o predicado é por `kind`, então é sempre verdadeiro por construção e o `assert` é removido.
- `copyWith(pdfIds:, audioIds:)` mantém a semântica da fatia 1 (regra de slots documentada e testada); novo `copyWith(entries:)` substitui tudo.

### A.2 Isar

**[decisão]** `Playlist` ganha `List<String> itemKinds` (nomes de `MaterialKind`), **declarado por último** (mesma técnica da fatia 1: índice de propriedade novo no fim). Sem objeto embutido: lista paralela a `items`, invariante `itemKinds.length == items.length`.

- Migração lazy na leitura (em `PlaylistLocalDatasource._migrated`, mesma transação): se `itemKinds.length != items.length` → recomputar: `kind = audioIds.contains(id) ? audio : materialIdKindOf(id)` e persistir. Idempotente; não toca `updatedAt`/`version`/`syncStatus`.
- `pdfIds`/`audioIds` continuam gravados por compatibilidade (leitura por builds antigos do mesmo dispositivo), sempre reprojetados de `entries` em toda escrita (`_toRow`) — inclusive em `create()` (fecha o minor "compat columns verbatim").
- `insert()`/`update()` com Isar indisponível **lançam** `StorageUnavailableException` (nova, em `lib/core/database/storage_unavailable_exception.dart`) em vez de no-op. `PlaylistRepositoryImpl.create()` deixa de devolver um id que não foi persistido (fecha a cadeia B5 do deep link).
- Teste de evolução de schema (engine sqlite) igual ao da fatia 1: schema legado sem `itemKinds` → reabre → migração lazy.

### A.3 Wire v2 definitivo

**[decisão — revisar]** Como nenhum Worker jamais persistiu v2, o formato v2 é fechado agora com `items` como **objetos**:

```json
{
  "schemaVersion": 2,
  "items": [{ "id": "Q29s…", "kind": "pdf" }, { "id": "YXNz…", "kind": "audio" }],
  "pdfIds": ["Q29s…"], "audioIds": ["YXNz…"], "...": "demais campos inalterados"
}
```

- `kind` ∈ `pdf | chord | audio | youtube | gesture | unknown` (strings de `MaterialKind.name`).
- Cliente **envia** v2 com `items` (objetos) + `pdfIds`/`audioIds` derivados (leitores v1 continuam funcionando).
- Cliente **lê**: sem `schemaVersion`/`items` → v1 (`entries` de `pdfIds` por extensão + `audioIds` como áudio); `items` com **strings** (rascunho v2 da fatia 1, só existe em Isar local, nunca no Worker) → classifica por extensão + `audioIds` declarados; `items` com objetos → usa `kind` do wire, normalizado por `resolveWireKind(kind, id)`: `audio` fica `audio`; `pdf`/`unknown` viram `materialIdKindOf(id)` quando este devolve `chord`/`gesture` (mais específico), senão ficam como vieram; valores desconhecidos de `kind` → `unknown`.
- `RemotePlaylist.entries` substitui `items`+`declaredAudioIds`.
- `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md` §7 atualizado (remove o aviso "client-local", descreve objetos e a normalização).

### A.4 Worker `plpcg-catalog`

- Migração `0007_add_playlist_items.sql`: `ALTER TABLE user_playlists ADD COLUMN items TEXT NOT NULL DEFAULT '[]'`.
- `validatePutBody`: `schemaVersion` opcional (inteiro ≥ 1), `items` opcional (array de `{id: string não vazio, kind: string ∈ conjunto permitido}`); `pdfIds` continua obrigatório para v1; v2 pode mandar só `items` (então `pdfIds`/`audioIds` são derivados no Worker: `kind == audio` → `audio_ids`, senão `pdf_ids`).
- Persistência: `items` é gravado como JSON quando presente; quando ausente (cliente v1), `items` é derivado das duas listas com `kind: pdf` para `pdf_ids` e `kind: audio` para `audio_ids` (o cliente normaliza `pdf` → `chord`/`gesture` pela extensão, ver A.3).
- `rowToJson` devolve `schemaVersion: 2`, `items` (objetos) e as duas listas.
- Regra de conflito e resurrect **inalteradas** (fora de escopo; B9 trata o 409 no cliente).
- CORS: `Access-Control-Expose-Headers` também no modo `playlists` (não é necessário para o body, mas fecha a assimetria com o modo catálogo).
- `matchesEtag(ifNoneMatch, etag)`: aceita lista separada por vírgula e `*`, com/sem `W/`.
- Testes `node:test`: `validatePutBody` (v1, v2, kind inválido, id vazio), derivação `itemsFromLegacy`/`listsFromItems`, `rowToJson` v2, `matchesEtag` (único, lista, `*`, weak), e `upsertPlaylist` com um **fake D1 mínimo** (`prepare().bind().first()/run()/all()` sobre um `Map` em memória) cobrindo INSERT v2, UPDATE v2 e PUT v1 sem `items`.
- CI: job `worker` em `.github/workflows/web.yml` (`npm ci` + `npm test` em `workers/plpcg-catalog`). **Não** aplica migração remota (isso é deploy, feito pelo dono).

### A.5 URL de compartilhamento v2

**[decisão — revisar]** Novo parâmetro `shareitems` com a ordem única e o tipo, mantendo os legados para compatibilidade com apps antigos:

```
/?shareitems=p:Q29s…,a:YXNz…,c:QXZ1…&sharename=Culto%20domingo&sharepdfs=Q29s…,QXZ1…&shareaudios=YXNz…
```

- Prefixos: `p` pdf, `c` chord, `a` audio, `y` youtube, `g` gesture, `u` unknown. Ids já são base64url (sem `,` nem `:`).
- `buildPlaylistShareLocation` emite `shareitems` + `sharename` + os dois legados (a URL fica maior; encurtador via Worker é D7, próxima onda).
- `parsePlaylistShareParams` prefere `shareitems` quando presente e válido; senão cai nos legados. `PlaylistShareParams` ganha `shareItems` (nullable) e `entries` derivadas.
- `safeQueryParameters(uri)` (B7): decodifica sem lançar em `%` malformado (tenta `queryParametersAll`; em `FormatException` faz parse manual componente a componente e descarta o inválido). Usado pelo builder, pelo `deep_link_initial_uri` e pelo router.
- `ImportSharedPlaylistFromUrl` cria a playlist com `entries` e carrega o carousel se houver qualquer entrada de partitura (PDF/cifra/gesto) — não só `pdfIds.isNotEmpty`.
- Fingerprint de dedupe do deep link passa a incluir `shareitems`.

### A.6 Consumidores das faces

- `PlaylistMediaFace` **permanece** como preferência de visualização (toggle inalterado). Todos os consumidores listados na exploração (tile, chips, face bar, painel de áudio, `active_playlist_sync`, `load_playlist_into_carousel`, share actions, `open_audio_in_player`) passam a derivar de `entries`/`kind`; nenhum lê `materialIdKindOf` diretamente para decidir face.
- Carousel continua **PDF-only** (`CarouselEntry{pdfId}`): D3 (carousel como view da lista) fica para a próxima onda e é o ponto em que a face vira filtro puro. A fila de áudio do tile/painel usa `audioIds` derivado (`kind == audio`) — inalterado em comportamento.
- Folheto/compartilhar-da-barra continuam PDF-only (D8, próxima onda).

### A.7 Sync (B8/B9) — depende de A.1–A.4

- `RemotePlaylist.fromJson` tolerante: campo obrigatório ausente/inválido → `FormatException` **por item**; `SyncPlaylists._fetch` filtra os inválidos com `debugPrint('[playlists] registro remoto ignorado: …')` e segue.
- Fase de pull com `try/catch` próprio: falha no pull **não** impede o push nem os tombstones.
- `PlaylistSyncState.lastError: String?` (mensagem já traduzida via `userMessageFor`, ver C.5) exibido como banner discreto na tela de listas, com "Tentar novamente".
- `_lastSyncedSub` persistido em `SharedPreferences` (`playlist_sync.last_synced_sub`): `syncAfterLogin` (com `markAllSavedPendingPush`) só roda quando o `sub` muda; boot com o mesmo `sub` faz `sync()` simples.
- 409: `PlaylistRemoteDatasource.upsert` lança `PlaylistConflictException(remote)`; `SyncPlaylists` aplica **last-write-wins por `updatedAt`**: se o remoto é mais novo → grava local com `synced`; senão re-envia com `version` do remoto (uma tentativa) e, se falhar de novo, marca `PlaylistSyncStatus.conflict` e segue (o banner mostra "1 lista em conflito").
- Tombstones: no máximo 3 tentativas por boot por playlist (contador em memória); falhas ficam logadas.

---

## Subprojeto B — E1 fatia 2 + E3: `LouvorGroup` sobre `CatalogMaterial`, um sheet, uma fonte

### B.0 Problema

`LouvorGroup` guarda quatro listas por tipo; a UI tem dois sheets quase iguais (731 + 386 linhas), ramos `isColdigom` em card e no botão de troca de material, 13 arquivos fora de `features/coldigom` importando dele, e `openMaterialProvider.open` sem chamador em produção.

### B.1 `LouvorGroup` unificado

**[decisão]** `LouvorGroup` passa a guardar `sections` (PDFs por classificação; a UI precisa das seções) **e** `List<CatalogMaterial> extras` (cifras, áudios, YouTube). `chordMaterials`, `audioTracks`, `youtubeMaterials` viram **getters derivados** (filtram `extras` por tipo e desembrulham), então os consumidores atuais não mudam. `materials` = PDFs por seção + `extras` na ordem canônica. `withColdigomMeta`, `fromLouvores`, `_buildGroup` adaptados; `ColdigomSearchRepositoryImpl` monta `extras` a partir do adapter. `flatPdfMaterials` permanece (o sheet Coldigom depende dele) e o sheet único passa a usar `sections`.

### B.2 Resolver de material por id

`lib/features/catalog/domain/usecases/resolve_catalog_material.dart`: `Future<CatalogMaterial?> resolveCatalogMaterial(ref, String materialId)` — `pdf` → `Louvor` do manifest ou do cache Coldigom (via `findLouvorByPdfIdWithColdigom`); `chord` → cache de cifras; `audio` → cache de áudios; `youtube` → `null` (ids de YouTube não são endereçáveis); `gesture`/`unknown` → `null`. Os dois desvios de cifra (`playlist_list_tile.dart:281`, `reader_carousel_actions_provider.dart:46`) passam a resolver o material e chamar `openMaterialProvider.open` quando o material **não** é PDF; o caminho PDF (que já passa por `resolvePdfForReaderProvider`/`openPdfInReaderProvider` com pré-fetch e skeleton) fica como está. `chordReaderLocationFor` sobrevive só como utilitário de rota da cifra (sem o `null` ambíguo: devolve `ChordRoute?` com `isChord` explícito).

### B.3 Um só sheet de materiais

**[decisão]** `MaterialSheet(group)` em `lib/features/catalog/presentation/widgets/material_sheet.dart` substitui `louvor_material_sheet.dart` e `coldigom_material_sheet.dart`: renderiza `group.sections` (PDF), depois cifras, áudios e YouTube a partir de `group.extras`, com o cabeçalho de metadados Coldigom quando `coldigomMeta != null`. Toque em qualquer item → `ref.read(openMaterialProvider).open(context, ref, material)`. Handlers de trailing (adicionar à lista, compartilhar, salvar) são componentes reaproveitados dos sheets atuais, extraídos para `material_sheet_actions.dart`. Os dois `showXMaterialSheet` viram um `showMaterialSheet(context, ref, group)`; os ramos `isColdigom` em `louvor_group_card.dart` e `carousel_swap_material_button.dart` colapsam para `groupWithColdigomMeta(ref, group)` + `showMaterialSheet`. Testes de widget dos dois sheets migram para o sheet único (mesmas asserções de conteúdo e ações).

### B.4 Porta `CatalogSource` (E3, fatia 1)

`lib/features/catalog/domain/ports/catalog_source.dart`: `abstract class CatalogSource { Future<LouvorGroup?> groupById(String groupId); Future<CatalogMaterial?> materialById(String materialId); Future<LouvorGroup?> groupForMaterial(String materialId); }` com `PlpcgCatalogSource` (manifest + `findLouvorGroupByPdfId`) e `ColdigomCatalogSource` (caches + `ensureColdigomPraiseMaterialsCached`), compostas por `CompositeCatalogSource` que despacha por `louvorDataSourceFromPdfId`. `resolveCatalogMaterial` (B.2) e `findSwapMaterialGroup` passam a usar a porta; `find_louvor_group_by_pdf_id.dart` encolhe para a implementação PLPCG. A reescrita da busca da Home (`HomeSearchState` imutável em `AsyncNotifier`, cancelamento, memo) **fica para a próxima onda** — este spec só cobre a porta de leitura por id.

### B.5 Limpeza

- Apagar `LouvorMaterialIcons.forCategory` (deprecado, sem chamadores); `LouvorMaterialIcons.forEntry(LouvorMaterialEntry)`/`forMaterial(CatalogMaterial)` substituem os três `forKind(kindForCategory(...))` idênticos.
- `_kindLabel`/`_buildKindList` do sheet Coldigom desaparecem com o sheet.
- Renomear `pdfId` → `materialId` **só** nos contratos novos (`PlaylistEntry`, `CatalogSource`, `resolveCatalogMaterial`). O carousel (`CarouselEntry.pdfId`, índice único no Isar) e as rotas do leitor mantêm `pdfId` até D3, quando o carousel deixa de ser persistência própria.

---

## Subprojeto C — Estabilidade B5–B17 + E9

Itens S/M, independentes, executáveis em paralelo com o subprojeto A (arquivos disjuntos), exceto A.7 (sync) que depende de A.

### C.1 Isar indisponível e exclusão mútua offline (B5 + B14)

- `StorageUnavailableException` (core) lançada pelas **escritas** de `OfflinePdfLocalDatasource` e `PlaylistLocalDatasource` quando `_isar == null`; leituras continuam devolvendo vazio.
- `ReconcileOfflineIndex`: recebe `isIndexAvailable`; reconcile **completo** com índice indisponível → aborta com resultado `skipped(reason)`; reconcile completo com índice **vazio** mas store com arquivos → também `skipped` (nunca apagar tudo por índice vazio); reconcile escopado continua, mas só apaga órfãos do escopo.
- `offlineMaintenanceLockProvider` (`Notifier<OfflineMaintenanceOwner?>`): bulk (start/resume), faltantes, limpar e reconcile adquirem antes de rodar; `requestReconcile` e `requestReconcileDebounced` devolvem sem fazer nada enquanto o lock pertence a outro dono, e o bulk pede um reconcile escopado ao terminar.
- Bulk e faltantes com Isar indisponível → estado `failed` com `offlineStorageUnavailable` (l10n) antes de baixar um byte.

### C.2 Download em massa robusto (B13)

- Cancel do usuário → `OfflineBulkDownloadStatus.cancelled` (não `failed`), sem retry.
- `cleanOrphanedTempFiles` só apaga `.tmp` cujo nome não corresponde a um checkpoint ativo, e roda no início de cada download (não só na criação do provider).
- ZIP em cache: além do tamanho, validar assinatura (`PK\x03\x04`); `FormatException` na extração → apagar o ZIP e baixar de novo uma vez.
- Watchdog de stall: timer reiniciado a cada chunk recebido; sem bytes por `OfflineConfig.zipDownloadStallTimeout` (90 s) → cancela o request e conta como tentativa retryável.

### C.3 Leitor (B6)

`pdfReaderSessionProvider`: após cada `await`, `if (!ref.mounted) { handle.dispose(); return; }`; `bindHandle`/`onDispose` só com o provider vivo. Teste com `Completer` gate + `container.dispose()` durante o `await`.

### C.4 Deep link (B7)

- `safeQueryParameters` (definido em A.5, `lib/core/utils/safe_query_parameters.dart`) usado por `deep_link_initial_uri.dart` e `app_router.dart`.
- `DeepLinkListenerState._handleUri`: `on Object` → snackbar `deepLinkImportFailed` (l10n) + `debugPrint('[deep-link] …')`; `SyncDeepLinkState` captura `StorageUnavailableException` → mensagem própria (`offlineStorageUnavailable`) e qualquer outra exceção → `deepLinkImportFailed`.
- Dedupe por (fingerprint, instante): a mesma URL só é reprocessada após 3 s.

### C.5 Token e rede (B10 + B16)

- `AuthUser.expiresAt` (do claim `exp` do `id_token`); `isExpired`/`expiresSoon`.
- `AuthRefreshInterceptor` (Dio, `lib/core/network/auth_refresh_interceptor.dart`): em 401 numa rota autenticada, chama `authStateProvider.notifier.refreshIdToken()` (que usa `attemptLightweightAuthentication`) e repete **uma** vez; se falhar → estado `sessionExpired` no `authStateProvider` + banner "Sessão expirada · entrar de novo" no perfil/listas.
- `RetryInterceptor` (`lib/core/network/retry_interceptor.dart`): GET idempotente, até 2 retentativas com backoff 300/900 ms em erro de conexão/timeout/5xx; aplicado aos dois `Dio`.
- `userMessageFor(AppLocalizations, Object error)` (`lib/core/errors/user_message_for.dart`): mapeia `DioException` (timeout, sem conexão, 5xx, 401/403), `StorageUnavailableException`, `AuthUnauthorizedException`, exceções de PDF já conhecidas, e fallback genérico; substitui os dois `$e` crus (`profile_screen.dart`, `louvor_group_card.dart`) e é a base do `lastError` do sync (A.7).

### C.6 Áudio (B11)

- `_applyQueue` com `_generation++` e checagem após cada `await` (descarta resultado de chamada superada).
- `player.errorStream` (just_audio) assinado → `errorMessage` + `playing: false`; a face de áudio e o player mostram a mensagem com botão "Tentar de novo" (re-`playQueue` do índice atual).
- `playPause`/`seek`/`skip*`: `try/on Object` com `debugPrint('[audio] …')` e `errorMessage`.

### C.7 Cifra (B12)

- `ChordContentDatasource.fetchSong`: `null` só em 404; demais erros propagam (`ChordFetchFailedException`).
- `chordSongProvider`: `keepAlive` só após sucesso; em erro o provider expõe `AsyncError` e o sheet mostra "indisponível · tentar de novo" (em vez de sumir).
- Cache persistente: coleção Isar `ChordContentCache { r2Key (unique), content, fetchedAt }` (`lib/core/database/collections/chord_content_cache.dart`, codegen); leitura cache-first com revalidação em background quando online; sem Isar, comportamento atual (memória).

### C.8 Catálogo: erro, retry e DTOs (B15)

- Home e Biblioteca: estado de erro com botão "Tentar novamente" (`ref.invalidate` do manifest/Coldigom) e recarga automática quando a conectividade volta (`connectivityStreamProvider` sobre `Connectivity().onConnectivityChanged`).
- Apagar `CatalogRefreshBanner` (código morto).
- `MaterialDto.fromJson` tolerante (`type` ausente → `unknown`, item inválido descartado com `debugPrint`), `PraiseDto` idem por material.
- Busca Coldigom falhando → linha "Coldigom indisponível · tentar de novo" nos resultados (novo `homeSearchColdigomErrorProvider`), em vez de lista vazia silenciosa.

### C.9 Boot e observabilidade (B17 + E9)

- `isarInitializerProvider`: `openAppIsar().timeout(15 s)` → modo degradado (o app abre sem Isar, com o aviso já existente).
- `lib/core/logging/app_logger.dart`: `AppLogger.of('feature')` com `debug/info/warn/error` (prefixo `[feature]`, `debugPrint` em debug, no-op em release salvo `error`), `ErrorReporter` (porta, implementação no-op) e `installErrorHandlers(reporter)` em `main.dart` (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`). Os 30 `debugPrint('[x]')` existentes **não** migram nesta onda (evita conflito com as outras tarefas); os arquivos novos desta onda já usam o logger.

---

## Ordem de execução e paralelismo

1. **Fase 1 (paralela, base = HEAD):** A.1–A.2 (modelo + Isar) → A.3–A.4 (wire + Worker) → A.5–A.6 (share URL + faces) em sequência num só fio; em paralelo, C.1, C.2, C.3, C.4, C.5, C.6, C.7, C.8, C.9 em worktrees com arquivos disjuntos.
2. **Fase 2:** A.7 (sync) depois de A e C.5 integrados.
3. **Fase 3 (sequencial):** B.1 → B.2 + B.4 → B.3 + B.5.
4. Revisão final da branch inteira + uma onda de correções, como na onda 1.

## Fora de escopo (próxima onda)

D3 (carousel como view da lista; face como filtro puro; rename `pdfId` → `materialId` nos contratos do carousel), D7 (short link), D8 (folheto com áudio), reescrita da busca da Home (E3 fatia 2), migração dos `debugPrint` para `AppLogger`, detecção de segunda aba (B17), performance A4–A14, UX C4–C14, D4–D6.

## Riscos aceitos

- URL de compartilhamento maior (três listas) até D7.
- Ids YouTube na face de partituras.
- Mudança de formato de `items` no wire antes de qualquer Worker tê-lo persistido (sem dado v2 em produção para migrar).
- Migração D1 (`0007`) precisa ser aplicada pelo dono (`npm run db:migrate:remote`) antes do deploy do Worker; até lá o Worker novo tolera a coluna ausente? **Não** — o Worker novo exige a coluna; a ordem é migrar e depois publicar.
