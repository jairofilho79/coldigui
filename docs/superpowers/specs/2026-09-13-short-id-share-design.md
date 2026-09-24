# Link curto por `shortId` — compartilhamento de listas PLPCG (admin, plpcjf, v2)

**Criado em:** 2026-09-13 · **Branch (coldigui):** `web/integration` @ `56790cd`
**Repositórios:** `plpcg-admin` (`main`), `plpcjf` (`main`), `coldigui` (Worker `plpcg-catalog` + app v2)
**Origem:** conversa com o dono do produto em 2026-09-13. Motivações: (1) o WhatsApp no iOS passou a entregar texto junto com imagem, o que dispensa o fluxo em dois passos do share; (2) o link de share é enorme porque cada `pdfId` é Base64 do caminho do arquivo; (3) o folheto deve carregar um QR code legível.
**Substitui parcialmente:** `2026-09-11-onda4-web-design.md` §C.2 (link curto `/l/<code>`) — o `/l/` **continua existindo** e não é tocado por esta spec; deixa de ser o caminho principal para listas PLPCG.

> **Substituído no v2 (2026-09-23)** pelo link por praise `?p=` do spec [fim da fonte PLPCG](./2026-09-23-fim-fonte-plpcg-design.md) §4: a §4 (coldigui) já não descreve o app — links `?s=` antigos mostram «link de versão antiga». A §3 (plpcjf) não é tocada.

---

## 0. Decisões fechadas

| # | Decisão |
|---|---|
| D1 | Cada material PDF do acervo PLPCG ganha um **`shortId`**: string hexadecimal minúscula, 4 caracteres hoje (`0000`–`ffff`), **atribuída uma vez, imutável, única, nunca reutilizada**. É **string, não número**: `"0000"` é um id válido; nenhum lado faz `parseInt`/`int.parse` nele, e a comparação é sempre textual. |
| D2 | Fonte da verdade: coluna `short_id` em `louvores` no D1 `plpcg-catalog` (compartilhado por `plpcg-admin` e pelo Worker `plpcg-catalog` do coldigui). O manifest do plpcjf e `/api/catalog/louvores` só ecoam o campo. |
| D3 | Dono da migration: **coldigui** (`workers/plpcg-catalog/migrations/0011_add_louvores_short_id.sql`), que já tem 10 migrations aplicadas e o único `db:migrate:remote`. O `plpcg-admin` recebe um **espelho** `worker/migrations/0003_add_short_id.sql` (mesmo SQL) exclusivamente para o D1 local dele, com comentário: «aplicar no remoto só via coldigui». |
| D4 | Backfill na própria migration, determinístico: `ROW_NUMBER() OVER (ORDER BY numero, nome, categoria, pdf_id)` → `printf('%04x', rn - 1)` a partir de `0000`. Contador para os próximos em `catalog_meta('short_id_next')` = `printf('%04x', COUNT(*))`. |
| D5 | Crescimento: quando o contador passar de `ffff`, `printf('%04x', 65536)` devolve `10000` naturalmente. **Não há truque de padding**: todos os leitores aceitam token `[0-9a-f]{4,8}`. |
| D6 | Coldigom fica fora: só materiais PLPCG (PDF) têm `shortId`. Login/encurtador `/l/` não entram nesta feature. |
| D7 | **Contrato do link** (§1) — único formato emitido para listas cujas entradas são **todas** PDFs PLPCG com `shortId`. Qualquer outra lista (material Coldigom, PDF ainda sem `shortId`) usa o formato longo de hoje, inalterado. **Emenda 2026-09-14:** o v2 **não emite mais** o formato longo em nenhuma opção de share; lista fora do PLPCG (Coldigom ou PDF sem `shortId`) vai só como folheto, sem link e sem QR, após aviso (`showColdigomShareDialog`). O parse do formato longo continua. plpcjf inalterado (sempre PLPCG). |
| D8 | Leitor de link: precisa do catálogo carregado para resolver `shortId → pdfId`. Token desconhecido é **ignorado com aviso de log**, não invalida a lista. Lista sem nenhum token resolvido = share inválido (aviso ao usuário, como hoje). |
| D9 | Share no v2 fica com **duas opções**: «Folheto» (PNG + `"{nome}\n\n{url}"` na legenda) e «Só o link». O modo WhatsApp em dois passos, seu diálogo e suas strings são removidos. `PlaylistShareOption.leaflet` continua no enum para o «Gerar folheto» do menu do tile. |
| D10 | Folheto (v2) ganha **QR code** do link **somente quando o link é do formato curto** (D7). Com link longo o folheto sai como hoje, sem QR — um QR de 1 000+ caracteres é ilegível em foto de tela. **Emenda 2026-09-14:** QR de 96 pt; PNG capturado com margem de 16 pt (`kLeafletCaptureMargin`) porque o WhatsApp iOS apara ~3% da borda de imagem enviada com legenda. plpcjf ganha o mesmo QR e a mesma legenda (`nome\n\nurl`). |

