# Fim da fonte PLPCG — plano 2: compartilhar por praise, fim dos gates, cor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o link de lista passa a ser por praise (`https://v2.plpcg.com/?p=1a2-0c3-fff&n=…`), serve a qualquer lista (PDF, áudio, cifra, gesto, YouTube) e o folheto sai com QR; os links antigos avisam em vez de abrir; somem o gate «só PLPCG» do share, o gate «só Coldigom» do ao vivo e a cor por fonte do chip.

**Architecture:** a geração troca o `pdfId → shortId` do manifesto pelo mapa material → praise do `ColdigomSearchIndex` (C4 do plano 1) e lê o `shortId` do praise em `LouvorGroup.coldigomMeta` (C3). O import troca o `ShortIdResolver` por um `PraiseEntryResolverLoader`: espera o índice (com prazo) e os favoritos, e escolhe o material de cada praise com o `preferredMaterialForGroup` do «+» do card. O parser reconhece os cinco params antigos e devolve `PlaylistShareParams.legacy()`, que vira a mensagem nova. Os gates e a cor por `LouvorDataSource` são apagados (não substituídos). `LouvorDataSource` continua a existir até ao plano 3.

**Tech Stack:** Flutter 3 + Riverpod 3 (`Provider`/`Notifier`/`AsyncNotifier`), `isar_plus` (só nos testes de use case), `share_plus`, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md` — §3.2, §4, §5, §8, §9, §10 (este plano); contrato C8 do brief comum. Quem executa lê os dois.

## Global Constraints

- `flutter analyze` limpo + `flutter test` verde; a CI roda **sem** dart-defines — nenhum teste pode depender de `COLDIGOM_API_BASE_URL`/`PLPCG_API_BASE_URL`.
- l10n: editar `lib/l10n/app_pt.arb` + `app_en.arb`, rodar `flutter gen-l10n`; gerados (`lib/l10n/app_localizations*.dart`) commitados.
- Isar: este plano não muda schema.
- Commits em português, um por tarefa, com o trailer exato:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- Nada de push, merge ou deploy sem pedido do dono.
- Não renomear código `Plpcg*`, a env `PLPCG_API_BASE_URL` nem o Worker `plpcg-catalog`; a marca «PLPCG» fica (spec §0). Código **morto** por este trabalho é apagado.
- Execução: subagentes em worktree, tarefa a tarefa. git como comando plano (sem `cd … &&`, sem `git -C`). UI de teste com `ensureVisible`/`tester.view.physicalSize`, nunca encolhendo densidade.
- Contrato do link (spec §4.1, C8): param `p` = `UrlSyncParams.praiseItems`; nome em `n` = `UrlSyncParams.shortName` (reusado); token `[0-9a-f]{3,8}`, **sempre string**; maiúsculas normalizam; origem `ShareConfig.appOrigin = 'https://v2.plpcg.com'`.
- `LouvorDataSource`, `Louvor.source`, `AudioTrack.source` etc. **não** saem aqui (plano 3). Saem só `CarouselItem.source` e `AppColors.chipColdigom`.
- Mensagem nova (spec §4.4): pt «Este link é de uma versão antiga e já não abre. Peça um link novo à pessoa.»

### Consome do plano 1 (já no código quando este plano começa)

- **C3:** `ColdigomPraiseMetadata({…, String? shortId})` com o getter `String? shortId` (default `null`); o adapter/hidratação preenchem-no a partir do dump.
- **C4:** `ColdigomSearchIndex.groupByShortId(String shortId) → LouvorGroup?` e `ColdigomSearchIndex.groupForMaterialId(String entryId) → LouvorGroup?`, ambos montados no `ColdigomSearchIndex.build(...)`. As fixtures deste plano montam o índice com `ColdigomSearchIndex.build([ColdigomIndexedPraise.build(...)])` e põem o `shortId` em `coldigomMeta`; a Tarefa 2 tem um teste-sentinela que falha na hora se o plano 1 tiver montado os mapas de outra forma.
- **C6:** o `coldigomSearchIndexProvider` reflete o índice nos dois caminhos (Isar e em memória) e `coldigomCatalogSyncProvider.notifier.sync()` funciona sem Isar.

## Review Focus

1. **Share com o índice ainda vazio** (arranque a frio, antes da hidratação, ou web sem catálogo): o share tem de falhar com o snackbar de erro e pedir sync — nunca sair um link com louvores a menos. Teste: Tarefa 2, `generate_playlist_share_url_provider_test` «índice ainda vazio».
2. **Dois materiais do mesmo louvor na lista** (partitura + áudio): o link leva o mesmo token duas vezes e o import cria duas entradas com o material preferido. Teste: Tarefa 2 («dois materiais do mesmo praise») e Tarefa 4 («uma entrada por token, com repetição»).
3. **Nome de lista com `&`, `#`, acento ou emoji**: tem de atravessar a URL sem cortar o `p` nem o nome. Teste: Tarefa 1 («nome com &, #, acento e emoji faz round-trip»).
4. **Link antigo colado em «Importar lista»** (o caminho do PWA no iOS, onde o link nunca abre o app): mensagem de link antigo, nada importado — não «Link inválido». Teste: Tarefa 4, `playlists_screen_test` «link antigo colado avisa e não importa».
5. **Link antigo pelo esquema `plpcg:///?s=…` ou Universal Link `plpcg.com/?sharepdfs=…`** no app nativo: mensagem de link antigo e URL limpa, sem ficar preso na rota com a query velha. Teste: Tarefa 4, `deep_link_listener_test` «link antigo … avisa e limpa a URL» (inclui `plpcg:///`).

### Desvios do spec (decididos ao planear; justificativa na tarefa)

1. **§8 «mensagem de link inválido de hoje»** — a chave `playlistImportInvalidUrl` fica, mas o valor muda para «Link inválido.» / «Invalid link.»: o texto de hoje manda usar `sharepdfs` e `sharename`, que agora são link antigo. Tarefa 4.
2. **§4.5 «Folheto: sai sempre com QR»** — sai com QR sempre que há link. Quando não pode haver link, o «Gerar folheto» continua a sair **sem** QR, como hoje: lista fora do repositório (`PlaylistNotFoundException`, ex.: web sem Isar) ou sem entradas. Um praise sem `shortId` **falha** o share (§4.2), em qualquer opção. Tarefa 2.
3. **§5, a mais** — saem também `liveLeadingProvider`/`LiveLeadingNotifier` (`live_projection_provider.dart`) e o `listenSelf` que o alimentava no `LiveSessionController`: só existiam para o editor ler «estou a transmitir» no gate. Tarefa 5.
4. **§4.5, a mais** — além do cliente `/l/`, saem a porta `ShareLinkShortener` e `ApiEndpoints.links` (sem outro chamador). Tarefa 2.
5. **§4.1/§4.4, precisão** — `n` sozinho (sem `p`) **não** é link de lista (`null`). `p` sem `n`, ou sem nenhum token válido, é link de lista **inválido** (aviso, como a D.6 de 13/09). Sem `p`, basta um dos cinco params antigos para ser link antigo. Tarefa 4.
6. **§3.2** — `carousel_chips.dart:211-218` não precisa de edição: o item sintético já não passava `source`, e o campo some. Tarefa 6.
7. **§3.2** — o fallback de artista vira a função `audioMediaArtist(AudioTrack)`, partilhada pela sessão nativa e pela web (a web já dizia `'PLPCG'`), para poder ter teste. Tarefa 6.

### Decisões pedidas pelo brief

- **Como o import espera o índice vazio:** `awaitColdigomSearchIndex(ref, {timeout = sharedPlaylistCatalogTimeout /* 20 s */})` (Tarefa 3).
  - Se o `coldigomSearchIndexProvider` já tem conteúdo, devolve-o na hora, sem rede.
  - Se está vazio, escuta o `coldigomSearchIndexProvider` (`ref.listen`, que também acorda a hidratação) e pede `coldigomCatalogSyncProvider.notifier.sync()`. O sync é deduplicado e cobre o aparelho que nunca sincronizou e o caminho sem Isar (C6).
  - O primeiro índice não vazio completa o `Future`. Com o prazo esgotado devolve `ColdigomSearchIndex.empty`: nenhum token resolve, o use case lança `InvalidSharePlaylistException` e aparece `playlistImportInvalidUrl` (§8).
  - Porquê 20 s: o arranque a frio baixa o dump (~950 KB comprimidos) e hidrata aos bocados, numa rede móvel. O `DeepLinkListener` já serializa os imports (`_handling`), portanto a espera não duplica.
  - O `ref` é o de um `Provider` sem `watch` (`praiseEntryResolverLoaderProvider`): não é reconstruído durante a espera, e o `ref.listen` fora do `build` é permitido no Riverpod 3.3 (só exige `ref.mounted`).
- **De onde vem o `rank` de favoritos no import:** `awaitFavoriteMaterialKindRank(ref, {timeout = favoriteRankImportTimeout /* 5 s */})` = `(await materialKindPrefsProvider.future.timeout(...)).rank` (Tarefa 3).
  - Deslogado dá `MaterialKindPrefs.empty` → `{}`. Erro ou prazo esgotado também dão `{}`, e o import segue com o fallback fixo (PDF principal → único áudio → primeiro adicionável).
  - **Não** usa o `favoriteMaterialKindRankProvider`: ele é `{}` enquanto a sessão restaura, e num deep link de arranque a frio gravaria sempre o PDF principal, mesmo para quem tem favoritos.

## Mapa de ficheiros

| Tarefa | Cria | Modifica | Apaga |
|---|---|---|---|
| 1 Formato `?p=` | `lib/core/constants/share_config.dart`, `test/unit/core/praise_share_url_test.dart` | `lib/core/utils/url_sync_params.dart`, `lib/core/utils/playlist_share_url_builder.dart`, `lib/core/constants/deep_link_config.dart` | — |
| 2 Gerar por praise + fim do gate de share | `…/playlists/domain/exceptions/praise_short_id_unavailable_exception.dart`, `test/support/fixtures/praise_share_fixtures.dart`, `test/unit/features/playlists/generate_playlist_share_url_provider_test.dart` | `generate_playlist_share_url.dart`, `playlist_providers.dart`, `playlist_share_actions_provider.dart`, `api_endpoints.dart`, `leaflet_content.dart`, `leaflet_document.dart`, arb + gerados, `generate_playlist_share_url_test.dart`, `playlist_share_actions_test.dart` | `playlist_share_link.dart`, `share_link_shortener.dart`, `share_link_shortener_remote.dart`, `coldigom_share_dialog.dart`, `share_link_shortener_remote_test.dart` |
| 3 Resolvedor do import (aditivo) | `…/playlists/domain/ports/praise_entry_resolver.dart`, `…/coldigom/presentation/providers/await_coldigom_search_index.dart`, `…/playlists/presentation/utils/preferred_entry_for_praise.dart`, `…/playlists/presentation/providers/praise_entry_resolver_provider.dart`, 4 testes | `material_kind_prefs_provider.dart` | — |
| 4 Importar por praise + links antigos | `…/playlists/domain/exceptions/legacy_share_link_exception.dart` | `playlist_share_url_builder.dart` (reescrito), `url_sync_params.dart`, `import_shared_playlist_from_url.dart`, `playlist_providers.dart`, `sync_deep_link_state.dart`, `deep_link_listener.dart`, `deep_link_initial_uri.dart`, `playlists_screen.dart`, `playlists_provider.dart`, arb + gerados, 8 ficheiros de teste | `short_id_resolver.dart`, `pdf_ids_by_short_id_provider.dart` (+ teste), `test/unit/core/playlist_share_url_builder_test.dart` |
| 5 Ao vivo sem gate | — | `active_playlist_editor.dart`, `live_projection_provider.dart`, `live_session_controller.dart`, `playlist_tile_actions.dart`, `live_session_banner.dart`, `louvor_group_card.dart`, `material_sheet_actions.dart`, arb + gerados, `live_session_banner_test.dart`, `active_playlist_editor_test.dart` | `live_coldigom_only.dart`, `live_coldigom_only_dialog.dart`, `live_coldigom_only_test.dart` |
| 6 Cor única + artista | `…/audio_player/domain/utils/audio_media_artist.dart`, `test/unit/features/audio_player/audio_media_artist_test.dart` | `carousel_item.dart`, `carousel_louvor_chip.dart`, `carousel_items_provider.dart`, `home_empty_state.dart`, `louvor_group_card.dart`, `playlist_tile_detail_chips.dart`, `color_extensions.dart`, `audio_player_session_provider.dart`, `audio_media_session_web.dart`, `carousel_louvor_chip_test.dart` | — |

Todos os paths são relativos à raiz do repo. `…/` = `lib/features/`. Comandos de teste: `flutter test <path>`; ao fim de cada tarefa, `flutter analyze` também.

---

## Unidade A — Compartilhar

### Task 1: Formato `?p=&n=` no builder (aditivo)

Só acrescenta. O formato antigo continua no ficheiro até à Tarefa 4, para que cada tarefa feche verde.

**Files:**
- Create: `lib/core/constants/share_config.dart`
- Modify: `lib/core/utils/url_sync_params.dart:44-50`
- Modify: `lib/core/utils/playlist_share_url_builder.dart` (acrescentar a seguir a `buildShortPlaylistShareUrl`, linha 113)
- Modify: `lib/core/constants/deep_link_config.dart:7`
- Test: `test/unit/core/praise_share_url_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class ShareConfig { static const String appOrigin = 'https://v2.plpcg.com'; }`
  - `UrlSyncParams.praiseItems = 'p'`
  - `bool isPraiseShortId(Object? value)`
  - `List<String> decodePraiseShareIds(String raw)`
  - `String buildPraiseShareLocation({required List<String> praiseShortIds, required String shareName})`, que lança `ArgumentError` com a lista vazia, com um token inválido ou com o nome em branco
  - `String buildPraiseShareUrl({required String origin, required List<String> praiseShortIds, required String shareName})`

- [ ] **Step 1: Teste do formato**

```dart
// test/unit/core/praise_share_url_test.dart
import 'package:coldigui/core/constants/share_config.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('origem do link é o PWA v2', () {
    expect(ShareConfig.appOrigin, 'https://v2.plpcg.com');
  });

  group('isPraiseShortId', () {
    test('aceita 3 a 8 hex minúsculos', () {
      for (final id in ['000', 'fff', '1a2', '1000', 'abcdef12']) {
        expect(isPraiseShortId(id), isTrue, reason: id);
      }
    });

    test('recusa curto, longo, maiúsculo, não-hex e não-string', () {
      for (final id in <Object?>[
        '00',
        '123456789',
        '0A1',
        'g00',
        '',
        ' 0a1',
        12,
        null,
      ]) {
        expect(isPraiseShortId(id), isFalse, reason: '$id');
      }
    });
  });

  group('decodePraiseShareIds', () {
    test(
      'normaliza maiúsculas, ignora inválidos e segmentos vazios, '
      'preserva ordem e repetição',
      () {
        expect(decodePraiseShareIds('0A1--fff- 1000 -zz-12-0a1-'), [
          '0a1',
          'fff',
          '1000',
          '0a1',
        ]);
      },
    );

    test('string vazia vira lista vazia', () {
      expect(decodePraiseShareIds(''), isEmpty);
    });
  });

  group('buildPraiseShareUrl', () {
    test('vetor do contrato (spec §4.1)', () {
      expect(
        buildPraiseShareUrl(
          origin: ShareConfig.appOrigin,
          praiseShortIds: const ['1a2', '0c3', 'fff'],
          shareName: 'Culto de domingo',
        ),
        'https://v2.plpcg.com/?p=1a2-0c3-fff&n=Culto%20de%20domingo',
      );
    });

    test('tira a barra final da origem', () {
      expect(
        buildPraiseShareUrl(
          origin: 'https://v2.plpcg.com/',
          praiseShortIds: const ['0a1'],
          shareName: 'X',
        ),
        'https://v2.plpcg.com/?p=0a1&n=X',
      );
    });

    test('repetição fica: a lista pode repetir um louvor', () {
      expect(
        buildPraiseShareLocation(
          praiseShortIds: const ['0a1', '0a1'],
          shareName: 'X',
        ),
        '/?p=0a1-0a1&n=X',
      );
    });

    test('nome com &, #, acento e emoji faz round-trip pela URL', () {
      const nome = 'Culto & Ceia #1 — louvor 🎵';
      final uri = Uri.parse(
        buildPraiseShareUrl(
          origin: ShareConfig.appOrigin,
          praiseShortIds: const ['0a1', 'fff'],
          shareName: nome,
        ),
      );
      expect(uri.queryParameters['n'], nome);
      expect(uri.queryParameters['p'], '0a1-fff');
    });

    test('lança com lista vazia, token inválido ou nome em branco', () {
      expect(
        () => buildPraiseShareLocation(praiseShortIds: const [], shareName: 'X'),
        throwsArgumentError,
      );
      expect(
        () => buildPraiseShareLocation(
          praiseShortIds: const ['0A1'],
          shareName: 'X',
        ),
        throwsArgumentError,
      );
      expect(
        () => buildPraiseShareLocation(
          praiseShortIds: const ['0a1'],
          shareName: '  ',
        ),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/core/praise_share_url_test.dart`
Expected: FAIL — `share_config.dart` não existe; `isPraiseShortId` não definido.

- [ ] **Step 3: `ShareConfig`**

```dart
// lib/core/constants/share_config.dart
/// Link de compartilhamento de lista (spec fim-fonte-plpcg §4.1).
abstract final class ShareConfig {
  /// Origem dos links `?p=…&n=…` e do QR do folheto — o PWA v2.
  ///
  /// Constante, não derivada de `AppConfig.apiBaseUrl` (Worker
  /// `plpcg-catalog`): o link abre o app, não a API.
  static const String appOrigin = 'https://v2.plpcg.com';
}
```

- [ ] **Step 4: `UrlSyncParams.praiseItems`**

Em `lib/core/utils/url_sync_params.dart`, trocar o bloco de `shortItems`/`shortName` (linhas 44–50) por:

```dart
  /// Legado — link curto por material (`?s=`, spec short-id-share). Só é
  /// reconhecido para avisar que o link é antigo (spec fim-fonte-plpcg §4.4).
  static const String shortItems = 's';

  /// Nome da lista no link por praise (`?p=…&n=…`) — obrigatório.
  static const String shortName = 'n';

  /// Link por praise (spec fim-fonte-plpcg §4.1): `shortId`s de **praise**
  /// hex separados por `-`, na ordem da lista (repetidos permitidos).
  static const String praiseItems = 'p';
```

- [ ] **Step 5: Funções do formato novo**

