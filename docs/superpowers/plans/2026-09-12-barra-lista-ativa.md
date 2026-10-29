# Barra da Lista Ativa (sem faces) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar a barra da lista ativa (duas faces PDF × Áudio, seis ícones ambíguos) por uma barra única, agrupada por escopo, com legendas, setas dentro do chip e mini-player com seek — e apagar o conceito de *face* do app inteiro, inclusive da tela de Playlists.

**Architecture:** A lista ativa vira uma sequência única de entradas (`carouselItemsProvider` = tudo, na ordem); dois filtros derivados servem o leitor (`readableCarouselItemsProvider`) e a fila de áudio (`audioCarouselItemsProvider`). A barra é `CarouselNavigatorBar` (chip com setas + grupo *louvor* + grupo *lista*) com botões responsivos `CarouselBarActionButton` (ícone + legenda ≥ 600 px). `PlaylistMediaFace` e tudo que o consome desaparecem; o mini-player passa a ser o único player compacto e ganha `AudioSeekBar`.

**Tech Stack:** Flutter 3.44 / Dart 3, Riverpod (`Notifier`/`Provider`), go_router, Isar (testes de provider), `flutter gen-l10n` (ARB → `lib/l10n/app_localizations*.dart`, versionados), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-12-barra-lista-ativa-design.md`

## Global Constraints

- Identidade visual incumbente (vinho `AppColors.title` / creme `AppColors.card` / ouro `AppColors.gold`) — refinar, não substituir.
- Ícones (spec D4): Abrir `Icons.file_open_outlined`, Material `Icons.change_circle_outlined`, Lista `Icons.queue_music`, Compartilhar `Icons.adaptive.share` (inalterado), Limpar `Icons.delete_outline`.
- Setas do chip: chevrons brancos/creme (`AppColors.card`), zonas de 36 px, **sempre presentes**, 35 % de opacidade e desabilitadas nos extremos (spec D5).
- Legendas nos botões quando a largura da barra ≥ 600 px (`carouselBarLabelsMinWidth`); só ícones abaixo (spec D3). Sem rótulo de texto sob os grupos (spec D2).
- Nenhum botão «Ouvir» (spec D6).
- l10n `pt` **e** `en` para toda string nova; regenerar com `flutter gen-l10n` e commitar os `.dart` gerados.
- Comentários e docs em português, no estilo dos arquivos vizinhos (`///` explicando o *porquê*).
- Antes de cada commit: `flutter analyze` sem erros nos arquivos tocados e os testes do task passando. Commits com prefixo `feat|refactor|test|docs(escopo):` em português.
- Comandos: `flutter test <caminho>` (um arquivo), `flutter analyze lib test`, `flutter gen-l10n`.
- Todo commit termina com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01WGjG48FUd5BwMWVsfKWmcG
  ```

---

## Mapa de arquivos

**Criar**
- `lib/features/carousel/presentation/widgets/carousel_bar_action_button.dart` — botão ícone + legenda responsivo e o container de grupo.
- `lib/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart` — zona de seta dentro do chip.
- `test/widget/features/carousel/carousel_bar_action_button_test.dart`
- `test/widget/features/carousel/carousel_louvor_chip_nav_test.dart`
- `test/widget/features/audio_player/mini_player_bar_test.dart`
- `test/widget/features/playlists/playlist_tile_detail_chips_test.dart`

**Modificar**
- `lib/features/carousel/presentation/providers/carousel_items_provider.dart` — lista unificada + filtros + ramo de áudio.
- `lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart` — deriva de `readableCarouselItemsProvider`, por chave.
- `lib/features/audio_player/presentation/providers/audio_follow_reader_provider.dart` — `resolveMaterialForGroup` usa `readableCarouselItemsProvider`.
- `lib/features/audio_player/presentation/utils/active_list_audio_queue.dart` — `audioCarouselItemsProvider`.
- `lib/features/playlists/presentation/providers/active_playlist_editor.dart` — `reorder` substitui `reorderFace`.
- `lib/features/carousel/presentation/widgets/active_list_panel.dart` — sem face.
- `lib/features/carousel/presentation/widgets/carousel_chips.dart` — sem face; `_openItem` por tipo; `showLabels`.
- `lib/features/carousel/presentation/widgets/carousel_navigator_bar.dart` — nova anatomia.
- `lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart` — Compartilhar + Limpar com legenda; sem toggle.
- `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart` — `showLabel`; troca de faixa de áudio por chave.
- `lib/features/carousel/presentation/widgets/carousel_bar_shell.dart` — `carouselBarLabelsMinWidth`.
- `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart` — setas dentro do chip; ícone por `kind`.
- `lib/features/carousel/presentation/widgets/active_playlist_name_chip.dart` — lápis.
- `lib/features/app_shell/presentation/shell_scaffold.dart` — `showMiniPlayer = currentTrack != null`.
- `lib/features/audio_player/presentation/widgets/mini_player_bar.dart` — `AudioSeekBar` + flags.
- `lib/features/audio_player/presentation/utils/open_audio_in_player.dart` — não seta face.
- `lib/features/playlists/presentation/providers/playlists_provider.dart` — não seta face.
- `lib/features/playlists/presentation/providers/playlist_session_hydrate.dart` — não seta face.
- `lib/features/playlists/presentation/pages/playlists_screen.dart` — sem toggle.
- `lib/features/playlists/presentation/widgets/playlist_list_tile.dart` — contagem mista, chips mistos.
- `lib/features/playlists/presentation/widgets/playlist_tile_detail_chips.dart` — chips mistos, `onAudioTap`.
- `lib/features/playlists/presentation/widgets/playlist_tile_actions.dart` — menu com as duas ações.
- `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados).

**Apagar**
- `lib/features/carousel/presentation/widgets/carousel_audio_face_bar.dart`
- `lib/features/playlists/domain/entities/playlist_media_face.dart`
- `lib/features/playlists/presentation/providers/playlist_media_face_provider.dart`
- `lib/features/playlists/presentation/widgets/playlist_media_face_toggle.dart`
- `lib/features/playlists/presentation/widgets/playlist_audio_face_panel.dart`
- `test/widget/features/carousel/carousel_audio_face_bar_test.dart`
- `test/widget/features/playlists/playlist_audio_face_panel_test.dart`

---

### Task 1: Lista unificada nos providers do carrossel

**Files:**
- Modify: `lib/features/carousel/presentation/providers/carousel_items_provider.dart`
- Modify: `lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart`
- Modify: `lib/features/audio_player/presentation/providers/audio_follow_reader_provider.dart:102-125`
- Modify: `lib/features/audio_player/presentation/utils/active_list_audio_queue.dart:22-32`
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart:189` (só renomear `audioFaceItemsProvider` → `audioCarouselItemsProvider`; a lógica de face cai na Task 3)
- Modify: `lib/features/carousel/presentation/widgets/carousel_chips.dart:56` (idem)
- Modify: `lib/features/carousel/presentation/widgets/carousel_audio_face_bar.dart:64` (idem — o arquivo é apagado na Task 3)
- Modify: `lib/features/carousel/presentation/widgets/active_list_panel.dart:56` (idem)
- Test: `test/unit/features/carousel/carousel_items_provider_test.dart`
- Test (renomear override): `test/unit/features/audio_player/active_list_audio_queue_test.dart:74,115`, `test/widget/features/catalog/open_material_provider_test.dart:115`, `test/widget/features/audio_player/play_entry_points_active_queue_test.dart:98`

**Interfaces:**
- Produces:
  - `final carouselItemsProvider = Provider<List<CarouselItem>>` — **todas** as entradas da lista ativa, na ordem; `index` = posição na lista inteira.
  - `final readableCarouselItemsProvider = Provider<List<CarouselItem>>` — só `!isAudio`, mesma ordem, `index` preservado da lista inteira.
  - `final audioCarouselItemsProvider = Provider<List<CarouselItem>>` — só `isAudio`, `index` preservado.
  - `focusedCarouselItemProvider` inalterado em assinatura (agora sobre a lista inteira).
  - `readerCarouselPositionProvider` inalterado em assinatura; deriva de `readableCarouselItemsProvider`.

- [ ] **Step 1: Escrever os testes novos/atualizados de `carouselItemsProvider`**

Em `test/unit/features/carousel/carousel_items_provider_test.dart`:

1. Adicionar import `import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';` e `import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';`.
2. Substituir o primeiro teste (`'carouselItemsProvider filtra a face de partituras e enriquece pelo manifest'`) por:

```dart
  test(
    'carouselItemsProvider devolve todas as entradas na ordem, com index global',
    () async {
      final c = await boot(
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
        ],
      );

      final items = c.read(carouselItemsProvider);

      expect(items.map((i) => i.materialId), [_pdfA, _audioA, _pdfB]);
      expect(items.map((i) => i.index), [0, 1, 2]);
      expect(items.map((i) => i.key), [_pdfA, _audioA, _pdfB]);
      expect(items.first.numero, '001');
      expect(items.first.nome, 'Santo');
      expect(items.last.label, '002 — Aleluia');
    },
  );

  test('readableCarouselItemsProvider filtra áudio e preserva o index', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      ],
    );

    final items = c.read(readableCarouselItemsProvider);

    expect(items.map((i) => i.materialId), [_pdfA, _pdfB]);
    expect(items.map((i) => i.index), [0, 2]);
  });

  test('entrada de áudio é enriquecida pela faixa do cache Coldigom', () async {
    final c = await boot(
      entries: [PlaylistEntry(id: _audioA, kind: MaterialKind.audio)],
    );
    c.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
      AudioTrack(
        audioId: _audioA,
        r2Key: 'ColAdultos/001.mp3',
        nome: 'Santo',
        numero: '001',
        groupId: '001',
        categoria: 'Coro',
        classificacao: 'ColAdultos',
      ),
    ]);

    final item = c.read(carouselItemsProvider).single;

    expect(item.isAudio, isTrue);
    expect(item.numero, '001');
    expect(item.nome, 'Santo');
    expect(item.categoria, 'Coro');
  });

  test('readerCarouselPositionProvider ignora entradas de áudio', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      ],
    );

    final position = c.read(readerCarouselPositionProvider(_pdfA))!;

    expect(position.currentIndex, 1);
    expect(position.total, 2);
    expect(position.nextKey, _pdfB);
    expect(position.previousKey, isNull);
  });
