# Leitor de Gestos CIAs — design

Data: 2026-09-11
Origem: `pdf_extractor/docs/superpowers/specs/2026-09-03-gestos-viewer-editor-design.md`
(contrato compartilhado com o coldigom) e
`pdf_extractor/docs/prompts/2026-09-03-prompt-coldigui-viewer-gestos.md`.

## 1. Contexto

### O que existe

O material "Gestos CIAs" de um louvor é hoje só o PDF `Gestos em Gravura`, aberto
no `PdfReaderScreen`. O coldigom passa a publicar um **segundo material** por
louvor: um documento JSON (`type: "gestures"`, `r2_key =
assets/praises/{pid}/{mid}.gestures`) com a sequência de gestos, mais um
**dicionário global** (`GET /api/gestures/dictionary`) que mapeia cada
`gestureId` a nome e figura PNG. Este design cobre a tela que lê os dois.

O precedente exato é o leitor de cifras (spec
`2026-08-29-leitor-cifras-chordpro-design.md`): rota filha da Home, material
no mesmo espaço de ids do PDF, conteúdo buscado sob demanda por `r2_key`,
cache Isar cache-first com revalidação, fonte ajustável persistida.

### O que o repo já tem (verificado em 2026-09-11)

- `MaterialKind.gesture` existe em `lib/core/utils/material_id_kind.dart`;
  `materialIdKindOf` classifica `.txt`/`.gest` como gesto — extensões que
  **nada no app produz** (só o classificador e o teste dele).
- `LouvorMaterialIcons.forKind(MaterialKind.gesture)` já devolve
  `Icons.pan_tool_outlined`.
- `MaterialSheet` (`lib/features/catalog/presentation/widgets/material_sheet.dart`)
  renderiza `LouvorGroup.extras` genericamente: não há `_visibleKinds` nem
  `StateError` para gesto. Basta o adapter emitir a variante nova.
- `PlaylistListTile` manda tudo que não é PDF para
  `resolveCatalogMaterialFromWidget` + `openMaterialProvider`; a playlist não
  precisa de caso novo, só de `ColdigomCatalogSource.findMaterialById`
  resolver `MaterialKind.gesture`.
- `CatalogMaterial` é `sealed`; `OpenMaterial.open` faz `switch` exaustivo —
  a variante nova quebra a compilação até ganhar um caso.
- Cache de conteúdo de texto é **Isar** (`ChordContentCache` +
  `ChordContentLocalDatasource`, TTL 24 h, marcador negativo, no-op sem Isar).
  Binário é `PdfStoragePort` (nativo: filesystem; web: Cache API).
- Wakelock: `_stageRoutes` em `stage_wakelock.dart`. Tela cheia:
  `readerFullscreenProvider`. Atalhos globais: `app_shortcuts.dart`.
- O coldigom **ainda não** publica documentos nem o dicionário (o editor é
  outro prompt, não executado). O leitor nasce antes do backend.

### Tamanhos reais

Dicionário: 208 figuras PNG, 8,8 MB no total (média 42 KB). Um louvor usa
10–25 figuras distintas. Documento JSON: 2–8 KB.

## 2. Decisões

1. **Contrato e cores são fixos** (seções 3 e 4). Vieram combinados com o
   coldigom e com o pipeline; não se alteram aqui.
2. **JSONs no Isar, como as cifras.** Documento por `r2Key` em
   `GestureDocumentCache`; dicionário em linha única `GestureDictionaryCache`
   com ETag. Reaproveita degradação sem Isar, TTL e marcador negativo.
3. **Figuras sob demanda, em store próprio nativo+web.** `GestureFigureStorePort`
   espelha `PdfStoragePort` (filesystem / Cache API) com store **separado** do
   de PDFs, para não contaminar `getTotalOfflineBytes`/`listOrphans` do UC-10.
   Pré-busca só as figuras do louvor aberto.
4. **Entrega completa, sem flag.** O adapter só emite o material quando o
   worker mandar `type: gestures`; hoje nada muda na UI. `--dart-define
   GESTURE_DICTIONARY_BASE_URL` (opcional) aponta o dicionário para outro
   servidor durante o desenvolvimento.
