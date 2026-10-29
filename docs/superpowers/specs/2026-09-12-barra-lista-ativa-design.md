# Barra da Lista Ativa — redesenho de usabilidade

**Data:** 2026-09-12
**Estado:** aprovado (decisões tomadas sobre mockups em `claude.ai/code/artifact/7c36ac25-abc6-4296-a26c-fe686eff16fc`)
**Escopo:** barra global do carrossel (`CarouselChips` e filhos), mini-player, sheet «Lista», tela de Playlists, remoção do conceito de *face* (PDF × Áudio).

## 1. Problema

A barra da lista ativa é o carro-chefe da app junto com a busca, mas só é legível para quem a construiu:

1. O toggle de face mostra o **destino** (♪ na face partitura, 📄 na face áudio) — a pessoa não sabe se o ícone diz "está aqui" ou "vai para lá".
2. Três escopos com o mesmo peso visual, lado a lado: ações do **louvor** (abrir, trocar material), ações da **lista** (ver, compartilhar, limpar) e o **modo** da barra.
3. `Icons.clear_all` (≡) parece menu, mas apaga a lista; fica colado ao Compartilhar.
4. `open_in_full` (↗) lê-se "tela cheia"; `visibility` (👁) lê-se "preview"; `layers` (⧉) não comunica "trocar material".
5. Na face áudio há dois pares de setas: `< >` (louvor) e `|◀ ▶|` (faixa dentro do grupo). Escolher a voz (Coro → Soprano) é escolha de material, não "próxima faixa".
6. As setas de louvor somem quando não há anterior/próximo, e são finas — ninguém as percebe.
7. As duas faces são duas filas paralelas na tela, contra o princípio 4 do `PRODUCT.md` ("lista é de louvores, não de um tipo de arquivo").

## 2. Decisões (fechadas)

| # | Decisão |
|---|---|
| D1 | **Sem faces.** A lista ativa é uma sequência única de entradas (partitura, cifra, gesto, áudio) na ordem da lista. `PlaylistMediaFace`, `playlistMediaFaceProvider` e o toggle da tela de Playlists são **removidos**. |
| D2 | **Grupos por escopo** na barra: grupo *louvor* (Abrir, Material) e grupo *lista* (Lista, Compartilhar, Limpar), cada um com fundo tintado leve e um divisor vertical entre eles. **Sem** rótulo de texto sob os grupos. |
| D3 | **Legendas** (ícone em cima, texto embaixo) em todos os botões quando a barra tem ≥ 600 px de largura lógica; só ícones abaixo disso. |
| D4 | **Ícones:** Abrir = `Icons.file_open_outlined`; Material = `Icons.change_circle_outlined`; Lista = `Icons.queue_music`; Compartilhar = `Icons.adaptive.share` (inalterado); Limpar = `Icons.delete_outline`. |
| D5 | **Setas de louvor dentro do chip** (o chip é o carrossel): duas zonas de 36 px nas bordas do cartão preto, chevron **branco/creme** (`AppColors.card`), fundo `white 6 %`. **Sempre presentes**; nos extremos ficam a 35 % de opacidade e desabilitadas. |
| D6 | O botão «Ouvir» (tocar a lista) **não existe**. Reprodução começa por «Abrir» numa entrada de áudio ou pelo sheet de materiais. |
| D7 | **Mini-player** aparece sempre que há faixa corrente (`currentTrack != null`) e ganha **seek arrastável com marcadores (flags)** — o que a face áudio oferecia. Altura continua `kMiniPlayerBarHeight`. |
| D8 | O `|◀ ▶|` de dentro do grupo sai da barra. As setas do mini-player continuam sendo faixa anterior/próxima da fila. |
| D9 | «Rascunho» (chip do nome da lista) ganha `Icons.edit` à direita do texto; comportamento inalterado. |
| D10 | Tela de Playlists: sem toggle; contagem `N partituras · M áudios`; tile expandido mostra chips **mistos** na ordem da lista, cada um com o ícone do tipo; menu com «Abrir no leitor» **e** «Abrir no reprodutor». `PlaylistAudioFacePanel` é removido. |

## 3. Anatomia da barra

```
[Rascunho ✎] [‹ Shekinah  #047 🎹 Coro ›]   ┃ Abrir  Material ┃ Lista  Compartilhar  Limpar
                                               (grupo louvor)      (grupo lista)
────────────────────────────────────────────────────────────────────────────────────
♪ 047 — Shekinah · Coro   0:02 ━━|━━━|━━━━ 4:21   |◀  ⏸  ▶|      ← mini-player, só tocando
```

- **Largura ≥ 600 px:** botões com legenda (50 px de altura, legenda 10–11 px `AppTypography.label`, `w600`). `ActivePlaylistNameChip` visível (regra C11 atual: some abaixo de 480 px — mantida).
- **Largura < 600 px:** botões só ícone (`carouselBarIconButtonStyle`, 42 px). Todos os cinco botões continuam na barra; em 360 px cabem chip (≥ 96 px) + 5 × 34 px.
- **Fullscreen do leitor:** barra oculta, mini-player em overlay — inalterado.
- **Grupos:** `Container` com `borderRadius: 12`, fundo `AppColors.title.withValues(alpha: .08)` (louvor) e `AppColors.gold.withValues(alpha: .18)` (lista); divisor `VerticalDivider` 1 × 28 px `AppColors.title` a 38 %.

