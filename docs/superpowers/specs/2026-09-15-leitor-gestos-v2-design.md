# Leitor de Gestos v2 — tema, leitura linear, autoscroll e zebra

Data: 2026-09-15
Origem: `2026-09-11-leitor-gestos-design.md` (v1, contrato de dados e blocos).
Este spec **substitui** a §4 «Regras de renderização» da v1 no que diz respeito
a cores, papel e cartão; o contrato de dados (§3) e a arquitetura de dados
(§5) da v1 continuam valendo.

## 1. Contexto

### Problema

O leitor de gestos (`/gestos`) nasceu com papel branco puro, cartões sem fundo
e sem dark mode — visualmente pobre ao lado do leitor de cifras, que já tem
tema claro/escuro local, zebra e autoscroll. Além disso, a estrutura do
documento (`Nx`, `CORO`, «Voltar ao coro», «Repetir o louvor») é fiel ao PDF
mas obriga a professora a interpretar saltos enquanto faz os gestos com as
mãos — e, com as mãos ocupadas, ela também não consegue rolar a tela.

### O que o repo já tem (verificado em 2026-09-15)

- `ChordReaderMode` + `ChordReaderPalette` (`lib/features/chords/presentation/theme/chord_reader_theme.dart`):
  claro/escuro **local ao leitor**, persistido em `StorageKeys.chordReaderMode`,
  sem tocar em `ThemeData`. Creme `AppColors.card` / carvão `AppColors.pdfArea`.
- `chordAutoscrollProvider` (`running`, `speed` 1–5, `autoDispose`) + motor
  `Ticker` no `State` de `ChordReaderScreen` (`_onAutoscrollTick`,
  `kChordAutoscrollPxPerSecondPerSpeed = 12`). Rolar com o dedo **para** o
  autoscroll (não retoma). Atalhos `S`, `[`, `]`.
- `_ChordReaderToolbar`: ícones dourados, `_ToolbarSeparator` entre grupos.
- `GestureReaderPalette` (constantes estáticas), `GestureDocumentView`
  (recursão sobre `GestureItem`, contador de índice igual ao
  `flattenGestureCards`), `GestureFocusView` (`PageView` sobre o `flatten`),
  `GestureReaderPreferencesDatasource` (só fonte).
- Figuras do dicionário: PNG ~100 px, **coloridas** (pele, setas laranja),
  borda preta desenhada dentro da imagem, fundo branco. Não invertem.
- `GestureItem` é `sealed`; variante nova quebra cada `switch` em compilação.

## 2. Decisões

1. **Linearização no domínio**, não na renderização: `linearizeGestureDocument`
   é função pura `GestureDocument → GestureDocument`. Página, `flatten` e
   modo foco recebem o documento já expandido e não sabem do modo. (Alternativas
   descartadas: expandir ao montar widgets — obrigaria o `flatten` a replicar a
   regra; pré-expandir no worker — dependeria de outro repo.)
2. **`SectionLabel` é variante nova de `GestureItem`.** Só o linearizador a
   produz; o parser nunca. Rótulo l10n na renderização.
3. **Tema, linear e velocidade persistem; `running` não.** Tema do leitor de
   gestos é **independente** do de cifras (quem rege gestos não
   necessariamente abre cifra). Leitura linear **default ligada**.
4. **Autoscroll retoma após scroll manual**, diferente da cifra (que só para).
   Pausa ao detectar o dedo, espera 1 s depois do fim do gesto, continua da
   posição em que a página ficou.
5. **Figura sempre em quadro branco.** Os PNGs não admitem inversão nem blend
   sobre carvão; o quadro branco arredondado é a leitura honesta da imagem.
6. **Paleta vira instância** (`GestureReaderPalette` com campos), escolhida
   por `GestureReaderMode`. Todos os widgets do leitor recebem a paleta por
   parâmetro, como `ChordProView` recebe `ChordReaderPalette`.

## 3. Tema claro/escuro

### 3.1 Modo

`enum GestureReaderMode { light, dark }` em
`presentation/theme/gesture_reader_theme.dart`, com `palette`, `toggle()`,
`toStorageString()`/`fromStorageString()` — cópia da forma de
`ChordReaderMode`. Persistido em `StorageKeys.gestureReaderMode`
(`'gestureReaderMode'`), default `light`.
`gestureReaderModeProvider` (`Notifier`, não `autoDispose`) em
`presentation/providers/gesture_reader_mode_provider.dart`.

### 3.2 Paleta

`GestureReaderPalette` passa a ser classe com campos `const`:

| Campo | Papel | Claro | Escuro |
|---|---|---|---|
| `paper` | fundo da página | `AppColors.card` (`#FFF8E1`) | `AppColors.pdfArea` (`#2A2A2A`) |
| `stripe` | zebra (cartões ímpares) | `0x0A6A2F2F` | `0x12FFFFFF` |
| `trigger` | gatilho | `#C62828` | `#FF5252` |
| `lyric` | leitura e título | `AppColors.textDark` (`#2C3E50`) | `AppColors.textLight` |
| `blue` | chave, `Nx`, `CORO`, chips do foco | `#1E63C8` | `#7FA9F0` |
| `orange` | conector de ligação | `#E08A1E` | `#F0B35A` |
| `wine` | divisor e rótulo `FINAL` | `AppColors.title` | `AppColors.goldLight` |
| `instructionBg` / `instructionText` / `instructionBorder` | cartão de instrução | `#F3EDDC` / `#4A4036` / `#D9CFB8` | `#3A3A3A` / `#D0D0D0` / `#555555` |
| `sectionLabel` | rótulo discreto (linear) e `text` livre | `#8A7F70` | `#9E9E9E` |
| `placeholderBg` / `placeholderBorder` | gesto ausente | `#FFF7E6` / `#E0B45C` | `#3D3420` / `#B8933E` |
| `figureBg` / `figureBorder` | quadro da figura | branco / `0x1A000000` | branco / `0x33FFFFFF` |
| `toolbarIcon` | ícones da barra 3 | `AppColors.title` (vinho — ouro sobre creme não tem contraste; é o que a cifra faz) | `AppColors.goldLight` |
| `divider` | separador da barra e rodapé do foco | `0x666A2F2F` | `0x66FFFFFF` |

`BracePainter`, `LinkConnectorPainter`, `FinalSectionView`,
`InstructionCardView`, `TextLineView`, `GestureFigure`, `LyricLineText`,
`GestureFocusView` e a barra passam a receber `palette`. Os construtores
deixam de ser `const` onde a paleta entra.

O quadro da figura: `ClipRRect(8)` + `ColoredBox(figureBg)` + borda 1 dp
`figureBorder`. A imagem continua `BoxFit.contain` com padding interno de 4 dp
para a borda preta do PNG não colar no arredondamento.

### 3.3 Barra 3

Espelho de `_ChordReaderToolbar`, alinhada à direita, ícones em
`palette.toolbarIcon`, `_ToolbarSeparator` em `palette.divider`:

```
A-  A+  |  ▶/⏸  3x  |  ☰/⌥  |  ☾/☀  |  ⛶
```

- `☰/⌥`: `Icons.view_agenda_outlined` quando linear (tooltip «Leitura
  estruturada»), `Icons.account_tree_outlined` quando estruturado (tooltip
  «Leitura linear»). O ícone mostra o **estado atual**, como o de tema.
- `☾/☀`: `Icons.dark_mode` no claro, `Icons.light_mode` no escuro.
- `3x`: `TextButton` que cicla 1→5→1, como na cifra.

Largura mínima: 7 botões × 40 + 3 separadores ≈ 330 dp — cabe em 360.

## 4. Cartão, zebra e alinhamento

`GestureCardTile`:

- Ocupa a largura inteira do nível em que está. Fundo `stripe` quando
  `index.isOdd` (índice do `flatten`), transparente quando par; cantos 6 dp;
  padding `EdgeInsets.symmetric(horizontal: 12, vertical: 10)`.
- `Row(crossAxisAlignment: CrossAxisAlignment.center)`: figura e coluna de
  letra **centralizadas verticalmente** entre si, com 1 ou 3 linhas.
- Gap entre cartões vizinhos: **4 dp** (era 12). Entre blocos: 16 (era 20).
  Dentro de `link`: 0, como hoje.
- Dentro de `Nx`/`CORO` (modo estruturado) a zebra continua pelo índice; a
  chave fica na coluna à direita, fora da faixa.
- Título: `AppTypography.headline` em `palette.lyric`, com 20 dp abaixo.

## 5. Leitura linear

### 5.1 Preferência

`gestureReaderLinearProvider` (`Notifier<bool>`, persistido em
`StorageKeys.gestureReaderLinear`, **default `true`**), `toggle()`.
`GestureReaderPreferencesDatasource` ganha `getLinear`/`saveLinear`,
`getMode`/`saveMode`, `getAutoscrollSpeed`/`saveAutoscrollSpeed`.

### 5.2 `SectionLabel`

