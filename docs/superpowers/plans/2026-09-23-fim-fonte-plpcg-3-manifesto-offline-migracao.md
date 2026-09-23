# Fim da fonte PLPCG — plano 3: ids legados, fim do manifesto, /offline de uma secção, script D1 e docs

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o app deixa de ler o manifesto PLPCG em qualquer forma: os ids legados guardados no aparelho passam uma vez pelo crosswalk do coldigom, a pilha do manifesto, o `CompositeCatalogSource`, o `LouvorCache` e o `LouvorDataSource` são apagados, o `/offline` fica com uma secção só (também sem login), o D1 ganha um script único de migração e os docs acompanham.

**Architecture:** um use case puro `NormalizeLegacyMaterialIds` recolhe ids legados de cinco *stores* (playlists, índice offline, três prefs) atrás de uma porta `LegacyIdStore`, pergunta ao crosswalk (`ColdigomRemoteDatasource.resolveLegacyPdfIds`, contrato C9 → endpoint C2) numa só rodada e devolve a cada store a mesma `LegacyIdResolution`; um `Notifier` deduplica rodadas e é chamado pelo hydrate da sessão e por cada pull de playlists. Depois, os consumidores do manifesto passam ao catálogo coldigom em memória (`catalogSourceProvider` → `ColdigomCatalogSource`, `CatalogMaterialLookup` sem alias), e só então a pilha morta é apagada, de fora para dentro, para cada commit compilar e ficar verde.

**Tech Stack:** Flutter 3 + Riverpod 3 (`Notifier`/`Provider`), Dio, `isar_plus` 1.3.7, SharedPreferences, `flutter_test`, `flutter gen-l10n`; Worker `plpcg-catalog` em TypeScript com `node --experimental-strip-types --test` e `wrangler d1 execute`.

**Spec:** `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md` — §3.1, §6 inteiro, §7.2 (lado cliente), §8, §9 (restante), §10 (restante), §11 itens 5–6. Modelo de dados anterior: `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md` (§11–§12). Quem executa lê os dois.

## Global Constraints

- `flutter analyze` limpo + `flutter test` verde; a CI roda **sem** dart-defines — nenhum teste pode depender de `COLDIGOM_API_BASE_URL`/`PLPCG_API_BASE_URL`.
- l10n: editar `lib/l10n/app_pt.arb` + `app_en.arb`, rodar `flutter gen-l10n`; gerados commitados.
- Isar: mudanças de schema são aditivas e anuláveis; regenerar com `dart run build_runner build --delete-conflicting-outputs`; `.g.dart` commitados. (Neste plano a única mudança de schema é **tirar** `LouvorCacheSchema` da lista aberta — ver desvio 3.)
- Commits em português, um por tarefa, com o trailer exato:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- Nada de push, merge ou deploy sem pedido do dono. O script do D1 (Tarefa 13) **não** é executado contra `--remote` neste plano: corre só depois do deploy do app e com pedido do dono (spec §6.3).
- Não renomear código `Plpcg*`, a env `PLPCG_API_BASE_URL` nem o Worker `plpcg-catalog`; marca «PLPCG» fica (spec §0). Código **morto** por este trabalho é apagado.
- Execução prevista: subagentes em worktree, tarefa a tarefa (subagent-driven-development). Implementadores rodam git como comando plano (sem `cd … &&` nem `git -C`); UI de teste com `ensureVisible`/`tester.view.physicalSize` em vez de encolher densidade.
- Worker: `npm run typecheck` e `npm test` verdes em `workers/plpcg-catalog` (a CI usa Node 22).
- Os ids legados deixam de ser um espaço suportado: **id legado = entrada PDF com `!isColdigomPdfId`** (inclui `assets/PES/…`), spec §6.1. Não há tabela congelada no app.
- `ContributionSource` fica (contrato com o servidor); `isColdigomPdfId` fica (é o detetor de id legado).

## Review Focus

Condições que o spec implica e que mais provavelmente mordem quem usa o app; cada linha tem o teste que a prende na tarefa dona do código.

1. **`/offline` sem login** — quem nunca entrou tem de ver a lista «Tipos» inteira e conseguir baixar um tipo; antes só via o convite. Teste «deslogado: lista Tipos inteira e baixa sem conta» (Tarefa 9).
2. **Crosswalk fora do ar ou a falhar a meio** (lote 2 de 3 dá 500, modo avião) — nada é reescrito, nenhuma store fica meio migrada, e a próxima rodada tenta de novo. Testes «erro HTTP num lote propaga» (Tarefa 2) e «resolve falha → pendente, nenhuma store reescrita» (Tarefa 3).
3. **Listas em conflito e rascunhos** — normalizar não pode transformar um conflito em `pendingPush` (o push o ignoraria e o banner some) nem subir um rascunho. Testes «conflito continua conflito» e «rascunho não vira pendingPush» (Tarefa 4).
4. **Colisões** — dois ids legados que o crosswalk manda para o mesmo id coldigom, um PDF baixado com o id legado **e** com o coldigom, e duas «últimas páginas» para o mesmo material: a lista mantém as duas entradas, o índice fica com uma linha, a página fica a mais recente. Testes nas Tarefas 4 e 5.
5. **Cliente antigo que volta a empurrar ids legados** depois da migração — o aparelho novo normaliza de novo depois do pull. Teste «pull com linhas novas pede a normalização» (Tarefa 6).

### Desvios do spec (decididos ao planear; justificativa na tarefa)

1. **§6.4 — `LouvorPdfPath` fica, simplificado.** O spec lista-o para sair como «derivação legada», mas é ele que monta `/assets/praises/<praise>/<material>.pdf` a partir do `pdfId` para **todo** PDF coldigom (o adapter põe em `Louvor.pdf` só o nome do ficheiro). Sai só o ramo do `pdf` absoluto do manifesto e o prefixo `assets/` para ids sem ele. Tarefa 11.
2. **§6.4 — `contributionSourceOf` é apagado.** Com um valor só, a função sem argumento seria um alias da constante; os três chamadores passam `ContributionSource.coldigom`. `ContributionSource` fica. Tarefa 12.
3. **§6.4 — `LouvorCache` sem passo de limpeza no `MigrateOfflineStorage`.** Medido a 2026-09-23 (sonda em VM, `isar_plus` 1.3.7 nativo): abrir a instância com um schema que já não tem a coleção **apaga os dados dela** (2000 linhas gravadas → reabrir sem a coleção → reabrir com ela → `count() == 0`). Um passo 5 também não conseguiria apagar a coleção: a build nova já não tem a classe. Na web (SQLite) não dá para medir na VM → item 10 da validação manual (Tarefa 15). Tarefa 11.
4. **§3.1 — um só «Atualizar» no `/offline`.** O spec mantém a linha de estado do catálogo **e** o «Atualizar» (reconcile), e o §10.2 pede «uma secção, um Atualizar». O botão único da linha de estado faz as duas coisas: `coldigomCatalogSyncProvider.sync()` + `offlineCacheStatusProvider.refreshAll()` (reconcile). Tarefa 9.
5. **§3.1 — `ResolvePdfForReader` perde `isFullOfflineMode` e `hasNetworkConnection`.** Os dois só existiam para a flag `OFFLINE_AVAILABLE`; sem ela o caminho é o que já valia para quem nunca fez o bulk PLPCG (fetch on-demand, LRU). Tarefa 10.
6. **§9.1 — saem também chaves que ficam mortas e não estavam listadas:** `offlineDownloadSelected`, `offlineMaintenanceBusy`, `offlineMissingLouvoresEmpty`, `offlineMissingLouvoresLoadError`, `offlineMissingLouvoresSheetTitle`. Cada uma é conferida com grep antes. Tarefa 10.
7. **§6.2 — sem gatilho extra ao voltar a rede.** O spec define dois gatilhos (hydrate da sessão e pull de playlists); com o crosswalk fora do ar a normalização espera o próximo. Não se acrescenta um terceiro.

## Pré-condições (planos 0–2 já no código)

- **C2 (plano 0):** `POST /api/plpcg/crosswalk` em produção no coldigom.
- **C3/C4/C5/C6/C7 (plano 1):** Home e /biblioteca já não leem o manifesto; `CatalogFilterState` novo; `matchesCatalogFilters`; `ColdigomSearchIndex.groupForMaterialId`; caminho em memória sem Isar. A pilha do manifesto e o `CompositeCatalogSource` ainda existem.
- **C8 (plano 2):** share por praise (`?p=`), `CarouselItem.source` e `AppColors.chipColdigom` apagados, gates de share e ao vivo apagados, `pdfIdsByShortIdProvider`/`ShortIdResolver`/encurtador `/l/` apagados. `LouvorDataSource` ainda existe.

A Tarefa 0 confere isto antes de qualquer commit.

## Mapa de ficheiros

| Tarefa | Cria | Modifica | Apaga |
|---|---|---|---|
| 0 Pré-condições | — | — | — |
| 1 Detetor e id pela URL | `test/unit/core/utils/pdf_id_codec_test.dart` | `lib/core/utils/pdf_id_codec.dart`, `lib/features/catalog/domain/entities/manifest_material_aliases.dart`, `test/unit/features/catalog/manifest_material_aliases_test.dart` | `lib/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart` |
| 2 Crosswalk (C9) | `test/unit/features/coldigom/coldigom_remote_datasource_crosswalk_test.dart` | `coldigom_endpoints.dart`, `coldigom_remote_datasource.dart` | — |
| 3 Use case | `lib/features/catalog/domain/legacy_ids/legacy_id_store.dart`, `lib/features/catalog/domain/usecases/normalize_legacy_material_ids.dart`, `test/unit/features/catalog/normalize_legacy_material_ids_test.dart` | — | — |
| 4 Stores Isar | `lib/features/playlists/data/legacy/playlist_legacy_id_store.dart`, `lib/features/offline/data/legacy/offline_index_legacy_id_store.dart`, `test/unit/features/playlists/playlist_legacy_id_store_test.dart`, `test/unit/features/offline/offline_index_legacy_id_store_test.dart` | `offline_maintenance_lock_provider.dart` | — |
| 5 Stores de prefs | `lib/features/catalog/data/legacy_ids/prefs_legacy_id_stores.dart`, `test/unit/features/catalog/prefs_legacy_id_stores_test.dart` | `reader_preferences_datasource.dart` | — |
| 6 Provider + gatilhos | `lib/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart`, `test/unit/features/catalog/legacy_material_ids_normalizer_provider_test.dart` | `playlist_session_hydrate.dart`, `playlist_sync_provider.dart`, `playlist_session_hydrate_test.dart`, `playlist_sync_provider_test.dart` | — |
| 7 Fonte e lookup coldigom | — | `test/helpers/coldigom_catalog_test_helpers.dart` (criado pelo plano 1), `catalog_source_provider.dart`, `catalog_material_lookup_provider.dart`, `find_louvor_group_by_pdf_id.dart`, `carousel_swap_material_button.dart`, `contribution_context_fields.dart`, `playlists_provider.dart`, testes | — |
| 8 Boot sem manifesto | — | `app.dart`, `pdfrx_bootstrap.dart`, `audio_follow_reader_provider.dart`, `find_material_for_group.dart`, `playlists_provider.dart`, `playlist_list_tile.dart`, `offline_lifecycle_listener.dart`, testes | — |
| 9 `/offline` uma secção | — | `offline_settings_screen.dart`, `coldigom_section.dart`, `remove_coldigom_downloads.dart`, `offline_coldigom_download_provider.dart`, arb + gerados, testes | `test/unit/features/offline/offline_bulk_completion_message_test.dart` |
| 10 Apagar secção PLPCG | `lib/features/offline/presentation/providers/download_wakelock_provider.dart` | `offline_core_providers.dart`, `offline_cache_status_provider.dart`, `offline_maintenance_lock_provider.dart`, `resolve_pdf_for_reader.dart`, `migrate_offline_storage.dart`, `offline_config.dart`, `storage_keys.dart`, arb + gerados, testes | secção PLPCG inteira (lista na tarefa) |
| 11 Apagar manifesto | — | `isar_app_schemas.dart`, `isar_provider.dart`, `coldigom_endpoints.dart`, `louvor.dart`, `louvor_pdf_path.dart`, `find_louvor_group_by_pdf_id.dart`, testes | pilha do manifesto + `LouvorCache` (lista na tarefa) |
| 12 Apagar `LouvorDataSource` | — | entidades, adapter, sheet, leitor, player, warmup, adoção, testes | `louvor_data_source.dart` |
| 13 Script D1 | `workers/plpcg-catalog/scripts/legacy_playlist_ids.ts`, `…/legacy_playlist_ids.test.ts`, `…/migrate-legacy-playlist-ids.ts` | `workers/plpcg-catalog/package.json`, `.gitignore`, `README.md` | — |
| 14 Docs | — | `FEATURE_INDEX.md`, `LOUVOR_GROUPING.md`, `UC-09-configure-offline.md`, specs de 18/09, 13/09 e 12/09, spec de 23/09 (§13) | — |
| 15 Verificação final | — | — | — |

Todos os paths abaixo são relativos à raiz do repo `coldigui`. Comandos de teste: `flutter test <path>`; ao fim de cada tarefa, `flutter analyze` também.

---

## Unidade 0 — Pré-condições

### Task 0: Conferir que os planos 0–2 estão no código

**Files:** nenhum (só leitura; não há commit).

- [ ] **Step 1: Planos 1 e 2 apagaram o que prometeram**

Run:

```bash
grep -rnE "libraryCatalogModeProvider|LibraryCatalogMode\b|librarySpecialArrangementProvider|filterByMaterialAndArranjoProvider|showColdigomShareDialog|pdfIdsByShortIdProvider|shortIdResolverProvider|shareLinkShortenerProvider|live_coldigom_only|chipColdigom" lib
```

Expected: nenhuma linha. Se aparecer alguma, **parar** e reportar ao coordenador (o plano 1 ou 2 não terminou).

- [ ] **Step 2: Planos 1 e 2 criaram o que o plano 3 usa**

Run:

```bash
grep -n "shortId" lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart
grep -n "groupForMaterialId\|groupByShortId" lib/features/coldigom/domain/search/coldigom_search_index.dart
grep -rn "bool matchesCatalogFilters" lib/features/catalog/domain/usecases/matches_catalog_filters.dart
```

Expected: as três dão pelo menos uma linha.

- [ ] **Step 3: Consumidores restantes do manifesto são só os que este plano trata**

Run: `grep -rln "louvoresManifestProvider" lib | sort`

Expected — exatamente este conjunto (ordem alfabética):

```text
lib/app.dart
lib/features/audio_player/presentation/providers/audio_follow_reader_provider.dart
lib/features/catalog/data/providers/plpcg_catalog_source_provider.dart
lib/features/catalog/presentation/providers/catalog_checksum_poll_provider.dart
lib/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart
lib/features/catalog/presentation/providers/louvores_manifest_provider.dart
lib/features/catalog/presentation/providers/manifest_material_aliases_provider.dart
lib/features/pdf_reader/data/pdfrx_bootstrap.dart
lib/features/playlists/presentation/providers/playlists_provider.dart
lib/features/playlists/presentation/widgets/playlist_list_tile.dart
```

Um ficheiro a mais (ex.: `home_screen.dart`, `library_screen.dart`, `home_search_provider.dart`, `known_praise_ids_provider.dart`, `playlist_providers.dart`) = plano 1/2 incompleto → parar e reportar.

- [ ] **Step 4: O endpoint C2 responde em produção**

Run:

```bash
curl -s -X POST "https://coldigom-api.jairofilho79.workers.dev/api/plpcg/crosswalk" \
  -H 'content-type: application/json' \
  -d '{"pdfIds":["MzAxMDIwMjUvQSBUaSBTZW5ob3IgLSBTb2xvIGUgVm96ZXMucGRm","naoexiste"]}'
```

Expected: `200` com `{"items":{"MzAxMDIwMjUvQSBUaSBTZW5ob3IgLSBTb2xvIGUgVm96ZXMucGRm":{"praiseId":"…","materialId":"…","url":"https://coldigom-api…/assets/praises/…/….pdf"}}}` e **sem** a chave `naoexiste`. Se der 404, o plano 0 ainda não foi deployado → parar e reportar (as Tarefas 1–12 podem ser escritas, mas a validação manual depende disto).

- [ ] **Step 5: Linha de base verde**

Run: `flutter analyze && flutter test`
Expected: analyze limpo, suíte verde. Anotar o número de testes (para comparar na Tarefa 15).

---

## Unidade A — Normalizador de ids legados (spec §6.1–§6.2, C9)

### Task 1: `isLegacyPdfId` e `coldigomPdfIdFromAssetUrl` no codec

O detetor de id legado e a regra «id coldigom = `encodePdfId(<path do url depois da base>)`» passam a viver no codec do core, onde o crosswalk (Tarefa 2) os usa. `coldigomPdfIdFromManifestPdf` era essa mesma regra presa ao manifesto; muda de nome e de casa, e o `ManifestMaterialAliases` (apagado na Tarefa 11) passa a chamá-la pelo nome novo.

**Files:**
- Modify: `lib/core/utils/pdf_id_codec.dart`
- Modify: `lib/features/catalog/domain/entities/manifest_material_aliases.dart:1,56`
- Modify: `test/unit/features/catalog/manifest_material_aliases_test.dart` (tirar o grupo `coldigomPdfIdFromManifestPdf` e o import)
- Delete: `lib/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart`
- Test: `test/unit/core/utils/pdf_id_codec_test.dart` (novo)

**Interfaces:**
- Produces: `bool isLegacyPdfId(String id)`; `String? coldigomPdfIdFromAssetUrl(String url)` — ambos em `package:coldigui/core/utils/pdf_id_codec.dart`. `encodePdfId` e `isColdigomPdfId` ficam com a mesma assinatura.

- [ ] **Step 1: Teste**

```dart
// test/unit/core/utils/pdf_id_codec_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodePdfId', () {
    test('mesma saída do script do D1 (base64url sem padding)', () {
      // Os mesmos literais estão em workers/plpcg-catalog/scripts/
      // legacy_playlist_ids.test.ts — os dois lados cunham o mesmo id.
      expect(
        encodePdfId('assets/praises/p1/m1.pdf'),
        'YXNzZXRzL3ByYWlzZXMvcDEvbTEucGRm',
      );
      expect(
        encodePdfId('ColAdultos/Cifra nível I/001.pdf'),
        'Q29sQWR1bHRvcy9DaWZyYSBuw612ZWwgSS8wMDEucGRm',
      );
    });
  });

  group('isLegacyPdfId', () {
    test('PDF fora de assets/praises é legado (inclui assets/PES)', () {
      expect(isLegacyPdfId(encodePdfId('ColAdultos/001.pdf')), isTrue);
      expect(isLegacyPdfId(encodePdfId('assets/PES/Hino 1.pdf')), isTrue);
      expect(
        isLegacyPdfId(encodePdfId('ColAdultos/Cifra nível I/001.pdf')),
        isTrue,
      );
    });

    test('id coldigom de qualquer tipo não é legado', () {
      for (final path in [
        'assets/praises/p1/m1.pdf',
        'assets/praises/p1/m1.chord',
        'assets/praises/p1/a.mp3',
        'assets/praises/p1/m1.gestures',
      ]) {
        expect(isLegacyPdfId(encodePdfId(path)), isFalse, reason: path);
      }
    });

    test('não-PDF, letra, YouTube e lixo não são legados', () {
      expect(isLegacyPdfId(encodePdfId('ColAdultos/001.chord')), isFalse);
      expect(isLegacyPdfId('lyrics:p1'), isFalse);
      expect(isLegacyPdfId('dQw4w9WgXcQ'), isFalse);
      expect(isLegacyPdfId(''), isFalse);
      expect(isLegacyPdfId('não é base64!'), isFalse);
    });
  });

  group('coldigomPdfIdFromAssetUrl', () {
    test('URL absoluta vira encodePdfId do r2Key', () {
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p1/m1.pdf',
        ),
        encodePdfId('assets/praises/p1/m1.pdf'),
      );
    });

    test('material movido: vale a pasta da URL', () {
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p9/m1.pdf',
        ),
        encodePdfId('assets/praises/p9/m1.pdf'),
      );
    });

    test('percent-encoding é decodificado antes de codificar', () {
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p9/m%202.pdf',
        ),
        'YXNzZXRzL3ByYWlzZXMvcDkvbSAyLnBkZg',
      );
    });

    test('sem assets/praises/<praise>/<ficheiro> devolve null', () {
      expect(
        coldigomPdfIdFromAssetUrl('https://coldigom.test/outra/coisa.pdf'),
        isNull,
      );
      expect(
        coldigomPdfIdFromAssetUrl('https://coldigom.test/assets/praises/'),
        isNull,
      );
      expect(
        coldigomPdfIdFromAssetUrl('https://coldigom.test/assets/praises/p1'),
        isNull,
      );
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p1/%E0%A4%A.pdf',
        ),
        isNull,
      );
      expect(coldigomPdfIdFromAssetUrl('001.pdf'), isNull);
      expect(coldigomPdfIdFromAssetUrl(''), isNull);
    });
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/core/utils/pdf_id_codec_test.dart`
Expected: FAIL — `isLegacyPdfId` e `coldigomPdfIdFromAssetUrl` não existem.

- [ ] **Step 3: Implementar no codec**

Em `lib/core/utils/pdf_id_codec.dart`: acrescentar o import `import 'material_id_kind.dart';` (junto do `pdf_path_normalizer.dart`), trocar o doc de `isColdigomPdfId` e acrescentar as duas funções no fim do ficheiro. `louvorDataSourceFromPdfId` e o import de `louvor_data_source.dart` ficam até à Tarefa 12.

```dart
/// `true` quando [pdfId] aponta para material coldigom (`assets/praises/...`).
///
/// Depois do fim da fonte PLPCG é também o detetor de id legado da
/// normalização (spec 2026-09-23 §6.1) — ver [isLegacyPdfId].
bool isColdigomPdfId(String pdfId) {
  try {
    return PdfPathNormalizer.getPdfRelPath(pdfId).startsWith('assets/praises/');
  } on Object {
    return false;
  }
}
```