---

## 1. Contrato do link (vale para plpcjf e v2)

```
https://plpcg.com/?s=1a2f-0c3d-ffe1&n=Culto%20de%20domingo
```

| Item | Regra |
|---|---|
| `s` | `shortId`s em hex minúsculo separados por `-` (não sofre URL-encode, nunca ocorre em hex). Ordem = ordem da lista. Repetidos permitidos na leitura (o v2 repete louvor; o plpcjf deduplica no caminho curto porque a UI dele nunca repete louvor — `addToCarousel` recusa duplicata). |
| token | `[0-9a-f]{4,8}`. Maiúsculas são normalizadas para minúsculas na leitura; token fora do padrão é ignorado como desconhecido (D8). |
| `n` | nome da lista, `encodeURIComponent`. **Obrigatório** — é o que marca a URL como share, no lugar de `sharename`. |
| Prioridade na leitura | `s` presente (com `n`) → usa `s` e **ignora** `shareitems`/`sharepdfs`/`shareaudios`/`sharename` se vierem juntos. Sem `s` → comportamento atual. |
| Limpeza da URL | `s` e `n` entram na lista de params removidos após o import (ao lado de `sharepdfs`/`sharename`/`shareitems`/`shareaudios`). |
| Origem | `https://plpcg.com` (a mesma de hoje). O plpcjf é o destino do clique; o v2 recebe o link por deep link nativo ou colado no diálogo de importar. |
| Tamanho | 20 louvores ≈ 100 caracteres + nome. QR versão 5–6 (correção M). |

---

## 2. `plpcg-admin`

### 2.1 Schema e atribuição
- `worker/migrations/0003_add_short_id.sql` — espelho de D3/D4: `ALTER TABLE louvores ADD COLUMN short_id TEXT`; `UPDATE … FROM (ROW_NUMBER …)`; `CREATE UNIQUE INDEX idx_louvores_short_id ON louvores(short_id)`; `INSERT INTO catalog_meta('short_id_next', …)`. Cabeçalho em comentário: «Espelho de coldigui/workers/plpcg-catalog/migrations/0011. Só para D1 local. Remoto: aplicar via coldigui.»
- `LouvorRow.short_id: string | null`, `LouvorJson.shortId?: string`. Todos os `SELECT` de `services/d1-catalog.ts` passam a projetar `short_id`; `mapRow` copia.
- Novo `services/short-id.ts`: `nextShortId(db)` lê `catalog_meta('short_id_next')`, devolve o valor atual e grava o próximo (`printf('%04x', valor + 1)` via SQL, para não converter em número no TypeScript além do estritamente necessário — a conversão fica encapsulada aqui, e o retorno é sempre string). Executado num `db.batch` junto do `INSERT`, para não gastar id em inserção que falha.
- `insertLouvor` recebe o `shortId` de `nextShortId` — o cliente **não** escolhe `shortId`; o `POST /api/admin/louvores` ignora o campo se vier no corpo.
- `updateLouvor`: invariante — **`short_id` nunca muda**. No caminho de rename de `pdf_id` (hoje delete+insert), o `short_id` da linha antiga é carregado antes e gravado na nova, na mesma transação/batch.
- `deleteLouvor`: não devolve o id ao contador (D1: nunca reutilizado).