5. **`MaterialKind.gesture` passa a significar "documento JSON de gestos".**
   `materialIdKindOf` reconhece `.gestures`; `.txt`/`.gest` são aposentadas.
   Ids `unknown` caem na mesma face de leitura da playlist que `gesture`, então
   o comportamento observável é idêntico.
6. **Chaves por `Row(crossAxisAlignment: stretch)`**, não `IntrinsicHeight`:
   a `Row` já tem a altura da coluna de filhos; a chave é um `CustomPaint`
   esticado. Aninhar é empilhar `Row`s.
7. **`gestureId` resolve na renderização**, não no parse. O cache do documento
   fica independente da versão do dicionário; o papel não espera o dicionário.
8. **Corpo em `SingleChildScrollView` + `Column`.** Documentos têm ≤ 40
   cartões; blocos aninhados não cabem num `ListView` lazy.
9. **Modo foco é overlay da mesma rota** (`showGeneralDialog`), não rota nova.
10. **Duas falhas de parse, não uma.** JSON inválido é conclusivo
    (`GestureDocumentParseException` → `AsyncError` → "tentar de novo"); tudo
    dentro de `items` é tolerado item a item.

## 3. Contrato de dados (fixo)

### 3.1 Documento de gestos (`coldigom.gestures/1`)

```ts
type GestureDocument = {
  schema: "coldigom.gestures/1";
  title: string;                 // "182 - QUERO VIVER PRA SEMPRE COM JESUS"
  dictionaryVersion: number;
  items: Item[];                 // ordem do documento = ordem de execução
};
type Item = GestureItem | RepeatBlock | ChorusBlock | LinkBlock | FinalBlock
          | InstructionItem | TextItem;
type GestureItem = { type: "gesture"; gestureId: string /* 12 hex */; lyrics: LyricLine[] /* 1–3 */ };
type LyricLine   = { trigger: string /* "" em continuação */; text: string };
type RepeatBlock = { type: "repeat"; count: number /* >= 2 */; children: BlockChild[] };
type ChorusBlock = { type: "coro";   children: BlockChild[] };
type LinkBlock   = { type: "link";   children: BlockChild[] };  // 2 ou 3 filhos
type FinalBlock  = { type: "final";  children: BlockChild[] };  // só na raiz
type BlockChild  = GestureItem | RepeatBlock | ChorusBlock | LinkBlock;
type InstructionItem = { type: "instruction";
  kind: "instruments" | "repeat_praise" | "back_to_chorus" | "back_to_chorus_and_finish" };
type TextItem = { type: "text"; text: string };
```

Blocos aninham livremente (há `repeat` dentro de `coro`, `link` dentro de
`repeat`, `coro` dentro de `repeat` no acervo real). Profundidade prática ≤ 3.

### 3.2 Dicionário (`coldigom.gesture-dictionary/1`)

`GET {base}/api/gestures/dictionary` — público, `ETag`, 304 com `If-None-Match`,
`Cache-Control: public, max-age=300`.

```ts
type GestureDictionary = { schema: "coldigom.gesture-dictionary/1"; version: number;
  generatedAt: string; gestures: GestureEntry[] };
type GestureEntry = { id: string; name: string; description: string;
  exampleTriggers: string[]; image: string /* r2_key PNG */; gif: string | null;
  status: "active" | "deprecated"; replacedBy: string | null; updatedAt: string };
```

Figuras: `{coldigom}/assets/{image}` — no app, `ColdigomAssetUrl.fetchUrlForKey`
(proxy na web, direto no nativo), como PDFs e cifras.

### 3.3 Leitura tolerante

| Situação | Comportamento |
|---|---|
| Corpo não é JSON, ou raiz não é objeto | `GestureDocumentParseException` (conclusivo) |
| `items` ausente ou não é lista | documento com `items` vazio → tela "sem gestos" |
| `type` desconhecido | `TextLine` com o JSON compactado do item; descartado se vazio |
| `gesture` sem `gestureId` válido (`^[0-9a-f]{12}$`) | mantido; a renderização mostra o placeholder com o id cru |
| `lyrics` ausente/vazia | uma `LyricLine('', '')` |
| `lyrics` > 3 linhas | truncado em 3 |
| `count` ausente, não inteiro ou `< 2` | 2 |
| bloco sem filhos válidos | descartado |
| `final`/`instruction` fora da raiz | renderizado onde está (o app não valida posição) |
| `schema` com major ≠ 1 | `schemaMajor` guardado; banner "formato mais novo; atualize o app"; renderiza |
| campo desconhecido | ignorado |
| dicionário: entrada sem `id`/`image` | descartada; `status` desconhecido → `active` |