```

3. Renomear o teste `'audioFaceItemsProvider só áudio'` para `'audioCarouselItemsProvider só áudio e preserva o index'` e trocar o corpo por:

```dart
    final items = c.read(audioCarouselItemsProvider);

    expect(items.map((i) => i.materialId), [_audioA]);
    expect(items.single.kind, MaterialKind.audio);
    expect(items.single.index, 1);
```

4. Renomear `'activeMaterialIdsProvider junta as duas faces'` → `'activeMaterialIdsProvider junta todos os ids'` (corpo igual).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/carousel/carousel_items_provider_test.dart`
Expected: FAIL — `readableCarouselItemsProvider`, `audioCarouselItemsProvider` não definidos; o primeiro teste espera 3 itens e recebe 2.

- [ ] **Step 3: Reescrever `carousel_items_provider.dart`**

Substituir o topo do arquivo (até `_enrich`) por:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import 'carousel_focused_index_provider.dart';

/// Lista ativa inteira, enriquecida — partitura, cifra, gesto e áudio na ordem
/// em que estão na lista (spec 2026-09-12, D1: sem faces).
///
/// Derivação pura de `activeEntriesProvider` + o lookup síncrono por id
/// (manifest PLPCG e caches Coldigom) — A4: nenhum mapa O(catálogo) por
/// mutação; o carousel não tem estado próprio (D3). `index` é a posição na
/// lista inteira, então continua válido nos filtros abaixo.
final carouselItemsProvider = Provider<List<CarouselItem>>((ref) {
  final entries = ref.watch(activeEntriesProvider);
  final lookup = ref.watch(catalogMaterialLookupProvider);
  return List<CarouselItem>.unmodifiable([
    for (final entry in entries) _enrich(entry, lookup),
  ]);
});

/// Só o que se **lê** (tudo menos áudio) — é por aqui que o leitor navega:
/// as setas do leitor pulam áudio, e «seguir o áudio» procura partitura aqui.
final readableCarouselItemsProvider = Provider<List<CarouselItem>>((ref) {
  final items = ref.watch(carouselItemsProvider);
  return List<CarouselItem>.unmodifiable([
    for (final item in items)
      if (!item.isAudio) item,
  ]);
});

/// Só as entradas de áudio — alimenta a fila de reprodução da lista ativa
/// (`activeListAudioQueue`).
final audioCarouselItemsProvider = Provider<List<CarouselItem>>((ref) {
  final items = ref.watch(carouselItemsProvider);
  return List<CarouselItem>.unmodifiable([
    for (final item in items)
      if (item.isAudio) item,
  ]);
});

/// Ids presentes na lista ativa — membership O(1).
///
/// Consumido pelo badge «já está na lista» dos cards (via `select`).
final activeMaterialIdsProvider = Provider<Set<String>>((ref) {
  final entries = ref.watch(activeEntriesProvider);
  return {for (final entry in entries) entry.id};
});

/// Item focado na lista, ou `null` se ela estiver vazia.
final focusedCarouselItemProvider = Provider<CarouselItem?>((ref) {
  final items = ref.watch(carouselItemsProvider);
  if (items.isEmpty) return null;
  final index = ref.watch(carouselFocusedIndexProvider);
  if (index < 0 || index >= items.length) return null;
  return items[index];
});

/// Precedência dos metadados: áudio pelo seu `kind`; cifra/gesto antes de PDF
/// — os três dividem o espaço de ids, e um material em cache é a resposta mais
/// específica.
CarouselItem _enrich(ActiveEntry entry, CatalogMaterialLookup lookup) {
  final index = entry.index;

  if (entry.isAudio) {
    final track = lookup.audioTrack(entry.id);
    if (track != null) {
      return CarouselItem(
        materialId: entry.id,
        kind: entry.kind,
        index: index,
        key: entry.key,
        numero: track.numero,
        nome: track.nome,
        categoria: track.categoria,
        classificacao: track.classificacao,
        source: track.source,
      );
    }
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: index,
      key: entry.key,
      numero: '',
      nome: fallbackCarouselNome(entry.id),
      categoria: '',
      classificacao: '',
      source: louvorDataSourceFromPdfId(entry.id),
    );
  }

  final chord = lookup.chord(entry.id);
  if (chord != null) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: index,
      key: entry.key,
      numero: chord.numero,
      nome: chord.nome,
      categoria: chord.categoria,
      classificacao: chord.classificacao,
      source: chord.source,
    );
  }
```

E, no resto de `_enrich`, trocar todas as ocorrências de `index: faceIndex` por `index: index` (ramos de gesto, louvor e fallback). Remover a função `_faceItems`.

- [ ] **Step 4: `readerCarouselPositionProvider` por chave sobre a lista legível**

Substituir o corpo do provider em `reader_carousel_position_provider.dart`:

```dart
final readerCarouselPositionProvider =
    Provider.family<CarouselReaderPosition?, String>((ref, currentMaterialId) {
      // Só o que se lê: uma entrada de áudio nunca é «anterior/próximo» do
      // leitor (spec 2026-09-12, §4). Como `index` é global, a posição aqui
      // é resolvida por **chave**, não por `item.index`.
      final items = ref.watch(readableCarouselItemsProvider);
      if (items.isEmpty) return null;

      final focused = ref.watch(focusedCarouselItemProvider);

      int index;
      if (focused != null && focused.materialId == currentMaterialId) {
        index = items.indexWhere((item) => item.key == focused.key);
      } else {
        index = items.indexWhere(
          (item) => item.materialId == currentMaterialId,
        );
        if (index < 0 && focused != null) {
          index = items.indexWhere((item) => item.key == focused.key);
        }
      }
      if (index < 0) index = 0;
      index = index.clamp(0, items.length - 1);

      final previous = index > 0 ? items[index - 1] : null;
      final next = index < items.length - 1 ? items[index + 1] : null;

      return CarouselReaderPosition(
        currentIndex: index + 1,
        total: items.length,
        currentKey: items[index].key,
        previousKey: previous?.key,
        nextKey: next?.key,
        previousMaterialId: previous?.materialId,
        nextMaterialId: next?.materialId,
      );
    });
```

Atualizar o doc-comment do provider: «dentro da face de partituras» → «dentro das entradas legíveis da lista ativa».

- [ ] **Step 5: Renomear consumidores de `audioFaceItemsProvider` e apontar «seguir o áudio» para a lista legível**

- `active_list_audio_queue.dart`: `ref.read(audioFaceItemsProvider)` → `ref.read(audioCarouselItemsProvider)` (duas ocorrências). No doc-comment de `_queueFrom`, «sem face de áudio a fila é vazia» → «sem entradas de áudio a fila é vazia».
- `audio_follow_reader_provider.dart`, em `resolveMaterialForGroup`: `carouselItemsProvider` → `readableCarouselItemsProvider` (nas duas linhas `watch`/`read`). Em `openMaterialForGroupInReader` (linha ~186) a busca `ref.read(carouselItemsProvider)` continua (ela procura o `targetPdfId`, que nunca é áudio).
- `shell_scaffold.dart:189`, `carousel_chips.dart:56`, `carousel_audio_face_bar.dart:64`, `active_list_panel.dart:56`: `audioFaceItemsProvider` → `audioCarouselItemsProvider`.
- Nos três testes que fazem `audioFaceItemsProvider.overrideWithValue(...)`: renomear para `audioCarouselItemsProvider.overrideWithValue(...)`.

- [ ] **Step 6: Rodar os testes do task**

Run: `flutter test test/unit/features/carousel/carousel_items_provider_test.dart test/unit/features/audio_player/active_list_audio_queue_test.dart test/widget/features/catalog/open_material_provider_test.dart test/widget/features/audio_player/play_entry_points_active_queue_test.dart`
Expected: PASS. (O teste `'carouselFocusedIndexProvider foca por chave e sobrevive a reorder'` ainda usa `reorderFace` — continua passando até a Task 2.)

Run: `flutter analyze lib test`
Expected: sem erros.

- [ ] **Step 7: Commit**

```bash
git add lib/features/carousel/presentation/providers/carousel_items_provider.dart lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart lib/features/audio_player lib/features/app_shell lib/features/carousel/presentation/widgets test/unit/features/carousel test/unit/features/audio_player test/widget/features/catalog test/widget/features/audio_player
git commit -m "refactor(carousel): lista ativa unificada nos providers (readable/audio como filtros)"
```

---

### Task 2: `ActivePlaylistEditor.reorder` substitui `reorderFace`

**Files:**
- Modify: `lib/features/playlists/presentation/providers/active_playlist_editor.dart:253-300`
- Modify: `lib/features/carousel/presentation/widgets/active_list_panel.dart`
- Modify: `test/support/fakes/fake_active_editor.dart:33,73-82`
- Test: `test/unit/features/playlists/active_playlist_editor_test.dart`, `test/unit/features/playlists/playlists_provider_remove_entry_test.dart:121`, `test/unit/features/carousel/carousel_items_provider_test.dart:215`, `test/widget/features/carousel/active_list_panel_test.dart:103-121`, `test/widget/features/carousel/carousel_selection_sheet_test.dart:129`

**Interfaces:**
- Produces: `Future<void> reorder(List<String> orderedKeys)` em `ActivePlaylistEditor` — `orderedKeys` é uma **permutação** de todas as chaves de `activeEntriesOf(_entries)`; lista curta, chave desconhecida ou repetida → ignorada com `_log.warn`. Override otimista + debounce iguais aos de `reorderFace`.
- Produces: `ActiveListPanel({this.onOpen, this.onRemoved})` — sem parâmetro `face`; mostra `carouselItemsProvider` inteiro; destaque do item focado sempre ligado.
- Fake: `FakeActiveEditor.lastReorder` continua; `lastReorderFace` é removido.

- [ ] **Step 1: Atualizar os testes do editor**

Em `test/unit/features/playlists/active_playlist_editor_test.dart`:
- Todo `reorderFace(PlaylistMediaFace.pdf, [a, b, c])` vira `reorder([...])` com a **ordem completa** das chaves (se o teste tinha áudio na lista, incluir a chave do áudio na posição desejada).
- O teste `'reorderFace(pdf) reordena a face e mantém os áudios nas posições'` (linha ~329) vira:

```dart
  test('reorder aplica a permutação completa, áudio incluído', () async {
    // mesma montagem do teste original (entradas _pdfA, _audioA, _pdfB)
    await c.read(activePlaylistEditorProvider.notifier).reorder([
      _pdfB,
      _audioA,
      _pdfA,
    ]);
    await _flush();

    expect(
      c.read(activeEntriesProvider).map((e) => e.id),
      [_pdfB, _audioA, _pdfA],
    );
  });