```dart
/// Id legado do manifest PLPCG (spec 2026-09-23 §6.1): entrada **PDF** cujo
/// path não está em `assets/praises/` — inclui os 36 `assets/PES/…`.
///
/// É o que `NormalizeLegacyMaterialIds` troca pelo id coldigom via crosswalk.
/// Cifra, áudio, gesto, letra e YouTube nunca são legados.
bool isLegacyPdfId(String id) =>
    materialIdKindOf(id) == MaterialKind.pdf && !isColdigomPdfId(id);

const _praisesPathMarker = '/assets/praises/';
const _praisesR2Prefix = 'assets/praises/';

/// Id coldigom do material cuja URL é [url]
/// (`https://…/assets/praises/<praise>/<material>.<ext>`).
///
/// É `encodePdfId(r2Key)` — o mesmo id que `ColdigomLouvorAdapter` cunha —,
/// com o `r2Key` lido da URL e **não** montado a partir de
/// `praiseId`/`materialId`: materiais movidos vivem na pasta de outro praise
/// e só a URL diz o path real (desvio 2 do spec de 18/09). Serve o crosswalk
/// (`ColdigomRemoteDatasource.resolveLegacyPdfIds`).
///
/// `null` quando [url] não tem `/assets/praises/<praise>/<ficheiro>` ou o
/// percent-encoding é inválido.
String? coldigomPdfIdFromAssetUrl(String url) {
  final index = url.indexOf(_praisesPathMarker);
  if (index < 0) return null;
  final r2Key = url.substring(index + 1); // sem a barra inicial
  final rest = r2Key.substring(_praisesR2Prefix.length);
  if (rest.isEmpty || !rest.contains('/')) return null;
  try {
    return encodePdfId(Uri.decodeComponent(r2Key));
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}
```

- [ ] **Step 4: Apontar o `ManifestMaterialAliases` para o nome novo e apagar o ficheiro velho**

Em `lib/features/catalog/domain/entities/manifest_material_aliases.dart`: trocar `import '../utils/coldigom_pdf_id_from_manifest_pdf.dart';` por `import '../../../../core/utils/pdf_id_codec.dart';` e, na linha 56, `coldigomPdfIdFromManifestPdf(louvor.pdf)` por `coldigomPdfIdFromAssetUrl(louvor.pdf)`.

Apagar `lib/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart`.

Em `test/unit/features/catalog/manifest_material_aliases_test.dart`: apagar o import de `coldigom_pdf_id_from_manifest_pdf.dart` e o `group('coldigomPdfIdFromManifestPdf', …)` inteiro (os casos migraram para `pdf_id_codec_test.dart`).

- [ ] **Step 5: Correr**

Run: `flutter test test/unit/core/utils/pdf_id_codec_test.dart test/unit/features/catalog/manifest_material_aliases_test.dart && flutter analyze`
Expected: PASS, analyze limpo.

- [ ] **Step 6: Commit**

```bash
git add lib/core/utils/pdf_id_codec.dart lib/features/catalog/domain/entities/manifest_material_aliases.dart lib/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart test/unit/core/utils/pdf_id_codec_test.dart test/unit/features/catalog/manifest_material_aliases_test.dart
git commit -m "feat(ids): isLegacyPdfId e coldigomPdfIdFromAssetUrl no codec

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `ColdigomRemoteDatasource.resolveLegacyPdfIds` (C9 → C2)

**Files:**
- Modify: `lib/features/coldigom/data/constants/coldigom_endpoints.dart`
- Modify: `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart`
- Test: `test/unit/features/coldigom/coldigom_remote_datasource_crosswalk_test.dart` (novo)

**Interfaces:**
- Consumes: `coldigomPdfIdFromAssetUrl(String url)` (Tarefa 1).
- Produces: `ColdigomEndpoints.plpcgCrosswalk = '/api/plpcg/crosswalk'`; `static const int ColdigomRemoteDatasource.crosswalkBatchSize = 500`; `Future<Map<String, String>> ColdigomRemoteDatasource.resolveLegacyPdfIds(Iterable<String> legacyPdfIds)` — legado → pdfId coldigom; desconhecidos e URLs fora de `assets/praises/` ficam de fora; erro HTTP em qualquer lote lança `DioException` (sem resultado parcial).

- [ ] **Step 1: Teste**

```dart
// test/unit/features/coldigom/coldigom_remote_datasource_crosswalk_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_endpoints.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Crosswalk falso: responde `items` para os ids de [urls] e guarda os pedidos.
/// [failOnCall] (1-based) devolve 500 nessa chamada.
class _CrosswalkAdapter implements HttpClientAdapter {
  _CrosswalkAdapter(this.urls, {this.failOnCall});

  final Map<String, String> urls;
  final int? failOnCall;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == failOnCall) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'x'}),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final ids = ((options.data as Map)['pdfIds'] as List).cast<String>();
    final items = {
      for (final id in ids)
        if (urls.containsKey(id))
          id: {'praiseId': 'p', 'materialId': 'm', 'url': urls[id]},
    };
    return ResponseBody.fromString(
      jsonEncode({'items': items}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ColdigomRemoteDatasource _datasource(_CrosswalkAdapter adapter) =>
    ColdigomRemoteDatasource(
      Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
        ..httpClientAdapter = adapter,
    );

void main() {
  final legadoA = encodePdfId('ColAdultos/001.pdf');
  final legadoMovido = encodePdfId('ColAdultos/002.pdf');
  final legadoSemPraise = encodePdfId('ColAdultos/003.pdf');
  final desconhecido = encodePdfId('ColAdultos/999.pdf');

  test('POST no endpoint; id coldigom sai da URL; desconhecidos omitidos', () async {
    final adapter = _CrosswalkAdapter({
      legadoA: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      // Material movido: o praise da resposta é outro, a URL manda.
      legadoMovido: 'https://coldigom.test/assets/praises/p9/m2.pdf',
      legadoSemPraise: 'https://coldigom.test/outra/coisa.pdf',
    });

    final resolved = await _datasource(
      adapter,
    ).resolveLegacyPdfIds([legadoA, legadoMovido, legadoSemPraise, desconhecido]);

    expect(resolved, {
      legadoA: encodePdfId('assets/praises/p1/m1.pdf'),
      legadoMovido: encodePdfId('assets/praises/p9/m2.pdf'),
    });
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, ColdigomEndpoints.plpcgCrosswalk);
  });

  test('lotes de 500, sem repetidos', () async {
    final ids = [
      for (var i = 0; i < 1201; i++) encodePdfId('ColAdultos/$i.pdf'),
    ];
    final adapter = _CrosswalkAdapter(const {});

    await _datasource(adapter).resolveLegacyPdfIds([...ids, ids.first]);

    expect(
      adapter.requests.map(
        (r) => ((r.data as Map)['pdfIds'] as List).length,
      ),
      [500, 500, 201],
    );
  });

  test('sem ids não toca a rede', () async {
    final adapter = _CrosswalkAdapter(const {});

    expect(await _datasource(adapter).resolveLegacyPdfIds(const []), isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('erro HTTP num lote propaga — sem resultado parcial', () async {
    final ids = [
      for (var i = 0; i < 1100; i++) encodePdfId('ColAdultos/$i.pdf'),
    ];
    final adapter = _CrosswalkAdapter(
      {ids.first: 'https://coldigom.test/assets/praises/p1/m1.pdf'},
      failOnCall: 2,
    );

    await expectLater(
      _datasource(adapter).resolveLegacyPdfIds(ids),
      throwsA(isA<DioException>()),
    );
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/coldigom/coldigom_remote_datasource_crosswalk_test.dart`
Expected: FAIL — `plpcgCrosswalk` e `resolveLegacyPdfIds` não existem.

- [ ] **Step 3: Endpoint**

Em `lib/features/coldigom/data/constants/coldigom_endpoints.dart`, depois de `plpcgCatalog`:

```dart
  /// Crosswalk legado → coldigom (spec 2026-09-23 §7.2): `POST` com
  /// `{"pdfIds": [...]}` (1..500) → `{"items": {pdfId: {praiseId,
  /// materialId, url}}}`; desconhecidos omitidos.
  static const plpcgCrosswalk = '/api/plpcg/crosswalk';
```

- [ ] **Step 4: Método no datasource**

Em `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart`: acrescentar os imports `import 'dart:math' show min;` e `import '../../../../core/utils/pdf_id_codec.dart';`, e dentro da classe `ColdigomRemoteDatasource`, depois de `fetchCatalog`:

```dart
  /// Tamanho máximo de um pedido ao crosswalk (o servidor devolve 400 acima).
  static const int crosswalkBatchSize = 500;

  /// Id coldigom de cada id legado de [legacyPdfIds] (contrato C9).
  ///
  /// `POST /api/plpcg/crosswalk` em lotes de [crosswalkBatchSize]. O id
  /// coldigom sai da `url` real do material ([coldigomPdfIdFromAssetUrl]) —
  /// é ela que acerta os materiais movidos. Desconhecidos (e URLs fora de
  /// `assets/praises/`) ficam de fora do mapa.
  ///
  /// Um erro HTTP em qualquer lote propaga como [DioException]: quem chama
  /// trata a rodada inteira como pendente, nunca um resultado parcial.
  Future<Map<String, String>> resolveLegacyPdfIds(
    Iterable<String> legacyPdfIds,
  ) async {
    final ids = legacyPdfIds.toSet().toList(growable: false);
    final resolved = <String, String>{};
    for (var start = 0; start < ids.length; start += crosswalkBatchSize) {
      final batch = ids.sublist(
        start,
        min(start + crosswalkBatchSize, ids.length),
      );
      final asked = batch.toSet();
      final response = await _dio.post<Map<String, dynamic>>(
        ColdigomEndpoints.plpcgCrosswalk,
        data: {'pdfIds': batch},
      );
      final items = response.data?['items'];
      if (items is! Map) continue;
      for (final MapEntry(:key, :value) in items.entries) {
        if (key is! String || !asked.contains(key) || value is! Map) continue;
        final url = value['url'];
        if (url is! String) continue;
        final coldigomId = coldigomPdfIdFromAssetUrl(url);
        if (coldigomId != null) resolved[key] = coldigomId;
      }
    }
    return resolved;
  }
```

- [ ] **Step 5: Correr**

Run: `flutter test test/unit/features/coldigom/ && flutter analyze`
Expected: PASS, analyze limpo.

- [ ] **Step 6: Commit**

```bash
git add lib/features/coldigom/data/constants/coldigom_endpoints.dart lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart test/unit/features/coldigom/coldigom_remote_datasource_crosswalk_test.dart
git commit -m "feat(coldigom): resolveLegacyPdfIds pelo crosswalk em lotes de 500

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Porta `LegacyIdStore` e use case `NormalizeLegacyMaterialIds`

Uma rodada: recolhe os ids legados de todas as stores, pergunta ao crosswalk **uma vez**, e entrega a mesma resposta a cada store com ids legados. Sem ids legados não há rede nem escrita; com o crosswalk a falhar, nada é escrito e a rodada fica pendente (spec §6.2, §8). Não há flag de «feito»: é idempotente.

**Files:**
- Create: `lib/features/catalog/domain/legacy_ids/legacy_id_store.dart`
- Create: `lib/features/catalog/domain/usecases/normalize_legacy_material_ids.dart`
- Test: `test/unit/features/catalog/normalize_legacy_material_ids_test.dart`

**Interfaces:**
- Produces:
  - `final class LegacyIdResolution({required Set<String> queried, required Map<String, String> resolved})` com `queried`, `resolved`, `bool isUnknown(String id)`, `String? rewrite(String id)` (id coldigom se resolvido; `null` se perguntado e desconhecido; o próprio `id` caso contrário).
  - `abstract interface class LegacyIdStore { String get name; Future<Set<String>> collectLegacyIds(); Future<int> rewrite(LegacyIdResolution resolution); }` — `rewrite` devolve quantos registos mudaram.
  - `typedef LegacyPdfIdResolver = Future<Map<String, String>> Function(Iterable<String> legacyPdfIds);`
  - `final class LegacyIdNormalizationOutcome({int legacy = 0, int resolved = 0, int rewritten = 0, bool pending = false})` com `static const nothingToDo` e `int get unknown`.
  - `class NormalizeLegacyMaterialIds({required List<LegacyIdStore> stores, required LegacyPdfIdResolver resolve})` com `Future<LegacyIdNormalizationOutcome> call()` — nunca lança.

- [ ] **Step 1: Teste**

```dart
// test/unit/features/catalog/normalize_legacy_material_ids_test.dart
import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/catalog/domain/usecases/normalize_legacy_material_ids.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements LegacyIdStore {
  _FakeStore(
    this.name,
    this.ids, {
    this.collectThrows,
    this.rewriteThrows,
    this.rewriteResult = 1,
  });

  @override
  final String name;
  final Set<String> ids;
  final Object? collectThrows;
  final Object? rewriteThrows;
  final int rewriteResult;
  final received = <LegacyIdResolution>[];

  @override
  Future<Set<String>> collectLegacyIds() async {
    final error = collectThrows;
    if (error != null) throw error;
    return ids;
  }

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    final error = rewriteThrows;
    if (error != null) throw error;
    received.add(resolution);
    return rewriteResult;
  }
}

class _Resolver {
  _Resolver(this.answer, {this.error});

  final Map<String, String> answer;
  final Object? error;
  final calls = <Set<String>>[];

  Future<Map<String, String>> call(Iterable<String> ids) async {
    calls.add(ids.toSet());
    final e = error;
    if (e != null) throw e;
    return answer;
  }
}

void main() {
  group('LegacyIdResolution.rewrite', () {
    final resolution = LegacyIdResolution(
      queried: {'l1', 'l2'},
      resolved: {'l1': 'x1'},
    );

    test('resolvido → id coldigom; desconhecido → null; outro → ele mesmo', () {
      expect(resolution.rewrite('l1'), 'x1');
      expect(resolution.rewrite('l2'), isNull);
      expect(resolution.isUnknown('l2'), isTrue);
      expect(resolution.rewrite('novo-depois-da-coleta'), 'novo-depois-da-coleta');
      expect(resolution.isUnknown('novo-depois-da-coleta'), isFalse);
    });
  });

  test('sem ids legados não há rede nem escrita', () async {
    final store = _FakeStore('a', const {});
    final resolver = _Resolver(const {});

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [store],
      resolve: resolver.call,
    )();

    expect(outcome.legacy, 0);
    expect(outcome.pending, isFalse);
    expect(resolver.calls, isEmpty);
    expect(store.received, isEmpty);
  });

  test('junta os ids de todas as stores numa pergunta só', () async {
    final a = _FakeStore('a', {'l1', 'l2'});
    final b = _FakeStore('b', {'l2', 'l3'});
    final vazia = _FakeStore('vazia', const {});
    final resolver = _Resolver({'l1': 'x1', 'l3': 'x3'});

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [a, b, vazia],
      resolve: resolver.call,
    )();

    expect(resolver.calls, [
      {'l1', 'l2', 'l3'},
    ]);
    expect(a.received.single.queried, {'l1', 'l2', 'l3'});
    expect(identical(a.received.single, b.received.single), isTrue);
    expect(vazia.received, isEmpty, reason: 'store sem legados não reescreve');
    expect(outcome.legacy, 3);
    expect(outcome.resolved, 2);
    expect(outcome.unknown, 1);
    expect(outcome.rewritten, 2);
  });

  test('resolve falha → pendente, nenhuma store reescrita', () async {
    final a = _FakeStore('a', {'l1'});
    final resolver = _Resolver(const {}, error: StateError('sem rede'));

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [a],
      resolve: resolver.call,
    )();

    expect(outcome.pending, isTrue);
    expect(outcome.legacy, 1);
    expect(a.received, isEmpty);
  });

  test('uma store que falha (coleta ou escrita) não trava as outras', () async {
    final quebraColeta = _FakeStore('c', {'l9'}, collectThrows: StateError('x'));
    final quebraEscrita = _FakeStore('e', {'l1'}, rewriteThrows: StateError('y'));
    final boa = _FakeStore('b', {'l1'});
    final resolver = _Resolver({'l1': 'x1'});

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [quebraColeta, quebraEscrita, boa],
      resolve: resolver.call,
    )();

    expect(resolver.calls.single, {'l1'});
    expect(boa.received, hasLength(1));
    expect(outcome.rewritten, 1);
  });

  test('chave que não foi perguntada é ignorada', () async {
    final a = _FakeStore('a', {'l1'});
    final resolver = _Resolver({'l1': 'x1', 'intrusa': 'x9'});

    await NormalizeLegacyMaterialIds(stores: [a], resolve: resolver.call)();

    expect(a.received.single.resolved, {'l1': 'x1'});
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/normalize_legacy_material_ids_test.dart`
Expected: FAIL — ficheiros não existem.

- [ ] **Step 3: Porta**

```dart
// lib/features/catalog/domain/legacy_ids/legacy_id_store.dart

/// Resposta do crosswalk para os ids legados de uma rodada (spec 2026-09-23
/// §6.2).
final class LegacyIdResolution {
  LegacyIdResolution({
    required Set<String> queried,
    required Map<String, String> resolved,
  }) : queried = Set.unmodifiable(queried),
       resolved = Map.unmodifiable(resolved);

  /// Ids legados perguntados ao crosswalk nesta rodada.
  final Set<String> queried;

  /// Id legado → id coldigom (só os que o crosswalk conhece).
  final Map<String, String> resolved;

  /// `true` quando o crosswalk foi perguntado sobre [id] e não o conhece.
  bool isUnknown(String id) =>
      queried.contains(id) && !resolved.containsKey(id);

  /// O que fica no lugar de [id]: o id coldigom; `null` se é um legado
  /// desconhecido; o próprio [id] quando não foi perguntado (não é legado,
  /// ou apareceu depois da coleta — fica para a próxima rodada).
  String? rewrite(String id) {
    final mapped = resolved[id];
    if (mapped != null) return mapped;
    return isUnknown(id) ? null : id;
  }
}

/// Um sítio do aparelho que guarda ids de material (spec §6.2, facto M9).
///
/// Cada store decide o que fazer com um id desconhecido (a playlist mantém,
/// o índice offline apaga a linha, as prefs descartam) — a tabela do §6.2.
abstract interface class LegacyIdStore {
  /// Nome curto para o log.
  String get name;

  /// Ids legados guardados agora; vazio = nada a fazer aqui.
  Future<Set<String>> collectLegacyIds();

  /// Reescreve com [resolution]; devolve quantos registos mudaram.
  Future<int> rewrite(LegacyIdResolution resolution);
}
```

- [ ] **Step 4: Use case**

```dart
// lib/features/catalog/domain/usecases/normalize_legacy_material_ids.dart
import 'package:flutter/foundation.dart';

import '../legacy_ids/legacy_id_store.dart';

/// Crosswalk legado → coldigom (C9: `ColdigomRemoteDatasource.resolveLegacyPdfIds`).
typedef LegacyPdfIdResolver =
    Future<Map<String, String>> Function(Iterable<String> legacyPdfIds);

/// Desfecho de uma rodada de [NormalizeLegacyMaterialIds].
final class LegacyIdNormalizationOutcome {
  const LegacyIdNormalizationOutcome({
    this.legacy = 0,
    this.resolved = 0,
    this.rewritten = 0,
    this.pending = false,
  });

  static const nothingToDo = LegacyIdNormalizationOutcome();

  /// Ids legados distintos encontrados.
  final int legacy;

  /// Quantos o crosswalk conhecia.
  final int resolved;

  /// Registos reescritos, somados de todas as stores.
  final int rewritten;

  /// Crosswalk indisponível: nada foi escrito, tenta no próximo gatilho.
  final bool pending;

  /// Legados que o crosswalk não conhece (0 enquanto [pending]).
  int get unknown => pending ? 0 : legacy - resolved;
}

/// Normaliza **uma vez** os ids legados guardados no aparelho (spec §6.2).
///
/// Recolhe os ids de todas as [stores], pergunta ao crosswalk numa só
/// chamada e entrega a mesma [LegacyIdResolution] a cada store que tinha
/// legados. Sem legados não há rede nem escrita; [resolve] a falhar deixa
/// tudo como está ([LegacyIdNormalizationOutcome.pending]). Uma store que
/// falha não trava as outras. Idempotente — sem flag de «feito», e por isso
/// também apanha ids legados que um cliente antigo volte a empurrar.
class NormalizeLegacyMaterialIds {
  const NormalizeLegacyMaterialIds({
    required this.stores,
    required this.resolve,
  });

  final List<LegacyIdStore> stores;
  final LegacyPdfIdResolver resolve;

  Future<LegacyIdNormalizationOutcome> call() async {
    final withLegacy = <LegacyIdStore>[];
    final all = <String>{};
    for (final store in stores) {
      try {
        final ids = await store.collectLegacyIds();
        if (ids.isEmpty) continue;
        withLegacy.add(store);
        all.addAll(ids);
      } on Object catch (e) {
        debugPrint('[legacy-ids] ${store.name}: coleta falhou: $e');
      }
    }
    if (all.isEmpty) return LegacyIdNormalizationOutcome.nothingToDo;

    final Map<String, String> answer;
    try {
      answer = await resolve(all);
    } on Object catch (e) {
      debugPrint('[legacy-ids] ${all.length} ids legados pendentes: $e');
      return LegacyIdNormalizationOutcome(legacy: all.length, pending: true);
    }

    final resolution = LegacyIdResolution(
      queried: all,
      resolved: {
        for (final MapEntry(:key, :value) in answer.entries)
          if (all.contains(key)) key: value,
      },
    );
    var rewritten = 0;
    for (final store in withLegacy) {
      try {
        rewritten += await store.rewrite(resolution);
      } on Object catch (e) {
        debugPrint('[legacy-ids] ${store.name}: reescrita falhou: $e');
      }
    }
    final resolved = resolution.resolved.length;
    // O log conta os casos: é por ele que se decide remover o normalizador
    // (spec §12, follow-up).
    debugPrint(
      '[legacy-ids] ${all.length} legados: $resolved resolvidos, '
      '${all.length - resolved} desconhecidos, $rewritten registos reescritos',
    );
    return LegacyIdNormalizationOutcome(
      legacy: all.length,
      resolved: resolved,
      rewritten: rewritten,
    );
  }
}
```

- [ ] **Step 5: Correr**

Run: `flutter test test/unit/features/catalog/normalize_legacy_material_ids_test.dart && flutter analyze`
Expected: PASS, analyze limpo.

- [ ] **Step 6: Commit**

```bash
git add lib/features/catalog/domain/legacy_ids/legacy_id_store.dart lib/features/catalog/domain/usecases/normalize_legacy_material_ids.dart test/unit/features/catalog/normalize_legacy_material_ids_test.dart
git commit -m "feat(ids): NormalizeLegacyMaterialIds — uma pergunta ao crosswalk por rodada

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Stores com Isar — playlists e índice offline

Regras do §6.2: a playlist troca o id mantendo `kind` e ordem pelo `PlaylistRepository.update(entries:)` (que já serializa escritas e marca `pendingPush` nas salvas), **preservando `conflict`**; id desconhecido fica. O índice offline usa `remapPdfId` (o ficheiro fica em `storagePath`; em colisão a linha legada sai) sob o `offlineMaintenanceLockProvider`; id desconhecido perde a linha e o ficheiro órfão fica para o reconcile (`listOrphans`).

**Files:**
- Create: `lib/features/playlists/data/legacy/playlist_legacy_id_store.dart`
- Create: `lib/features/offline/data/legacy/offline_index_legacy_id_store.dart`
- Modify: `lib/features/offline/presentation/providers/offline_maintenance_lock_provider.dart:5` (dono novo `normalize`)
- Test: `test/unit/features/playlists/playlist_legacy_id_store_test.dart`, `test/unit/features/offline/offline_index_legacy_id_store_test.dart`

**Interfaces:**
- Consumes: `LegacyIdStore`, `LegacyIdResolution` (Tarefa 3); `isLegacyPdfId` (Tarefa 1); `PlaylistRepository.getAll()`/`update(String, {List<PlaylistEntry>? entries, PlaylistSyncStatus? syncStatus})`; `OfflinePdfRepository.listAll()`/`remapPdfId({required String fromPdfId, required String toPdfId})`/`removeIndexEntries(Set<String>)`.
- Produces: `class PlaylistLegacyIdStore(PlaylistRepository)`; `class OfflineIndexLegacyIdStore(OfflinePdfRepository, {required bool Function() tryLock, required void Function() unlock})`; `OfflineMaintenanceOwner.normalize`.

- [ ] **Step 1: Teste das playlists (Isar real)**

```dart
// test/unit/features/playlists/playlist_legacy_id_store_test.dart
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/legacy/playlist_legacy_id_store.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _legadoB = encodePdfId('ColAdultos/002.pdf');
final _desconhecido = encodePdfId('ColAdultos/999.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomB = encodePdfId('assets/praises/p2/m2.pdf');
final _audio = encodePdfId('assets/praises/p1/a.mp3');

final _ontem = DateTime.utc(2026, 9, 22, 12);

LegacyIdResolution _resolution() => LegacyIdResolution(
  queried: {_legadoA, _legadoB, _desconhecido},
  // Os dois legados caem no mesmo material coldigom (duplicata do PLPCG).
  resolved: {_legadoA: _coldigomA, _legadoB: _coldigomA},
);

SavedPlaylist _playlist(
  String id,
  List<PlaylistEntry> entries, {
  bool salva = true,
  PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
}) => SavedPlaylist(
  playlistId: id,
  nome: 'Culto $id',
  createdAt: _ontem,
  updatedAt: _ontem,
  entries: entries,
  salva: salva,
  syncStatus: syncStatus,
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl repository;
  late PlaylistLegacyIdStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('legacy_playlists_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    store = PlaylistLegacyIdStore(repository);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('collect junta só os PDFs legados de todas as listas', () async {
    await repository.upsert(
      _playlist('a', [
        PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audio, kind: MaterialKind.audio),
      ]),
    );
    await repository.upsert(
      _playlist('b', [PlaylistEntry(id: _coldigomB, kind: MaterialKind.pdf)]),
    );

    expect(await store.collectLegacyIds(), {_legadoA});
  });

  test(
    'troca os ids mantendo kind, ordem e repetidos; desconhecido fica; salva sobe',
    () async {
      await repository.upsert(
        _playlist('a', [
          PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _audio, kind: MaterialKind.audio),
          PlaylistEntry(id: _legadoB, kind: MaterialKind.pdf),
          PlaylistEntry(id: _desconhecido, kind: MaterialKind.pdf),
        ]),
      );

      expect(await store.rewrite(_resolution()), 1);

      final after = (await repository.getById('a'))!;
      expect(after.entries, [
        PlaylistEntry(id: _coldigomA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audio, kind: MaterialKind.audio),
        PlaylistEntry(id: _coldigomA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _desconhecido, kind: MaterialKind.pdf),
      ]);
      expect(after.syncStatus, PlaylistSyncStatus.pendingPush);
      expect(after.updatedAt.isAfter(_ontem), isTrue);
    },
  );

  test('conflito continua conflito', () async {
    await repository.upsert(
      _playlist(
        'c',
        [PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf)],
        syncStatus: PlaylistSyncStatus.conflict,
      ),
    );

    await store.rewrite(_resolution());

    final after = (await repository.getById('c'))!;
    expect(after.entries.single.id, _coldigomA);
    expect(after.syncStatus, PlaylistSyncStatus.conflict);
  });

  test('rascunho não vira pendingPush', () async {
    await repository.upsert(
      _playlist(
        'r',
        [PlaylistEntry(id: _legadoA, kind: MaterialKind.pdf)],
        salva: false,
      ),
    );

    await store.rewrite(_resolution());

    final after = (await repository.getById('r'))!;
    expect(after.entries.single.id, _coldigomA);
    expect(after.syncStatus, PlaylistSyncStatus.synced);
  });

  test('lista sem legado resolvido não é tocada', () async {
    await repository.upsert(
      _playlist('d', [
        PlaylistEntry(id: _desconhecido, kind: MaterialKind.pdf),
        PlaylistEntry(id: _coldigomB, kind: MaterialKind.pdf),
      ]),
    );

    expect(await store.rewrite(_resolution()), 0);

    final after = (await repository.getById('d'))!;
    expect(after.updatedAt.isAtSameMomentAs(_ontem), isTrue);
    expect(after.syncStatus, PlaylistSyncStatus.synced);
  });
}
```

- [ ] **Step 2: Teste do índice offline (Isar + disco reais)**

```dart
// test/unit/features/offline/offline_index_legacy_id_store_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/legacy/offline_index_legacy_id_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import 'offline_test_helpers.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _desconhecido = encodePdfId('ColAdultos/999.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomB = encodePdfId('assets/praises/p2/m2.pdf');

LegacyIdResolution _resolution() => LegacyIdResolution(
  queried: {_legadoA, _desconhecido},
  resolved: {_legadoA: _coldigomA},
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflinePdfRepositoryImpl repository;
  var lockFree = true;
  var unlocks = 0;

  OfflineIndexLegacyIdStore store() => OfflineIndexLegacyIdStore(
    repository,
    tryLock: () => lockFree,
    unlock: () => unlocks++,
  );

  Future<String> seed(String pdfId) async {
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      category: 'x',
      isPersistent: true,
    );
    return entry.absolutePath;
  }

  setUp(() async {
    lockFree = true;
    unlocks = 0;
    tempDir = await Directory.systemTemp.createTemp('legacy_offline_');
    final docsDir = Directory('${tempDir.path}/docs')
      ..createSync(recursive: true);
    isar = openOfflineTestIsar(tempDir);
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(
        PdfLocalStore(getApplicationDocumentsDirectory: () async => docsDir),
      ),
      local: OfflinePdfLocalDatasource(isar),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('collect só devolve PDFs legados do índice', () async {
    await seed(_legadoA);
    await seed(_coldigomB);

    expect(await store().collectLegacyIds(), {_legadoA});
  });

  test('resolvido: a linha passa ao id coldigom com o mesmo ficheiro', () async {
    final path = await seed(_legadoA);

    expect(await store().rewrite(_resolution()), 1);

    expect(await repository.findIndexEntry(_legadoA), isNull);
    final remapped = await repository.findIndexEntry(_coldigomA);
    expect(remapped?.absolutePath, path);
    expect(remapped?.isPersistent, isTrue);
    expect(unlocks, 1);
  });

  test('colisão: já baixado com o id coldigom → a linha legada sai', () async {
    await seed(_legadoA);
    final coldigomPath = await seed(_coldigomA);

    await store().rewrite(_resolution());

    expect(await repository.findIndexEntry(_legadoA), isNull);
    expect((await repository.findIndexEntry(_coldigomA))?.absolutePath, coldigomPath);
  });

  test('desconhecido: a linha sai e o ficheiro fica para o reconcile', () async {
    final path = await seed(_desconhecido);

    expect(await store().rewrite(_resolution()), 1);

    expect(await repository.findIndexEntry(_desconhecido), isNull);
    expect(File(path).existsSync(), isTrue);
  });

  test('manutenção ocupada: não mexe e não liberta o lock alheio', () async {
    await seed(_legadoA);
    lockFree = false;

    expect(await store().rewrite(_resolution()), 0);

    expect(await repository.findIndexEntry(_legadoA), isNotNull);
    expect(unlocks, 0);
  });
}
```

`encodePdfId` chega por `offline_test_helpers.dart` (ele reexporta `pdf_id_codec.dart`).

- [ ] **Step 3: Correr e ver falhar**

Run: `flutter test test/unit/features/playlists/playlist_legacy_id_store_test.dart test/unit/features/offline/offline_index_legacy_id_store_test.dart`
Expected: FAIL — as stores não existem.

- [ ] **Step 4: Store das playlists**

```dart
// lib/features/playlists/data/legacy/playlist_legacy_id_store.dart
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../catalog/domain/legacy_ids/legacy_id_store.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/repositories/playlist_repository.dart';

/// `Playlist.items` + `pdfIds` (spec 2026-09-23 §6.2).
///
/// Troca cada id legado resolvido mantendo o `kind` e a ordem, pelo
/// [PlaylistRepository.update] — que serializa as escritas, reprojeta
/// `pdfIds`/`audioIds` e marca `pendingPush` nas salvas (o push leva a lista
/// normalizada ao D1). Id desconhecido fica: aparece como indisponível e o
/// usuário remove.
class PlaylistLegacyIdStore implements LegacyIdStore {
  const PlaylistLegacyIdStore(this._repository);

  final PlaylistRepository _repository;

  @override
  String get name => 'playlists';

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final playlist in await _repository.getAll())
      for (final entry in playlist.entries)
        if (isLegacyPdfId(entry.id)) entry.id,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    var changed = 0;
    for (final playlist in await _repository.getAll()) {
      var touched = false;
      final next = <PlaylistEntry>[];
      for (final entry in playlist.entries) {
        final mapped = resolution.resolved[entry.id];
        if (mapped == null) {
          next.add(entry);
          continue;
        }
        next.add(PlaylistEntry(id: mapped, kind: entry.kind));
        touched = true;
      }
      if (!touched) continue;
      await _repository.update(
        playlist.playlistId,
        entries: next,
        // `update` marcaria `pendingPush`; um conflito continua conflito — o
        // banner conta-o e o push ignora-o até o usuário decidir.
        syncStatus: playlist.syncStatus == PlaylistSyncStatus.conflict
            ? PlaylistSyncStatus.conflict
            : null,
      );
      changed++;
    }
    return changed;
  }
}
```

- [ ] **Step 5: Dono `normalize` no lock**

Em `lib/features/offline/presentation/providers/offline_maintenance_lock_provider.dart`, trocar o enum por:

```dart
/// Quem pode segurar o lock de manutenção offline (spec C.1 / B14).
///
/// `normalize` é a troca de ids legados do índice (spec fim-fonte-plpcg §6.2).
enum OfflineMaintenanceOwner {
  bulk,
  missing,
  clear,
  reconcile,
  coldigom,
  normalize,
}
```

(`bulk`, `missing` e `clear` saem na Tarefa 10.)

- [ ] **Step 6: Store do índice offline**

```dart
// lib/features/offline/data/legacy/offline_index_legacy_id_store.dart
import 'package:flutter/foundation.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../../../catalog/domain/legacy_ids/legacy_id_store.dart';
import '../../domain/repositories/offline_pdf_repository.dart';