### 3.1 Chip (`CarouselLouvorChip`, variante `topBar`)

- Layout: `[zona ‹ 36 px] [corpo: nome / #numero · ícone-tipo · categoria] [zona › 36 px]`.
- Ícone do tipo no subtítulo: partitura `LouvorMaterialIcons.pdf` (piano), cifra e gesto os seus, áudio `LouvorMaterialIcons.audio` (♪).
- Toque no corpo = «Abrir». Toque nas zonas = anterior / próximo. Zonas desabilitadas nos extremos (opacidade 35 %, sem `onTap`), **nunca removidas**.
- Semântica: zonas com `tooltip` «Louvor anterior» / «Próximo louvor» (chaves l10n existentes).
- A variante `modal` (usada no sheet e na tela de Playlists) **não** tem zonas de seta.

### 3.2 Grupo louvor

- **Abrir** (`file_open_outlined`, legenda `Abrir`): entrada não-áudio → abre no leitor (fluxo atual `_openInReader` / `openCarouselPdfInReader`); entrada de áudio → `pushAudioPlayerRoute` **e** inicia a reprodução com a fila híbrida atual (`queueForTrack`: a lista se a faixa está nela, senão o grupo). No leitor, «Abrir» some (já é o caso: `onOpenPlayer == null`).
- **Material** (`change_circle_outlined`, legenda `Material`): `CarouselSwapMaterialButton` da entrada focada — abre o sheet de materiais com abas (já existe). Para entrada de áudio, `materialId` = o áudio, `entryKey` = a chave da ocorrência; escolher outra faixa do grupo troca a entrada **e** a faixa corrente, se ela estiver tocando.

### 3.3 Grupo lista

- **Lista** (`queue_music`, legenda `Lista`): `showCarouselSelectionSheet` com `ActiveListPanel` sem parâmetro de face — todas as entradas, reorder sobre a lista inteira (`ActivePlaylistEditor.reorderFace` → `reorder`, recebendo a ordem completa de chaves). Toque numa entrada: não-áudio abre no leitor; áudio = «Abrir» de áudio.
- **Compartilhar**: inalterado (`CarouselBarTrailingActions._openShareSheet`).
- **Limpar** (`delete_outline`, legenda `Limpar`): inalterado (`showCarouselClearChoiceDialog`).

## 4. Modelo de dados e providers

| Hoje | Passa a ser |
|---|---|
| `carouselItemsProvider` = entradas não-áudio | `carouselItemsProvider` = **todas** as entradas, na ordem da lista (`index` = posição na lista inteira) |
| `audioFaceItemsProvider` = entradas de áudio | `audioCarouselItemsProvider` = entradas de áudio (derivado de `carouselItemsProvider`, `where(isAudio)`); alimenta `activeListAudioQueue` |
| — | `readableCarouselItemsProvider` = entradas não-áudio (`where(!isAudio)`); alimenta `readerCarouselPositionProvider`, `readerCarouselActionsProvider` e `audio_follow_reader` (o leitor navega só entre o que se lê) |
| `focusedCarouselItemProvider` sobre a face PDF | idem, sobre a lista inteira |
| `_enrich` sem ramo de áudio | novo ramo: `lookup.audioTrack(entry.id)` → `numero`, `nome`, `categoria` (kind do material Coldigom), `source`; fallback igual ao atual |
| `playlistMediaFaceProvider`, `PlaylistMediaFace`, `PlaylistMediaFaceNotifier`, `PlaylistMediaFaceToggle`, `CarouselAudioFaceBar`, `shouldShowCarouselAudioFace`, `PlaylistAudioFacePanel` | **removidos**. SharedPreferences `playlist_media_face` deixa de ser lida (não precisa migrar; chave morta). |
| `open_audio_in_player.dart` seta face áudio | não seta nada |
| `playlists_provider._releaseMediaSelectionViews` seta face PDF | não seta nada |
| `playlist_session_hydrate` reseta face se não há faixas | só o `return true` |
| `ShellScaffold.showMiniPlayer = currentTrack != null && !shouldShowCarouselAudioFace(...)` | `= currentTrack != null` |

**Foco na lista unificada.** `carouselFocusedIndexProvider` / `carouselFocusedKeyProvider` seguem por chave; como `carouselItemsProvider` passa a incluir áudio, o foco pode cair numa entrada de áudio (chip ♪). Focar **não** toca: só «Abrir» toca.

**Leitor.** `readerCarouselPositionProvider(materialId)` deriva de `readableCarouselItemsProvider`; as setas do chip no leitor andam só entre entradas legíveis. No shell, andam pela lista inteira.