### 2.2 Manifest
- `toManifestEntry` inclui `shortId` quando presente (omite se `null`, para não publicar `"shortId": null`). Checksum muda por consequência — é o esperado; clientes rebaixam para o manifest novo.
- **Checksum do D1 (`catalog_meta.checksum`, ETag do Worker do v2):** `shortId` entra em `CANONICAL_FIELDS`/`canonicalEntry` (`domain/checksum.ts`), senão o backfill não muda o checksum e o v2 nunca baixa o catálogo com `shortId`. `POST /api/admin/manifest/publish` passa a chamar `updateCatalogMeta` **antes** de publicar — «publicar» atualiza as duas projeções (D1 meta + R2 manifest). O `scripts/seed_d1_louvores.py` do coldigui espelha o campo na sua lista canônica.

### 2.3 UI
- Lista e formulário de edição mostram `shortId` **somente leitura** (`ui/src/app.ts`). Não há campo editável.

### 2.4 Testes (vitest)
- `nextShortId`: sequência `0000 → 0001`, cruzamento `ffff → 10000`, valor devolvido é string com zeros à esquerda.
- `insertLouvor` gasta id; falha do insert não avança o contador (batch).
- Rename de `pdf_id` preserva `short_id`.
- `toManifestEntry` com e sem `shortId`.
- Migration de backfill: rodada no D1 local, `SELECT COUNT(DISTINCT short_id) = COUNT(*)`, menor `0000`, `short_id_next = printf('%04x', COUNT(*))`.

---

## 3. `plpcjf`

### 3.1 Catálogo
- `stores/louvores.js` normaliza com spread (`{...item, nome, pdfId}`), então `shortId` já atravessa. Confirmar por teste que o campo sobrevive à normalização e ao cache do catálogo em IndexedDB.

### 3.2 `lib/utils/playlistShare.js`
- `encodeShortShareIds(shortIds)` → `"1a2f-0c3d"`; `parseShortShareIds(param)` → array de tokens válidos, minúsculos, ordem preservada; `resolveShortIds(shortIds, louvores)` → `pdfIds` conhecidos, ordem preservada, dedupe (mesmo critério de `resolveKnownPdfIds`); `stripShareParams` também remove `s` e `n`.
- `shortIdsForPdfIds(pdfIds, louvores)` → array de `shortId` ou `null` se algum pdfId não tem `shortId` (D7).

### 3.3 `lib/utils/playlistUtils.js`
- `generatePlaylistShareUrl(pdfIds, nome, louvores)`: com `shortIdsForPdfIds` não-nulo → `/?s=…&n=…`; senão → formato legado atual. Os dois chamadores (`CarouselChips.svelte`, `routes/listas/+page.svelte`) passam `$louvores`.

### 3.4 `routes/+page.svelte` — importação
- `handleSharedPlaylistLink` trata `s` antes de `sharepdfs`: `parseShortShareIds` → `resolveShortIds` → mesmo fluxo de `loadPlaylist`/`savePlaylist`, nome vindo de `n`. Continua esperando `$louvores.length > 0`. Limpeza via `stripShareParams` (que já cobre `s`/`n`).

### 3.5 Testes (`node --test`)
- Encode/parse/resolve/strip, incluindo token inválido ignorado, maiúsculas normalizadas, `0000` preservado como string.
- `generatePlaylistShareUrl`: curto quando todos têm `shortId`; legado quando falta um.
- `playlistShare.contrato.test.js` ganha os casos do §1 (é o teste de contrato entre repositórios — espelhar os mesmos vetores no v2, §4.3).

---

## 4. `coldigui`

### 4.1 Worker `plpcg-catalog`
- `migrations/0011_add_louvores_short_id.sql` — canônica (D3/D4).
- `fetchLouvores` projeta `short_id` e emite `shortId` no JSON (omitido quando `NULL`).
- `scripts/seed_d1_louvores.py` passa `shortId` do manifest para `short_id` quando presente (seed local continua funcionando com manifests antigos).
- README do Worker: linha na tabela de endpoints e nota da migration compartilhada (D3).

