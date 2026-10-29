# Leitor de cifras ChordPro — design

Data: 2026-08-29
Branch: `web/integration`
Status: aprovado na abordagem; pendente revisão da spec

## 1. Contexto

### As três peças

**PLPCG** — manifest estático servido pelo worker `workers/plpcg-catalog`
(`PLPCG_API_BASE_URL = https://plpcg.com`). Fonte simples, chips vermelhos na UI.
Será descontinuada, mas continua sendo a fonte principal por ora.

**Coldigom** — API Hono sobre D1 + R2
(`COLDIGOM_API_BASE_URL = https://coldigom-api.jairofilho79.workers.dev`).
Acervo rico, chips pretos com borda dourada. Assets em
`assets/praises/<praise_id>/<material_id>.<ext>`, servidos por `GET /assets/*`.

**Coldigui** — este app Flutter. Funde as duas fontes por `groupId` em
`LouvorGroup`, e o bottom sheet (`louvor_material_sheet.dart`) mostra seções de
PDF por classificação, seguidas de Áudios e YouTube.

### Como um material chega ao sheet hoje

```
MaterialDto.type  →  ColdigomLouvorAdapter.toX()  →  LouvorGroup.<lista>  →  seção no sheet
     'pdf'              toLouvores()                    sections
     'mp3'              toAudioTracks()                 audioTracks
     'youtube'          toYoutubeMaterials()            youtubeMaterials
     'chord'            (não existe)                    (não existe)     ← esta spec
```

O commit `ea2bd5a` (YouTube) é o precedente exato desse caminho.

### Estado dos dados de cifra

Levantado em 2026-08-29 contra a API de produção:

| Fato | Valor |
|---|---|
| Materiais `type: "chord"` no D1 | 2.271 |
| Kinds usados | `Cifra`, `Cifra I`, `Cifra II` |
| Arquivos `.chord` publicados no R2 | **57 (2,5%)** |
| Demais | `404 {"error":"File not found"}` |
| Tamanho médio / máximo dos publicados | 611 B / 1.750 B |

Os 57 publicados são os revisados, e o formato está limpo — zero `|` em todos.
O conteúdo não publicado vive em `coldigom/storage/chordpro_staging/` (local) e
na tabela D1 `raw_chordpros` (4.548 linhas, **0 validadas**), ainda com ruído de
OCR e barras `|` cruas. **Esta spec não consome nenhum dos dois**: o app lê só o
R2, e a cobertura cresce sozinha conforme a revisão avança do lado do coldigom.

### Formato publicado

```
{title: Comigo Habita, Ó Deus}
{key: Eb}
{rhythm: Canção}
{artist: Let. H/F.L / Mus. W.H.M / Trad. J.G.R / Adap. J.B.G.}

[Eb]Co - [Bb]migo ha[Cm]bi - [Gm]ta, ó [Ab]Deus!
A [Bb]noite [Eb]vem,
```

Diretivas presentes nos 57: `title` (57), `key` (57), `rhythm` (57),
`artist` (56), `subtitle` (42). O staging também usa `{comment: ...}` e
`{meta: column left|right|full}`, então o parser precisa tolerar e ignorar
diretivas desconhecidas.

Adjacência dos 2.224 acordes dos 57 arquivos:

| Vizinhança | Casos | Barra? |
|---|---:|---|
| espaço → texto (`é [Ab]Deus`) | 921 | sim |
| texto → texto (`ha[Cm]bi`) | 715 | sim |
| início de linha → texto | 208 | sim |
| texto → espaço/fim (`Sinai[C#m7]`) | 9 | sim |
| espaço → fim de linha | 170 | não |
| espaço → espaço | 148 | não |
| início → espaço (`[E]   A linda`) | 53 | não |

37 dos 57 arquivos têm corridas de 2+ espaços entre não-brancos, então o
espaçamento significativo é frequente e precisa ser preservado.

### Rede

`https://plpcg.com/api/coldigom/<r2_key>` responde `200 text/plain` com
`cross-origin-resource-policy: cross-origin` — seguro sob o COEP que o pdfrx
exige — e preserva o `404`. É o mesmo proxy que o áudio já usa em
`AudioTrackUrl.fetchUrlForKey`. Acesso direto ao worker também tem CORS liberado
para `https://plpcg.com`, e serve de fallback nativo.