```
  (manter os helpers/fixtures que o arquivo já usa — `c`, `_flush`, ids — só trocando a chamada e a expectativa).
- O grupo `'reorderFace só aceita permutação da face'` (linha ~616) vira `'reorder só aceita permutação completa'`: os três casos (lista curta, chave desconhecida, chave repetida) chamam `reorder(...)` e esperam a ordem **inalterada**.
- Remover o import de `playlist_media_face.dart`.

Em `playlists_provider_remove_entry_test.dart:121` e `carousel_items_provider_test.dart:215`: `reorderFace(PlaylistMediaFace.pdf, [x, y])` → `reorder([x, y])` (nesses dois testes a lista só tem PDFs, então a permutação já é completa); remover o import de `playlist_media_face.dart`.

Em `active_list_panel_test.dart:103-121` e `carousel_selection_sheet_test.dart:129`: título `'reorder dispara reorder por chaves'`; apagar a linha `expect(editor.lastReorderFace, PlaylistMediaFace.pdf);`; se o teste passa `face:` ao `ActiveListPanel`, remover; remover o import de `playlist_media_face.dart`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/playlists/active_playlist_editor_test.dart`
Expected: FAIL — `reorder` não definido.

- [ ] **Step 3: Implementar `reorder` e apagar `reorderFace`**

Em `active_playlist_editor.dart`, substituir o método `reorderFace` inteiro por:

```dart
  /// Reordena a lista ativa inteira.
  ///
  /// [orderedKeys] são as chaves de [ActiveEntry] na ordem desejada. Aplica o
  /// override otimista na hora e persiste depois de
  /// [activeReorderPersistDebounce] (a última ordem vence).
  ///
  /// [orderedKeys] tem que ser uma **permutação** das chaves da lista:
  /// reordenar é permutar, não editar. Uma lista curta, com chave desconhecida
  /// ou repetida não apaga entrada nenhuma — a reordenação é ignorada e
  /// registrada.
  Future<void> reorder(List<String> orderedKeys) async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return;
    final entries = _entries;

    final byKey = <String, PlaylistEntry>{
      for (final active in activeEntriesOf(entries)) active.key: active.entry,
    };

    final seen = <String>{};
    final reordered = <PlaylistEntry>[];
    for (final key in orderedKeys) {
      final entry = byKey[key];
      if (entry == null) continue;
      if (!seen.add(key)) continue;
      reordered.add(entry);
    }

    if (reordered.length != byKey.length) {
      _log.warn(
        'reorder ignorado: ${orderedKeys.length} chaves resolveram '
        '${reordered.length} de ${byKey.length} entradas',
      );
      return;
    }

    state = reordered;

    _pendingReorder = state;
    _pendingPlaylistId = activeId;
    _pendingUpdate = ref.read(updatePlaylistProvider);
    _reorderPersistTimer?.cancel();
    _reorderPersistTimer = Timer(activeReorderPersistDebounce, () {
      unawaited(_flushPendingReorder());
    });
  }
```

Remover o import de `playlist_media_face.dart` desse arquivo se nada mais o usar (verificar com `grep -n PlaylistMediaFace`). Se `SavedPlaylist.replaceSubset` ficar sem uso em `lib/`, **manter** (ele é usado por `copyWith(pdfIds:)`).

- [ ] **Step 4: `ActiveListPanel` sem face**

Substituir a classe em `active_list_panel.dart`:

```dart
/// Lista reordenável da lista ativa (spec A.6 C7; sem faces desde a spec
/// 2026-09-12).
///
/// Mostra [carouselItemsProvider] inteiro — partitura, cifra, gesto e áudio na
/// ordem da lista. O item focado ([carouselFocusedIndexProvider]) ganha
/// destaque visual.
///
/// Drag reordena e chama [ActivePlaylistEditor.reorder] com a nova ordem de
/// chaves; `×` remove por chave ([ActivePlaylistEditor.removeByKey]) e avisa
/// [onRemoved]; toque foca a ocorrência e, se [onOpen] for informado, dispara
/// a mesma navegação do chip da barra.
class ActiveListPanel extends ConsumerStatefulWidget {
  const ActiveListPanel({this.onOpen, this.onRemoved, super.key});

  /// Toque no item — `null` desliga a navegação (o toque só foca).
  final Future<void> Function(CarouselItem item)? onOpen;

  /// Chamado depois que a remoção já foi persistida (`removeByKey`).
  final Future<void> Function(CarouselItem item)? onRemoved;

  @override
  ConsumerState<ActiveListPanel> createState() => _ActiveListPanelState();
}

class _ActiveListPanelState extends ConsumerState<ActiveListPanel> {
  void _handleReorder(int oldIndex, int newIndex) {
    final items = ref.read(carouselItemsProvider);
    final reordered = List<CarouselItem>.from(items);
    if (oldIndex < 0 || oldIndex >= reordered.length) return;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);

    // `reorder` aplica o override otimista antes de persistir: a lista já
    // desenha a ordem nova sem esperar a escrita.
    unawaited(
      ref.read(activePlaylistEditorProvider.notifier).reorder([
        for (final item in reordered) item.key,
      ]),
    );
  }
```

No `build`: `final items = ref.watch(carouselItemsProvider); final focusedIndex = ref.watch(carouselFocusedIndexProvider);` — apagar o getter `_itemsProvider` e o import de `playlist_media_face.dart`. O resto do `build` fica igual.

- [ ] **Step 5: Fake**

Em `test/support/fakes/fake_active_editor.dart`: apagar o campo `lastReorderFace` e trocar o override por:

```dart
  @override
  Future<void> reorder(List<String> orderedKeys) async {
    lastReorder = orderedKeys;
    final byKey = {for (final active in _entries) active.key: active.entry};
    state = [for (final key in orderedKeys) ?byKey[key]];
  }
```
Atualizar o comentário da linha 6 (`reorderFace` → `reorder`) e remover o import de `playlist_media_face.dart`.

- [ ] **Step 6: Rodar**

Run: `flutter test test/unit/features/playlists test/unit/features/carousel test/widget/features/carousel/active_list_panel_test.dart test/widget/features/carousel/carousel_selection_sheet_test.dart`
Expected: PASS.

Run: `flutter analyze lib test` — sem erros.

- [ ] **Step 7: Commit**

```bash
git add lib/features/playlists/presentation/providers/active_playlist_editor.dart lib/features/carousel/presentation/widgets/active_list_panel.dart test/support/fakes/fake_active_editor.dart test/unit test/widget/features/carousel
git commit -m "refactor(playlists): reorder da lista inteira substitui reorderFace"
```

---

### Task 3: Face fora da barra, do shell e da reprodução

**Files:**
- Delete: `lib/features/carousel/presentation/widgets/carousel_audio_face_bar.dart`, `test/widget/features/carousel/carousel_audio_face_bar_test.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_chips.dart:1-75`
- Modify: `lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart` (tira o toggle)
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart:181-193`
- Modify: `lib/features/audio_player/presentation/utils/open_audio_in_player.dart:66-75`
- Modify: `lib/features/playlists/presentation/providers/playlists_provider.dart:421-428`
- Modify: `lib/features/playlists/presentation/providers/playlist_session_hydrate.dart:91-99`
- Test: `test/widget/features/app_shell/shell_scaffold_test.dart:203-224,316-323`, `test/unit/features/audio_player/audio_player_session_close_test.dart:118-190`, `test/unit/features/playlists/playlist_session_hydrate_test.dart:90,133,166-167`, `test/unit/features/playlists/playlists_provider_boot_hydrate_test.dart:70,104,126,153`

**Interfaces:**
- Produces: `CarouselChips` renderiza `_CarouselChipsBar(items: carouselItemsProvider)` sempre que a lista não está vazia; `SizedBox.shrink` quando vazia.
- Produces: `ShellScaffold.showMiniPlayer = !hideChrome && currentTrack != null`.
- `shouldShowCarouselAudioFace` deixa de existir.

- [ ] **Step 1: Atualizar os testes**

`shell_scaffold_test.dart`: substituir o teste `'com a face de áudio visível, o mini-player some (ela já mostra os controles)'` (linhas ~203-224) por:

```dart
  testWidgets(
    'com faixa corrente e PDFs na lista, o mini-player aparece (não há mais face de áudio)',
    (tester) async {
      await pumpShell(
        tester,
        overrides: [
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor([pdfEntry, audioEntry]),
          ),
          audioPlayerSessionProvider.overrideWith(
            () => _FakeAudioSession(
              const AudioPlayerSessionState(queue: [track]),
            ),
          ),
        ],
      );

      expect(find.byType(MiniPlayerBar), findsOneWidget);
    },
  );
```
Apagar a classe `_FixedFace` (linhas ~316-323) e os imports de `playlist_media_face.dart` / `playlist_media_face_provider.dart`.

`audio_player_session_close_test.dart`: apagar o grupo `'shouldShowCarouselAudioFace'` inteiro (linhas ~118-190) e o import de `carousel_chips.dart` se ficar sem uso; se o teste acima dele verificava «após close a face continua PDF», trocar a asserção por «após close, `carouselItemsProvider` ainda tem os PDFs».

`playlist_session_hydrate_test.dart` e `playlists_provider_boot_hydrate_test.dart`: apagar as entradas `'playlist_media_face': PlaylistMediaFace.audio.name` dos mapas de prefs e as asserções `expect(container.read(playlistMediaFaceProvider), PlaylistMediaFace.audio)` (e o `expect(...)` das linhas 166-167 do hydrate). Remover os imports correspondentes. O que esses testes de fato verificam (fila restaurada, `startIndex`) continua.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/app_shell/shell_scaffold_test.dart`
Expected: FAIL — o mini-player some porque a face de áudio ainda cobre.

- [ ] **Step 3: `CarouselChips` sem face**