Em `lib/core/utils/playlist_share_url_builder.dart`, acrescentar o import `import '../../features/coldigom/domain/utils/praise_short_id.dart';` (criado no plano 1, Task 1) e, logo depois de `buildShortPlaylistShareUrl` (fim na linha 113), acrescentar:

```dart
/// `shortId` de praise válido (spec fim-fonte-plpcg §4.1): **string** hex
/// minúscula de 3 a 8 caracteres. Nunca é número — `"000"` é um id.
///
/// Delega em `normalizePraiseShortId` (plano 1, `praise_short_id.dart`) — uma
/// fonte só para o padrão `[0-9a-f]{3,8}`.
bool isPraiseShortId(Object? value) =>
    value is String && normalizePraiseShortId(value) == value;

/// Lê o param `p`: `trim`, maiúsculas viram minúsculas, token fora do padrão
/// é ignorado; ordem e repetições ficam (a lista pode repetir um louvor).
List<String> decodePraiseShareIds(String raw) => [
  for (final part in raw.split('-'))
    if (normalizePraiseShortId(part) case final id?) id,
];

/// Monta `/?p=…&n=…` (spec fim-fonte-plpcg §4.1).
///
/// Lança [ArgumentError] com [praiseShortIds] vazio, com um token que não é
/// [isPraiseShortId] (quem gera valida antes — aqui seria bug) ou com
/// [shareName] em branco.
String buildPraiseShareLocation({
  required List<String> praiseShortIds,
  required String shareName,
}) {
  if (praiseShortIds.isEmpty) {
    throw ArgumentError.value(
      praiseShortIds,
      'praiseShortIds',
      'must not be empty',
    );
  }
  final invalid = [
    for (final id in praiseShortIds)
      if (!isPraiseShortId(id)) id,
  ];
  if (invalid.isNotEmpty) {
    throw ArgumentError.value(invalid, 'praiseShortIds', 'invalid shortId');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }
  return '${RoutePaths.home}'
      '?${UrlSyncParams.praiseItems}=${praiseShortIds.join('-')}'
      '&${UrlSyncParams.shortName}=${Uri.encodeComponent(shareName)}';
}

/// URL absoluta do link por praise ([origin] + [buildPraiseShareLocation]).
String buildPraiseShareUrl({
  required String origin,
  required List<String> praiseShortIds,
  required String shareName,
}) {
  final normalizedOrigin = origin.endsWith('/')
      ? origin.substring(0, origin.length - 1)
      : origin;
  return '$normalizedOrigin'
      '${buildPraiseShareLocation(praiseShortIds: praiseShortIds, shareName: shareName)}';
}
```

- [ ] **Step 6: Doc do esquema custom**

Em `lib/core/constants/deep_link_config.dart`, linha 7, trocar o comentário por:

```dart
  /// URL scheme customizado para dev/testes (`plpcg:///?p=…&n=…`).
```

- [ ] **Step 7: Correr e ver passar**

Run: `flutter test test/unit/core/praise_share_url_test.dart test/unit/core/playlist_share_url_builder_test.dart && flutter analyze`
Expected: PASS; analyze sem issues.

- [ ] **Step 8: Commit**

```bash
git add lib/core/constants/share_config.dart lib/core/constants/deep_link_config.dart lib/core/utils/url_sync_params.dart lib/core/utils/playlist_share_url_builder.dart test/unit/core/praise_share_url_test.dart
git commit -m "$(cat <<'EOF'
feat(share): formato de link por praise (?p=&n=) e ShareConfig.appOrigin

Aditivo: o formato antigo continua no builder até o import trocar.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Gerar por praise + fim do gate de share

**Files:**
- Create: `lib/features/playlists/domain/exceptions/praise_short_id_unavailable_exception.dart`
- Modify: `lib/features/playlists/domain/usecases/generate_playlist_share_url.dart` (reescrito)
- Modify: `lib/features/playlists/data/providers/playlist_providers.dart:1-28, 104-125`
- Modify: `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart` (reescrito)
- Modify: `lib/core/constants/api_endpoints.dart:35-39`
- Modify: `lib/features/leaflet/presentation/widgets/leaflet_content.dart:257-258`, `lib/features/leaflet/domain/entities/leaflet_document.dart:27-28`
- Modify: `lib/l10n/app_pt.arb:615-620`, `lib/l10n/app_en.arb:600-605` (+ gerados)
- Delete: `lib/features/playlists/domain/entities/playlist_share_link.dart`, `lib/features/playlists/domain/ports/share_link_shortener.dart`, `lib/features/playlists/data/datasources/share_link_shortener_remote.dart`, `lib/features/playlists/presentation/widgets/coldigom_share_dialog.dart`, `test/unit/features/playlists/share_link_shortener_remote_test.dart`
- Create (teste): `test/support/fixtures/praise_share_fixtures.dart`, `test/unit/features/playlists/generate_playlist_share_url_provider_test.dart`
- Test (reescritos): `test/unit/features/playlists/generate_playlist_share_url_test.dart`, `test/unit/features/playlists/playlist_share_actions_test.dart`

**Interfaces:**
- Consumes: `buildPraiseShareUrl`, `isPraiseShortId`, `ShareConfig.appOrigin` (Tarefa 1); `ColdigomSearchIndex.groupForMaterialId`, `ColdigomPraiseMetadata.shortId`, `ColdigomSearchIndex.groupByShortId` (plano 1); `coldigomSearchIndexProvider`, `coldigomCatalogSyncProvider` (existentes, `coldigom_catalog_providers.dart`).
- Produces:
  - `typedef PraiseShortIdLookup = String? Function(String entryId);`
  - `GeneratePlaylistShareUrl(PlaylistRepository, {required PraiseShortIdLookup praiseShortIdOf, String shareOrigin = ShareConfig.appOrigin})` com `Future<String> call({required String playlistId})`
  - `class PraiseShortIdUnavailableException implements Exception { const PraiseShortIdUnavailableException(List<String> entryIds); final List<String> entryIds; }`
  - `generatePlaylistShareUrlProvider`, que resolve pelo `coldigomSearchIndexProvider`
  - Fixtures de teste: `praiseMaterialId`, `praisePdf`, `praiseAudio`, `praiseChord`, `praiseGroup`, `praiseIndex`

- [ ] **Step 1: Fixtures de catálogo por praise (reusadas nas Tarefas 2–4)**

```dart
// test/support/fixtures/praise_share_fixtures.dart
//
// Catálogo mínimo por praise para os testes do link `?p=` (plano 2).
// O `shortId` vive em `coldigomMeta` (C3) e o índice monta os mapas
// `shortId → grupo` e `material → grupo` no `build` (C4).
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';

/// Id de material Coldigom — `encodePdfId` do path R2, como no app.
String praiseMaterialId(String praiseId, String file) =>
    encodePdfId('assets/praises/$praiseId/$file');

Louvor praisePdf({
  required String praiseId,
  required String pdfId,
  String categoria = 'Partitura',
  String? materialKindId,
}) => Louvor(
  nome: 'Louvor $praiseId',
  numero: '001',
  categoria: categoria,
  classificacao: 'Coro',
  pdf: 'https://coldigom.test/$pdfId',
  pdfId: pdfId,
  groupId: praiseId,
  searchTitleNorm: 'louvor $praiseId',
  searchContentTokens: const [],
  searchCompactContent: '',
  materialKindId: materialKindId,
  praiseId: praiseId,
);

AudioTrack praiseAudio({
  required String praiseId,
  required String audioId,
  String? materialKindId,
}) => AudioTrack(
  audioId: audioId,
  r2Key: 'assets/praises/$praiseId/audio.mp3',
  nome: 'Louvor $praiseId',
  numero: '001',
  groupId: praiseId,
  categoria: 'Áudio',
  classificacao: 'Coro',
  materialKindId: materialKindId,
);

ChordMaterial praiseChord({required String praiseId, required String chordId}) =>
    ChordMaterial(
      chordId: chordId,
      r2Key: 'assets/praises/$praiseId/cifra.chord',
      nome: 'Louvor $praiseId',
      numero: '001',
      groupId: praiseId,
      categoria: 'Cifra',
      classificacao: 'Coro',
    );

LouvorGroup praiseGroup({
  required String praiseId,
  String? shortId,
  List<Louvor> pdfs = const [],
  List<AudioTrack> audios = const [],
  List<ChordMaterial> chords = const [],
}) => LouvorGroup(
  groupId: praiseId,
  numero: '001',
  nome: 'Louvor $praiseId',
  sections: [
    if (pdfs.isNotEmpty)
      LouvorMaterialSection(
        classificacao: 'Coro',
        displayLabel: 'Coro',
        materials: [
          for (final pdf in pdfs)
            LouvorMaterialEntry(
              categoria: pdf.categoria,
              pdfId: pdf.pdfId,
              louvor: pdf,
            ),
        ],
      ),
  ],
  audioTracks: audios,
  chordMaterials: chords,
  coldigomMeta: ColdigomPraiseMetadata(
    name: 'Louvor $praiseId',
    shortId: shortId,
  ),
);

ColdigomSearchIndex praiseIndex(List<LouvorGroup> groups) =>
    ColdigomSearchIndex.build([
      for (final group in groups)
        ColdigomIndexedPraise.build(
          praiseId: group.groupId,
          numero: group.numero,
          nome: group.nome,
          searchTokens: group.nome.toLowerCase(),
          group: group,
        ),
    ]);
```

- [ ] **Step 2: Teste do use case (reescrever o ficheiro inteiro)**

```dart
// test/unit/features/playlists/generate_playlist_share_url_test.dart
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_playlist_share_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/praise_short_id_unavailable_exception.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlists);

  final Map<String, SavedPlaylist> _playlists;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      _playlists[playlistId];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _pdf = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _audio = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);
const _chord = PlaylistEntry(id: 'cif-1', kind: MaterialKind.chord);
const _gesture = PlaylistEntry(id: 'ges-1', kind: MaterialKind.gesture);
const _youtube = PlaylistEntry(id: 'yt-1', kind: MaterialKind.youtube);

GeneratePlaylistShareUrl _useCase(
  List<PlaylistEntry>? entries,
  Map<String, String> shortIds, {
  String nome = 'Culto de domingo',
  String? origin,
}) {
  final repository = _FakePlaylistRepository({
    if (entries != null)
      'p1': SavedPlaylist(
        playlistId: 'p1',
        nome: nome,
        entries: entries,
        createdAt: DateTime(2026, 9, 23),
      ),
  });
  String? lookup(String entryId) => shortIds[entryId];
  return origin == null
      ? GeneratePlaylistShareUrl(repository, praiseShortIdOf: lookup)
      : GeneratePlaylistShareUrl(
          repository,
          praiseShortIdOf: lookup,
          shareOrigin: origin,
        );
}

void main() {
  test('vetor do contrato: PDF, áudio e cifra, origem v2 por padrão', () async {
    final url = await _useCase(
      const [_pdf, _audio, _chord],
      const {'pdf-a': '1a2', 'aud-1': '0c3', 'cif-1': 'fff'},
    )(playlistId: 'p1');
    expect(url, 'https://v2.plpcg.com/?p=1a2-0c3-fff&n=Culto%20de%20domingo');
  });

  test('gesto e YouTube também servem', () async {
    final url = await _useCase(
      const [_gesture, _youtube],
      const {'ges-1': '0a1', 'yt-1': '0b2'},
    )(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '0a1-0b2');
  });

  test('dois materiais do mesmo praise viram o mesmo token duas vezes', () async {
    final url = await _useCase(
      const [_pdf, _audio],
      const {'pdf-a': '0a1', 'aud-1': '0a1'},
      nome: 'Ensaio',
    )(playlistId: 'p1');
    expect(url, 'https://v2.plpcg.com/?p=0a1-0a1&n=Ensaio');
  });

  test('entrada repetida repete o token, na ordem da lista', () async {
    final url = await _useCase(
      const [_pdf, _audio, _pdf],
      const {'pdf-a': '1a2', 'aud-1': '0c3'},
    )(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '1a2-0c3-1a2');
  });

  test('maiúsculas e espaços do catálogo normalizam', () async {
    final url = await _useCase(
      const [_pdf],
      const {'pdf-a': ' 1A2 '},
    )(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '1a2');
  });

  test('praise sem shortId → PraiseShortIdUnavailableException com os ids', () async {
    await expectLater(
      _useCase(
        const [_pdf, _audio, _chord],
        const {'pdf-a': '1a2'},
      )(playlistId: 'p1'),
      throwsA(
        isA<PraiseShortIdUnavailableException>().having(
          (e) => e.entryIds,
          'entryIds',
          ['aud-1', 'cif-1'],
        ),
      ),
    );
  });

  test('shortId fora do padrão conta como em falta', () async {
    await expectLater(
      _useCase(
        const [_pdf, _audio],
        const {'pdf-a': '12', 'aud-1': 'zzz'},
      )(playlistId: 'p1'),
      throwsA(
        isA<PraiseShortIdUnavailableException>().having(
          (e) => e.entryIds,
          'entryIds',
          ['pdf-a', 'aud-1'],
        ),
      ),
    );
  });

  test('origem configurável, sem barra final', () async {
    final url = await _useCase(
      const [_pdf],
      const {'pdf-a': '1a2'},
      origin: 'https://staging.plpcg.test/',
    )(playlistId: 'p1');
    expect(url, startsWith('https://staging.plpcg.test/?p=1a2&n='));
  });

  test('lista ausente → PlaylistNotFoundException', () async {
    await expectLater(
      _useCase(null, const {})(playlistId: 'p1'),
      throwsA(isA<PlaylistNotFoundException>()),
    );
  });

  test('lista vazia → EmptyPlaylistShareException', () async {
    await expectLater(
      _useCase(const [], const {})(playlistId: 'p1'),
      throwsA(isA<EmptyPlaylistShareException>()),
    );
  });
}
```

- [ ] **Step 3: Teste do provider sobre o índice (novo)**

```dart
// test/unit/features/playlists/generate_playlist_share_url_provider_test.dart
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/praise_short_id_unavailable_exception.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures/praise_share_fixtures.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlist);

  final SavedPlaylist _playlist;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      playlistId == _playlist.playlistId ? _playlist : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  // Material movido (desvio 2 do spec de 18/09): o path aponta a pasta de
  // `p-outro`, mas o material pertence ao praise `p1` no catálogo.
  final movedPdfId = praiseMaterialId('p-outro', 'partitura.pdf');
  final ownAudioId = praiseMaterialId('p1', 'audio.mp3');
  final index = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      pdfs: [praisePdf(praiseId: 'p1', pdfId: movedPdfId)],
      audios: [praiseAudio(praiseId: 'p1', audioId: ownAudioId)],
    ),
    praiseGroup(
      praiseId: 'p-outro',
      shortId: 'fff',
      pdfs: [
        praisePdf(
          praiseId: 'p-outro',
          pdfId: praiseMaterialId('p-outro', 'coro.pdf'),
        ),
      ],
    ),
    praiseGroup(
      praiseId: 'p-sem-id',
      audios: [
        praiseAudio(
          praiseId: 'p-sem-id',
          audioId: praiseMaterialId('p-sem-id', 'audio.mp3'),
        ),
      ],
    ),
  ]);

  Future<String> share(
    ColdigomSearchIndex index,
    List<PlaylistEntry> entries,
  ) {
    final container = ProviderContainer(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(
          _FakePlaylistRepository(
            SavedPlaylist(
              playlistId: 'p1',
              nome: 'Ensaio',
              entries: entries,
              createdAt: DateTime(2026, 9, 23),
            ),
          ),
        ),
        coldigomSearchIndexProvider.overrideWithValue(index),
      ],
    );
    addTearDown(container.dispose);
    return container.read(generatePlaylistShareUrlProvider)(playlistId: 'p1');
  }

  test('sentinela do contrato C4: o índice resolve shortId e material', () {
    expect(index.groupByShortId('0a1')?.groupId, 'p1');
    expect(index.groupForMaterialId(movedPdfId)?.groupId, 'p1');
    expect(index.groupForMaterialId(ownAudioId)?.groupId, 'p1');
  });

  test('material movido usa o praise do catálogo, não o do path', () async {
    final url = await share(index, [
      PlaylistEntry(id: movedPdfId, kind: MaterialKind.pdf),
      PlaylistEntry(id: ownAudioId, kind: MaterialKind.audio),
    ]);
    expect(url, 'https://v2.plpcg.com/?p=0a1-0a1&n=Ensaio');
  });

  test('índice ainda vazio (arranque a frio) → PraiseShortIdUnavailableException', () async {
    await expectLater(
      share(ColdigomSearchIndex.empty, [
        PlaylistEntry(id: ownAudioId, kind: MaterialKind.audio),
      ]),
      throwsA(isA<PraiseShortIdUnavailableException>()),
    );
  });

  test('praise sem shortId no catálogo → PraiseShortIdUnavailableException', () async {
    await expectLater(
      share(index, [
        PlaylistEntry(
          id: praiseMaterialId('p-sem-id', 'audio.mp3'),
          kind: MaterialKind.audio,
        ),
      ]),
      throwsA(isA<PraiseShortIdUnavailableException>()),
    );
  });
}
```

- [ ] **Step 4: Teste das ações de share (reescrever o ficheiro inteiro)**