## 2. Decisões tomadas

| # | Decisão | Escolha |
|---|---|---|
| 1 | Fonte do conteúdo | `GET` do `.chord` no R2, via o proxy que o áudio já usa |
| 2 | Representação do material | Híbrido: entidade `ChordMaterial` própria, **id no mesmo espaço do `pdfId`** |
| 3 | Integração | Entra no carousel e na playlist, como o PDF |
| 4 | Materiais sem arquivo | Checagem de disponibilidade ao abrir o sheet; só lista o que existe |
| 5 | Acorde encostado só à esquerda | Leva barra, depois do último caractere |
| 6 | Tema claro/escuro | Toggle local do leitor, persistido em `SharedPreferences` |

### Por que o híbrido (decisão 2)

`CarouselItem` persiste apenas `pdfId` + `sortOrder`; todo o resto é derivado do
manifest. Como `pdfId = encodePdfId(r2Key)` é só o Base64 URL-safe do path
relativo, um material de cifra ganha um id no mesmo espaço sem nenhuma mudança
de schema — e o tipo é recuperável do próprio id, decodificando e olhando a
extensão. Isso dá a limpeza de uma entidade separada (sem cifra vazando para
`LouvorGroup.sections` nem para os caminhos que assumem PDF) sem o custo de
estender a persistência de carousel e playlist para um segundo espaço de ids.

O `docs/superpowers/specs/` é novo neste repo; a spec mora aqui por convenção
do fluxo de brainstorming, e o `docs/features/FEATURE_INDEX.md` ganha um ponteiro.

## 3. Arquitetura

### 3.1 Discriminador de tipo de material

Ponto único que decide o que um id representa. Novo:
`lib/core/utils/material_id_kind.dart`

```dart
enum MaterialIdKind { pdf, chord, unknown }

MaterialIdKind materialIdKindOf(String id);  // decodifica, olha a extensão
```

Consome `PdfPathNormalizer.getPdfRelPath`, que já existe e já trata padding
URL-safe. Retorna `unknown` em id inválido, sem lançar.

Consumidores:
- `ReaderCarouselActionsNotifier.navigateToPdfId` — escolhe `/cifra` ou `/leitor`
- `openCarouselPdfInReader` — idem
- guardas nos caminhos PDF-only (§3.6)

### 3.2 Domínio — entidade

Novo: `lib/features/chords/domain/entities/chord_material.dart`

```dart
class ChordMaterial {
  final String chordId;       // encodePdfId(r2Key) — mesmo espaço do pdfId
  final String r2Key;
  final String nome;
  final String numero;
  final String groupId;
  final String categoria;     // 'Cifra', 'Cifra I', 'Cifra II'
  final String classificacao;
  final String author;
  final LouvorDataSource source;
}
```

Espelha `YoutubeMaterial` de propósito — mesma forma, mesmo lugar no `LouvorGroup`.

### 3.3 Domínio — parser ChordPro

Novo: `lib/features/chords/domain/usecases/parse_chordpro.dart`

O modelo central é a **célula**: um acorde opcional sobre um trecho de texto.

```dart
class ChordCell {
  final String? chord;     // null quando o trecho não tem acorde
  final bool attached;     // true → barra vermelha na borda esquerda do texto
  final String text;       // inclui o espaço em branco literal
}

sealed class ChordProLine {}
class ChordProLyricLine  extends ChordProLine { List<ChordCell> cells; }
class ChordProCommentLine extends ChordProLine { String text; }
class ChordProStanzaBreak extends ChordProLine {}

class ChordProSong {
  final String title, subtitle, key, rhythm, artist;
  final List<ChordProLine> lines;
}
```

Regras:

1. Linha `^\{chave:\s*valor\}$` é diretiva. `title`, `subtitle`, `key`, `rhythm`,
   `artist` alimentam o cabeçalho; `comment` vira `ChordProCommentLine`;
   qualquer outra (inclusive `meta`) é ignorada em silêncio. Valor vazio ou `?`
   conta como ausente e some do cabeçalho — ambos ocorrem no corpus publicado
   (`{key: }`, `{subtitle: ?}`).