Em `carousel_chips.dart`, substituir o `build` de `CarouselChips` e apagar `shouldShowCarouselAudioFace`:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenAudioFollowReader(ref, context);

    // Só a lista: a barra é montada em toda rota do shell e não pode
    // reconstruir a ~5 Hz com o estado da sessão de áudio (A7) — o áudio vive
    // no mini-player, fora daqui.
    final items = ref.watch(carouselItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    return _CarouselChipsBar(items: items);
  }
```
Apagar os imports de `carousel_audio_face_bar.dart`, `playlist_media_face.dart`, `playlist_media_face_provider.dart` e `audio_player_session_provider.dart` (este último só se nada mais no arquivo o usar). Atualizar o doc-comment da classe: remover os parágrafos «Face PDF / Face áudio».

- [ ] **Step 4: Trailing actions sem toggle**

Em `carousel_bar_trailing_actions.dart`: apagar o primeiro `IconButton` (o toggle de face) e as linhas `final face = ...; final isAudioFace = ...;`, e os imports de `playlist_media_face.dart`, `playlist_media_face_provider.dart`, `louvor_material_icons.dart`. Atualizar o doc-comment («toggle de face, compartilhar a lista e limpar» → «compartilhar a lista e limpar»).

- [ ] **Step 5: Shell, reprodução, playlists, hydrate**

`shell_scaffold.dart`: 
```dart
    final showMiniPlayer = !hideChrome && currentTrack != null;
```
Apagar os imports de `playlist_media_face_provider.dart`, `carousel_items_provider.dart` (se ficar sem uso) e a referência a `shouldShowCarouselAudioFace` no doc-comment (linhas ~50-53: «só aparece quando a face de áudio não cobre» → «aparece sempre que há faixa corrente»).

`open_audio_in_player.dart`: apagar o bloco `unawaited(ref.read(playlistMediaFaceProvider.notifier).setFace(PlaylistMediaFace.audio));` e os dois imports de face.

`playlists_provider.dart` `_releaseMediaSelectionViews`: apagar o `await ref.read(playlistMediaFaceProvider.notifier).setFace(PlaylistMediaFace.pdf);`; doc-comment: «Para o áudio e esquece o foco — a seleção some inteira.». Remover imports de face.

`playlist_session_hydrate.dart`: o `if (tracks.isEmpty) { ... }` vira `if (tracks.isEmpty) return true;`. Remover imports de face.

- [ ] **Step 6: Apagar a face bar**

```bash
git rm lib/features/carousel/presentation/widgets/carousel_audio_face_bar.dart test/widget/features/carousel/carousel_audio_face_bar_test.dart
```
Verificar com `grep -rn "CarouselAudioFaceBar\|shouldShowCarouselAudioFace\|audioOpenPlayer" lib test` — nenhuma ocorrência restante (a chave l10n `audioOpenPlayer` sai na Task 9).

- [ ] **Step 7: Rodar**

Run: `flutter analyze lib test` — sem erros.
Run: `flutter test test/widget/features/app_shell test/unit/features/audio_player test/unit/features/playlists test/widget/features/carousel`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A lib/features/carousel lib/features/app_shell lib/features/audio_player lib/features/playlists test
git commit -m "refactor(carousel): barra sem faces; mini-player sempre que há faixa"
```

---

### Task 4: Face fora da tela de Playlists; apagar `PlaylistMediaFace`

**Files:**
- Delete: `lib/features/playlists/domain/entities/playlist_media_face.dart`, `lib/features/playlists/presentation/providers/playlist_media_face_provider.dart`, `lib/features/playlists/presentation/widgets/playlist_media_face_toggle.dart`, `lib/features/playlists/presentation/widgets/playlist_audio_face_panel.dart`, `test/widget/features/playlists/playlist_audio_face_panel_test.dart`
- Modify: `lib/features/playlists/presentation/pages/playlists_screen.dart:243-250`
- Modify: `lib/features/playlists/presentation/widgets/playlist_list_tile.dart:80-85,127,150-160`
- Modify: `lib/features/playlists/presentation/widgets/playlist_tile_detail_chips.dart`
- Modify: `lib/features/playlists/presentation/widgets/playlist_tile_actions.dart:70-83`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/widget/features/playlists/playlist_tile_detail_chips_test.dart` (novo)

**Interfaces:**
- Produces (l10n): `playlistSheetCount(int)`, `playlistAudioOnlyCount(int)`, `playlistEmptyCount` — compostos em Dart como «3 partituras · 1 áudio», «3 partituras», «1 áudio», «Vazia» (en: «3 sheets · 1 audio», «Empty»).
- Produces: `PlaylistTileDetailChips({required item, required loading, required onPdfTap, required onAudioTap})` com `Future<void> Function(AudioTrack track) onAudioTap`.
- Produces: `PlaylistTileActions.menuItems()` — sem parâmetro; contém `openReader` **e** `openAudio`.

- [ ] **Step 1: Chaves l10n**

Em `lib/l10n/app_pt.arb`, logo após `"playlistPdfCount"` e seu `@`, adicionar três chaves simples (a composição «3 partituras · 1 áudio» é feita em Dart — um plural ICU aninhado ficaria ilegível):

```json
  "playlistSheetCount": "{count, plural, =1{1 partitura} other{{count} partituras}}",
  "@playlistSheetCount": { "placeholders": { "count": { "type": "int" } } },
  "playlistAudioOnlyCount": "{count, plural, =1{1 áudio} other{{count} áudios}}",
  "@playlistAudioOnlyCount": { "placeholders": { "count": { "type": "int" } } },
  "playlistEmptyCount": "Vazia",
```
e em `app_en.arb`:
```json
  "playlistSheetCount": "{count, plural, =1{1 sheet} other{{count} sheets}}",
  "@playlistSheetCount": { "placeholders": { "count": { "type": "int" } } },
  "playlistAudioOnlyCount": "{count, plural, =1{1 audio} other{{count} audios}}",
  "@playlistAudioOnlyCount": { "placeholders": { "count": { "type": "int" } } },
  "playlistEmptyCount": "Empty",
```
Rodar `flutter gen-l10n`.

- [ ] **Step 2: Teste dos chips mistos**

Criar `test/widget/features/playlists/playlist_tile_detail_chips_test.dart`:

```dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_tile_detail_chips.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_overrides.dart';

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _audioA = encodePdfId('ColAdultos/001.mp3');

void main() {
  testWidgets('mostra chips de partitura e de áudio na ordem da lista', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tappedPdf = <String>[];
    final tappedAudio = <String>[];

    final playlist = SavedPlaylist(
      playlistId: 'p1',
      nome: 'Culto',
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
      ],
      createdAt: DateTime(2026, 9, 12),
      salva: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(prefs: prefs),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref
                    .read(coldigomAudioTracksCacheProvider.notifier)
                    .mergeTracks([
                      AudioTrack(
                        audioId: _audioA,
                        r2Key: 'ColAdultos/001.mp3',
                        nome: 'Santo',
                        numero: '001',
                        groupId: '001',
                        categoria: 'Coro',
                        classificacao: 'ColAdultos',
                      ),
                    ]);
                return PlaylistTileDetailChips(
                  item: PlaylistViewItem(
                    playlist: playlist,
                    pdfLabels: const ['001 — Santo'],
                  ),
                  loading: false,
                  onPdfTap: (id) async => tappedPdf.add(id),
                  onAudioTap: (track) async => tappedAudio.add(track.audioId),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Santo'), findsNWidgets(2));
    expect(find.byIcon(LouvorMaterialIcons.audio), findsOneWidget);
    expect(find.byIcon(Icons.piano), findsOneWidget);

    await tester.tap(find.text('Santo').last);
    await tester.pump();
    expect(tappedAudio, [_audioA]);
    expect(tappedPdf, isEmpty);
  });
}
```
(Se o construtor de `SavedPlaylist` exigir outros campos obrigatórios, preencher com os valores neutros que os outros testes de playlist já usam — ver `test/unit/features/playlists/active_playlist_editor_test.dart`.)

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/playlists/playlist_tile_detail_chips_test.dart`
Expected: FAIL — `onAudioTap` não existe.

- [ ] **Step 4: `PlaylistTileDetailChips` misto**

Reescrever o `build` e o helper:

```dart
  final Future<void> Function(String pdfId) onPdfTap;

  /// Toque num chip de áudio — abre no reprodutor (spec 2026-09-12, D10).
  final Future<void> Function(AudioTrack track) onAudioTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lookup = ref.read(catalogMaterialLookupProvider);
    // Lista inteira, na ordem, com chave por ocorrência: o «×» remove
    // **aquela** ocorrência (B.1). `pdfLabels` é a projeção só das entradas
    // legíveis, então ela anda com um cursor próprio.
    final entries = activeEntriesOf(item.playlist.entries);
    var pdfCursor = 0;

    final chips = <Widget>[];
    for (final entry in entries) {
      final CarouselItem chipItem;
      if (entry.isAudio) {
        chipItem = _audioItemFor(entry: entry, track: lookup.audioTrack(entry.id));
      } else {
        chipItem = _carouselItemFor(
          entry: entry,
          label: pdfCursor < item.pdfLabels.length
              ? item.pdfLabels[pdfCursor]
              : entry.id,
          findLouvor: lookup.louvor,
        );
        pdfCursor++;
      }
      final track = entry.isAudio ? lookup.audioTrack(entry.id) : null;

      if (chips.isNotEmpty) chips.add(const SizedBox(height: 8));
      chips.add(
        CarouselLouvorChip(
          key: ValueKey(entry.key),
          item: chipItem,
          onTap: loading
              ? null
              : entry.isAudio
              ? (track == null ? null : () => onAudioTap(track))
              : () => onPdfTap(entry.id),
          onRemove: loading
              ? null
              : () async {
                  if (entries.length == 1) {
                    final confirmed = await showConfirmDialog(
                      context: context,
                      title: l10n.playlistDeleteLastPdfTitle,
                      message: l10n.playlistDeleteLastPdfMessage,
                    );
                    if (confirmed != true || !context.mounted) return;
                  }
                  await ref
                      .read(playlistsProvider.notifier)
                      .removeEntryAt(
                        playlistId: item.playlist.playlistId,
                        index: entry.index,
                      );
                },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: chips,
      ),
    );
  }

  static CarouselItem _audioItemFor({
    required ActiveEntry entry,
    required AudioTrack? track,
  }) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: entry.index,
      key: entry.key,
      numero: track?.numero ?? '',
      nome: track?.nome ?? entry.id,
      categoria: track?.categoria ?? '',
      classificacao: track?.classificacao ?? '',
      source: track?.source ?? louvorDataSourceFromPdfId(entry.id),
    );
  }
```
Em `_carouselItemFor`: remover o parâmetro `faceIndex` e usar `index: entry.index` nos três `CarouselItem(...)`. Adicionar o import `package:coldigui/features/audio_player/domain/entities/audio_track.dart`. Atualizar o doc-comment («um por PDF/cifra na face de partituras» → «um por entrada da lista — partitura, cifra, gesto ou áudio»).