```dart
// test/unit/features/playlists/playlist_share_actions_test.dart
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlist);

  final SavedPlaylist? _playlist;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      _playlist?.playlistId == playlistId ? _playlist : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Conta os `sync()` que o share pede quando falta `shortId` (§4.2).
class _CountingSync extends ColdigomCatalogSyncNotifier {
  var calls = 0;

  @override
  ColdigomCatalogSyncState build() => const ColdigomCatalogSyncState();

  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    calls++;
    return const ColdigomCatalogSyncNoop();
  }
}

const _pdf = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _audio = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);
const _chord = PlaylistEntry(id: 'cif-1', kind: MaterialKind.chord);
const _shortIds = {'pdf-a': '1a2', 'aud-1': '0c3', 'cif-1': 'fff'};
const _url = 'https://v2.plpcg.com/?p=1a2-0c3-fff&n=Ensaio';

SavedPlaylist _ensaio(List<PlaylistEntry> entries) => SavedPlaylist(
  playlistId: 'p1',
  nome: 'Ensaio',
  entries: entries,
  createdAt: DateTime(2026, 9, 23),
);

PlaylistShareContext _shareContext(List<PlaylistEntry> entries) =>
    PlaylistShareContext(playlistId: 'p1', nome: 'Ensaio', entries: entries);

/// Monta o scope com a lista [playlist] no repositório e o catálogo
/// [shortIds]; devolve o contexto pronto e o sync contador.
Future<(BuildContext, _CountingSync)> _pump(
  WidgetTester tester, {
  required SavedPlaylist? playlist,
  Map<String, String> shortIds = _shortIds,
}) async {
  final repository = _FakePlaylistRepository(playlist);
  final sync = _CountingSync();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(repository),
        generatePlaylistShareUrlProvider.overrideWithValue(
          GeneratePlaylistShareUrl(
            repository,
            praiseShortIdOf: (id) => shortIds[id],
          ),
        ),
        coldigomCatalogSyncProvider.overrideWith(() => sync),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  return (tester.element(find.byType(Scaffold)), sync);
}

/// `capture` que lê o [LeafletDocument] montado no overlay.
CaptureWidgetToPngFn _captureInto(
  WidgetTester tester,
  void Function(LeafletDocument) onDocument,
) {
  return (boundaryKey) async {
    // O overlay foi inserido, mas só constrói no próximo frame.
    await tester.pump();
    final content = tester.widget<LeafletContent>(find.byType(LeafletContent));
    onDocument(content.document);
    return const [1, 2, 3];
  };
}

void main() {
  testWidgets('Só o link partilha a URL por praise (PDF, áudio e cifra)', (
    tester,
  ) async {
    final (context, sync) = await _pump(
      tester,
      playlist: _ensaio(const [_pdf, _audio, _chord]),
    );
    final notifier = ProviderScope.containerOf(
      context,
    ).read(playlistShareActionsProvider.notifier);
    String? sharedText;

    final ok = await notifier.share(
      context,
      _shareContext(const [_pdf, _audio, _chord]),
      PlaylistShareOption.link,
      sharePositionOrigin: null,
      share: (text, {subject, sharePositionOrigin}) async {
        sharedText = text;
      },
    );

    expect(ok, isTrue);
    expect(sharedText, _url);
    expect(sync.calls, 0);
  });

  testWidgets('Folheto de lista com áudio e cifra leva link e QR', (
    tester,
  ) async {
    final (context, _) = await _pump(
      tester,
      playlist: _ensaio(const [_pdf, _audio, _chord]),
    );
    final notifier = ProviderScope.containerOf(
      context,
    ).read(playlistShareActionsProvider.notifier);
    LeafletDocument? doc;
    String? capturedText;

    final ok = await notifier.share(
      context,
      _shareContext(const [_pdf, _audio, _chord]),
      PlaylistShareOption.linkWithLeaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
        capturedText = text;
      },
      capture: _captureInto(tester, (d) => doc = d),
    );

    expect(ok, isTrue);
    expect(doc?.shareUrl, _url);
    expect(capturedText, contains(_url));
  });

  testWidgets('«Gerar folheto» sai com o QR do link', (tester) async {
    final (context, _) = await _pump(
      tester,
      playlist: _ensaio(const [_pdf, _audio]),
      shortIds: const {'pdf-a': '1a2', 'aud-1': '0c3'},
    );
    final notifier = ProviderScope.containerOf(
      context,
    ).read(playlistShareActionsProvider.notifier);
    LeafletDocument? doc;
    String? capturedSubject;
    String? capturedText;

    final ok = await notifier.share(
      context,
      _shareContext(const [_pdf, _audio]),
      PlaylistShareOption.leaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
        capturedSubject = subject;
        capturedText = text;
      },
      capture: _captureInto(tester, (d) => doc = d),
    );

    expect(ok, isTrue);
    expect(doc?.shareUrl, 'https://v2.plpcg.com/?p=1a2-0c3&n=Ensaio');
    expect(capturedSubject, 'Folheto PLPCG');
    expect(capturedText, isNull);
  });

  testWidgets('«Gerar folheto» de lista fora do repositório sai sem QR', (
    tester,
  ) async {
    final (context, sync) = await _pump(tester, playlist: null);
    final notifier = ProviderScope.containerOf(
      context,
    ).read(playlistShareActionsProvider.notifier);
    LeafletDocument? doc;

    final ok = await notifier.share(
      context,
      _shareContext(const [_pdf]),
      PlaylistShareOption.leaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {},
      capture: _captureInto(tester, (d) => doc = d),
    );

    expect(ok, isTrue);
    expect(doc, isNotNull);
    expect(doc?.shareUrl, isNull);
    expect(sync.calls, 0);
  });

  testWidgets(
    'leaflet com lista só de áudio gera folheto (não mostra playlistEmptyCarousel)',
    (tester) async {
      final (context, _) = await _pump(
        tester,
        playlist: _ensaio(const [_audio]),
      );
      final notifier = ProviderScope.containerOf(
        context,
      ).read(playlistShareActionsProvider.notifier);
      var shared = false;

      final ok = await notifier.share(
        context,
        _shareContext(const [_audio]),
        PlaylistShareOption.leaflet,
        sharePositionOrigin: null,
        shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
          shared = true;
        },
        capture: (boundaryKey) async => const [1, 2, 3],
      );

      expect(ok, isTrue);
      expect(shared, isTrue);
      expect(
        find.text(AppLocalizations.of(context)!.playlistEmptyCarousel),
        findsNothing,
      );
    },
  );

  testWidgets('praise sem shortId: Só o link falha com um snackbar e pede sync', (
    tester,
  ) async {
    final (context, sync) = await _pump(
      tester,
      playlist: _ensaio(const [_pdf, _audio]),
      shortIds: const {'pdf-a': '1a2'},
    );
    final notifier = ProviderScope.containerOf(
      context,
    ).read(playlistShareActionsProvider.notifier);
    String? sharedText;

    final ok = await notifier.share(
      context,
      _shareContext(const [_pdf, _audio]),
      PlaylistShareOption.link,
      sharePositionOrigin: null,
      share: (text, {subject, sharePositionOrigin}) async {
        sharedText = text;
      },
    );
    await tester.pump();

    expect(ok, isFalse);
    expect(sharedText, isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(sync.calls, 1);
  });

  testWidgets('praise sem shortId: Folheto não captura nem partilha', (
    tester,
  ) async {
    final (context, sync) = await _pump(
      tester,
      playlist: _ensaio(const [_pdf, _audio]),
      shortIds: const {'pdf-a': '1a2'},
    );
    final notifier = ProviderScope.containerOf(
      context,
    ).read(playlistShareActionsProvider.notifier);
    var captured = false;
    var shared = false;

    final ok = await notifier.share(
      context,
      _shareContext(const [_pdf, _audio]),
      PlaylistShareOption.linkWithLeaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
        shared = true;
      },
      capture: (boundaryKey) async {
        captured = true;
        return const [1, 2, 3];
      },
    );
    await tester.pump();

    expect(ok, isFalse);
    expect(captured, isFalse);
    expect(shared, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(sync.calls, 1);
  });

  testWidgets(
    'playlist sem entradas: EmptyPlaylistShareException mostra exatamente '
    'um snackbar (o provider é o único dono do feedback)',
    (tester) async {
      final (context, _) = await _pump(tester, playlist: _ensaio(const []));
      final notifier = ProviderScope.containerOf(
        context,
      ).read(playlistShareActionsProvider.notifier);

      final ok = await notifier.share(
        context,
        _shareContext(const [_pdf]),
        PlaylistShareOption.link,
        sharePositionOrigin: null,
      );
      await tester.pump();

      expect(ok, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );
}
```

`CaptureWidgetToPngFn` vem de `playlist_share_actions_provider.dart`, que o teste já importa.

- [ ] **Step 5: Correr e ver falhar**

Run: `flutter test test/unit/features/playlists/generate_playlist_share_url_test.dart test/unit/features/playlists/generate_playlist_share_url_provider_test.dart test/unit/features/playlists/playlist_share_actions_test.dart`
Expected: FAIL (compilação): `praise_short_id_unavailable_exception.dart` não existe; `GeneratePlaylistShareUrl` sem `praiseShortIdOf`.

- [ ] **Step 6: Exceção**

```dart
// lib/features/playlists/domain/exceptions/praise_short_id_unavailable_exception.dart

/// Entrada(s) da lista sem `shortId` de praise no catálogo local — o link por
/// praise não pode ser montado (spec fim-fonte-plpcg §4.2).
///
/// Lançada por `GeneratePlaylistShareUrl`. Quem mostra o erro também pede um
/// sync do catálogo: o próximo share já encontra o id.
class PraiseShortIdUnavailableException implements Exception {
  const PraiseShortIdUnavailableException(this.entryIds);

  /// Ids das entradas sem token, na ordem da lista.
  final List<String> entryIds;

  @override
  String toString() =>
      'PraiseShortIdUnavailableException(${entryIds.length} sem shortId: '
      '${entryIds.join(', ')})';
}
```

- [ ] **Step 7: Use case (substituir o ficheiro inteiro)**

```dart
// lib/features/playlists/domain/usecases/generate_playlist_share_url.dart
import '../../../../core/constants/share_config.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../entities/saved_playlist.dart';
import '../exceptions/empty_playlist_share_exception.dart';
import '../exceptions/playlist_not_found_exception.dart';
import '../exceptions/praise_short_id_unavailable_exception.dart';
import '../repositories/playlist_repository.dart';

/// Id de uma entrada da lista → `shortId` do praise dela, pelo catálogo local
/// (spec fim-fonte-plpcg §4.2) — nunca pelo path do id (materiais movidos).
/// `null` = material fora do índice ou praise sem `shortId`.
typedef PraiseShortIdLookup = String? Function(String entryId);

/// UC-07 — gerar o link de compartilhamento por praise (`?p=…&n=…`).
class GeneratePlaylistShareUrl {
  const GeneratePlaylistShareUrl(
    this._repository, {
    required this.praiseShortIdOf,
    this.shareOrigin = ShareConfig.appOrigin,
  });

  final PlaylistRepository _repository;
  final PraiseShortIdLookup praiseShortIdOf;
  final String shareOrigin;

  /// Um token por entrada, na ordem da lista. Repetidos ficam: duas entradas
  /// do mesmo praise viram o mesmo token duas vezes. Qualquer kind serve
  /// (PDF, áudio, cifra, gesto, YouTube).
  ///
  /// Lança [PlaylistNotFoundException], [EmptyPlaylistShareException] ou
  /// [PraiseShortIdUnavailableException] (com os ids sem token) — o link
  /// nunca sai com louvores a menos.
  Future<String> call({required String playlistId}) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) throw const PlaylistNotFoundException();
    if (playlist.entries.isEmpty) throw const EmptyPlaylistShareException();

    final shortIds = <String>[];
    final missing = <String>[];
    for (final entry in playlist.entries) {
      final shortId = praiseShortIdOf(entry.id)?.trim().toLowerCase();
      if (shortId == null || !isPraiseShortId(shortId)) {
        missing.add(entry.id);
        continue;
      }
      shortIds.add(shortId);
    }
    if (missing.isNotEmpty) throw PraiseShortIdUnavailableException(missing);

    return buildPraiseShareUrl(
      origin: shareOrigin,
      praiseShortIds: shortIds,
      shareName: playlist.nome,
    );
  }
}
```

- [ ] **Step 8: Provider**

Em `lib/features/playlists/data/providers/playlist_providers.dart`:
- apagar os imports `../../../../core/providers/dio_provider.dart`, `../../../auth/presentation/providers/auth_state_provider.dart`, `../../../catalog/presentation/providers/louvores_by_pdf_id_provider.dart`, `../../domain/ports/share_link_shortener.dart` e `../datasources/share_link_shortener_remote.dart`;
- acrescentar `import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';`;
- trocar os blocos `shareLinkShortenerProvider` e `generatePlaylistShareUrlProvider` (linhas 104–125) por:

```dart
/// UC-07 — gerar o link por praise (spec fim-fonte-plpcg §4.2): entrada →
/// grupo pelo índice local (`groupForMaterialId`) → `shortId` do praise.
/// Lido na hora do share: um índice que hidratou depois vale.
final generatePlaylistShareUrlProvider = Provider<GeneratePlaylistShareUrl>((
  ref,
) {
  return GeneratePlaylistShareUrl(
    ref.watch(playlistRepositoryProvider),
    praiseShortIdOf: (entryId) => ref
        .read(coldigomSearchIndexProvider)
        .groupForMaterialId(entryId)
        ?.coldigomMeta
        ?.shortId,
  );
});
```

`shortIdResolverProvider` e `importSharedPlaylistFromUrlProvider` ficam como estão até à Tarefa 4.

- [ ] **Step 9: Ações de share (substituir o ficheiro inteiro)**

```dart
// lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../leaflet/domain/exceptions/empty_leaflet_exception.dart';
import '../../../leaflet/presentation/providers/leaflet_actions_provider.dart';
import '../../../leaflet/presentation/utils/leaflet_capture.dart';
import '../../../leaflet/presentation/utils/leaflet_debug_log.dart';
import '../../../leaflet/presentation/widgets/leaflet_content_labels.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/playlist_share_option.dart';
import '../../domain/exceptions/empty_playlist_share_exception.dart';
import '../../domain/exceptions/playlist_not_found_exception.dart';
import '../../domain/exceptions/praise_short_id_unavailable_exception.dart';
import '../providers/playlists_provider.dart';
import '../utils/playlist_share_debug_log.dart';

/// Callback injetável para testes — espelha [captureLeafletPngBytes].
typedef CaptureWidgetToPngFn = Future<List<int>> Function(
  GlobalKey boundaryKey,
);

/// Callback injetável para testes — espelha `Share.shareXFiles`.
typedef ShareXFilesFn = Future<void> Function(
  List<XFile> files, {
  String? subject,
  String? text,
  Rect? sharePositionOrigin,
});

/// Orquestra os 3 modos: link, folheto, folheto+link.
///
/// O link é sempre por praise (`?p=…&n=…`, spec fim-fonte-plpcg §4) e serve
/// a qualquer lista, com qualquer material. Entrada cujo praise não tem
/// `shortId` no catálogo local falha o share com o snackbar de erro e pede um
/// sync do catálogo (§4.2).
class PlaylistShareActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Executa [option] para [shareContext].
  ///
  /// [sharePositionOrigin] deve ser capturado antes de qualquer `await`.
  /// Retorna `false` em falha — o próprio provider mostra o snackbar
  /// (mensagem específica para [EmptyLeafletException], genérica para as
  /// demais exceções) antes de retornar; quem chama **não deve** mostrar
  /// outro snackbar em cima do retorno `false`.
  Future<bool> share(
    BuildContext context,
    PlaylistShareContext shareContext,
    PlaylistShareOption option, {
    required Rect? sharePositionOrigin,
    ShareFn? share,
    ShareXFilesFn? shareXFiles,
    CaptureWidgetToPngFn? capture,
  }) async {
    playlistShareDebugClearLastFailure();
    final l10n = AppLocalizations.of(context)!;
    final shareTextFn = share ?? _defaultShare;
    final shareFilesFn = shareXFiles ?? _defaultShareXFiles;

    try {
      switch (option) {
        case PlaylistShareOption.link:
          return await _shareLinkOnly(
            shareContext,
            shareTextFn,
            sharePositionOrigin,
          );
        case PlaylistShareOption.leaflet:
          return await _shareLeafletOnly(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            capture: capture,
          );
        case PlaylistShareOption.linkWithLeaflet:
          return await _shareLinkWithLeaflet(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            capture: capture,
          );
      }
    } on EmptyLeafletException catch (error, stackTrace) {
      playlistShareDebugLogError('seleção vazia', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.playlistEmptyCarousel)));
      }
      return false;
    } on PlaylistNotFoundException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist não encontrada', error, stackTrace);
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
      return false;
    } on EmptyPlaylistShareException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist sem entradas', error, stackTrace);
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
      return false;
    } on PraiseShortIdUnavailableException catch (error, stackTrace) {
      playlistShareDebugLogError('praise sem shortId', error, stackTrace);
      _requestCatalogSync();
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
      return false;
    } on Object catch (error, stackTrace) {
      playlistShareDebugLogError('share', error, stackTrace);
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
      return false;
    }
  }

  Future<bool> _shareLinkOnly(
    PlaylistShareContext shareContext,
    ShareFn shareTextFn,
    Rect? sharePositionOrigin,
  ) async {
    final url = await _generateUrl(shareContext.playlistId);
    await shareTextFn(
      url,
      subject: shareContext.nome,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<bool> _shareLeafletOnly(
    BuildContext context,
    PlaylistShareContext shareContext,
    AppLocalizations l10n,
    ShareXFilesFn shareFilesFn,
    Rect? sharePositionOrigin, {
    CaptureWidgetToPngFn? capture,
  }) async {
    // O folheto sai com o QR do link (§4.5). Só fica sem QR quando não pode
    // haver link: lista fora do repositório (ex.: web sem Isar) ou sem
    // entradas. Praise sem `shortId` não cai aqui — falha o share (§4.2).
    String? qrUrl;
    try {
      qrUrl = await _generateUrl(shareContext.playlistId);
    } on PlaylistNotFoundException catch (error, stackTrace) {
      playlistShareDebugLogError('link para QR', error, stackTrace);
    } on EmptyPlaylistShareException catch (error, stackTrace) {
      playlistShareDebugLogError('link para QR', error, stackTrace);
    }
    if (!context.mounted) return false;
    final overlay = Overlay.of(context);
    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
      shareUrl: qrUrl,
    );
    if (!context.mounted) return false;

    await shareFilesFn(
      [xFile],
      subject: l10n.leafletShareSubject,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<bool> _shareLinkWithLeaflet(
    BuildContext context,
    PlaylistShareContext shareContext,
    AppLocalizations l10n,
    ShareXFilesFn shareFilesFn,
    Rect? sharePositionOrigin, {
    CaptureWidgetToPngFn? capture,
  }) async {
    final url = await _generateUrl(shareContext.playlistId);
    if (!context.mounted) return false;
    final overlay = Overlay.of(context);

    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
      shareUrl: url,
    );
    if (!context.mounted) return false;

    final message = l10n.playlistShareLinkWithLeafletMessage(
      shareContext.nome,
      url,
    );
    await shareFilesFn(
      [xFile],
      subject: shareContext.nome,
      text: message,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<String> _generateUrl(String playlistId) =>
      ref.read(generatePlaylistShareUrlProvider)(playlistId: playlistId);

  /// Pedido quando um praise da lista não tem `shortId` no catálogo local
  /// (§4.2). Não bloqueia o snackbar; falha vira log.
  void _requestCatalogSync() {
    final syncNotifier = ref.read(coldigomCatalogSyncProvider.notifier);
    unawaited(
      syncNotifier.sync().then<void>(
        (_) {},
        onError: (Object e) =>
            debugPrint('[UC-07 playlist-share] sync do catálogo falhou: $e'),
      ),
    );
  }

  Future<XFile> _captureLeafletXFile(
    OverlayState overlay,
    PlaylistShareContext shareContext,
    AppLocalizations l10n, {
    CaptureWidgetToPngFn? capture,
    String? shareUrl,
  }) async {
    final document = await resolveLeafletDocument(
      ref,
      entries: shareContext.entries,
      fromCarousel: shareContext.fromCarousel,
      shareUrl: shareUrl,
    );
    final labels = LeafletContentLabels.fromL10n(l10n, document.generatedAt);
    leafletDebugLog(
      'captureLeaflet: ${document.entries.length} entradas '
      '(fromCarousel=${shareContext.fromCarousel})',
    );
    final pngBytes = await captureLeafletPngBytes(
      overlay,
      document,
      labels,
      capture: capture,
    );
    return leafletXFileFromBytes(pngBytes);
  }
}

Future<void> _defaultShare(
  String text, {
  String? subject,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

Future<void> _defaultShareXFiles(
  List<XFile> files, {
  String? subject,
  String? text,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: files,
      subject: subject,
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

final playlistShareActionsProvider =
    NotifierProvider<PlaylistShareActionsNotifier, void>(
      PlaylistShareActionsNotifier.new,
    );
```