2. Linha começando com `;` é comentário ChordPro de autoria e **não é
   renderizada** — diferente de `{comment: ...}`, que é dirigido ao músico. No
   corpus, `;` carrega recado de pipeline ("reanexe o PDF correto"), que não é
   conteúdo para o usuário final.
3. Linha em branco vira `ChordProStanzaBreak`. Brancos consecutivos colapsam em
   um só.
4. Nas demais, `\[([^\]]*)\]` separa acordes de texto. Para cada acorde,
   olhando a **linha original**:
   - `attachLeft` = existe caractere anterior e ele não é espaço
   - `attachRight` = existe caractere seguinte e ele não é espaço
   - `attached = attachLeft || attachRight`
5. O texto de uma célula vai do fim do acorde até o próximo acorde (ou o fim da
   linha), **com o espaço em branco preservado byte a byte**. Texto antes do
   primeiro acorde vira uma célula com `chord: null`.
6. `\[` e `\]` escapados são texto literal, não delimitador de acorde.
7. Um `[]` vazio é tratado como texto literal, não como acorde sem nome.

8. Uma música cujo parse não produz **nenhuma** `ChordProLyricLine` conta como
   indisponível, mesmo com HTTP 200. O corpus tem um arquivo assim — uma lápide
   com diretivas e notas `;` explicando que a cifra foi removida por PDF errado.
   O sheet não lista e o leitor mostra o estado de indisponível.

O parser não normaliza acordes, não transpõe e não conserta OCR. Só estrutura.

### 3.4 Renderização

Novo: `lib/features/chords/presentation/widgets/chordpro_view.dart`

Cada `ChordCell` vira uma `Column`: rótulo do acorde em cima, texto embaixo. A
linha é um `Wrap` dessas colunas, o que resolve quebra em tela estreita sem
perder o alinhamento acorde↔sílaba (a quebra acontece entre células, nunca
dentro de uma).

```
ha[Cm]bi - [Gm]ta, ó [Ab]Deus!          [E]   A linda [A]flor

      Cm      Gm      Ab                E          A
  ha │bi -  │ta, ó  │Deus!                 A linda│flor
     ↑       ↑       ↑                  ↑         ↑
  encosta encosta encosta            solto:    encosta
                                   sem barra, 3 espaços
                                  preservados no texto
```

- A barra vermelha é um `Container` de 2 lg colado na borda esquerda do texto da
  célula, desenhado só quando `attached`. Altura = altura da linha de texto.
- Célula com `text` vazio e `attached` (o caso `Sinai[C#m7]`) desenha a barra
  logo após o texto da célula anterior — cai naturalmente, já que a barra fica na
  borda esquerda de um texto de largura zero.
- O espaço em branco é texto de verdade na linha de baixo, então
  `"Deus é Amor [C]"` e `"Deus é Amor   [C]"` divergem sozinhos, sem cálculo
  especial. Requer fonte que não colapse espaços: `Text` com
  `softWrap: false` dentro da célula.
- Quando o rótulo do acorde é mais largo que o texto da célula, a célula assume a
  largura do rótulo e empurra o resto — que é como a cifra impressa se comporta.
- `ChordProStanzaBreak` vira `SizedBox` vertical; `ChordProCommentLine`, texto
  itálico secundário.

### 3.5 Dados

`ColdigomLouvorAdapter` ganha:

```dart
static List<ChordMaterial> toChordMaterials(PraiseDetailDto praise);
// filtra type == 'chord' com r2Key não vazio
```

`MaterialDto` já carrega `type` e `r2Key` — nenhuma mudança de DTO.

Novo: `lib/features/chords/data/datasources/chord_content_datasource.dart`

```dart
Future<String?> fetch(String r2Key);   // null em 404
```

Monta a URL com a mesma lógica de `AudioTrackUrl.fetchUrlForKey` (proxy
`/api/coldigom/<key>` na web, direto no nativo). Essa lógica é extraída de
`audio_track_url.dart` para `lib/core/utils/coldigom_asset_url.dart` e passa a
ser compartilhada — `AudioTrackUrl` delega, mantendo sua API pública.