```dart
/// Rótulo discreto que o linearizador insere entre trechos expandidos.
final class SectionLabel extends GestureItem {
  const SectionLabel.chorus() : pass = null;
  const SectionLabel.pass(int this.pass);
  /// `null` = «coro»; `k` (≥ 2) = «kª vez».
  final int? pass;
}
```

Renderização (`SectionLabelView`): linha de largura total, texto em caixa
alta, `fontSize × 0.7`, `FontWeight.w600`, `letterSpacing 1`, cor
`palette.sectionLabel`, padding vertical 6. l10n: `gestureSectionChorus`
(«coro» / «chorus»), `gestureSectionPass` («{n}ª vez» / «time {n}»).

`flattenGestureCards` e `GestureDocumentView._isBlock` tratam `SectionLabel`
como `InstructionCard`/`TextLine` (não é cartão, não é bloco).
`GestureDocument.hasGestures` idem.

### 5.3 `linearizeGestureDocument`

`domain/usecases/linearize_gesture_document.dart`. Pura. Percorre `items` em
ordem, emitindo numa lista de saída, com dois registradores: `lastChorus`
(`List<GestureItem>` já linearizada do último `ChorusBlock` visto, em qualquer
profundidade) e a própria saída (para «repetir o louvor»).

| Entrada | Saída |
|---|---|
| `GestureCard`, `TextLine`, `InstructionCard(instruments)` | inalterado |
| `RepeatBlock(n, children)` | `L(children)` n vezes; antes da passagem k ≥ 2, `SectionLabel.pass(k)` |
| `ChorusBlock(children)` | `SectionLabel.chorus()` + `L(children)`; `lastChorus = L(children)` |
| `InstructionCard(backToChorus)` | `SectionLabel.chorus()` + `lastChorus`; se `lastChorus == null`, mantém a instrução |
| `InstructionCard(backToChorusAndFinish)` | igual a `backToChorus` (o `FinalBlock` já vem depois na raiz) |
| `InstructionCard(repeatPraise)` | `SectionLabel.pass(2)` + cópia de tudo já emitido na raiz até ali; se nada foi emitido, mantém a instrução |
| `LinkBlock(children)` | `LinkBlock(L(children))` |
| `FinalBlock(children)` | `FinalBlock(L(children))` |
| `SectionLabel` (entrada já linear) | inalterado |

`L(children)` é a recursão; `lastChorus` é global ao documento (um `coro`
dentro de `Nx` conta). Blocos aninhados multiplicam: `2x{ 3x{ g } }` → 6 `g`,
com rótulos «2ª vez»/«3ª vez» internos e «2ª vez» externo. `repeatPraise`
dentro de bloco copia só o que a raiz emitiu até o início daquele bloco
(o bloco em andamento não está na saída ainda) — comportamento aceito, não é
caso real. Um segundo `repeatPraise` copia a saída inteira de novo (inclusive
a primeira cópia); documentos reais têm no máximo um.

`GestureReaderScreen`:

```dart
final shown = linear ? linearizeGestureDocument(document) : document;
final flat = flattenGestureCards(shown);
```

`shown` vai para `GestureDocumentView` e `flat` para o foco. Trocar o modo
recria a view (key por modo) — o `scrollToCard` não tenta preservar posição
entre modos.

Modo foco em linear: os chips de contexto `Nx`/`CORO` somem sozinhos (os
blocos não existem mais); `FINAL` e `ligação` continuam.

## 6. Autoscroll com retomada

### 6.1 Estado

`gestureAutoscrollProvider` (`NotifierProvider.autoDispose`) com
`GestureAutoscrollState { bool running; int speed }`, `speed` 1–5, default 3,
**persistido** (`StorageKeys.gestureAutoscrollSpeed`); `running` some com o
`autoDispose`. `toggle()`, `setSpeed()`, `stop()` como na cifra.

`GestureAutoscrollSpeed { min 1, max 5, initial 3, pxPerSecondPerLevel 10 }`
(entidade de domínio, forma de `GestureReaderFontSize`) → 10–50 px/s
(cifra: 12–60).

### 6.2 Motor

No `State` de `GestureReaderScreen` (`SingleTickerProviderStateMixin`),
cópia de `_ensureAutoscrollTicker`/`_onAutoscrollTick`/`_stopAutoscroll` da
cifra, mais:

- `_pausedByUser` (bool) e `_resumeTimer` (`Timer?`). O `Ticker` **não** para
  durante a pausa: só deixa de mover a página.