### 3.4 Resolução de alias

`GestureDictionary.resolve(id)`: segue `replacedBy` enquanto `status ==
deprecated`, no máximo 5 saltos, com conjunto de visitados (ciclo → devolve a
última entrada visitada). Id ausente → `null` → placeholder "gesto não
encontrado" com o id em fonte pequena.

## 4. Regras de renderização (fixas)

O documento é desenhado sobre **papel branco** (`#FFFFFF`) dentro do chrome
vinho/creme do app. Sem dark mode no papel.

| Papel | Cor |
|---|---|
| gatilho (`trigger`) | `#D32F2F`, negrito |
| leitura (`text`) | `#1A1A1A`, regular |
| chave de repetição, `Nx`, rótulo `CORO`, chave tracejada | `#1E63C8` |
| conector de ligação (`link`) | `#E08A1E` |
| divisor e rótulo `FINAL` | `#6A2F2F` |
| cartão de instrução | fundo `#F3F4F6`, texto `#374151`, borda `#D1D5DB` |
| placeholder de gesto ausente | fundo `#FFF7E6`, borda tracejada `#E0B45C` |
| `text` livre | `#6B7280`, itálico |

**Cartão de gesto**

- `Row` alinhada pelo topo: figura à esquerda, letra à direita.
- Figura: caixa quadrada, `BoxFit.contain`, fundo branco. Lado =
  `96 dp × (fonte / 18)`.
- Letra: um `RichText` por `LyricLine`, empilhados. `trigger` vermelho negrito
  + espaço + `text` preto. Sem espaço se `text` começa com `, . ; : ! ? ) ]`.
  `trigger` vazio → só `text`. **Nunca quebrar linha dentro do gatilho** —
  espaços do gatilho viram ` `.
- Figura e toda a letra ficam no mesmo cartão.
- Fonte base 18, faixa 14–28, passo 2, persistida.

**Blocos**

- `repeat`: filhos empilhados; à direita chave vertical azul (altura = altura
  dos filhos) com `Nx` centralizado. Cada nível de aninhamento adiciona uma
  chave mais externa; largura da coluna da chave = 28 dp (o prompt dizia
  recuo de 20 dp por nível; 20 não comporta `12x` em fonte 28 — o rótulo
  manda).
- `coro`: rótulo `CORO` azul negrito acima dos filhos; à direita chave
  vertical **tracejada** azul.
- `link`: filhos sem espaço entre si; à esquerda conector vertical laranja
  com seta para baixo no fim.
- `final`: divisor horizontal traço-ponto + rótulo `FINAL` à esquerda, depois
  os filhos.
- `instruction`: cartão de largura total com rótulo l10n (pt: `Instrumentos` /
  `Repetir o louvor` / `Voltar ao coro` / `Voltar ao coro e finalizar`; en:
  `Instruments` / `Repeat the hymn` / `Back to chorus` / `Back to chorus and
  finish`).

**Página**

- Uma coluna, largura máxima 720 dp centralizada, margens 16 dp.
- Título (`title`) no topo, caixa alta, `AppTypography` de headline.
- Espaço entre cartões 12 dp; entre blocos 20 dp.

**Modo foco**

- Toque num cartão abre `GestureFocusView` sobre a lista do `flatten`, já no
  cartão tocado. Blocos não expandem repetições; a estrutura vira chip de
  contexto (`2x`, `CORO`, `FINAL`, `ligação`), um chip por nível.
- Figura ≥ 60 % da largura (GIF em vez do PNG quando `entry.gif != null`);
  letra abaixo com as mesmas cores, fonte `base + 6`.
- Rodapé fixo: `próximo: ` + gatilho do próximo cartão em vermelho negrito;
  no último, `fim`.
- Avanço: toque na metade direita/esquerda, swipe, `←`/`→`; `Esc` fecha; `F`
  alterna tela cheia via `readerFullscreenProvider`.
- Ao fechar, a página rola até o cartão em foco (`Scrollable.ensureVisible`).