### 4.2 Catálogo no app
- `LouvorDto.shortId` (`String?`), `Louvor.shortId` (`String?`), `LouvorCache.shortId` (Isar, campo novo anulável; regenerar `.g.dart`), `louvor_cache_mapper` nos dois sentidos, `Louvor.fromManifest`.
- Novo `louvoresByShortIdProvider` (`Map<String, Louvor>`), mesmo padrão de `louvoresByPdfIdProvider` (A4: construído uma vez por manifest).

### 4.3 URL — `lib/core/utils/playlist_share_url_builder.dart`
- `UrlSyncParams.shortItems = 's'`, `UrlSyncParams.shortName = 'n'`.
- `encodeShortShareIds` / `decodeShortShareIds` (mesmas regras do §1 — vetores de teste idênticos aos do §3.5).
- `buildShortPlaylistShareLocation({shortIds, shareName})` → `/?s=…&n=…`; `buildShortPlaylistShareUrl({origin, …})`.
- `PlaylistShareParams` ganha `shortIds: List<String>?`. `parsePlaylistShareParams`: se `s` e `n` presentes → `PlaylistShareParams(shortIds: …, shareName: n)`; senão fluxo atual por `sharename`. `entries` continua só para o formato longo; params com `shortIds` exigem resolução (§4.4). `extractShareParamsFromUserInput` herda pelo mesmo parser.
- `stripPlaylistShareParams` remove `s` e `n`.

### 4.4 Importação
- Porta nova em `features/playlists/domain/ports/short_id_resolver.dart`: `typedef ShortIdResolver = Future<Map<String, Louvor>> Function()` — devolve o mapa `shortId → Louvor` **depois** de o manifest existir (`ref.read(louvoresManifestProvider.future)` e então `louvoresByShortIdProvider`). Isso resolve o caso «deep link chega antes do catálogo» sem estado extra.
- `ImportSharedPlaylistFromUrl` recebe o resolver; ganha parâmetro `shortIds`. Quando presente: resolve cada token para `PlaylistEntry(id: louvor.pdfId, kind: pdf/classificado)`, ignora desconhecidos com `AppLogger.warn`, e lança `InvalidSharePlaylistException` se nada resolveu. Dedupe por fingerprint e ativação continuam iguais (o fingerprint usa `pdfId`, então um link curto e um longo da mesma lista deduplicam entre si).
- `SyncDeepLinkState`, `PlaylistsNotifier.importFromShareParams` (o chamador do diálogo) e `ImportPlaylistDialogResult` repassam `shortIds`.
- `deep_link_config.dart`: documentação do scheme passa a citar `?s=…&n=…`.

### 4.5 Geração
- `GeneratePlaylistShareUrl` recebe `Map<String, Louvor> Function() louvoresByPdfId`. Se **todas** as entradas são PDF com `shortId` → URL curta; senão → URL longa como hoje (inclusive a tentativa de `/l/` quando `short: true`, que só se aplica ao formato longo — o Worker do `/l/` exige `shareitems`).
- Resultado passa a ser um objeto `PlaylistShareLink {url, isShort}` para o folheto decidir o QR (D10) sem re-parsear a string.

### 4.6 Share — sheet e provider
- `PlaylistShareOption`: remove `linkAndLeafletWhatsApp`. Sheet com 2 tiles: «Folheto» (`linkWithLeaflet`, primeiro) e «Só o link» (`link`).
- `PlaylistShareActionsNotifier`: remove `_shareWhatsAppTwoStep`, o parâmetro `showWhatsAppStepDialog` e o `typedef` associado; a doc do retorno `false` passa a significar só falha. Apaga `playlist_share_whatsapp_step_dialog.dart`.
- l10n: remove `playlistShareOptionWhatsApp`, `playlistShareOptionWhatsAppSubtitle`, `playlistShareWhatsAppStepTitle/Message/Continue/Cancel` (pt/en). `playlistShareOptionLinkWithLeaflet` → «Folheto» / «Imagem da lista com o link e QR code» (en: «Leaflet» / «List image with link and QR code»). `playlistShareOptionLeaflet*` ficam (menu «Gerar folheto» usa `leaflet` sem passar pelo sheet, mas o rótulo é do menu; as strings do sheet para `leaflet` saem se ninguém mais as usar — verificar no plano).
- Ordem no `linkWithLeaflet`: gerar o link **antes** de capturar o folheto (já é assim), passando `PlaylistShareLink` para o documento (§4.7).