- [ ] **Step 10: Apagar o gate, o encurtador e o link por material**

```bash
git rm lib/features/playlists/domain/entities/playlist_share_link.dart \
  lib/features/playlists/domain/ports/share_link_shortener.dart \
  lib/features/playlists/data/datasources/share_link_shortener_remote.dart \
  lib/features/playlists/presentation/widgets/coldigom_share_dialog.dart \
  test/unit/features/playlists/share_link_shortener_remote_test.dart
```

Em `lib/core/constants/api_endpoints.dart`, apagar o bloco `links` inteiro (o comentário das linhas 35–38 e `static const String links = '/api/links';`).

- [ ] **Step 11: Docs do QR no folheto**

Em `lib/features/leaflet/presentation/widgets/leaflet_content.dart`, trocar as duas primeiras linhas do doc de `_ShareQrBand` por:

```dart
/// Rodapé com o QR do link da lista (`?p=…&n=…`, spec fim-fonte-plpcg §4.5).
/// Só existe quando [LeafletDocument.shareUrl] veio preenchido.
```

Em `lib/features/leaflet/domain/entities/leaflet_document.dart`, trocar o doc de `shareUrl` (linhas 27–28) por:

```dart
  /// Link da lista para o QR do rodapé (spec fim-fonte-plpcg §4.5).
  /// `null` = sem QR (lista fora do repositório ou sem entradas).
```

- [ ] **Step 12: Strings do diálogo Coldigom saem**

Em `lib/l10n/app_pt.arb` e `lib/l10n/app_en.arb`, apagar as seis linhas `playlistShareColdigomTitle`, `playlistShareColdigomBodyLeaflet`, `playlistShareColdigomBodyLink`, `playlistShareColdigomCancel`, `playlistShareColdigomLeafletOnly` e `playlistShareColdigomDismiss` (não têm bloco `@`). Depois:

Run: `flutter gen-l10n && grep -rn "playlistShareColdigom\|ShareLinkShortener\|PlaylistShareLink\b\|showColdigomShareDialog\|ApiEndpoints.links" lib test`
Expected: grep sem saída.

- [ ] **Step 13: Correr e ver passar**

Run: `flutter test test/unit/features/playlists/ test/unit/core/ test/widget/features/playlists/ test/widget/features/carousel/ test/unit/features/leaflet/ test/widget/features/leaflet/ && flutter analyze`
Expected: PASS; analyze sem issues.

- [ ] **Step 14: Commit**

```bash
git add -A lib/features/playlists lib/core/constants/api_endpoints.dart lib/features/leaflet lib/l10n test/support/fixtures test/unit/features/playlists
git commit -m "$(cat <<'EOF'
feat(share): link por praise para qualquer lista; sai o gate Coldigom

GeneratePlaylistShareUrl resolve entrada → praise pelo índice local e
devolve só a URL; praise sem shortId falha com snackbar e pede sync.
Saem o diálogo Coldigom, PlaylistShareLink, o encurtador /l/ e as 6
strings playlistShareColdigom*.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Resolvedor do import por praise (aditivo)

Peças novas, ainda sem chamador. A Tarefa 4 liga-as ao use case.

**Files:**
- Create: `lib/features/playlists/domain/ports/praise_entry_resolver.dart`
- Create: `lib/features/coldigom/presentation/providers/await_coldigom_search_index.dart`
- Modify: `lib/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart` (acrescentar no fim)
- Create: `lib/features/playlists/presentation/utils/preferred_entry_for_praise.dart`
- Create: `lib/features/playlists/presentation/providers/praise_entry_resolver_provider.dart`
- Test: `test/unit/features/coldigom/await_coldigom_search_index_test.dart`, `test/unit/features/material_kind_prefs/await_favorite_material_kind_rank_test.dart`, `test/unit/features/playlists/preferred_entry_for_praise_test.dart`, `test/unit/features/playlists/praise_entry_resolver_provider_test.dart`

**Interfaces:**
- Consumes: `ColdigomSearchIndex.groupByShortId` (plano 1); `preferredMaterialForGroup(LouvorGroup, {Map<String,int> rank})` (existente); `materialKindPrefsProvider`, `MaterialKindPrefs.rank` (existentes); fixtures da Tarefa 2.
- Produces:
  - `typedef PraiseEntryResolver = PlaylistEntry? Function(String praiseShortId);`
  - `typedef PraiseEntryResolverLoader = Future<PraiseEntryResolver> Function();`
  - `const sharedPlaylistCatalogTimeout = Duration(seconds: 20);` e `Future<ColdigomSearchIndex> awaitColdigomSearchIndex(Ref ref, {Duration timeout})`
  - `const favoriteRankImportTimeout = Duration(seconds: 5);` e `Future<Map<String, int>> awaitFavoriteMaterialKindRank(Ref ref, {Duration timeout})`
  - `PlaylistEntry? preferredEntryForPraise(ColdigomSearchIndex index, String praiseShortId, {Map<String, int> rank})`
  - `final praiseEntryResolverLoaderProvider = Provider<PraiseEntryResolverLoader>(…)`

- [ ] **Step 1: Teste da escolha de material por praise**

```dart
// test/unit/features/playlists/preferred_entry_for_praise_test.dart
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/utils/preferred_entry_for_praise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures/praise_share_fixtures.dart';

void main() {
  final pdfId = praiseMaterialId('p1', 'partitura.pdf');
  final audioId = praiseMaterialId('p1', 'audio.mp3');
  final onlyAudioId = praiseMaterialId('p2', 'audio.mp3');
  final index = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      pdfs: [praisePdf(praiseId: 'p1', pdfId: pdfId, materialKindId: 'k-part')],
      audios: [
        praiseAudio(praiseId: 'p1', audioId: audioId, materialKindId: 'k-audio'),
      ],
    ),
    praiseGroup(
      praiseId: 'p2',
      shortId: '0c3',
      audios: [praiseAudio(praiseId: 'p2', audioId: onlyAudioId)],
    ),
    praiseGroup(
      praiseId: 'p3',
      shortId: 'fff',
      chords: [
        praiseChord(
          praiseId: 'p3',
          chordId: praiseMaterialId('p3', 'cifra.chord'),
        ),
      ],
    ),
  ]);

  test('sem favoritos: PDF principal', () {
    expect(
      preferredEntryForPraise(index, '0a1'),
      PlaylistEntry(id: pdfId, kind: MaterialKind.pdf),
    );
  });

  test('com favoritos: o material do favorito mais bem colocado', () {
    expect(
      preferredEntryForPraise(index, '0a1', rank: const {'k-audio': 0, 'k-part': 1}),
      PlaylistEntry(id: audioId, kind: MaterialKind.audio),
    );
  });

  test('favorito ausente do praise cai no fallback fixo', () {
    expect(
      preferredEntryForPraise(index, '0a1', rank: const {'k-outro': 0}),
      PlaylistEntry(id: pdfId, kind: MaterialKind.pdf),
    );
  });

  test('praise só com áudio: o áudio', () {
    expect(
      preferredEntryForPraise(index, '0c3'),
      PlaylistEntry(id: onlyAudioId, kind: MaterialKind.audio),
    );
  });

  test('praise sem nada adicionável (só cifra) → null', () {
    expect(preferredEntryForPraise(index, 'fff'), isNull);
  });

  test('token desconhecido → null', () {
    expect(preferredEntryForPraise(index, 'abc'), isNull);
  });
}
```

- [ ] **Step 2: Teste da espera pelo índice**

```dart
// test/unit/features/coldigom/await_coldigom_search_index_test.dart
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/await_coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures/praise_share_fixtures.dart';

class _CountingSync extends ColdigomCatalogSyncNotifier {
  var calls = 0;

  @override
  ColdigomCatalogSyncState build() => const ColdigomCatalogSyncState();

  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    calls++;
    return const ColdigomCatalogSyncNoop();
  }
}

class _MutableIndex extends Notifier<ColdigomSearchIndex> {
  _MutableIndex(this._initial);

  final ColdigomSearchIndex _initial;

  @override
  ColdigomSearchIndex build() => _initial;

  void update(ColdigomSearchIndex index) => state = index;
}

final _mutableIndexProvider =
    NotifierProvider<_MutableIndex, ColdigomSearchIndex>(
      () => _MutableIndex(ColdigomSearchIndex.empty),
    );

/// Dá um `Ref` estável ao helper — um `Provider` sem `watch` não reconstrói.
final _awaitProbe =
    Provider<Future<ColdigomSearchIndex> Function(Duration timeout)>(
      (ref) => (timeout) => awaitColdigomSearchIndex(ref, timeout: timeout),
    );

void main() {
  final hydrated = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      audios: [
        praiseAudio(
          praiseId: 'p1',
          audioId: praiseMaterialId('p1', 'audio.mp3'),
        ),
      ],
    ),
  ]);
  late _CountingSync sync;

  ProviderContainer container(ColdigomSearchIndex initial) {
    sync = _CountingSync();
    final c = ProviderContainer(
      overrides: [
        _mutableIndexProvider.overrideWith(() => _MutableIndex(initial)),
        coldigomSearchIndexProvider.overrideWith(
          (ref) => ref.watch(_mutableIndexProvider),
        ),
        coldigomCatalogSyncProvider.overrideWith(() => sync),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('índice já hidratado volta na hora, sem sync', () async {
    final c = container(hydrated);
    expect(
      await c.read(_awaitProbe)(const Duration(seconds: 1)),
      same(hydrated),
    );
    expect(sync.calls, 0);
  });

  test('índice vazio: pede sync e devolve o índice assim que ele enche', () async {
    final c = container(ColdigomSearchIndex.empty);
    final pending = c.read(_awaitProbe)(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);

    c.read(_mutableIndexProvider.notifier).update(hydrated);

    expect(await pending, same(hydrated));
    expect(sync.calls, 1);
  });

  test('prazo esgotado devolve o índice vazio', () async {
    final c = container(ColdigomSearchIndex.empty);
    final result = await c.read(_awaitProbe)(const Duration(milliseconds: 50));
    expect(result.isEmpty, isTrue);
    expect(sync.calls, 1);
  });
}
```

- [ ] **Step 3: Teste da espera pelos favoritos**

```dart
// test/unit/features/material_kind_prefs/await_favorite_material_kind_rank_test.dart
import 'dart:async';

import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedPrefs extends MaterialKindPrefsNotifier {
  _FixedPrefs(this._value);

  final MaterialKindPrefs _value;

  @override
  Future<MaterialKindPrefs> build() async => _value;
}

class _HangingPrefs extends MaterialKindPrefsNotifier {
  @override
  Future<MaterialKindPrefs> build() => Completer<MaterialKindPrefs>().future;
}

class _FailingPrefs extends MaterialKindPrefsNotifier {
  @override
  Future<MaterialKindPrefs> build() async => throw StateError('prefs quebradas');
}

final _rankProbe =
    Provider<Future<Map<String, int>> Function(Duration timeout)>(
      (ref) => (timeout) => awaitFavoriteMaterialKindRank(ref, timeout: timeout),
    );

void main() {
  Future<Map<String, int>> rankWith(
    MaterialKindPrefsNotifier Function() create, {
    Duration timeout = const Duration(seconds: 1),
  }) {
    final c = ProviderContainer(
      overrides: [materialKindPrefsProvider.overrideWith(create)],
    );
    addTearDown(c.dispose);
    return c.read(_rankProbe)(timeout);
  }

  test('logado com favoritos → rank na ordem', () async {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['k-audio', 'k-part'],
      updatedAt: DateTime.utc(2026, 9, 23),
    );
    expect(await rankWith(() => _FixedPrefs(prefs)), {
      'k-audio': 0,
      'k-part': 1,
    });
  });

  test('deslogado → vazio', () async {
    expect(await rankWith(() => _FixedPrefs(MaterialKindPrefs.empty)), isEmpty);
  });

  test('favoritos que não chegam no prazo → vazio', () async {
    expect(
      await rankWith(
        _HangingPrefs.new,
        timeout: const Duration(milliseconds: 50),
      ),
      isEmpty,
    );
  });

  test('erro ao ler favoritos → vazio', () async {
    expect(await rankWith(_FailingPrefs.new), isEmpty);
  });
}
```

- [ ] **Step 4: Teste do provider do resolvedor**

```dart
// test/unit/features/playlists/praise_entry_resolver_provider_test.dart
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
import 'package:coldigui/features/playlists/presentation/providers/praise_entry_resolver_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures/praise_share_fixtures.dart';

class _FixedPrefs extends MaterialKindPrefsNotifier {
  _FixedPrefs(this._value);

  final MaterialKindPrefs _value;

  @override
  Future<MaterialKindPrefs> build() async => _value;
}

void main() {
  final pdfId = praiseMaterialId('p1', 'partitura.pdf');
  final audioId = praiseMaterialId('p1', 'audio.mp3');
  final index = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      pdfs: [praisePdf(praiseId: 'p1', pdfId: pdfId, materialKindId: 'k-part')],
      audios: [
        praiseAudio(praiseId: 'p1', audioId: audioId, materialKindId: 'k-audio'),
      ],
    ),
  ]);

  Future<PraiseEntryResolver> load(MaterialKindPrefs prefs) {
    final c = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(index),
        materialKindPrefsProvider.overrideWith(() => _FixedPrefs(prefs)),
      ],
    );
    addTearDown(c.dispose);
    return c.read(praiseEntryResolverLoaderProvider)();
  }

  test('import com favoritos: grava o material do favorito', () async {
    final resolve = await load(
      MaterialKindPrefs.validated(
        kindIds: const ['k-audio'],
        updatedAt: DateTime.utc(2026, 9, 23),
      ),
    );
    expect(resolve('0a1'), PlaylistEntry(id: audioId, kind: MaterialKind.audio));
  });

  test('import sem login: PDF principal', () async {
    final resolve = await load(MaterialKindPrefs.empty);
    expect(resolve('0a1'), PlaylistEntry(id: pdfId, kind: MaterialKind.pdf));
  });

  test('token desconhecido → null', () async {
    final resolve = await load(MaterialKindPrefs.empty);
    expect(resolve('fff'), isNull);
  });
}
```

- [ ] **Step 5: Correr e ver falhar**

Run: `flutter test test/unit/features/playlists/preferred_entry_for_praise_test.dart test/unit/features/coldigom/await_coldigom_search_index_test.dart test/unit/features/material_kind_prefs/await_favorite_material_kind_rank_test.dart test/unit/features/playlists/praise_entry_resolver_provider_test.dart`
Expected: FAIL (compilação) — ficheiros e símbolos novos não existem.

- [ ] **Step 6: Porta**

```dart
// lib/features/playlists/domain/ports/praise_entry_resolver.dart
import '../entities/playlist_entry.dart';

/// `shortId` de praise → a entrada que o import grava (spec fim-fonte-plpcg
/// §4.3), com o material já escolhido: favorito da conta, senão PDF
/// principal → único áudio → primeiro adicionável. `null` = token
/// desconhecido no catálogo ou praise sem material adicionável — o import
/// salta.
typedef PraiseEntryResolver = PlaylistEntry? Function(String praiseShortId);

/// Espera o catálogo local (com prazo) e os favoritos e devolve o
/// [PraiseEntryResolver]. Com o prazo esgotado, o resolver devolve `null`
/// para tudo, e o import vira «link inválido» (§8).
typedef PraiseEntryResolverLoader = Future<PraiseEntryResolver> Function();
```

- [ ] **Step 7: Espera pelo índice**

```dart
// lib/features/coldigom/presentation/providers/await_coldigom_search_index.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/search/coldigom_search_index.dart';
import 'coldigom_catalog_providers.dart';

final _log = AppLogger.of('coldigom');

/// Prazo que o import de um link `?p=` espera o catálogo local (spec
/// fim-fonte-plpcg §4.3/§8). Cobre o arranque a frio, que baixa o dump
/// (~950 KB) e hidrata aos bocados; esgotado, o link cai em «link inválido».
const sharedPlaylistCatalogTimeout = Duration(seconds: 20);

/// O índice do catálogo **com conteúdo**, esperando até [timeout].
///
/// Já hidratado: devolve na hora, sem rede. Vazio: escuta
/// [coldigomSearchIndexProvider] (a escuta também acorda a hidratação) e pede
/// [ColdigomCatalogSyncNotifier.sync] — deduplicado; cobre o aparelho que
/// nunca sincronizou e o caminho sem Isar. O primeiro índice não vazio
/// responde; prazo esgotado devolve [ColdigomSearchIndex.empty].
///
/// [ref] tem de ser de um provider que não reconstrói durante a espera (ex.:
/// um `Provider` sem `watch`); a escuta é fechada no fim.
Future<ColdigomSearchIndex> awaitColdigomSearchIndex(
  Ref ref, {
  Duration timeout = sharedPlaylistCatalogTimeout,
}) async {
  final current = ref.read(coldigomSearchIndexProvider);
  if (!current.isEmpty) return current;

  final ready = Completer<ColdigomSearchIndex>();
  final subscription = ref.listen<ColdigomSearchIndex>(
    coldigomSearchIndexProvider,
    (_, next) {
      if (!next.isEmpty && !ready.isCompleted) ready.complete(next);
    },
    fireImmediately: true,
  );
  final syncNotifier = ref.read(coldigomCatalogSyncProvider.notifier);
  unawaited(
    syncNotifier.sync().then<void>(
      (_) {},
      onError: (Object e) =>
          _log.warn('sync do catálogo para o import falhou', e),
    ),
  );
  try {
    return await ready.future.timeout(
      timeout,
      onTimeout: () {
        _log.warn(
          'catálogo ainda vazio após ${timeout.inMilliseconds} ms — '
          'import sem índice',
        );
        return ColdigomSearchIndex.empty;
      },
    );
  } finally {
    subscription.close();
  }
}
```

- [ ] **Step 8: Espera pelos favoritos**

No fim de `lib/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart` (o ficheiro já importa `flutter/foundation.dart` e `flutter_riverpod`):

```dart