Cache em memória `Map<String, String>` por `r2Key`, num provider Riverpod de
escopo de app. Como os arquivos têm 611 B em média, o cache do sheet serve o
leitor sem segunda ida à rede. Sem persistência em Isar nesta etapa.

### 3.6 Seção "Cifras" no sheet

`LouvorGroup` ganha `List<ChordMaterial> chordMaterials`, agrupado por `groupId`
em `fromLouvores` exatamente como `youtubeMaterials`, e somado em
`totalMaterials`. `withColdigomMeta` propaga o campo.

`ColdigomSearchRepositoryImpl` e o warmup de cache passam a coletar cifras junto
com PDFs, áudios e YouTube.

No sheet, a seção nova entra **entre PDFs e Áudios** — cifra é material de
leitura, fica perto dos PDFs. Ícone `Icons.music_note` (o que
`LouvorMaterialIcons.forCategory` já devolve para `cifra`). Título via l10n nova
`chordMaterialSection` = "Cifras" / "Chords".

**Disponibilidade (decisão 4):** ao montar o sheet, um provider dispara um `GET`
por `ChordMaterial` do grupo (tipicamente 1–2) e a seção só renderiza os que
responderam 200 **e cujo parse produziu ao menos uma linha de letra** (regra 8
de §3.3). Enquanto as respostas não chegam, a seção não aparece — sem
placeholder e sem pulo de layout para a maioria dos louvores, que não tem cifra
publicada. O corpo baixado já entra no cache de §3.5.

### 3.7 Rota e página

`RoutePaths.chords = '/cifra'`, irmã de `/leitor` e `/audio` sob a branch Home no
`StatefulShellRoute` — mesmo shell, mesmo carousel.

`buildChordReaderLocation({required String chordId, String? titulo, String? subtitulo})`
em `lib/core/utils/chord_reader_url_builder.dart`, espelhando
`reader_url_builder.dart`. Não há param `file`: o id decodifica para o `r2Key`,
então a URL é `/cifra?pdfId=…&titulo=…`.

**Reusa `UrlSyncParams.pdfId`, sem param novo.** `CarouselChips` lê o id sempre
de `UrlSyncParams.pdfId` (`_resolveReaderPdfId`) e decide se está num leitor por
um gate único, `_isReaderRoute`. Reusando a chave, a sincronização de carousel no
leitor de cifras custa uma linha — estender `_isReaderRoute` para aceitar
`RoutePaths.chords` — em vez de um segundo caminho de params paralelo.

`ChordReaderScreen` (`lib/features/chords/presentation/pages/chord_reader_screen.dart`):

- Cabeçalho com `title`/`subtitle` do arquivo, e `key` · `rhythm` · `artist`
- Corpo: `ChordProView` em scroll vertical
- AppBar: toggle claro/escuro (`Icons.light_mode` / `Icons.dark_mode`)
- Barra de carousel, como o `/leitor` tem, incluindo `CarouselSwapMaterialButton`
- Estados: carregando, 404 ("cifra ainda não disponível"), erro de rede

### 3.8 Tema do leitor

O app tem paleta litúrgica única (`AppColors`), sem dark mode. O toggle é local
ao leitor de cifras e não vaza para o resto da UI.

`ChordReaderTheme { light, dark }` com dois conjuntos: fundo, texto da letra,
texto do acorde, vermelho da barra. No claro, fundo `AppColors.card` (creme) e
texto `AppColors.textDark`; no escuro, fundo próximo de `AppColors.pdfArea` e
texto `AppColors.textLight`. O vermelho da barra é ajustado por tema para manter
contraste — o mesmo tom sobre creme e sobre carvão não lê igual.

Persistido em `StorageKeys.chordReaderTheme` via um datasource no molde de
`ReaderPreferencesDatasource`.

### 3.9 Carousel e playlist

Como o `chordId` vive no espaço do `pdfId`, `addLouvorToCarousel`, reorder,
persistência, sync de playlist e `carouselPdfIdsProvider` funcionam sem mudança.
O que muda:

- `ReaderCarouselActionsNotifier.navigateToPdfId` — hoje faz
  `findLouvorByPdfIdWithColdigom` e devolve `/leitor`. Passa a checar
  `materialIdKindOf` primeiro e, sendo cifra, devolver
  `buildChordReaderLocation`. Precisa de um lookup de `ChordMaterial` por
  `chordId`, análogo ao cache de louvores coldigom.
- `CarouselChips._isReaderRoute` — passa a aceitar `RoutePaths.chords` além de
  `RoutePaths.reader`. Sem isso, navegar pelo carousel dentro do leitor de cifras
  daria `push` em vez de `replace` e o chip focado não sincronizaria.
- `buildCarouselMetadataMap` — inclui cifras, para o chip mostrar
  `numero — nome` e a categoria certa.
- `CarouselSwapMaterialButton` — o sheet de troca ganha a seção Cifras pelo mesmo
  caminho do §3.6, já que reusa `showLouvorMaterialSheet`.

Guardas nos caminhos que assumem PDF, todas via `materialIdKindOf`:

- `LouvorPdfPath.fromLouvor` / `resolvePdfForReaderProvider` — cifra nunca chega
  lá, mas a guarda impede regressão silenciosa
- prefetch de PDFs adjacentes — pula ids de cifra
- compartilhar / salvar PDF — desabilitado para cifra
- download offline — fora do escopo desta etapa; cifra não é baixada

O folheto (UC-08) não precisa de guarda: `LeafletDocument` usa só
`numero`/`nome` do metadata, então uma cifra na lista vira uma linha de título
normal.

## 4. Testes

Unitários (`test/unit/features/chords/`):

- **Parser** — as sete regras de §3.3, uma a uma. Fixtures reais: os arquivos
  publicados que cobrem cada caso de adjacência, incluindo os 9 de
  `texto → espaço/fim` (`Sinai[C#m7]`, `Se[A]nhor.[E]`) e os de espaçamento
  múltiplo (`[E]   A linda`).
- **Adjacência** — tabela de `(antes, depois) → attached` cobrindo as 7 combinações.
- **Espaçamento** — `"Deus é Amor [C]"` e `"Deus é Amor   [C]"` produzem células
  com `text` diferente.
- **Discriminador** — `materialIdKindOf` para `.pdf`, `.chord`, id inválido.
- **Adapter** — `toChordMaterials` filtra por type e r2Key vazio.
- **URL** — `coldigom_asset_url` monta proxy e direto; `AudioTrackUrl` não regride.

Widget (`test/widget/features/chords/`):

- Sheet mostra a seção Cifras só para os materiais disponíveis; some quando
  nenhum responde 200.
- `ChordProView` desenha barra em célula `attached` e não desenha em célula solta.
- Toggle de tema troca as cores e persiste.

Fixtures: os 57 `.chord` publicados foram baixados durante o levantamento; um
subconjunto representativo entra em `test/fixtures/chordpro/`.

## 5. Fora de escopo

- Transposição de tom
- Auto-scroll / modo palco
- Edição ou correção de cifra no app
- Download offline de cifra
- Consumo de `raw_chordpros` ou do staging local
- Publicar os 2.214 `.chord` faltantes (trabalho do lado do coldigom)

## 6. Riscos

**Cobertura de 2,5%.** A seção Cifras vai aparecer em pouquíssimos louvores até a
revisão avançar. É esperado, e a decisão 4 garante que o usuário nunca vê uma
cifra que não abre. Vale confirmar com os 57 publicados que a experiência está
boa antes de investir mais.

**Qualidade do que for publicado depois.** Os 57 atuais estão limpos porque foram
revisados. Se o pipeline publicar em lote sem revisão, chega `|` cru e ruído de
OCR no app. O parser trata `|` como texto literal, então apareceria como um
caractere estranho na letra — degrada, não quebra.

**Largura do rótulo do acorde.** Sequências densas (`ex[Bm]cel-[E7]so a[A]mor`)
esticam o texto. Aceitável e fiel ao impresso, mas merece olhada em tela estreita.