/// `OfflinePdfIndex` (spec 2026-09-23 §6.2).
///
/// Resolvido → [OfflinePdfRepository.remapPdfId]: o ficheiro fica onde está e
/// só a chave muda (se o id coldigom já estava indexado, a linha legada sai).
/// Desconhecido → a linha sai; o ficheiro órfão é limpo pelo reconcile
/// (`listOrphans`). Reescreve sob o lock de manutenção: com outro dono (um
/// download, o reconcile) não mexe, e a próxima rodada tenta de novo.
class OfflineIndexLegacyIdStore implements LegacyIdStore {
  const OfflineIndexLegacyIdStore(
    this._repository, {
    required bool Function() tryLock,
    required void Function() unlock,
  }) : _tryLock = tryLock, // ignore: prefer_initializing_formals
       _unlock = unlock; // ignore: prefer_initializing_formals

  final OfflinePdfRepository _repository;
  final bool Function() _tryLock;
  final void Function() _unlock;

  @override
  String get name => 'offline';

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final entry in await _repository.listAll())
      if (isLegacyPdfId(entry.pdfId)) entry.pdfId,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    if (!_tryLock()) {
      debugPrint('[legacy-ids] offline: manutenção ocupada, fica para depois');
      return 0;
    }
    try {
      var changed = 0;
      final unknown = <String>{};
      for (final entry in await _repository.listAll()) {
        final id = entry.pdfId;
        final mapped = resolution.resolved[id];
        if (mapped != null) {
          await _repository.remapPdfId(fromPdfId: id, toPdfId: mapped);
          changed++;
        } else if (resolution.isUnknown(id)) {
          unknown.add(id);
        }
      }
      if (unknown.isNotEmpty) {
        changed += await _repository.removeIndexEntries(unknown);
      }
      return changed;
    } finally {
      _unlock();
    }
  }
}
```

- [ ] **Step 7: Correr**

Run: `flutter test test/unit/features/playlists/playlist_legacy_id_store_test.dart test/unit/features/offline/offline_index_legacy_id_store_test.dart test/unit/features/offline/offline_maintenance_lock_test.dart && flutter analyze`
Expected: PASS, analyze limpo.

- [ ] **Step 8: Commit**

```bash
git add lib/features/playlists/data/legacy/playlist_legacy_id_store.dart lib/features/offline/data/legacy/offline_index_legacy_id_store.dart lib/features/offline/presentation/providers/offline_maintenance_lock_provider.dart test/unit/features/playlists/playlist_legacy_id_store_test.dart test/unit/features/offline/offline_index_legacy_id_store_test.dart
git commit -m "feat(ids): stores de playlists e do índice offline para a normalização

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Stores de prefs — `recentlyOpened`, `pdfLastPages`, `carousel_focused_pdf_id`

Regras do §6.2: `recentlyOpened` troca sem repetidos (descarta desconhecido); `pdfLastPages` troca o `id` e em colisão fica a entrada **mais recente** (o LRU guarda do mais antigo ao mais recente); `carousel_focused_pdf_id` troca a parte do id e mantém `#n` (desconhecido → pref apagada, o foco cai no início). O formato do LRU é privado do `ReaderPreferencesDatasource`, que ganha dois métodos em vez de a store o reimplementar.

**Files:**
- Modify: `lib/features/pdf_reader/data/datasources/reader_preferences_datasource.dart`
- Create: `lib/features/catalog/data/legacy_ids/prefs_legacy_id_stores.dart`
- Test: `test/unit/features/catalog/prefs_legacy_id_stores_test.dart`

**Interfaces:**
- Consumes: `LegacyIdStore`, `LegacyIdResolution` (Tarefa 3); `isLegacyPdfId` (Tarefa 1); `StorageKeys.recentlyOpened`, `StorageKeys.pdfLastPages`.
- Produces:
  - `List<String> ReaderPreferencesDatasource.lastPageIds()` (mais antigo → mais recente);
  - `Future<bool> ReaderPreferencesDatasource.rewriteLastPageIds(String? Function(String id) rewrite)` (`null` tira a entrada; colisão → fica a mais recente; `true` se mudou);
  - `class RecentlyOpenedLegacyIdStore(SharedPreferences)`, `class PdfLastPagesLegacyIdStore(ReaderPreferencesDatasource)`, `class FocusedEntryLegacyIdStore(SharedPreferences, {required String key})`.

- [ ] **Step 1: Teste**

```dart
// test/unit/features/catalog/prefs_legacy_id_stores_test.dart
import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/data/legacy_ids/prefs_legacy_id_stores.dart';
import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/pdf_reader/data/datasources/reader_preferences_datasource.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _desconhecido = encodePdfId('ColAdultos/999.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomB = encodePdfId('assets/praises/p2/m2.pdf');

LegacyIdResolution _resolution() => LegacyIdResolution(
  queried: {_legadoA, _desconhecido},
  resolved: {_legadoA: _coldigomA},
);

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs;
}

List<Map<String, Object?>> _lastPages(SharedPreferences prefs) =>
    (jsonDecode(prefs.getString(StorageKeys.pdfLastPages)!) as List)
        .cast<Map<String, Object?>>();

void main() {
  group('RecentlyOpenedLegacyIdStore', () {
    test('troca, descarta desconhecido e tira repetidos (mais recente primeiro)', () async {
      final prefs = await _prefs({
        StorageKeys.recentlyOpened: jsonEncode([
          _legadoA,
          _coldigomB,
          _desconhecido,
          _coldigomA,
        ]),
      });
      final store = RecentlyOpenedLegacyIdStore(prefs);

      expect(await store.collectLegacyIds(), {_legadoA, _desconhecido});
      expect(await store.rewrite(_resolution()), 1);
      expect(
        jsonDecode(prefs.getString(StorageKeys.recentlyOpened)!),
        [_coldigomA, _coldigomB],
      );
    });

    test('sem legado não escreve', () async {
      final prefs = await _prefs({
        StorageKeys.recentlyOpened: jsonEncode([_coldigomB]),
      });

      expect(await RecentlyOpenedLegacyIdStore(prefs).rewrite(_resolution()), 0);
    });
  });

  group('PdfLastPagesLegacyIdStore', () {
    test('colisão com entrada mais nova do id coldigom: fica a mais nova', () async {
      final prefs = await _prefs({
        StorageKeys.pdfLastPages: jsonEncode([
          {'id': _legadoA, 'p': 3},
          {'id': _coldigomA, 'p': 7},
          {'id': _desconhecido, 'p': 1},
        ]),
      });
      final store = PdfLastPagesLegacyIdStore(ReaderPreferencesDatasource(prefs));

      expect(await store.collectLegacyIds(), {_legadoA, _desconhecido});
      expect(await store.rewrite(_resolution()), 1);
      expect(_lastPages(prefs), [
        {'id': _coldigomA, 'p': 7},
      ]);
    });

    test('colisão em que o legado é o mais recente: fica a página dele', () async {
      final prefs = await _prefs({
        StorageKeys.pdfLastPages: jsonEncode([
          {'id': _coldigomA, 'p': 7},
          {'id': _legadoA, 'p': 3},
        ]),
      });

      await PdfLastPagesLegacyIdStore(
        ReaderPreferencesDatasource(prefs),
      ).rewrite(_resolution());

      expect(_lastPages(prefs), [
        {'id': _coldigomA, 'p': 3},
      ]);
      expect(ReaderPreferencesDatasource(prefs).lastPageFor(_coldigomA), 3);
    });
  });

  group('FocusedEntryLegacyIdStore', () {
    Future<(SharedPreferences, FocusedEntryLegacyIdStore)> build(
      String? value,
    ) async {
      final prefs = await _prefs({
        kCarouselFocusedPdfIdPrefsKey: ?value,
      });
      return (
        prefs,
        FocusedEntryLegacyIdStore(prefs, key: kCarouselFocusedPdfIdPrefsKey),
      );
    }

    test('mantém o sufixo #n da ocorrência', () async {
      final (prefs, store) = await build('$_legadoA#2');

      expect(await store.collectLegacyIds(), {_legadoA});
      expect(await store.rewrite(_resolution()), 1);
      expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), '$_coldigomA#2');
    });

    test('sem sufixo', () async {
      final (prefs, store) = await build(_legadoA);

      await store.rewrite(_resolution());

      expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), _coldigomA);
    });

    test('desconhecido apaga a pref (o foco cai no início)', () async {
      final (prefs, store) = await build('$_desconhecido#1');

      expect(await store.rewrite(_resolution()), 1);
      expect(prefs.containsKey(kCarouselFocusedPdfIdPrefsKey), isFalse);
    });

    test('id coldigom ou pref ausente: nada a fazer', () async {
      final (_, coldigom) = await build('$_coldigomB#1');
      expect(await coldigom.collectLegacyIds(), isEmpty);
      expect(await coldigom.rewrite(_resolution()), 0);

      final (_, ausente) = await build(null);
      expect(await ausente.collectLegacyIds(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/prefs_legacy_id_stores_test.dart`
Expected: FAIL — ficheiro e métodos não existem.

- [ ] **Step 3: Métodos no `ReaderPreferencesDatasource`**

Em `lib/features/pdf_reader/data/datasources/reader_preferences_datasource.dart`, depois de `saveLastPage`:

```dart
  /// Ids com última página guardada, do mais antigo ao mais recente.
  List<String> lastPageIds() => [
    for (final entry in _readLastPages()) entry.id,
  ];

  /// Reescreve os ids do LRU (normalização de ids legados, spec 2026-09-23
  /// §6.2): [rewrite] devolve o id novo, o mesmo, ou `null` (a entrada sai).
  /// Duas entradas que acabam no mesmo id: fica a mais recente. Devolve
  /// `true` se gravou alguma coisa.
  Future<bool> rewriteLastPageIds(String? Function(String id) rewrite) async {
    final entries = _readLastPages();
    final seen = <String>{};
    final keptNewestFirst = <_LastPageEntry>[];
    // Do mais recente (fim) para o mais antigo: o primeiro a ocupar um id vence.
    for (final entry in entries.reversed) {
      final id = rewrite(entry.id);
      if (id == null || !seen.add(id)) continue;
      keptNewestFirst.add(_LastPageEntry(id: id, page: entry.page));
    }
    final next = keptNewestFirst.reversed.toList(growable: false);
    var changed = next.length != entries.length;
    for (var i = 0; !changed && i < next.length; i++) {
      changed = next[i].id != entries[i].id;
    }
    if (!changed) return false;
    await _prefs.setString(
      StorageKeys.pdfLastPages,
      jsonEncode(next.map((entry) => entry.toJson()).toList()),
    );
    return true;
  }
```

- [ ] **Step 4: Stores**

```dart
// lib/features/catalog/data/legacy_ids/prefs_legacy_id_stores.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../pdf_reader/data/datasources/reader_preferences_datasource.dart';
import '../../domain/legacy_ids/legacy_id_store.dart';

/// «Abertos recentemente» (`StorageKeys.recentlyOpened`, JSON, mais recente
/// primeiro) — spec 2026-09-23 §6.2: troca sem repetidos, desconhecido sai.
///
/// Escreve direto na pref; quem chama invalida o `recentlyOpenedProvider`.
class RecentlyOpenedLegacyIdStore implements LegacyIdStore {
  const RecentlyOpenedLegacyIdStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String get name => 'recentlyOpened';

  List<String> _read() {
    final raw = _prefs.getString(StorageKeys.recentlyOpened);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final id in _read())
      if (isLegacyPdfId(id)) id,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    final current = _read();
    final next = <String>[];
    for (final id in current) {
      final rewritten = resolution.rewrite(id);
      if (rewritten != null && !next.contains(rewritten)) next.add(rewritten);
    }
    if (_sameList(current, next)) return 0;
    await _prefs.setString(StorageKeys.recentlyOpened, jsonEncode(next));
    return 1;
  }
}

/// Última página por PDF (`StorageKeys.pdfLastPages`) — spec §6.2: troca o
/// `id`; em colisão fica a entrada mais recente; desconhecido sai.
class PdfLastPagesLegacyIdStore implements LegacyIdStore {
  const PdfLastPagesLegacyIdStore(this._datasource);

  final ReaderPreferencesDatasource _datasource;

  @override
  String get name => 'pdfLastPages';

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final id in _datasource.lastPageIds())
      if (isLegacyPdfId(id)) id,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async =>
      await _datasource.rewriteLastPageIds(resolution.rewrite) ? 1 : 0;
}

/// Entrada focada da lista ativa (`carousel_focused_pdf_id`, formato `id` ou
/// `id#n` — ver `entryKeyFor`) — spec §6.2: troca a parte do id e mantém o
/// sufixo; desconhecido apaga a pref (o foco cai no início).
///
/// Um id Base64 URL-safe nunca tem `#`, por isso o último `#` separa o
/// sufixo. Quem chama invalida o `carouselFocusedKeyProvider`.
class FocusedEntryLegacyIdStore implements LegacyIdStore {
  const FocusedEntryLegacyIdStore(this._prefs, {required this.key});

  final SharedPreferences _prefs;

  /// `kCarouselFocusedPdfIdPrefsKey` — vem por parâmetro para a camada de
  /// dados não importar a de apresentação das playlists.
  final String key;

  @override
  String get name => 'focusedEntry';

  (String id, String suffix)? _read() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final hash = raw.lastIndexOf('#');
    return hash < 0 ? (raw, '') : (raw.substring(0, hash), raw.substring(hash));
  }

  @override
  Future<Set<String>> collectLegacyIds() async {
    final value = _read();
    return value != null && isLegacyPdfId(value.$1) ? {value.$1} : const <String>{};
  }

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    final value = _read();
    if (value == null) return 0;
    final (id, suffix) = value;
    final next = resolution.rewrite(id);
    if (next == id) return 0;
    if (next == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, '$next$suffix');
    }
    return 1;
  }
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

- [ ] **Step 5: Correr**

Run: `flutter test test/unit/features/catalog/prefs_legacy_id_stores_test.dart test/unit/features/pdf_reader/ && flutter analyze`
Expected: PASS, analyze limpo.

- [ ] **Step 6: Commit**

```bash
git add lib/features/pdf_reader/data/datasources/reader_preferences_datasource.dart lib/features/catalog/data/legacy_ids/prefs_legacy_id_stores.dart test/unit/features/catalog/prefs_legacy_id_stores_test.dart
git commit -m "feat(ids): stores de prefs (recentes, última página, foco) para a normalização

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Provider do normalizador e gatilhos (hydrate da sessão, pull de playlists)

Quando corre (§6.2): depois de o Isar assentar, no `hydratePlaylistSession` (depois do `MigrateCarouselStore`, que já esvazia o `CarouselEntry` — por isso esta coleção não precisa de store), e depois de cada pull de playlists com linhas novas. Sem Isar só as prefs são normalizadas. Nunca atrasa a sessão (`unawaited`), nunca lança. Sem `COLDIGOM_API_BASE_URL` (CI) o resolver falha na hora e a rodada fica pendente, sem rede.

**Files:**
- Create: `lib/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart`
- Modify: `lib/features/playlists/presentation/providers/playlist_session_hydrate.dart`
- Modify: `lib/features/playlists/presentation/providers/playlist_sync_provider.dart` (`_run`)
- Test: `test/unit/features/catalog/legacy_material_ids_normalizer_provider_test.dart` (novo), `test/unit/features/playlists/playlist_session_hydrate_test.dart`, `test/unit/features/playlists/playlist_sync_provider_test.dart`

**Interfaces:**
- Consumes: Tarefas 2–5; `playlistRepositoryProvider`, `offlinePdfRepositoryProvider`, `offlineMaintenanceLockProvider`, `readerPreferencesDatasourceProvider`, `sharedPreferencesProvider`, `isarAvailableProvider`, `coldigomRemoteDatasourceProvider`, `recentlyOpenedProvider`, `carouselFocusedKeyProvider`, `playlistsProvider`, `kCarouselFocusedPdfIdPrefsKey`.
- Produces: `final legacyPdfIdResolverProvider = Provider<LegacyPdfIdResolver>`; `final legacyMaterialIdsNormalizerProvider = NotifierProvider<LegacyMaterialIdsNormalizer, LegacyIdNormalizationOutcome?>`; `class LegacyMaterialIdsNormalizer extends Notifier<LegacyIdNormalizationOutcome?>` com `Future<LegacyIdNormalizationOutcome> run()` (deduplicada; nunca lança).

- [ ] **Step 1: Teste do provider**

```dart
// test/unit/features/catalog/legacy_material_ids_normalizer_provider_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_playlists_notifier.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');

class _Resolver {
  _Resolver(this.answer, {this.gate});

  final Map<String, String> answer;
  final Completer<void>? gate;
  final calls = <Set<String>>[];

  Future<Map<String, String>> call(Iterable<String> ids) async {
    calls.add(ids.toSet());
    await gate?.future;
    return answer;
  }
}