**Seguir o áudio.** Inalterado em comportamento; a resolução do PDF do louvor tocando usa `readableCarouselItemsProvider`.

## 5. Mini-player

- Visível sempre que `currentTrack != null`; overlay em fullscreen inalterado.
- A linha de progresso vira `AudioSeekBar(compact: true, onLightBackground: true, flags: …, onSeek: …, onFlagTap: …)` — o mesmo widget que a face áudio usava — dentro dos 44 px atuais (título à esquerda, seek no meio, transporte à direita; em < 400 px o título trunca com ellipsis).
- Transporte: anterior / play-pausa / próxima (inalterado).

## 6. Tela de Playlists (D10)

- Remove o `PlaylistMediaFaceToggle` e o `Padding` que o envolve.
- `PlaylistListTile`: `countLabel` = `l10n.playlistEntryCount(pdfs, audios)` → «3 partituras · 1 áudio» (plural em pt/en; omite a parte zerada: «3 partituras», «1 áudio»).
- Tile expandido: `PlaylistTileDetailChips` itera `activeEntriesOf(playlist.entries)` **sem** filtrar por tipo; chip de áudio com ♪; toque em áudio → `openAudioInPlayer(track)` (util existente), toque em partitura → `openPdfInReader` (inalterado).
- `PlaylistTileActions.menuItems`: `openReader` e `openAudio` **ambos** presentes (rótulos existentes `playlistOpenInReader`, `playlistOpenInAudioPlayer`); sem parâmetro `face`.
- `PlaylistAudioFacePanel` removido junto com seu teste.

## 7. l10n (pt / en)

Novas chaves: `carouselOpen` («Abrir» / «Open»), `carouselMaterial` («Material» / «Material»), `carouselList` («Lista» / «List»), legenda de Compartilhar reusa `carouselSharePlaylist`; tooltip de Limpar reusa `carouselClear` («Limpar seleção») e a legenda curta é a nova `carouselClearShort` («Limpar» / «Clear»), `playlistEntryCount` (com plurais).
Removidas: `playlistFacePdf`, `playlistFaceAudio`, `playlistFaceToggleSemantics`, `playlistPdfCount`, `playlistAudioCount` (se não houver outro consumidor), `audioOpenPlayer` (se só a face usava).

## 8. Fora do escopo

- Redesenho da identidade visual (paleta/tipografia) — restrição de preservação.
- Mudanças no leitor além da barra 2 e do fullscreen.
- Migração de dados: `Playlist.pdfIds` / `audioIds` continuam derivados de `entries`; wire inalterado.
- Fila de reprodução: `queueForTrack` inalterado.

## 9. Testes

**Removidos:** `carousel_audio_face_bar_test`, `playlist_audio_face_panel_test`.

**Atualizados** (referenciam face ou a barra): `playlists_provider_remove_entry_test`, `playlist_session_hydrate_test`, `playlists_provider_boot_hydrate_test`, `active_playlist_editor_test`, `carousel_items_provider_test`, `audio_player_session_close_test`, `active_list_audio_queue_test`, `open_material_provider_test`, `active_list_panel_test`, `play_entry_points_active_queue_test`, `carousel_navigator_bar_test`, `shell_scaffold_test`, `test/support/fakes/fake_active_editor.dart`.

**Novos:**
- `carouselItemsProvider` devolve todas as entradas na ordem, com `index` global; `readableCarouselItemsProvider` e `audioCarouselItemsProvider` filtram; ramo de áudio do `_enrich`.
- Chip: zonas de seta sempre renderizadas; desabilitadas nos extremos; toque no corpo chama `onTap`; variante `modal` sem zonas.
- Barra: legendas presentes ≥ 600 px e ausentes abaixo; cinco botões presentes nas duas larguras; ícones D4.
- «Abrir» em entrada de áudio: empurra a rota do player e chama `playQueue` com a fila híbrida.
- `ActiveListPanel` misto: reorder devolve a ordem completa; entrada de áudio abre por «Abrir» de áudio.
- `ShellScaffold`: mini-player visível com faixa corrente mesmo com PDFs na lista (o caso que hoje a face áudio cobria).
- Mini-player: `AudioSeekBar` presente com flags; `onSeek` chama `seek`.
- Leitor: `readerCarouselPositionProvider` ignora entradas de áudio (anterior/próximo pulam áudio).
- Tela de Playlists: sem toggle; contagem mista; chips mistos; menu com as duas ações.

## 10. Riscos e mitigações

- **Perda do "modo áudio" como visão filtrada.** Quem hoje usa a face áudio para ver só os áudios da lista passa a vê-los misturados no sheet «Lista». Aceito (D1); se doer, filtro por tipo dentro do sheet é a extensão natural.
- **Foco em entrada de áudio no shell** enquanto o leitor está aberto em outra rota: não há efeito colateral (focar não toca).
- **Largura em 360 px com nome de lista longo:** `ActivePlaylistNameChip` já some abaixo de 480 px.
- **Chave `playlist_media_face` em SharedPreferences** fica órfã; sem efeito.