### 4.7 Folheto com QR
- Dependência `qr_flutter` (última estável).
- `LeafletDocument.shareUrl: String?` — preenchido só quando `PlaylistShareLink.isShort` (D10). `resolveLeafletDocument` ganha o parâmetro.
- `LeafletContent` renderiza, quando `shareUrl != null`, um rodapé com `QrImageView(data: shareUrl, errorCorrectionLevel: M)` de tamanho fixo em unidades lógicas do folheto e o texto do link abaixo em fonte pequena. `LeafletContentLabels` ganha o rótulo «Abrir lista no PLPCG» (pt/en).
- «Gerar folheto» do menu do tile e o modo `leaflet` também geram o link (no formato curto é local, sem rede) para incluir o QR; se a lista cai no formato longo, sem QR.

### 4.8 Testes
- Unit: `playlist_share_url_builder_test.dart` (encode/decode/strip/parse com prioridade de `s`, vetores do §1), `generate_playlist_share_url_test.dart` (curto vs longo; `/l/` só no longo), `import_shared_playlist_from_url_test.dart` (resolver; desconhecido ignorado; nada resolvido → inválido; dedupe curto×longo), `sync_deep_link_state_test.dart` (`?s=&n=`), `leaflet_document` com `shareUrl`.
- Widget: `playlist_share_sheet_test.dart` (2 tiles, ordem, retornos), `playlist_share_actions_test.dart` sem two-step, `leaflet_content` com e sem QR, `import_playlist_dialog` colando link curto.
- Worker: teste de `fetchLouvores` com `short_id` nulo e preenchido.
- Manual (produção, `v2.plpcg.com` — memória `test-on-production-v2`): iOS WhatsApp «Folheto» → imagem + legenda com link curto; abrir link no plpcjf; colar link no v2; QR lido por câmera abre o plpcjf.

---

## 5. Ordem de entrega e compatibilidade

1. **coldigui Worker + migration** (`0011`), deploy, `db:migrate:remote`. Validar `SELECT COUNT(DISTINCT short_id)` = 4627 e `/api/catalog/louvores` com `shortId`.
2. **plpcg-admin** (espelho `0003` local, atribuição, manifest, UI), deploy, **publicar manifest**.
3. **plpcjf** (leitura **e** emissão), deploy.
4. **coldigui app v2** (leitura, emissão, sheet, QR), deploy web + builds nativos.

Entre 3 e 4, um link curto emitido pelo plpcjf só chegaria ao v2 por deep link nativo ou colado — janela pequena e aceitável. Links longos antigos continuam válidos para sempre nos dois lados.

## 6. Fora de escopo
- Materiais Coldigom: sem `shortId` → sem link e sem QR (gate com dialog). **Débito técnico:** remover o gate, o dialog e a emissão de link longo/`/l/` quando o acervo PLPCG sair do coldigui.
- Encurtador `/l/` e qualquer coisa ligada a login.
- Migrar listas salvas para guardar `shortId` — elas continuam em `pdfId`; o `shortId` é só de transporte.
- Alterar o formato do folheto além do rodapé com QR.

## 7. Riscos
- **Migration num D1 compartilhado (D3):** se alguém rodar o espelho do admin no remoto depois do coldigui, `ALTER TABLE` falha com «duplicate column» — sem dano, só ruído. O comentário no arquivo e o README mitigam.
- **`UPDATE … FROM` + window function** exigem SQLite ≥ 3.33; o D1 atende. Validar no local antes do remoto.
- **Checksum do manifest muda** ao publicar: plpcjf e v2 baixam o catálogo inteiro uma vez — comportamento normal de qualquer republish.
- **QR em folheto capturado em alta escala:** confirmar que o `RepaintBoundary` off-screen renderiza o `QrImageView` (é `CustomPaint`, sem imagem assíncrona — deve funcionar; o teste de widget do folheto cobre).