void main() {
  late SharedPreferences prefs;
  late FakePlaylistsNotifier playlists;

  Future<void> boot(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  ProviderContainer container(_Resolver resolver) {
    playlists = FakePlaylistsNotifier();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Sem Isar: só as prefs entram na rodada (spec §6.2).
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
        legacyPdfIdResolverProvider.overrideWithValue(resolver.call),
        playlistsProvider.overrideWith(() => playlists),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('sem Isar normaliza as prefs e recarrega quem as lê', () async {
    await boot({
      StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
      StorageKeys.pdfLastPages: jsonEncode([
        {'id': _legadoA, 'p': 4},
      ]),
      kCarouselFocusedPdfIdPrefsKey: '$_legadoA#1',
    });
    final resolver = _Resolver({_legadoA: _coldigomA});
    final c = container(resolver);
    expect(c.read(carouselFocusedKeyProvider), '$_legadoA#1');

    final outcome = await c
        .read(legacyMaterialIdsNormalizerProvider.notifier)
        .run();

    expect(resolver.calls.single, {_legadoA});
    expect(outcome.rewritten, 3);
    expect(jsonDecode(prefs.getString(StorageKeys.recentlyOpened)!), [
      _coldigomA,
    ]);
    expect(c.read(carouselFocusedKeyProvider), '$_coldigomA#1');
    expect(playlists.reloadCalls, 1);
    expect(c.read(legacyMaterialIdsNormalizerProvider), same(outcome));
  });

  test('sem ids legados não chama o crosswalk nem recarrega', () async {
    await boot({
      StorageKeys.recentlyOpened: jsonEncode([_coldigomA]),
    });
    final resolver = _Resolver(const {});
    final c = container(resolver);

    final outcome = await c
        .read(legacyMaterialIdsNormalizerProvider.notifier)
        .run();

    expect(resolver.calls, isEmpty);
    expect(outcome.legacy, 0);
    expect(playlists.reloadCalls, 0);
  });

  test('duas chamadas simultâneas partilham a rodada', () async {
    await boot({
      StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
    });
    final gate = Completer<void>();
    final resolver = _Resolver({_legadoA: _coldigomA}, gate: gate);
    final c = container(resolver);
    final notifier = c.read(legacyMaterialIdsNormalizerProvider.notifier);

    final first = notifier.run();
    final second = notifier.run();
    gate.complete();
    await Future.wait([first, second]);

    expect(resolver.calls, hasLength(1));
  });

  test('falha inesperada vira pendente e não lança', () async {
    // Sem `sharedPreferencesProvider`: montar as stores explode.
    final c = ProviderContainer(
      overrides: [
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
        legacyPdfIdResolverProvider.overrideWithValue(
          _Resolver(const {}).call,
        ),
      ],
    );
    addTearDown(c.dispose);

    final outcome = await c
        .read(legacyMaterialIdsNormalizerProvider.notifier)
        .run();

    expect(outcome.pending, isTrue);
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/legacy_material_ids_normalizer_provider_test.dart`
Expected: FAIL — o provider não existe.

- [ ] **Step 3: Provider**

```dart
// lib/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../coldigom/data/constants/coldigom_api_config.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../offline/data/legacy/offline_index_legacy_id_store.dart';
import '../../../offline/data/providers/offline_repository_providers.dart';
import '../../../offline/presentation/providers/offline_maintenance_lock_provider.dart';
import '../../../pdf_reader/data/providers/pdf_reader_viewer_providers.dart';
import '../../../playlists/data/legacy/playlist_legacy_id_store.dart';
import '../../../playlists/data/providers/playlist_providers.dart';
import '../../../playlists/presentation/providers/playlist_session_prefs.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../data/legacy_ids/prefs_legacy_id_stores.dart';
import '../../domain/legacy_ids/legacy_id_store.dart';
import '../../domain/usecases/normalize_legacy_material_ids.dart';
import 'recently_opened_provider.dart';

/// Crosswalk legado → coldigom (C9).
///
/// Sem `COLDIGOM_API_BASE_URL` (CI, testes sem dart-define) falha na hora: a
/// rodada fica pendente em vez de tentar rede com a base vazia.
final legacyPdfIdResolverProvider = Provider<LegacyPdfIdResolver>((ref) {
  if (ColdigomApiConfig.isBaseUrlMissing) {
    return (_) async => throw StateError('COLDIGOM_API_BASE_URL ausente');
  }
  return ref.watch(coldigomRemoteDatasourceProvider).resolveLegacyPdfIds;
});

/// Normalização única dos ids legados guardados (spec 2026-09-23 §6.2).
///
/// Gatilhos: `hydratePlaylistSession` e cada pull de playlists com linhas
/// novas (`PlaylistSyncNotifier`). Estado = desfecho da última rodada.
final legacyMaterialIdsNormalizerProvider =
    NotifierProvider<
      LegacyMaterialIdsNormalizer,
      LegacyIdNormalizationOutcome?
    >(LegacyMaterialIdsNormalizer.new);

class LegacyMaterialIdsNormalizer
    extends Notifier<LegacyIdNormalizationOutcome?> {
  Future<LegacyIdNormalizationOutcome>? _inFlight;

  @override
  LegacyIdNormalizationOutcome? build() => null;

  /// Uma rodada; um pedido durante outra recebe o mesmo future. Nunca lança.
  Future<LegacyIdNormalizationOutcome> run() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _run();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<LegacyIdNormalizationOutcome> _run() async {
    try {
      final outcome = await NormalizeLegacyMaterialIds(
        stores: _stores(),
        resolve: ref.read(legacyPdfIdResolverProvider),
      )();
      if (!ref.mounted) return outcome;
      state = outcome;
      if (outcome.rewritten > 0) {
        // As prefs mudaram por baixo dos notifiers que as leram no build, e o
        // `PlaylistsNotifier` não observa o banco (mesma razão do reload pós-
        // sync em `PlaylistSyncNotifier._run`).
        ref.invalidate(recentlyOpenedProvider);
        ref.invalidate(carouselFocusedKeyProvider);
        await ref.read(playlistsProvider.notifier).reload();
      }
      return outcome;
    } on Object catch (e) {
      debugPrint('[legacy-ids] normalização abortada: $e');
      return const LegacyIdNormalizationOutcome(pending: true);
    }
  }

  /// Sem Isar não há playlists nem índice para migrar — só as prefs (§6.2).
  List<LegacyIdStore> _stores() {
    final prefs = ref.read(sharedPreferencesProvider);
    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    return [
      if (ref.read(isarAvailableProvider)) ...[
        PlaylistLegacyIdStore(ref.read(playlistRepositoryProvider)),
        OfflineIndexLegacyIdStore(
          ref.read(offlinePdfRepositoryProvider),
          tryLock: () => lock.tryAcquire(OfflineMaintenanceOwner.normalize),
          unlock: () => lock.release(OfflineMaintenanceOwner.normalize),
        ),
      ],
      RecentlyOpenedLegacyIdStore(prefs),
      PdfLastPagesLegacyIdStore(ref.read(readerPreferencesDatasourceProvider)),
      FocusedEntryLegacyIdStore(prefs, key: kCarouselFocusedPdfIdPrefsKey),
    ];
  }
}
```

Nota: `playlists_provider.dart` importa `playlist_session_hydrate.dart`, que (Step 5) importa este ficheiro, que importa `playlists_provider.dart` — ciclo de imports é legal em Dart e não há ciclo de providers (só `ref.read` em runtime).

- [ ] **Step 4: Correr o teste do provider**

Run: `flutter test test/unit/features/catalog/legacy_material_ids_normalizer_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Gatilho no hydrate**

Em `lib/features/playlists/presentation/providers/playlist_session_hydrate.dart`: acrescentar `import 'dart:async';` e `import '../../../catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart';`; acrescentar a função privada no fim do ficheiro:

```dart
/// Normalização dos ids legados (spec 2026-09-23 §6.2) em segundo plano —
/// nunca atrasa a restauração da sessão; `run()` nunca lança.
void _requestLegacyIdNormalization(Ref ref) {
  unawaited(ref.read(legacyMaterialIdsNormalizerProvider.notifier).run());
}
```

e no corpo de `hydratePlaylistSession`: no ramo sem Isar, antes do `return false`:

```dart
  if (await awaitIsarSettled(ref) != IsarStatus.available) {
    debugPrint('[playlists] hidratação adiada: storage indisponível');
    // Sem Isar ainda dá para normalizar as prefs (spec fim-fonte-plpcg §6.2).
    _requestLegacyIdNormalization(ref);
    return false;
  }
```

e logo depois do bloco `if (createdByMigration != null) { … }` (a migração do carousel já correu e os ids dela já estão na lista):

```dart
  _requestLegacyIdNormalization(ref);
```

Atualizar o doc da função: acrescentar ao último parágrafo «Depois da migração, pede a normalização dos ids legados (em segundo plano).»

- [ ] **Step 6: Gatilho depois do pull**

Em `lib/features/playlists/presentation/providers/playlist_sync_provider.dart`: acrescentar o import `import '../../../catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart';` e, em `_run`, logo depois do bloco `if (result.movedRows && ref.mounted) { … reload(); }`:

```dart
      // Um pull pode trazer ids legados que um cliente antigo empurrou depois
      // da migração do D1: normaliza de novo (spec fim-fonte-plpcg §6.2).
      if (result.pulled > 0 && ref.mounted) {
        unawaited(ref.read(legacyMaterialIdsNormalizerProvider.notifier).run());
      }
```

- [ ] **Step 7: Testes dos gatilhos**

Em `test/unit/features/playlists/playlist_session_hydrate_test.dart`: acrescentar os imports

```dart
import 'package:coldigui/features/catalog/domain/usecases/normalize_legacy_material_ids.dart';
import 'package:coldigui/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart';
```

a classe (antes de `main`):

```dart
/// Conta os pedidos de normalização sem tocar em store nenhuma.
class _CountingNormalizer extends LegacyMaterialIdsNormalizer {
  var runs = 0;

  @override
  Future<LegacyIdNormalizationOutcome> run() async {
    runs++;
    return LegacyIdNormalizationOutcome.nothingToDo;
  }
}
```

e, dentro de `main`, depois do teste «hydrate restaura fila pausada no audioId persistido»:

```dart
  group('pede a normalização dos ids legados (spec fim-fonte-plpcg §6.2)', () {
    Future<int> runsAfterHydrate(IsarStatus status) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final normalizer = _CountingNormalizer();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isarStatusProvider.overrideWithValue(status),
          playlistRepositoryProvider.overrideWithValue(_FakePlaylistRepo(null)),
          carouselLocalDatasourceProvider.overrideWithValue(
            const CarouselLocalDatasource.unavailable(),
          ),
          legacyMaterialIdsNormalizerProvider.overrideWith(() => normalizer),
        ],
      );
      addTearDown(container.dispose);
      await container.read(_hydrateRunnerProvider.notifier).run();
      return normalizer.runs;
    }

    test('com Isar, depois da migração do carousel', () async {
      expect(await runsAfterHydrate(IsarStatus.available), 1);
    });

    test('sem Isar também (só as prefs)', () async {
      expect(await runsAfterHydrate(IsarStatus.unavailable), 1);
    });
  });
```

Em `test/unit/features/playlists/playlist_sync_provider_test.dart`: acrescentar os imports

```dart
import 'package:coldigui/features/catalog/domain/usecases/normalize_legacy_material_ids.dart';
import 'package:coldigui/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart';

import '../../../support/fakes/fake_playlists_notifier.dart';
```

a mesma classe `_CountingNormalizer` (cópia literal da de cima, antes de `main`), e no fim de `main`:

```dart
  group('normalização depois do pull (spec fim-fonte-plpcg §6.2)', () {
    /// Boot com o `sub` já persistido: o listener de auth faz **uma** `sync()`
    /// (sem adoção) — é essa rodada que se observa.
    Future<int> runsAfterSync(PlaylistSyncResult result) async {
      await prefs.setString(_subKey, 'sub-1');
      final normalizer = _CountingNormalizer();
      final container = ProviderContainer(
        overrides: [
          isarInitializerProvider.overrideWith(
            (ref) => Future<Isar>.error(StateError('sem Isar')),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(_LoggedInAuth.new),
          playlistRepositoryProvider.overrideWithValue(_CountingRepository()),
          syncPlaylistsProvider.overrideWithValue(_ScriptedSync(result: result)),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
          legacyMaterialIdsNormalizerProvider.overrideWith(() => normalizer),
        ],
      );
      addTearDown(container.dispose);
      container.read(playlistSyncProvider);
      await container.read(authStateProvider.future);
      await settle();
      return normalizer.runs;
    }

    test('pull com linhas novas pede a normalização', () async {
      expect(await runsAfterSync(const PlaylistSyncResult(pulled: 2)), 1);
    });

    test('sem pull não pede', () async {
      expect(await runsAfterSync(const PlaylistSyncResult(pushed: 1)), 0);
    });
  });
```

(`_LoggedInAuth`, `_CountingRepository`, `_ScriptedSync`, `_subKey`, `prefs` e `settle()` já existem no ficheiro.)

- [ ] **Step 8: Correr**

Run: `flutter test test/unit/features/catalog/ test/unit/features/playlists/ && flutter analyze`
Expected: PASS, analyze limpo.

- [ ] **Step 9: Commit**

```bash
git add lib/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart lib/features/playlists/presentation/providers/playlist_session_hydrate.dart lib/features/playlists/presentation/providers/playlist_sync_provider.dart test/unit/features/catalog/legacy_material_ids_normalizer_provider_test.dart test/unit/features/playlists/playlist_session_hydrate_test.dart test/unit/features/playlists/playlist_sync_provider_test.dart
git commit -m "feat(ids): normalizador no hydrate da sessão e depois de cada pull

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade B — Fim do manifesto (spec §6.4)

Ordem: primeiro os consumidores passam ao catálogo coldigom (Tarefas 7–8), depois o `/offline` perde a secção PLPCG (Tarefas 9–10), e só então a pilha do manifesto (Tarefa 11) e o `LouvorDataSource` (Tarefa 12) são apagados. Cada tarefa compila e fica verde sozinha.

**Destino de cada consumidor do manifesto** (o que sobra depois dos planos 1 e 2 — Tarefa 0 Step 3):

| Consumidor | Hoje lê | Passa a | Tarefa |
|---|---|---|---|
| `catalog_source_provider.dart` (`catalogSourceProvider`, `compositeCatalogSourceProvider`) | `CompositeCatalogSource` (manifest + aliases + coldigom) | `coldigomCatalogSourceProvider`; o composite provider sai | 7 |
| `catalog_material_lookup_provider.dart` | `louvoresByPdfIdProvider` + `manifestMaterialAliasesProvider` | só os caches coldigom | 7 |
| `carousel_swap_material_button.dart` + `findSwapMaterialGroup` | `compositeCatalogSourceProvider` | `coldigomCatalogSourceProvider` | 7 |
| `contribution_context_fields.dart` | `lookup.plpcgLouvoresByPdfId` | `lookup.coldigomLouvoresByPdfId` | 7 |
| `playlists_provider.dart` (`findLouvorByPdfId`) | `louvoresManifestProvider` (log) | lookup coldigom | 7 |
| `playlists_provider.dart` (`build`) | `ref.listen(louvoresManifestProvider)` | `ref.listen(coldigomSearchIndexProvider)` | 8 |
| `app.dart` | `ref.listen(louvoresManifestProvider)` | nada (o `ShellScaffold` já escuta hidratação e sync) | 8 |
| `pdfrx_bootstrap.dart` | espera o manifesto | espera `coldigomCatalogHydrationProvider` | 8 |
| `audio_follow_reader_provider.dart` + `find_material_for_group.dart` | `catalog: manifest.louvores` | só caches | 8 |
| `playlist_list_tile.dart` | doc | doc | 8 |
| `offline_lifecycle_listener.dart` | `catalogChecksumPollProvider` | nada | 8 |
| `offline_core_providers.dart`, `download_missing_pdfs.dart`, `get_offline_stats_by_category.dart`, `list_missing_louvores_by_material.dart`, `clear_offline_cache.dart` | `CatalogLocalDatasource` (`LouvorCache`) | apagados com a secção PLPCG | 10 |
| `catalog_manifest_sync_providers.dart`, `catalog_checksum_poll_provider.dart`, `plpcg_catalog_source_provider.dart`, `louvores_by_pdf_id_provider.dart`, `manifest_material_aliases_provider.dart`, `louvores_manifest_provider.dart` | o próprio manifesto | apagados | 11 |

### Task 7: Fonte e lookup do catálogo = coldigom

`catalogSourceProvider` passa a devolver o `ColdigomCatalogSource` (spec §2.1); o `CatalogMaterialLookup` perde o mapa do manifesto e o alias (id coldigom → id legado), que deixam de existir no app. Os ficheiros do composite e do manifesto continuam a compilar até à Tarefa 11 (os testes deles também).

**Files:**
- Modify: `lib/features/catalog/data/providers/catalog_source_provider.dart`
- Modify: `lib/features/catalog/presentation/providers/catalog_material_lookup_provider.dart`
- Modify: `lib/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart` (`findSwapMaterialGroup`)
- Modify: `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart:32`
- Modify: `lib/features/contributions/presentation/widgets/contribution_context_fields.dart:31-35,186-190`
- Modify: `lib/features/playlists/presentation/providers/playlists_provider.dart:435-463` (`findLouvorByPdfId`)
- Modify: `test/helpers/coldigom_catalog_test_helpers.dart` (criado pelo plano 1, Task 2 — acrescentar um override)
- Test (adaptar): `test/unit/features/catalog/catalog_source_test.dart` (grupo «providers de fonte»), `test/unit/features/catalog/resolve_catalog_material_test.dart`, `test/unit/features/catalog/catalog_material_lookup_test.dart`, `test/unit/features/audio_player/swap_material_group_test.dart`, `test/unit/features/leaflet/generate_leaflet_from_entries_test.dart`, `test/unit/features/pdf_reader/reader_carousel_actions_provider_test.dart`, `test/unit/features/chords/chord_carousel_navigation_test.dart`, `test/unit/features/carousel/carousel_items_provider_test.dart`, `test/widget/features/catalog/home_empty_state_test.dart`, `test/widget/features/pdf_reader/pdf_reader_screen_test.dart`, `test/widget/features/playlists/playlist_tile_detail_chips_test.dart` e o que mais a suíte apontar.

**Interfaces:**
- Consumes: `coldigomCatalogSourceProvider` (`Provider<ColdigomCatalogSource>`), `ColdigomCatalogSource.audioTracks`, `.findGroupById`, `.findGroupForMaterial`.
- Produces: `catalogSourceProvider` (`Provider<CatalogSource>`) = `ref.watch(coldigomCatalogSourceProvider)`; `compositeCatalogSourceProvider` deixa de existir; `CatalogMaterialLookup` sem `plpcgLouvoresByPdfId` nem `legacyPdfIdByColdigomPdfId` (fica `coldigomLouvoresByPdfId` — nome mantido para não mexer nos 6 leitores); `LouvorGroup? findSwapMaterialGroup({String? pdfId, String? audioId, required ColdigomCatalogSource source})`; helper de teste `Override coldigomLouvoresOverride(List<Louvor> louvores)`.

- [ ] **Step 1: Helper de teste**

O ficheiro já existe (plano 1: `catalogGroup`, `catalogIndexOf`, `FakeColdigomCatalogSyncNotifier`, `catalogIndexOverrides`). Acrescentar os imports que faltarem —

```dart
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:flutter_riverpod/misc.dart';
```

— e, no fim do ficheiro:

```dart
/// `coldigomLouvoresCacheProvider` já com [louvores] — o catálogo em memória
/// que o lookup e a fonte leem. Substitui o `louvoresManifestOverride` nos
/// testes que precisavam de PDFs conhecidos (spec fim-fonte-plpcg §6.4).
Override coldigomLouvoresOverride(List<Louvor> louvores) {
  return coldigomLouvoresCacheProvider.overrideWith(
    () => _SeededLouvoresCache(louvores),
  );
}

class _SeededLouvoresCache extends ColdigomLouvoresCacheNotifier {
  _SeededLouvoresCache(this._seed);

  final List<Louvor> _seed;

  @override
  Map<String, Louvor> build() => {for (final l in _seed) l.pdfId: l};
}
```

- [ ] **Step 2: Teste do provider de fonte (falha)**

Em `test/unit/features/catalog/catalog_source_test.dart`, substituir o `group('providers de fonte', …)` inteiro (os dois testes: o de identidade do índice PLPCG e «catalogSourceProvider compõe as duas fontes») por:

```dart
  group('providers de fonte', () {
    test('catalogSourceProvider é a fonte coldigom (spec fim-fonte-plpcg §2.1)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
        _coldigomPdf,
      ]);

      final CatalogSource source = container.read(catalogSourceProvider);

      expect(source, isA<ColdigomCatalogSource>());
      expect(await source.materialById(_coldigomPdfId), isA<PdfMaterial>());
      expect(
        await source.materialById(_plpcgPdfId),
        isNull,
        reason: 'id legado já não é endereçável',
      );
    });
  });
```

Tirar do topo os imports que ficarem sem uso (`louvores_manifest_test_helpers.dart`, `plpcg_catalog_source_provider.dart`, `manifest_material_aliases_provider.dart`, `louvores_manifest_provider.dart` — o analyze aponta).

Em `test/unit/features/catalog/resolve_catalog_material_test.dart`:
- o teste `'resolve PDF do manifest PLPCG'` passa a ser:

```dart
  testWidgets('id legado não resolve (o manifesto já não é fonte)', (
    tester,
  ) async {
    final ref = await _widgetRef(tester);

    expect(await resolveCatalogMaterialFromWidget(ref, _plpcgPdfId), isNull);
  });
```

- o teste `'catalogSourceProvider despacha os dois acervos'` passa a ser:

```dart
  test('catalogSourceProvider lê o catálogo coldigom', () async {
    final container = await _container();
    final source = container.read(catalogSourceProvider);

    expect((await source.groupForMaterial(_coldigomPdfId))!.groupId, 'p1');
    expect(await source.materialById(_plpcgPdfId), isNull);
  });
```

Run: `flutter test test/unit/features/catalog/catalog_source_test.dart test/unit/features/catalog/resolve_catalog_material_test.dart`
Expected: FAIL — `catalogSourceProvider` ainda devolve o composite.

- [ ] **Step 3: `catalogSourceProvider`**

Substituir o conteúdo de `lib/features/catalog/data/providers/catalog_source_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../domain/ports/catalog_source.dart';

/// Porta única de leitura e busca do catálogo — o catálogo coldigom
/// (spec 2026-09-23 §2.1). Quem precisa dos métodos síncronos
/// (`findGroupById`/`findGroupForMaterial`) lê `coldigomCatalogSourceProvider`.
final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return ref.watch(coldigomCatalogSourceProvider);
});
```

- [ ] **Step 4: Trocar material**

Em `lib/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart`: trocar o import `import '../../data/sources/composite_catalog_source.dart';` por `import '../../../coldigom/data/sources/coldigom_catalog_source.dart';` e reescrever `findSwapMaterialGroup`:

```dart
/// Grupo para o botão layers da barra: inclui áudios/cifras do cache e aceita
/// 1 PDF se [LouvorGroup.totalMaterials] > 1.
///
/// Precedência quando os dois ids chegam (face de áudio): manda a faixa
/// tocando ([audioId]) se o [pdfId] for de **outro** louvor — o chip focado no
/// carousel não tem relação com o que está tocando. Com os dois no mesmo
/// grupo o [pdfId] segue mandando.
///
/// Síncrono (a UI decide se mostra o botão durante o build): usa os métodos
/// síncronos da fonte coldigom, que só lê memória.
LouvorGroup? findSwapMaterialGroup({
  String? pdfId,
  String? audioId,
  required ColdigomCatalogSource source,
}) {
  final playingTrack = (audioId == null || audioId.isEmpty)
      ? null
      : source.audioTracks[audioId];
  final playingGroupId =
      (playingTrack == null || playingTrack.groupId.isEmpty)
      ? null
      : playingTrack.groupId;

  final materialGroup = (pdfId == null || pdfId.isEmpty)
      ? null
      : source.findGroupForMaterial(pdfId);

  if (playingGroupId != null && playingGroupId != materialGroup?.groupId) {
    return _multipleOnly(source.findGroupById(playingGroupId));
  }
  if (materialGroup != null) return _multipleOnly(materialGroup);
  if (playingGroupId != null) {
    return _multipleOnly(source.findGroupById(playingGroupId));
  }
  return null;
}
```

(`findLouvorGroupByPdfId` e o import de `plpcg_catalog_source.dart` ficam até à Tarefa 11.)

Em `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart`: trocar o import `package:coldigui/features/catalog/data/providers/catalog_source_provider.dart` por `package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart` e a linha 32 por `source: ref.watch(coldigomCatalogSourceProvider),`.

- [ ] **Step 5: Lookup sem manifesto nem alias**

Em `lib/features/catalog/presentation/providers/catalog_material_lookup_provider.dart`:
- apagar os imports de `louvores_by_pdf_id_provider.dart` e `manifest_material_aliases_provider.dart`;
- no construtor e nos campos, apagar `plpcgLouvoresByPdfId` e `legacyPdfIdByColdigomPdfId` (com os docs);
- doc de `coldigomLouvoresByPdfId`: `/// PDFs do catálogo coldigom em memória, por \`pdfId\`.`;
- `louvor` passa a:

```dart
  /// PDF de [materialId], ou `null` se o catálogo em memória ainda não o tem
  /// (antes da hidratação, ou id legado que o crosswalk não conhece).
  Louvor? louvor(String materialId) => coldigomLouvoresByPdfId[materialId];
```

- o provider:

```dart
/// Lookup síncrono do material por id, sobre os caches do catálogo coldigom.
final catalogMaterialLookupProvider = Provider<CatalogMaterialLookup>((ref) {
  return CatalogMaterialLookup(
    coldigomLouvoresByPdfId: ref.watch(coldigomLouvoresCacheProvider),
    audioTracksById: ref.watch(coldigomAudioTracksCacheProvider),
    chordsById: ref.watch(coldigomChordMaterialsCacheProvider),
    gesturesById: ref.watch(coldigomGestureMaterialsCacheProvider),
    praiseMetaByGroupId: ref.watch(coldigomPraiseMetaCacheProvider),
    youtubeByGroupId: ref.watch(coldigomYoutubeCacheProvider),
  );
});
```

- no doc da classe, trocar «e nenhum sabendo do manifest PLPCG» por «— sempre os caches do catálogo coldigom».

- [ ] **Step 6: Contribuições e playlists**

Em `lib/features/contributions/presentation/widgets/contribution_context_fields.dart`: apagar os dois ramos `for (final l in lookup.plpcgLouvoresByPdfId.values) …` (linhas 32–33) e `...lookup.plpcgLouvoresByPdfId.values,` (linha 188).

Em `lib/features/playlists/presentation/providers/playlists_provider.dart`, substituir `findLouvorByPdfId` inteiro por:

```dart
  /// Louvor do PDF [pdfId] no catálogo em memória — usado ao abrir PDF de
  /// playlist no leitor.
  ///
  /// Lookup O(1) pelo [catalogMaterialLookupProvider] (A4/C.3). `null` se o
  /// catálogo ainda não hidratou ou o id é desconhecido (ex.: legado que o
  /// crosswalk não conhece). Em debug registra via [playlistOpenDebugLog*].
  Louvor? findLouvorByPdfId(String pdfId) {
    final lookup = ref.read(catalogMaterialLookupProvider);
    playlistOpenDebugLog(
      'findLouvorByPdfId: pdfId=$pdfId '
      'catalogo=${lookup.coldigomLouvoresByPdfId.length}',
    );
    final louvor = lookup.louvor(pdfId);
    if (louvor != null) {
      playlistOpenDebugLog(
        'findLouvorByPdfId: encontrado numero=${louvor.numero} '
        'nome="${louvor.nome}"',
      );
      return louvor;
    }
    playlistOpenDebugLogFailure(
      'findLouvorByPdfId',
      'pdfId=$pdfId ausente no catálogo',
    );
    return null;
  }
```

(O `ref.listen(louvoresManifestProvider, …)` do `build` e o import saem na Tarefa 8.)

- [ ] **Step 7: Adaptar a suíte**

Run: `flutter analyze && flutter test`

Corrigir cada falha por uma destas regras (todas mecânicas; nenhuma muda a asserção de comportamento, só a origem do dado):

1. `CatalogMaterialLookup(plpcgLouvoresByPdfId: X)` → `CatalogMaterialLookup(coldigomLouvoresByPdfId: X)` (ex.: `generate_leaflet_from_entries_test.dart:44,83`, `home_empty_state_test.dart:228,463`, `pdf_reader_screen_test.dart:524`).
2. Teste que punha louvores **não vazios** no manifesto para o lookup/fonte os acharem (`louvoresManifestOverride(LouvoresManifest.fromLouvores([…]))`) → acrescentar `coldigomLouvoresOverride([…])` com os mesmos louvores (import `'…/helpers/coldigom_catalog_test_helpers.dart'`). O override do manifesto pode ficar até à Tarefa 11. Se o teste depende de **agrupar** esses louvores (troca de material, «seguir o áudio»), o fixture ganha `praiseId:` igual ao `groupId` esperado — é por ele que `ColdigomCatalogSource.findGroupForMaterial` acha o grupo. Casos conhecidos: `reader_carousel_actions_provider_test.dart:97,149,259`, `chord_carousel_navigation_test.dart:148`, `carousel_items_provider_test.dart:88`, `playlist_tile_detail_chips_test.dart:73,171`, `catalog_material_lookup_test.dart:92`.
3. Testes do **alias** (id coldigom resolvido pelo louvor do manifest com cache frio) testam um comportamento que sai → apagar: em `catalog_material_lookup_test.dart` os que usam `legacyPdfIdByColdigomPdfId` (≈ linhas 225–260); em `reader_carousel_actions_provider_test.dart` o que monta `covered` (≈ linha 196).
4. `swap_material_group_test.dart`: `CompositeCatalogSource(plpcg: …, coldigom: X, …)` → `X` (a `ColdigomCatalogSource`); casos que só existiam para PLPCG × Coldigom (grupo PLPCG pelo manifest, alias) saem; os fixtures dos casos que ficam precisam de `praiseId`.

- [ ] **Step 8: Correr**

Run: `flutter analyze && flutter test`
Expected: analyze limpo, suíte verde.

- [ ] **Step 9: Commit**

```bash
git add -A lib/features/catalog lib/features/carousel lib/features/contributions lib/features/playlists test
git commit -m "refactor(catalog): fonte e lookup do catálogo passam a ser só coldigom

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Boot e listeners sem manifesto

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/features/pdf_reader/data/pdfrx_bootstrap.dart`
- Modify: `lib/features/audio_player/presentation/providers/audio_follow_reader_provider.dart:94-151`
- Modify: `lib/features/audio_player/domain/utils/find_material_for_group.dart`
- Modify: `lib/features/playlists/presentation/providers/playlists_provider.dart` (`build`, imports, doc de `PlaylistViewItem`)
- Modify: `lib/features/playlists/presentation/widgets/playlist_list_tile.dart:33`
- Modify: `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart`
- Test: `test/unit/features/pdf_reader/pdfrx_idle_preloader_test.dart`, `test/unit/features/audio_player/find_material_for_group_test.dart`, `test/unit/features/audio_player/audio_follow_reader_provider_test.dart`

**Interfaces:**
- Consumes: `coldigomCatalogHydrationProvider` (`FutureProvider<ColdigomSearchIndex>`), `coldigomSearchIndexProvider`, `coldigomLouvoresOverride` (Tarefa 7).
- Produces: `findMaterialForGroup({required String groupId, required List<String> carouselPdfIds, required Map<String, Louvor> byPdfId, Map<String, ChordMaterial> chordsById, Map<String, GestureMaterial> gesturesById})` e `groupIdForMaterialId({required String materialId, required Map<String, Louvor> byPdfId, Map<String, ChordMaterial> chordsById, Map<String, GestureMaterial> gesturesById})` — sem o parâmetro `catalog`.

- [ ] **Step 1: Teste do preload do pdfium (falha)**

Substituir, em `test/unit/features/pdf_reader/pdfrx_idle_preloader_test.dart`, os imports do manifesto e a classe `_GatedManifestNotifier` pela hidratação do catálogo:

```dart
import 'dart:async';

import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/pdf_reader/data/pdfrx_bootstrap.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_prefetch_providers.dart';
import 'package:coldigui/features/pdf_reader/domain/ports/network_connection_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
```

`pumpPreloader` passa a receber `required Future<ColdigomSearchIndex> Function() hydration` e o override vira `coldigomCatalogHydrationProvider.overrideWith((ref) => hydration())`. Nos testes: `Completer<LouvoresManifest>` → `Completer<ColdigomSearchIndex>`; `emptyManifest` → `ColdigomSearchIndex.empty`; o parâmetro `manifest:` → `hydration:`; os nomes passam a «enquanto a hidratação do catálogo não resolve», «agenda 3 s depois de a hidratação resolver», «erro da hidratação também libera o preload». As asserções e os tempos não mudam.

Run: `flutter test test/unit/features/pdf_reader/pdfrx_idle_preloader_test.dart`
Expected: FAIL — o preloader ainda espera o manifesto (o primeiro teste agenda aos 3 s sem esperar o gate).

- [ ] **Step 2: Preloader espera a hidratação**

Em `lib/features/pdf_reader/data/pdfrx_bootstrap.dart`: trocar o import do manifesto por `import '../../coldigom/presentation/providers/coldigom_catalog_providers.dart';`; a constante e os docs:

```dart
/// Ociosidade exigida depois do catálogo antes de buscar o `pdfium.wasm` (A11).
const pdfrxPreloadIdleDelay = Duration(seconds: 3);
```

```dart
/// Agenda [schedulePdfrxIdlePreload] só depois que o catálogo sai da frente (A11).
///
/// O `pdfium.wasm` tem 5,2 MB e o catálogo coldigom (~950 KB comprimidos)
/// compete pela mesma banda no boot. Aqui o preload espera
/// [coldigomCatalogHydrationProvider] chegar a `data` **ou** `error` e, depois
/// disso, mais [pdfrxPreloadIdleDelay] de folga.
```

e no `build` do state:

```dart
  @override
  Widget build(BuildContext context) {
    // `listen` (não `watch`): o preload reage à hidratação sem reconstruir a
    // subárvore quando o índice chega.
    ref.listen(coldigomCatalogHydrationProvider, (_, next) {
      if (next.hasValue || next.hasError) _armIdleTimer();
    });

    final hydration = ref.read(coldigomCatalogHydrationProvider);
    if (hydration.hasValue || hydration.hasError) _armIdleTimer();

    return widget.child;
  }
```

O doc de `_armIdleTimer` troca «quando o manifest já não usa a rede» por «quando o catálogo já hidratou».

Run: `flutter test test/unit/features/pdf_reader/pdfrx_idle_preloader_test.dart`
Expected: PASS.

- [ ] **Step 3: «Seguir o áudio» sem catálogo PLPCG**

Em `lib/features/audio_player/domain/utils/find_material_for_group.dart`: apagar o parâmetro `List<Louvor> catalog = const []` de `findMaterialForGroup` e de `groupIdForMaterialId`, o laço `for (final louvor in catalog) …` de cada uma e o argumento `catalog: catalog` na chamada interna. Doc de `findMaterialForGroup`: passo 2 vira «senão o primeiro PDF do grupo no cache ([byPdfId])»; tirar «[catalog] é o manifest PLPCG;». Doc de `groupIdForMaterialId`: «Retorna `null` quando o id não está em nenhum dos caches.»

Em `lib/features/audio_player/presentation/providers/audio_follow_reader_provider.dart`: apagar o import de `louvores_manifest_provider.dart`, as leituras `final manifest = …` nas duas funções e os argumentos `catalog: manifest.value?.louvores ?? const [],`.

Em `test/unit/features/audio_player/find_material_for_group_test.dart`: apagar os testes `'resolve grupo PLPCG pelo catálogo do manifest'`, `'encontra material da lista ativa vindo do catálogo PLPCG'` e `'resolve pelo catálogo PLPCG'`, e os fixtures `plpcgGroupId`, `plpcgPartitura`, `plpcgCifra` (e o import de `louvor_group_id.dart` se ficar sem uso).

Em `test/unit/features/audio_player/audio_follow_reader_provider_test.dart:264`: `louvoresManifestOverride(LouvoresManifest.fromLouvores([louvor]))` → `coldigomLouvoresOverride([louvor])` (o `louvor` do teste já tem `groupId`; se o teste espera o grupo pelo material, acrescentar `praiseId:` igual a ele).

- [ ] **Step 4: Playlists, app e listener**

Em `lib/features/playlists/presentation/providers/playlists_provider.dart`: trocar o import de `louvores_manifest_provider.dart` por `import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';`; no `build`:

```dart
    // Os rótulos saem do lookup, que só enche quando o catálogo hidrata:
    // recarrega quando o índice troca (boot e cada sync que substituiu o dump).
    ref.listen(coldigomSearchIndexProvider, (_, _) {
      unawaited(_reload());
    });
```

e o doc de `PlaylistViewItem`: «Playlist enriquecida com os rótulos do catálogo para exibição na UI.» No comentário de `_reload` sobre a trava, trocar «quando o manifest chega» por «quando o catálogo hidrata».

Em `lib/features/playlists/presentation/widgets/playlist_list_tile.dart:33`: `[louvoresManifestProvider]` → `[catalogMaterialLookupProvider]`; linha 41 «com labels do manifest» → «com os rótulos do catálogo».

Em `lib/app.dart`: apagar o import de `louvores_manifest_provider.dart` e a linha `ref.listen(louvoresManifestProvider, (_, _) {});` com o comentário; o doc da classe passa a:

```dart
/// Widget raiz — MaterialApp com tema Coletânea Digital, l10n e GoRouter.
///
/// Se falta `PLPCG_API_BASE_URL` ou `COLDIGOM_API_BASE_URL`, renderiza
/// [MissingApiConfigScreen] (sem router). O catálogo coldigom arranca no
/// [ShellScaffold] (hidratação + sync). Envolve o router com
/// [DeepLinkListener] (Fase 4.5 — import automático de playlist via deep link).
///
/// Ambos os [MaterialApp] usam `debugShowCheckedModeBanner: false` para ocultar
/// o selo DEBUG no canto superior direito.
```

Em `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart`: apagar o import de `catalog_checksum_poll_provider.dart` e a linha `ref.read(catalogChecksumPollProvider.notifier).requestPollDebounced();`.

- [ ] **Step 5: Correr**

Run: `flutter analyze && flutter test`
Expected: analyze limpo, suíte verde. Se algum teste de playlists ficar pendurado à espera do Isar real (o `ref.listen(coldigomSearchIndexProvider)` arranca a hidratação), acrescentar ao container `coldigomCatalogHydrationProvider.overrideWith((ref) async => ColdigomSearchIndex.empty)`. `grep -rn "louvoresManifestProvider" lib` devolve só os ficheiros da própria pilha (`plpcg_catalog_source_provider.dart`, `catalog_checksum_poll_provider.dart`, `louvores_by_pdf_id_provider.dart`, `louvores_manifest_provider.dart`, `manifest_material_aliases_provider.dart`) e o doc de `pdfrx_bootstrap.dart`, se sobrou — corrigir o doc.