/// Prazo para os favoritos no import de um link por praise (spec
/// fim-fonte-plpcg §4.3).
const favoriteRankImportTimeout = Duration(seconds: 5);

/// `kindId → posição` **esperando** os favoritos carregarem — para quem lê
/// uma vez só, fora de um `build` (o import de um link por praise).
///
/// [favoriteMaterialKindRankProvider] é vazio enquanto a sessão restaura; num
/// deep link de arranque a frio o import leria «sem favoritos» e gravaria o
/// PDF principal mesmo para quem os tem. Deslogado: [MaterialKindPrefs.empty]
/// → `{}`. Erro ou prazo esgotado: `{}` — o import segue com o fallback fixo
/// de `preferredMaterialForGroup`.
Future<Map<String, int>> awaitFavoriteMaterialKindRank(
  Ref ref, {
  Duration timeout = favoriteRankImportTimeout,
}) async {
  try {
    final prefs = await ref
        .read(materialKindPrefsProvider.future)
        .timeout(timeout);
    return prefs.rank;
  } on Object catch (e) {
    debugPrint('[material-kind-prefs] favoritos indisponíveis no import: $e');
    return const {};
  }
}
```

- [ ] **Step 9: Escolha por praise**

```dart
// lib/features/playlists/presentation/utils/preferred_entry_for_praise.dart
import '../../../catalog/presentation/utils/preferred_material_for_group.dart';
import '../../../coldigom/domain/search/coldigom_search_index.dart';
import '../../domain/entities/playlist_entry.dart';

/// Entrada que o import de um link por praise grava para [praiseShortId]
/// (spec fim-fonte-plpcg §4.3). O material vem de [preferredMaterialForGroup]
/// com o [rank] de favoritos — a mesma escolha do «+» do card. `null` quando
/// o token não está no [index] ou o praise não tem nada adicionável (ex.: só
/// cifra ou só YouTube).
PlaylistEntry? preferredEntryForPraise(
  ColdigomSearchIndex index,
  String praiseShortId, {
  Map<String, int> rank = const {},
}) {
  final group = index.groupByShortId(praiseShortId);
  if (group == null) return null;
  final material = preferredMaterialForGroup(group, rank: rank);
  if (material == null) return null;
  return PlaylistEntry(id: material.id, kind: material.kind);
}
```

- [ ] **Step 10: Provider do resolvedor**

```dart
// lib/features/playlists/presentation/providers/praise_entry_resolver_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../coldigom/presentation/providers/await_coldigom_search_index.dart';
import '../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../domain/ports/praise_entry_resolver.dart';
import '../utils/preferred_entry_for_praise.dart';

final _log = AppLogger.of('playlists');

/// Import de link por praise (spec fim-fonte-plpcg §4.3): espera o índice
/// ([awaitColdigomSearchIndex], prazo [sharedPlaylistCatalogTimeout]) e os
/// favoritos ([awaitFavoriteMaterialKindRank]) em paralelo, e resolve cada
/// token por [preferredEntryForPraise]. Token sem entrada vira log.
///
/// Sem `watch` de propósito: o `ref` fica estável durante a espera.
final praiseEntryResolverLoaderProvider = Provider<PraiseEntryResolverLoader>((
  ref,
) {
  return () async {
    final (index, rank) = await (
      awaitColdigomSearchIndex(ref),
      awaitFavoriteMaterialKindRank(ref),
    ).wait;
    return (praiseShortId) {
      final entry = preferredEntryForPraise(index, praiseShortId, rank: rank);
      if (entry == null) {
        _log.warn('praise $praiseShortId sem entrada no catálogo — ignorado');
      }
      return entry;
    };
  };
});
```

- [ ] **Step 11: Correr e ver passar**

Run: `flutter test test/unit/features/playlists/preferred_entry_for_praise_test.dart test/unit/features/coldigom/await_coldigom_search_index_test.dart test/unit/features/material_kind_prefs/ test/unit/features/playlists/praise_entry_resolver_provider_test.dart && flutter analyze`
Expected: PASS; analyze sem issues.

- [ ] **Step 12: Commit**

```bash
git add lib/features/playlists/domain/ports/praise_entry_resolver.dart lib/features/coldigom/presentation/providers/await_coldigom_search_index.dart lib/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart lib/features/playlists/presentation/utils/preferred_entry_for_praise.dart lib/features/playlists/presentation/providers/praise_entry_resolver_provider.dart test/unit/features/playlists/preferred_entry_for_praise_test.dart test/unit/features/coldigom/await_coldigom_search_index_test.dart test/unit/features/material_kind_prefs/await_favorite_material_kind_rank_test.dart test/unit/features/playlists/praise_entry_resolver_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(share): resolvedor do import por praise (índice + favoritos)

awaitColdigomSearchIndex espera o índice com prazo de 20 s e pede sync;
awaitFavoriteMaterialKindRank espera os favoritos (5 s); a escolha usa o
preferredMaterialForGroup do «+» do card. Ainda sem chamador.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Importar por praise + links antigos avisam

Troca atómica do formato de import. `PlaylistShareParams` muda de forma, e por isso o parser, o use case, o deep link, a tela «Importar lista» e os testes deles mudam juntos.

**Files:**
- Modify: `lib/core/utils/playlist_share_url_builder.dart` (substituir o ficheiro inteiro)
- Modify: `lib/core/utils/url_sync_params.dart:20-21, 33-42`
- Create: `lib/features/playlists/domain/exceptions/legacy_share_link_exception.dart`
- Modify: `lib/features/playlists/domain/usecases/import_shared_playlist_from_url.dart` (substituir o ficheiro inteiro)
- Modify: `lib/features/playlists/data/providers/playlist_providers.dart`
- Modify: `lib/features/app_shell/domain/usecases/sync_deep_link_state.dart`
- Modify: `lib/features/app_shell/presentation/widgets/deep_link_listener.dart:111-133`
- Modify: `lib/features/app_shell/presentation/utils/deep_link_initial_uri.dart:9-14`
- Modify: `lib/features/playlists/presentation/pages/playlists_screen.dart:145-149`
- Modify: `lib/features/playlists/presentation/providers/playlists_provider.dart:512-519`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados)
- Delete: `lib/features/playlists/domain/ports/short_id_resolver.dart`, `lib/features/catalog/presentation/providers/pdf_ids_by_short_id_provider.dart`, `test/unit/features/catalog/pdf_ids_by_short_id_provider_test.dart`, `test/unit/core/playlist_share_url_builder_test.dart`
- Test: `test/unit/core/praise_share_url_test.dart` (acrescentar), `test/unit/features/playlists/import_shared_playlist_from_url_test.dart` (reescrito), `test/unit/features/app_shell/sync_deep_link_state_test.dart` (novo `main`), `test/unit/features/playlists/playlists_provider_import_activates_test.dart` (reescrito), `test/widget/features/playlists/import_playlist_dialog_test.dart` (reescrito), `test/widget/features/playlists/playlists_screen_test.dart` (3 testes), `test/widget/features/app_shell/deep_link_listener_test.dart` (edições), `test/widget/features/app_shell/deep_link_listener_live_test.dart` (edições)

**Interfaces:**
- Consumes: Tarefa 1 (`isPraiseShortId`, `decodePraiseShareIds`, `buildPraiseShareLocation`, `buildPraiseShareUrl`, `UrlSyncParams.praiseItems`); Tarefa 3 (`PraiseEntryResolver`, `PraiseEntryResolverLoader`, `praiseEntryResolverLoaderProvider`).
- Produces:
  - `class PlaylistShareParams { const PlaylistShareParams({required String shareName, required List<String> praiseShortIds}); const PlaylistShareParams.legacy(); final String shareName; final List<String> praiseShortIds; final bool isLegacy; bool get hasMaterial; }`
  - `const Set<String> legacyPlaylistShareParams`
  - `PlaylistShareParams? parsePlaylistShareParams(Uri)`, `Uri stripPlaylistShareParams(Uri)` e `PlaylistShareParams? extractShareParamsFromUserInput(String)`, com os mesmos nomes de hoje
  - `class LegacyShareLinkException implements Exception`
  - `ImportSharedPlaylistFromUrl(PlaylistRepository, {required PraiseEntryResolverLoader loadPraiseEntryResolver})`
  - `SyncDeepLinkOutcome.legacy` e `SyncDeepLinkResult.legacy`
  - string `playlistShareLegacyLinkUnsupported`
- Saem: `ShortIdResolver`, `shortIdResolverProvider`, `pdfIdsByShortIdProvider`, `isShortId`, `encodeShortShareIds`, `decodeShortShareIds`, `buildShortPlaylistShareLocation`/`Url`, `encodeShareItems`, `decodeShareItems`, `buildPlaylistShareLocation`, `buildPlaylistShareUrl`, `buildPlaylistShareUrlFromEntries`, `parsePdfIdsFromSharePdfs`, `parseAudioIdsFromShareAudios`, `PlaylistShareParams.isShortFormat`/`entries`/`sharePdfs`/`shareAudios`/`shareItems`/`shortIds`.

- [ ] **Step 1: Testes do parser (acrescentar a `test/unit/core/praise_share_url_test.dart`)**

Dentro de `main()`, depois do grupo `buildPraiseShareUrl`:

```dart
  group('parsePlaylistShareParams', () {
    test('p + n → tokens normalizados, na ordem, e nome decodificado', () {
      final params = parsePlaylistShareParams(
        Uri.parse('https://v2.plpcg.com/?p=0A1-fff--zz-0a1&n=Culto%20de%20domingo'),
      )!;
      expect(params.isLegacy, isFalse);
      expect(params.praiseShortIds, ['0a1', 'fff', '0a1']);
      expect(params.shareName, 'Culto de domingo');
      expect(params.hasMaterial, isTrue);
    });

    test('p sem token válido é link sem material (aviso, D.6)', () {
      final params = parsePlaylistShareParams(Uri.parse('/?p=zz-12&n=X'))!;
      expect(params.isLegacy, isFalse);
      expect(params.hasMaterial, isFalse);
    });

    test('p sem n é link com nome vazio', () {
      final params = parsePlaylistShareParams(Uri.parse('/?p=0a1'))!;
      expect(params.shareName, '');
      expect(params.praiseShortIds, ['0a1']);
    });

    test('p vence params antigos na mesma URL', () {
      final params = parsePlaylistShareParams(
        Uri.parse('/?p=0a1&n=X&s=1a2f&sharename=Y'),
      )!;
      expect(params.isLegacy, isFalse);
      expect(params.praiseShortIds, ['0a1']);
    });

    test('cada param antigo, sem p, é link antigo', () {
      for (final query in [
        's=1a2f-0000&n=Culto',
        'sharepdfs=a',
        'shareitems=p%3Aa',
        'shareaudios=a',
        'sharename=Ensaio',
      ]) {
        final params = parsePlaylistShareParams(Uri.parse('/?$query'));
        expect(params?.isLegacy, isTrue, reason: query);
        expect(params?.hasMaterial, isFalse, reason: query);
      }
    });

    test('esquema plpcg:/// antigo também é link antigo', () {
      expect(
        parsePlaylistShareParams(Uri.parse('plpcg:///?s=1a2f&n=Culto'))?.isLegacy,
        isTrue,
      );
    });

    test('n sozinho ou URL comum não é link de lista', () {
      expect(parsePlaylistShareParams(Uri.parse('/?n=Culto')), isNull);
      expect(parsePlaylistShareParams(Uri.parse('/?pesquisa=aleluia')), isNull);
      expect(parsePlaylistShareParams(Uri.parse('/')), isNull);
    });

    test('não lança com "%" malformado noutro param', () {
      final params = parsePlaylistShareParams(
        Uri.parse('/?p=0a1&n=X&junk=%E0%A4%A'),
      );
      expect(params?.praiseShortIds, ['0a1']);
    });
  });

  group('stripPlaylistShareParams', () {
    test('remove p, n e todos os antigos; preserva o resto', () {
      final stripped = stripPlaylistShareParams(
        Uri.parse(
          '/?pesquisa=x&p=0a1&n=Y&s=1&sharepdfs=a&shareitems=b'
          '&shareaudios=c&sharename=d',
        ),
      );
      expect(stripped.queryParameters, {'pesquisa': 'x'});
    });

    test('URL só com share fica sem query', () {
      expect(
        stripPlaylistShareParams(Uri.parse('/?p=0a1&n=Y')).queryParameters,
        isEmpty,
      );
    });

    test('não lança com "%" malformado', () {
      expect(
        stripPlaylistShareParams(
          Uri.parse('/?p=0a1&junk=%E0%A4%A'),
        ).queryParameters,
        isEmpty,
      );
    });
  });

  group('extractShareParamsFromUserInput', () {
    test('aceita URL completa', () {
      expect(
        extractShareParamsFromUserInput(
          'https://v2.plpcg.com/?p=0a1-fff&n=Ensaio',
        )?.praiseShortIds,
        ['0a1', 'fff'],
      );
    });

    test('aceita query crua, com ou sem "?"', () {
      expect(
        extractShareParamsFromUserInput('p=0a1&n=Ensaio')?.praiseShortIds,
        ['0a1'],
      );
      expect(
        extractShareParamsFromUserInput('?p=0a1&n=Ensaio')?.praiseShortIds,
        ['0a1'],
      );
    });

    test('aceita texto com prefixo antes do "?"', () {
      final params = extractShareParamsFromUserInput(
        'abre isto: v2.plpcg.com/?p=0a1&n=Ensaio',
      );
      expect(params?.praiseShortIds, ['0a1']);
      expect(params?.shareName, 'Ensaio');
    });

    test('link antigo colado devolve params antigos', () {
      expect(
        extractShareParamsFromUserInput(
          'https://plpcg.com/?s=1a2f-0000&n=Culto',
        )?.isLegacy,
        isTrue,
      );
      expect(
        extractShareParamsFromUserInput('sharepdfs=a&sharename=X')?.isLegacy,
        isTrue,
      );
    });

    test('p sem token válido devolve params sem material (aviso)', () {
      final params = extractShareParamsFromUserInput(
        'https://v2.plpcg.com/?p=zz&n=X',
      );
      expect(params, isNotNull);
      expect(params!.isLegacy, isFalse);
      expect(params.hasMaterial, isFalse);
    });

    test('input que não é link de lista → null', () {
      expect(extractShareParamsFromUserInput('https://example.com'), isNull);
      expect(extractShareParamsFromUserInput('   '), isNull);
    });
  });
```

- [ ] **Step 2: Teste do use case (substituir o ficheiro inteiro)**

```dart
// test/unit/features/playlists/import_shared_playlist_from_url_test.dart
import 'dart:async';
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/exceptions/invalid_share_playlist_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/legacy_share_link_exception.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

const _pdfA = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _audio1 = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);
const _pdfB = PlaylistEntry(id: 'pdf-b', kind: MaterialKind.pdf);

PlaylistShareParams _link(String nome, List<String> tokens) =>
    PlaylistShareParams(shareName: nome, praiseShortIds: tokens);

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl playlistRepository;
  late ImportSharedPlaylistFromUrl useCase;
  const catalog = {'0a1': _pdfA, '0c3': _audio1, 'fff': _pdfB};
  var loaderCalls = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_playlist_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    loaderCalls = 0;
    useCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      loadPraiseEntryResolver: () async {
        loaderCalls++;
        return (shortId) => catalog[shortId];
      },
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cria lista salva com uma entrada por token, na ordem, com repetição', () async {
    final result = await useCase(params: _link('Culto', ['0a1', '0c3', '0a1']));

    expect(result.alreadyExisted, isFalse);
    final saved = await playlistRepository.getById(result.playlist.playlistId);
    expect(saved!.nome, 'Culto');
    expect(saved.salva, isTrue);
    expect(saved.entries, const [_pdfA, _audio1, _pdfA]);
  });

  test('token desconhecido é saltado e o resto importa', () async {
    final result = await useCase(params: _link('Culto', ['abc', 'fff']));
    final saved = await playlistRepository.getById(result.playlist.playlistId);
    expect(saved!.entries, const [_pdfB]);
  });

  test('nenhum token resolvido → InvalidSharePlaylistException', () async {
    await expectLater(
      useCase(params: _link('Culto', ['abc'])),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
    expect(await playlistRepository.getAll(), isEmpty);
  });

  test('sem token ou com nome em branco lança sem acordar o resolver', () async {
    await expectLater(
      useCase(params: _link('Culto', const [])),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
    await expectLater(
      useCase(params: _link('  ', ['0a1'])),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
    expect(loaderCalls, 0);
  });

  test('link antigo → LegacyShareLinkException sem acordar o resolver', () async {
    await expectLater(
      useCase(params: const PlaylistShareParams.legacy()),
      throwsA(isA<LegacyShareLinkException>()),
    );
    expect(loaderCalls, 0);
  });

  test('o resolver é aguardado (deep link antes do catálogo)', () async {
    final completer = Completer<PraiseEntryResolver>();
    final lateUseCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      loadPraiseEntryResolver: () => completer.future,
    );
    final future = lateUseCase(params: _link('Culto', ['0a1']));
    completer.complete((shortId) => catalog[shortId]);
    expect((await future).playlist.entries, const [_pdfA]);
  });

  test('catálogo que não chegou no prazo → InvalidSharePlaylistException', () async {
    final emptyUseCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      loadPraiseEntryResolver: () async => (_) => null,
    );
    await expectLater(
      emptyUseCase(params: _link('Culto', ['0a1'])),
      throwsA(isA<InvalidSharePlaylistException>()),
    );
  });

  group('dedupe por conteúdo (spec C.2)', () {
    test('lista salva com o mesmo conteúdo — alreadyExisted, nenhuma create', () async {
      final first = await useCase(params: _link('Original', ['0a1', 'fff']));
      expect(first.alreadyExisted, isFalse);

      final second = await useCase(params: _link('Outro nome', ['0a1', 'fff']));

      expect(second.alreadyExisted, isTrue);
      expect(second.playlist.playlistId, first.playlist.playlistId);
      expect(second.playlist.nome, 'Original');
      expect(await playlistRepository.getAll(), hasLength(1));
    });

    test('a ordem importa — não deduplica', () async {
      await useCase(params: _link('Ordem 1', ['0a1', 'fff']));
      final result = await useCase(params: _link('Ordem 2', ['fff', '0a1']));
      expect(result.alreadyExisted, isFalse);
      expect(await playlistRepository.getAll(), hasLength(2));
    });

    test('rascunho com o mesmo conteúdo não conta', () async {
      await playlistRepository.create(
        nome: 'Rascunho',
        entries: const [_pdfA, _pdfB],
        salva: false,
      );
      final result = await useCase(params: _link('Importada', ['0a1', 'fff']));
      expect(result.alreadyExisted, isFalse);
      expect(await playlistRepository.getAll(), hasLength(2));
    });

    test('lista salva apagada (tombstone) não conta', () async {
      final id = await playlistRepository.create(
        nome: 'Apagada',
        entries: const [_pdfA, _pdfB],
        salva: true,
      );
      await playlistRepository.update(id, deletedAt: DateTime.now());

      final result = await useCase(params: _link('Importada', ['0a1', 'fff']));
      expect(result.alreadyExisted, isFalse);
    });

    // Fix round 2 (Minor): exclusão adiada (C11) ainda sem `deletedAt`.
    test('lista pendente de exclusão (excludePlaylistId) não conta', () async {
      final id = await playlistRepository.create(
        nome: 'Vai sair',
        entries: const [_pdfA, _pdfB],
        salva: true,
      );
      final result = await useCase(
        params: _link('Importada', ['0a1', 'fff']),
        excludePlaylistId: id,
      );
      expect(result.alreadyExisted, isFalse);
      expect(result.playlist.playlistId, isNot(id));
    });
  });
}
```