## 5. Arquitetura

Feature nova `lib/features/gestures/` no layout clean da casa.

### 5.1 Domínio

```
domain/
  entities/gesture_document.dart      GestureDocument, sealed GestureItem
  entities/gesture_dictionary.dart    GestureDictionary, GestureEntry, GestureStatus
  entities/gesture_material.dart      GestureMaterial (forma de ChordMaterial)
  entities/gesture_reader_font_size.dart
  entities/flat_gesture_card.dart     FlatGestureCard, BlockContext
  usecases/parse_gesture_document.dart
  usecases/parse_gesture_dictionary.dart
  utils/flatten_gesture_cards.dart
```

- `GestureDocument { int schemaMajor; String title; int dictionaryVersion;
  List<GestureItem> items; bool get isNewerSchema => schemaMajor > 1;
  bool get hasGestures }`.
- `sealed class GestureItem`: `GestureCard(gestureId, lyrics)`,
  `RepeatBlock(count, children)`, `ChorusBlock(children)`,
  `LinkBlock(children)`, `FinalBlock(children)`, `InstructionCard(kind)`,
  `TextLine(text)`. `LyricLine(trigger, text)`. `enum InstructionKind
  { instruments, repeatPraise, backToChorus, backToChorusAndFinish }`.
- `GestureDictionary { int version; DateTime? generatedAt;
  Map<String, GestureEntry> byId; GestureEntry? resolve(String id) }`.
- `GestureMaterial { gestureId (= encodePdfId(r2Key)), r2Key, nome, numero,
  groupId, categoria, classificacao, author, source }`.
- `GestureReaderFontSize { min 14, max 28, step 2, initial 18 }` — cópia de
  `ChordReaderFontSize` com faixa própria.
- `parseGestureDocument(String json) → GestureDocument` (lança
  `GestureDocumentParseException` só nos casos conclusivos da 3.3).
- `parseGestureDictionary(String json) → GestureDictionary` (idem;
  `GestureDictionaryParseException`).
- `flattenGestureCards(GestureDocument) → List<FlatGestureCard>`;
  `FlatGestureCard { int index; GestureCard card; List<BlockContext> contexts }`;
  `BlockContext` é `sealed`: `RepeatContext(count)`, `ChorusContext`,
  `FinalContext`, `LinkContext`. Ordem de `contexts`: do bloco mais externo
  para o mais interno. `index` é o único esquema de numeração de cartões do
  app: a página e o foco usam o mesmo.

### 5.2 Dados

```
lib/core/database/collections/
  gesture_document_cache.dart     { id, r2Key @Index(unique), content, fetchedAt }
  gesture_dictionary_cache.dart   { id, content, etag, fetchedAt }  (linha única, id = 1)
data/
  datasources/gesture_content_datasource.dart        GET .gestures por r2Key
  datasources/gesture_content_local_datasource.dart  Isar; espelho do de cifras
  datasources/gesture_dictionary_datasource.dart     GET /api/gestures/dictionary + If-None-Match
  datasources/gesture_dictionary_local_datasource.dart
  datasources/gesture_figure_store.dart              port + createGestureFigureStore()
  datasources/gesture_figure_store_native.dart       path_provider, plpcg_gestures/figures/
  datasources/gesture_figure_store_web.dart          Cache API, store "plpcg-gesture-figures"
  repositories/gesture_figure_repository.dart        get(r2Key) cache→rede; prefetch(keys)
  providers/gesture_providers.dart
```

- `GestureContentDatasource.fetchContent(r2Key) → String?` — mesma escada de
  `ChordContentDatasource`: 404 e corpo vazio → `null`; qualquer outra falha →
  `GestureFetchFailedException(r2Key, cause)`.
- `GestureDictionaryDatasource.fetch({String? etag}) →
  GestureDictionaryFetchResult` = `Fresh(body, etag)` | `NotModified` |
  `NotFound`. Base URL: `GestureDictionaryConfig.baseUrl` =
  `String.fromEnvironment('GESTURE_DICTIONARY_BASE_URL')` quando não vazio,
  senão `ColdigomApiConfig.baseUrl`. É chamada de API JSON, não de asset: vai
  direto no `coldigomDioProvider` (como `/api/plpcg/praises`), sem o proxy
  `/api/coldigom/*` — esse só existe para assets sob COEP.