- [ ] **Step 6: Commit**

```bash
git add -A lib/app.dart lib/features/pdf_reader lib/features/audio_player lib/features/playlists lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart test
git commit -m "refactor: boot, preload do pdfium, seguir o áudio e playlists sem o manifesto

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade C — `/offline` de uma secção (spec §3.1)

### Task 9: Uma secção «Baixar para usar offline», também sem login

Mantém-se: a linha de estado do catálogo; a escolha por tipo, «Baixar selecionados», «Parar» e o progresso; o uso de disco, um «Atualizar» (sync + reconcile, desvio 4) e o banner «N removidos» só com «dispensar». Sem login aparece a lista «Tipos» completa e uma linha opcional para entrar. Um estado de ocupado só: decide o `offlineMaintenanceLockProvider`. «Remover todos os baixados» remove todos os PDFs e áudios indexados.

**Files:**
- Modify: `lib/features/offline/presentation/pages/offline_settings_screen.dart` (reescrita)
- Modify: `lib/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart`
- Modify: `lib/features/offline/domain/usecases/remove_coldigom_downloads.dart`
- Modify: `lib/features/offline/presentation/providers/offline_coldigom_download_provider.dart` (docs de `removeDownloads`)
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados)
- Test: `test/widget/features/offline/offline_settings_screen_test.dart` (reescrita), `test/widget/features/offline/offline_settings_screen_coldigom_test.dart`, `test/unit/features/offline/remove_coldigom_downloads_test.dart`
- Delete: `test/unit/features/offline/offline_bulk_completion_message_test.dart` (a função `offlineBulkCompletionMessage` sai)

**Interfaces:**
- Consumes: `offlineCacheStatusProvider` (`OfflineCacheStatus.stats.totalDiskUsageBytes`, `freeDiskBytes`, `isRefreshing`, `removedCount`, `showRemovedWarning`; notifier `refresh()`, `refreshAll()`, `dismissRemovedWarning()`), `offlineMaintenanceLockProvider`, `coldigomCatalogSyncProvider`, `offlineColdigomDownloadProvider`, `offlineColdigomStatsProvider`.
- Produces: `ColdigomOfflineSection({super.key})` (sem `maintenanceBusy`); strings `offlineSectionTitle`, `offlineKindsAll`; `RemoveColdigomDownloads` remove todos os PDFs do índice.

- [ ] **Step 1: Strings**

Em `lib/l10n/app_pt.arb`:
- novas (junto das `offlineColdigom*`):

```json
  "offlineSectionTitle": "Baixar para usar offline",
  "offlineKindsAll": "Tipos",
```

- valores novos: `"offlineColdigomRemove": "Remover todos os baixados"`, `"offlineColdigomRemoveConfirmTitle": "Remover todos os baixados?"`, `"offlineColdigomSignInPrompt": "Entre com Google para ver os seus tipos favoritos primeiro"`.

Em `lib/l10n/app_en.arb`:

```json
  "offlineSectionTitle": "Download for offline use",
  "offlineKindsAll": "Types",
```

e `"offlineColdigomRemove": "Remove all downloads"`, `"offlineColdigomRemoveConfirmTitle": "Remove all downloads?"`, `"offlineColdigomSignInPrompt": "Sign in with Google to see your favorite types first"`.

Run: `flutter gen-l10n`

- [ ] **Step 2: `RemoveColdigomDownloads` sem filtro (teste primeiro)**

Substituir o teste em `test/unit/features/offline/remove_coldigom_downloads_test.dart` (o `main`) por:

```dart
void main() {
  test('remove todos os áudios e todos os PDFs indexados', () async {
    final pdfRepo = _PdfRepo([
      _entry('assets/praises/p1/a.pdf', persistent: true),
      _entry('assets/praises/p1/b.pdf', persistent: false),
      // Id legado que o crosswalk não conhecia — também sai.
      _entry('ColAdultos/001.pdf', persistent: true),
    ]);
    final audioRepo = _AudioRepo();

    final result = await RemoveColdigomDownloads(
      pdfRepository: pdfRepo,
      audioRepository: audioRepo,
    ).call();

    expect(pdfRepo.removedMany, {
      encodePdfId('assets/praises/p1/a.pdf'),
      encodePdfId('assets/praises/p1/b.pdf'),
      encodePdfId('ColAdultos/001.pdf'),
    });
    expect(audioRepo.removeAllCalls, 1);
    expect(result.removedPdfs, 3);
  });
}
```

Run: `flutter test test/unit/features/offline/remove_coldigom_downloads_test.dart`
Expected: FAIL (hoje só sai o persistente coldigom).

Em `lib/features/offline/domain/usecases/remove_coldigom_downloads.dart`: apagar o import de `pdf_id_codec.dart`; o doc da classe:

```dart
/// «Remover todos os baixados» (spec 2026-09-23 §3.1).
///
/// Áudio sai inteiro (índice + store). PDF sai todo o que está no índice —
/// baixado por tipo ou guardado pelo leitor —, de qualquer espaço de ids.
/// Cifras e gestos ficam: pesam KB («textos ficam sempre» na UI).
```

e o conjunto:

```dart
    final pdfIds = {
      for (final entry in await _pdfRepository.listAll()) entry.pdfId,
    };
```

Em `offline_coldigom_download_provider.dart`, o doc de `removeDownloads`: `/// «Remover todos os baixados»; \`null\` se o lock estiver ocupado ou não houver Isar.`

Run: `flutter test test/unit/features/offline/remove_coldigom_downloads_test.dart`
Expected: PASS.

- [ ] **Step 3: Testes da secção (falham)**

Em `test/widget/features/offline/offline_settings_screen_coldigom_test.dart`:
- acrescentar os imports `package:coldigui/features/offline/domain/entities/offline_stats.dart` e `package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart`;
- acrescentar a classe:

```dart
class _FixedCacheStatus extends OfflineCacheStatusNotifier {
  var refreshAllCalls = 0;
  var refreshCalls = 0;

  @override
  OfflineCacheStatus build() => const OfflineCacheStatus(
    stats: OfflineStats(byCategory: {}, totalDiskUsageBytes: 5 * 1024 * 1024),
  );

  @override
  Future<void> refreshAll() async => refreshAllCalls++;

  @override
  Future<void> refresh({int? removedCount}) async => refreshCalls++;
}
```

- `_BusyLock.build` devolve `OfflineMaintenanceOwner.reconcile` (em vez de `bulk`);
- `_pump` passa a devolver também o fake do cache (`({_FixedSync sync, _FixedDownload download, _FixedCacheStatus cache})`), monta `const SingleChildScrollView(child: ColdigomOfflineSection())` e acrescenta `offlineCacheStatusProvider.overrideWith(() => cache)` aos overrides;
- o teste `'deslogado: convite + botão Google; sem lista de kinds'` passa a:

```dart
  testWidgets(
    'deslogado: lista Tipos inteira e baixa sem conta; entrar é opcional',
    (tester) async {
      final handles = await _pump(tester, loggedIn: false, rank: const {});

      expect(
        find.text('Entre com Google para ver os seus tipos favoritos primeiro'),
        findsOneWidget,
      );
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('Tipos'), findsOneWidget);
      expect(find.text('Seus tipos favoritos'), findsNothing);
      expect(find.text('Outros tipos'), findsNothing);
      final tiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((t) => (t.title as Text).data)
          .toList();
      expect(tiles, ['Cifra', 'Grade', 'Playback']);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Grade'));
      await tester.pumpAndSettle();
      final baixar = find.textContaining('Baixar selecionados');
      await tester.ensureVisible(baixar);
      await tester.tap(baixar);
      await tester.pumpAndSettle();

      expect(handles.download.started.single, {'k-grade'});
    },
  );
```

- o teste da linha do catálogo passa a:

```dart
  testWidgets(
    'linha de estado: catálogo + disco e um só Atualizar (sync + reconcile)',
    (tester) async {
      final handles = await _pump(tester);
      expect(find.textContaining('Catálogo: 1690 louvores'), findsOneWidget);
      expect(find.textContaining('Acervo offline: '), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);

      await tester.tap(find.text('Atualizar'));
      await tester.pumpAndSettle();

      expect(handles.sync.syncCalls, 1);
      expect(handles.cache.refreshAllCalls, 1);

      await _pump(tester, syncState: const ColdigomCatalogSyncState(count: 0));
      expect(
        find.text('Ligue-se à internet para baixar o catálogo'),
        findsOneWidget,
      );
    },
  );
```

- nos testes de remoção, os textos passam a `'Remover todos os baixados'` e `'Remover todos os baixados?'`; o teste «remover pede confirmação e mostra o resultado» acrescenta no fim `expect(handles.cache.refreshCalls, 1);` (o uso de disco é relido).

Reescrever `test/widget/features/offline/offline_settings_screen_test.dart` inteiro:

```dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/offline/domain/entities/offline_stats.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_screen.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_reconcile_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedCacheStatusNotifier extends OfflineCacheStatusNotifier {
  _FixedCacheStatusNotifier(this.fixed);

  final OfflineCacheStatus fixed;
  var dismissCalls = 0;

  @override
  OfflineCacheStatus build() => fixed;

  @override
  Future<void> refreshAll() async {}

  @override
  Future<void> refresh({int? removedCount}) async {}

  @override
  void dismissRemovedWarning() => dismissCalls++;
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _FixedSync extends ColdigomCatalogSyncNotifier {
  @override
  ColdigomCatalogSyncState build() =>
      const ColdigomCatalogSyncState(count: 2063);

  @override
  Future<ColdigomCatalogSyncResult> sync() async =>
      const ColdigomCatalogSyncNoop();
}

class _IdleReconcileNotifier extends OfflineReconcileNotifier {
  @override
  OfflineReconcileState build() => const OfflineReconcileState();

  @override
  Future<void> requestReconcile() async {}
}

class _BusyLock extends OfflineMaintenanceLock {
  @override
  OfflineMaintenanceOwner? build() => OfflineMaintenanceOwner.reconcile;
}

late SharedPreferences _prefs;

Future<_FixedCacheStatusNotifier> _pump(
  WidgetTester tester, {
  OfflineCacheStatus status = const OfflineCacheStatus(
    stats: OfflineStats(byCategory: {}, totalDiskUsageBytes: 5 * 1024 * 1024),
  ),
  List<Override> extra = const [],
}) async {
  final cache = _FixedCacheStatusNotifier(status);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        authStateProvider.overrideWith(_LoggedOut.new),
        offlineCacheStatusProvider.overrideWith(() => cache),
        offlineReconcileProvider.overrideWith(_IdleReconcileNotifier.new),
        coldigomCatalogSyncProvider.overrideWith(_FixedSync.new),
        offlineColdigomStatsProvider.overrideWith(
          (ref) async => OfflineColdigomStats.empty,
        ),
        ...extra,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const OfflineSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cache;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('uma secção «Baixar para usar offline» e um só «Atualizar»', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Baixar para usar offline'), findsOneWidget);
    expect(find.text('Acervo PLPCG (PDFs)'), findsNothing);
    expect(find.text('Coldigom por tipo de material'), findsNothing);
    expect(find.text('Atualizar'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Limpar cache offline'), findsNothing);
  });

  testWidgets('banner de removidos só com «Dispensar»', (tester) async {
    final cache = await _pump(
      tester,
      status: const OfflineCacheStatus(
        stats: OfflineStats(byCategory: {}),
        removedCount: 2,
      ),
    );

    expect(
      find.text('2 PDFs deixaram de estar disponíveis localmente'),
      findsOneWidget,
    );
    final banner = find.byType(MaterialBanner);
    expect(
      find.descendant(of: banner, matching: find.byType(TextButton)),
      findsOneWidget,
    );
    await tester.tap(find.text('Dispensar'));
    expect(cache.dismissCalls, 1);
  });

  testWidgets('manutenção de outro dono desabilita «Dispensar»', (
    tester,
  ) async {
    await _pump(
      tester,
      status: const OfflineCacheStatus(
        stats: OfflineStats(byCategory: {}),
        removedCount: 1,
      ),
      extra: [offlineMaintenanceLockProvider.overrideWith(_BusyLock.new)],
    );

    final dismiss = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Dispensar'),
    );
    expect(dismiss.onPressed, isNull);
  });

  testWidgets('sem overflow a 400px de largura', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      status: const OfflineCacheStatus(
        stats: OfflineStats(byCategory: {}, totalDiskUsageBytes: 1 << 30),
        removedCount: 12,
        freeDiskBytes: 1 << 34,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
```

Apagar `test/unit/features/offline/offline_bulk_completion_message_test.dart`.

Run: `flutter test test/widget/features/offline/`
Expected: FAIL (tela ainda com duas secções; secção sem lista sem login).

- [ ] **Step 4: A secção**

Em `lib/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart`:
- imports novos: `../../providers/offline_cache_status_provider.dart`;
- `ColdigomOfflineSection`:

```dart
/// A secção única do `/offline` — «Baixar para usar offline» (spec
/// 2026-09-23 §3.1): estado do catálogo e do disco, tipos de material,
/// baixar/parar/remover. Sem login mostra todos os tipos; a conta só traz os
/// favoritos para o topo.
class ColdigomOfflineSection extends ConsumerWidget {
  const ColdigomOfflineSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;
    final sync = ref.watch(coldigomCatalogSyncProvider);
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    final lockOwner = ref.watch(offlineMaintenanceLockProvider);
    final download = ref.watch(offlineColdigomDownloadProvider);
    // Um estado de ocupado só (§3.1): decide o lock. O nosso não nos
    // desabilita — é o «Parar» que fica ativo.
    final busy =
        lockOwner != null && lockOwner != OfflineMaintenanceOwner.coldigom;

    // … aqui fica, sem mudança, o `ref.listen(offlineColdigomDownloadProvider,
    // …)` de hoje (snackbars de falha e de conclusão) …

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusLines(
          sync: sync,
          cacheStatus: cacheStatus,
          l10n: l10n,
          busy: busy || download.isActive || download.removing,
        ),
        const SizedBox(height: 12),
        if (user == null) ...[
          _SignInRow(l10n: l10n),
          const SizedBox(height: 8),
        ],
        _KindsBody(
          l10n: l10n,
          busy: busy,
          download: download,
          signedIn: user != null,
        ),
      ],
    );
  }
}
```

- `_CatalogStatusLine` vira `_StatusLines` (catálogo + disco + um «Atualizar»):

```dart
class _StatusLines extends ConsumerWidget {
  const _StatusLines({
    required this.sync,
    required this.cacheStatus,
    required this.l10n,
    required this.busy,
  });

  final ColdigomCatalogSyncState sync;
  final OfflineCacheStatus cacheStatus;
  final AppLocalizations l10n;
  final bool busy;

  String _ago(DateTime? at) {
    if (at == null) return l10n.offlineColdigomAgoJustNow;
    final diff = DateTime.now().toUtc().difference(at.toUtc());
    if (diff.inMinutes < 1) return l10n.offlineColdigomAgoJustNow;
    if (diff.inHours < 1) return l10n.offlineColdigomAgoMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.offlineColdigomAgoHours(diff.inHours);
    return l10n.offlineColdigomAgoDays(diff.inDays);
  }

  String _diskUsage() {
    final used = formatCompactBytes(cacheStatus.stats.totalDiskUsageBytes);
    final free = cacheStatus.freeDiskBytes;
    return free == null
        ? l10n.offlineStatsDiskUsageUsedOnly(used)
        : l10n.offlineStatsDiskUsage(used, formatCompactBytes(free));
  }

  /// Um «Atualizar» (desvio 4 do plano): catálogo (sync por ETag) + índice
  /// offline (reconcile + uso de disco).
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
    try {
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.offlineRefreshSuccess)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.offlineRefreshError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = sync.count == 0
        ? l10n.offlineColdigomCatalogMissing
        : l10n.offlineColdigomCatalogStatus(sync.count, _ago(sync.lastSyncedAt));
    final hintStyle = AppTypography.body.copyWith(
      color: AppColors.title.withValues(alpha: 0.75),
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(catalog, style: hintStyle),
              const SizedBox(height: 4),
              Text(_diskUsage(), style: hintStyle),
            ],
          ),
        ),
        if (sync.isSyncing || cacheStatus.isRefreshing)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton.icon(
            onPressed: busy ? null : () => unawaited(_refresh(context, ref)),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.offlineRefreshStats),
          ),
      ],
    );
  }
}
```

- `_SignInCard` vira `_SignInRow` (mesmo conteúdo, doc novo, sem bloquear):

```dart
/// Deslogado: convite opcional — os tipos aparecem na mesma (§3.1, M8).
class _SignInRow extends StatelessWidget {
  const _SignInRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          l10n.offlineColdigomSignInPrompt,
          textAlign: TextAlign.center,
          style: AppTypography.hint(),
        ),
        const SizedBox(height: 8),
        const GoogleSignInButton(),
      ],
    );
  }
}
```

- `_KindsBody` ganha `required this.signedIn` (`final bool signedIn;`). No `build`: `favoriteIds` só com conta; sem conta, uma lista plana ordenada por nome com o rótulo «Tipos":

```dart
    final rank = signedIn
        ? ref.watch(favoriteMaterialKindRankProvider)
        : const <String, int>{};
```

e, na `Column`, os três primeiros filhos (`_sectionLabel(favoritos)`, a lista de favoritos, o `ExpansionTile` de outros) passam a:

```dart
        if (signedIn) ...[
          _sectionLabel(l10n.offlineColdigomFavoriteKinds),
          if (favorites.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                l10n.offlineColdigomNoFavorites,
                style: AppTypography.hint(),
              ),
            )
          else
            for (final kind in favorites) tile(kind),
          if (others.isNotEmpty)
            ExpansionTile(
              title: Text(
                l10n.offlineColdigomOtherKinds,
                style: AppTypography.label,
              ),
              tilePadding: EdgeInsets.zero,
              children: [for (final kind in others) tile(kind)],
            ),
        ] else ...[
          // Sem conta não há favoritos: `others` já é a lista inteira, por nome.
          _sectionLabel(l10n.offlineKindsAll),
          for (final kind in others) tile(kind),
        ],
```

(Sem conta `rank` é vazio, logo `others` contém todos os tipos já ordenados por nome e `effectiveSelection` recebe `favoriteKindIds` vazio.)

- `_remove`, depois do snackbar do resultado: `unawaited(ref.read(offlineCacheStatusProvider.notifier).refresh());` (o uso de disco mudou).

- [ ] **Step 5: A tela**

Substituir `lib/features/offline/presentation/pages/offline_settings_screen.dart` inteiro:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/golden_tagged_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/offline_cache_status_provider.dart';
import '../providers/offline_coldigom_download_provider.dart';
import '../providers/offline_maintenance_lock_provider.dart';
import '../providers/offline_reconcile_provider.dart';
import 'offline_settings_widgets/coldigom_section.dart';

/// UC-09, UC-10 — `/offline` com uma secção só (spec 2026-09-23 §3.1).
class OfflineSettingsScreen extends ConsumerStatefulWidget {
  const OfflineSettingsScreen({super.key});

  @override
  ConsumerState<OfflineSettingsScreen> createState() =>
      _OfflineSettingsScreenState();
}

class _OfflineSettingsScreenState extends ConsumerState<OfflineSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(offlineReconcileProvider.notifier).requestReconcile();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(offlineColdigomDownloadProvider.notifier).pauseForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    final busy = ref.watch(offlineMaintenanceLockProvider) != null;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GoldenTaggedContainer(
            label: l10n.offlineSectionTitle,
            child: const ColdigomOfflineSection(),
          ),
          if (cacheStatus.showRemovedWarning) ...[
            const SizedBox(height: 12),
            MaterialBanner(
              backgroundColor: AppColors.card,
              content: Text(
                l10n.offlineRemovedBanner(cacheStatus.removedCount),
                style: AppTypography.body,
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => ref
                            .read(offlineCacheStatusProvider.notifier)
                            .dismissRemovedWarning(),
                  child: Text(l10n.offlineDismissRemoved),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Correr**

Run: `flutter analyze && flutter test test/widget/features/offline/ test/unit/features/offline/`
Expected: analyze limpo (os providers PLPCG ainda existem, sem chamadores de UI — não é aviso), PASS.

- [ ] **Step 7: Suíte e commit**

Run: `flutter test`
Expected: verde.

```bash
git add -A lib/features/offline lib/l10n test/widget/features/offline test/unit/features/offline
git commit -m "feat(offline): uma secção «Baixar para usar offline», também sem login

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---
### Task 10: Apagar a secção PLPCG do `/offline` e o que só ela usava

Sai (spec §3.1): `_OfflineContent` (já saiu na Tarefa 9), `OfflineBulkDownloadNotifier` e `DownloadMissingPdfs` sobre o `LouvorCache`, `offlineCategorySelectionProvider`, `GetOfflineStatsByCategory`/`loadPdfIdToCategoria`, `OfflineAvailableStore` com a flag `OFFLINE_AVAILABLE` e o gate UC-09/UC-10, as prefs `offlineSelectedCategories`/`offlineBulkCategories`, `ProgressSection` e `KeepAppOpenBanner` (a secção por tipo tem o seu próprio progresso). O `MigrateOfflineStorage` ganha o passo 5 (prefs mortas desta secção **e** do manifesto). O `offlineCacheStatusProvider` fica só com o uso de disco.

**Files:**
- Create: `lib/features/offline/presentation/providers/download_wakelock_provider.dart` (o wakelock que o download por tipo usa, hoje dentro do provider do bulk)
- Modify: `lib/features/offline/presentation/providers/offline_coldigom_download_provider.dart:13` (import do wakelock)
- Modify: `lib/features/offline/data/providers/offline_core_providers.dart`
- Modify: `lib/features/offline/presentation/providers/offline_cache_status_provider.dart`
- Modify: `lib/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart` (`_diskUsage`)
- Modify: `lib/features/offline/presentation/providers/offline_maintenance_lock_provider.dart`
- Modify: `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart`
- Modify: `lib/features/offline/domain/usecases/migrate_offline_storage.dart`
- Modify: `lib/features/offline/domain/exceptions/offline_bulk_exceptions.dart` (sai `OfflineBulkCancelledException`)
- Modify: `lib/core/constants/offline_config.dart` (`offlineStorageVersion = 5`)
- Modify: `lib/core/constants/storage_keys.dart` (saem `offlineAvailable`, `offlineBulkCheckpoint`, `offlineBulkCategories`, `offlineSelectedCategories`)
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados)
- Delete (lib): `lib/features/offline/data/datasources/offline_available_store.dart`, `offline_bulk_categories_store.dart`, `offline_selected_categories_store.dart`; `lib/features/offline/domain/entities/offline_download_progress.dart`, `offline_stats.dart`; `lib/features/offline/domain/usecases/clear_offline_cache.dart`, `download_missing_pdfs.dart`, `get_offline_stats_by_category.dart`, `list_missing_louvores_by_material.dart`; `lib/features/offline/domain/utils/offline_material_resolver.dart`; `lib/features/offline/presentation/pages/offline_settings_widgets/category_filter_chip.dart`, `keep_app_open_banner.dart`, `progress_section.dart`; `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`, `offline_category_selection_provider.dart`, `offline_missing_download_provider.dart`, `offline_missing_louvores_provider.dart`, `offline_mode_provider.dart`; `lib/features/offline/presentation/widgets/offline_missing_louvores_sheet.dart`
- Delete (test): `test/unit/features/offline/clear_offline_cache_test.dart`, `download_missing_pdfs_test.dart`, `get_offline_stats_by_category_test.dart`, `list_missing_louvores_by_material_test.dart`, `offline_available_store_test.dart`, `offline_bulk_categories_store_test.dart`, `offline_bulk_download_provider_test.dart`, `offline_selected_categories_store_test.dart`, `offline_missing_download_provider_test.dart`, `offline_material_resolver_test.dart`; `test/widget/features/offline/offline_missing_louvores_sheet_test.dart`
- Test (adaptar): `migrate_offline_storage_test.dart` (+ passo 5), `offline_cache_status_provider_test.dart`, `resolve_pdf_for_reader_test.dart`, `offline_maintenance_lock_test.dart`, `offline_reconcile_provider_test.dart`, `offline_coldigom_download_provider_test.dart`, os dois testes de widget do `/offline`

**Interfaces:**
- Produces: `abstract interface class BulkDownloadWakelock`, `WakelockPlusBulkDownloadWakelock`, `bulkDownloadWakelockProvider` (mesmos nomes, ficheiro novo); `OfflineCacheStatus({int diskUsageBytes = 0, int removedCount = 0, bool isRefreshing = false, int? freeDiskBytes})` com `empty`, `showRemovedWarning`, `copyWith`; `enum OfflineMaintenanceOwner { reconcile, coldigom, normalize }`; `ResolvePdfForReader(OfflinePdfRepository, FetchAndStorePdf)` (sem parâmetros nomeados); `MigrateOfflineStorage(SharedPreferences prefs, OfflinePdfLocalDatasource local, PdfStoragePort store)`; `OfflineConfig.offlineStorageVersion == 5`.

- [ ] **Step 1: Teste do passo 5 (falha)**

Em `test/unit/features/offline/migrate_offline_storage_test.dart`:
- todas as construções `MigrateOfflineStorage(prefs, OfflinePdfLocalDatasource(isar), OfflineAvailableStore(prefs), store)` passam a `MigrateOfflineStorage(prefs, OfflinePdfLocalDatasource(isar), store)` (idem no teste v2, com o `pdfStoragePortFor(...)` como terceiro argumento); sai o import de `offline_available_store.dart`;
- `StorageKeys.offlineAvailable` → `'OFFLINE_AVAILABLE'` e `StorageKeys.manifestChecksum` → `'manifestChecksum'` (as constantes saem do `StorageKeys`);
- acrescentar:

```dart
  test('v5 apaga as prefs mortas do manifesto e da secção PLPCG', () async {
    const dead = [
      'manifestChecksum',
      'catalogLastSyncAt',
      'lastChecksumPollAt',
      'offlineSelectedCategories',
      'offlineBulkCategories',
      'offlineBulkCheckpoint',
      'OFFLINE_AVAILABLE',
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.offlineStorageVersion, 4);
    for (final key in dead) {
      await prefs.setString(key, 'x');
    }
    await prefs.setString(StorageKeys.recentlyOpened, '[]');

    final isar = openOfflineTestIsar(
      await Directory.systemTemp.createTemp('migrate_v5_'),
    );
    await MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      _TrackingPdfStoragePort(),
    )();

    expect(prefs.getInt(StorageKeys.offlineStorageVersion), 5);
    for (final key in dead) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(
      prefs.getString(StorageKeys.recentlyOpened),
      '[]',
      reason: 'só as mortas saem',
    );
    isar.close(deleteFromDisk: true);
  });
```

Run: `flutter test test/unit/features/offline/migrate_offline_storage_test.dart`
Expected: FAIL (construtor com 4 argumentos; versão 4).

- [ ] **Step 2: `MigrateOfflineStorage` v5**

Em `lib/core/constants/offline_config.dart`: `static const int offlineStorageVersion = 5;`.