- [ ] **Step 3: `sync_deep_link_state_test` (manter a classe `_ThrowingPlaylistRepository` das linhas 15–101 como está; substituir os imports e o `main`)**

Imports (topo do ficheiro):

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/app_shell/domain/usecases/sync_deep_link_state.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
```

Novo `main` (e as duas constantes antes dele):

```dart
const _pdfA = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _audio1 = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);

PraiseEntryResolverLoader _catalog(Map<String, PlaylistEntry> entries) =>
    () async => (shortId) => entries[shortId];

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl playlistRepository;
  late SyncDeepLinkState useCase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_deep_link_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = SyncDeepLinkState(
      ImportSharedPlaylistFromUrl(
        playlistRepository,
        loadPraiseEntryResolver: _catalog({'0a1': _pdfA, '0c3': _audio1}),
      ),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('skipped quando a URI não tem link de lista', () async {
    expect(
      (await useCase(uri: Uri.parse('/'))).outcome,
      SyncDeepLinkOutcome.skipped,
    );
    expect(
      (await useCase(uri: Uri.parse('/?n=Culto'))).outcome,
      SyncDeepLinkOutcome.skipped,
    );
  });

  test('success com ?p=&n=, na ordem e com repetição', () async {
    final result = await useCase(
      uri: Uri.parse('https://v2.plpcg.com/?p=0a1-0c3-0a1&n=Culto'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);
    expect(result.playlistId, isNotEmpty);

    final saved = isar.playlists.where().findAll().single;
    expect(saved.nome, 'Culto');
    expect(saved.items, ['pdf-a', 'aud-1', 'pdf-a']);
    expect(saved.itemKinds, ['pdf', 'audio', 'pdf']);
  });

  test('aceita queryParams map', () async {
    final result = await useCase(queryParams: const {'p': '0a1', 'n': 'Lista'});
    expect(result.outcome, SyncDeepLinkOutcome.success);
  });

  test('invalid quando o nome é só espaço', () async {
    final result = await useCase(uri: Uri.parse('/?p=0a1&n=%20%20'));
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('invalid quando p não tem token válido', () async {
    final result = await useCase(uri: Uri.parse('/?p=zz&n=Nome'));
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('invalid quando nenhum token é conhecido', () async {
    final result = await useCase(uri: Uri.parse('/?p=abc&n=Nome'));
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('legacy para cada formato antigo, sem gravar nada', () async {
    for (final uri in [
      '/?s=1a2f-0000&n=Culto',
      '/?sharepdfs=a&sharename=Ensaio',
      '/?shareitems=p%3Aa&sharename=Ensaio',
      'plpcg:///?s=1a2f&n=Culto',
    ]) {
      final result = await useCase(uri: Uri.parse(uri));
      expect(result.outcome, SyncDeepLinkOutcome.legacy, reason: uri);
    }
    expect(isar.playlists.where().findAll(), isEmpty);
  });

  test('failed com o StorageUnavailableException quando o repositório lança', () async {
    final failingUseCase = SyncDeepLinkState(
      ImportSharedPlaylistFromUrl(
        _ThrowingPlaylistRepository(
          const StorageUnavailableException('playlists.insert'),
        ),
        loadPraiseEntryResolver: _catalog({'0a1': _pdfA}),
      ),
    );
    final result = await failingUseCase(uri: Uri.parse('/?p=0a1&n=Ensaio'));
    expect(result.outcome, SyncDeepLinkOutcome.failed);
    expect(result.reason, isA<StorageUnavailableException>());
  });

  test('alreadyExisted e o nome da lista existente quando o import dedupa', () async {
    final first = await useCase(uri: Uri.parse('/?p=0a1-0c3&n=Original'));
    expect(first.alreadyExisted, isFalse);

    final second = await useCase(uri: Uri.parse('/?p=0a1-0c3&n=Outro%20nome'));

    expect(second.outcome, SyncDeepLinkOutcome.success);
    expect(second.alreadyExisted, isTrue);
    expect(second.playlistId, first.playlistId);
    expect(second.nome, 'Original');
    expect(isar.playlists.where().findAll(), hasLength(1));
  });

  test('failed sem lançar quando o import falha com exceção genérica', () async {
    final failingUseCase = SyncDeepLinkState(
      ImportSharedPlaylistFromUrl(
        _ThrowingPlaylistRepository(StateError('boom')),
        loadPraiseEntryResolver: _catalog({'0a1': _pdfA}),
      ),
    );
    final result = await failingUseCase(uri: Uri.parse('/?p=0a1&n=Ensaio'));
    expect(result.outcome, SyncDeepLinkOutcome.failed);
    expect(result.reason, isA<StateError>());
  });
}
```

- [ ] **Step 4: `playlists_provider_import_activates_test` (substituir o ficheiro inteiro)**

```dart
// test/unit/features/playlists/playlists_provider_import_activates_test.dart
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/praise_entry_resolver_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';
import '../../../support/test_overrides.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _pdfA = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _catalog = {
  '0a1': _pdfA,
  '0c3': PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
};

/// D6 — importar por URL torna a importada a lista ativa pelo mesmo caminho
/// do «Editar por aqui»: a lista que era ativa continua salva.
void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playlist_import_act_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: 'p-anterior',
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer container({PraiseEntryResolverLoader? loader}) {
    return ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
        praiseEntryResolverLoaderProvider.overrideWithValue(
          loader ?? () async => (shortId) => _catalog[shortId],
        ),
      ],
    );
  }

  test('importar por URL ativa a importada e mantém a anterior', () async {
    await repository.create(
      nome: 'Anterior',
      pdfIds: const ['pdf-x'],
      playlistId: 'p-anterior',
      salva: true,
    );
    final c = container();
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();
    c.read(carouselFocusedKeyProvider.notifier).focus('pdf-x');

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            shareName: 'Importada',
            praiseShortIds: ['0a1', '0c3', '0a1'],
          ),
        );
    await _flushAsync();

    expect(imported, isNotNull);
    expect(c.read(activePlaylistIdProvider), imported);
    expect(c.read(activePlaylistProvider)?.items, ['pdf-a', 'aud-1', 'pdf-a']);
    expect((await repository.getById('p-anterior'))?.nome, 'Anterior');
    expect(c.read(carouselFocusedKeyProvider), isNull);
  });

  // Fix round 2 (Minor): a dedupe por conteúdo (spec C.2) não pode reaproveitar
  // uma lista na graça de uma exclusão adiada (C11).
  test('importar com o mesmo conteúdo de uma lista pendente de exclusão cria '
      'nova, não reaproveita a pendente', () async {
    await repository.create(
      nome: 'Vai sair (exclusão adiada, ainda não comitou)',
      entries: const [_pdfA],
      playlistId: 'p1',
      salva: true,
    );
    final c = container();
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    c.read(playlistsProvider.notifier).deleteWithUndo('p1');

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            shareName: 'Reimportada',
            praiseShortIds: ['0a1'],
          ),
        );

    expect(imported, isNotNull);
    expect(imported, isNot('p1'));
    expect((await repository.getById(imported!))?.nome, 'Reimportada');
  });

  // Fix round final (#3): o resolver espera o catálogo — se ele falhar, o
  // import não derruba quem chamou; a tela trata o `null`.
  test('resolver que falha devolve null sem lançar', () async {
    final c = container(
      loader: () async => throw StateError('catálogo indisponível'),
    );
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await _flushAsync();

    final imported = await c
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          params: const PlaylistShareParams(
            shareName: 'X',
            praiseShortIds: ['0a1'],
          ),
        );

    expect(imported, isNull);
  });
}
```

- [ ] **Step 5: `import_playlist_dialog_test` (substituir o ficheiro inteiro)**

```dart
// test/widget/features/playlists/import_playlist_dialog_test.dart
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/presentation/widgets/import_playlist_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlaylistShareParams? result;

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showImportPlaylistDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> submit(WidgetTester tester, String text) async {
    result = null;
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
  }

  testWidgets('link por praise fecha o diálogo com os tokens', (tester) async {
    await submit(tester, 'https://v2.plpcg.com/?p=0a1-fff&n=Ensaio');

    expect(find.text('open'), findsOneWidget);
    expect(result?.praiseShortIds, ['0a1', 'fff']);
    expect(result?.shareName, 'Ensaio');
  });

  testWidgets('link antigo fecha o diálogo com params antigos', (tester) async {
    await submit(tester, 'https://plpcg.com/?sharepdfs=a%2Cb&sharename=Ensaio');

    expect(find.text('open'), findsOneWidget);
    expect(result?.isLegacy, isTrue);
  });

  testWidgets('exibe erro para URL que não é link de lista', (tester) async {
    await submit(tester, 'https://example.com');

    expect(find.textContaining('Link inválido'), findsOneWidget);
    expect(result, isNull);
  });
}
```

- [ ] **Step 6: `playlists_screen_test` — trocar os três testes de import**

Em `test/widget/features/playlists/playlists_screen_test.dart`, apagar os três `testWidgets` que começam em `'importar via FAB dispara importSharedFromUrl'`, `'importar por URL não pede confirmação'` e `'importar URL legada (sem shareitems) segue funcionando'`, do primeiro `testWidgets(` até ao `});` que fecha o terceiro, logo antes de `Widget buildWithSync(`. No lugar deles:

```dart
  Future<FakePlaylistsNotifier> pasteInImportDialog(
    WidgetTester tester,
    String text,
  ) async {
    final notifier = FakePlaylistsNotifier(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(_LoggedOutAuth.new),
          playlistsProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const PlaylistsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('importar via FAB leva os tokens do link ao notifier', (
    tester,
  ) async {
    final notifier = await pasteInImportDialog(
      tester,
      'https://v2.plpcg.com/?p=0a1-fff-0a1&n=Teste',
    );

    expect(notifier.lastImport?.praiseShortIds, ['0a1', 'fff', '0a1']);
    expect(notifier.lastImport?.shareName, 'Teste');
    expect(find.text('Lista importada'), findsOneWidget);
  });

  // D6: importar cria uma lista nova e a torna ativa — a anterior continua
  // salva, então não há "substituição" a confirmar (paridade com o deep link).
  testWidgets('importar por URL não pede confirmação', (tester) async {
    final notifier = await pasteInImportDialog(tester, 'p=0a1&n=Teste');

    expect(find.text('Substituir seleção?'), findsNothing);
    expect(find.text('Confirmar'), findsNothing);
    expect(notifier.lastImport?.shareName, 'Teste');
    expect(find.text('Lista importada'), findsOneWidget);
  });

  // Review Focus 4: o PWA do iOS nunca abre o link no app — o caminho é colar.
  for (final legacy in [
    'sharepdfs=x&sharename=Teste',
    'https://plpcg.com/?s=1a2f-0000&n=Culto',
  ]) {
    testWidgets('link antigo colado avisa e não importa ($legacy)', (
      tester,
    ) async {
      final notifier = await pasteInImportDialog(tester, legacy);

      expect(notifier.lastImport, isNull);
      expect(
        find.text(
          'Este link é de uma versão antiga e já não abre. '
          'Peça um link novo à pessoa.',
        ),
        findsOneWidget,
      );
      expect(find.text('Lista importada'), findsNothing);
    });
  }
```

- [ ] **Step 7: `deep_link_listener_test` — edições**

Em `test/widget/features/app_shell/deep_link_listener_test.dart`:

1. No `setUpAll`, trocar `resolveShortIds: () async => const {},` por `loadPraiseEntryResolver: () async => (_) => null,`.
2. Trocar todas as ocorrências de `Uri.parse('/?sharepdfs=a&sharename=Teste')` e `Uri.parse('/?sharepdfs=x&sharename=Teste')` por `Uri.parse('/?p=0a1&n=Teste')`, e a ocorrência `final uri = Uri.parse('/?sharepdfs=a&sharename=Teste');` (duas vezes) por `final uri = Uri.parse('/?p=0a1&n=Teste');`. Confira com `grep -n "sharepdfs" test/widget/features/app_shell/deep_link_listener_test.dart`, que deve ficar só com a linha da lista de links antigos do passo 3.
3. Apagar o `testWidgets('deep link só com sharename avisa em vez de sumir (D.6)', …)` inteiro, do `testWidgets(` até ao `});` que o fecha, logo antes de `testWidgets(\n    'sincronização lançando PlaylistNotFoundException`. No lugar dele:

```dart
  /// Listener com o `SyncDeepLinkState` de verdade — a URL passa pelo parser
  /// e pelo use case reais.
  Future<GoRouter> pumpRealSync(WidgetTester tester) async {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          deepLinkHandlingEnabledProvider.overrideWithValue(true),
          syncDeepLinkStateProvider.overrideWithValue(
            SyncDeepLinkState(importUseCase),
          ),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        ],
        child: DeepLinkListener(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('?p= sem token válido avisa em vez de sumir (D.6)', (
    tester,
  ) async {
    await pumpRealSync(tester);
    final state = tester.state<DeepLinkListenerState>(
      find.byType(DeepLinkListener),
    );
    await state.handleUriForTest(Uri.parse('/?p=zz&n=Ensaio'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Link inválido'), findsOneWidget);
  });

  // Review Focus 5: inclui o esquema custom antigo, que o app nativo recebe.
  for (final legacy in [
    '/?sharename=Ensaio',
    '/?sharepdfs=a&sharename=Teste',
    '/?s=1a2f-0000&n=Culto',
    'plpcg:///?s=1a2f&n=Culto',
  ]) {
    testWidgets('link antigo $legacy avisa e limpa a URL', (tester) async {
      final router = await pumpRealSync(tester);
      final state = tester.state<DeepLinkListenerState>(
        find.byType(DeepLinkListener),
      );
      await state.handleUriForTest(Uri.parse(legacy));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Este link é de uma versão antiga e já não abre. '
          'Peça um link novo à pessoa.',
        ),
        findsOneWidget,
      );
      expect(router.state.uri.path, RoutePaths.home);
      expect(router.state.uri.queryParameters, isEmpty);
    });
  }
```

- [ ] **Step 8: `deep_link_listener_live_test` — edições**

Em `test/widget/features/app_shell/deep_link_listener_live_test.dart`:
1. No `setUpAll`, trocar `resolveShortIds: () async => const {},` por `loadPraiseEntryResolver: () async => (_) => null,`.
2. No último teste, trocar o título por `'URL de share (?p=&n=) continua no fluxo de import, não navega para /ao-vivo'` e a URI por `Uri.parse('https://v2.plpcg.com/?p=0a1&n=x')`.

- [ ] **Step 9: Correr e ver falhar**

Run: `flutter test test/unit/core/praise_share_url_test.dart test/unit/features/playlists/import_shared_playlist_from_url_test.dart test/unit/features/app_shell/sync_deep_link_state_test.dart`
Expected: FAIL (compilação) — `PlaylistShareParams` sem `praiseShortIds`; `LegacyShareLinkException` e `SyncDeepLinkOutcome.legacy` não existem.

- [ ] **Step 10: Builder (substituir o ficheiro inteiro)**

```dart
// lib/core/utils/playlist_share_url_builder.dart
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/safe_query_parameters.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// `shortId` de praise válido (spec fim-fonte-plpcg §4.1): **string** hex
/// minúscula de 3 a 8 caracteres. Nunca é número — `"000"` é um id.
///
/// Delega em `normalizePraiseShortId` (plano 1, `praise_short_id.dart`) — uma
/// fonte só para o padrão `[0-9a-f]{3,8}`.
bool isPraiseShortId(Object? value) =>
    value is String && normalizePraiseShortId(value) == value;

/// Lê o param `p`: `trim`, maiúsculas viram minúsculas, token fora do padrão
/// é ignorado; ordem e repetições ficam (a lista pode repetir um louvor).
List<String> decodePraiseShareIds(String raw) => [
  for (final part in raw.split('-'))
    if (normalizePraiseShortId(part) case final id?) id,
];

/// Monta `/?p=…&n=…` (spec fim-fonte-plpcg §4.1).
///
/// Lança [ArgumentError] com [praiseShortIds] vazio, com um token que não é
/// [isPraiseShortId] (quem gera valida antes — aqui seria bug) ou com
/// [shareName] em branco.
String buildPraiseShareLocation({
  required List<String> praiseShortIds,
  required String shareName,
}) {
  if (praiseShortIds.isEmpty) {
    throw ArgumentError.value(
      praiseShortIds,
      'praiseShortIds',
      'must not be empty',
    );
  }
  final invalid = [
    for (final id in praiseShortIds)
      if (!isPraiseShortId(id)) id,
  ];
  if (invalid.isNotEmpty) {
    throw ArgumentError.value(invalid, 'praiseShortIds', 'invalid shortId');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }
  return '${RoutePaths.home}'
      '?${UrlSyncParams.praiseItems}=${praiseShortIds.join('-')}'
      '&${UrlSyncParams.shortName}=${Uri.encodeComponent(shareName)}';
}

/// URL absoluta do link por praise ([origin] + [buildPraiseShareLocation]).
String buildPraiseShareUrl({
  required String origin,
  required List<String> praiseShortIds,
  required String shareName,
}) {
  final normalizedOrigin = origin.endsWith('/')
      ? origin.substring(0, origin.length - 1)
      : origin;
  return '$normalizedOrigin'
      '${buildPraiseShareLocation(praiseShortIds: praiseShortIds, shareName: shareName)}';
}

/// Params dos links de lista **anteriores** ao link por praise (spec
/// fim-fonte-plpcg §4.4): o curto por material (`?s=`) e o longo
/// (`shareitems`/`sharepdfs`/`shareaudios`/`sharename`). Só são reconhecidos
/// para avisar e limpar a URL — nenhum deles abre mais.
const Set<String> legacyPlaylistShareParams = {
  UrlSyncParams.shortItems,
  UrlSyncParams.shareItems,
  UrlSyncParams.sharePdfs,
  UrlSyncParams.shareAudios,
  UrlSyncParams.shareName,
};

/// Params de um link de lista (UC-07).
class PlaylistShareParams {
  /// Link por praise (`?p=…&n=…`). [praiseShortIds] já validados e minúsculos.
  const PlaylistShareParams({
    required this.shareName,
    required this.praiseShortIds,
  }) : isLegacy = false;

  /// Link de uma versão antiga (§4.4) — não importa nada.
  const PlaylistShareParams.legacy()
    : shareName = '',
      praiseShortIds = const [],
      isLegacy = true;

  /// Nome da lista (`n`).
  final String shareName;

  /// Tokens do `p`, na ordem, com repetições.
  final List<String> praiseShortIds;

  /// `true` quando a URL só tem params de link antigo.
  final bool isLegacy;

  /// Há o que importar. Um `p` sem token válido é link **inválido** (aviso),
  /// não «não é link».
  bool get hasMaterial => praiseShortIds.isNotEmpty;
}

/// Remove de [uri] os params de link de lista — `p`, `n` e os antigos.
Uri stripPlaylistShareParams(Uri uri) {
  final query = Map<String, String>.from(safeQueryParameters(uri))
    ..remove(UrlSyncParams.praiseItems)
    ..remove(UrlSyncParams.shortName)
    ..removeWhere((key, _) => legacyPlaylistShareParams.contains(key));
  if (query.isEmpty) {
    return uri.replace(queryParameters: const {});
  }
  return uri.replace(queryParameters: query);
}

/// Lê um link de lista em [uri].
///
/// - `p` presente → link por praise, mesmo sem token válido ou sem `n` (aí é
///   inválido e o import avisa — D.6 de 2026-09-13).
/// - sem `p`, com algum param antigo → [PlaylistShareParams.legacy].
/// - senão `null`: não é link de lista (todo link comum do app passa aqui;
///   `n` sozinho também não é).
///
/// Lê a query por [safeQueryParameters] — `%` malformado não lança.
PlaylistShareParams? parsePlaylistShareParams(Uri uri) {
  final query = safeQueryParameters(uri);
  final praiseRaw = query[UrlSyncParams.praiseItems];
  if (praiseRaw != null) {
    return PlaylistShareParams(
      shareName: query[UrlSyncParams.shortName] ?? '',
      praiseShortIds: decodePraiseShareIds(praiseRaw),
    );
  }
  if (query.keys.any(legacyPlaylistShareParams.contains)) {
    return const PlaylistShareParams.legacy();
  }
  return null;
}

/// Aceita URL completa, query crua ou texto colado com o link no meio
/// («Importar lista», UC-07).
///
/// Tenta três leituras (URL, query crua, trecho depois do `?`); a primeira
/// com material vence. Sem material em nenhuma, devolve o melhor recurso —
/// link antigo antes de um `p` sem token válido, porque a mensagem de link
/// antigo diz mais ao usuário — ou `null` se nada parece link de lista.
PlaylistShareParams? extractShareParamsFromUserInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  PlaylistShareParams? fallback;
  PlaylistShareParams? consider(PlaylistShareParams? params) {
    if (params == null) return null;
    if (params.hasMaterial) return params;
    final current = fallback;
    if (current == null || (params.isLegacy && !current.isLegacy)) {
      fallback = params;
    }
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasQuery) {
    final fromUri = consider(parsePlaylistShareParams(uri));
    if (fromUri != null) return fromUri;
  }

  final queryOnly = trimmed.startsWith('?') ? trimmed.substring(1) : trimmed;
  final fromQuery = consider(parsePlaylistShareParams(Uri(query: queryOnly)));
  if (fromQuery != null) return fromQuery;

  final questionIndex = trimmed.indexOf('?');
  if (questionIndex >= 0) {
    final fromFragment = consider(
      parsePlaylistShareParams(
        Uri(query: trimmed.substring(questionIndex + 1)),
      ),
    );
    if (fromFragment != null) return fromFragment;
  }

  return fallback;
}
```

- [ ] **Step 11: Docs dos params antigos**

Em `lib/core/utils/url_sync_params.dart`:
- antes de `static const String sharePdfs = 'sharepdfs';` pôr `/// Legado — link longo antigo; só reconhecido (spec fim-fonte-plpcg §4.4).`;
- antes de `static const String shareName = 'sharename';` pôr a mesma linha;
- trocar o doc de `shareAudios` por `/// Legado — CSV de audioIds do link longo antigo; só reconhecido.`;
- trocar o doc de `shareItems` (linhas 36–41) por `/// Legado — ordem tipada do link longo antigo (`shareitems`); só reconhecido.`

- [ ] **Step 12: Exceção de link antigo**

```dart
// lib/features/playlists/domain/exceptions/legacy_share_link_exception.dart

/// Link de lista de uma versão antiga (`?s=`, `sharepdfs`, `shareitems`,
/// `shareaudios`, `sharename` — spec fim-fonte-plpcg §4.4): não abre mais.
///
/// Lançada por `ImportSharedPlaylistFromUrl`; a UI mostra
/// `playlistShareLegacyLinkUnsupported`.
class LegacyShareLinkException implements Exception {
  const LegacyShareLinkException();

  @override
  String toString() => 'LegacyShareLinkException';
}
```

- [ ] **Step 13: Use case do import (substituir o ficheiro inteiro)**

```dart
// lib/features/playlists/domain/usecases/import_shared_playlist_from_url.dart
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../entities/saved_playlist.dart';
import '../exceptions/invalid_share_playlist_exception.dart';
import '../exceptions/legacy_share_link_exception.dart';
import '../ports/praise_entry_resolver.dart';
import '../repositories/playlist_repository.dart';
import '../utils/content_fingerprint.dart';

final _log = AppLogger.of('playlists');

/// Resultado de [ImportSharedPlaylistFromUrl.call] (D7, spec C.2).
class ImportResult {
  const ImportResult({required this.playlist, required this.alreadyExisted});

  /// A lista salva — nova, ou a já existente reaproveitada.
  final SavedPlaylist playlist;

  /// `true` quando já havia uma lista salva com o mesmo conteúdo: nenhuma
  /// lista nova foi criada, [playlist] é a existente.
  final bool alreadyExisted;
}

/// UC-07 — importar lista de um link por praise (spec fim-fonte-plpcg §4.3).
class ImportSharedPlaylistFromUrl {
  const ImportSharedPlaylistFromUrl(
    this._playlistRepository, {
    required this.loadPraiseEntryResolver,
  });

  final PlaylistRepository _playlistRepository;
  final PraiseEntryResolverLoader loadPraiseEntryResolver;

  /// Persiste a nova lista (ou reaproveita uma existente) e devolve o
  /// [ImportResult].
  ///
  /// Cada token do `p` vira a entrada que [loadPraiseEntryResolver] escolhe
  /// (favorito da conta, senão PDF principal → único áudio → primeiro
  /// adicionável). Token desconhecido ou praise sem material adicionável é
  /// saltado; repetições ficam. O material escolhido por quem enviou não
  /// viaja — o link é por louvor. Quem chama torna a lista ativa (D3).
  ///
  /// **Dedupe por conteúdo (spec C.2):** antes de criar, procura entre as
  /// listas salvas e não apagadas uma com o mesmo [contentFingerprint]
  /// (`kind:id` por entrada, na ordem — o nome do link não entra na conta).
  /// Se existir, não cria: devolve a existente com `alreadyExisted: true`.
  ///
  /// [excludePlaylistId] tira da dedupe a lista na graça de uma exclusão
  /// adiada (C11), que o repositório ainda não sabe apagada.
  ///
  /// Lança [LegacyShareLinkException] para link antigo (§4.4) e
  /// [InvalidSharePlaylistException] sem token, com nome em branco ou sem
  /// nenhum token resolvido — inclusive quando o catálogo não chegou no prazo
  /// (§8).
  Future<ImportResult> call({
    required PlaylistShareParams params,
    String? excludePlaylistId,
  }) async {
    if (params.isLegacy) throw const LegacyShareLinkException();
    final nome = params.shareName.trim();
    // Sem token ou sem nome nem vale acordar o resolver, que espera o catálogo.
    if (!params.hasMaterial || nome.isEmpty) {
      throw const InvalidSharePlaylistException();
    }

    final resolve = await loadPraiseEntryResolver();
    final entries = <PlaylistEntry>[
      for (final shortId in params.praiseShortIds) ?resolve(shortId),
    ];
    if (entries.isEmpty) throw const InvalidSharePlaylistException();
    final skipped = params.praiseShortIds.length - entries.length;
    if (skipped > 0) {
      _log.warn(
        'import: $skipped de ${params.praiseShortIds.length} louvores do '
        'link sem entrada — saltados',
      );
    }

    final fingerprint = contentFingerprint(entries);
    final saved = await _playlistRepository.getAll();
    for (final playlist in saved) {
      if (!playlist.salva || playlist.deletedAt != null) continue;
      if (playlist.playlistId == excludePlaylistId) continue;
      if (contentFingerprint(playlist.entries) == fingerprint) {
        return ImportResult(playlist: playlist, alreadyExisted: true);
      }
    }

    final now = DateTime.now();
    final playlistId = await _playlistRepository.create(
      nome: nome,
      entries: entries,
      salva: true,
      savedAt: now,
    );
    final created = await _playlistRepository.getById(playlistId);
    return ImportResult(playlist: created!, alreadyExisted: false);
  }
}
```

- [ ] **Step 14: Provider do import**

Em `lib/features/playlists/data/providers/playlist_providers.dart`:
- apagar os imports `../../../catalog/presentation/providers/louvores_manifest_provider.dart`, `../../../catalog/presentation/providers/pdf_ids_by_short_id_provider.dart` e `../../domain/ports/short_id_resolver.dart`;
- acrescentar `import '../../presentation/providers/praise_entry_resolver_provider.dart';`;
- trocar os blocos `shortIdResolverProvider` e `importSharedPlaylistFromUrlProvider` (fim do ficheiro) por:

```dart
/// UC-07 — importar lista de um link por praise (spec fim-fonte-plpcg §4.3).
final importSharedPlaylistFromUrlProvider =
    Provider<ImportSharedPlaylistFromUrl>((ref) {
      return ImportSharedPlaylistFromUrl(
        ref.watch(playlistRepositoryProvider),
        loadPraiseEntryResolver: ref.watch(praiseEntryResolverLoaderProvider),
      );
    });
```

- [ ] **Step 15: `SyncDeepLinkState` ganha o desfecho `legacy`**

Em `lib/features/app_shell/domain/usecases/sync_deep_link_state.dart`:
- acrescentar `import '../../../playlists/domain/exceptions/legacy_share_link_exception.dart';`;
- no enum `SyncDeepLinkOutcome`, entre `invalid` e `failed`:

```dart
  /// Link de uma versão antiga (`?s=`, `sharepdfs`… — spec fim-fonte-plpcg
  /// §4.4): nada importado; a UI avisa com `playlistShareLegacyLinkUnsupported`
  /// e limpa a URL.
  legacy,
```

- em `SyncDeepLinkResult`, depois de `static const invalid = …;`:

```dart
  static const legacy = SyncDeepLinkResult(
    outcome: SyncDeepLinkOutcome.legacy,
  );
```

- trocar o doc da classe `SyncDeepLinkState` («Detecta `s`+`n` (curto) ou `sharename` (longo) na URI…») por:

```dart
/// UC-14 — Sincronizar deep link de lista com o estado local (Fase 4.5).
///
/// Detecta `p` (link por praise) ou um param de link antigo na URI e delega a
/// [ImportSharedPlaylistFromUrl]. Sem UI — import automático (paridade PWA).
```

- no `try` de `call`, entre `on InvalidSharePlaylistException` e `on StorageUnavailableException`:

```dart
    } on LegacyShareLinkException {
      return SyncDeepLinkResult.legacy;
```

- [ ] **Step 16: Listener avisa link antigo**

Em `lib/features/app_shell/presentation/widgets/deep_link_listener.dart`, no `switch (result.outcome)`, depois do `case SyncDeepLinkOutcome.invalid:` (que termina em `_showSnackbar((l10n) => l10n.playlistImportInvalidUrl);`), acrescentar:

```dart
        case SyncDeepLinkOutcome.legacy:
          _markProcessed(fingerprint);
          _navigateAfterImport(sanitizedUri);
          _showSnackbar((l10n) => l10n.playlistShareLegacyLinkUnsupported);
```

Em `lib/features/app_shell/presentation/utils/deep_link_initial_uri.dart`, trocar a linha 9 do doc («Navegação direta com `/?sharepdfs=&sharename=` não usa esquema `plpcg://`;») por:

```dart
/// Navegação direta com `/?p=…&n=…` (ou um link antigo, para o aviso) não usa
/// esquema `plpcg://`;
```

- [ ] **Step 17: «Importar lista» avisa link antigo**

Em `lib/features/playlists/presentation/pages/playlists_screen.dart`, em `_importPlaylist`, logo depois de `if (result == null || !context.mounted) return;`:

```dart
    // Link de versão antiga (spec fim-fonte-plpcg §4.4): nada a importar.
    if (result.isLegacy) {
      showAppSnackbar(context, l10n.playlistShareLegacyLinkUnsupported);
      return;
    }
```

Em `lib/features/playlists/presentation/providers/playlists_provider.dart`, no `on Object catch` de `importSharedFromUrl`, trocar o comentário («Catálogo indisponível (short-id resolver depende do manifest, por exemplo)…») por:

```dart
      // O resolver por praise espera o catálogo; qualquer falha dele (ou
      // outra inesperada) vira o erro genérico de import em vez de derrubar
      // a tela.
```

- [ ] **Step 18: Strings**

Em `lib/l10n/app_pt.arb`:
- trocar o valor de `playlistImportInvalidUrl` por `"Link inválido."` (desvio 1);
- depois de `"deepLinkImportFailed": …,` acrescentar:

```json
  "playlistShareLegacyLinkUnsupported": "Este link é de uma versão antiga e já não abre. Peça um link novo à pessoa.",
  "@playlistShareLegacyLinkUnsupported": {
    "description": "Snackbar ao abrir ou colar um link de lista antigo (?s=, sharepdfs, shareitems…) — spec fim-fonte-plpcg §4.4"
  },
```

Em `lib/l10n/app_en.arb`:
- `playlistImportInvalidUrl` passa a `"Invalid link."`;
- no mesmo ponto:

```json
  "playlistShareLegacyLinkUnsupported": "This link is from an older version and no longer opens. Ask the person for a new link.",
  "@playlistShareLegacyLinkUnsupported": {
    "description": "Snackbar when opening or pasting an old list link (?s=, sharepdfs, shareitems…)"
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 19: Apagar o que ficou morto**

```bash
git rm lib/features/playlists/domain/ports/short_id_resolver.dart \
  lib/features/catalog/presentation/providers/pdf_ids_by_short_id_provider.dart \
  test/unit/features/catalog/pdf_ids_by_short_id_provider_test.dart \
  test/unit/core/playlist_share_url_builder_test.dart
```

Run: `grep -rn "ShortIdResolver\|shortIdResolverProvider\|pdfIdsByShortId\|isShortFormat\|isShortId\b\|resolveShortIds\|decodeShareItems\|buildShortPlaylistShare\|parsePdfIdsFromSharePdfs" lib test`
Expected: sem saída, fora `manifest_material_aliases_provider.dart:7`, que cita `pdfIdsByShortIdProvider` num comentário: trocar esse comentário por «(construído uma vez por manifest)» (o ficheiro sai no plano 3).

- [ ] **Step 20: Correr e ver passar**

Run: `flutter test test/unit/core/ test/unit/features/playlists/ test/unit/features/app_shell/ test/widget/features/app_shell/ test/widget/features/playlists/ test/unit/features/catalog/ && flutter analyze`
Expected: PASS; analyze sem issues.

- [ ] **Step 21: Commit**

```bash
git add -A lib/core/utils lib/features/playlists lib/features/app_shell lib/features/catalog/presentation/providers lib/l10n test/unit/core test/unit/features/playlists test/unit/features/app_shell test/unit/features/catalog test/widget/features/app_shell test/widget/features/playlists
git commit -m "$(cat <<'EOF'
feat(share): importar link por praise; links antigos avisam

?p=&n= resolve cada praise pelo índice local, com o favorito da conta ou
o PDF principal; o import espera o catálogo até 20 s. ?s=, sharepdfs,
shareitems, shareaudios e sharename mostram
playlistShareLegacyLinkUnsupported e saem da URL. Saem ShortIdResolver,
pdfIdsByShortIdProvider e os parsers por material.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Unidade B — Ao vivo

### Task 5: O gate «só Coldigom» do ao vivo morre

**Files:**
- Delete: `lib/features/live/domain/live_coldigom_only.dart`, `lib/features/live/presentation/widgets/live_coldigom_only_dialog.dart`, `test/unit/features/live/live_coldigom_only_test.dart`
- Modify: `lib/features/playlists/presentation/providers/active_playlist_editor.dart:10, 43-47, 90-94, 106-115, 279`
- Modify: `lib/features/live/presentation/providers/live_projection_provider.dart:38-55`
- Modify: `lib/features/live/presentation/providers/live_session_controller.dart:126-128`
- Modify: `lib/features/playlists/presentation/widgets/playlist_tile_actions.dart:20, 23, 566-580`
- Modify: `lib/features/live/presentation/widgets/live_session_banner.dart:11-17, 38-48`
- Modify: `lib/features/catalog/presentation/widgets/louvor_group_card.dart:196-199`
- Modify: `lib/features/catalog/presentation/widgets/material_sheet_actions.dart:104`
- Modify: `lib/l10n/app_pt.arb:883-894`, `lib/l10n/app_en.arb:783-794` (+ gerados)
- Test: `test/widget/features/live/live_session_banner_test.dart`, `test/unit/features/playlists/active_playlist_editor_test.dart`

**Interfaces:**
- Saem: `isColdigomEntry`, `nonColdigomEntries`, `showLiveColdigomOnlyDialog`, `AddToActiveOutcome.liveColdigomOnly`, `ActivePlaylistEditor.isLeadingLive`, `LiveLeadingNotifier`, `liveLeadingProvider`, as strings `liveColdigomOnlyTitle`/`Body`/`Add`.
- `AddToActiveOutcome` fica com `added`, `alreadyPresent`, `storageUnavailable` e `following`.

- [ ] **Step 1: Teste do banner — «Retomar» não barra id legado**

Em `test/widget/features/live/live_session_banner_test.dart`, substituir o `testWidgets('Retomar com material PLPCG na lista ativa só avisa', …)` inteiro por:

```dart
  testWidgets('Retomar com id legado na lista ativa retoma direto (sem gate)', (
    tester,
  ) async {
    await prefs.setString(
      kLiveLeaderSessionPrefsKey,
      '{"code":"k7x2m9q","playlistId":"p1","playlistName":"Culto"}',
    );
    final stub = await pump(
      tester,
      const LiveSessionState(),
      active: SavedPlaylist(
        playlistId: 'p1',
        nome: 'Culto',
        createdAt: DateTime(2026),
        entries: [PlaylistEntry.classified(encodePdfId('ColAdultos/001.pdf'))],
      ),
    );
    await tester.tap(find.text('Retomar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(stub.calls, ['resume:k7x2m9q']);
  });
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/widget/features/live/live_session_banner_test.dart`
Expected: FAIL — o diálogo «Só materiais do Coldigom» abre e `stub.calls` fica vazio.

- [ ] **Step 3: Banner sem gate**

Em `lib/features/live/presentation/widgets/live_session_banner.dart`:
- apagar os imports `../../../playlists/presentation/providers/active_playlist_provider.dart`, `../../domain/live_coldigom_only.dart` e `live_coldigom_only_dialog.dart`;
- trocar a `_Action(l10n.liveResume, () { … })` inteira por:

```dart
          _Action(
            l10n.liveResume,
            () => unawaited(controller.resumeLeader(pending)),
          ),
```

- [ ] **Step 4: Editor sem gate**

Em `lib/features/playlists/presentation/providers/active_playlist_editor.dart`:
- apagar `import '../../../live/domain/live_coldigom_only.dart';`;
- no enum `AddToActiveOutcome`, apagar o membro `liveColdigomOnly` e o doc dele (as 4 linhas de comentário antes);
- apagar o getter `isLeadingLive` e o doc dele (linhas 90–94);
- em `addToActive`, apagar o bloco inteiro:

```dart
    if (isLeadingLive &&
        !isColdigomEntry(
          PlaylistEntry(
            id: materialId,
            kind: kind ?? materialIdKindOf(materialId),
          ),
        )) {
      return AddToActiveOutcome.liveColdigomOnly;
    }
```

- em `replaceByKey`, apagar a linha `if (isLeadingLive && !isColdigomEntry(replacement)) return false;`.

- [ ] **Step 5: O espelho `liveLeadingProvider` sai**

Em `lib/features/live/presentation/providers/live_projection_provider.dart`, apagar a classe `LiveLeadingNotifier` (com o doc) e `final liveLeadingProvider = …;`.

Em `lib/features/live/presentation/providers/live_session_controller.dart`, apagar:

```dart
    listenSelf(
      (_, next) => ref.read(liveLeadingProvider.notifier).set(next.isLeading),
    );
```

(O import de `live_projection_provider.dart` fica, porque o controller ainda usa `liveProjectionProvider`.)

- [ ] **Step 6: «Iniciar ao vivo» sem gate**

Em `lib/features/playlists/presentation/widgets/playlist_tile_actions.dart`:
- apagar os imports `../../../live/domain/live_coldigom_only.dart` e `../../../live/presentation/widgets/live_coldigom_only_dialog.dart`;
- em `_goLive`, apagar:

```dart
    if (nonColdigomEntries(playlist.entries).isNotEmpty) {
      if (context.mounted) await showLiveColdigomOnlyDialog(context);
      return;
    }
```

- trocar o doc de `_goLive` por:

```dart
  /// «Iniciar ao vivo» (só lista salva, spec lista-ao-vivo): exige login;
  /// garante a sala no Worker, torna a lista ativa, começa a transmitir e
  /// abre a sala (link + QR). Qualquer material sobe (spec fim-fonte-plpcg §5).
```

- [ ] **Step 7: Card e sheet sem o desfecho**

Em `lib/features/catalog/presentation/widgets/louvor_group_card.dart`, apagar:

```dart
    if (outcome == AddToActiveOutcome.liveColdigomOnly) {
      showAppSnackbar(context, l10n.liveColdigomOnlyAdd);
      return;
    }
```

Em `lib/features/catalog/presentation/widgets/material_sheet_actions.dart`, apagar a linha `AddToActiveOutcome.liveColdigomOnly => l10n.liveColdigomOnlyAdd,`.

- [ ] **Step 8: Strings e ficheiros mortos**

Em `lib/l10n/app_pt.arb` e `lib/l10n/app_en.arb`, apagar `liveColdigomOnlyTitle`, `liveColdigomOnlyBody` e `liveColdigomOnlyAdd` com os respetivos blocos `@…`. Depois:

```bash
flutter gen-l10n
git rm lib/features/live/domain/live_coldigom_only.dart \
  lib/features/live/presentation/widgets/live_coldigom_only_dialog.dart \
  test/unit/features/live/live_coldigom_only_test.dart
```

- [ ] **Step 9: Teste do editor sem o caso do gate**

Em `test/unit/features/playlists/active_playlist_editor_test.dart`, apagar o `test('transmitindo ao vivo, só entra material Coldigom', …)` inteiro (o último do ficheiro) e o import `package:coldigui/features/live/presentation/providers/live_projection_provider.dart` (só servia para o `liveLeadingProvider`).

Run: `grep -rn "liveColdigomOnly\|nonColdigomEntries\|isColdigomEntry\|showLiveColdigomOnlyDialog\|liveLeadingProvider\|LiveLeadingNotifier\|isLeadingLive" lib test`
Expected: sem saída.

- [ ] **Step 10: Correr e ver passar**

Run: `flutter test test/widget/features/live/ test/unit/features/live/ test/unit/features/playlists/active_playlist_editor_test.dart test/widget/features/catalog/ test/widget/features/playlists/ && flutter analyze`
Expected: PASS; analyze sem issues.

- [ ] **Step 11: Commit**

```bash
git add -A lib/features/live lib/features/playlists lib/features/catalog/presentation/widgets lib/l10n test/widget/features/live test/unit/features/live test/unit/features/playlists/active_playlist_editor_test.dart
git commit -m "$(cat <<'EOF'
feat(live): qualquer lista sobe ao vivo — sai o gate «só Coldigom»

Saem live_coldigom_only, o diálogo, AddToActiveOutcome.liveColdigomOnly,
as verificações no editor, no «Iniciar ao vivo» e no «Retomar», o espelho
liveLeadingProvider (só existia para o gate) e as 3 strings.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Unidade C — Cor

### Task 6: Chip de cor única e artista «PLPCG»

**Files:**
- Modify: `lib/features/carousel/domain/entities/carousel_item.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart:1, 227-229`
- Modify: `lib/features/carousel/presentation/providers/carousel_items_provider.dart`
- Modify: `lib/features/catalog/presentation/widgets/home_empty_state.dart:11, 61-113`
- Modify: `lib/features/catalog/presentation/widgets/louvor_group_card.dart:13, 74, 318`
- Modify: `lib/features/playlists/presentation/widgets/playlist_tile_detail_chips.dart:1, 139, 162, 166, 178, 191`
- Modify: `lib/core/theme/color_extensions.dart:33`
- Create: `lib/features/audio_player/domain/utils/audio_media_artist.dart`
- Modify: `lib/features/audio_player/presentation/providers/audio_player_session_provider.dart:650-655`
- Modify: `lib/features/audio_player/data/audio_media_session_web.dart:48-50`
- Test: `test/widget/features/carousel/carousel_louvor_chip_test.dart:295-328`, `test/unit/features/audio_player/audio_media_artist_test.dart`

**Interfaces:**
- Saem: `CarouselItem.source` (campo e parâmetro) e `AppColors.chipColdigom`.
- Produces: `String audioMediaArtist(AudioTrack track)` (autor → número → `'PLPCG'`).

- [ ] **Step 1: Testes (vermelhos)**

Em `test/widget/features/carousel/carousel_louvor_chip_test.dart`, no teste `'chip coldigom usa fundo preto'`, trocar o título por `'chip usa AppColors.title para qualquer material'` e a asserção final por `expect(decoration.color, AppColors.title);` (o `source: LouvorDataSource.coldigom` fica por agora).

```dart
// test/unit/features/audio_player/audio_media_artist_test.dart
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/domain/utils/audio_media_artist.dart';
import 'package:flutter_test/flutter_test.dart';

AudioTrack _track({String author = '', String numero = ''}) => AudioTrack(
  audioId: 'a',
  r2Key: 'assets/praises/p1/audio.mp3',
  nome: 'Louvor',
  numero: numero,
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
  author: author,
);

void main() {
  test('autor quando há', () {
    expect(audioMediaArtist(_track(author: 'Fulano', numero: '031')), 'Fulano');
  });

  test('sem autor: o número do louvor', () {
    expect(audioMediaArtist(_track(numero: '031')), '031');
  });

  test('sem autor nem número: a marca PLPCG', () {
    expect(audioMediaArtist(_track()), 'PLPCG');
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/widget/features/carousel/carousel_louvor_chip_test.dart test/unit/features/audio_player/audio_media_artist_test.dart`
Expected: FAIL — o chip dá `Color(0xFF131214)` em vez de `AppColors.title`; `audio_media_artist.dart` não existe.

- [ ] **Step 3: `CarouselItem` sem `source`**

Em `lib/features/carousel/domain/entities/carousel_item.dart`:
- apagar `import '../../../catalog/domain/entities/louvor_data_source.dart';`;
- apagar a linha `this.source = LouvorDataSource.plpcg,` do construtor;
- apagar o campo e o doc dele:

```dart
  /// Origem dos metadados — define cor do chip na UI.
  final LouvorDataSource source;
```

- trocar a frase «enriquecida com os metadados do manifest/caches» do doc da classe por «enriquecida com os metadados do catálogo».

- [ ] **Step 4: Chip de cor única**

Em `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart`:
- apagar `import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';`;
- trocar:

```dart
    final backgroundColor = item.source == LouvorDataSource.coldigom
        ? AppColors.chipColdigom
        : AppColors.title;
```

por:

```dart
    const backgroundColor = AppColors.title;
```

Em `lib/core/theme/color_extensions.dart`, apagar `static const Color chipColdigom = Color(0xFF131214);`.

- [ ] **Step 5: Quem montava `source`**

- `lib/features/carousel/presentation/providers/carousel_items_provider.dart`: apagar as seis linhas `source: …,` (`track.source`, duas vezes `louvorDataSourceFromPdfId(entry.id)`, `chord.source`, `gesture.source`, `louvor.source`) e o import `../../../../core/utils/pdf_id_codec.dart`. No doc do provider, trocar «(manifest PLPCG e caches Coldigom)» por «(catálogo)».
- `lib/features/catalog/presentation/widgets/louvor_group_card.dart`: apagar `source: louvor.source,` (em `_toCarouselItem`), `source: singleAudio?.source ?? LouvorDataSource.coldigom,` (no `chipItem`) e o import `package:coldigui/features/catalog/domain/entities/louvor_data_source.dart`.
- `lib/features/playlists/presentation/widgets/playlist_tile_detail_chips.dart`: apagar `source: track?.source ?? louvorDataSourceFromPdfId(entry.id),`, `source: louvor.source,`, `final inferredSource = louvorDataSourceFromPdfId(pdfId);`, as duas linhas `source: inferredSource,` e o import `package:coldigui/core/utils/pdf_id_codec.dart`.
- `lib/features/catalog/presentation/widgets/home_empty_state.dart`: apagar `import '../../domain/entities/louvor_data_source.dart';` e trocar `_toCarouselItem` inteiro (com o doc) por:

```dart
/// Adapta um [CatalogMaterial] já resolvido para o `item` que
/// [CarouselLouvorChip] espera — o mesmo chip da barra de playlist do leitor
/// (C6): a borda dourada e a linha "classificação · categoria" vêm de graça.
CarouselItem _toCarouselItem(CatalogMaterial material, int index) {
  final (numero, nome, classificacao) = switch (material) {
    PdfMaterial(:final louvor) => (
      louvor.numero,
      louvor.nome,
      louvor.classificacao,
    ),
    ChordMaterialRef(:final chord) => (
      chord.numero,
      chord.nome,
      chord.classificacao,
    ),
    GestureMaterialRef(:final gesture) => (
      gesture.numero,
      gesture.nome,
      gesture.classificacao,
    ),
    AudioMaterial(:final track) => (
      track.numero,
      track.nome,
      track.classificacao,
    ),
    YoutubeMaterialRef(material: final youtube) => (
      youtube.numero,
      youtube.nome,
      youtube.classificacao,
    ),
    LyricsMaterial(:final numero, :final nome) => (numero, nome, ''),
  };
  return CarouselItem(
    materialId: material.id,
    kind: material.kind,
    index: index,
    numero: numero,
    nome: nome,
    categoria: material.categoria,
    classificacao: classificacao,
  );
}
```

`carousel_chips.dart:211-218` não muda (desvio 6).

- [ ] **Step 6: Teste do chip sem `source`**

No mesmo teste do chip (Step 1), apagar a linha `source: LouvorDataSource.coldigom,` e o import `package:coldigui/features/catalog/domain/entities/louvor_data_source.dart`; trocar o nome da constante `coldigomItem` por `item` (duas ocorrências).

- [ ] **Step 7: Artista da notificação**

```dart
// lib/features/audio_player/domain/utils/audio_media_artist.dart
import '../entities/audio_track.dart';

/// Linha «artista» da notificação de áudio (media session nativa e web):
/// autor, senão número do louvor, senão a marca `PLPCG` (spec
/// fim-fonte-plpcg §3.2).
String audioMediaArtist(AudioTrack track) {
  if (track.author.isNotEmpty) return track.author;
  if (track.numero.isNotEmpty) return track.numero;
  return 'PLPCG';
}
```

Em `lib/features/audio_player/presentation/providers/audio_player_session_provider.dart`, acrescentar `import '../../domain/utils/audio_media_artist.dart';` e trocar o `artist: tracks[i].author.isNotEmpty ? … : 'Coldigom'),` (linhas 650–655) por `artist: audioMediaArtist(tracks[i]),`.

Em `lib/features/audio_player/data/audio_media_session_web.dart`, acrescentar `import '../domain/utils/audio_media_artist.dart';` e trocar o `artist: track.author.isNotEmpty ? … : 'PLPCG'),` por `artist: audioMediaArtist(track),`.

- [ ] **Step 8: Correr e ver passar**

Run: `grep -rn "chipColdigom\|'Coldigom'" lib && flutter test test/widget/features/carousel/ test/unit/features/carousel/ test/unit/features/audio_player/ test/widget/features/catalog/ test/widget/features/playlists/ test/widget/features/audio_player/ && flutter analyze`
Expected: o grep só acha `lib/l10n/…` (`libraryCatalogModeColdigom`, que sai no plano 1; se o plano 1 já correu, sem saída); testes PASS; analyze sem issues.

- [ ] **Step 9: Commit**

```bash
git add -A lib/features/carousel lib/features/catalog/presentation/widgets lib/features/playlists/presentation/widgets/playlist_tile_detail_chips.dart lib/core/theme/color_extensions.dart lib/features/audio_player test/widget/features/carousel/carousel_louvor_chip_test.dart test/unit/features/audio_player/audio_media_artist_test.dart
git commit -m "$(cat <<'EOF'
feat(ui): chip vinho em todo o lado; artista «PLPCG» na notificação

Saem CarouselItem.source e AppColors.chipColdigom; o fallback de artista
passa a audioMediaArtist, partilhado pela sessão nativa e pela web.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Verificação do plano (depois da Tarefa 6)

- [ ] `flutter analyze` sem issues e `flutter test` verde (suite inteira).
- [ ] `grep -rn "chipColdigom\|liveColdigomOnly\|playlistShareColdigom\|showColdigomShareDialog\|ShareLinkShortener\|PlaylistShareLink\b\|pdfIdsByShortId\|ShortIdResolver\|isShortFormat\|nonColdigomEntries\|liveLeadingProvider\|ApiEndpoints.links" lib test` → sem saída.
- [ ] `grep -rn "playlistShareLegacyLinkUnsupported" lib/l10n/app_pt.arb lib/l10n/app_en.arb` → 2 chaves + 2 blocos `@`.
- [ ] Itens 6, 7 e 8 da validação manual do spec (§11) ficam para depois do deploy conjunto com os planos 1 e 3.

## Self-review

1. **Cobertura do spec:**
   - §3.2 cor → Tarefa 6.
   - §4.1 contrato → Tarefa 1.
   - §4.2 gerar (material movido; praise sem `shortId` → erro + sync; todos os kinds; só URL) → Tarefa 2.
   - §4.3 importar (índice vazio → espera com prazo; token desconhecido; favoritos; praise sem adicionável) → Tarefas 3 e 4.
   - §4.4 links antigos → Tarefa 4.
   - §4.5 o que sai (diálogo, 6 strings, `/l/`, `pdfIdsByShortIdProvider`, `ShortIdResolver`, `isShortId`/`isShortFormat`, débito do `_generateUrl`, folheto com QR) → Tarefas 2 e 4.
   - §5 ao vivo → Tarefa 5.
   - §8, linhas de share → Tarefas 2 e 4.
   - §9, strings deste escopo → Tarefas 2, 4 e 5.
   - §10, testes deste escopo: `generate_playlist_share_url_test`, `playlist_share_actions_test`, `playlist_share_sheet_test` (sem mudança; corre na Tarefa 2), `share_link_shortener_remote_test` (apagado), `pdf_ids_by_short_id_provider_test` (apagado), `live_coldigom_only_test` (apagado), `live_session_banner_test`, `active_playlist_editor_test`, `carousel_louvor_chip_test`, `carousel_items_provider_test` e `carousel_chips_test` (sem mudança; correm na Tarefa 6), testes de import e deep link (Tarefa 4).
   - Novos de §10.3 → Tarefas 1 a 4.
2. **Placeholders:** nenhum «TBD»; cada passo de código traz o código. As edições pequenas em ficheiros grandes vêm como «apagar/trocar estas linhas», com o texto exato.
3. **Tipos:** `PraiseShortIdLookup` (T2), `PraiseEntryResolver`/`PraiseEntryResolverLoader` (T3, usados em T4), `praiseEntryResolverLoaderProvider` (T3, T4), `PlaylistShareParams({shareName, praiseShortIds})`/`.legacy()` (T4, usados pelos testes de T4), `LegacyShareLinkException` (T4), `SyncDeepLinkOutcome.legacy` (T4) e `audioMediaArtist` (T6) — os nomes batem entre tarefas.
4. **Review Focus:** as 5 linhas têm teste na tarefa dona (T2, T1, T4 ×2, T2/T4).