- `NotificationListener<ScrollNotification>` em volta da view:
  - `UserScrollNotification` com `direction != idle` → `_pausedByUser = true`,
    `_resumeTimer?.cancel()`.
  - `ScrollEndNotification` enquanto `_pausedByUser` e sem timer armado →
    `_resumeTimer = Timer(1 s, () => _pausedByUser = false)`. (O `jumpTo` do
    motor também emite `ScrollEnd`, mas com `_pausedByUser == false` é
    ignorado; a roda do mouse emite `UserScroll` + `ScrollEnd`, então cada
    notch pausa e rearma.)
  - Quando o timer dispara, o tick seguinte parte de `position.pixels` (o
    motor nunca guarda alvo, então a "nova posição" é automática).
- `_onAutoscrollTick` atualiza o relógio e retorna sem rolar enquanto
  `_pausedByUser`.
- Chegou em `maxScrollExtent` → `stop()` (botão volta a ▶).
- `didUpdateWidget` com outro `pdfId` → `_stopAutoscroll()` + cancela timer.
- `dispose` cancela timer e ticker.
- Fechar o modo foco chama `scrollToCard` (animação programática, sem
  `UserScrollNotification`) — não interfere.

### 6.3 Atalhos

`S` liga/desliga, `[`/`]` velocidade — em `_onKeyEvent`, sem modificador,
como na cifra (as setas sem modificador seguem reservadas ao foco).

## 7. Arquivos

Novos:

```
lib/features/gestures/domain/usecases/linearize_gesture_document.dart
lib/features/gestures/presentation/theme/gesture_reader_theme.dart      (GestureReaderMode)
lib/features/gestures/presentation/providers/gesture_reader_mode_provider.dart
lib/features/gestures/presentation/providers/gesture_reader_linear_provider.dart
lib/features/gestures/presentation/providers/gesture_autoscroll_provider.dart
lib/features/gestures/presentation/widgets/section_label_view.dart
test/unit/features/gestures/linearize_gesture_document_test.dart
test/unit/features/gestures/gesture_reader_preferences_test.dart
test/unit/features/gestures/gesture_autoscroll_provider_test.dart
test/widget/features/gestures/gesture_card_tile_test.dart
test/widget/features/gestures/gesture_reader_toolbar_test.dart
test/widget/features/gestures/gesture_reader_autoscroll_test.dart
```

Alterados: `gesture_document.dart` (+`SectionLabel`), `flatten_gesture_cards.dart`,
`gesture_reader_palette.dart` (vira instância), todos os widgets de
`presentation/widgets/`, `gesture_reader_screen.dart`,
`gesture_reader_preferences_datasource.dart`, `storage_keys.dart`,
`app_pt.arb`/`app_en.arb` (+`gestureSectionChorus`, `gestureSectionPass`,
`gesturesReaderLinear`, `gesturesReaderStructured`, `gesturesReaderToggleTheme`,
`gesturesAutoscrollPlay`/`Pause`/`Speed`), testes existentes de gestos que
referenciam constantes da paleta.

## 8. Testes

Unit:

- `linearize_gesture_document_test`: cada linha da tabela 5.3; fixture 181
  (`2x` na raiz → 8 cartões + «2ª vez»); 182 (coro + `backToChorus` — verificar
  que o coro reaparece com rótulo); `sintetico_final_link` (`3x` com `link`
  dentro, `coro{2x}`, `final`); `backToChorus` sem coro mantém instrução;
  `repeatPraise` duplica a saída; idempotência (`L(L(d)) == L(d)`).
- Preferências: default `light`/`true`/`3`; leitura de valor inválido cai no
  default; `toggle` persiste.
- `gesture_autoscroll_provider_test`: `setSpeed` grampeia; `stop` idempotente.

Widget:

- `GestureCardTile`: cartão ímpar tem `stripe`, par não; figura e letra
  centralizadas (mesmo `dy` do centro com 3 linhas).
- Tela: toggle de tema troca a cor do `paper`; toggle linear faz
  `SectionLabel` aparecer/sumir; barra tem os 7 botões.
- Autoscroll: play → `pixels` cresce após `pump`; drag do usuário → `pixels`
  não muda por 1 s após o `ScrollEnd`; após `pump(1 s)` volta a crescer a
  partir da posição do drag; fim da página → `running == false`.

Validação manual em produção v2 (`v2.plpcg.com`), celular, aba visível: um
louvor com coro + «voltar ao coro» nos dois modos e nos dois temas; autoscroll
com interrupção pelo dedo.

## 9. Fora de escopo

- Autoscroll no modo foco (é paginado, não rola).
- Sincronizar tema/linear entre leitor de cifras e de gestos.
- Alterar o contrato do documento ou o coldigom.
- Preservar a posição de rolagem ao trocar linear ↔ estruturado.