- [ ] **Step 5: Tile, ações e tela**

`playlist_list_tile.dart`:
```dart
    final l10n = AppLocalizations.of(context)!;
    final playlist = widget.item.playlist;
    final countLabel = _countLabel(
      l10n,
      pdfs: playlist.pdfIds.length,
      audios: playlist.audioIds.length,
    );
```
e o helper (no `State`):
```dart
  /// «3 partituras · 1 áudio»; omite a parte zerada; «Vazia» sem nada.
  static String _countLabel(
    AppLocalizations l10n, {
    required int pdfs,
    required int audios,
  }) {
    final parts = <String>[
      if (pdfs > 0) l10n.playlistSheetCount(pdfs),
      if (audios > 0) l10n.playlistAudioOnlyCount(audios),
    ];
    return parts.isEmpty ? l10n.playlistEmptyCount : parts.join(' · ');
  }
```
`menuItems: _actions(context, l10n).menuItems()`; o bloco `if (face == PlaylistMediaFace.audio) PlaylistAudioFacePanel(...) else PlaylistTileDetailChips(...)` vira só:
```dart
                    PlaylistTileDetailChips(
                      item: widget.item,
                      loading: _loading,
                      onPdfTap: (pdfId) =>
                          _actions(context, l10n).openPdfInReader(pdfId),
                      onAudioTap: (track) =>
                          _actions(context, l10n).openAudioTrack(track),
                    ),
```
Remover os imports de face e de `playlist_audio_face_panel.dart`.

`playlist_tile_actions.dart`: `menuItems()` sem parâmetro; os dois itens:
```dart
      PopupMenuItem(
        value: 'openReader',
        child: Text(l10n.playlistOpenInReader),
      ),
      PopupMenuItem(
        value: 'openAudio',
        child: Text(l10n.playlistOpenInAudioPlayer),
      ),
```
Extrair de `case 'openAudio'` um método público reutilizado pelo chip:
```dart
  /// Ativa a lista e toca [track] com a fila híbrida (D4): se a faixa já
  /// está na lista ativa, a fila é a lista; senão, o grupo.
  Future<void> openAudioTrack(AudioTrack track) async {
    if (loading) return;
    onExpandedChanged(true);
    await ref
        .read(activePlaylistEditorProvider.notifier)
        .activate(playlist.playlistId);
    if (!context.mounted) return;
    final tracks = ref
        .read(catalogMaterialLookupProvider)
        .tracksFor(playlist.audioIds);
    await openAudioInPlayer(
      ref: ref,
      context: context,
      track: track,
      queue: queueForTrack(
        track: track,
        groupTracks: tracks,
        activeQueue: activeListAudioQueue(ref),
      ),
    );
  }
```
e `case 'openAudio'` vira:
```dart
      case 'openAudio':
        if (playlist.audioIds.isEmpty) {
          _showError(l10n.playlistAudioEmpty);
          return;
        }
        final tracks = ref
            .read(catalogMaterialLookupProvider)
            .tracksFor(playlist.audioIds);
        if (tracks.isEmpty) {
          _showError(l10n.playlistAudioEmpty);
          return;
        }
        await openAudioTrack(tracks.first);
```
Import `audio_track.dart`; remover import de face.

`playlists_screen.dart`: apagar o `Padding(... child: Align(... child: PlaylistMediaFaceToggle()))` (linhas ~243-250) e o import do toggle.

- [ ] **Step 6: Apagar a face**

```bash
git rm lib/features/playlists/domain/entities/playlist_media_face.dart lib/features/playlists/presentation/providers/playlist_media_face_provider.dart lib/features/playlists/presentation/widgets/playlist_media_face_toggle.dart lib/features/playlists/presentation/widgets/playlist_audio_face_panel.dart test/widget/features/playlists/playlist_audio_face_panel_test.dart
```
`grep -rn "PlaylistMediaFace\|playlist_media_face\|PlaylistAudioFacePanel" lib test` → vazio.

- [ ] **Step 7: Rodar**

Run: `flutter analyze lib test` — sem erros.
Run: `flutter test test/widget/features/playlists test/unit/features/playlists`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A lib/features/playlists lib/l10n test/widget/features/playlists test/unit/features/playlists
git commit -m "refactor(playlists): tela sem faces — contagem e chips mistos, PlaylistMediaFace removido"
```

---

### Task 5: Setas dentro do chip e ícone por tipo

**Files:**
- Create: `lib/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart`
- Test: `test/widget/features/carousel/carousel_louvor_chip_nav_test.dart` (novo)

**Interfaces:**
- Produces em `CarouselLouvorChip`: `this.showNavArrows = false, this.canGoPrevious = false, this.canGoNext = false, this.onPrevious, this.onNext` (`VoidCallback?`). Só têm efeito com `showNavArrows: true`.
- Produces: `ChipNavZone({required IconData icon, required String tooltip, required bool enabled, VoidCallback? onTap})` — 36 px de largura, chevron `AppColors.card` tamanho 26, fundo `AppColors.textLight` a 6 %, `Opacity(0.35)` quando `!enabled`.

- [ ] **Step 1: Teste**

Criar `test/widget/features/carousel/carousel_louvor_chip_nav_test.dart`:

```dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pdfItem = CarouselItem(
  materialId: 'a',
  index: 0,
  numero: '047',
  nome: 'Shekinah',
  categoria: 'Coro',
  classificacao: 'ColAdultos',
);