Substituir `lib/features/offline/domain/usecases/migrate_offline_storage.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../data/datasources/offline_pdf_local_datasource.dart';
import '../ports/pdf_storage_port.dart';

/// Flag UC-09 do bulk PLPCG (legado; lida só pela v2, apagada pela v5).
const _offlineAvailableKey = 'OFFLINE_AVAILABLE';

/// Checksum do manifest (legado; apagado pela v4 e pela v5).
const _manifestChecksumKey = 'manifestChecksum';

/// Prefs sem leitor desde o fim da fonte PLPCG (spec 2026-09-23 §3.1/§6.4).
/// Literais de propósito: as constantes saíram de [StorageKeys].
const _deadPrefsV5 = [
  _manifestChecksumKey,
  'catalogLastSyncAt',
  'lastChecksumPollAt',
  'offlineSelectedCategories',
  'offlineBulkCategories',
  'offlineBulkCheckpoint',
  _offlineAvailableKey,
];

/// UC-10 — Migrar layout do store offline (Fase 3.6).
///
/// Move PDFs entre versões de diretório/schema; atualiza paths no índice Isar.
/// Os dados da coleção Isar `LouvorCache` não precisam de passo: o
/// `isar_plus` apaga uma coleção que saiu do schema ao abrir (medido
/// 2026-09-23, plano 3 do fim da fonte PLPCG, desvio 3).
class MigrateOfflineStorage {
  const MigrateOfflineStorage(this.prefs, this.local, this.store);

  final SharedPreferences prefs;
  final OfflinePdfLocalDatasource local;
  final PdfStoragePort store;

  Future<void> call() async {
    final stored = prefs.getInt(StorageKeys.offlineStorageVersion) ?? 0;
    if (stored >= OfflineConfig.offlineStorageVersion) {
      return;
    }

    for (
      var version = stored;
      version < OfflineConfig.offlineStorageVersion;
      version++
    ) {
      await _runMigration(version + 1);
    }

    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );
  }

  Future<void> _runMigration(int targetVersion) async {
    switch (targetVersion) {
      case 1:
        break;
      case 2:
        if (prefs.getString(_offlineAvailableKey) == 'TRUE') {
          await local.markAllPersistent();
        }
        break;
      case 3:
        await store.purgeLegacyStorage();
        if (kIsWeb) {
          await local.clearAll();
        }
        break;
      case 4:
        // shortId (set/2026): o checksum antigo casaria 304 e o cache nunca
        // ganharia o campo — força um download do corpo.
        await prefs.remove(_manifestChecksumKey);
        break;
      case 5:
        // Fim da fonte PLPCG: manifesto e secção PLPCG do /offline sem leitor.
        for (final key in _deadPrefsV5) {
          await prefs.remove(key);
        }
        break;
      default:
        break;
    }
  }
}
```

Em `offline_core_providers.dart`, `migrateOfflineStorageProvider` passa a:

```dart
/// DI — [MigrateOfflineStorage] (Fase 3.6).
final migrateOfflineStorageProvider = Provider<MigrateOfflineStorage>((ref) {
  return MigrateOfflineStorage(
    ref.watch(sharedPreferencesProvider),
    ref.watch(offlinePdfLocalDatasourceProvider),
    ref.watch(pdfStoragePortProvider),
  );
});
```

Em `test/unit/features/offline/offline_reconcile_provider_test.dart`, as três construções do `_CountingMigrate(...)` perdem o argumento `OfflineAvailableStore(prefs)` (e o import). Se `_CountingMigrate` repassa quatro argumentos ao `super`, passa a três.

Run: `flutter test test/unit/features/offline/migrate_offline_storage_test.dart`
Expected: PASS.

- [ ] **Step 3: `ResolvePdfForReader` sem a flag (desvio 5)**

Em `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart`: apagar os parâmetros nomeados `isFullOfflineMode`/`hasNetworkConnection`, os defaults estáticos, os campos `_isFullOfflineMode`/`_hasNetworkConnection`, o bloco `final online = …; if (_isFullOfflineMode() && !online) {…}` e o argumento `persistentDownload: _isFullOfflineMode(),` na chamada ao `_fetchAndStore`. O construtor fica `const ResolvePdfForReader(this._repository, this._fetchAndStore);`. Doc da classe: apagar o parágrafo «Quando [isFullOfflineMode] retorna `true` (`OFFLINE_AVAILABLE=TRUE`)…».

Em `offline_core_providers.dart`:

```dart
/// DI — [ResolvePdfForReader] (Fase 3.2 + 3.3 + 3.4).
final resolvePdfForReaderProvider = Provider<ResolvePdfForReader>((ref) {
  return ResolvePdfForReader(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(fetchAndStorePdfProvider),
  );
});
```

Em `test/unit/features/offline/resolve_pdf_for_reader_test.dart`: apagar os testes `'miss com isFullOfflineMode true e offline falha sem fetch'`, `'miss com isFullOfflineMode true e online delega fetch persistente'` e `'fullOfflineMode com índice órfão e offline lança PdfExternallyDeletedException'`; renomear `'miss com isFullOfflineMode false passa persistentDownload false'` para `'miss delega fetch sem persistentDownload'`.

- [ ] **Step 4: `offlineCacheStatusProvider` só com o disco**

Substituir o topo de `lib/features/offline/presentation/providers/offline_cache_status_provider.dart` (a classe `OfflineCacheStatus` e o notifier) por:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/offline_providers.dart';
import '../../data/utils/storage_quota_estimator.dart';
import 'offline_reconcile_provider.dart';

/// Uso de disco do offline e aviso pós-reconcile para o `/offline`.
class OfflineCacheStatus {
  const OfflineCacheStatus({
    this.diskUsageBytes = 0,
    this.removedCount = 0,
    this.isRefreshing = false,
    this.freeDiskBytes,
  });

  static const empty = OfflineCacheStatus();

  /// Bytes dos PDFs offline no store (scan real — `getTotalOfflineBytes`).
  final int diskUsageBytes;

  /// Bytes livres no volume de armazenamento (`null` se indisponível).
  final int? freeDiskBytes;

  /// PDFs removidos do índice no último reconcile (banner no `/offline`).
  final int removedCount;

  /// `true` enquanto [OfflineCacheStatusNotifier.refresh] está em execução.
  final bool isRefreshing;

  /// Exibir banner de PDFs removidos externamente.
  bool get showRemovedWarning => removedCount > 0;

  OfflineCacheStatus copyWith({
    int? diskUsageBytes,
    int? removedCount,
    bool? isRefreshing,
    int? freeDiskBytes,
  }) {
    return OfflineCacheStatus(
      diskUsageBytes: diskUsageBytes ?? this.diskUsageBytes,
      removedCount: removedCount ?? this.removedCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      freeDiskBytes: freeDiskBytes ?? this.freeDiskBytes,
    );
  }
}

/// Provider do uso de disco offline para a UI (Fase 3.7).
///
/// Cold start: carrega via microtask — **sem** reconcile no boot. Listener em
/// [offlineReconcileProvider] propaga `removedFromIndex`.
final offlineCacheStatusProvider =
    NotifierProvider<OfflineCacheStatusNotifier, OfflineCacheStatus>(
      OfflineCacheStatusNotifier.new,
    );

class OfflineCacheStatusNotifier extends Notifier<OfflineCacheStatus> {
  @override
  OfflineCacheStatus build() {
    ref.listen(offlineReconcileProvider, (previous, next) {
      final wasRunning = previous?.isRunning ?? false;
      if (wasRunning && !next.isRunning) {
        unawaited(refresh(removedCount: _removedFromLastReconcile(next)));
      }
    });

    Future.microtask(refresh);
    return OfflineCacheStatus.empty;
  }

  Future<OfflineCacheStatus> _read({required int removedCount}) async {
    final used = await ref.read(pdfStoragePortProvider).getTotalOfflineBytes();
    final free = await estimateFreeStorageBytes();
    return OfflineCacheStatus(
      diskUsageBytes: used,
      removedCount: removedCount,
      freeDiskBytes: free,
    );
  }

  /// Relê o uso de disco. [removedCount] opcional após reconcile.
  Future<void> refresh({int? removedCount}) async {
    final preserved = removedCount ?? state.removedCount;
    state = state.copyWith(isRefreshing: true);
    try {
      state = await _read(removedCount: preserved);
    } finally {
      if (state.isRefreshing) state = state.copyWith(isRefreshing: false);
    }
  }

  /// Reconcile índice vs disco e relê o uso de disco (UC-10 UI).
  Future<void> refreshAll() async {
    state = state.copyWith(isRefreshing: true);
    try {
      await ref.read(offlineReconcileProvider.notifier).requestReconcile();
      state = await _read(
        removedCount: _removedFromLastReconcile(
          ref.read(offlineReconcileProvider),
        ),
      );
    } finally {
      if (state.isRefreshing) state = state.copyWith(isRefreshing: false);
    }
  }
```

(`_removedFromLastReconcile` e `dismissRemovedWarning` ficam iguais.)

Em `coldigom_section.dart`, `_diskUsage()`: `formatCompactBytes(cacheStatus.stats.totalDiskUsageBytes)` → `formatCompactBytes(cacheStatus.diskUsageBytes)`.

Nos testes de widget do `/offline` (Tarefa 9): `OfflineCacheStatus(stats: OfflineStats(byCategory: {}, totalDiskUsageBytes: N), …)` → `OfflineCacheStatus(diskUsageBytes: N, …)` e `OfflineCacheStatus(stats: OfflineStats(byCategory: {}), removedCount: 2)` → `OfflineCacheStatus(removedCount: 2)`; sai o import de `offline_stats.dart`.

Em `test/unit/features/offline/offline_cache_status_provider_test.dart`: apagar `_StubIsar`, `_StatsRepo`, `_StubCatalogLocal`, `_FixedGetOfflineStatsByCategory` e os imports que ficarem sem uso; o helper de overrides passa a:

```dart
/// Store que só sabe o tamanho do acervo — o resto não é chamado aqui.
class _BytesPort implements PdfStoragePort {
  _BytesPort(this.bytes);

  final int bytes;