- `GestureContentLocalDatasource` / `GestureDictionaryLocalDatasource`:
  `read()` / `write()` best-effort, no-op sem Isar, `debugPrint` em falha,
  TTL `kGestureCacheTtl = 24 h` (documento) e
  `kGestureDictionaryTtl = 1 h` (dicionário).
- `GestureFigureStorePort { Future<Uint8List?> read(String r2Key);
  Future<void> write(String r2Key, Uint8List bytes); Future<void> deleteAll() }`.
  Chave de arquivo = `sha1(r2Key).hex + extensão`. Nativo grava atômico
  (`.tmp` + rename). Web usa `caches.open('plpcg-gesture-figures')`.
- `GestureFigureRepository.get(r2Key) → Future<Uint8List?>`: store, senão
  Dio (`responseType: bytes`) via `ColdigomAssetUrl.fetchUrlForKey`, grava e
  devolve; `null` em 404 ou falha (best-effort). `prefetch(Iterable<String>)`
  com concorrência 4, ignora falhas.

Providers (`gesture_providers.dart`), espelhando `chord_providers.dart`:

- `gestureDocumentProvider = FutureProvider.autoDispose.family<GestureDocument?, String>(retry: null)`
  — cache-first; `keepAlive()` só no sucesso; 404 grava marcador negativo;
  revalidação em background quando `isStaleAt` e há conexão
  (`deviceConnectivityProvider`); `invalidateSelf` se o corpo mudou.
- `gestureDictionaryProvider = FutureProvider<GestureDictionary?>` (keepAlive
  natural) — cache-first; revalida com `If-None-Match` quando stale e online;
  304 só atualiza `fetchedAt`. Sem cache e sem rede → `null` (a tela renderiza
  com placeholders, não erro).
- `gestureFigureProvider = FutureProvider.family<Uint8List?, String>` (keepAlive).
- `gestureFigurePrefetchProvider = Provider.family<void, String r2KeyDoc>` —
  ouve documento + dicionário e chama `prefetch` uma vez com as figuras
  resolvidas dos ids do documento.
- `gestureReaderFontSizeProvider` — `Notifier<double>` persistido em
  `StorageKeys.gestureReaderFontSize`.

### 5.3 Apresentação

```
presentation/
  pages/gesture_reader_screen.dart
  providers/gesture_focus_index_provider.dart     int? (null = página)
  theme/gesture_reader_palette.dart
  utils/open_gesture_in_reader.dart               espelho de open_chord_in_reader
  widgets/gesture_document_view.dart
  widgets/gesture_card_tile.dart
  widgets/lyric_line_text.dart                    RichText do gatilho + leitura
  widgets/gesture_figure.dart
  widgets/brace_painter.dart                      chave sólida/tracejada + rótulo
  widgets/link_connector_painter.dart
  widgets/repeat_block_view.dart
  widgets/chorus_block_view.dart
  widgets/link_block_view.dart
  widgets/final_section_view.dart
  widgets/instruction_card_view.dart
  widgets/text_line_view.dart
  widgets/newer_schema_banner.dart
  widgets/gesture_focus_view.dart
```

- `GestureReaderScreen(queryParams)` — espelho de `ChordReaderScreen`:
  publica params em `readerRouteParamsProvider`; barra 3 com `A-`/`A+`, tela
  cheia, indicador; `Ctrl+↑/↓` fonte, `Ctrl+←/→` louvor pelo carousel; resto
  sobe para `AppShortcuts`. Estados: loading → skeleton; `AsyncError` →
  "indisponível · tentar de novo" (`ref.invalidate`); `null` → "este louvor
  ainda não tem gestos"; dado → banner de schema (se houver) +
  `GestureDocumentView`.
- `GestureDocumentView({document, dictionary: AsyncValue<GestureDictionary?>,
  fontSize, flat, onCardTap(index), scrollController})` — `Column` centrado em
  720 dp; mantém `Map<int, GlobalKey>` dos cartões para `scrollToCard(index)`.
- `GestureCardTile` — `Row` topo; `GestureFigure` + `Column` de
  `LyricLineText`; `InkWell` → `onTap(index)`.