const _audioItem = CarouselItem(
  materialId: 'a.mp3',
  kind: MaterialKind.audio,
  index: 1,
  numero: '047',
  nome: 'Shekinah',
  categoria: 'Coro',
  classificacao: 'ColAdultos',
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('pt'),
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

void main() {
  testWidgets('setas sempre presentes; apagadas e inertes nos extremos', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(
      _wrap(
        CarouselLouvorChip(
          item: _pdfItem,
          variant: CarouselLouvorChipVariant.topBar,
          showNavArrows: true,
          canGoPrevious: false,
          canGoNext: true,
          onPrevious: () => previous++,
          onNext: () => next++,
        ),
      ),
    );

    expect(find.byType(ChipNavZone), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    final left = tester.widget<Opacity>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(left.opacity, 0.35);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(previous, 0);
    expect(next, 1);
  });

  testWidgets('sem showNavArrows não há zonas de seta', (tester) async {
    await tester.pumpWidget(_wrap(const CarouselLouvorChip(item: _pdfItem)));
    expect(find.byType(ChipNavZone), findsNothing);
  });

  testWidgets('toque no corpo chama onTap, não as setas', (tester) async {
    var tapped = 0;
    var next = 0;
    await tester.pumpWidget(
      _wrap(
        CarouselLouvorChip(
          item: _pdfItem,
          variant: CarouselLouvorChipVariant.topBar,
          showNavArrows: true,
          canGoNext: true,
          onTap: () => tapped++,
          onNext: () => next++,
        ),
      ),
    );

    await tester.tap(find.text('Shekinah'));
    await tester.pump();
    expect(tapped, 1);
    expect(next, 0);
  });

  testWidgets('entrada de áudio usa o ícone de áudio na linha de metadados', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const CarouselLouvorChip(
          item: _audioItem,
          variant: CarouselLouvorChipVariant.topBar,
        ),
      ),
    );
    expect(find.byIcon(LouvorMaterialIcons.audio), findsOneWidget);
    expect(find.byIcon(Icons.piano), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/carousel/carousel_louvor_chip_nav_test.dart`
Expected: FAIL — `chip_nav_zone.dart` não existe / parâmetros desconhecidos.

- [ ] **Step 3: `ChipNavZone`**

Criar `lib/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart`:

```dart
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Largura da zona de seta nas bordas do chip da barra (spec 2026-09-12, D5).
const chipNavZoneWidth = 36.0;

/// Zona de toque «anterior / próximo» dentro do chip — o chip **é** o
/// carrossel.
///
/// Sempre desenhada: nos extremos da lista fica a 35 % e sem `onTap`, para a
/// pessoa saber que é ali que se troca de louvor mesmo quando não dá.
class ChipNavZone extends StatelessWidget {
  const ChipNavZone({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: AppColors.textLight.withValues(alpha: 0.06),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: chipNavZoneWidth,
              child: Center(
                child: Icon(icon, color: AppColors.card, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Chip com setas e ícone por `kind`**

Em `carousel_louvor_chip.dart`:

1. Import `import 'chip_parts/chip_nav_zone.dart';` e `import 'package:coldigui/core/utils/material_id_kind.dart';`.
2. Novos campos no construtor (com docs):
```dart
    this.showNavArrows = false,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.onPrevious,
    this.onNext,
```
```dart
  /// Zonas «‹ ›» nas bordas do chip (só a barra do shell/leitor usa).
  final bool showNavArrows;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
```
3. Ícone da categoria por tipo — trocar
```dart
    final categoryIcon = LouvorMaterialIcons.forKind(
      LouvorMaterialIcons.kindForCategory(item.categoria),
    );
```
por
```dart
    // Áudio, cifra e gesto já sabem o que são; só PDF depende da categoria
    // (o manifest mistura Partitura/Cifra/Gestos em `type: pdf`).
    final categoryIcon = LouvorMaterialIcons.forKind(
      switch (item.kind) {
        MaterialKind.pdf ||
        MaterialKind.unknown => LouvorMaterialIcons.kindForCategory(
          item.categoria,
        ),
        _ => item.kind,
      },
    );
```
4. No `build`, o `Container(... padding: padding, child: Row(...))` vira: quando `showNavArrows`, o `Container` tem `padding: EdgeInsets.zero` e `clipBehavior: Clip.antiAlias`, e o `Row` ganha a zona esquerda antes do drag handle e a zona direita depois do share:
```dart
    final l10n = AppLocalizations.of(context);
    final body = Padding(
      padding: showNavArrows ? padding : EdgeInsets.zero,
      child: Row(children: [ /* conteúdo atual do Row: drag handle, Expanded(ChipBody...), trailing, share */ ]),
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(chipRadius),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: AppColors.shadowMd,
      ),
      clipBehavior: showNavArrows ? Clip.antiAlias : Clip.none,
      padding: showNavArrows ? EdgeInsets.zero : padding,
      child: showNavArrows
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChipNavZone(
                  icon: Icons.chevron_left,
                  tooltip: l10n?.readerCarouselPrevious ?? 'Louvor anterior',
                  enabled: canGoPrevious && onPrevious != null,
                  onTap: onPrevious,
                ),
                Expanded(child: body),
                ChipNavZone(
                  icon: Icons.chevron_right,
                  tooltip: l10n?.readerCarouselNext ?? 'Próximo louvor',
                  enabled: canGoNext && onNext != null,
                  onTap: onNext,
                ),
              ],
            )
          : body,
    );
```
(mover o `Row` atual para dentro de `body`, sem mudar seu conteúdo). Garantir altura mínima da zona: envolver `body` num `ConstrainedBox(constraints: const BoxConstraints(minHeight: 44))` quando `showNavArrows`.

- [ ] **Step 5: Rodar**

Run: `flutter test test/widget/features/carousel/carousel_louvor_chip_nav_test.dart test/widget/features/carousel`
Expected: PASS (os testes existentes do chip não usam `showNavArrows`, então continuam iguais).

`flutter analyze lib test` — sem erros.

- [ ] **Step 6: Commit**

```bash
git add lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart lib/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart test/widget/features/carousel/carousel_louvor_chip_nav_test.dart
git commit -m "feat(carousel): setas de louvor dentro do chip; ícone de áudio por kind"
```

---

### Task 6: Nova anatomia da barra — grupos, legendas, ícones

**Files:**
- Create: `lib/features/carousel/presentation/widgets/carousel_bar_action_button.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_bar_shell.dart` (constante)
- Modify: `lib/features/carousel/presentation/widgets/carousel_navigator_bar.dart` (reescrita)
- Modify: `lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart:46-79`
- Modify: `lib/features/carousel/presentation/widgets/carousel_chips.dart:391-470,530-550`
- Modify: `lib/features/carousel/presentation/widgets/active_playlist_name_chip.dart:76-92`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/widget/features/carousel/carousel_bar_action_button_test.dart` (novo), `test/widget/features/carousel/carousel_navigator_bar_test.dart` (reescrita)

**Interfaces:**
- Produces (l10n): `carouselOpen` («Abrir»/«Open»), `carouselMaterial` («Material»/«Material»), `carouselList` («Lista»/«List»), `carouselClearShort` («Limpar»/«Clear»). Reusa `carouselSharePlaylist` («Compartilhar»), `carouselClear` («Limpar seleção», tooltip), `readerSwitchMaterial` (tooltip).
- Produces: `const carouselBarLabelsMinWidth = 600.0;` em `carousel_bar_shell.dart`.
- Produces: `CarouselBarActionButton({required IconData icon, required String label, required VoidCallback? onPressed, String? tooltip, bool showLabel = true, Widget? iconOverride})` — `showLabel` → coluna ícone (22 px) + `label` 10 px; senão `IconButton(style: carouselBarIconButtonStyle, tooltip: tooltip ?? label)`.
- Produces: `CarouselBarActionGroup({required List<Widget> children, required Color tint})` — `Container` `borderRadius 12`, `padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2)`, `Row(mainAxisSize: min)`.
- Produces: `CarouselNavigatorBar({required item, required canGoPrevious, required canGoNext, required onOpenSelection, this.showLabels = true, this.chipVariant, this.onPrevious, this.onNext, this.onChipTap, this.onOpen, this.swapMaterial, this.loading = false, this.trailingActions = const []})` — `onOpenPlayer` **renomeado** para `onOpen`.
- Produces: `CarouselSwapMaterialButton({materialId, entryKey, audioId, this.showLabel = true})`.
- Produces: `CarouselBarTrailingActions({this.showLabels = true})`.

- [ ] **Step 1: l10n**

`app_pt.arb`, após `"carouselOpenList"`:
```json
  "carouselOpen": "Abrir",
  "carouselMaterial": "Material",
  "carouselList": "Lista",
  "carouselClearShort": "Limpar",
```
`app_en.arb`, mesmo lugar:
```json
  "carouselOpen": "Open",
  "carouselMaterial": "Material",
  "carouselList": "List",
  "carouselClearShort": "Clear",
```
`flutter gen-l10n`.

- [ ] **Step 2: Testes**

Criar `test/widget/features/carousel/carousel_bar_action_button_test.dart`:

```dart
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('com legenda: ícone + texto, sem tooltip', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        CarouselBarActionButton(
          icon: Icons.file_open_outlined,
          label: 'Abrir',
          onPressed: () => pressed++,
        ),
      ),
    );

    expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byTooltip('Abrir'), findsNothing);

    await tester.tap(find.text('Abrir'));
    expect(pressed, 1);
  });

  testWidgets('sem legenda: IconButton com tooltip', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CarouselBarActionButton(
          icon: Icons.queue_music,
          label: 'Lista',
          showLabel: false,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Lista'), findsNothing);
    expect(find.byTooltip('Lista'), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('grupo envolve os filhos num container tintado', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CarouselBarActionGroup(
          tint: Colors.red,
          children: [
            CarouselBarActionButton(
              icon: Icons.delete_outline,
              label: 'Limpar',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    expect(find.byType(CarouselBarActionGroup), findsOneWidget);
    expect(find.text('Limpar'), findsOneWidget);
  });
}
```

Reescrever `test/widget/features/carousel/carousel_navigator_bar_test.dart`:

```dart
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_navigator_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _testItem = CarouselItem(
  materialId: 'b',
  index: 1,
  numero: '002',
  nome: 'Louvor B',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
);

Widget _wrap(Widget child, {double width = 900}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('pt'),
  home: Scaffold(body: SizedBox(width: width, child: child)),
);

void main() {
  testWidgets('chip com setas, Abrir e Lista com legenda; toques chegam', (
    tester,
  ) async {
    var previousTapped = false;
    var nextTapped = false;
    var selectionTapped = false;
    var openTapped = false;

    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: true,
          canGoNext: true,
          onPrevious: () => previousTapped = true,
          onNext: () => nextTapped = true,
          onOpenSelection: () => selectionTapped = true,
          onOpen: () => openTapped = true,
        ),
      ),
    );

    expect(find.textContaining('Louvor B'), findsOneWidget);
    expect(find.byType(ChipNavZone), findsNWidgets(2));
    expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byIcon(Icons.queue_music), findsOneWidget);
    expect(find.text('Lista'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.open_in_full), findsNothing);

    await tester.tap(find.byTooltip('Louvor anterior'));
    await tester.tap(find.byTooltip('Próximo louvor'));
    await tester.tap(find.text('Lista'));
    await tester.tap(find.text('Abrir'));

    expect(previousTapped, isTrue);
    expect(nextTapped, isTrue);
    expect(selectionTapped, isTrue);
    expect(openTapped, isTrue);
  });

  testWidgets('setas continuam presentes (apagadas) nos extremos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: false,
          canGoNext: false,
          onOpenSelection: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('sem Abrir nem Material, o grupo louvor não aparece', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: false,
          canGoNext: false,
          onOpenSelection: () {},
        ),
      ),
    );

    expect(find.byType(CarouselBarActionGroup), findsOneWidget);
  });

  testWidgets('showLabels false: só ícones com tooltip', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: false,
          canGoNext: false,
          showLabels: false,
          onOpenSelection: () {},
          onOpen: () {},
        ),
        width: 360,
      ),
    );

    expect(find.text('Abrir'), findsNothing);
    expect(find.byTooltip('Abrir'), findsOneWidget);
    expect(find.byTooltip('Lista'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/carousel/carousel_bar_action_button_test.dart test/widget/features/carousel/carousel_navigator_bar_test.dart`
Expected: FAIL — arquivo/parâmetros inexistentes.

- [ ] **Step 4: `CarouselBarActionButton` e `CarouselBarActionGroup`**

Criar `lib/features/carousel/presentation/widgets/carousel_bar_action_button.dart`:

```dart
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

import 'carousel_bar_shell.dart';

/// Botão da barra da lista ativa: ícone em cima, legenda embaixo (spec
/// 2026-09-12, D3). Em barra estreita ([showLabel] `false`) vira o
/// [IconButton] de sempre, com a legenda como tooltip.
///
/// A legenda existe porque os ícones da barra são conceitos próprios do app
/// («Material», «Lista») — texto ganha de metáfora para quem chega agora.
class CarouselBarActionButton extends StatelessWidget {
  const CarouselBarActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.showLabel = true,
    this.iconOverride,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Tooltip do modo sem legenda — default [label].
  final String? tooltip;
  final bool showLabel;

  /// Substitui o ícone (ex.: spinner enquanto compartilha).
  final Widget? iconOverride;

  @override
  Widget build(BuildContext context) {
    final iconWidget = iconOverride ?? Icon(icon, size: 22);

    if (!showLabel) {
      return IconButton(
        style: carouselBarIconButtonStyle,
        tooltip: tooltip ?? label,
        icon: iconWidget,
        onPressed: onPressed,
      );
    }

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.title,
        disabledForegroundColor: AppColors.title.withValues(alpha: 0.38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(54, 50),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de botões por escopo (louvor / lista): fundo tintado leve que diz
/// «estes agem sobre a mesma coisa» sem gastar altura com rótulo (spec D2).
class CarouselBarActionGroup extends StatelessWidget {
  const CarouselBarActionGroup({
    required this.children,
    required this.tint,
    super.key,
  });

  final List<Widget> children;
  final Color tint;

  /// Tinta do grupo «louvor».
  static Color get louvorTint => AppColors.title.withValues(alpha: 0.08);

  /// Tinta do grupo «lista».
  static Color get listaTint => AppColors.gold.withValues(alpha: 0.18);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Divisor entre grupos.
class CarouselBarGroupDivider extends StatelessWidget {
  const CarouselBarGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.title.withValues(alpha: 0.38),
    );
  }
}
```

Em `carousel_bar_shell.dart`, após `carouselBarHorizontalGap`:
```dart
/// Largura da barra a partir da qual os botões mostram legenda (spec
/// 2026-09-12, D3); abaixo, só ícone com tooltip.
const carouselBarLabelsMinWidth = 600.0;
```

- [ ] **Step 5: `CarouselNavigatorBar`**

Reescrever o arquivo:

```dart
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Barra da lista ativa: chip-carrossel + grupo «louvor» + grupo «lista»
/// (spec 2026-09-12).
///
/// ```
/// [‹ chip ›]  ┃ Abrir  Material ┃ Lista  Compartilhar  Limpar
///               (louvor)          (lista)
/// ```
///
/// Embutida em `CarouselBarShell` no shell (`CarouselChips`), em toda rota.
///
/// [onChipTap] / [onOpen] — abrir o item focado (leitor ou player); ausentes
/// no leitor, onde o chip já representa o material aberto.
///
/// [swapMaterial] — `CarouselSwapMaterialButton`, omitido quando o louvor não
/// tem alternativa. Sem [onOpen] e sem [swapMaterial], o grupo «louvor» não
/// é desenhado.
///
/// [trailingActions] — `CarouselBarTrailingActions` (compartilhar + limpar),
/// desenhadas dentro do grupo «lista», depois de «Lista».
///
/// [showLabels] — legendas sob os ícones (barra ≥ `carouselBarLabelsMinWidth`).
class CarouselNavigatorBar extends StatelessWidget {
  const CarouselNavigatorBar({
    required this.item,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onOpenSelection,
    this.showLabels = true,
    this.chipVariant = CarouselLouvorChipVariant.topBar,
    this.onPrevious,
    this.onNext,
    this.onChipTap,
    this.onOpen,
    this.swapMaterial,
    this.loading = false,
    this.trailingActions = const [],
    super.key,
  });

  final CarouselItem item;
  final CarouselLouvorChipVariant chipVariant;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool showLabels;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onChipTap;
  final VoidCallback? onOpen;
  final Widget? swapMaterial;
  final VoidCallback onOpenSelection;

  /// Desabilita setas/chip/abrir; «Lista» permanece habilitado.
  final bool loading;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasLouvorGroup = onOpen != null || swapMaterial != null;

    return Row(
      children: [
        Flexible(
          child: CarouselLouvorChip(
            item: item,
            variant: chipVariant,
            showNavArrows: true,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: loading ? null : onPrevious,
            onNext: loading ? null : onNext,
            onTap: loading ? null : onChipTap,
          ),
        ),
        const SizedBox(width: 6),
        if (hasLouvorGroup) ...[
          CarouselBarActionGroup(
            tint: CarouselBarActionGroup.louvorTint,
            children: [
              if (onOpen != null)
                CarouselBarActionButton(
                  icon: Icons.file_open_outlined,
                  label: l10n?.carouselOpen ?? 'Abrir',
                  showLabel: showLabels,
                  onPressed: loading ? null : onOpen,
                ),
              ?swapMaterial,
            ],
          ),
          const CarouselBarGroupDivider(),
        ],
        CarouselBarActionGroup(
          tint: CarouselBarActionGroup.listaTint,
          children: [
            CarouselBarActionButton(
              icon: Icons.queue_music,
              label: l10n?.carouselList ?? 'Lista',
              showLabel: showLabels,
              onPressed: onOpenSelection,
            ),
            ...trailingActions,
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Trailing actions e swap com legenda**

`carousel_bar_trailing_actions.dart` — construtor `const CarouselBarTrailingActions({this.showLabels = true, super.key}); final bool showLabels;` e o `build`:
```dart
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CarouselBarActionButton(
          icon: Icons.adaptive.share,
          label: l10n.carouselSharePlaylist,
          showLabel: widget.showLabels,
          iconOverride: _sharing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.title,
                  ),
                )
              : null,
          onPressed: _sharing
              ? null
              : () => unawaited(_openShareSheet(context, ref, l10n)),
        ),
        CarouselBarActionButton(
          icon: Icons.delete_outline,
          label: l10n.carouselClearShort,
          tooltip: l10n.carouselClear,
          showLabel: widget.showLabels,
          onPressed: () => _confirmClear(context, ref),
        ),
      ],
    );
```
Import `carousel_bar_action_button.dart`; remover o import de `carousel_bar_shell.dart` se ficar sem uso. Doc-comment: «Ações da lista à direita da barra: compartilhar e limpar (lixeira — o `clear_all` parecia menu).»

`carousel_swap_material_button.dart` — adicionar `this.showLabel = true` / `final bool showLabel;` e trocar o `IconButton` por:
```dart
    return CarouselBarActionButton(
      icon: Icons.change_circle_outlined,
      label: l10n.carouselMaterial,
      tooltip: l10n.readerSwitchMaterial,
      showLabel: showLabel,
      onPressed: () => showCarouselSwapMaterialSheet(
        context: context,
        ref: ref,
        group: group,
        currentMaterialId: materialId,
        currentEntryKey: entryKey,
      ),
    );
```
Doc-comment: «Layers» → ««Material»».

- [ ] **Step 7: `CarouselChips` — largura, grupo louvor só quando há alternativa, lápis**

Em `carousel_chips.dart`:

1. `_buildNavigatorBar` ganha `required bool showLabels` e passa adiante:
```dart
          Expanded(
            child: CarouselNavigatorBar(
              item: item,
              chipVariant: CarouselLouvorChipVariant.topBar,
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              showLabels: showLabels,
              loading: loading,
              onPrevious: onPrevious,
              onNext: onNext,
              onChipTap: onChipTap,
              onOpen: onOpen,
              onOpenSelection: onOpenSelection,
              swapMaterial: hasSwap
                  ? CarouselSwapMaterialButton(
                      materialId: item.materialId,
                      entryKey: item.key,
                      showLabel: showLabels,
                    )
                  : null,
              trailingActions: [
                CarouselBarTrailingActions(showLabels: showLabels),
              ],
            ),
          ),
```
com, antes do `return`:
```dart
    final hasSwap =
        resolveCarouselSwapMaterialGroup(ref, materialId: item.materialId) !=
        null;
```
e o parâmetro `VoidCallback? onOpenPlayer` renomeado para `onOpen` (em `_buildNavigatorBar`, `_buildShellMode` — `onOpen: onReaderWithoutPdfId ? null : () => _openInReader(focusedItem)` — e `_buildReaderMode`).

2. No `build` (LayoutBuilder): `final showLabels = constraints.maxWidth >= carouselBarLabelsMinWidth;` e passar `showLabels: showLabels` nas duas chamadas (`_buildReaderMode`, `_buildShellMode`), que repassam a `_buildNavigatorBar`.

`active_playlist_name_chip.dart`: o `Text(label, ...)` dentro do `ConstrainedBox` vira
```dart
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.headline.copyWith(
                        fontSize: 13,
                        height: 1.1,
                        color: AppColors.textLight,
                        shadows: const [],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // O lápis diz que dá para nomear/renomear (spec D9).
                  const Icon(Icons.edit, size: 14, color: AppColors.textLight),
                ],
              ),
```

- [ ] **Step 8: Rodar**

Run: `flutter analyze lib test` — sem erros.
Run: `flutter test test/widget/features/carousel test/widget/features/app_shell`
Expected: PASS. Se algum teste de `carousel_chips` procurar `Icons.open_in_full`, `Icons.visibility_outlined`, `Icons.layers_outlined` ou `Icons.clear_all`, atualizar para `Icons.file_open_outlined`, `Icons.queue_music`, `Icons.change_circle_outlined`, `Icons.delete_outline` respectivamente (ou pelos textos «Abrir», «Lista», «Material», «Limpar» quando o teste roda em largura ≥ 600).

- [ ] **Step 9: Commit**

```bash
git add lib/features/carousel lib/l10n test/widget/features/carousel
git commit -m "feat(carousel): barra agrupada por escopo com legendas e ícones novos"
```

---

### Task 7: «Abrir» e «Material» em entrada de áudio

**Files:**
- Modify: `lib/features/carousel/presentation/widgets/carousel_chips.dart:262-280` (`_openInReader` → `_openItem`), e os usos em `_buildShellMode` / `onOpenSelection`
- Modify: `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart:83-135`
- Test: `test/widget/features/carousel/carousel_chips_open_audio_test.dart` (novo)

**Interfaces:**
- Produces em `_CarouselChipsBarState`: `Future<void> _openItem(CarouselItem item)` — despacha por `item.isAudio`; `Future<void> _openAudio(CarouselItem item)`.
- Produces em `showCarouselSwapMaterialSheet`: ao escolher `AudioMaterial` quando `currentEntryKey != null` e `materialIdKindOf(currentMaterialId) == MaterialKind.audio`, chama `replaceByKey(currentEntryKey, PlaylistEntry(id: track.audioId, kind: MaterialKind.audio))` antes de tocar.

- [ ] **Step 1: Teste**

Criar `test/widget/features/carousel/carousel_chips_open_audio_test.dart`. Reaproveitar a montagem de `test/widget/features/app_shell/shell_scaffold_test.dart` (`pumpShell`, `FakeActiveEditor`, `_FakeAudioSession`, `track`, `audioEntry`) — copiar os helpers necessários para este arquivo (não importar de outro teste). O teste:

```dart
  testWidgets('«Abrir» numa entrada de áudio toca a faixa e abre /audio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = _FakeAudioSession(const AudioPlayerSessionState());
    await pumpShell(
      tester,
      overrides: [
        activePlaylistEditorProvider.overrideWith(
          () => FakeActiveEditor([audioEntry]),
        ),
        audioPlayerSessionProvider.overrideWith(() => session),
      ],
    );
    // cache de faixas: mergeTracks([track]) no container do ProviderScope
    // (obter via `ProviderScope.containerOf(tester.element(find.byType(CarouselChips)))`)

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(session.playedQueue, isNotNull);
    expect(session.playedQueue!.single.audioId, track.audioId);
    expect(find.text('Áudio'), findsWidgets); // título da rota /audio no shell
  });
```
`_FakeAudioSession` deve gravar `playedQueue` no override de `playQueue(List<AudioTrack> tracks, {int startIndex = 0})` — ver como `shell_scaffold_test.dart` define o fake e acrescentar o campo.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/carousel/carousel_chips_open_audio_test.dart`
Expected: FAIL — «Abrir» em áudio tenta abrir no leitor (snackbar de erro), `playedQueue` nulo.

- [ ] **Step 3: `_openItem` em `carousel_chips.dart`**

Renomear `_openInReader` para `_openItem` (todos os call sites: `onChipTap`, `onOpen`, `onOpenSelection.onItemTap`) e trocar o corpo por:

```dart
  /// «Abrir» o item focado: leitor para o que se lê, player para áudio
  /// (spec 2026-09-12, §3.2).
  Future<void> _openItem(CarouselItem item) async {
    if (item.isAudio) return _openAudio(item);
    return _openInReader(item);
  }

  Future<void> _openAudio(CarouselItem item) async {
    if (_openingReader) return;
    final lookup = ref.read(catalogMaterialLookupProvider);
    final track = lookup.audioTrack(item.materialId);
    if (track == null) {
      final l10n = AppLocalizations.of(context);
      showAppSnackbar(
        context,
        l10n?.audioPlaybackError ?? 'Não foi possível tocar o áudio',
      );
      return;
    }
    setState(() => _openingReader = true);
    try {
      ref.read(carouselFocusedIndexProvider.notifier).focusKey(item.key);
      await openAudioInPlayer(
        ref: ref,
        context: context,
        track: track,
        queue: queueForTrack(
          track: track,
          groupTracks: tracksForGroup(
            track.groupId,
            lookup.audioTracksById.values.toList(growable: false),
          ),
          activeQueue: activeListAudioQueue(ref),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingReader = false);
    }
  }
```
(`_openInReader` mantém o corpo atual.) Imports novos: `catalog_material_lookup_provider.dart`, `open_audio_in_player.dart`, `active_list_audio_queue.dart`, `find_material_for_group.dart` (para `tracksForGroup`).

- [ ] **Step 4: Troca de faixa por chave no sheet de materiais**

Em `showCarouselSwapMaterialSheet`, o `case AudioMaterial(:final track):` vira:

```dart
        case AudioMaterial(:final track):
          // A entrada focada já é um áudio: escolher outra voz **troca** a
          // entrada (spec 2026-09-12, §3.2) — o `|◀ ▶|` de dentro do grupo
          // saiu da barra e este é o lugar dele agora.
          if (currentEntryKey != null &&
              currentMaterialId != null &&
              materialIdKindOf(currentMaterialId) == MaterialKind.audio &&
              track.audioId != currentMaterialId) {
            await ref
                .read(activePlaylistEditorProvider.notifier)
                .replaceByKey(
                  currentEntryKey,
                  PlaylistEntry(id: track.audioId, kind: MaterialKind.audio),
                );
          }
          await playAudioInSession(
            ref: ref,
            track: track,
            queue: queueForTrack(
              track: track,
              groupTracks: resolved.audioTracks,
              activeQueue: activeListAudioQueue(ref),
            ),
          );
```
Import `package:coldigui/core/utils/material_id_kind.dart` se ainda não houver.

- [ ] **Step 5: Rodar**

Run: `flutter test test/widget/features/carousel test/widget/features/app_shell`
Expected: PASS. `flutter analyze lib test` — sem erros.

- [ ] **Step 6: Commit**

```bash
git add lib/features/carousel test/widget/features/carousel
git commit -m "feat(carousel): Abrir toca entrada de áudio; Material troca a voz por chave"
```

---

### Task 8: Mini-player com seek arrastável e marcadores

**Files:**
- Modify: `lib/features/audio_player/presentation/widgets/mini_player_bar.dart`
- Test: `test/widget/features/audio_player/mini_player_bar_test.dart` (novo)

**Interfaces:**
- `MiniPlayerBar({this.overlay = false})` inalterado. Internamente desenha `AudioSeekBar(compact: true, onLightBackground: !overlay, flags: <do track>, onSeek: seek, onFlagTap: seek(flag.position))` entre o título e o transporte; a `LinearProgressIndicator` de 2 px sai.

- [ ] **Step 1: Teste**

Criar `test/widget/features/audio_player/mini_player_bar_test.dart`, com um `_FakeAudioSession` (copiar o padrão de `shell_scaffold_test.dart`, com um campo `Duration? seeked` gravado no override de `seek`) e um override de `audioPlayerPositionProvider` com `position: 30s, duration: 4min`:

```dart
  testWidgets('mini-player tem seek arrastável e chama seek', (tester) async {
    final session = _FakeAudioSession(
      const AudioPlayerSessionState(queue: [track]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(prefs: prefs),
          audioPlayerSessionProvider.overrideWith(() => session),
          audioPlayerPositionProvider.overrideWith(
            () => _FixedPosition(
              const AudioPlayerPositionState(
                position: Duration(seconds: 30),
                duration: Duration(minutes: 4),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: MiniPlayerBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AudioSeekBar), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('0:30'), findsOneWidget);

    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(session.seeked, isNotNull);
  });
```
(Ajustar os nomes `AudioPlayerPositionState` / campos conforme `audio_player_position_provider.dart` — ler o arquivo; o notifier fake `_FixedPosition` devolve o estado fixo em `build`.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/audio_player/mini_player_bar_test.dart`
Expected: FAIL — `AudioSeekBar` ausente, `LinearProgressIndicator` presente.

- [ ] **Step 3: Implementar**

Em `mini_player_bar.dart`:
- Imports: `audio_seek_bar.dart`, `../../../audio_flags/domain/entities/saved_audio_flag.dart`, `../../../audio_flags/presentation/providers/audio_flags_for_track_provider.dart`, `../../../audio_flags/presentation/providers/audio_flag_sync_provider.dart`.
- No `build`, depois de `track`: 
```dart
    ref.watch(audioFlagSyncProvider);
    final positionState = ref.watch(audioPlayerPositionProvider);
    final flags =
        ref.watch(audioFlagsForTrackProvider(track.audioId)).asData?.value ??
        const <SavedAudioFlag>[];
```
  e apagar `final progress = ...`.
- Trocar o `Column` (`LinearProgressIndicator` + `Expanded(Row)`) por um único `Padding(horizontal: 8, child: Row(...))` cujos filhos são: `Flexible(flex: 2, child: Text(title, ...))`, `const SizedBox(width: 8)`, `Expanded(flex: 3, child: AudioSeekBar(position: positionState.position, duration: positionState.duration, onLightBackground: !overlay, compact: true, flags: flags, onFlagTap: (flag) => ref.read(audioPlayerSessionProvider.notifier).seek(flag.position), onSeek: (value) => ref.read(audioPlayerSessionProvider.notifier).seek(value)))`, o ícone de erro (se houver) e os três `IconButton` de transporte como estão.
- Doc-comment da classe: «título, transporte e progresso finos» → «título, seek arrastável com marcadores e transporte».

- [ ] **Step 4: Rodar**

Run: `flutter test test/widget/features/audio_player test/widget/features/app_shell`
Expected: PASS. `flutter analyze lib test` — sem erros.

- [ ] **Step 5: Commit**

```bash
git add lib/features/audio_player/presentation/widgets/mini_player_bar.dart test/widget/features/audio_player/mini_player_bar_test.dart
git commit -m "feat(audio_player): mini-player com seek arrastável e marcadores"
```

---

### Task 9: Limpeza — chaves l10n mortas, suíte completa, docs

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados)
- Modify: `docs/features/FEATURE_INDEX.md` (se listar a face de áudio / `CarouselAudioFaceBar`)
- Modify: `test/widget/features/carousel/carousel_chips_test.dart` ou equivalentes que ainda falhem na suíte completa

- [ ] **Step 1: Chaves sem consumidor**

Para cada chave abaixo, `grep -rn "\.<chave>\b" lib --include='*.dart' | grep -v "^lib/l10n/"`; se vazio, apagar a chave (e o `@chave`) dos dois ARB:
`playlistFacePdf`, `playlistFaceAudio`, `playlistFaceToggleSemantics`, `playlistAudioCount`, `audioOpenPlayer`, `audioFacePreviousLouvor`, `audioFaceNextLouvor`.
(`playlistPdfCount` fica — `social_user_card.dart` usa. `carouselOpenList` fica se `carousel_chips`/sheet ainda usar; senão apagar.)
`flutter gen-l10n`.

- [ ] **Step 2: Suíte completa**

Run: `flutter analyze lib test`
Expected: sem erros nem warnings novos.

Run: `flutter test`
Expected: PASS. Qualquer teste que falhe por procurar ícone/tooltip antigo (`open_in_full`, `visibility_outlined`, `layers_outlined`, `clear_all`, `Ver seleção`, `Abrir player`) é atualizado para o novo (`file_open_outlined`/«Abrir», `queue_music`/«Lista», `change_circle_outlined`/«Material», `delete_outline`/«Limpar»).

- [ ] **Step 3: Docs**

Em `docs/features/FEATURE_INDEX.md`, se houver entradas para face de áudio / `CarouselAudioFaceBar` / `PlaylistMediaFaceToggle`, trocar por uma linha «Barra da lista ativa (sem faces) — spec `docs/superpowers/specs/2026-09-12-barra-lista-ativa-design.md`».

- [ ] **Step 4: Commit**

```bash
git add lib/l10n docs test
git commit -m "chore(carousel): remove chaves l10n da face; docs da barra sem faces"
```

---

## Self-review (feito ao escrever)

- **Cobertura da spec:** D1 (T1–T4), D2/D3/D4 (T6), D5 (T5), D6 (nenhum «Ouvir» em lugar nenhum), D7 (T3 + T8), D8 (T3 remove a face bar; T7 leva a voz para «Material»), D9 (T6 step 7), D10 (T4); §4 providers (T1, T2, T3); §5 (T8); §6 (T4); §7 l10n (T4, T6, T9); §9 testes (cada task).
- **Consistência de nomes:** `readableCarouselItemsProvider` / `audioCarouselItemsProvider` (T1) usados em T3/T4/T7; `reorder` (T2) usado em T2 fake/panel; `onOpen` (T6) usado em T6/T7; `showLabels`/`showLabel` (T6) em navigator/trailing/swap; `openAudioTrack` (T4) usado no tile; `ChipNavZone` (T5) usado nos testes de T6.
- **Sem placeholders:** todo passo de código tem o código; onde o passo é «renomear», a lista de arquivos e linhas está dada.