  @override
  Future<int> getTotalOfflineBytes() async => bytes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

List<Override> _offlineCacheStatusTestOverrides({int diskBytes = 0}) => [
  pdfStoragePortProvider.overrideWithValue(_BytesPort(diskBytes)),
];
```

(import `package:coldigui/features/offline/domain/ports/pdf_storage_port.dart`). Nos testes: `stats: const OfflineStats(byCategory: {'Partitura': 2})` → `diskBytes: 2048`; o primeiro teste vira `'refresh lê o uso de disco'` com `expect(status.diskUsageBytes, 2048)`; `expect(status.validCount, 1)` → `expect(status.diskUsageBytes, 1024)` (com `diskBytes: 1024`).

- [ ] **Step 5: Wakelock num ficheiro próprio; lock com três donos**

```dart
// lib/features/offline/presentation/providers/download_wakelock_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantém a tela ligada durante um download prolongado (backlog #12).
abstract interface class BulkDownloadWakelock {
  Future<void> enable();
  Future<void> disable();
}

class WakelockPlusBulkDownloadWakelock implements BulkDownloadWakelock {
  const WakelockPlusBulkDownloadWakelock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final bulkDownloadWakelockProvider = Provider<BulkDownloadWakelock>(
  (ref) => const WakelockPlusBulkDownloadWakelock(),
);
```

Em `offline_coldigom_download_provider.dart:13`: `import 'offline_bulk_download_provider.dart' show bulkDownloadWakelockProvider;` → `import 'download_wakelock_provider.dart';`; no doc da classe, «Bulk PLPCG e este são mutuamente exclusivos pelo lock» → «Reconcile, normalização de ids e este são mutuamente exclusivos pelo lock». Em `test/unit/features/offline/offline_coldigom_download_provider_test.dart`: o import de `offline_bulk_download_provider.dart` → `download_wakelock_provider.dart`; linha 177 `OfflineMaintenanceOwner.bulk` → `OfflineMaintenanceOwner.reconcile`.

Em `offline_maintenance_lock_provider.dart`:

```dart
/// Quem pode segurar o lock de manutenção offline (spec C.1 / B14).
///
/// `normalize` é a troca de ids legados do índice (spec fim-fonte-plpcg §6.2).
enum OfflineMaintenanceOwner { reconcile, coldigom, normalize }
```

e o doc do provider: «Reconcile, download/remoção por tipo e a normalização de ids mexem no mesmo par índice+disco: …».

Testes: em `offline_maintenance_lock_test.dart` trocar `OfflineMaintenanceOwner.bulk` → `.reconcile`, `.missing` → `.coldigom`, `.clear` → `.normalize` (mantém três donos distintos); em `offline_reconcile_provider_test.dart:278` `.bulk` → `.coldigom` (tem de ser **outro** dono que não o reconcile); nos dois testes de widget do `/offline` os `_BusyLock` já devolvem `.reconcile` (Tarefa 9).


- [ ] **Step 6: Apagar a secção PLPCG**

Apagar os ficheiros de lib e de teste listados em **Files → Delete**. Em `offline_core_providers.dart` apagar `offlineBulkCategoriesStoreProvider`, `offlineSelectedCategoriesStoreProvider`, `offlineAvailableStoreProvider`, `getOfflineStatsByCategoryProvider`, `downloadMissingPdfsProvider`, `listMissingLouvoresByMaterialProvider`, `clearOfflineCacheProvider` e os imports que ficarem sem uso (`catalog_local_providers.dart`, `device_connectivity_provider.dart`, os dos ficheiros apagados). Em `offline_bulk_exceptions.dart` apagar a classe `OfflineBulkCancelledException`.

Em `lib/core/constants/storage_keys.dart` apagar `offlineAvailable`, `offlineBulkCheckpoint`, `offlineBulkCategories` e `offlineSelectedCategories` (com os docs).

Confirmar que nada mais os usa:

```bash
grep -rnE "OfflineAvailableStore|offlineAvailableStoreProvider|OfflineBulkDownload|offlineBulkDownloadProvider|offlineCategorySelectionProvider|GetOfflineStatsByCategory|DownloadMissingPdfs|ListMissingLouvoresByMaterial|ClearOfflineCache|offlineModeProvider|OfflineMaterialResolver|OfflineStats\b|OfflineDownloadProgress|ProgressSection|KeepAppOpenBanner|CategoryFilterChip|showOfflineMissingLouvoresSheet|OfflineBulkCancelledException|isFullOfflineMode|OfflineMaintenanceOwner\.(bulk|missing|clear)|StorageKeys\.(offlineAvailable|offlineBulkCheckpoint|offlineBulkCategories|offlineSelectedCategories)" lib test
```

Expected: nenhuma linha.

`CatalogMaterials` (`lib/features/catalog/domain/constants/catalog_materials.dart`) ficou no plano 1 só para esta secção (`uiMaterials`/`defaultSelected`): `grep -rn "CatalogMaterials\|catalog_materials.dart" lib test`. Se só sobrar o próprio ficheiro, apagá-lo; se sobrar um chamador fora do `/offline`, manter só o que ele usa.

- [ ] **Step 7: Strings mortas (spec §9.1 + desvio 6)**

Para cada chave abaixo, primeiro `grep -rn "\.<chave>\b" lib test --include='*.dart' | grep -v lib/l10n/` tem de estar vazio; só então apagar a chave (e o `@<chave>`, se houver) de `app_pt.arb` **e** `app_en.arb`:

`offlineColdigomPlpcgSection`, `offlineColdigomSection`, `offlineClearCache`, `offlineClearCacheCancel`, `offlineClearCacheConfirm`, `offlineClearCacheConfirmBody`, `offlineClearCacheConfirmBodyAll`, `offlineClearCacheConfirmTitle`, `offlineClearCacheSuccess`, `offlineClearCacheSuccessPartial`, `offlineDownloadCompleted`, `offlineDownloadCompletedWithFailures`, `offlineStatsCategory`, `offlineStatsCategoryUnreliableMissing`, `offlineStatsCategoryWithMissing`, `offlineStatsMissingUnreliable`, `offlineStatsTotal`, `offlineStatsTotalMissing`, `offlineStopDownload`, `offlinePhaseFetching`, `offlineProgressDetail`, `offlineKeepAppOpenDuringDownload`, `offlineStatsTitle`, `offlineSelectCategories`, `offlineDownloadSelected`, `offlineMaintenanceBusy`, `offlineMissingLouvoresEmpty`, `offlineMissingLouvoresLoadError`, `offlineMissingLouvoresSheetTitle`.

**Ficam** (têm chamador): `offlineStoppingDownload`, `offlineRefreshStats`, `offlineRefreshSuccess`, `offlineRefreshError`, `offlineRemovedBanner`, `offlineDismissRemoved`, `offlineStatsDiskUsage`, `offlineStatsDiskUsageUsedOnly`, `offlineStorageUnavailable`.

Conferir também as chaves de §9 dos planos 1 e 2 — têm de já não estar nos arb: `libraryCatalogModeLabel`, `libraryCatalogModePlpcg`, `libraryCatalogModeColdigom`, `coldigomLoadError`, `playlistShareColdigomTitle`, `playlistShareColdigomBodyLeaflet`, `playlistShareColdigomBodyLink`, `playlistShareColdigomCancel`, `playlistShareColdigomLeafletOnly`, `playlistShareColdigomDismiss`, `liveColdigomOnlyTitle`, `liveColdigomOnlyBody`, `liveColdigomOnlyAdd`, `filtersSpecialArrangementTitle`, `specialArrangementPadrao`. Se alguma sobrar **sem chamador**, apagar aqui; com chamador, parar e reportar. `homeColdigomOffline` tem de valer «Sem conexão — o catálogo pode estar incompleto nesta busca.» / «No connection — the catalog may be incomplete for this search.» — se ainda tiver o texto antigo, trocar aqui (e o teste `home_empty_state_test` que o procura).

Run: `flutter gen-l10n`

- [ ] **Step 8: Correr**

Run: `flutter analyze && flutter test`
Expected: analyze limpo, suíte verde.

- [ ] **Step 9: Commit**

```bash
git add -A lib/features/offline lib/core/constants lib/l10n test/unit/features/offline test/widget/features/offline
git commit -m "chore(offline): apaga a secção PLPCG (bulk, categorias, OFFLINE_AVAILABLE); passo 5 limpa as prefs mortas

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade D — Apagar o que morreu (spec §6.4)

### Task 11: Apagar a pilha do manifesto, o `CompositeCatalogSource` e o `LouvorCache`

Nenhum código vivo lê o manifesto desde as Tarefas 7–10. Sai tudo o que o spec §6.4 lista, exceto o `LouvorPdfPath` (desvio 1), que é simplificado. `LouvorCache` sai do schema aberto; o `isar_plus` apaga os dados da coleção na próxima abertura (desvio 3).

**Files:**
- Delete (lib):
  - `lib/core/database/collections/louvor_cache.dart`, `louvor_cache.g.dart`
  - `lib/features/catalog/data/datasources/catalog_local_datasource.dart`, `catalog_remote_datasource.dart`, `catalog_sync_metadata_store.dart`, `manifest_checksum_store.dart`
  - `lib/features/catalog/data/mappers/louvor_cache_mapper.dart`
  - `lib/features/catalog/data/models/louvor_dto.dart`
  - `lib/features/catalog/data/providers/catalog_local_providers.dart`, `catalog_manifest_sync_providers.dart`, `catalog_providers.dart`, `plpcg_catalog_source_provider.dart`
  - `lib/features/catalog/data/repositories/catalog_repository_impl.dart`
  - `lib/features/catalog/data/sources/composite_catalog_source.dart`, `plpcg_catalog_source.dart`
  - `lib/features/catalog/domain/entities/louvores_manifest.dart`, `manifest_material_aliases.dart`
  - `lib/features/catalog/domain/ports/catalog_manifest_sync_listener.dart`
  - `lib/features/catalog/domain/repositories/catalog_repository.dart`, `manifest_checksum_reader.dart`
  - `lib/features/catalog/domain/search/plpcg_search_index.dart`
  - `lib/features/catalog/domain/usecases/load_louvores_manifest.dart`, `poll_manifest_checksum.dart`, `search_louvor_by_number_or_text.dart`
  - `lib/features/catalog/domain/utils/find_louvor_by_pdf_id.dart`
  - `lib/features/catalog/presentation/providers/catalog_checksum_poll_provider.dart`, `louvores_by_pdf_id_provider.dart`, `louvores_manifest_provider.dart`, `manifest_material_aliases_provider.dart`
  - `lib/features/offline/data/listeners/offline_catalog_manifest_sync_listener.dart`
  - `lib/features/offline/domain/usecases/remap_pdf_ids_after_catalog_update.dart`
  - `lib/features/offline/domain/utils/catalog_pdf_id_remap.dart`
- Modify: `lib/core/database/isar_app_schemas.dart`, `lib/core/database/isar_provider.dart:136`, `lib/core/constants/storage_keys.dart`, `lib/core/constants/offline_config.dart`, `lib/features/coldigom/data/constants/coldigom_endpoints.dart`, `lib/features/catalog/domain/entities/louvor.dart`, `lib/features/pdf_opening/domain/utils/louvor_pdf_path.dart`, `lib/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart`, docs em `coldigom_catalog_source.dart`, `coldigom_catalog_source_provider.dart`, `coldigom_search_index.dart`, `coldigom_praise_cache.dart`, `coldigom_praise_cache_warmup.dart`
- Delete (test): `test/helpers/louvores_manifest_test_helpers.dart`; `test/support/fakes/fake_catalog_repository.dart`; `test/fixtures/louvores_manifest_sample.json`, `test/fixtures/manifest_coldigom_sample.json`; em `test/unit/features/catalog/`: `catalog_checksum_poll_provider_test.dart`, `catalog_local_datasource_test.dart`, `catalog_remote_datasource_test.dart`, `catalog_repository_impl_test.dart`, `find_louvor_by_pdf_id_test.dart`, `load_louvores_manifest_test.dart`, `louvor_short_id_test.dart`, `louvores_by_pdf_id_provider_test.dart`, `louvores_manifest_notifier_test.dart`, `manifest_material_aliases_test.dart`, `plpcg_search_index_test.dart`, `poll_manifest_checksum_test.dart`, `search_louvor_by_number_or_text_test.dart` (e, se ainda existirem, `filter_by_material_and_arranjo_test.dart`, `filter_by_special_arrangement_test.dart`, `louvor_classification_special_test.dart`, `pdf_ids_by_short_id_provider_test.dart` — os planos 1/2 deviam tê-los apagado); em `test/unit/features/offline/`: `remap_pdf_ids_after_catalog_update_test.dart`, `catalog_pdf_id_remap_test.dart`
- Test (adaptar): `test/unit/features/catalog/catalog_source_test.dart`, `test/unit/features/catalog/louvor_praise_id_test.dart`, `test/unit/core/database/isar_smoke_test.dart`, `test/unit/features/offline/offline_test_helpers.dart`, `test/unit/features/offline/fetch_and_store_pdf_test.dart`, `test/unit/features/offline/offline_pdf_repository_test.dart`, `test/unit/features/pdf_opening/louvor_pdf_path_test.dart`, `test/integration/uc01_search_home_test.dart`, `test/support/README.md`, e todo teste que ainda tenha `louvoresManifestOverride`/`louvoresManifestProvider`

**Interfaces:**
- Produces: `kAppIsarSchemas` sem `LouvorCacheSchema`; `Louvor` sem `shortId`; `LouvorPdfPath.fromLouvor(Louvor)` = `'/${PdfPathNormalizer.getPdfRelPath(louvor.pdfId)}'` (sem `remotePath`); `find_louvor_group_by_pdf_id.dart` só com `findSwapMaterialGroup`.

- [ ] **Step 1: `LouvorPdfPath` só deriva do `pdfId` (teste primeiro)**

Substituir o `main` de `test/unit/features/pdf_opening/louvor_pdf_path_test.dart` (mantém `_encodePdfId` e `_louvorWithPdfId`):

```dart
void main() {
  test('deriva /assets/praises/… do pdfId coldigom', () {
    const relPath = 'assets/praises/p1/m1.pdf';
    final louvor = _louvorWithPdfId(relPath);

    expect(LouvorPdfPath.fromLouvor(louvor), '/$relPath');
    expect(PdfPathNormalizer.getPdfRelPath(louvor.pdfId), relPath);
  });

  test('preserva acentos e espaços do path', () {
    const relPath = 'assets/praises/p1/Cifra nível I.pdf';

    expect(LouvorPdfPath.fromLouvor(_louvorWithPdfId(relPath)), '/$relPath');
  });

  test('ignora o campo pdf (só nome do ficheiro no adapter)', () {
    final louvor = Louvor.fromManifest(
      nome: 'Teste',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Coro',
      pdf: 'https://outro.test/qualquer.pdf',
      pdfId: _encodePdfId('assets/praises/p1/m1.pdf'),
    );

    expect(LouvorPdfPath.fromLouvor(louvor), '/assets/praises/p1/m1.pdf');
  });
}
```

Run: `flutter test test/unit/features/pdf_opening/louvor_pdf_path_test.dart`
Expected: FAIL no terceiro teste (o `pdf` absoluto ainda vence).

Substituir `lib/features/pdf_opening/domain/utils/louvor_pdf_path.dart`:

```dart
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../catalog/domain/entities/louvor.dart';

/// Path remoto do PDF de um [Louvor] para [PdfSourceResolver] (UC-04).
abstract final class LouvorPdfPath {
  /// `/assets/praises/<praise>/<material>.pdf`, derivado do [Louvor.pdfId]
  /// (o adapter coldigom põe em `Louvor.pdf` só o nome do ficheiro). O
  /// `AssetBaseUrlResolver` escolhe a base coldigom pelo prefixo.
  static String fromLouvor(Louvor louvor) =>
      '/${PdfPathNormalizer.getPdfRelPath(louvor.pdfId)}';
}
```

(O único chamador de `remotePath` era `DownloadMissingPdfs`, apagado na Tarefa 10; confirmar com `grep -rn "LouvorPdfPath.remotePath" lib test` → vazio.)

- [ ] **Step 2: Apagar os ficheiros de lib**

Apagar a lista **Files → Delete (lib)**. Depois:

- `lib/core/database/isar_app_schemas.dart`: tirar `LouvorCacheSchema` da lista e o import de `collections/louvor_cache.dart`;
- `lib/core/database/isar_provider.dart:136`: `/// Schemas: [kAppIsarSchemas] (catálogo coldigom, playlists, índices offline, caches de cifra/gestos).`;
- `lib/core/constants/storage_keys.dart`: apagar `catalogLastSyncAt`, `manifestChecksum`, `lastChecksumPollAt` (com os docs);
- `lib/core/constants/offline_config.dart`: apagar `catalogChecksumPollMinInterval`; no doc de `coldigomCatalogSyncMinInterval` tirar «— o mesmo dos 30 min do checksum PLPCG»;
- `lib/features/coldigom/data/constants/coldigom_endpoints.dart`: apagar `plpcgManifest` e `plpcgManifestChecksum` (com os docs);
- `lib/features/catalog/domain/entities/louvor.dart`: apagar o campo `shortId` (doc, construtor, `fromManifest` e o repasse); doc da classe: «Entidade de domínio — um PDF do catálogo coldigom. [praiseId] agrupa materiais do mesmo louvor (ver [LouvorGroup]). [searchTitleNorm], [searchContentTokens] e [searchCompactContent] são pré-computados em [Louvor.fromManifest] para a busca UC-01.» (o nome `fromManifest` fica — renomear não é deste plano); doc de `praiseId`: «Id do praise no coldigom — identidade do louvor lógico.»;
- `lib/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart`: apagar `findLouvorGroupByPdfId`, e os imports de `plpcg_catalog_source.dart` e `louvor.dart` se ficarem sem uso;
- `lib/features/catalog/domain/utils/louvor_classification.dart`: apagar `collectAvailableArranjos` (o plano 1 manteve-o só para o `LouvoresManifest.availableArranjos`) e o teste dele, se existir (`grep -rn collectAvailableArranjos test`);
- docs que citam o que saiu: `coldigom_catalog_source.dart` (doc de `ColdigomGroupParts`: «Tudo o que os caches Coldigom têm de um praise, por tipo.»), `coldigom_catalog_source_provider.dart` (tirar a frase sobre `plpcgCatalogSourceProvider`), `coldigom_search_index.dart` (doc da classe: «Índice de busca do catálogo coldigom — ranking número exato → título exato → parcial (UC-01), sobre praises; a unidade da Home é o grupo, que já sai montado daqui.»; e o comentário que cita `SearchLouvorByNumberOrText._rankByTitle` → «só sobra o número exato»), `coldigom_praise_cache.dart:11` («… numa transação.» sem `[LouvorCache]`), `coldigom_praise_cache_warmup.dart` (doc do provider: «Busca sob demanda os materiais do praise ao abrir o leitor (áudio/cifra/letra no sheet).»).

Run: `flutter analyze lib`
Expected: limpo. Um erro aqui é um chamador esquecido — resolver pelo destino da tabela da Unidade B, nunca recriando o que saiu.

- [ ] **Step 3: Regenerar Isar**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: nenhum `.g.dart` novo além dos que já existiam; `louvor_cache.g.dart` não volta. Commitar os `.g.dart` que o build_runner tocar.

- [ ] **Step 4: Testes**

Apagar a lista **Files → Delete (test)** e tirar a entrada de `fake_catalog_repository.dart` de `test/support/README.md`. Depois:

- **Overrides do manifesto que sobraram:** `grep -rln "louvoresManifestOverride\|louvoresManifestLoadingOverride\|louvoresManifestErrorOverride\|louvoresManifestProvider\|LouvoresManifest" test` → em cada ficheiro apagar a linha do override, o import de `louvores_manifest_test_helpers.dart`/`louvores_manifest.dart`/`louvores_manifest_provider.dart` e `await container.read(louvoresManifestProvider.future);` quando houver. Onde o manifesto tinha louvores que o teste ainda precisa, eles já estão no `coldigomLouvoresOverride` (Tarefa 7).
- **`catalog_source_test.dart`:** apagar os grupos `'PlpcgCatalogSource'`, `'CompositeCatalogSource'`, `'CompositeCatalogSource — fusão por praise'` e, em `'searchLocal / search'`, os quatro testes `PlpcgCatalogSource.*`; apagar os fixtures e helpers que ficarem sem uso (`_plpcg*`, `_manifest*`, `_aliases*` — o analyze aponta `unused_element`).
- **`louvor_praise_id_test.dart`:** ficar só com `'effectiveGroupId prefere praiseId, depois groupId, depois cálculo'`; apagar os três testes de DTO/cache e os imports de `louvor_cache.dart`, `louvor_cache_mapper.dart`, `louvor_dto.dart`.
- **`isar_smoke_test.dart`:** abrir com `schemas: [OfflinePdfIndexSchema]`, apagar o teste `'CRUD LouvorCache com lookup por pdfId indexado'` e o import de `louvor_cache.dart`.
- **`offline_test_helpers.dart`:** apagar `openOfflineCatalogTestIsar` e o import de `louvor_cache.dart`; quem o chamava usa `openOfflineTestIsar`.
- **`fetch_and_store_pdf_test.dart:81`** e **`offline_pdf_repository_test.dart:96`:** tirar `LouvorCacheSchema` da lista de schemas (e o import).
- **`test/integration/uc01_search_home_test.dart`:** substituir inteiro por:

```dart
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UC-01 integração — busca por número no catálogo coldigom em memória', () {
    final louvor = Louvor.fromManifest(
      nome: 'Louvor de teste',
      numero: '100',
      categoria: 'Partitura',
      classificacao: 'Coro',
      pdf: 'm1.pdf',
      pdfId: 'test-id',
      groupId: 'p1',
      praiseId: 'p1',
    );
    final group = LouvorGroup.fromLouvores([louvor]).single;
    final index = ColdigomSearchIndex.build([
      ColdigomIndexedPraise.build(
        praiseId: 'p1',
        numero: '100',
        nome: 'Louvor de teste',
        searchTokens: 'louvor teste 100',
        group: group,
      ),
    ]);

    final results = index.search('100');

    expect(results, hasLength(1));
    expect(results.single.primaryLouvor?.pdfId, 'test-id');
  });
}
```

- **`shortId` do `Louvor`:** `grep -rn "shortId:" test | grep -i "fromManifest\|Louvor("` → tirar o argumento onde for de `Louvor` (não mexer em `shortId` de praise/`ColdigomPraiseMetadata`/DTOs do plano 1).

Run: `flutter analyze && flutter test`
Expected: analyze limpo, suíte verde.

- [ ] **Step 5: Greps de fecho**

Run:

```bash
grep -rnE "louvoresManifestProvider|LouvoresManifest|plpcgCatalogSourceProvider|PlpcgCatalogSource|PlpcgSearchIndex|runPlpcgSearchPipeline|SearchLouvorByNumberOrText|CompositeCatalogSource|compositeCatalogSourceProvider|ManifestMaterialAliases|manifestMaterialAliasesProvider|louvoresByPdfIdProvider|findLouvorByPdfIdWithColdigom|findLouvorGroupByPdfId|resolveLouvorDataSource|LouvorCache\b|LouvorCacheSchema|LouvorCacheMapper|LouvorDto|CatalogRepository|CatalogLocalDatasource\b|catalogLocalDatasourceProvider|CatalogRemoteDatasource|catalogChecksumPoll|PollManifestChecksum|ManifestChecksumStore|CatalogSyncMetadataStore|RemapPdfIdsAfterCatalogUpdate|OfflineCatalogManifestSyncListener|mergeLocalSearchResults|plpcgManifest|/api/plpcg/manifest" lib test
```

Expected: nenhuma linha. (`PlaylistsNotifier.findLouvorByPdfId` e `ColdigomCatalogLocalDatasource` não casam com os padrões acima de propósito.)

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "chore(catalog): apaga a pilha do manifesto, o CompositeCatalogSource e o LouvorCache

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Apagar `LouvorDataSource`, `louvorDataSourceFromPdfId` e `LouvorGroup.isColdigom`

Com um espaço de ids só, o enum e os campos `source` de `Louvor`, `AudioTrack`, `ChordMaterial`, `GestureMaterial` e `YoutubeMaterial` são apagados. `LouvorGroup.isColdigom` sai; os chamadores assumem coldigom. `ContributionSource` fica; `contributionSourceOf` sai (desvio 2).

**Files:**
- Delete: `lib/features/catalog/domain/entities/louvor_data_source.dart`
- Modify: `lib/core/utils/pdf_id_codec.dart` (sai `louvorDataSourceFromPdfId` e o import de feature)
- Modify: `lib/features/catalog/domain/entities/louvor.dart`, `youtube_material.dart`, `louvor_group.dart`
- Modify: `lib/features/audio_player/domain/entities/audio_track.dart`, `lib/features/chords/domain/entities/chord_material.dart`, `lib/features/gestures/domain/entities/gesture_material.dart`
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`, `lib/features/coldigom/data/coldigom_praise_cache_warmup.dart:118-128`, `lib/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart`
- Modify: `lib/features/contributions/domain/entities/contribution_kind.dart:58-69`, `lib/features/contributions/presentation/widgets/contribution_context_fields.dart:208-213`
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart:686`, `lib/features/audio_player/presentation/pages/audio_player_screen.dart:192-195`, `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart:357-359`
- Test: todos os que o grep apontar (≈ 33 ficheiros; lista em `grep -rln "LouvorDataSource\|isColdigom" test`)

**Interfaces:**
- Produces: construtores de `Louvor`/`Louvor.fromManifest`, `AudioTrack`, `ChordMaterial`, `GestureMaterial`, `YoutubeMaterial` sem o parâmetro `source`; `LouvorGroup` sem `isColdigom`; `ContributionSource` inalterado; sem `contributionSourceOf`.

- [ ] **Step 1: Teste que prende a adoção sem o gate de fonte (falha)**

Em `test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart`, substituir o teste `'grupos PLPCG são ignorados; sem Isar devolve vazio sem lançar'` por:

```dart
    test(
      'grupo remoto sem meta também é adotado (um espaço de ids só)',
      () async {
        final semMeta = LouvorGroup.fromLouvores([
          Louvor.fromManifest(
            nome: 'Aleluia',
            numero: '001',
            categoria: 'Partitura',
            classificacao: 'Coro',
            pdf: 'm1.pdf',
            pdfId: encodePdfId('assets/praises/p-sem-meta/m1.pdf'),
            groupId: 'p-sem-meta',
            praiseId: 'p-sem-meta',
          ),
        ]).single;

        expect(
          await AdoptColdigomSearchNovelties(local)([
            semMeta,
          ], knownPraiseIds: const {}),
          {'p-sem-meta'},
        );
      },
    );

    test('sem Isar devolve vazio sem lançar', () async {
      expect(
        await const AdoptColdigomSearchNovelties(
          ColdigomCatalogLocalDatasource.unavailable(),
        )([_remoteGroup('p-new')], knownPraiseIds: const {}),
        isEmpty,
      );
    });
```

Run: `flutter test test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart`
Expected: FAIL no primeiro (o Louvor sem `source` é PLPCG por omissão → `isColdigom` falso → não adota).

- [ ] **Step 2: Entidades e codec**

- Apagar `lib/features/catalog/domain/entities/louvor_data_source.dart`.
- `pdf_id_codec.dart`: apagar `louvorDataSourceFromPdfId` e o import `package:coldigui/features/catalog/domain/entities/louvor_data_source.dart`.
- `louvor.dart`, `youtube_material.dart`, `audio_track.dart` (também no `copyWith`), `chord_material.dart`, `gesture_material.dart`: apagar o import, o parâmetro `this.source = …`, o campo `final LouvorDataSource source;` (com o doc) e, em `Louvor.fromManifest`, o parâmetro e o repasse. Nos docs de `materialKindId` destas classes, «`null` no acervo PLPCG» → «`null` quando o dump não traz o kind».
- `louvor_group.dart`: apagar o getter `isColdigom` (com o doc) e o import de `louvor_data_source.dart`; no doc de `lyrics`, «`null` no PLPCG e sem letra» → «`null` sem letra».

- [ ] **Step 3: Chamadores**

- `coldigom_louvor_adapter.dart`: apagar as cinco linhas `source: LouvorDataSource.coldigom,` e o import.
- `coldigom_praise_cache_warmup.dart`: o bloco

```dart
        // Só materiais Coldigom nativos entram no cache Coldigom; um louvor
        // do manifest já vive na fonte PLPCG e o composite funde os dois.
        if (louvor.source == LouvorDataSource.coldigom) {
          ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
            louvor,
          ]);
        }
```

passa a

```dart
        ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
          louvor,
        ]);
```

(e sai o import de `louvor_data_source.dart`).
- `adopt_coldigom_search_novelties.dart`: a condição fica `if (!knownPraiseIds.contains(group.groupId) && _local.findByPraiseIdSync(group.groupId) == null)`; doc: «Só grupos fora de [knownPraiseIds] (os ids do índice hidratado) e fora do Isar.»
- `contribution_kind.dart`: apagar `contributionSourceOf` e o doc que a precede.
- `material_sheet.dart:686`, `audio_player_screen.dart:192-195`, `pdf_reader_screen.dart:357-359`: o argumento vira `source: ContributionSource.coldigom,` (conferir o import de `contribution_kind.dart`; tirar o de `louvor_data_source.dart`).
- `contribution_context_fields.dart:208-213`: `onSelected: (l) => onSelected(praiseId: l.groupId, source: ContributionSource.coldigom),` e sai o import de `louvor_data_source.dart`.
- Restos do plano 2: `grep -rnE "LouvorDataSource|louvorDataSourceFromPdfId|(louvor|track|chord|gesture|youtube|item|l)\??\.source\b" lib` — cada linha que sobrar é um `source:` de material/chip (ex.: `home_empty_state.dart`, `louvor_group_card.dart`, `playlist_tile_detail_chips.dart`, `carousel_items_provider.dart`, `playlists_provider.dart`) → apagar o argumento/uso.

Run: `flutter analyze lib`
Expected: limpo.

- [ ] **Step 4: Testes**

Remoção mecânica (revisar o diff antes de seguir):

```bash
perl -0pi -e 's/\n[ \t]*source: LouvorDataSource\.(coldigom|plpcg),//g; s/,?[ \t]*source: LouvorDataSource\.(coldigom|plpcg)//g' $(grep -rl "LouvorDataSource" test)
perl -ni -e 'print unless /import .*louvor_data_source\.dart/' $(grep -rl "louvor_data_source.dart" test)
```

Depois, à mão (o analyze aponta cada um):
- `expect(group.isColdigom, isTrue);` em `louvor_group_gestures_test.dart:18`, `louvor_group_materials_test.dart:261,297`, `lyrics_material_test.dart:56` → apagar a linha;
- `resolve_catalog_material_test.dart`: `expect((material! as PdfMaterial).louvor.source, LouvorDataSource.coldigom);` → `expect((material! as PdfMaterial).louvor.pdfId, _coldigomPdfId);`;
- testes que comparavam `source` de itens/chips (se o plano 2 deixou algum) → apagar a asserção de fonte, manter as outras.

Run: `flutter analyze && flutter test`
Expected: analyze limpo, suíte verde (inclui o teste do Step 1).

- [ ] **Step 5: Grep de fecho**

Run: `grep -rnE "LouvorDataSource|louvorDataSourceFromPdfId|isColdigom\b|contributionSourceOf" lib test`
Expected: nenhuma linha.

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "chore(catalog): apaga LouvorDataSource, source dos materiais e LouvorGroup.isColdigom

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade E — Servidor e docs

### Task 13: Script único do D1 — `migrate-legacy-playlist-ids.ts`

Spec §6.3: lê `user_playlists` com id legado em `items` ou `pdf_ids` (linhas anteriores à 0008 têm `items='[]'` e derivam das duas listas — as duas colunas são reescritas), resolve pelo mesmo crosswalk, grava `items` e `pdf_ids` com `version = version + 1` e **`updated_at` intacto**; `--dry-run` imprime o diff e a contagem; o modo real grava um relatório. **Corre só depois do deploy do app e com pedido do dono** — esta tarefa escreve e testa o script, não o executa contra `--remote`.

**Files:**
- Create: `workers/plpcg-catalog/scripts/legacy_playlist_ids.ts` (funções puras)
- Create: `workers/plpcg-catalog/scripts/legacy_playlist_ids.test.ts`
- Create: `workers/plpcg-catalog/scripts/migrate-legacy-playlist-ids.ts` (casca: wrangler + crosswalk)
- Modify: `workers/plpcg-catalog/package.json` (`test` cobre `scripts/`; script `migrate:legacy-ids`)
- Modify: `workers/plpcg-catalog/.gitignore` (`scripts/out/`)
- Modify: `workers/plpcg-catalog/README.md` (runbook)

**Interfaces:**
- Consumes: `parseItemsColumn`, `itemsFromLegacy`, `listsFromItems`, `PlaylistItem` de `workers/plpcg-catalog/src/playlists/items.ts`; `POST {COLDIGOM_API_BASE_URL}/api/plpcg/crosswalk` (C2).
- Produces (em `legacy_playlist_ids.ts`): `interface PlaylistRow { user_id; id; items: string | null; pdf_ids: string | null; audio_ids: string | null; version: number }`, `interface RowRewrite`, `interface MigrationReport`, `decodePdfId`, `encodePdfId`, `isLegacyPdfId`, `coldigomPdfIdFromAssetUrl`, `resolvedFromCrosswalk(items: unknown): Map<string, string>`, `rowItems(row)`, `collectLegacyIds(rows): Set<string>`, `rewriteRow(row, resolved): RowRewrite | null`, `updateSql(rewrite): string`, `buildReport(rows, rewrites, legacy, resolved, now?)`.

- [ ] **Step 1: Teste**

```ts
// workers/plpcg-catalog/scripts/legacy_playlist_ids.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  buildReport,
  coldigomPdfIdFromAssetUrl,
  collectLegacyIds,
  encodePdfId,
  isLegacyPdfId,
  resolvedFromCrosswalk,
  rewriteRow,
  updateSql,
  type PlaylistRow,
  type RowRewrite,
} from './legacy_playlist_ids.ts';

const legadoA = encodePdfId('ColAdultos/001.pdf');
const legadoPes = encodePdfId('assets/PES/Hino 1.pdf');
const desconhecido = encodePdfId('ColAdultos/999.pdf');
const coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
const coldigomB = encodePdfId('assets/praises/p9/m 2.pdf');
const audio = encodePdfId('assets/praises/p1/a.mp3');
const cifraLegada = encodePdfId('ColAdultos/001.chord');

function row(partial: Partial<PlaylistRow>): PlaylistRow {
  return {
    user_id: 'u1',
    id: 'pl1',
    items: '[]',
    pdf_ids: '[]',
    audio_ids: '[]',
    version: 3,
    ...partial,
  };
}

test('encodePdfId é o do app (mesmos literais de pdf_id_codec_test.dart)', () => {
  assert.equal(encodePdfId('assets/praises/p1/m1.pdf'), 'YXNzZXRzL3ByYWlzZXMvcDEvbTEucGRm');
  assert.equal(
    encodePdfId('ColAdultos/Cifra nível I/001.pdf'),
    'Q29sQWR1bHRvcy9DaWZyYSBuw612ZWwgSS8wMDEucGRm',
  );
});

test('isLegacyPdfId: PDF fora de assets/praises; o resto não', () => {
  assert.equal(isLegacyPdfId(legadoA), true);
  assert.equal(isLegacyPdfId(legadoPes), true);
  assert.equal(isLegacyPdfId(coldigomA), false);
  assert.equal(isLegacyPdfId(audio), false);
  assert.equal(isLegacyPdfId(cifraLegada), false);
  assert.equal(isLegacyPdfId('lyrics:p1'), false);
  assert.equal(isLegacyPdfId(''), false);
});

test('coldigomPdfIdFromAssetUrl lê o r2Key da URL', () => {
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/assets/praises/p1/m1.pdf'), coldigomA);
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/assets/praises/p9/m%202.pdf'), coldigomB);
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/outra/coisa.pdf'), null);
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/assets/praises/p1'), null);
});

test('resolvedFromCrosswalk ignora entradas sem URL de assets/praises', () => {
  const resolved = resolvedFromCrosswalk({
    [legadoA]: { praiseId: 'p1', materialId: 'm1', url: 'https://c.test/assets/praises/p1/m1.pdf' },
    [legadoPes]: { praiseId: 'p2', materialId: 'm2', url: 'https://c.test/x.pdf' },
    [desconhecido]: 'lixo',
  });
  assert.deepEqual([...resolved], [[legadoA, coldigomA]]);
});

test('linha v2: troca mantendo kind e ordem; áudio e desconhecido ficam', () => {
  const rewrite = rewriteRow(
    row({
      items: JSON.stringify([
        { id: legadoA, kind: 'pdf' },
        { id: audio, kind: 'audio' },
        { id: desconhecido, kind: 'pdf' },
        { id: legadoA, kind: 'pdf' },
      ]),
      audio_ids: JSON.stringify([audio]),
    }),
    new Map([[legadoA, coldigomA]]),
  );
  assert.ok(rewrite);
  assert.deepEqual(rewrite.items, [
    { id: coldigomA, kind: 'pdf' },
    { id: audio, kind: 'audio' },
    { id: desconhecido, kind: 'pdf' },
    { id: coldigomA, kind: 'pdf' },
  ]);
  assert.deepEqual(rewrite.pdfIds, [coldigomA, desconhecido, coldigomA]);
  assert.deepEqual(rewrite.replaced, [
    [legadoA, coldigomA],
    [legadoA, coldigomA],
  ]);
  assert.deepEqual(rewrite.unknown, [desconhecido]);
});

test('linha anterior à 0008 (items vazio): deriva de pdf_ids/audio_ids', () => {
  const rewrite = rewriteRow(
    row({
      items: '[]',
      pdf_ids: JSON.stringify([legadoPes, coldigomA]),
      audio_ids: JSON.stringify([audio]),
    }),
    new Map([[legadoPes, coldigomB]]),
  );
  assert.ok(rewrite);
  assert.deepEqual(rewrite.items, [
    { id: coldigomB, kind: 'pdf' },
    { id: coldigomA, kind: 'pdf' },
    { id: audio, kind: 'audio' },
  ]);
  assert.deepEqual(rewrite.pdfIds, [coldigomB, coldigomA]);
});

test('sem legado resolvido a linha não muda', () => {
  assert.equal(
    rewriteRow(row({ items: JSON.stringify([{ id: desconhecido, kind: 'pdf' }]) }), new Map()),
    null,
  );
  assert.equal(
    rewriteRow(
      row({ items: JSON.stringify([{ id: coldigomA, kind: 'pdf' }]) }),
      new Map([[legadoA, coldigomA]]),
    ),
    null,
  );
});

test('collectLegacyIds junta as duas formas de linha', () => {
  const ids = collectLegacyIds([
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }, { id: audio, kind: 'audio' }]) }),
    row({ id: 'pl2', items: '[]', pdf_ids: JSON.stringify([legadoPes, coldigomA]) }),
  ]);
  assert.deepEqual([...ids].sort(), [legadoA, legadoPes].sort());
});

test('updateSql: version + 1, updated_at intacto, guarda de versão, aspas escapadas', () => {
  const sql = updateSql({
    userId: "u'1",
    id: 'pl1',
    version: 3,
    items: [{ id: coldigomA, kind: 'pdf' }],
    pdfIds: [coldigomA],
    replaced: [[legadoA, coldigomA]],
    unknown: [],
  });
  assert.match(sql, /version = version \+ 1/);
  assert.doesNotMatch(sql, /updated_at/);
  assert.match(sql, /WHERE user_id = 'u''1' AND id = 'pl1' AND version = 3;$/);
  assert.ok(sql.includes(`items = '${JSON.stringify([{ id: coldigomA, kind: 'pdf' }])}'`));
  assert.ok(sql.includes(`pdf_ids = '${JSON.stringify([coldigomA])}'`));
});

test('buildReport conta linhas, resolvidos e desconhecidos', () => {
  const rows = [
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }, { id: desconhecido, kind: 'pdf' }]) }),
  ];
  const resolved = new Map([[legadoA, coldigomA]]);
  const rewrites = rows
    .map((r) => rewriteRow(r, resolved))
    .filter((r): r is RowRewrite => r !== null);
  const report = buildReport(
    rows,
    rewrites,
    collectLegacyIds(rows),
    resolved,
    new Date('2026-09-23T00:00:00Z'),
  );
  assert.equal(report.rowsScanned, 1);
  assert.equal(report.rowsChanged, 1);
  assert.equal(report.legacyIds, 2);
  assert.equal(report.resolvedIds, 1);
  assert.deepEqual(report.unknownIds, [desconhecido]);
  assert.equal(report.generatedAt, '2026-09-23T00:00:00.000Z');
});
```

Em `workers/plpcg-catalog/package.json`, o script `test` passa a:

```json
    "test": "node --experimental-strip-types --test \"src/**/*.test.ts\" \"scripts/**/*.test.ts\"",
```

Run (em `workers/plpcg-catalog`): `npm test`
Expected: FAIL — `legacy_playlist_ids.ts` não existe.

- [ ] **Step 2: Funções puras**

```ts
// workers/plpcg-catalog/scripts/legacy_playlist_ids.ts
/**
 * Migração única dos ids legados das playlists no D1 (spec
 * docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md §6.3).
 *
 * Funções puras — sem D1, sem rede — testadas com `node:test`. A casca que
 * fala com o wrangler e com o crosswalk é `migrate-legacy-playlist-ids.ts`.
 * As regras espelham o app (`lib/core/utils/pdf_id_codec.dart`).
 */
import {
  itemsFromLegacy,
  listsFromItems,
  parseItemsColumn,
  type PlaylistItem,
} from '../src/playlists/items.ts';

/** Linha de `user_playlists` que o script lê. */
export interface PlaylistRow {
  user_id: string;
  id: string;
  items: string | null;
  pdf_ids: string | null;
  audio_ids: string | null;
  version: number;
}

/** O que muda numa linha. */
export interface RowRewrite {
  userId: string;
  id: string;
  version: number;
  items: PlaylistItem[];
  pdfIds: string[];
  replaced: Array<[string, string]>;
  unknown: string[];
}

export interface MigrationReport {
  generatedAt: string;
  rowsScanned: number;
  rowsChanged: number;
  legacyIds: number;
  resolvedIds: number;
  unknownIds: string[];
  rows: Array<{
    userId: string;
    id: string;
    replaced: Array<[string, string]>;
    unknown: string[];
  }>;
}

const strictUtf8 = new TextDecoder('utf-8', { fatal: true });
const PRAISES_MARKER = '/assets/praises/';
const PRAISES_R2_PREFIX = 'assets/praises/';

/** Path que [id] codifica (base64url UTF-8), ou `null`. Espelha `PdfPathNormalizer.getPdfRelPath`. */
export function decodePdfId(id: string): string | null {
  if (id.length === 0 || !/^[A-Za-z0-9_-]+$/.test(id)) return null;
  try {
    return strictUtf8.decode(Buffer.from(id, 'base64url'));
  } catch {
    return null;
  }
}

/** Espelha `encodePdfId`: base64url do UTF-8, sem padding. */
export function encodePdfId(path: string): string {
  return Buffer.from(path, 'utf8').toString('base64url');
}

/** Espelha `isLegacyPdfId`: PDF cujo path não está em `assets/praises/`. */
export function isLegacyPdfId(id: string): boolean {
  const path = decodePdfId(id);
  if (path === null) return false;
  return path.toLowerCase().endsWith('.pdf') && !path.startsWith(PRAISES_R2_PREFIX);
}

/** Espelha `coldigomPdfIdFromAssetUrl`: `encodePdfId(r2Key)` lido da URL. */
export function coldigomPdfIdFromAssetUrl(url: string): string | null {
  const index = url.indexOf(PRAISES_MARKER);
  if (index < 0) return null;
  const r2Key = url.substring(index + 1);
  const rest = r2Key.substring(PRAISES_R2_PREFIX.length);
  if (rest.length === 0 || !rest.includes('/')) return null;
  try {
    return encodePdfId(decodeURIComponent(r2Key));
  } catch {
    return null;
  }
}

/** Legado → id coldigom a partir do `items` de uma resposta do crosswalk. */
export function resolvedFromCrosswalk(items: unknown): Map<string, string> {
  const resolved = new Map<string, string>();
  if (typeof items !== 'object' || items === null) return resolved;
  for (const [pdfId, value] of Object.entries(items as Record<string, unknown>)) {
    if (typeof value !== 'object' || value === null) continue;
    const url = (value as { url?: unknown }).url;
    if (typeof url !== 'string') continue;
    const coldigomId = coldigomPdfIdFromAssetUrl(url);
    if (coldigomId !== null) resolved.set(pdfId, coldigomId);
  }
  return resolved;
}

function parseIdList(text: string | null): string[] {
  if (!text) return [];
  try {
    const parsed: unknown = JSON.parse(text);
    return Array.isArray(parsed)
      ? parsed.filter((x): x is string => typeof x === 'string')
      : [];
  } catch {
    return [];
  }
}

/**
 * Ordem única da linha: `items`; linhas anteriores à migration 0008
 * (`items = '[]'`) derivam das duas colunas v1, como o `rowToJson` do handler.
 */
export function rowItems(row: PlaylistRow): PlaylistItem[] {
  const stored = parseItemsColumn(row.items);
  if (stored.length > 0) return stored;
  return itemsFromLegacy(parseIdList(row.pdf_ids), parseIdList(row.audio_ids));
}

/** Ids legados de todas as [rows] (áudio nunca é legado). */
export function collectLegacyIds(rows: PlaylistRow[]): Set<string> {
  const ids = new Set<string>();
  for (const row of rows) {
    for (const item of rowItems(row)) {
      if (item.kind !== 'audio' && isLegacyPdfId(item.id)) ids.add(item.id);
    }
  }
  return ids;
}

/**
 * [row] com os legados resolvidos trocados (kind e ordem mantidos), ou `null`
 * se nenhum legado desta linha foi resolvido. Desconhecidos ficam — o app
 * mostra-os como indisponíveis.
 */
export function rewriteRow(
  row: PlaylistRow,
  resolved: ReadonlyMap<string, string>,
): RowRewrite | null {
  const replaced: Array<[string, string]> = [];
  const unknown: string[] = [];
  const items = rowItems(row).map((item): PlaylistItem => {
    if (item.kind === 'audio' || !isLegacyPdfId(item.id)) return item;
    const mapped = resolved.get(item.id);
    if (mapped === undefined) {
      unknown.push(item.id);
      return item;
    }
    replaced.push([item.id, mapped]);
    return { id: mapped, kind: item.kind };
  });
  if (replaced.length === 0) return null;
  return {
    userId: row.user_id,
    id: row.id,
    version: row.version,
    items,
    pdfIds: listsFromItems(items).pdfIds,
    replaced,
    unknown,
  };
}

function sqlString(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

/**
 * UPDATE de uma linha: `items` e `pdf_ids` novos, `version + 1` e
 * **`updated_at` intacto** (spec §6.3, facto M10) — um cliente sem push
 * pendente puxa a linha (mesmo `updatedAt`, `version` maior) e ninguém leva
 * 409 nem cópia de conflito. `AND version = N` não pisa uma escrita que
 * chegou entretanto: essa linha fica para uma segunda passada.
 */
export function updateSql(rewrite: RowRewrite): string {
  return (
    `UPDATE user_playlists SET items = ${sqlString(JSON.stringify(rewrite.items))}, ` +
    `pdf_ids = ${sqlString(JSON.stringify(rewrite.pdfIds))}, ` +
    `version = version + 1 ` +
    `WHERE user_id = ${sqlString(rewrite.userId)} AND id = ${sqlString(rewrite.id)} ` +
    `AND version = ${Math.trunc(rewrite.version)};`
  );
}

export function buildReport(
  rows: PlaylistRow[],
  rewrites: RowRewrite[],
  legacy: ReadonlySet<string>,
  resolved: ReadonlyMap<string, string>,
  now: Date = new Date(),
): MigrationReport {
  const all = [...legacy];
  return {
    generatedAt: now.toISOString(),
    rowsScanned: rows.length,
    rowsChanged: rewrites.length,
    legacyIds: legacy.size,
    resolvedIds: all.filter((id) => resolved.has(id)).length,
    unknownIds: all.filter((id) => !resolved.has(id)).sort(),
    rows: rewrites.map((r) => ({
      userId: r.userId,
      id: r.id,
      replaced: r.replaced,
      unknown: r.unknown,
    })),
  };
}
```

Run: `npm test`
Expected: PASS (os testes de `src/` continuam verdes).

- [ ] **Step 3: A casca (wrangler + crosswalk)**

```ts
// workers/plpcg-catalog/scripts/migrate-legacy-playlist-ids.ts
/**
 * Migração única dos ids legados das playlists no D1 (spec 2026-09-23 §6.3).
 *
 * Corre **depois** do deploy do app novo (senão um cliente antigo repõe ids
 * legados logo a seguir) e só com pedido do dono. Ver o runbook no README.
 *
 *   COLDIGOM_API_BASE_URL=https://coldigom-api.jairofilho79.workers.dev \
 *     npm run migrate:legacy-ids -- --dry-run [--local]
 */
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  buildReport,
  collectLegacyIds,
  resolvedFromCrosswalk,
  rewriteRow,
  updateSql,
  type PlaylistRow,
  type RowRewrite,
} from './legacy_playlist_ids.ts';

const DATABASE = 'plpcg-catalog';
const CROSSWALK_BATCH = 500;

function d1(target: string, extra: string[]): unknown {
  const out = execFileSync(
    'npx',
    ['wrangler', 'd1', 'execute', DATABASE, target, '--json', ...extra],
    { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024 },
  );
  return JSON.parse(out);
}

function selectRows(target: string): PlaylistRow[] {
  const parsed = d1(target, [
    '--command',
    'SELECT user_id, id, items, pdf_ids, audio_ids, version FROM user_playlists WHERE deleted_at IS NULL',
  ]);
  const first = Array.isArray(parsed) ? parsed[0] : parsed;
  const results = (first as { results?: unknown } | undefined)?.results;
  if (!Array.isArray(results)) throw new Error('resposta inesperada do wrangler');
  return results as PlaylistRow[];
}

async function resolve(base: string, ids: string[]): Promise<Map<string, string>> {
  const resolved = new Map<string, string>();
  for (let start = 0; start < ids.length; start += CROSSWALK_BATCH) {
    const batch = ids.slice(start, start + CROSSWALK_BATCH);
    const asked = new Set(batch);
    const response = await fetch(`${base}/api/plpcg/crosswalk`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pdfIds: batch }),
    });
    if (!response.ok) throw new Error(`crosswalk respondeu ${response.status}`);
    const body = (await response.json()) as { items?: unknown };
    for (const [legacy, coldigom] of resolvedFromCrosswalk(body.items)) {
      if (asked.has(legacy)) resolved.set(legacy, coldigom);
    }
  }
  return resolved;
}

async function main(): Promise<void> {
  const args = new Set(process.argv.slice(2));
  const dryRun = args.has('--dry-run');
  const target = args.has('--local') ? '--local' : '--remote';
  const base = (process.env.COLDIGOM_API_BASE_URL ?? '').replace(/\/$/, '');
  if (!base) throw new Error('defina COLDIGOM_API_BASE_URL');

  const rows = selectRows(target);
  const legacy = collectLegacyIds(rows);
  const resolved = await resolve(base, [...legacy]);
  const rewrites = rows
    .map((row) => rewriteRow(row, resolved))
    .filter((r): r is RowRewrite => r !== null);
  const report = buildReport(rows, rewrites, legacy, resolved);

  for (const r of rewrites) {
    console.log(`${r.userId}/${r.id} (v${r.version} → v${r.version + 1}):`);
    for (const [from, to] of r.replaced) console.log(`  - ${from}\n  + ${to}`);
    for (const id of r.unknown) console.log(`  ? ${id} (desconhecido, fica)`);
  }
  console.log(
    `${report.rowsScanned} linhas lidas; ${report.rowsChanged} a reescrever; ` +
      `${report.legacyIds} ids legados: ${report.resolvedIds} resolvidos, ` +
      `${report.unknownIds.length} desconhecidos.`,
  );
  if (dryRun) {
    console.log('--dry-run: nada gravado.');
    return;
  }

  const outDir = join(import.meta.dirname, 'out');
  mkdirSync(outDir, { recursive: true });
  const stamp = report.generatedAt.replaceAll(':', '-');
  const sqlPath = join(outDir, `migrate-legacy-playlist-ids-${stamp}.sql`);
  writeFileSync(sqlPath, rewrites.map(updateSql).join('\n') + '\n');
  if (rewrites.length > 0) d1(target, ['--file', sqlPath]);
  const reportPath = join(outDir, `migrate-legacy-playlist-ids-${stamp}.json`);
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(`Gravado. SQL: ${sqlPath}\nRelatório: ${reportPath}`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
```

Em `package.json`, junto dos outros scripts:

```json
    "migrate:legacy-ids": "node --experimental-strip-types scripts/migrate-legacy-playlist-ids.ts",
```

Em `workers/plpcg-catalog/.gitignore`, acrescentar a linha `scripts/out/`.

- [ ] **Step 4: Smoke local (sem tocar produção)**

Run (em `workers/plpcg-catalog`, com o D1 local migrado — `npm run db:migrate:local`):

```bash
npx wrangler d1 execute plpcg-catalog --local --command "INSERT INTO user_playlists (id, user_id, nome, pdf_ids, created_at, updated_at, version, items) VALUES ('smoke', 'u-smoke', 'Smoke', '[\"MzAxMDIwMjUvQSBUaSBTZW5ob3IgLSBTb2xvIGUgVm96ZXMucGRm\"]', '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z', 1, '[]')"
COLDIGOM_API_BASE_URL=https://coldigom-api.jairofilho79.workers.dev npm run migrate:legacy-ids -- --dry-run --local
COLDIGOM_API_BASE_URL=https://coldigom-api.jairofilho79.workers.dev npm run migrate:legacy-ids -- --local
npx wrangler d1 execute plpcg-catalog --local --command "SELECT items, pdf_ids, version, updated_at FROM user_playlists WHERE id = 'smoke'"
npx wrangler d1 execute plpcg-catalog --local --command "DELETE FROM user_playlists WHERE id = 'smoke'"
```

Expected: o dry-run lista `u-smoke/smoke (v1 → v2)` com `- MzAx…` e `+ <id coldigom>`; o modo real grava; o `SELECT` mostra `items` com `{"id":"<id coldigom>","kind":"pdf"}`, `pdf_ids` com o mesmo id, `version = 2` e `updated_at` **igual** a `2026-09-01T00:00:00Z`. (Só crosswalk de produção é lido; o D1 é o local.) Se o crosswalk ainda não estiver em produção (Tarefa 0, Step 4), pular este step e anotar.

- [ ] **Step 5: Runbook no README**

Em `workers/plpcg-catalog/README.md`, antes de «## Setup local»:

````markdown
## Migração única de ids legados das playlists (set/2026)

Spec: `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md` §6.3. Troca, em `user_playlists.items` e `pdf_ids`, os ids de PDF do manifesto PLPCG pelos ids coldigom (via `POST /api/plpcg/crosswalk`), com `version + 1` e `updated_at` intacto. Desconhecidos ficam (o app mostra-os indisponíveis). `short_links` não é migrado.

**Só depois do deploy do app novo e com pedido do dono.**

```bash
cd workers/plpcg-catalog
export COLDIGOM_API_BASE_URL=https://coldigom-api.jairofilho79.workers.dev
npm run migrate:legacy-ids -- --dry-run   # diff + contagem, não grava
npm run migrate:legacy-ids                # grava; SQL e relatório em scripts/out/
```

Pode correr de novo: linhas já normalizadas não mudam, e uma linha que mudou entre a leitura e a escrita (guarda `AND version = N`) fica para a passada seguinte. O normalizador do app (`NormalizeLegacyMaterialIds`) cobre o que escapar.
````

- [ ] **Step 6: Typecheck, testes e commit**

Run (em `workers/plpcg-catalog`): `npm run typecheck && npm test`
Expected: typecheck limpo (o `tsconfig` só inclui `src/`; os scripts correm pelo strip-types), testes verdes.

```bash
git add workers/plpcg-catalog/scripts/legacy_playlist_ids.ts workers/plpcg-catalog/scripts/legacy_playlist_ids.test.ts workers/plpcg-catalog/scripts/migrate-legacy-playlist-ids.ts workers/plpcg-catalog/package.json workers/plpcg-catalog/.gitignore workers/plpcg-catalog/README.md
git commit -m "feat(worker): script único para migrar ids legados das playlists no D1

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Docs

**Files:**
- Modify: `docs/features/FEATURE_INDEX.md`
- Modify: `docs/features/LOUVOR_GROUPING.md`
- Modify: `docs/use-cases/UC-09-configure-offline.md`
- Modify: `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md`, `docs/superpowers/specs/2026-09-13-short-id-share-design.md`, `docs/superpowers/specs/2026-09-12-lista-ao-vivo-design.md`, `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md`

- [ ] **Step 1: FEATURE_INDEX — tabela de status**

Em `docs/features/FEATURE_INDEX.md`:
- linha 3 (`**Última atualização:**`): pôr no início «setembro de 2026 (**fim da fonte PLPCG** — o app lê só o catálogo coldigom; ids legados normalizados pelo crosswalk; `/offline` de uma secção; link de lista por praise `?p=`; ao vivo sem regra «só Coldigom») ·» e manter o resto como histórico;
- linha `catalog`: substituir a coluna de notas por: «**Estado atual (23/09/2026):** o catálogo é o dump `GET /api/plpcg/catalog` do coldigom no Isar ([SyncColdigomCatalog], ETag/304) ou em memória sem Isar, hidratado no [ColdigomSearchIndex] (um [LouvorGroup] por praise); `catalogSourceProvider` = [ColdigomCatalogSource]; filtros únicos ([CatalogFilterState] + [matchesCatalogFilters]); ids legados do manifesto trocados uma vez pelo crosswalk ([NormalizeLegacyMaterialIds], [ColdigomRemoteDatasource.resolveLegacyPdfIds]); o manifesto, o [CompositeCatalogSource], o `LouvorCache` e o `LouvorDataSource` foram apagados. Spec [fim da fonte PLPCG](../superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md). **Histórico:** manifest servido pelo coldigom (18/09, spec [catálogo coldigom modo único](../superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md)); D1 `plpcg-catalog` (jun/2026).»;
- linha `library`: acrescentar «**set/2026:** sem seletor de fonte — pipeline único local (índice → [matchesCatalogFilters] → ordenar → paginar); filtros tom/ritmo/categoria/tags/tipo de material.»;
- linha `offline`: substituir por «Local-first ([ResolvePdfForReader], LRU on-demand); **uma secção** «Baixar para usar offline» ([ColdigomOfflineSection]): estado do catálogo e do disco, um «Atualizar» (sync + reconcile), tipos de material (todos sem login; favoritos no topo com login), baixar/parar ([DownloadColdigomMaterials]) e «Remover todos os baixados» ([RemoveColdigomDownloads]); índice offline normalizado de ids legados sob o [offlineMaintenanceLockProvider]. Saíram (23/09/2026) o bulk por categoria PLPCG, `OFFLINE_AVAILABLE` e o gate UC-09/UC-10.»;
- linha `playlists`: trocar o trecho «**link curto por shortId set/2026** … ([showColdigomShareDialog])» por «**link por praise** `?p=<shortIds>&n=…` (origem `v2.plpcg.com`; import pelo índice local com o material favorito); links `?s=`/longos antigos → mensagem de link antigo; folheto sempre com QR»;
- linha `live`: acrescentar «**23/09/2026:** sem a regra «só Coldigom» (qualquer lista vai ao ar).»

- [ ] **Step 2: FEATURE_INDEX — débito, trailing actions e APIs**

- «## Débitos técnicos»: a linha do gate passa a `| ~~Gate Coldigom no share de listas~~ — **pago em 2026-09-23** (link por praise, sem gate nem diálogo; spec [fim da fonte PLPCG](../superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md) §4). | — | — |`.
- Linha `CarouselBarTrailingActions` (≈ 1254): o trecho «(bottom sheet 2 modos — Folheto (imagem + link curto + QR, só lista PLPCG pura; caso contrário só folheto após [showColdigomShareDialog]) / Só o link — UC-07/08, spec short-id-share)» vira «(bottom sheet 2 modos — Folheto (imagem + link por praise + QR) / Só o link — UC-07/08, spec fim-fonte-plpcg §4)».
- Tabelas de API: `grep -n "LouvorCache\b\|CatalogRepository\|LoadLouvoresManifest\|SearchLouvorByNumberOrText\|FilterByMaterialAndArranjo\|FilterBySpecialArrangement\|findLouvorByPdfId\|ForceRefreshCatalog\|PollManifestChecksum\|LouvorDto\|CompositeCatalogSource\|ManifestMaterialAliases\|PlpcgCatalogSource\|PlpcgSearchIndex\|OfflineBulkDownload\|OfflineAvailableStore\|GetOfflineStatsByCategory\|DownloadMissingPdfs\|isFullOfflineMode\|LouvorDataSource\|plpcgManifest" docs/features/FEATURE_INDEX.md` → cada **linha de tabela** de API desses símbolos sai; a linha `ApiEndpoints` troca «(`plpcgManifest`, `plpcgManifestChecksum`)» por «(`plpcgCatalog`, `plpcgPraises`, `plpcgCrosswalk`)»; a linha `OfflineConfig` tira «**não** aplica a UC-10 com `persistentDownload`»; as secções «### `LouvorCache` — campos», «### `findLouvorByPdfId` — API pública», «## Agrupamento manifest (`groupId`)» e «### Contrato ingest — catálogo D1» ganham logo abaixo do título a linha `> **Histórico (23/09/2026):** o app já não lê o manifesto nem tem o \`LouvorCache\`; ver spec fim-fonte-plpcg.` (o corpo fica como registo).
- Acrescentar à tabela «APIs públicas — Domínio» (depois de `LouvorGroup`):

```markdown
| `NormalizeLegacyMaterialIds` | `lib/features/catalog/domain/usecases/normalize_legacy_material_ids.dart` | **Implementado 23/09/2026 + testes** | Uma rodada: recolhe ids legados das [LegacyIdStore] (playlists, índice offline, `recentlyOpened`, `pdfLastPages`, foco da lista), pergunta ao crosswalk uma vez, reescreve; sem legados = sem rede; crosswalk fora = pendente. Gatilhos: `hydratePlaylistSession` e pull de playlists ([legacyMaterialIdsNormalizerProvider]). Sai quando não houver mais ids legados (spec §12). |
| `isLegacyPdfId` / `coldigomPdfIdFromAssetUrl` | `lib/core/utils/pdf_id_codec.dart` | **Implementado 23/09/2026 + testes** | Id legado = PDF fora de `assets/praises/`; id coldigom = `encodePdfId(r2Key da URL)` |
| `ColdigomRemoteDatasource.resolveLegacyPdfIds` | `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart` | **Implementado 23/09/2026 + testes** | `POST /api/plpcg/crosswalk` em lotes de 500 → legado → id coldigom |
```

- [ ] **Step 3: LOUVOR_GROUPING**

Em `docs/features/LOUVOR_GROUPING.md`, logo depois do parágrafo `**Atualização set/2026:** …`:

```markdown
**Atualização 23/09/2026 (fim da fonte PLPCG):** o app já não lê o `louvores-manifest.json` em forma nenhuma. Um louvor lógico é um praise do coldigom: o `ColdigomSearchIndex` monta um `LouvorGroup` por praise a partir do dump `GET /api/plpcg/catalog` (`effectiveGroupId` = `praiseId`). O `groupId` fuzzy e o `LouvorCache` saíram; o resto deste documento é histórico. Ver `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md`.
```

- [ ] **Step 4: UC-09**

Substituir `docs/use-cases/UC-09-configure-offline.md` inteiro:

```markdown
# UC-09 — Configurar modo offline (primeira vez)

| Campo | Valor |
|-------|-------|
| **ID** | UC-09 |
| **Feature** | `offline` |
| **Prioridade** | Alta |
| **Ator** | Usuário (com ou sem login) |

## Pré-condições

Rede disponível; espaço em disco; catálogo coldigom sincronizado (a linha de estado do `/offline` diz quantos louvores e quando).

## Fluxo principal

1. Acessa `/offline` — uma secção, «Baixar para usar offline».
2. Marca os tipos de material a baixar. Sem login aparece a lista «Tipos» inteira; com login os tipos favoritos vêm primeiro e pré-marcados, e os outros ficam em «Outros tipos».
3. Toca «Baixar selecionados (~X MB)» → PDFs, áudios, cifras e gestos desses tipos ficam no aparelho (`DownloadColdigomMaterials`), com progresso por tipo e «Parar».

## Fluxos alternativos

- «Parar»: o que já baixou fica; «Tentar de novo» retoma saltando o que existe.
- «Atualizar»: sincroniza o catálogo e reconcilia o índice com o disco (banner «N removidos», só com «Dispensar»).
- «Remover todos os baixados»: apaga todos os PDFs e áudios do índice (cifras e gestos ficam).

## Pós-condições

Materiais dos tipos escolhidos disponíveis offline; catálogo coldigom local (`ColdigomPraiseCache`) com metadados, lista de materiais e letra.

## Regras de negócio

PDF → `OfflinePdfIndex` persistente; áudio → `OfflineAudioIndex` + `AudioStoragePort`; cifra/gestos → caches Isar. Seleção local em prefs `offlineColdigomKindIds`; idempotente sem checkpoint; estimativas por tipo quando o dump não traz `size`. Um estado de ocupado só: o `offlineMaintenanceLockProvider` (reconcile, download/remoção, normalização de ids legados). Sem `OFFLINE_AVAILABLE` nem seleção por categoria PLPCG (saíram em 23/09/2026).

## Componentes Flutter alvo

`OfflineSettingsScreen`, `ColdigomOfflineSection`, `DownloadColdigomMaterials`, `RemoveColdigomDownloads`, `offlineColdigomDownloadProvider`, `offlineCacheStatusProvider`

## Dependências

UC-10, UC-04

## Use case Dart

`lib/features/offline/domain/usecases/` — ver FEATURE_INDEX.md
```

- [ ] **Step 5: Notas nos specs antigos e estado no spec novo**

- `2026-09-18-catalogo-coldigom-modo-unico-design.md`, logo depois da linha `**Estado:**`:

```markdown
> **Substituído em parte (2026-09-23)** pelo spec [fim da fonte PLPCG](./2026-09-23-fim-fonte-plpcg-design.md): §3.2–§3.5 (manifest e checksum), §4.3–§4.5 (`LouvorDataSource`, `isColdigom`, alias de ids), §5 (fusão no `CompositeCatalogSource`), §6 (offline PDF a PDF sobre o `LouvorCache`) e os follow-ups «Lista ao Vivo» e «Share» de §11 já não descrevem o app.
```

- `2026-09-13-short-id-share-design.md`, logo depois da linha `**Substitui parcialmente:**`:

```markdown
> **Substituído no v2 (2026-09-23)** pelo link por praise `?p=` do spec [fim da fonte PLPCG](./2026-09-23-fim-fonte-plpcg-design.md) §4: a §4 (coldigui) já não descreve o app — links `?s=` antigos mostram «link de versão antiga». A §3 (plpcjf) não é tocada.
```

- `2026-09-12-lista-ao-vivo-design.md`, logo abaixo do título `## 14. Refinamento pós-deploy (2026-09-14): só Coldigom, material próprio`:

```markdown
> **Substituído (2026-09-23):** a regra «só Coldigom» morreu com o fim da fonte PLPCG (spec [fim da fonte PLPCG](./2026-09-23-fim-fonte-plpcg-design.md) §5). O material próprio de cada consumidor fica.
```

- `2026-09-23-fim-fonte-plpcg-design.md`: acrescentar no fim (ou completar, se os planos 1/2 já criaram a secção) `## 13. Estado implementado e desvios` com a subsecção `### Plano 3` que lista os sete desvios do topo deste plano, uma linha cada, e a medição do `isar_plus` (desvio 3).

- [ ] **Step 6: Commit**

```bash
git add docs/features/FEATURE_INDEX.md docs/features/LOUVOR_GROUPING.md docs/use-cases/UC-09-configure-offline.md docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md docs/superpowers/specs/2026-09-13-short-id-share-design.md docs/superpowers/specs/2026-09-12-lista-ao-vivo-design.md docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md
git commit -m "docs: fim da fonte PLPCG — índice de features, agrupamento, UC-09 e notas nos specs antigos

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Verificação final

**Files:** nenhum (só verificação; sem commit, salvo correção).

- [ ] **Step 1: Suíte completa**

Run: `./scripts/test_all.sh` (com Chrome) ou `./scripts/test_all.sh --vm-only` sem Chrome — registar qual correu e o número de testes (comparar com a linha de base da Tarefa 0: saem os testes apagados, entram os novos).
Expected: analyze limpo, VM verde, Chrome verde (se correu).

- [ ] **Step 2: Worker**

Run (em `workers/plpcg-catalog`): `npm run typecheck && npm test`
Expected: verde.

- [ ] **Step 3: Greps do brief (em `lib/`)**

Run:

```bash
grep -rn "louvoresManifestProvider" lib
grep -rn "LouvorDataSource" lib
grep -rn "CompositeCatalogSource" lib
grep -rn "/api/plpcg/manifest" lib
```

Expected: as quatro sem nenhuma linha.

Run também (fecho mais largo, `lib` e `test`):

```bash
grep -rnE "LouvorCache\b|PlpcgCatalogSource|PlpcgSearchIndex|ManifestMaterialAliases|louvoresByPdfIdProvider|catalogChecksumPoll|OfflineBulkDownloadNotifier|OfflineAvailableStore|OFFLINE_AVAILABLE|offlineCategorySelectionProvider|GetOfflineStatsByCategory|DownloadMissingPdfs|isColdigom\b|contributionSourceOf|coldigomPdfIdFromManifestPdf" lib test
```

Expected: só a linha literal `'OFFLINE_AVAILABLE'` dentro de `migrate_offline_storage.dart` (a chave que o passo 5 apaga) e a do `migrate_offline_storage_test.dart`. Nada mais.

- [ ] **Step 4: Rede no boot (sanidade manual local)**

Run: `flutter run -d chrome --dart-define-from-file=dart_defines/plpcg.json` e, no DevTools → Network, recarregar a Home e a /biblioteca.
Expected: nenhum pedido a `/api/plpcg/manifest*`; um `GET /api/plpcg/catalog` (200 ou 304); nenhum `POST /api/plpcg/crosswalk` num perfil limpo (sem ids legados). Num perfil com uma lista antiga (antes de 20/09): **um** `POST /api/plpcg/crosswalk` e, a seguir, as entradas da lista abrem.

- [ ] **Step 5: Anotar para o dono (sem executar)**

Registar no relatório final: (a) o script do D1 **não** foi corrido contra `--remote` — corre depois do deploy do app, com pedido; (b) o checklist manual do spec §11 (itens 1–9) mais o item 10 abaixo fica para prod v2 depois do deploy.

---

## Validação manual pós-deploy (spec §11 + desvio 3)

Não faz parte do código; fica aqui para a entrega. Itens 1–9: os do spec §11 (biblioteca sem seletor; busca e «novos»; arranque a frio sem Isar; `/offline` sem login até ao fim de «Gestos CIAs» e «Remover todos os baixados»; playlist antiga com ids legados abre e o índice offline mostra os PDFs já baixados sem os baixar de novo; share `?p=` com PDF + áudio + cifra; link `?s=` antigo; ao vivo com lista antes recusada; rede sem `/api/plpcg/manifest*`, `/api/praises/filters` e `/api/materials/kinds`). **Item 10 (web):** num navegador que tinha o app antigo, abrir o v2 novo, depois DevTools → Application → IndexedDB/OPFS da instância `plpcg_plus` e confirmar que a tabela `LouvorCache` sumiu ou está vazia (o `isar_plus` web usa SQLite; a limpeza ao abrir foi medida só no nativo). Se não sumir, não há impacto funcional — abrir follow-up para um passo de limpeza específico da web. Depois do item 5, correr o script do D1 (Tarefa 13) com pedido do dono.

---

## Self-review (feito ao escrever)

1. **Cobertura do spec:** §3.1 → Tarefas 9–10 (secção única, «Tipos» sem login, «Remover todos», um ocupado, passo 5); §6.1 → Tarefa 1 (`isLegacyPdfId`, `isColdigomPdfId` fica); §6.2 → Tarefas 2–6 (C9 em lotes de 500, cada store da tabela, gatilhos, sem Isar só prefs, lock, `CarouselEntry` coberto pela ordem depois do `MigrateCarouselStore`); §6.3 → Tarefa 13 (transformador puro testado, `--dry-run`, relatório, `version+1` sem `updated_at`, `items`+`pdf_ids`, só depois do deploy); §6.4 → Tarefas 7, 8, 10, 11, 12 (cada consumidor com destino na tabela da Unidade B; `LouvorCache` fora do schema; prefs mortas no passo 5; `LouvorDataSource` e `isColdigom`; `contributionSourceOf` → desvio 2; `LouvorPdfPath` → desvio 1); §7.2 lado cliente → Tarefa 2; §8 → Tarefas 3 e 6 (crosswalk fora = pendente, entradas indisponíveis); §9 restante → Tarefas 9–10 (+ conferência das chaves dos planos 1/2 e de `homeColdigomOffline`); §10 restante → testes novos e adaptados em cada tarefa; §11 itens 5–6 → Tarefas 13–14; validação → Tarefa 15.
2. **Placeholders:** nenhum «TBD»/«similar à tarefa N»; passos de adaptação em massa (Tarefas 7, 11, 12) dão a regra exata, os ficheiros conhecidos e o grep que prova o fim.
3. **Tipos:** `LegacyIdResolution.rewrite`/`isUnknown`/`resolved`/`queried`, `LegacyIdStore.collectLegacyIds`/`rewrite`, `LegacyPdfIdResolver`, `LegacyIdNormalizationOutcome.nothingToDo`/`pending`/`rewritten`, `legacyPdfIdResolverProvider`, `legacyMaterialIdsNormalizerProvider`/`run()`, `OfflineMaintenanceOwner.normalize`, `coldigomLouvoresOverride`, `OfflineCacheStatus.diskUsageBytes` — mesmos nomes em todas as tarefas.
4. **Review Focus:** as cinco linhas têm teste na tarefa dona (9; 2 e 3; 4; 4 e 5; 6).