- `RepeatBlockView`/`ChorusBlockView` — `Row(stretch)`:
  `Expanded(Column(filhos))` + `SizedBox(width: 28, CustomPaint(BracePainter(
  dashed, label)))`. `CORO` como `Text` acima dos filhos.
- `LinkBlockView` — `Row(stretch)`: `SizedBox(width: 20,
  CustomPaint(LinkConnectorPainter))` + `Expanded(Column(filhos, sem gap))`.
- `GestureFigure({entry, size})` — observa `gestureFigureProvider(entry.image)`;
  bytes → `Image.memory` (`gaplessPlayback`); carregando → caixa branca com
  progress discreto; `entry == null` ou bytes `null` → placeholder tracejado
  com o id.
- `GestureFocusView` — `showGeneralDialog` fullscreen; `PageView` sobre `flat`,
  `initialPage` = índice tocado; chips de contexto; figura ≥ 60 % (GIF se
  houver); letra `base + 6`; rodapé `próximo:`/`fim`; `Focus` com `←`/`→`
  `Esc` `F`; `GestureDetector` nas metades. Retorna `int` (índice atual) ao
  fechar; a tela chama `scrollToCard`.

### 5.4 Encaixes fora da feature

| # | Arquivo | Mudança |
|---|---|---|
| 1 | `lib/features/catalog/domain/entities/catalog_material.dart` | `final class GestureMaterialRef extends CatalogMaterial` (`kind = gesture`) |
| 2 | `lib/features/catalog/domain/entities/louvor_group.dart` | `gestureMaterials` no construtor de compatibilidade e getter derivado de `extras` (após cifras, antes de áudio) |
| 3 | `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart` | `'gestures' => MaterialKind.gesture` em `_kindOfType`; `toGestureMaterials` |
| 4 | `lib/features/coldigom/data/sources/coldigom_catalog_source.dart` | mapa `gestures`; `findMaterialById` resolve `MaterialKind.gesture`; grupos recebem `gestureMaterials` |
| 5 | `lib/core/utils/material_id_kind.dart` | `.gestures` → gesture; `.txt`/`.gest` removidas; doc atualizada |
| 6 | `lib/features/catalog/presentation/providers/open_material_provider.dart` | `GestureMaterialOpener` + caso `GestureMaterialRef` |
| 7 | `lib/core/routing/route_paths.dart`, `app_router.dart` | `RoutePaths.gestos = '/gestos'`; `GoRoute(path: 'gestos')` irmã de `cifra` |
| 8 | `lib/core/utils/gesture_reader_url_builder.dart` | `buildGestureReaderLocation({gestureId, titulo, subtitulo})` reusando `UrlSyncParams.pdfId` |
| 9 | `lib/features/app_shell/presentation/widgets/stage_wakelock.dart` | `RoutePaths.gestos` em `_stageRoutes` |
| 10 | `lib/core/constants/storage_keys.dart` | `gestureReaderFontSize` |
| 11 | `lib/core/database/isar_app_schemas.dart` | dois schemas novos |
| 12 | `lib/l10n/app_pt.arb`, `app_en.arb` | `gesturesMaterialLabel`, `gesturesReaderTitle`, `gesturesReaderEmpty`, `gesturesReaderUnavailable`, `gestureInstructionInstruments`, `gestureInstructionRepeatPraise`, `gestureInstructionBackToChorus`, `gestureInstructionBackToChorusAndFinish`, `gestureNotFound`, `gestureFocusNext`, `gestureFocusEnd`, `gesturesNewerSchemaWarning`, `gestureContextRepeat` (`{count}x`), `gestureContextChorus`, `gestureContextFinal`, `gestureContextLink` |
| 13 | `docs/features/FEATURE_INDEX.md`, `docs/use-cases/UC-15-leitor-gestos.md` | entrada `gestures` + UC curto |

Onde a playlist e o sheet já funcionam sem código novo (ver §1), o plano só
adiciona testes que pinam isso.

### 5.5 Fluxo de abertura

```
sheet/playlist → OpenMaterial.open(GestureMaterialRef)
  → openGestureInReader → context.go(buildGestureReaderLocation(...))
  → GestureReaderScreen(queryParams)
      pdfId → decodePdfId → r2Key
      watch gestureDocumentProvider(r2Key)      (Isar → rede)
      watch gestureDictionaryProvider           (Isar → rede c/ ETag)
      read  gestureFigurePrefetchProvider(r2Key)
      → GestureDocumentView → GestureCardTile → GestureFigure(gestureFigureProvider)
```

## 6. Testes

Rodar sempre com `--dart-define-from-file=dart_defines/plpcg.json`.

Fixtures em `test/fixtures/gestures/`: `182_quero_viver.json` (coro +
instruções, do prompt), `181_jerusalem.json` (5 na raiz + `repeat 2` com 4),
`sintetico_final_link.json` (`final`, `link` dentro de `repeat`, `instruction:
instruments`, um `type` desconhecido, um `gestureId` inexistente),
`schema_v2.json`, `dictionary.json` (12 entradas; uma `deprecated` →
`replacedBy`; um ciclo `x→y→x`), `figures/*.png` (1×1, gerados no teste ou
commitados).

**Unit** (`test/unit/features/gestures/`): `parse_gesture_document_test`
(3 fixtures + cada linha da tabela 3.3), `parse_gesture_dictionary_test`,
`gesture_dictionary_resolve_test` (alias, 5 saltos, ciclo, ausente),
`flatten_gesture_cards_test` (índices, contexts aninhados, ordem),
`gesture_content_datasource_test` (200/404/vazio/rede/500, Dio mockado),
`gesture_dictionary_datasource_test` (200 com ETag, 304, 404, rede),
`gesture_document_provider_test` (cache-first, negativo, stale → revalida,
erro não gruda), `gesture_dictionary_provider_test`,
`gesture_figure_repository_test` (store hit, miss → rede → grava, falha →
null, prefetch ignora falhas), `gesture_material_adapter_test`,
`gesture_reader_font_size_test`. Fora da feature:
`material_id_kind_test` (`.gestures`; `.txt`/`.gest` → unknown),
`gesture_reader_url_builder_test`, `stage_wakelock_test` (`/gestos`),
`coldigom_catalog_source` (`findMaterialById` gesto),
`open_material_provider_test` (caso gesto chama o opener).

**Widget** (`test/widget/features/gestures/`): `gesture_card_tile_test`
(gatilho vermelho negrito, pontuação sem espaço, gatilho não quebra, tamanho da
figura por fonte), `repeat_block_view_test` (chave cobre a altura dos filhos,
`2x`, aninhado), `chorus_block_view_test` (`CORO`, tracejada),
`link_block_view_test`, `final_section_view_test`,
`instruction_card_view_test` (4 rótulos pt/en), `gesture_figure_test`
(bytes, loading, placeholder), `gesture_document_view_test` (fixture 182
completo; id desconhecido não quebra; schema v2 mostra banner),
`gesture_reader_screen_test` (4 estados; A-/A+ persiste; params publicados),
`gesture_focus_view_test` (abre no índice, rodapé próximo/fim, `→`, `Esc`
devolve índice, retorno rola), `material_sheet` (gesto aparece com ícone e
rótulo), `playlist_list_tile` (entrada gesto abre pelo opener).

Critérios de aceite do prompt (§7) mapeados 1:1 nesses testes.

## 7. Fora de escopo (v1)

Duas colunas em tablet paisagem; gestos e figuras nos pacotes ZIP offline;
GIF fora do modo foco; `offline_material_resolver` contando gestos (só não
pode quebrar); edição; busca por gesto; áudio sincronizado; download do
dicionário inteiro.

## 8. Riscos

- **Backend inexistente.** Nada aparece na UI até o coldigom publicar. Mitigação:
  fixtures cobrem tudo; `GESTURE_DICTIONARY_BASE_URL` permite um servidor local.
- **Cache API na web para figuras.** Mesma técnica do `PdfStorageWeb`, já
  validada (COOP/COEP). Store separado evita colisão de chaves.
- **Chave com altura errada.** `Row(stretch)` depende de a `Column` de filhos
  ser o filho mais alto — verdade por construção (a chave tem altura 0
  intrínseca). Teste de widget pina a altura.
- **Dicionário e documento fora de sincronia** (`dictionaryVersion` maior que
  a versão cacheada): ids novos viram placeholder até a revalidação. Aceitável;
  o placeholder mostra o id.
