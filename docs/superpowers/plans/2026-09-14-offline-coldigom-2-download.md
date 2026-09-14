# Offline Coldigom — Parte 2: Download por tipos favoritos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No `/offline`, o utilizador logado escolhe kinds Coldigom (favoritos pré-marcados + «Outros tipos») e baixa PDFs, áudios, cifras e gestos desses kinds, filtrados a partir do catálogo local. Áudio ganha persistência própria (`OfflineAudioIndex` + `AudioStoragePort`) e o player toca do disco/Cache API primeiro. Offline, o sheet desabilita o que não está no aparelho; o badge dos cards passa a olhar todos os tipos de material.

**Architecture:** Storage por tipo (C1/O7): PDF → `OfflinePdfIndex` + `PdfStoragePort` (`isPersistent = true`, LRU promovido sem novo download via `OfflinePdfLocalDatasource.markPersistent`); áudio → **novo** `OfflineAudioIndex` + `AudioStoragePort` (gémeos nativo/web copiados de `pdf_storage_*`) + `OfflineAudioRepository`; cifra → `ChordContentCache` via `ChordContentLocalDatasource.write`; gestos → `GestureDocumentCache` + `GestureFigureRepository.prefetch`. `DownloadColdigomMaterials` enumera alvos do `ColdigomPraiseCache` (`coldigomDownloadTargetsFrom`), salta o que já existe e corre uma fila com concorrência fixa; é idempotente, cancelável e devolve o parcial. `offlineColdigomDownloadProvider` (Notifier) adquire `offlineMaintenanceLockProvider` + wakelock. `offlineColdigomStatsProvider` e `materialAvailabilityMapProvider` derivam de índices + catálogo (revisões). UI: secção nova no `OfflineSettingsScreen`; `MaterialSheet` com `enabled`/`subtitle`; badge do card; empty state da Home.

**Tech Stack:** Flutter 3 + Riverpod 3, `isar_plus` (collection nova + `build_runner`), Dio (`RetryInterceptor.disableKey`), `path_provider`, `package:web` (Cache API) com imports condicionais `x_native.dart`/`x_web.dart`, `wakelock_plus`, SharedPreferences, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-14-offline-coldigom-design.md` (secção §5 completa: 5.1 áudio persistente, 5.2 `DownloadColdigomMaterials`, 5.3 stats/disponibilidade, 5.4 ecrã `/offline`, 5.5 sheet/cards/Home; decisões O7–O14)

**Depende de:** `2026-09-14-offline-coldigom-1-catalogo.md`. Consome: `ColdigomPraiseCache` (`praiseId, number, name, materialsJson`), `ColdigomCatalogLocalDatasource.findAllSync()`, `ColdigomPraiseCacheMapper.decodeMaterials(row) → List<ColdigomCatalogMaterialEntry {id, kindId, kindName, type, r2Key, size, url}>`, `coldigomCatalogLocalDatasourceProvider`, `coldigomCatalogSyncProvider` (estado `ColdigomCatalogSyncState {isSyncing, lastResult, lastSyncedAt, count}`, `sync()`), `coldigomCatalogHydrationProvider`, `LyricsMaterial`/`MaterialKind.lyrics`, `ColdigomCatalogSyncFailed.cause`.

## Global Constraints

- Todos os comandos rodam a partir da raiz da worktree `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/offline-coldigom`.
- Nunca migrar/alterar `OfflinePdfIndex`, `LouvorCache`, `ChordContentCache`, `GestureDocumentCache` (decisões O7/O8) — só collections novas (`ColdigomPraiseCache` do plano 1, `OfflineAudioIndex` aqui). Cifras/gestos **não** ganham `isPersistent` e não são apagados por «Remover baixados» (O8).
- `r2Key` é derivado: `assets/praises/<praiseId>/<materialId>.<ext>` (O2) — já vem pronto em `ColdigomCatalogMaterialEntry.r2Key`; YouTube usa `url` e nunca é alvo de download (O10).
- Letra: `MaterialKind.lyrics`, id `lyrics:<praiseId>`, sem download, sem favoritos (O6) — nunca entra em alvos, stats ou mapa de disponibilidade.
- Download só logado (O9); seleção local em prefs `offlineColdigomKindIds` (O11: pré-marcação só para kinds nunca decididos); idempotente sem checkpoint (O12); usa `offlineMaintenanceLockProvider` (dono novo `OfflineMaintenanceOwner.coldigom`) e `wakelock_plus` como o bulk PLPCG.
- Tipos baixáveis: `pdf | mp3 | audio | chord | gestures`. Estimativas sem `size` (O13): `pdf` 350 KB, `mp3` 4 MB, `chord` 1 KB, `gestures` 60 KB; a UI mostra `~` quando há estimativa.
- Concorrência do download: `OfflineConfig.coldigomDownloadConcurrency` = 3 no nativo, 6 na web (o PDF on-demand já usa 3; a web tem `bulkWebFetchConcurrency` 8).
- Áudio é sempre persistente — sem LRU, sem quota (§9); só remoção manual.
- Pesquisa: lista única, PLPCG primeiro e Coldigom depois; remoto só valida a página 1; novos entram no fim (O15/O16) — plano 3, nada aqui toca na pesquisa.
- Sheet desabilitado (O14) é conforto, nunca bloqueio: com `connectivityStreamProvider` a dizer online, tudo continua ativo e o erro de abertura existente aparece.
- Comentários de código e strings em português, no tom do código vizinho (explicam o porquê).
- Antes de cada commit: `dart format` nos ficheiros tocados, `flutter analyze` sem erros novos, testes da task verdes (`flutter gen-l10n` antes do `analyze` quando a task mexe nos `.arb`).
- Commits terminam com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP
  ```
- Baseline conhecido: `pdfrx_viewer_adapter_test` e `reconcile_offline_index_benchmark_test` falham por timeout sob carga — pré-existente, não corrigir.

---

## File map

**Áudio persistente**
- Create `lib/core/database/collections/offline_audio_index.dart` (+ `.g.dart`) — índice `audioId → storageKey`.
- Modify `lib/core/database/isar_app_schemas.dart` — `OfflineAudioIndexSchema`.
- Modify `lib/core/constants/offline_config.dart` — `audioStorageSubdir`, `audioCacheStoreName`, `coldigomDownloadConcurrency`, estimativas por tipo.
- Modify `lib/features/offline/domain/exceptions/offline_bulk_exceptions.dart` — `AudioStorageWriteException`.
- Create `lib/features/offline/data/datasources/offline_audio_local_datasource.dart` — CRUD Isar.
- Create `lib/features/offline/domain/ports/audio_storage_port.dart`, `lib/features/offline/data/datasources/audio_storage_native.dart`, `audio_storage_web.dart`, `audio_storage_impl.dart`.
- Create `lib/features/offline/domain/entities/offline_audio_entry.dart`, `local_audio_source.dart`.
- Create `lib/features/offline/domain/repositories/offline_audio_repository.dart`, `lib/features/offline/data/repositories/offline_audio_repository_impl.dart`.
- Create `lib/features/offline/data/providers/offline_audio_providers.dart` — `audioStoragePortProvider`, `offlineAudioIndexRevisionProvider`, `offlineAudioLocalDatasourceProvider`, `offlineAudioRepositoryProvider`.
- Create `lib/features/audio_player/data/datasources/audio_bytes_datasource.dart` — fetch de bytes de uma faixa.
- Modify `lib/features/audio_player/data/web_audio_source_resolver_stub.dart`, `web_audio_source_resolver_web.dart` — `resolveFromBytes`.
- Modify `lib/features/audio_player/presentation/providers/audio_player_session_provider.dart` — `_playbackUriForTrack` local-first; `AudioNotDownloadedException`; `notDownloaded` no estado.
- Modify `lib/features/audio_player/presentation/pages/audio_player_screen.dart` — mensagem «Este áudio não foi baixado».

**Download**
- Modify `lib/features/offline/data/datasources/offline_pdf_local_datasource.dart` — `markPersistent(Set<String>)`.
- Create `lib/features/offline/domain/entities/coldigom_download_target.dart` — `ColdigomDownloadTarget`, `coldigomDownloadTargetsFrom`, `coldigomEstimatedBytes`.
- Create `lib/features/offline/domain/entities/coldigom_download_progress.dart` — `ColdigomDownloadProgress`, `ColdigomDownloadResult`, `ColdigomDownloadFailure`.
- Create `lib/features/offline/domain/usecases/download_coldigom_materials.dart`.
- Create `lib/features/offline/domain/usecases/remove_coldigom_downloads.dart`.
- Create `lib/features/offline/data/datasources/offline_coldigom_kind_selection_store.dart` — prefs `offlineColdigomKindIds`.
- Modify `lib/core/constants/storage_keys.dart` — `offlineColdigomKindIds`.
- Create `lib/features/offline/data/providers/offline_coldigom_providers.dart` — DI do use case, remoção e store.
- Modify `lib/features/offline/presentation/providers/offline_maintenance_lock_provider.dart` — dono `coldigom`.
- Create `lib/features/offline/presentation/providers/offline_coldigom_stats_provider.dart` — `ColdigomKindStats`, `offlineColdigomStatsProvider`.
- Create `lib/features/offline/presentation/providers/material_availability_map_provider.dart`.
- Create `lib/features/offline/presentation/providers/offline_coldigom_download_provider.dart`.
- Modify `lib/features/offline/presentation/pages/offline_settings_screen.dart` — duas secções; pausa em background do download Coldigom.
- Create `lib/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart` — secção Coldigom.

**Sheet, cards, Home**
- Modify `lib/features/catalog/presentation/widgets/material_sheet.dart` — `enabled`/`subtitle` por disponibilidade, banner offline.
- Modify `lib/features/catalog/presentation/widgets/louvor_group_card.dart` — badge considera qualquer material do grupo.
- Modify `lib/features/catalog/presentation/widgets/home_empty_state.dart` — aviso «Coldigom offline» só sem catálogo local.
- Modify `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` — chaves de §7 (`offlineColdigom*`, `materialNotDownloadedOffline`, `materialNeedsConnection`, `materialSheetOfflineBanner`, `audioNotDownloaded`).

**Docs**
- Modify `docs/use-cases/UC-09-configure-offline.md`, `docs/use-cases/UC-10-offline-maintenance.md`, `docs/features/FEATURE_INDEX.md`.

---

### Task 1: `OfflineAudioIndex` + `OfflineAudioLocalDatasource` + revisão

**Files:**
- Create: `lib/core/database/collections/offline_audio_index.dart` (+ `.g.dart`)
- Modify: `lib/core/database/isar_app_schemas.dart`
- Create: `lib/features/offline/data/datasources/offline_audio_local_datasource.dart`
- Test: `test/unit/features/offline/offline_audio_local_datasource_test.dart`

**Interfaces:**
- Produces:
  - `@Collection() class OfflineAudioIndex { int id; @Index(unique: true) String audioId; String r2Key; String storageKey; int fileSize; DateTime downloadedAt; }`
  - `class OfflineAudioLocalDatasource { const (Isar?, {void Function()? onIndexChanged}); const .unavailable(); OfflineAudioIndex? findByAudioIdSync(String); List<OfflineAudioIndex> findByAudioIds(Set<String>); List<OfflineAudioIndex> findAllSync(); Future<void> put(OfflineAudioIndex); Future<void> deleteByAudioId(String); Future<void> clearAll(); int sumFileSizes(); }` — escritas sem Isar lançam `StorageUnavailableException('offline_audio.<op>')`; `onIndexChanged` após cada escrita.

- [ ] **Step 1: Collection**

`lib/core/database/collections/offline_audio_index.dart`:

```dart
import 'package:isar_plus/isar_plus.dart';

part 'offline_audio_index.g.dart';

/// Índice offline de áudios Coldigom `audioId → storageKey` (spec offline
/// Coldigom §5.1, O7).
///
/// Irmão de [OfflinePdfIndex], sem `isPersistent` nem `lastAccessedAt`: áudio
/// só entra aqui por download explícito e nunca é evictado (não há LRU de
/// áudio, §9) — sai só por «Remover baixados do Coldigom».
@Collection()
class OfflineAudioIndex {
  int id = 0;

  /// `encodePdfId(r2Key)` — o mesmo id de `AudioTrack.audioId`.
  @Index(unique: true)
  late String audioId;

  /// Chave do objeto no R2 (`assets/praises/<praise>/<material>.mp3`).
  late String r2Key;

  /// Path absoluto (nativo, `documents/plpcg_audio/…`) ou chave lógica
  /// (web, `plpcg_audio/…` na Cache API) — o que [AudioStoragePort] devolveu.
  late String storageKey;

  /// Bytes gravados — soma para «Remover» e para as stats, sem scan.
  late int fileSize;

  late DateTime downloadedAt;
}
```

Em `isar_app_schemas.dart`: import `collections/offline_audio_index.dart` e `OfflineAudioIndexSchema,` na lista. Correr `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 2: Teste que falha**

`test/unit/features/offline/offline_audio_local_datasource_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/offline/data/datasources/offline_audio_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

OfflineAudioIndex _row(String audioId, {int size = 10}) => OfflineAudioIndex()
  ..audioId = audioId
  ..r2Key = 'assets/praises/p1/$audioId.mp3'
  ..storageKey = '/docs/plpcg_audio/p1/$audioId.mp3'
  ..fileSize = size
  ..downloadedAt = DateTime.utc(2026, 9, 14);

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflineAudioLocalDatasource datasource;
  var changes = 0;

  setUp(() async {
    changes = 0;
    tempDir = await Directory.systemTemp.createTemp('offline_audio_');
    isar = Isar.open(
      schemas: [OfflineAudioIndexSchema],
      directory: tempDir.path,
      name: 'offline_audio_${DateTime.now().microsecondsSinceEpoch}',
    );
    datasource = OfflineAudioLocalDatasource(isar, onIndexChanged: () => changes++);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('put faz upsert por audioId e avisa a revisão', () async {
    await datasource.put(_row('a1', size: 5));
    await datasource.put(_row('a1', size: 7));

    expect(datasource.findAllSync(), hasLength(1));
    expect(datasource.findByAudioIdSync('a1')!.fileSize, 7);
    expect(datasource.sumFileSizes(), 7);
    expect(changes, 2);
  });

  test('findByAudioIds devolve só os presentes; delete e clear avisam', () async {
    await datasource.put(_row('a1'));
    await datasource.put(_row('a2'));

    expect(datasource.findByAudioIds({'a1', 'zz'}).map((e) => e.audioId), ['a1']);

    await datasource.deleteByAudioId('a1');
    await datasource.deleteByAudioId('a1');
    expect(datasource.findAllSync().map((e) => e.audioId), ['a2']);

    await datasource.clearAll();
    expect(datasource.findAllSync(), isEmpty);
    expect(changes, 5);
  });

  test('sem Isar: leituras vazias, escritas lançam', () async {
    const degraded = OfflineAudioLocalDatasource.unavailable();

    expect(degraded.findAllSync(), isEmpty);
    expect(degraded.findByAudioIdSync('a1'), isNull);
    expect(degraded.sumFileSizes(), 0);
    await expectLater(degraded.put(_row('a1')), throwsA(isA<StorageUnavailableException>()));
    await expectLater(degraded.clearAll(), throwsA(isA<StorageUnavailableException>()));
  });
}
```

Correr: `flutter test test/unit/features/offline/offline_audio_local_datasource_test.dart` → falha.

- [ ] **Step 3: Datasource**

`lib/features/offline/data/datasources/offline_audio_local_datasource.dart`:

```dart
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/offline_audio_index.dart';
import '../../../../core/database/storage_unavailable_exception.dart';

/// CRUD Isar de [OfflineAudioIndex] — espelho enxuto de
/// `OfflinePdfLocalDatasource` (sem LRU, sem `isPersistent`).
///
/// Sem Isar as leituras devolvem vazio e as escritas lançam
/// [StorageUnavailableException]. [onIndexChanged] sobe a revisão do índice
/// de áudio (`offlineAudioIndexRevisionProvider`) depois de cada escrita —
/// é o que re-deriva `materialAvailabilityMapProvider` e as stats.
class OfflineAudioLocalDatasource {
  const OfflineAudioLocalDatasource(this._isar, {this.onIndexChanged});

  const OfflineAudioLocalDatasource.unavailable()
    : _isar = null,
      onIndexChanged = null;

  final Isar? _isar;
  final void Function()? onIndexChanged;

  OfflineAudioIndex? findByAudioIdSync(String audioId) {
    final isar = _isar;
    if (isar == null || audioId.isEmpty) return null;
    return isar.offlineAudioIndexs.where().audioIdEqualTo(audioId).findFirst();
  }

  List<OfflineAudioIndex> findByAudioIds(Set<String> audioIds) {
    final isar = _isar;
    if (isar == null || audioIds.isEmpty) return const [];
    return isar.offlineAudioIndexs
        .where()
        .anyOf(audioIds, (q, id) => q.audioIdEqualTo(id))
        .findAll();
  }

  List<OfflineAudioIndex> findAllSync() {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.offlineAudioIndexs.where().findAll();
  }

  /// Upsert por `audioId`.
  Future<void> put(OfflineAudioIndex index) async {
    final isar = _requireIsar('put');
    await isar.write((isar) {
      final coll = isar.offlineAudioIndexs;
      final existing = coll.where().audioIdEqualTo(index.audioId).findFirst();
      if (existing != null) {
        index.id = existing.id;
      } else if (index.id == 0) {
        index.id = coll.autoIncrement();
      }
      coll.put(index);
    });
    onIndexChanged?.call();
  }

  /// Idempotente se ausente.
  Future<void> deleteByAudioId(String audioId) async {
    final isar = _requireIsar('deleteByAudioId');
    await isar.write((isar) {
      final coll = isar.offlineAudioIndexs;
      final existing = coll.where().audioIdEqualTo(audioId).findFirst();
      if (existing != null) coll.delete(existing.id);
    });
    onIndexChanged?.call();
  }

  Future<void> clearAll() async {
    final isar = _requireIsar('clearAll');
    await isar.write((isar) => isar.offlineAudioIndexs.clear());
    onIndexChanged?.call();
  }

  /// Soma de [OfflineAudioIndex.fileSize] — stats sem scan de disco.
  int sumFileSizes() =>
      findAllSync().fold<int>(0, (sum, index) => sum + index.fileSize);

  Isar _requireIsar(String operation) {
    final isar = _isar;
    if (isar == null) {
      throw StorageUnavailableException('offline_audio.$operation');
    }
    return isar;
  }
}
```

Correr: `flutter test test/unit/features/offline/offline_audio_local_datasource_test.dart` → 3 verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib/core/database lib/features/offline/data/datasources/offline_audio_local_datasource.dart test/unit/features/offline/offline_audio_local_datasource_test.dart
flutter analyze
git add lib/core/database lib/features/offline/data/datasources/offline_audio_local_datasource.dart test/unit/features/offline/offline_audio_local_datasource_test.dart
git commit -m "feat(offline): OfflineAudioIndex + datasource Isar do índice de áudio Coldigom

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 2: `AudioStoragePort` nativo/web

**Files:**
- Modify: `lib/core/constants/offline_config.dart` (fim da classe)
- Modify: `lib/features/offline/domain/exceptions/offline_bulk_exceptions.dart` (fim do ficheiro)
- Create: `lib/features/offline/domain/ports/audio_storage_port.dart`
- Create: `lib/features/offline/data/datasources/audio_storage_native.dart`
- Create: `lib/features/offline/data/datasources/audio_storage_web.dart`
- Create: `lib/features/offline/data/datasources/audio_storage_impl.dart`
- Test: `test/unit/features/offline/audio_storage_native_test.dart`

**Interfaces:**
- Produces:
  - `OfflineConfig.audioStorageSubdir = 'plpcg_audio'`, `OfflineConfig.audioCacheStoreName = 'plpcg-audio-store-v1'`, `OfflineConfig.coldigomDownloadConcurrency` (getter: `kIsWeb ? 6 : 3`), `OfflineConfig.coldigomEstimatedBytesByType = {'pdf': 350*1024, 'mp3': 4*1024*1024, 'audio': 4*1024*1024, 'chord': 1024, 'gestures': 60*1024}`.
  - `class AudioStorageWriteException implements Exception { String message; }`.
  - `abstract interface class AudioStoragePort { Future<String> writeAtomic(Uint8List bytes, String relPath); Future<bool> exists(String storageKey); Future<Uint8List?> readBytes(String storageKey); Future<void> delete(String storageKey); Future<void> deleteTree(); Future<int> getTotalBytes(); }`
  - `AudioStorageNative({GetApplicationDocumentsDirectoryFn? getApplicationDocumentsDirectory})` — `documents/plpcg_audio/<relPath>`, `.tmp` + rename; `AudioStorageWeb()` — Cache API `plpcg-audio-store-v1`, chaves `plpcg_audio/<relPath>`, origem `https://plpcg-offline.local`, quota → `InsufficientDiskSpaceException`; `AudioStoragePort createAudioStoragePort()`.

- [ ] **Step 1: Config e exceção**

`offline_config.dart`, no fim da classe (precisa de `import 'package:flutter/foundation.dart' show kIsWeb;` no topo):

```dart
  /// Subdiretório de áudios Coldigom baixados em documents (nativo).
  static const String audioStorageSubdir = 'plpcg_audio';

  /// Bucket Cache API dos áudios Coldigom na web — irmão de
  /// [pdfCacheStoreName]; buckets separados para «Remover áudios» não
  /// tocar nos PDFs.
  static const String audioCacheStoreName = 'plpcg-audio-store-v1';

  /// Downloads Coldigom simultâneos (spec offline Coldigom §5.2): 3 no
  /// nativo (como o on-demand de PDF), 6 na web (o bulk web usa 8).
  static int get coldigomDownloadConcurrency => kIsWeb ? 6 : 3;

  /// Estimativa de bytes por `type` quando o dump não traz `size` (O13).
  static const Map<String, int> coldigomEstimatedBytesByType = {
    'pdf': 350 * 1024,
    'mp3': 4 * 1024 * 1024,
    'audio': 4 * 1024 * 1024,
    'chord': 1024,
    'gestures': 60 * 1024,
  };
```

`offline_bulk_exceptions.dart`, no fim:

```dart
/// Falha ao gravar áudio no storage (web — Cache API) não relacionada a quota.
class AudioStorageWriteException implements Exception {
  const AudioStorageWriteException(this.message);

  final String message;

  @override
  String toString() => 'AudioStorageWriteException($message)';
}
```

- [ ] **Step 2: Teste que falha (nativo)**

`test/unit/features/offline/audio_storage_native_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/features/offline/data/datasources/audio_storage_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory docsDir;
  late AudioStorageNative store;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('audio_storage_');
    store = AudioStorageNative(getApplicationDocumentsDirectory: () async => docsDir);
  });

  tearDown(() async {
    if (docsDir.existsSync()) await docsDir.delete(recursive: true);
  });

  test('writeAtomic grava em docs/plpcg_audio/<relPath> sem deixar .tmp', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final key = await store.writeAtomic(bytes, 'assets/praises/p1/m1.mp3');

    expect(key, '${docsDir.path}/${OfflineConfig.audioStorageSubdir}/assets/praises/p1/m1.mp3');
    expect(await File(key).readAsBytes(), bytes);
    expect(await File('$key.tmp').exists(), isFalse);
    expect(await store.exists(key), isTrue);
    expect(await store.readBytes(key), bytes);
    expect(await store.getTotalBytes(), 4);
  });

  test('delete é idempotente e readBytes devolve null para ausente', () async {
    final key = await store.writeAtomic(Uint8List.fromList([9]), 'p1/m1.mp3');

    await store.delete(key);
    await store.delete(key);

    expect(await store.exists(key), isFalse);
    expect(await store.readBytes(key), isNull);
  });

  test('deleteTree apaga tudo e recria a raiz vazia', () async {
    await store.writeAtomic(Uint8List.fromList([1]), 'p1/a.mp3');
    await store.writeAtomic(Uint8List.fromList([1, 2]), 'p2/b.mp3');

    await store.deleteTree();

    expect(await store.getTotalBytes(), 0);
    expect(
      await Directory('${docsDir.path}/${OfflineConfig.audioStorageSubdir}').exists(),
      isTrue,
    );
  });
}
```

Correr: `flutter test test/unit/features/offline/audio_storage_native_test.dart` → falha.

- [ ] **Step 3: Porta e implementações**

`lib/features/offline/domain/ports/audio_storage_port.dart`:

```dart
import 'dart:typed_data';

/// Porta de persistência de áudios Coldigom baixados (spec §5.1, O7).
///
/// Gémea de [PdfStoragePort], enxuta: sem `listOrphans`/`purgeLegacyStorage`
/// (não há reconcile nem migração de áudio). Nativo: paths absolutos em
/// `documents/plpcg_audio/`; web: chaves lógicas na Cache API.
abstract interface class AudioStoragePort {
  /// Grava [bytes] em [relPath] (ex.: o `r2Key`); devolve o `storageKey`.
  Future<String> writeAtomic(Uint8List bytes, String relPath);

  Future<bool> exists(String storageKey);

  /// Bytes completos, ou `null` se ausente.
  Future<Uint8List?> readBytes(String storageKey);

  /// Idempotente.
  Future<void> delete(String storageKey);

  /// Apaga tudo e recria a raiz vazia («Remover áudios baixados»).
  Future<void> deleteTree();

  /// Soma de bytes persistidos — auditoria.
  Future<int> getTotalBytes();
}
```

`lib/features/offline/data/datasources/audio_storage_native.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart' as path_provider;

import '../../../../core/constants/offline_config.dart';
import '../../domain/ports/audio_storage_port.dart';
import 'pdf_local_store.dart' show GetApplicationDocumentsDirectoryFn;

AudioStoragePort createAudioStoragePortImpl() => AudioStorageNative();

/// Áudios Coldigom em `documents/plpcg_audio/` — `.tmp` + rename, como
/// [PdfLocalStore]. **Proibido** cache/temp: o download é explícito e o
/// utilizador conta com ele no modo de avião.
class AudioStorageNative implements AudioStoragePort {
  AudioStorageNative({
    GetApplicationDocumentsDirectoryFn? getApplicationDocumentsDirectory,
  }) : _getApplicationDocumentsDirectory =
           getApplicationDocumentsDirectory ??
           path_provider.getApplicationDocumentsDirectory;

  final GetApplicationDocumentsDirectoryFn _getApplicationDocumentsDirectory;
  Directory? _root;

  Future<Directory> get _rootDirectory async {
    if (_root != null) return _root!;
    final docs = await _getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/${OfflineConfig.audioStorageSubdir}');
    if (!await _root!.exists()) await _root!.create(recursive: true);
    return _root!;
  }

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    final root = await _rootDirectory;
    final target = File('${root.path}/${relPath.replaceAll(r'\', '/')}');
    final tmp = File('${target.path}.tmp');
    if (!await target.parent.exists()) await target.parent.create(recursive: true);
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(target.path);
      return target.path;
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  @override
  Future<bool> exists(String storageKey) => File(storageKey).exists();

  @override
  Future<Uint8List?> readBytes(String storageKey) async {
    final file = File(storageKey);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String storageKey) async {
    final file = File(storageKey);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteTree() async {
    final root = await _rootDirectory;
    if (await root.exists()) await root.delete(recursive: true);
    _root = null;
    await _rootDirectory;
  }

  @override
  Future<int> getTotalBytes() async {
    final root = await _rootDirectory;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || entity.path.endsWith('.tmp')) continue;
      total += await entity.length();
    }
    return total;
  }
}
```

`lib/features/offline/data/datasources/audio_storage_web.dart` (não compila na VM; só na web — mesmo padrão de `pdf_storage_web.dart`):

```dart
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import '../../../../core/constants/offline_config.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/exceptions/quota_exceeded_classifier.dart';
import '../../domain/ports/audio_storage_port.dart';

AudioStoragePort createAudioStoragePortImpl() => AudioStorageWeb();

/// Áudios Coldigom na Cache API (web) — bucket próprio
/// [OfflineConfig.audioCacheStoreName], chaves `plpcg_audio/<relPath>` na
/// origem lógica `https://plpcg-offline.local`, como [PdfStorageWeb].
class AudioStorageWeb implements AudioStoragePort {
  static const _offlineOrigin = 'https://plpcg-offline.local';

  Cache? _cache;

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    final storageKey =
        '${OfflineConfig.audioStorageSubdir}/${relPath.replaceAll(r'\', '/')}';
    final cache = await _openCache();
    final blob = Blob(
      [bytes.toJS].toJS,
      BlobPropertyBag(type: _mimeForKey(storageKey)),
    );
    try {
      await cache.put(_requestForKey(storageKey), Response(blob, ResponseInit(status: 200))).toDart;
    } on Object catch (e) {
      // `isA` (não `on DOMException catch`) — checagem de tipo interop
      // consistente entre dart2js e dart2wasm.
      if (e.isA<DOMException>()) {
        final domError = e as DOMException;
        if (isQuotaExceededError(name: domError.name, message: domError.message)) {
          throw InsufficientDiskSpaceException(
            requiredBytes: bytes.length,
            availableBytes: null,
          );
        }
        throw AudioStorageWriteException(domError.toString());
      }
      throw AudioStorageWriteException(e.toString());
    }
    return storageKey;
  }

  @override
  Future<bool> exists(String storageKey) async {
    try {
      final cache = await _openCache();
      return await cache.match(_requestForKey(storageKey)).toDart != null;
    } on Object {
      return false;
    }
  }

  @override
  Future<Uint8List?> readBytes(String storageKey) async {
    try {
      final cache = await _openCache();
      final response = await cache.match(_requestForKey(storageKey)).toDart;
      if (response == null) return null;
      final buffer = await response.arrayBuffer().toDart;
      return Uint8List.view(buffer.toDart);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> delete(String storageKey) async {
    final cache = await _openCache();
    try {
      await cache.delete(_requestForKey(storageKey)).toDart;
    } on Object {
      // Idempotente.
    }
  }

  @override
  Future<void> deleteTree() async {
    await window.caches.delete(OfflineConfig.audioCacheStoreName).toDart;
    _cache = null;
  }

  @override
  Future<int> getTotalBytes() async {
    final cache = await _openCache();
    final requests = await cache.keys().toDart;
    var total = 0;
    for (var i = 0; i < requests.length; i++) {
      final response = await cache.match(requests[i]).toDart;
      if (response == null) continue;
      total += (await response.blob().toDart).size;
    }
    return total;
  }

  Future<Cache> _openCache() async {
    _cache ??= await window.caches.open(OfflineConfig.audioCacheStoreName).toDart;
    return _cache!;
  }

  Request _requestForKey(String storageKey) => Request(
    Uri(
      scheme: 'https',
      host: Uri.parse(_offlineOrigin).host,
      pathSegments: storageKey.split('/'),
    ).toString().toJS,
  );

  static String _mimeForKey(String key) {
    final lower = key.toLowerCase();
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    return 'audio/mpeg';
  }
}
```

`lib/features/offline/data/datasources/audio_storage_impl.dart`:

```dart
import '../../domain/ports/audio_storage_port.dart';
import 'audio_storage_native.dart'
    if (dart.library.js_interop) 'audio_storage_web.dart';

/// Factory por plataforma (conditional import) — como `pdf_storage_impl.dart`.
AudioStoragePort createAudioStoragePort() => createAudioStoragePortImpl();
```

Correr: `flutter test test/unit/features/offline/audio_storage_native_test.dart` → 3 verdes. A web só é validada por `flutter build web` no `analyze` do commit (o ficheiro é compilado) e no checklist manual.

- [ ] **Step 4: Commit**

```bash
dart format lib/core/constants/offline_config.dart lib/features/offline test/unit/features/offline/audio_storage_native_test.dart
flutter analyze
git add lib/core/constants/offline_config.dart lib/features/offline test/unit/features/offline/audio_storage_native_test.dart
git commit -m "feat(offline): AudioStoragePort nativo (documents/plpcg_audio) e web (Cache API plpcg-audio-store-v1)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 3: `OfflineAudioRepository` + providers

**Files:**
- Create: `lib/features/offline/domain/entities/offline_audio_entry.dart`
- Create: `lib/features/offline/domain/entities/local_audio_source.dart`
- Create: `lib/features/offline/domain/repositories/offline_audio_repository.dart`
- Create: `lib/features/offline/data/repositories/offline_audio_repository_impl.dart`
- Create: `lib/features/offline/data/providers/offline_audio_providers.dart`
- Test: `test/unit/features/offline/offline_audio_repository_test.dart`

**Interfaces:**
- Consumes: `OfflineAudioLocalDatasource` (Task 1), `AudioStoragePort`/`createAudioStoragePort` (Task 2), `optionalIsarProvider`.
- Produces:
  - `class OfflineAudioEntry { String audioId, r2Key, storageKey; int fileSize; DateTime downloadedAt; }`
  - `class LocalAudioSource { String audioId, storageKey; }`
  - `abstract class OfflineAudioRepository { Future<LocalAudioSource?> lookup(String audioId); Future<Set<String>> lookupBatch(Set<String> audioIds); Future<OfflineAudioEntry> upsert({required String audioId, required String r2Key, required Uint8List bytes}); Future<void> remove(String audioId); Future<List<OfflineAudioEntry>> listAll(); Future<int> totalBytes(); Future<void> removeAll(); }`
  - `OfflineAudioRepositoryImpl({required AudioStoragePort store, required OfflineAudioLocalDatasource local})` — `lookup` valida `store.exists`; `lookupBatch` = ids com índice **e** ficheiro; `upsert` grava em `relPath = r2Key`; `removeAll` = `deleteTree` + `clearAll`.
  - Providers: `audioStoragePortProvider`, `offlineAudioIndexRevisionProvider` (`NotifierProvider<OfflineAudioIndexRevisionNotifier, int>`, `bump()`), `offlineAudioLocalDatasourceProvider`, `offlineAudioRepositoryProvider`.

- [ ] **Step 1: Teste que falha**

`test/unit/features/offline/offline_audio_repository_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/features/offline/data/datasources/audio_storage_native.dart';
import 'package:coldigui/features/offline/data/datasources/offline_audio_local_datasource.dart';
import 'package:coldigui/features/offline/data/repositories/offline_audio_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflineAudioRepositoryImpl repository;
  late AudioStorageNative store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_repo_');
    isar = Isar.open(
      schemas: [OfflineAudioIndexSchema],
      directory: tempDir.path,
      name: 'audio_repo_${DateTime.now().microsecondsSinceEpoch}',
    );
    store = AudioStorageNative(
      getApplicationDocumentsDirectory: () async => Directory('${tempDir.path}/docs'),
    );
    repository = OfflineAudioRepositoryImpl(
      store: store,
      local: OfflineAudioLocalDatasource(isar),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  final bytes = Uint8List.fromList(List.filled(16, 7));

  test('upsert grava bytes e índice; lookup devolve a fonte local', () async {
    final entry = await repository.upsert(
      audioId: 'a1',
      r2Key: 'assets/praises/p1/m1.mp3',
      bytes: bytes,
    );

    expect(entry.fileSize, 16);
    expect(entry.storageKey, endsWith('plpcg_audio/assets/praises/p1/m1.mp3'));
    final local = (await repository.lookup('a1'))!;
    expect(local.storageKey, entry.storageKey);
    expect(await store.readBytes(local.storageKey), bytes);
    expect(await repository.totalBytes(), 16);
    expect((await repository.listAll()).single.r2Key, 'assets/praises/p1/m1.mp3');
  });

  test('lookup é null sem índice ou sem ficheiro; lookupBatch filtra os dois', () async {
    await repository.upsert(audioId: 'a1', r2Key: 'p1/m1.mp3', bytes: bytes);
    await repository.upsert(audioId: 'a2', r2Key: 'p1/m2.mp3', bytes: bytes);
    final a2 = (await repository.lookup('a2'))!;
    await store.delete(a2.storageKey);

    expect(await repository.lookup('zz'), isNull);
    expect(await repository.lookup('a2'), isNull);
    expect(await repository.lookupBatch({'a1', 'a2', 'zz'}), {'a1'});
  });

  test('remove apaga ficheiro e índice; removeAll limpa tudo', () async {
    await repository.upsert(audioId: 'a1', r2Key: 'p1/m1.mp3', bytes: bytes);
    await repository.upsert(audioId: 'a2', r2Key: 'p1/m2.mp3', bytes: bytes);
    final a1 = (await repository.lookup('a1'))!;

    await repository.remove('a1');
    await repository.remove('a1');
    expect(await store.exists(a1.storageKey), isFalse);
    expect((await repository.listAll()).map((e) => e.audioId), ['a2']);

    await repository.removeAll();
    expect(await repository.listAll(), isEmpty);
    expect(await store.getTotalBytes(), 0);
  });
}
```

Correr: `flutter test test/unit/features/offline/offline_audio_repository_test.dart` → falha.

- [ ] **Step 2: Entidades e porta**

`lib/features/offline/domain/entities/offline_audio_entry.dart`:

```dart
/// Áudio Coldigom baixado — índice + ficheiro válidos (spec §5.1).
class OfflineAudioEntry {
  const OfflineAudioEntry({
    required this.audioId,
    required this.r2Key,
    required this.storageKey,
    required this.fileSize,
    required this.downloadedAt,
  });

  final String audioId;
  final String r2Key;
  final String storageKey;
  final int fileSize;
  final DateTime downloadedAt;
}
```

`lib/features/offline/domain/entities/local_audio_source.dart`:

```dart
/// O que o player precisa para tocar do aparelho: onde estão os bytes.
///
/// Nativo: [storageKey] é um path absoluto (`Uri.file`); web: chave da Cache
/// API — o player lê os bytes pelo `AudioStoragePort` e cria um blob URL.
class LocalAudioSource {
  const LocalAudioSource({required this.audioId, required this.storageKey});

  final String audioId;
  final String storageKey;
}
```

`lib/features/offline/domain/repositories/offline_audio_repository.dart`:

```dart
import 'dart:typed_data';

import '../entities/local_audio_source.dart';
import '../entities/offline_audio_entry.dart';

/// Persistência de áudios Coldigom — índice Isar + [AudioStoragePort] (O7).
///
/// DI via `offlineAudioRepositoryProvider`. Consumido pelo player
/// (`lookup`), pelo download (`lookupBatch`/`upsert`) e pela remoção.
abstract class OfflineAudioRepository {
  /// Índice + ficheiro válidos; `null` caso contrário.
  Future<LocalAudioSource?> lookup(String audioId);

  /// Subconjunto de [audioIds] com índice e ficheiro.
  Future<Set<String>> lookupBatch(Set<String> audioIds);

  Future<OfflineAudioEntry> upsert({
    required String audioId,
    required String r2Key,
    required Uint8List bytes,
  });

  /// Apaga ficheiro e índice (idempotente).
  Future<void> remove(String audioId);

  Future<List<OfflineAudioEntry>> listAll();

  /// Soma de `fileSize` do índice — sem scan.
  Future<int> totalBytes();

  /// «Remover áudios baixados»: store inteiro + índice.
  Future<void> removeAll();
}
```

- [ ] **Step 3: Implementação e providers**

`lib/features/offline/data/repositories/offline_audio_repository_impl.dart`:

```dart
import 'dart:typed_data';

import '../../../../core/database/collections/offline_audio_index.dart';
import '../../domain/entities/local_audio_source.dart';
import '../../domain/entities/offline_audio_entry.dart';
import '../../domain/ports/audio_storage_port.dart';
import '../../domain/repositories/offline_audio_repository.dart';
import '../datasources/offline_audio_local_datasource.dart';

/// Orquestra [AudioStoragePort] + [OfflineAudioLocalDatasource].
class OfflineAudioRepositoryImpl implements OfflineAudioRepository {
  OfflineAudioRepositoryImpl({
    required AudioStoragePort store,
    required OfflineAudioLocalDatasource local,
  }) : _store = store,
       _local = local;

  final AudioStoragePort _store;
  final OfflineAudioLocalDatasource _local;

  @override
  Future<LocalAudioSource?> lookup(String audioId) async {
    final index = _local.findByAudioIdSync(audioId);
    if (index == null) return null;
    // Índice órfão (ficheiro apagado pelo SO) fica até «Remover»: não há
    // reconcile de áudio — o player cai na rede como se não estivesse.
    if (!await _store.exists(index.storageKey)) return null;
    return LocalAudioSource(audioId: audioId, storageKey: index.storageKey);
  }

  @override
  Future<Set<String>> lookupBatch(Set<String> audioIds) async {
    final valid = <String>{};
    for (final index in _local.findByAudioIds(audioIds)) {
      if (await _store.exists(index.storageKey)) valid.add(index.audioId);
    }
    return valid;
  }

  @override
  Future<OfflineAudioEntry> upsert({
    required String audioId,
    required String r2Key,
    required Uint8List bytes,
  }) async {
    // O `r2Key` já é um path relativo único (`assets/praises/<p>/<m>.mp3`).
    final storageKey = await _store.writeAtomic(bytes, r2Key);
    final now = DateTime.now();
    await _local.put(
      OfflineAudioIndex()
        ..audioId = audioId
        ..r2Key = r2Key
        ..storageKey = storageKey
        ..fileSize = bytes.length
        ..downloadedAt = now,
    );
    return OfflineAudioEntry(
      audioId: audioId,
      r2Key: r2Key,
      storageKey: storageKey,
      fileSize: bytes.length,
      downloadedAt: now,
    );
  }

  @override
  Future<void> remove(String audioId) async {
    final index = _local.findByAudioIdSync(audioId);
    if (index == null) return;
    await _store.delete(index.storageKey);
    await _local.deleteByAudioId(audioId);
  }

  @override
  Future<List<OfflineAudioEntry>> listAll() async => [
    for (final index in _local.findAllSync())
      OfflineAudioEntry(
        audioId: index.audioId,
        r2Key: index.r2Key,
        storageKey: index.storageKey,
        fileSize: index.fileSize,
        downloadedAt: index.downloadedAt,
      ),
  ];

  @override
  Future<int> totalBytes() async => _local.sumFileSizes();

  @override
  Future<void> removeAll() async {
    await _store.deleteTree();
    await _local.clearAll();
  }
}
```

`lib/features/offline/data/providers/offline_audio_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../domain/ports/audio_storage_port.dart';
import '../../domain/repositories/offline_audio_repository.dart';
import '../datasources/audio_storage_impl.dart';
import '../datasources/offline_audio_local_datasource.dart';
import '../repositories/offline_audio_repository_impl.dart';

/// DI — [AudioStoragePort] (nativo: documents; web: Cache API).
final audioStoragePortProvider = Provider<AudioStoragePort>((ref) {
  return createAudioStoragePort();
});

/// Revisão do índice de áudio — sobe a cada escrita; é o que re-deriva o
/// `materialAvailabilityMapProvider` e as stats Coldigom (mesmo papel de
/// `offlineIndexRevisionProvider` para os PDFs).
class OfflineAudioIndexRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final offlineAudioIndexRevisionProvider =
    NotifierProvider<OfflineAudioIndexRevisionNotifier, int>(
      OfflineAudioIndexRevisionNotifier.new,
    );

/// DI — CRUD Isar [OfflineAudioIndex]; degradado sem Isar.
final offlineAudioLocalDatasourceProvider =
    Provider<OfflineAudioLocalDatasource>((ref) {
      final isar = ref.watch(optionalIsarProvider);
      if (isar == null) return const OfflineAudioLocalDatasource.unavailable();
      return OfflineAudioLocalDatasource(
        isar,
        onIndexChanged: () =>
            ref.read(offlineAudioIndexRevisionProvider.notifier).bump(),
      );
    });

/// DI — [OfflineAudioRepositoryImpl].
final offlineAudioRepositoryProvider = Provider<OfflineAudioRepository>((ref) {
  return OfflineAudioRepositoryImpl(
    store: ref.watch(audioStoragePortProvider),
    local: ref.watch(offlineAudioLocalDatasourceProvider),
  );
});
```

Correr: `flutter test test/unit/features/offline/offline_audio_repository_test.dart` → 3 verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib/features/offline test/unit/features/offline/offline_audio_repository_test.dart
flutter analyze
git add lib/features/offline test/unit/features/offline/offline_audio_repository_test.dart
git commit -m "feat(offline): OfflineAudioRepository (lookup/upsert/remove/removeAll) + providers do índice de áudio

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 4: `AudioBytesDatasource` + player toca do aparelho primeiro

**Files:**
- Create: `lib/features/audio_player/data/datasources/audio_bytes_datasource.dart`
- Modify: `lib/features/audio_player/data/web_audio_source_resolver_stub.dart` (classe inteira)
- Modify: `lib/features/audio_player/data/web_audio_source_resolver_web.dart` (método novo depois de `resolveForPlayback`, linha 49)
- Modify: `lib/features/audio_player/presentation/providers/audio_player_session_provider.dart` (estado linhas 26–83; `_playbackUriForTrack` linhas 450–453; `catch` de `_applyQueue` linhas 598–603)
- Modify: `lib/features/audio_player/presentation/pages/audio_player_screen.dart` (linhas 265–272)
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/unit/features/audio_player/audio_bytes_datasource_test.dart`
- Test: `test/unit/features/audio_player/audio_player_session_local_source_test.dart`

**Interfaces:**
- Consumes: `offlineAudioRepositoryProvider`, `audioStoragePortProvider` (Task 3), `deviceConnectivityProvider`, `platformCapabilitiesProvider.isWeb`, `ColdigomAssetUrl`, `RetryInterceptor.disableKey`, `OfflineConfig.pdfDownloadReceiveTimeout`.
- Produces:
  - `class AudioBytesDatasource { AudioBytesDatasource(Dio dio, {required String apiBase, required bool isWeb}); Future<Uint8List> fetch(String r2Key, {CancelToken? cancelToken}); }` — URL via `ColdigomAssetUrl.fetchUrlForKey` na web (proxy) e `directUrlForKey` no nativo; `receiveTimeout` 120 s; `RetryInterceptor.disableKey: true` (o use case retenta); corpo vazio → `StateError`.
  - `WebAudioSourceResolver.resolveFromBytes(String cacheKey, Uint8List bytes) → Uri?` — web: blob URL (mesmo cache de 2 entradas) ou `null` acima de `maxBlobBytes`; stub: `null`.
  - `class AudioNotDownloadedException implements Exception { String audioId; }`.
  - `AudioPlayerSessionState.notDownloaded` (`bool`, limpo por `clearError`); `AudioPlayerSessionNotifier._playbackUriForTrack`: repositório → nativo `Uri.file`, web bytes → blob; miss com rede → URL de rede; miss **sem** rede → lança `AudioNotDownloadedException`.
  - l10n `audioNotDownloaded` («Este áudio não foi baixado»).

- [ ] **Step 1: Teste do datasource que falha**

`test/unit/features/audio_player/audio_bytes_datasource_test.dart`:

```dart
import 'dart:typed_data';

import 'package:coldigui/core/network/retry_interceptor.dart';
import 'package:coldigui/features/audio_player/data/datasources/audio_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);
  final List<int> bytes;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? s, Future<void>? c) async {
    last = options;
    return ResponseBody.fromBytes(Uint8List.fromList(bytes), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('web: proxy /api/coldigom/<key>, timeout de 120 s, retry do interceptor desligado', () async {
    final adapter = _BytesAdapter([1, 2, 3]);
    final dio = Dio()..httpClientAdapter = adapter;
    final ds = AudioBytesDatasource(dio, apiBase: 'https://plpcg.test', isWeb: true);

    final bytes = await ds.fetch('assets/praises/p1/m1.mp3');

    expect(bytes, [1, 2, 3]);
    expect(adapter.last!.uri.toString(), 'https://plpcg.test/api/coldigom/assets/praises/p1/m1.mp3');
    expect(adapter.last!.receiveTimeout, const Duration(seconds: 120));
    expect(adapter.last!.extra[RetryInterceptor.disableKey], isTrue);
    expect(adapter.last!.responseType, ResponseType.bytes);
  });

  test('nativo: URL direta do worker', () async {
    final adapter = _BytesAdapter([9]);
    final dio = Dio()..httpClientAdapter = adapter;
    final ds = AudioBytesDatasource(dio, apiBase: 'https://plpcg.test', isWeb: false);

    await ds.fetch('assets/praises/p1/m1.mp3');

    expect(adapter.last!.uri.toString(), isNot(contains('/api/coldigom/')));
    expect(adapter.last!.uri.path, endsWith('assets/praises/p1/m1.mp3'));
  });

  test('corpo vazio lança', () async {
    final dio = Dio()..httpClientAdapter = _BytesAdapter(const []);
    final ds = AudioBytesDatasource(dio, apiBase: '', isWeb: false);

    expect(ds.fetch('k'), throwsA(isA<StateError>()));
  });
}
```

Correr: `flutter test test/unit/features/audio_player/audio_bytes_datasource_test.dart` → falha.

- [ ] **Step 2: Datasource**

`lib/features/audio_player/data/datasources/audio_bytes_datasource.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/network/retry_interceptor.dart';
import '../../../../core/utils/coldigom_asset_url.dart';

/// Bytes de um áudio Coldigom para persistir (download do `/offline`).
///
/// Mesma regra de URL de `AudioTrackUrl.fetchUrlForTrack`: na web passa pelo
/// proxy same-policy (`/api/coldigom/<chave>`), no nativo vai direto ao
/// worker. `isWeb` é injetado para o teste cobrir os dois ramos sem `kIsWeb`.
/// O retry do interceptor fica desligado: `DownloadColdigomMaterials` já
/// retenta com o backoff de `download_retry.dart`, como o PDF.
class AudioBytesDatasource {
  const AudioBytesDatasource(
    this._dio, {
    required String apiBase,
    required bool isWeb,
  }) : _apiBase = apiBase,
       _isWeb = isWeb;

  final Dio _dio;
  final String _apiBase;
  final bool _isWeb;

  Future<Uint8List> fetch(String r2Key, {CancelToken? cancelToken}) async {
    final url = _isWeb
        ? ColdigomAssetUrl.fetchUrlForKey(r2Key, apiBase: _apiBase)
        : ColdigomAssetUrl.directUrlForKey(r2Key);
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: OfflineConfig.pdfDownloadReceiveTimeout,
        sendTimeout: OfflineConfig.pdfDownloadSendTimeout,
        extra: const {RetryInterceptor.disableKey: true},
      ),
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw StateError('Resposta de áudio vazia: $r2Key');
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }
}
```

Correr: `flutter test test/unit/features/audio_player/audio_bytes_datasource_test.dart` → 3 verdes.

- [ ] **Step 3: `resolveFromBytes` no resolver web e no stub**

`web_audio_source_resolver_stub.dart` — classe inteira:

```dart
import 'dart:typed_data';

/// Resolve URL de reprodução — nativo devolve HTTP direto.
class WebAudioSourceResolver {
  WebAudioSourceResolver({this.fetchBytes});

  final FetchAudioBytesFn? fetchBytes;

  static const int maxBlobBytes = 20 * 1024 * 1024;

  Future<Uri> resolveForPlayback(
    String fetchUrl, {
    String? cacheKey,
    String? streamFallbackUrl,
  }) async {
    return Uri.parse(streamFallbackUrl ?? fetchUrl);
  }

  /// No nativo o áudio local toca por `Uri.file`; blob URL é coisa da web.
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) => null;

  void revokeAll() {}
}

typedef FetchAudioBytesFn =
    Future<List<int>> Function(String url, {String? fallbackUrl});

WebAudioSourceResolver createWebAudioSourceResolver({
  required FetchAudioBytesFn fetchBytes,
}) {
  return WebAudioSourceResolver(fetchBytes: fetchBytes);
}
```

`web_audio_source_resolver_web.dart`, depois de `resolveForPlayback` (linha 49):

```dart
  /// Blob URL para bytes já no aparelho (Cache API) — o caminho offline.
  ///
  /// Mesmo cache de 2 entradas e o mesmo teto [maxBlobBytes]: acima dele
  /// devolve `null` e quem chama cai na URL de rede (um áudio desse tamanho
  /// não é tocado por blob nem online).
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) {
    final cached = _blobUrls[cacheKey];
    if (cached != null) return Uri.parse(cached);
    if (bytes.length > maxBlobBytes) return null;
    final blob = Blob(
      [bytes.toJS].toJS,
      BlobPropertyBag(type: _mimeFromUrl(cacheKey)),
    );
    final blobUrl = URL.createObjectURL(blob);
    _blobUrls[cacheKey] = blobUrl;
    _trimCache(cacheKey);
    return Uri.parse(blobUrl);
  }
```

- [ ] **Step 4: l10n**

`app_pt.arb`: `"audioNotDownloaded": "Este áudio não foi baixado — sem ligação, só o que está no aparelho toca"`. `app_en.arb`: `"audioNotDownloaded": "This audio was not downloaded — offline, only what is on the device plays"`. Correr `flutter gen-l10n`.

- [ ] **Step 5: Teste da sessão que falha**

`test/unit/features/audio_player/audio_player_session_local_source_test.dart` — copie de `audio_player_session_robustness_test.dart` (linhas 1–120) a classe `_ControllablePlayer` e a função `_track` **na íntegra** (o duplo do player é o mesmo), e acrescente:

```dart
import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_audio_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_audio_source.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_audio_repository.dart';
import 'package:just_audio/just_audio.dart';

class _Connectivity implements DeviceConnectivity {
  _Connectivity(this.online);
  final bool online;
  @override
  Future<bool> hasConnection() async => online;
}

/// Só `lookup` importa aqui; o resto do contrato não é chamado.
class _LookupRepo implements OfflineAudioRepository {
  _LookupRepo(this.local);
  final Map<String, String> local;

  @override
  Future<LocalAudioSource?> lookup(String audioId) async {
    final key = local[audioId];
    return key == null ? null : LocalAudioSource(audioId: audioId, storageKey: key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ControllablePlayer player;

  Future<ProviderContainer> makeContainer({
    required Map<String, String> local,
    required bool online,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioSessionPlayerFactoryProvider.overrideWithValue(() => player),
        offlineAudioRepositoryProvider.overrideWithValue(_LookupRepo(local)),
        deviceConnectivityProvider.overrideWithValue(_Connectivity(online)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _ControllablePlayer();
  });

  Uri uriOf(AudioSource source) => (source as UriAudioSource).uri;

  test('faixa baixada toca por Uri.file; miss toca da rede', () async {
    final container = await makeContainer(
      local: {'a1': '/docs/plpcg_audio/assets/praises/p1/a1.mp3'},
      online: true,
    );

    await container
        .read(audioPlayerSessionProvider.notifier)
        .playQueue([_track('a1'), _track('a2')]);

    final sources = player.setSourcesCalls.single;
    expect(uriOf(sources[0]), Uri.file('/docs/plpcg_audio/assets/praises/p1/a1.mp3'));
    expect(uriOf(sources[1]).scheme, 'https');
    expect(container.read(audioPlayerSessionProvider).notDownloaded, isFalse);
  });

  test('miss sem rede → erro «não baixado», nada é aplicado ao player', () async {
    final container = await makeContainer(local: const {}, online: false);

    await container.read(audioPlayerSessionProvider.notifier).playQueue([_track('a1')]);

    final state = container.read(audioPlayerSessionProvider);
    expect(state.notDownloaded, isTrue);
    expect(state.errorMessage, isNotNull);
    expect(player.setSourcesCalls, isEmpty);
  });

  test('miss sem rede mas com outra faixa local: só a ausente falha a fila', () async {
    final container = await makeContainer(local: {'a1': '/x/a1.mp3'}, online: false);

    await container.read(audioPlayerSessionProvider.notifier).playQueue([_track('a1')]);

    expect(container.read(audioPlayerSessionProvider).notDownloaded, isFalse);
    expect(uriOf(player.setSourcesCalls.single.single), Uri.file('/x/a1.mp3'));
  });
}
```

Correr: `flutter test test/unit/features/audio_player/audio_player_session_local_source_test.dart` → falha (`notDownloaded` não existe).

- [ ] **Step 6: Sessão**

Em `audio_player_session_provider.dart`:

1. Imports: `../../../../core/providers/device_connectivity_provider.dart`, `../../../offline/data/providers/offline_audio_providers.dart`.
2. Estado: campo `final bool notDownloaded;` (construtor `this.notDownloaded = false`), doc: «`true` quando a última carga falhou porque a faixa não está no aparelho e não há rede — a tela troca a mensagem genérica por `audioNotDownloaded`.»; em `copyWith`: parâmetro `bool? notDownloaded` e `notDownloaded: clearError ? false : (notDownloaded ?? this.notDownloaded),`.
3. Antes da classe `AudioPlayerSessionNotifier`:

```dart
/// A faixa não está no aparelho e não há rede — não é falha de rede
/// genérica, é «baixe primeiro» (spec offline Coldigom §5.1).
class AudioNotDownloadedException implements Exception {
  const AudioNotDownloadedException(this.audioId);

  final String audioId;

  @override
  String toString() => 'AudioNotDownloadedException($audioId)';
}
```

4. `_playbackUriForTrack`:

```dart
  /// Aparelho primeiro (O7): índice de áudio → `Uri.file` no nativo, bytes da
  /// Cache API → blob URL na web. Miss com rede → URL de rede (HTTP + CORP +
  /// crossOrigin; blob: com anonymous falha no Chrome/Safari). Miss sem rede
  /// → [AudioNotDownloadedException], para a tela dizer «baixe primeiro» em
  /// vez do erro genérico do player.
  Future<Uri> _playbackUriForTrack(AudioTrack track) async {
    final local = await ref.read(offlineAudioRepositoryProvider).lookup(track.audioId);
    if (local != null) {
      if (!ref.read(platformCapabilitiesProvider).isWeb) {
        return Uri.file(local.storageKey);
      }
      final bytes = await ref.read(audioStoragePortProvider).readBytes(local.storageKey);
      final blob = bytes == null ? null : _sourceResolver?.resolveFromBytes(track.audioId, bytes);
      if (blob != null) return blob;
    }
    if (!await ref.read(deviceConnectivityProvider).hasConnection()) {
      throw AudioNotDownloadedException(track.audioId);
    }
    return Uri.parse(AudioTrackUrl.fetchUrlForTrack(track));
  }
```

5. No `catch` de `_applyQueue` (linhas 598–603), antes do `on Object catch (e)` existente:

```dart
    } on AudioNotDownloadedException catch (e) {
      if (gen != _generation) return;
      debugPrint('[audio] faixa não baixada e sem rede: ${e.audioId}');
      state = state.copyWith(
        errorMessage: e.toString(),
        notDownloaded: true,
        playing: false,
      );
```

6. `audio_player_screen.dart` linhas 265–272: `Text(session.notDownloaded ? l10n.audioNotDownloaded : l10n.audioPlaybackError, …)`.

Correr: `flutter test test/unit/features/audio_player` → verdes (os testes existentes de robustez usam `_ControllablePlayer` sem override do repositório: o `offlineAudioRepositoryProvider` real cai em `optionalIsarProvider` = `null` → datasource degradado → `lookup` devolve `null` sem tocar em disco; e `deviceConnectivityProvider` real chama `connectivity_plus` — se algum teste existente falhar por `MissingPluginException`, sobrescreva nele `deviceConnectivityProvider` com `_Connectivity(true)`).

- [ ] **Step 7: Commit**

```bash
flutter gen-l10n
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(audio): AudioBytesDatasource e reprodução local-first (índice de áudio → Uri.file / blob; sem rede → «não baixado»)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 5: Alvos de download (`ColdigomDownloadTarget`), estimativas e `markPersistent`

**Files:**
- Modify: `lib/features/offline/data/datasources/offline_pdf_local_datasource.dart` (método novo depois de `markAllPersistent`, linha 175)
- Create: `lib/features/offline/domain/entities/coldigom_download_target.dart`
- Create: `lib/features/offline/domain/entities/coldigom_download_progress.dart`
- Test: `test/unit/features/offline/coldigom_download_target_test.dart`
- Test (existente, acrescentar caso): `test/unit/features/offline/offline_pdf_repository_test.dart`

**Interfaces:**
- Consumes: `ColdigomPraiseCache`, `ColdigomPraiseCacheMapper.decodeMaterials`, `ColdigomCatalogMaterialEntry` (plano 1), `materialKindOfRawType`, `encodePdfId`, `OfflineConfig.coldigomEstimatedBytesByType`.
- Produces:
  - `Future<int> OfflinePdfLocalDatasource.markPersistent(Set<String> pdfIds)` — marca `isPersistent = true` só nos presentes; devolve quantos mudaram; avisa `onIndexChanged` se > 0.
  - `class ColdigomDownloadTarget { String praiseId, praiseNumber, praiseName, materialId, kindId, rawType, r2Key; MaterialKind kind; int? size; String get localId => encodePdfId(r2Key); int get estimatedBytes; bool get sizeIsEstimated; }`
  - `bool isColdigomDownloadableType(String rawType)` — `pdf|mp3|audio|chord|gestures`.
  - `List<ColdigomDownloadTarget> coldigomDownloadTargetsFrom(List<ColdigomPraiseCache> rows, {required Set<String> kindIds})` — só `kindId ∈ kindIds`, tipo baixável, `r2Key` não vazio; ordenado por `number` (numérico, vazios no fim) e depois `name`.
  - `class ColdigomDownloadProgress { String kindId; int doneInKind, totalInKind, doneTotal, total; String currentTitle; }`; `class ColdigomDownloadFailure { String materialId; Object cause; }`; `class ColdigomDownloadResult { int done, skipped, bytes; List<ColdigomDownloadFailure> failed; bool cancelled; bool get hasFailures; }`.

- [ ] **Step 1: Testes que falham**

`test/unit/features/offline/coldigom_download_target_test.dart`:

```dart
import 'dart:convert';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_target.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomPraiseCache _row(String id, String number, String name, List<Map<String, Object?>> materials) =>
    ColdigomPraiseCache()
      ..praiseId = id
      ..number = number
      ..name = name
      ..author = ''
      ..rhythm = ''
      ..tonality = ''
      ..category = ''
      ..tags = const []
      ..lyrics = ''
      ..materialsJson = jsonEncode(materials)
      ..searchTokens = '';

Map<String, Object?> _m(String id, String kind, String type, {int? size, String? r2}) => {
  'id': id,
  'kind': kind,
  'kindName': kind,
  'type': type,
  'r2': r2 ?? 'assets/praises/x/$id.$type',
  if (size != null) 'size': size,
};

void main() {
  final rows = [
    _row('p2', '010', 'Dez', [_m('m-pdf', 'k-grade', 'pdf', size: 1000)]),
    _row('p1', '002', 'Dois', [
      _m('m-mp3', 'k-play', 'mp3'),
      _m('m-chord', 'k-cifra', 'chord'),
      _m('m-gest', 'k-gest', 'gestures'),
      {'id': 'yt', 'kind': 'k-yt', 'kindName': '', 'type': 'youtube', 'r2': null, 'url': 'https://youtu.be/x'},
      {'id': 'm-sem-r2', 'kind': 'k-grade', 'kindName': '', 'type': 'pdf', 'r2': null},
    ]),
    _row('p3', '', 'Sem número', [_m('m-pdf3', 'k-grade', 'pdf')]),
  ];

  test('filtra por kind e tipo baixável, ignora youtube e sem r2Key', () {
    final targets = coldigomDownloadTargetsFrom(rows, kindIds: {'k-grade', 'k-play', 'k-yt'});

    expect(targets.map((t) => t.materialId), ['m-mp3', 'm-pdf', 'm-pdf3']);
    expect(targets.first.kind, MaterialKind.audio);
    expect(targets.first.localId, encodePdfId('assets/praises/x/m-mp3.mp3'));
    expect(targets.first.praiseName, 'Dois');
  });

  test('ordena por número (numérico, vazios no fim) e depois nome', () {
    final targets = coldigomDownloadTargetsFrom(rows, kindIds: {'k-grade', 'k-play', 'k-cifra', 'k-gest'});

    expect(targets.map((t) => t.praiseNumber), ['002', '002', '002', '010', '']);
  });

  test('estimativa: size quando existe, senão média por tipo com marca ~', () {
    final targets = coldigomDownloadTargetsFrom(rows, kindIds: {'k-grade', 'k-play', 'k-cifra', 'k-gest'});
    final byId = {for (final t in targets) t.materialId: t};

    expect(byId['m-pdf']!.estimatedBytes, 1000);
    expect(byId['m-pdf']!.sizeIsEstimated, isFalse);
    expect(byId['m-mp3']!.estimatedBytes, 4 * 1024 * 1024);
    expect(byId['m-mp3']!.sizeIsEstimated, isTrue);
    expect(byId['m-chord']!.estimatedBytes, 1024);
    expect(byId['m-gest']!.estimatedBytes, 60 * 1024);
  });

  test('isColdigomDownloadableType', () {
    expect(['pdf', 'MP3', 'audio', 'chord', 'gestures'].every(isColdigomDownloadableType), isTrue);
    expect(isColdigomDownloadableType('youtube'), isFalse);
    expect(isColdigomDownloadableType('lyrics'), isFalse);
  });
}
```

Em `test/unit/features/offline/offline_pdf_repository_test.dart`, acrescente no fim de `main` (use o `setUp` do ficheiro, que expõe o `local` datasource / `repository` — adapte o nome da variável ao que lá existe):

```dart
  test('markPersistent promove só os presentes e devolve quantos mudaram', () async {
    await repository.upsert(pdfId: 'lru-1', bytes: _validPdfBytes(), category: 'x');
    await repository.upsert(pdfId: 'lru-2', bytes: _validPdfBytes(), category: 'x', isPersistent: true);

    final changed = await local.markPersistent({'lru-1', 'lru-2', 'ausente'});

    expect(changed, 1);
    expect((await repository.findIndexEntry('lru-1'))!.isPersistent, isTrue);
    expect(await local.markPersistent({'lru-1'}), 0);
  });
```

Correr: `flutter test test/unit/features/offline/coldigom_download_target_test.dart test/unit/features/offline/offline_pdf_repository_test.dart` → falha.

- [ ] **Step 2: `markPersistent`**

Em `offline_pdf_local_datasource.dart`, depois de `markAllPersistent`:

```dart
  /// Promove [pdfIds] presentes a persistentes (download Coldigom por kind,
  /// spec §5.2): um PDF que já está no cache LRU não é baixado de novo, só
  /// deixa de ser candidato à eviction. Devolve quantos mudaram.
  Future<int> markPersistent(Set<String> pdfIds) async {
    if (pdfIds.isEmpty) return 0;
    final isar = _requireIsar('markPersistent');
    var changed = 0;
    await isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      final rows = coll
          .where()
          .anyOf(pdfIds, (q, pdfId) => q.pdfIdEqualTo(pdfId))
          .findAll();
      for (final row in rows) {
        if (row.isPersistent) continue;
        row.isPersistent = true;
        coll.put(row);
        changed++;
      }
    });
    if (changed > 0) onIndexChanged?.call();
    return changed;
  }
```

- [ ] **Step 3: Entidades**

`lib/features/offline/domain/entities/coldigom_download_target.dart`:

```dart
import '../../../../core/constants/offline_config.dart';
import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../coldigom/data/mappers/coldigom_praise_cache_mapper.dart';

/// `type` do Worker que o download sabe persistir (O10): PDF, áudio, cifra e
/// gestos. YouTube é link, letra já está no Isar.
bool isColdigomDownloadableType(String rawType) {
  return switch (rawType.toLowerCase()) {
    'pdf' || 'mp3' || 'audio' || 'chord' || 'gestures' => true,
    _ => false,
  };
}

/// Um material Coldigom a baixar — enumerado do catálogo local (§5.2).
class ColdigomDownloadTarget {
  const ColdigomDownloadTarget({
    required this.praiseId,
    required this.praiseNumber,
    required this.praiseName,
    required this.materialId,
    required this.kindId,
    required this.rawType,
    required this.kind,
    required this.r2Key,
    this.size,
  });

  final String praiseId;
  final String praiseNumber;
  final String praiseName;
  final String materialId;
  final String kindId;

  /// `pdf`/`mp3`/`audio`/`chord`/`gestures` como o Worker manda.
  final String rawType;
  final MaterialKind kind;
  final String r2Key;

  /// Bytes reais quando o dump os trouxe (O13).
  final int? size;

  /// Id no espaço do app (`pdfId`/`audioId`/`chordId`/`gestureId`).
  String get localId => encodePdfId(r2Key);

  bool get sizeIsEstimated => size == null;

  /// [size] ou a média por tipo de [OfflineConfig.coldigomEstimatedBytesByType].
  int get estimatedBytes =>
      size ??
      OfflineConfig.coldigomEstimatedBytesByType[rawType.toLowerCase()] ??
      0;

  /// Título de progresso: «001 · Nome».
  String get title =>
      praiseNumber.isEmpty ? praiseName : '$praiseNumber · $praiseName';
}

/// Alvos dos [kindIds] a partir das linhas do catálogo, em ordem de número
/// (o utilizador vê o progresso «em ordem»).
List<ColdigomDownloadTarget> coldigomDownloadTargetsFrom(
  List<ColdigomPraiseCache> rows, {
  required Set<String> kindIds,
}) {
  if (kindIds.isEmpty) return const [];
  final targets = <ColdigomDownloadTarget>[];
  for (final row in rows) {
    for (final m in ColdigomPraiseCacheMapper.decodeMaterials(row)) {
      final kindId = m.kindId;
      final r2Key = m.r2Key;
      if (kindId == null || !kindIds.contains(kindId)) continue;
      if (!isColdigomDownloadableType(m.type)) continue;
      if (r2Key == null || r2Key.isEmpty) continue;
      targets.add(
        ColdigomDownloadTarget(
          praiseId: row.praiseId,
          praiseNumber: row.number,
          praiseName: row.name,
          materialId: m.id,
          kindId: kindId,
          rawType: m.type,
          kind: materialKindOfRawType(m.type),
          r2Key: r2Key,
          size: m.size,
        ),
      );
    }
  }
  targets.sort(_compareTargets);
  return targets;
}

int _compareTargets(ColdigomDownloadTarget a, ColdigomDownloadTarget b) {
  final na = int.tryParse(a.praiseNumber) ?? -1;
  final nb = int.tryParse(b.praiseNumber) ?? -1;
  if (na != -1 && nb != -1 && na != nb) return na.compareTo(nb);
  if (na != -1 && nb == -1) return -1;
  if (na == -1 && nb != -1) return 1;
  final byName = a.praiseName.toLowerCase().compareTo(b.praiseName.toLowerCase());
  if (byName != 0) return byName;
  return a.materialId.compareTo(b.materialId);
}
```

`lib/features/offline/domain/entities/coldigom_download_progress.dart`:

```dart
/// Progresso de [DownloadColdigomMaterials] — por kind e total (§5.2).
class ColdigomDownloadProgress {
  const ColdigomDownloadProgress({
    required this.kindId,
    required this.doneInKind,
    required this.totalInKind,
    required this.doneTotal,
    required this.total,
    required this.currentTitle,
  });

  final String kindId;
  final int doneInKind;
  final int totalInKind;
  final int doneTotal;
  final int total;

  /// «001 · Nome» do alvo que acabou de ser processado.
  final String currentTitle;
}

/// Um alvo que falhou — o download segue; a UI oferece «Tentar de novo».
class ColdigomDownloadFailure {
  const ColdigomDownloadFailure({required this.materialId, required this.cause});

  final String materialId;
  final Object cause;
}

/// Resultado de [DownloadColdigomMaterials] (parcial se cancelado/quota).
class ColdigomDownloadResult {
  const ColdigomDownloadResult({
    required this.done,
    required this.skipped,
    required this.failed,
    required this.bytes,
    this.cancelled = false,
  });

  /// Baixados nesta execução.
  final int done;

  /// Já presentes (índice/cache) — não re-fetchados.
  final int skipped;
  final List<ColdigomDownloadFailure> failed;

  /// Bytes gravados nesta execução.
  final int bytes;

  /// Parado por cancelamento ou falta de espaço.
  final bool cancelled;

  bool get hasFailures => failed.isNotEmpty;
}
```

Correr: `flutter test test/unit/features/offline/coldigom_download_target_test.dart test/unit/features/offline/offline_pdf_repository_test.dart` → verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib/features/offline test/unit/features/offline
flutter analyze
git add lib/features/offline test/unit/features/offline
git commit -m "feat(offline): alvos de download Coldigom por kind (ordem, estimativas O13) e markPersistent no índice de PDF

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 6: `DownloadColdigomMaterials`

**Files:**
- Create: `lib/features/offline/domain/usecases/download_coldigom_materials.dart`
- Test: `test/unit/features/offline/download_coldigom_materials_test.dart`

**Interfaces:**
- Consumes: `coldigomDownloadTargetsFrom`, `ColdigomDownloadProgress/Result/Failure` (Task 5); `ColdigomCatalogLocalDatasource.findAllSync` (plano 1); `OfflinePdfRepository.listAll/lookupBatch`, `OfflinePdfLocalDatasource.markPersistent`; `AudioBytesDatasource.fetch` (Task 4), `OfflineAudioRepository.lookupBatch/upsert` (Task 3); `ChordContentDatasource.fetchContent`, `ChordContentLocalDatasource.read/write`; `GestureContentDatasource.fetchContent`, `GestureContentLocalDatasource.read/write`, `GestureFigureRepository.prefetch`; `isRetryableDioException`, `retryDelayForAttempt`; `InsufficientDiskSpaceException`; `CancelToken`.
- Produces:
  - `typedef FetchColdigomPdf = Future<void> Function(String pdfId, String r2Key)` — em produção: `fetchAndStorePdf(pdfId:, remotePath: '/$r2Key', persistentDownload: true)`.
  - `typedef GestureFigureKeysResolver = Future<Set<String>> Function(String gestureJson)` — em produção: parse + dicionário + `flattenGestureCards`.
  - `class DownloadColdigomMaterials { DownloadColdigomMaterials({required catalog, required pdfRepository, required pdfLocal, required fetchPdf, required audioBytes, required audioRepository, required chordRemote, required chordLocal, required gestureRemote, required gestureLocal, required figures, required figureKeysFor, required int concurrency}); Future<ColdigomDownloadResult> call({required Set<String> kindIds, CancelToken? cancelToken, void Function(ColdigomDownloadProgress)? onProgress}); }`
  - Regras: alvos presentes → `skipped` (PDF LRU presente → `markPersistent`, sem download); cifra/gestos `404` → marcador negativo gravado, conta como `done`; falha individual → `failed` e segue (com até `OfflineConfig.maxRetryAttempts` tentativas em `DioException` retryável); `InsufficientDiskSpaceException` ou cancelamento → para os workers e devolve `cancelled: true`.

- [ ] **Step 1: Teste que falha**

`test/unit/features/offline/download_coldigom_materials_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/data/datasources/audio_bytes_datasource.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_datasource.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_local_datasource.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_progress.dart';
import 'package:coldigui/features/offline/domain/entities/local_audio_source.dart';
import 'package:coldigui/features/offline/domain/entities/offline_audio_entry.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_audio_repository.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/download_coldigom_materials.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ------------------------------------------------------------- catálogo

ColdigomPraiseCache _row(String id, String number, List<Map<String, Object?>> materials) =>
    ColdigomPraiseCache()
      ..praiseId = id
      ..number = number
      ..name = 'Louvor $number'
      ..author = ''
      ..rhythm = ''
      ..tonality = ''
      ..category = ''
      ..tags = const []
      ..lyrics = ''
      ..materialsJson = jsonEncode(materials)
      ..searchTokens = '';

Map<String, Object?> _m(String id, String kind, String type) => {
  'id': id,
  'kind': kind,
  'kindName': kind,
  'type': type,
  'r2': 'assets/praises/x/$id.$type',
};

String _r2(String id, String type) => 'assets/praises/x/$id.$type';

class _Catalog extends ColdigomCatalogLocalDatasource {
  const _Catalog(this.rows) : super(null);
  final List<ColdigomPraiseCache> rows;
  @override
  List<ColdigomPraiseCache> findAllSync() => rows;
}

// ------------------------------------------------------------------ PDF

class _PdfRepo implements OfflinePdfRepository {
  _PdfRepo({this.present = const {}, this.persistent = const {}});
  final Set<String> present;
  final Set<String> persistent;

  @override
  Future<List<OfflinePdfEntry>> listAll() async => [
    for (final id in present)
      OfflinePdfEntry(
        pdfId: id,
        absolutePath: '/x/$id',
        category: 'x',
        fileSize: 1,
        downloadedAt: DateTime(2026),
        isPersistent: persistent.contains(id),
      ),
  ];

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) async => pdfIds.intersection(present);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _PdfLocal extends OfflinePdfLocalDatasource {
  const _PdfLocal(this.marked) : super(null);
  final Set<String> marked;
  @override
  Future<int> markPersistent(Set<String> pdfIds) async {
    marked.addAll(pdfIds);
    return pdfIds.length;
  }
}

// ---------------------------------------------------------------- áudio

class _AudioBytes extends AudioBytesDatasource {
  _AudioBytes(this.respond) : super(Dio(), apiBase: '', isWeb: false);
  final Future<Uint8List> Function(String r2Key) respond;
  final calls = <String>[];
  @override
  Future<Uint8List> fetch(String r2Key, {CancelToken? cancelToken}) {
    calls.add(r2Key);
    return respond(r2Key);
  }
}

class _AudioRepo implements OfflineAudioRepository {
  _AudioRepo({this.present = const {}, this.upsertThrows});
  final Set<String> present;
  final Object? upsertThrows;
  final upserted = <String>[];

  @override
  Future<Set<String>> lookupBatch(Set<String> audioIds) async => audioIds.intersection(present);

  @override
  Future<OfflineAudioEntry> upsert({required String audioId, required String r2Key, required Uint8List bytes}) async {
    if (upsertThrows != null) throw upsertThrows!;
    upserted.add(audioId);
    return OfflineAudioEntry(audioId: audioId, r2Key: r2Key, storageKey: '/x/$audioId', fileSize: bytes.length, downloadedAt: DateTime(2026));
  }

  @override
  Future<LocalAudioSource?> lookup(String audioId) async => null;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

// ----------------------------------------------------------- cifra/gestos

class _ChordRemote extends ChordContentDatasource {
  _ChordRemote(this.respond) : super(Dio(), apiBase: '');
  final Future<String?> Function(String) respond;
  @override
  Future<String?> fetchContent(String r2Key) => respond(r2Key);
}

class _ChordLocal extends ChordContentLocalDatasource {
  _ChordLocal(this.store) : super(null);
  final Map<String, String> store;
  @override
  ChordCacheEntry? read(String r2Key) {
    final c = store[r2Key];
    return c == null ? null : ChordCacheEntry(content: c, fetchedAt: DateTime(2026));
  }
  @override
  void write(String r2Key, String content) => store[r2Key] = content;
}

class _GestureRemote extends GestureContentDatasource {
  _GestureRemote(this.respond) : super(Dio(), apiBase: '');
  final Future<String?> Function(String) respond;
  @override
  Future<String?> fetchContent(String r2Key) => respond(r2Key);
}

class _GestureLocal extends GestureContentLocalDatasource {
  _GestureLocal(this.store) : super(null);
  final Map<String, String> store;
  @override
  GestureCacheEntry? read(String r2Key) {
    final c = store[r2Key];
    return c == null ? null : GestureCacheEntry(content: c, fetchedAt: DateTime(2026));
  }
  @override
  void write(String r2Key, String content) => store[r2Key] = content;
}

class _Figures extends GestureFigureRepository {
  _Figures() : super(_NoStore(), Dio(), apiBase: '');
  final prefetched = <Set<String>>[];
  @override
  Future<void> prefetch(Iterable<String> r2Keys) async => prefetched.add(r2Keys.toSet());
}

class _NoStore implements GestureFigureStorePort {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

// --------------------------------------------------------------- helpers

DioException _retryable() => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: DioExceptionType.connectionTimeout,
);

void main() {
  late Set<String> marked;
  late _Figures figures;

  DownloadColdigomMaterials build({
    required List<ColdigomPraiseCache> rows,
    _PdfRepo? pdfRepo,
    Set<String>? pdfFetched,
    Future<void> Function(String pdfId, String r2Key)? fetchPdf,
    _AudioBytes? audioBytes,
    _AudioRepo? audioRepo,
    Future<String?> Function(String)? chord,
    Map<String, String>? chordStore,
    Future<String?> Function(String)? gesture,
    Map<String, String>? gestureStore,
    int concurrency = 2,
  }) {
    marked = {};
    figures = _Figures();
    final fetched = pdfFetched ?? <String>{};
    return DownloadColdigomMaterials(
      catalog: _Catalog(rows),
      pdfRepository: pdfRepo ?? _PdfRepo(),
      pdfLocal: _PdfLocal(marked),
      fetchPdf: fetchPdf ?? (id, _) async {
        fetched.add(id);
      },
      audioBytes: audioBytes ?? _AudioBytes((_) async => Uint8List(3)),
      audioRepository: audioRepo ?? _AudioRepo(),
      chordRemote: _ChordRemote(chord ?? (_) async => '{t: x}'),
      chordLocal: _ChordLocal(chordStore ?? {}),
      gestureRemote: _GestureRemote(gesture ?? (_) async => '{"cards":[]}'),
      gestureLocal: _GestureLocal(gestureStore ?? {}),
      figures: figures,
      figureKeysFor: (_) async => {'fig/a.png', 'fig/b.png'},
      concurrency: concurrency,
    );
  }

  test('filtra por kind/tipo e baixa cada tipo pelo caminho certo', () async {
    final pdfFetched = <String>{};
    final chordStore = <String, String>{};
    final gestureStore = <String, String>{};
    final audioRepo = _AudioRepo();
    final usecase = build(
      rows: [
        _row('p1', '001', [
          _m('a', 'k-pdf', 'pdf'),
          _m('b', 'k-mp3', 'mp3'),
          _m('c', 'k-chord', 'chord'),
          _m('d', 'k-gest', 'gestures'),
          _m('e', 'k-fora', 'pdf'),
        ]),
      ],
      pdfFetched: pdfFetched,
      audioRepo: audioRepo,
      chordStore: chordStore,
      gestureStore: gestureStore,
    );
    final progress = <ColdigomDownloadProgress>[];

    final result = await usecase(
      kindIds: {'k-pdf', 'k-mp3', 'k-chord', 'k-gest'},
      onProgress: progress.add,
    );

    expect(result.done, 4);
    expect(result.skipped, 0);
    expect(result.failed, isEmpty);
    expect(result.bytes, 3 + '{t: x}'.length + '{"cards":[]}'.length);
    expect(pdfFetched, {encodePdfId(_r2('a', 'pdf'))});
    expect(audioRepo.upserted, [encodePdfId(_r2('b', 'mp3'))]);
    expect(chordStore[_r2('c', 'chord')], '{t: x}');
    expect(gestureStore[_r2('d', 'gestures')], '{"cards":[]}');
    expect(figures.prefetched.single, {'fig/a.png', 'fig/b.png'});
    expect(progress.last.doneTotal, 4);
    expect(progress.last.total, 4);
    expect(progress.map((p) => p.currentTitle).toSet(), {'001 · Louvor 001'});
  });

  test('presentes são saltados; PDF LRU é promovido sem download; cifra 404 conta como feito', () async {
    final pdfFetched = <String>{};
    final pdfA = encodePdfId(_r2('a', 'pdf'));
    final audioB = encodePdfId(_r2('b', 'mp3'));
    final chordStore = <String, String>{_r2('c', 'chord'): 'já tenho'};
    final usecase = build(
      rows: [
        _row('p1', '001', [
          _m('a', 'k', 'pdf'),
          _m('b', 'k', 'mp3'),
          _m('c', 'k', 'chord'),
          _m('c2', 'k', 'chord'),
        ]),
      ],
      pdfRepo: _PdfRepo(present: {pdfA}),
      pdfFetched: pdfFetched,
      audioRepo: _AudioRepo(present: {audioB}),
      chord: (_) async => null,
      chordStore: chordStore,
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.skipped, 3);
    expect(result.done, 1);
    expect(pdfFetched, isEmpty);
    expect(marked, {pdfA});
    expect(chordStore[_r2('c2', 'chord')], '');
  });

  test('falha individual (após retries) não para; DioException retryável é retentada', () async {
    var attempts = 0;
    final usecase = build(
      rows: [
        _row('p1', '001', [_m('a', 'k', 'mp3'), _m('b', 'k', 'mp3')]),
      ],
      audioBytes: _AudioBytes((key) async {
        if (key.contains('/a.')) {
          attempts++;
          throw _retryable();
        }
        return Uint8List(1);
      }),
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.done, 1);
    expect(result.failed.single.materialId, 'a');
    expect(result.failed.single.cause, isA<DioException>());
    expect(attempts, 3);
    expect(result.cancelled, isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('falta de espaço para tudo e devolve o parcial', () async {
    final usecase = build(
      rows: [
        _row('p1', '001', [_m('a', 'k', 'mp3')]),
        _row('p2', '002', [_m('b', 'k', 'mp3')]),
        _row('p3', '003', [_m('c', 'k', 'mp3')]),
      ],
      audioRepo: _AudioRepo(
        upsertThrows: const InsufficientDiskSpaceException(requiredBytes: 1, availableBytes: 0),
      ),
      concurrency: 1,
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.cancelled, isTrue);
    expect(result.done, 0);
    expect(result.failed.single.cause, isA<InsufficientDiskSpaceException>());
  });

  test('cancelamento devolve o parcial e não inicia mais alvos', () async {
    final gate = Completer<void>();
    final token = CancelToken();
    final audio = _AudioBytes((key) async {
      if (key.contains('/a.')) {
        await gate.future;
        return Uint8List(1);
      }
      return Uint8List(1);
    });
    final usecase = build(
      rows: [
        _row('p1', '001', [_m('a', 'k', 'mp3')]),
        _row('p2', '002', [_m('b', 'k', 'mp3')]),
        _row('p3', '003', [_m('c', 'k', 'mp3')]),
      ],
      audioBytes: audio,
      concurrency: 1,
    );

    final future = usecase(kindIds: {'k'}, cancelToken: token);
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    gate.complete();
    final result = await future;

    expect(result.cancelled, isTrue);
    expect(result.done, 1);
    expect(audio.calls, hasLength(1));
  });

  test('concorrência limitada ao valor configurado', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final usecase = build(
      rows: [
        for (var i = 0; i < 6; i++) _row('p$i', '00$i', [_m('m$i', 'k', 'mp3')]),
      ],
      audioBytes: _AudioBytes((_) async {
        inFlight++;
        maxInFlight = maxInFlight < inFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return Uint8List(1);
      }),
      concurrency: 2,
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.done, 6);
    expect(maxInFlight, 2);
  });
}
```

(import extra: `package:coldigui/features/gestures/data/datasources/gesture_figure_store.dart` para `GestureFigureStorePort` — confirme o nome exato da porta nesse ficheiro.)

Correr: `flutter test test/unit/features/offline/download_coldigom_materials_test.dart` → falha.

- [ ] **Step 2: Use case**

`lib/features/offline/domain/usecases/download_coldigom_materials.dart`:

```dart
import 'dart:math' show min;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../audio_player/data/datasources/audio_bytes_datasource.dart';
import '../../../chords/data/datasources/chord_content_datasource.dart';
import '../../../chords/data/datasources/chord_content_local_datasource.dart';
import '../../../coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import '../../../gestures/data/datasources/gesture_content_datasource.dart';
import '../../../gestures/data/datasources/gesture_content_local_datasource.dart';
import '../../../gestures/data/repositories/gesture_figure_repository.dart';
import '../../data/datasources/offline_pdf_local_datasource.dart';
import '../entities/coldigom_download_progress.dart';
import '../entities/coldigom_download_target.dart';
import '../exceptions/offline_bulk_exceptions.dart';
import '../repositories/offline_audio_repository.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/download_retry.dart';

/// Baixa e persiste um PDF como persistente (`FetchAndStorePdf` em produção).
typedef FetchColdigomPdf = Future<void> Function(String pdfId, String r2Key);

/// `r2Key`s das figuras de um documento `.gestures` (parse + dicionário).
typedef GestureFigureKeysResolver = Future<Set<String>> Function(String gestureJson);

/// Download dos materiais Coldigom dos [kindIds] escolhidos (spec §5.2, O12).
///
/// Idempotente e retomável por construção: enumera do catálogo local, salta
/// o que já está no índice/cache e pode ser parado e chamado de novo sem
/// checkpoint. Cada tipo persiste onde já persistia (C1/O7): PDF no
/// `OfflinePdfIndex` (LRU presente é só promovido), áudio no índice novo,
/// cifra e gestos nos caches Isar (404 vira marcador negativo e conta como
/// feito — o sheet já sabe que «não existe»).
///
/// Falha individual → `failed` e segue, como `DownloadMissingPdfs`;
/// [InsufficientDiskSpaceException] ou cancelamento → para tudo e devolve o
/// parcial (`cancelled: true`).
class DownloadColdigomMaterials {
  DownloadColdigomMaterials({
    required ColdigomCatalogLocalDatasource catalog,
    required OfflinePdfRepository pdfRepository,
    required OfflinePdfLocalDatasource pdfLocal,
    required FetchColdigomPdf fetchPdf,
    required AudioBytesDatasource audioBytes,
    required OfflineAudioRepository audioRepository,
    required ChordContentDatasource chordRemote,
    required ChordContentLocalDatasource chordLocal,
    required GestureContentDatasource gestureRemote,
    required GestureContentLocalDatasource gestureLocal,
    required GestureFigureRepository figures,
    required GestureFigureKeysResolver figureKeysFor,
    required int concurrency,
  }) : _catalog = catalog,
       _pdfRepository = pdfRepository,
       _pdfLocal = pdfLocal,
       _fetchPdf = fetchPdf,
       _audioBytes = audioBytes,
       _audioRepository = audioRepository,
       _chordRemote = chordRemote,
       _chordLocal = chordLocal,
       _gestureRemote = gestureRemote,
       _gestureLocal = gestureLocal,
       _figures = figures,
       _figureKeysFor = figureKeysFor,
       _concurrency = concurrency < 1 ? 1 : concurrency;

  final ColdigomCatalogLocalDatasource _catalog;
  final OfflinePdfRepository _pdfRepository;
  final OfflinePdfLocalDatasource _pdfLocal;
  final FetchColdigomPdf _fetchPdf;
  final AudioBytesDatasource _audioBytes;
  final OfflineAudioRepository _audioRepository;
  final ChordContentDatasource _chordRemote;
  final ChordContentLocalDatasource _chordLocal;
  final GestureContentDatasource _gestureRemote;
  final GestureContentLocalDatasource _gestureLocal;
  final GestureFigureRepository _figures;
  final GestureFigureKeysResolver _figureKeysFor;
  final int _concurrency;

  Future<ColdigomDownloadResult> call({
    required Set<String> kindIds,
    CancelToken? cancelToken,
    void Function(ColdigomDownloadProgress)? onProgress,
  }) async {
    final targets = coldigomDownloadTargetsFrom(
      _catalog.findAllSync(),
      kindIds: kindIds,
    );
    final present = await _collectPresent(targets);

    final pending = <ColdigomDownloadTarget>[];
    var skipped = 0;
    for (final target in targets) {
      if (present.contains(target.localId)) {
        skipped++;
      } else {
        pending.add(target);
      }
    }

    final totalInKind = <String, int>{};
    for (final t in targets) {
      totalInKind.update(t.kindId, (v) => v + 1, ifAbsent: () => 1);
    }
    final doneInKind = <String, int>{};
    for (final t in targets) {
      if (present.contains(t.localId)) {
        doneInKind.update(t.kindId, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    var done = 0;
    var bytes = 0;
    var doneTotal = skipped;
    var stopped = false;
    var nextIndex = 0;
    final failed = <ColdigomDownloadFailure>[];

    Future<void> worker() async {
      while (!stopped) {
        if (cancelToken?.isCancelled ?? false) {
          stopped = true;
          break;
        }
        if (nextIndex >= pending.length) break;
        final target = pending[nextIndex++];
        try {
          bytes += await _download(target, cancelToken);
          done++;
        } on InsufficientDiskSpaceException catch (error) {
          failed.add(ColdigomDownloadFailure(materialId: target.materialId, cause: error));
          stopped = true;
          break;
        } on Object catch (error) {
          if (cancelToken?.isCancelled ?? false) {
            stopped = true;
            break;
          }
          debugPrint('[offline] coldigom ${target.materialId} falhou: $error');
          failed.add(ColdigomDownloadFailure(materialId: target.materialId, cause: error));
        }
        doneTotal++;
        doneInKind.update(target.kindId, (v) => v + 1, ifAbsent: () => 1);
        onProgress?.call(
          ColdigomDownloadProgress(
            kindId: target.kindId,
            doneInKind: doneInKind[target.kindId] ?? 0,
            totalInKind: totalInKind[target.kindId] ?? 0,
            doneTotal: doneTotal,
            total: targets.length,
            currentTitle: target.title,
          ),
        );
      }
    }

    if (pending.isNotEmpty) {
      final workers = min(_concurrency, pending.length);
      await Future.wait(List.generate(workers, (_) => worker()));
    }

    return ColdigomDownloadResult(
      done: done,
      skipped: skipped,
      failed: failed,
      bytes: bytes,
      cancelled: stopped,
    );
  }

  /// `localId`s já presentes, por tipo. PDFs no índice mas só em LRU são
  /// promovidos a persistentes aqui — sem novo download.
  Future<Set<String>> _collectPresent(List<ColdigomDownloadTarget> targets) async {
    final present = <String>{};

    final pdfIds = {for (final t in targets) if (t.kind == MaterialKind.pdf) t.localId};
    if (pdfIds.isNotEmpty) {
      final valid = await _pdfRepository.lookupBatch(pdfIds);
      present.addAll(valid);
      final lru = {
        for (final entry in await _pdfRepository.listAll())
          if (!entry.isPersistent && valid.contains(entry.pdfId)) entry.pdfId,
      };
      if (lru.isNotEmpty) await _pdfLocal.markPersistent(lru);
    }

    final audioIds = {for (final t in targets) if (t.kind == MaterialKind.audio) t.localId};
    if (audioIds.isNotEmpty) {
      present.addAll(await _audioRepository.lookupBatch(audioIds));
    }

    for (final t in targets) {
      if (t.kind == MaterialKind.chord && _chordLocal.read(t.r2Key) != null) {
        present.add(t.localId);
      }
      if (t.kind == MaterialKind.gesture && _gestureLocal.read(t.r2Key) != null) {
        present.add(t.localId);
      }
    }
    return present;
  }

  /// Bytes gravados para [target]; lança para o worker classificar.
  Future<int> _download(ColdigomDownloadTarget target, CancelToken? cancelToken) async {
    switch (target.kind) {
      case MaterialKind.pdf:
        await _withRetry(() => _fetchPdf(target.localId, target.r2Key));
        return target.estimatedBytes;
      case MaterialKind.audio:
        final bytes = await _withRetry(
          () => _audioBytes.fetch(target.r2Key, cancelToken: cancelToken),
        );
        await _audioRepository.upsert(
          audioId: target.localId,
          r2Key: target.r2Key,
          bytes: bytes,
        );
        return bytes.length;
      case MaterialKind.chord:
        final content = await _withRetry(() => _chordRemote.fetchContent(target.r2Key));
        _chordLocal.write(target.r2Key, content ?? '');
        return content?.length ?? 0;
      case MaterialKind.gesture:
        final content = await _withRetry(() => _gestureRemote.fetchContent(target.r2Key));
        _gestureLocal.write(target.r2Key, content ?? '');
        if (content != null) {
          await _figures.prefetch(await _figureKeysFor(content));
        }
        return content?.length ?? 0;
      case MaterialKind.youtube:
      case MaterialKind.lyrics:
      case MaterialKind.unknown:
        // `coldigomDownloadTargetsFrom` nunca emite estes tipos.
        throw StateError('tipo não baixável: ${target.rawType}');
    }
  }

  /// Mesmo backoff de `FetchAndStorePdf._fetchBytesWithRetry`; só
  /// `DioException` retryável (rede/5xx) é repetida.
  Future<T> _withRetry<T>(Future<T> Function() attempt) async {
    for (var n = 1; ; n++) {
      try {
        return await attempt();
      } on DioException catch (error) {
        if (!isRetryableDioException(error) || n >= OfflineConfig.maxRetryAttempts) {
          rethrow;
        }
        await Future<void>.delayed(retryDelayForAttempt(n));
      }
    }
  }
}
```

Correr: `flutter test test/unit/features/offline/download_coldigom_materials_test.dart` → 6 verdes. Nota: `ChordFetchFailedException`/`GestureFetchFailedException` embrulham o `DioException` — não são retentadas aqui (contam como falha individual), o que é aceitável: os ficheiros têm < 8 KB e o botão «Tentar de novo» re-executa idempotente.

- [ ] **Step 3: Commit**

```bash
dart format lib/features/offline test/unit/features/offline/download_coldigom_materials_test.dart
flutter analyze
git add lib/features/offline test/unit/features/offline/download_coldigom_materials_test.dart
git commit -m "feat(offline): DownloadColdigomMaterials — fila idempotente por kind, por tipo de storage, parcial em quota/cancelamento

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 7: `RemoveColdigomDownloads`, store de seleção e DI

**Files:**
- Create: `lib/features/offline/domain/usecases/remove_coldigom_downloads.dart`
- Create: `lib/features/offline/data/datasources/offline_coldigom_kind_selection_store.dart`
- Modify: `lib/core/constants/storage_keys.dart` (fim da classe)
- Create: `lib/features/offline/data/providers/offline_coldigom_providers.dart`
- Test: `test/unit/features/offline/remove_coldigom_downloads_test.dart`
- Test: `test/unit/features/offline/offline_coldigom_kind_selection_store_test.dart`

**Interfaces:**
- Consumes: `OfflinePdfRepository.listAll/remove`, `isColdigomPdfId`, `OfflineAudioRepository.removeAll` (Task 3), `DownloadColdigomMaterials` (Task 6), `fetchAndStorePdfProvider`, `offlinePdfRepositoryProvider`, `offlinePdfLocalDatasourceProvider`, `coldigomCatalogLocalDatasourceProvider` (plano 1), `chordContentDatasourceProvider`, `chordContentLocalDatasourceProvider`, `gestureContentDatasourceProvider`, `gestureContentLocalDatasourceProvider`, `gestureFigureRepositoryProvider`, `gestureDictionaryProvider`, `parseGestureDocument`, `flattenGestureCards`, `dioProvider`, `AppConfig.apiBaseUrl`, `platformCapabilitiesProvider`.
- Produces:
  - `class RemoveColdigomDownloads { RemoveColdigomDownloads({required OfflinePdfRepository pdfRepository, required OfflineAudioRepository audioRepository}); Future<RemoveColdigomDownloadsResult> call(); }` — `class RemoveColdigomDownloadsResult { int removedPdfs; int removedAudios; }`. Remove `OfflineAudioIndex` + store inteiro; PDFs Coldigom (`isColdigomPdfId`) com `isPersistent = true` → `remove`. Cifras/gestos/LRU ficam (O8).
  - `StorageKeys.offlineColdigomKindIds = 'offlineColdigomKindIds'`.
  - `class OfflineColdigomKindSelectionStore { const (SharedPreferences); bool get hasDecision; Set<String> read(); Future<void> write(Set<String>); }` — `hasDecision` distingue «nunca decidiu» (O11: pré-marcar favoritos) de «desmarcou tudo».
  - Providers: `offlineColdigomKindSelectionStoreProvider`, `audioBytesDatasourceProvider`, `downloadColdigomMaterialsProvider`, `removeColdigomDownloadsProvider`.

- [ ] **Step 1: Testes que falham**

`test/unit/features/offline/remove_coldigom_downloads_test.dart`:

```dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_audio_repository.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/remove_coldigom_downloads.dart';
import 'package:flutter_test/flutter_test.dart';

class _PdfRepo implements OfflinePdfRepository {
  _PdfRepo(this.entries);
  final List<OfflinePdfEntry> entries;
  final removed = <String>[];

  @override
  Future<List<OfflinePdfEntry>> listAll() async => entries;

  @override
  Future<void> remove(String pdfId) async => removed.add(pdfId);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _AudioRepo implements OfflineAudioRepository {
  var removeAllCalls = 0;
  @override
  Future<void> removeAll() async => removeAllCalls++;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

OfflinePdfEntry _entry(String path, {required bool persistent}) => OfflinePdfEntry(
  pdfId: encodePdfId(path),
  absolutePath: '/x/$path',
  category: 'x',
  fileSize: 1,
  downloadedAt: DateTime(2026),
  isPersistent: persistent,
);

void main() {
  test('remove áudios (tudo) e só PDFs Coldigom persistentes; PLPCG e LRU ficam', () async {
    final pdfRepo = _PdfRepo([
      _entry('assets/praises/p1/a.pdf', persistent: true),
      _entry('assets/praises/p1/b.pdf', persistent: false),
      _entry('ColAdultos/001.pdf', persistent: true),
    ]);
    final audioRepo = _AudioRepo();

    final result = await RemoveColdigomDownloads(
      pdfRepository: pdfRepo,
      audioRepository: audioRepo,
    ).call();

    expect(pdfRepo.removed, [encodePdfId('assets/praises/p1/a.pdf')]);
    expect(audioRepo.removeAllCalls, 1);
    expect(result.removedPdfs, 1);
  });
}
```

`test/unit/features/offline/offline_coldigom_kind_selection_store_test.dart`:

```dart
import 'package:coldigui/features/offline/data/datasources/offline_coldigom_kind_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sem decisão: hasDecision false e leitura vazia; write persiste e marca decisão', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineColdigomKindSelectionStore(await SharedPreferences.getInstance());

    expect(store.hasDecision, isFalse);
    expect(store.read(), isEmpty);

    await store.write({'k2', 'k1'});
    expect(store.hasDecision, isTrue);
    expect(store.read(), {'k1', 'k2'});

    await store.write({});
    expect(store.hasDecision, isTrue);
    expect(store.read(), isEmpty);
  });
}
```

Correr os dois → falham.

- [ ] **Step 2: Use case e store**

`lib/features/offline/domain/usecases/remove_coldigom_downloads.dart`:

```dart
import '../../../../core/utils/pdf_id_codec.dart';
import '../repositories/offline_audio_repository.dart';
import '../repositories/offline_pdf_repository.dart';

class RemoveColdigomDownloadsResult {
  const RemoveColdigomDownloadsResult({
    required this.removedPdfs,
    required this.removedAudios,
  });

  final int removedPdfs;

  /// Áudios no índice antes de apagar tudo.
  final int removedAudios;
}

/// «Remover áudios e PDFs baixados do Coldigom» (spec §5.2, O8).
///
/// Áudio sai inteiro (índice + store — só entra lá por download explícito).
/// PDF Coldigom só o persistente: o LRU on-demand continua a ser cache do
/// leitor e o PLPCG não é tocado. Cifras e gestos ficam — pesam KB e não são
/// evictados («textos ficam sempre» na UI).
class RemoveColdigomDownloads {
  const RemoveColdigomDownloads({
    required OfflinePdfRepository pdfRepository,
    required OfflineAudioRepository audioRepository,
  }) : _pdfRepository = pdfRepository,
       _audioRepository = audioRepository;

  final OfflinePdfRepository _pdfRepository;
  final OfflineAudioRepository _audioRepository;

  Future<RemoveColdigomDownloadsResult> call() async {
    final audios = (await _audioRepository.listAll()).length;
    await _audioRepository.removeAll();

    var removedPdfs = 0;
    for (final entry in await _pdfRepository.listAll()) {
      if (!entry.isPersistent || !isColdigomPdfId(entry.pdfId)) continue;
      await _pdfRepository.remove(entry.pdfId);
      removedPdfs++;
    }
    return RemoveColdigomDownloadsResult(
      removedPdfs: removedPdfs,
      removedAudios: audios,
    );
  }
}
```

(No teste acima, `_AudioRepo` precisa também de `listAll` → `async => const []`; acrescente.)

`storage_keys.dart`: `/// Kinds Coldigom marcados para download no /offline (O11) — JSON array.` + `static const String offlineColdigomKindIds = 'offlineColdigomKindIds';`.

`lib/features/offline/data/datasources/offline_coldigom_kind_selection_store.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Seleção **local** de kinds Coldigom para download (O11): independente
/// dos favoritos da conta — mudar favoritos não mexe no que já foi
/// marcado/baixado. A pré-marcação dos favoritos só se aplica quando o
/// utilizador nunca decidiu ([hasDecision] `false`), por isso «vazio» e
/// «nunca gravado» são estados diferentes.
class OfflineColdigomKindSelectionStore {
  const OfflineColdigomKindSelectionStore(this._prefs);

  final SharedPreferences _prefs;

  bool get hasDecision => _prefs.containsKey(StorageKeys.offlineColdigomKindIds);

  Set<String> read() {
    final raw = _prefs.getString(StorageKeys.offlineColdigomKindIds);
    if (raw == null) return const {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const {};
      return {for (final id in list) if (id is String && id.isNotEmpty) id};
    } on FormatException {
      return const {};
    }
  }

  Future<void> write(Set<String> kindIds) {
    return _prefs.setString(
      StorageKeys.offlineColdigomKindIds,
      jsonEncode(kindIds.toList()..sort()),
    );
  }
}
```

- [ ] **Step 3: DI**

`lib/features/offline/data/providers/offline_coldigom_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/offline_config.dart';
import '../../../../core/platform/platform_capabilities_provider.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../audio_player/data/datasources/audio_bytes_datasource.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../../gestures/domain/usecases/parse_gesture_document.dart';
import '../../../gestures/domain/utils/flatten_gesture_cards.dart';
import '../../domain/usecases/download_coldigom_materials.dart';
import '../../domain/usecases/remove_coldigom_downloads.dart';
import '../datasources/offline_coldigom_kind_selection_store.dart';
import 'offline_audio_providers.dart';
import 'offline_core_providers.dart';

/// DI — seleção local de kinds para download (O11).
final offlineColdigomKindSelectionStoreProvider =
    Provider<OfflineColdigomKindSelectionStore>((ref) {
      return OfflineColdigomKindSelectionStore(ref.watch(sharedPreferencesProvider));
    });

/// DI — bytes de áudio para persistir (proxy na web, direto no nativo).
final audioBytesDatasourceProvider = Provider<AudioBytesDatasource>((ref) {
  return AudioBytesDatasource(
    ref.watch(dioProvider),
    apiBase: AppConfig.apiBaseUrl,
    isWeb: ref.watch(platformCapabilitiesProvider).isWeb,
  );
});

/// DI — [DownloadColdigomMaterials].
///
/// As figuras dos gestos precisam do dicionário para resolver os `r2Key`s
/// (`prefetchGestureFigures` faz o mesmo na tela); sem dicionário, o
/// documento fica gravado e as figuras são buscadas na primeira abertura.
final downloadColdigomMaterialsProvider = Provider<DownloadColdigomMaterials>((ref) {
  final fetchAndStorePdf = ref.watch(fetchAndStorePdfProvider);
  return DownloadColdigomMaterials(
    catalog: ref.watch(coldigomCatalogLocalDatasourceProvider),
    pdfRepository: ref.watch(offlinePdfRepositoryProvider),
    pdfLocal: ref.watch(offlinePdfLocalDatasourceProvider),
    fetchPdf: (pdfId, r2Key) => fetchAndStorePdf(
      pdfId: pdfId,
      remotePath: '/$r2Key',
      persistentDownload: true,
    ),
    audioBytes: ref.watch(audioBytesDatasourceProvider),
    audioRepository: ref.watch(offlineAudioRepositoryProvider),
    chordRemote: ref.watch(chordContentDatasourceProvider),
    chordLocal: ref.watch(chordContentLocalDatasourceProvider),
    gestureRemote: ref.watch(gestureContentDatasourceProvider),
    gestureLocal: ref.watch(gestureContentLocalDatasourceProvider),
    figures: ref.watch(gestureFigureRepositoryProvider),
    figureKeysFor: (json) async {
      final dictionary = await ref.read(gestureDictionaryProvider.future);
      if (dictionary == null) return const {};
      final keys = <String>{};
      for (final flat in flattenGestureCards(parseGestureDocument(json))) {
        final entry = dictionary.resolve(flat.card.gestureId);
        if (entry == null) continue;
        keys.add(entry.image);
        final gif = entry.gif;
        if (gif != null) keys.add(gif);
      }
      return keys;
    },
    concurrency: OfflineConfig.coldigomDownloadConcurrency,
  );
});

/// DI — [RemoveColdigomDownloads].
final removeColdigomDownloadsProvider = Provider<RemoveColdigomDownloads>((ref) {
  return RemoveColdigomDownloads(
    pdfRepository: ref.watch(offlinePdfRepositoryProvider),
    audioRepository: ref.watch(offlineAudioRepositoryProvider),
  );
});
```

Confirme o caminho real de `flatten_gesture_cards.dart` (`lib/features/gestures/domain/utils/`) e o nome do campo do id do gesto em `FlatGestureCard` (`flat.card.gestureId` — como em `prefetchGestureFigures` de `gesture_providers.dart` linha 244).

Correr: `flutter test test/unit/features/offline/remove_coldigom_downloads_test.dart test/unit/features/offline/offline_coldigom_kind_selection_store_test.dart` → verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(offline): RemoveColdigomDownloads (áudio + PDFs Coldigom persistentes, O8), seleção local de kinds (O11) e DI do download

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 8: `offlineColdigomStatsProvider` + `materialAvailabilityMapProvider`

**Files:**
- Create: `lib/features/offline/presentation/providers/offline_coldigom_stats_provider.dart`
- Create: `lib/features/offline/presentation/providers/material_availability_map_provider.dart`
- Test: `test/unit/features/offline/offline_coldigom_stats_test.dart`
- Test: `test/unit/features/offline/material_availability_map_provider_test.dart`

**Interfaces:**
- Consumes: `coldigomCatalogLocalDatasourceProvider.findAllSync`, `coldigomCatalogHydrationProvider` (para re-derivar após sync), `coldigomDownloadTargetsFrom`, `offlineAvailabilityMapProvider`, `offlineIndexRevisionProvider`, `offlineAudioIndexRevisionProvider`, `offlineAudioLocalDatasourceProvider.findAllSync`, `chordContentLocalDatasourceProvider.read`, `gestureContentLocalDatasourceProvider.read`, `optionalIsarProvider`.
- Produces:
  - `class ColdigomKindStats { String kindId, kindName; int total, downloaded, bytesKnown, bytesEstimated; bool get hasEstimate; int get bytesTotal; }` e `class OfflineColdigomStats { Map<String, ColdigomKindStats> byKind; int get pendingBytes(Set<String> kindIds); }`.
  - `offlineColdigomStatsProvider` — `FutureProvider<OfflineColdigomStats>` (recalcula quando sobem as revisões de PDF/áudio, a hidratação do catálogo e `chordGestureCacheRevisionProvider`); computação em fatias de 300 praises com `await Future.delayed(Duration.zero)` (o padrão de `library_group_worker`; sem `compute` — a linha Isar não atravessa isolates e a soma cabe no event loop).
  - `chordGestureCacheRevisionProvider` (`NotifierProvider<…, int>`, `bump()`) — subido pelo download depois de gravar cifra/gestos (Task 9), porque os datasources de texto não têm callback.
  - `materialAvailabilityMapProvider` — `Provider<Map<String, PdfOfflineAvailability>>`: união de `offlineAvailabilityMapProvider` (PDF), índice de áudio (`persistentOffline`), cifras/gestos com conteúdo não vazio no cache (`persistentOffline`). Letra e YouTube não entram.

- [ ] **Step 1: Testes que falham**

`test/unit/features/offline/material_availability_map_provider_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/chord_content_cache.dart';
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/collections/gesture_document_cache.dart';
import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/offline/data/providers/offline_audio_providers.dart';
import 'package:coldigui/features/offline/data/providers/offline_repository_providers.dart';
import 'package:coldigui/features/offline/presentation/providers/material_availability_map_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('availability_');
    isar = Isar.open(
      schemas: [
        OfflinePdfIndexSchema,
        OfflineAudioIndexSchema,
        ChordContentCacheSchema,
        GestureDocumentCacheSchema,
        ColdigomPraiseCacheSchema,
      ],
      directory: tempDir.path,
      name: 'availability_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [isarInitializerProvider.overrideWith((ref) async => isar)],
    );
    addTearDown(container.dispose);
    await container.read(isarInitializerProvider.future);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('une PDF (LRU/persistente), áudio, cifra e gestos com conteúdo', () async {
    final pdfLru = encodePdfId('assets/praises/p/a.pdf');
    final pdfPersist = encodePdfId('assets/praises/p/b.pdf');
    final audio = encodePdfId('assets/praises/p/c.mp3');
    const chordKey = 'assets/praises/p/d.chord';
    const chordEmptyKey = 'assets/praises/p/e.chord';
    const gestKey = 'assets/praises/p/f.gestures';

    final pdfLocal = container.read(offlinePdfLocalDatasourceProvider);
    await pdfLocal.put(_pdf(pdfLru, persistent: false));
    await pdfLocal.put(_pdf(pdfPersist, persistent: true));
    await container.read(offlineAudioLocalDatasourceProvider).put(
      OfflineAudioIndex()
        ..audioId = audio
        ..r2Key = 'assets/praises/p/c.mp3'
        ..storageKey = '/x'
        ..fileSize = 1
        ..downloadedAt = DateTime(2026),
    );
    container.read(chordContentLocalDatasourceProvider).write(chordKey, '{t: x}');
    container.read(chordContentLocalDatasourceProvider).write(chordEmptyKey, '');
    container.read(gestureContentLocalDatasourceProvider).write(gestKey, '{}');
    container.read(chordGestureCacheRevisionProvider.notifier).bump();

    final map = container.read(materialAvailabilityMapProvider);

    expect(map[pdfLru], PdfOfflineAvailability.cachedLru);
    expect(map[pdfPersist], PdfOfflineAvailability.persistentOffline);
    expect(map[audio], PdfOfflineAvailability.persistentOffline);
    expect(map[encodePdfId(chordKey)], PdfOfflineAvailability.persistentOffline);
    expect(map.containsKey(encodePdfId(chordEmptyKey)), isFalse);
    expect(map[encodePdfId(gestKey)], PdfOfflineAvailability.persistentOffline);
  });

  test('re-deriva quando a revisão de áudio sobe', () async {
    final audio = encodePdfId('assets/praises/p/c.mp3');
    expect(container.read(materialAvailabilityMapProvider).containsKey(audio), isFalse);

    await container.read(offlineAudioLocalDatasourceProvider).put(
      OfflineAudioIndex()
        ..audioId = audio
        ..r2Key = 'x'
        ..storageKey = '/x'
        ..fileSize = 1
        ..downloadedAt = DateTime(2026),
    );

    expect(container.read(materialAvailabilityMapProvider)[audio], PdfOfflineAvailability.persistentOffline);
  });
}

OfflinePdfIndex _pdf(String id, {required bool persistent}) => OfflinePdfIndex()
  ..pdfId = id
  ..storagePath = '/x/$id'
  ..category = 'x'
  ..fileSize = 1
  ..downloadedAt = DateTime(2026)
  ..isPersistent = persistent;
```

`test/unit/features/offline/offline_coldigom_stats_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/collections/chord_content_cache.dart';
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/collections/gesture_document_cache.dart';
import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/offline/data/providers/offline_audio_providers.dart';
import 'package:coldigui/features/offline/data/providers/offline_repository_providers.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

ColdigomPraiseCache _row(String id, List<Map<String, Object?>> materials) => ColdigomPraiseCache()
  ..praiseId = id
  ..number = '001'
  ..name = 'x'
  ..author = ''
  ..rhythm = ''
  ..tonality = ''
  ..category = ''
  ..tags = const []
  ..lyrics = ''
  ..materialsJson = jsonEncode(materials)
  ..searchTokens = '';

Map<String, Object?> _m(String id, String kind, String type, {int? size}) => {
  'id': id, 'kind': kind, 'kindName': 'Kind $kind', 'type': type,
  'r2': 'assets/praises/x/$id.$type', if (size != null) 'size': size,
};

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stats_');
    isar = Isar.open(
      schemas: [
        OfflinePdfIndexSchema, OfflineAudioIndexSchema, ChordContentCacheSchema,
        GestureDocumentCacheSchema, ColdigomPraiseCacheSchema,
      ],
      directory: tempDir.path,
      name: 'stats_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [isarInitializerProvider.overrideWith((ref) async => isar)],
    );
    addTearDown(container.dispose);
    await container.read(isarInitializerProvider.future);
    await ColdigomCatalogLocalDatasource(isar).replaceAll([
      _row('p1', [_m('a', 'k-pdf', 'pdf', size: 1000), _m('b', 'k-mp3', 'mp3')]),
      _row('p2', [_m('c', 'k-pdf', 'pdf'), _m('yt', 'k-yt', 'youtube')]),
    ]);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('conta total/baixados e soma bytes conhecidos + estimados por kind', () async {
    await container.read(offlinePdfLocalDatasourceProvider).put(
      OfflinePdfIndex()
        ..pdfId = encodePdfId('assets/praises/x/a.pdf')
        ..storagePath = '/x'
        ..category = 'x'
        ..fileSize = 1000
        ..downloadedAt = DateTime(2026)
        ..isPersistent = true,
    );

    final stats = await container.read(offlineColdigomStatsProvider.future);

    final pdf = stats.byKind['k-pdf']!;
    expect(pdf.kindName, 'Kind k-pdf');
    expect(pdf.total, 2);
    expect(pdf.downloaded, 1);
    expect(pdf.bytesKnown, 1000);
    expect(pdf.bytesEstimated, 350 * 1024);
    expect(pdf.hasEstimate, isTrue);
    final mp3 = stats.byKind['k-mp3']!;
    expect(mp3.total, 1);
    expect(mp3.downloaded, 0);
    expect(mp3.bytesEstimated, 4 * 1024 * 1024);
    expect(stats.byKind.containsKey('k-yt'), isFalse);
    // Pendente = só o que falta baixar dos kinds pedidos.
    expect(stats.pendingBytes({'k-pdf', 'k-mp3'}), 350 * 1024 + 4 * 1024 * 1024);
  });
}
```

Correr os dois → falham.

- [ ] **Step 2: Mapa de disponibilidade**

`lib/features/offline/presentation/providers/material_availability_map_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../../pdf_opening/domain/entities/pdf_offline_availability.dart';
import '../../data/providers/offline_audio_providers.dart';
import 'offline_availability_map_provider.dart';
import 'offline_coldigom_stats_provider.dart' show chordGestureCacheRevisionProvider;

/// Disponibilidade local de **qualquer** material por id (spec §5.3).
///
/// União de: `offlineAvailabilityMapProvider` (PDF, LRU ou persistente),
/// índice de áudio (sempre `persistentOffline`), cifras e gestos com corpo
/// não vazio no cache Isar (`persistentOffline` — nunca são evictados). O
/// marcador negativo (corpo vazio, 404) **não** conta: o material não
/// existe, e o sheet mostra isso pelo caminho de hoje. Letra e YouTube não
/// entram (regras fixas no sheet, O14).
///
/// Re-derivado pelas revisões de PDF, áudio e cifra/gestos — uma leitura por
/// mudança, `select` por card, como o mapa de PDF (A5). Uma cifra aberta
/// on-demand (fora do download) só entra aqui na próxima revisão — o
/// `chordSongProvider` não sobe nenhuma; é o download em lote quem sobe.
final materialAvailabilityMapProvider =
    Provider<Map<String, PdfOfflineAvailability>>((ref) {
      final pdfs = ref.watch(offlineAvailabilityMapProvider);
      ref.watch(offlineAudioIndexRevisionProvider);
      ref.watch(chordGestureCacheRevisionProvider);
      final audio = ref.watch(offlineAudioLocalDatasourceProvider);
      final chords = ref.watch(chordContentLocalDatasourceProvider);
      final gestures = ref.watch(gestureContentLocalDatasourceProvider);

      final map = <String, PdfOfflineAvailability>{...pdfs};
      for (final entry in audio.findAllSync()) {
        map[entry.audioId] = PdfOfflineAvailability.persistentOffline;
      }
      for (final r2Key in chords.allKeysWithContent()) {
        map[encodePdfId(r2Key)] = PdfOfflineAvailability.persistentOffline;
      }
      for (final r2Key in gestures.allKeysWithContent()) {
        map[encodePdfId(r2Key)] = PdfOfflineAvailability.persistentOffline;
      }
      return Map.unmodifiable(map);
    });
```

Isto exige um método novo nos dois datasources de texto — acrescente a `ChordContentLocalDatasource` (depois de `write`) e, idêntico, a `GestureContentLocalDatasource`:

```dart
  /// `r2Key`s com corpo gravado (exclui o marcador negativo) — insumo do
  /// mapa de disponibilidade offline; vazio sem Isar.
  List<String> allKeysWithContent() {
    final isar = _isar;
    if (isar == null) return const [];
    try {
      return [
        for (final row in isar.chordContentCaches.where().findAll())
          if (row.content.isNotEmpty) row.r2Key,
      ];
    } on Object catch (error) {
      debugPrint('[cifras] listagem do cache falhou: $error');
      return const [];
    }
  }
```

(na versão de gestos: `isar.gestureDocumentCaches` e prefixo `[gestos]`.)

- [ ] **Step 3: Stats**

`lib/features/offline/presentation/providers/offline_coldigom_stats_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../data/providers/offline_audio_providers.dart';
import '../../data/providers/offline_repository_providers.dart';
import '../../domain/entities/coldigom_download_target.dart';

/// Revisão dos caches de cifra/gestos — os datasources de texto não têm
/// callback de escrita, então quem grava em lote (o download Coldigom) sobe
/// isto ao terminar, e o mapa de disponibilidade e as stats re-derivam.
class ChordGestureCacheRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final chordGestureCacheRevisionProvider =
    NotifierProvider<ChordGestureCacheRevisionNotifier, int>(
      ChordGestureCacheRevisionNotifier.new,
    );

/// Contagens e bytes de um kind Coldigom no `/offline` (§5.3/§5.4).
class ColdigomKindStats {
  const ColdigomKindStats({
    required this.kindId,
    required this.kindName,
    required this.total,
    required this.downloaded,
    required this.bytesKnown,
    required this.bytesEstimated,
    required this.pendingBytes,
  });

  final String kindId;
  final String kindName;
  final int total;
  final int downloaded;

  /// Soma dos `size` do dump (todos os alvos do kind).
  final int bytesKnown;

  /// Soma das médias por tipo dos alvos sem `size`.
  final int bytesEstimated;

  /// Bytes (conhecidos + estimados) só dos alvos **ainda não** baixados.
  final int pendingBytes;

  bool get hasEstimate => bytesEstimated > 0;
  int get bytesTotal => bytesKnown + bytesEstimated;
}

class OfflineColdigomStats {
  const OfflineColdigomStats(this.byKind);

  static const empty = OfflineColdigomStats({});

  /// Por `kindId`, só kinds com pelo menos um alvo baixável (O10).
  final Map<String, ColdigomKindStats> byKind;

  /// Estimativa do que «Baixar selecionados» vai transferir.
  int pendingBytes(Set<String> kindIds) => kindIds.fold(
    0,
    (sum, id) => sum + (byKind[id]?.pendingBytes ?? 0),
  );
}

/// Stats por kind a partir do catálogo local + índices (§5.3).
///
/// Recalcula quando sobem as revisões (PDF, áudio, cifra/gestos) ou o
/// catálogo é re-hidratado. Corre em fatias de
/// [OfflineConfig.coldigomHydrationChunkSize] praises cedendo o event loop
/// — o padrão do `library_group_worker` —, sem `compute`: as linhas Isar não
/// atravessam isolates e a soma cabe entre frames.
final offlineColdigomStatsProvider = FutureProvider<OfflineColdigomStats>((ref) async {
  ref.watch(offlineIndexRevisionProvider);
  ref.watch(offlineAudioIndexRevisionProvider);
  ref.watch(chordGestureCacheRevisionProvider);
  ref.watch(coldigomCatalogHydrationProvider);

  final rows = ref.read(coldigomCatalogLocalDatasourceProvider).findAllSync();
  if (rows.isEmpty) return OfflineColdigomStats.empty;

  final pdfs = ref.read(offlinePdfLocalDatasourceProvider).findAllSync();
  final present = <String>{
    for (final p in pdfs) if (p.isPersistent) p.pdfId,
    for (final a in ref.read(offlineAudioLocalDatasourceProvider).findAllSync()) a.audioId,
    for (final k in ref.read(chordContentLocalDatasourceProvider).allKeysWithContent())
      encodePdfId(k),
    for (final k in ref.read(gestureContentLocalDatasourceProvider).allKeysWithContent())
      encodePdfId(k),
  };

  final kindNames = <String, String>{};
  final total = <String, int>{};
  final downloaded = <String, int>{};
  final known = <String, int>{};
  final estimated = <String, int>{};
  final pending = <String, int>{};

  for (var i = 0; i < rows.length; i++) {
    for (final m in ColdigomPraiseCacheMapper.decodeMaterials(rows[i])) {
      final kindId = m.kindId;
      final r2Key = m.r2Key;
      if (kindId == null || r2Key == null || r2Key.isEmpty) continue;
      if (!isColdigomDownloadableType(m.type)) continue;
      if (materialKindOfRawType(m.type) == MaterialKind.unknown) continue;
      kindNames[kindId] = m.kindName;
      total.update(kindId, (v) => v + 1, ifAbsent: () => 1);
      final size = m.size;
      final bytes = size ?? OfflineConfig.coldigomEstimatedBytesByType[m.type.toLowerCase()] ?? 0;
      if (size != null) {
        known.update(kindId, (v) => v + size, ifAbsent: () => size);
      } else {
        estimated.update(kindId, (v) => v + bytes, ifAbsent: () => bytes);
      }
      if (present.contains(encodePdfId(r2Key))) {
        downloaded.update(kindId, (v) => v + 1, ifAbsent: () => 1);
      } else {
        pending.update(kindId, (v) => v + bytes, ifAbsent: () => bytes);
      }
    }
    if ((i + 1) % OfflineConfig.coldigomHydrationChunkSize == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  return OfflineColdigomStats({
    for (final kindId in total.keys)
      kindId: ColdigomKindStats(
        kindId: kindId,
        kindName: kindNames[kindId] ?? '',
        total: total[kindId]!,
        downloaded: downloaded[kindId] ?? 0,
        bytesKnown: known[kindId] ?? 0,
        bytesEstimated: estimated[kindId] ?? 0,
        pendingBytes: pending[kindId] ?? 0,
      ),
  });
});
```

Correr: `flutter test test/unit/features/offline/material_availability_map_provider_test.dart test/unit/features/offline/offline_coldigom_stats_test.dart` → verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(offline): stats Coldigom por kind e mapa de disponibilidade unificado (PDF + áudio + cifra + gestos)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 9: `offlineColdigomDownloadProvider` (lock, wakelock, pausa em background)

**Files:**
- Modify: `lib/features/offline/presentation/providers/offline_maintenance_lock_provider.dart` (enum linha 5)
- Create: `lib/features/offline/presentation/providers/offline_coldigom_download_provider.dart`
- Test: `test/unit/features/offline/offline_coldigom_download_provider_test.dart`

**Interfaces:**
- Consumes: `downloadColdigomMaterialsProvider`, `removeColdigomDownloadsProvider` (Task 7), `bulkDownloadWakelockProvider` (existente em `offline_bulk_download_provider.dart`), `offlineMaintenanceLockProvider`, `isarAvailableProvider`, `chordGestureCacheRevisionProvider` (Task 8), `AppFailure.from`, `StorageFailure`.
- Produces:
  - `OfflineMaintenanceOwner.coldigom`.
  - `enum OfflineColdigomDownloadStatus { idle, running, cancelling, done, failed }`; `class OfflineColdigomDownloadState { status; ColdigomDownloadProgress? progress; ColdigomDownloadResult? result; AppFailure? failure; bool get isActive; }`.
  - `offlineColdigomDownloadProvider` — `Notifier`: `Future<void> start(Set<String> kindIds)`, `void stop()`, `Future<void> pauseForBackground()` (= `stop()`; o resultado parcial fica e «Tentar de novo» re-executa, O12), `Future<RemoveColdigomDownloadsResult?> removeDownloads()` (lock `coldigom`, sem wakelock).

- [ ] **Step 1: Teste que falha**

`test/unit/features/offline/offline_coldigom_download_provider_test.dart`:

```dart
import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_coldigom_providers.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_progress.dart';
import 'package:coldigui/features/offline/domain/usecases/download_coldigom_materials.dart';
import 'package:coldigui/features/offline/domain/usecases/remove_coldigom_downloads.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_bulk_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wakelock implements BulkDownloadWakelock {
  var enabled = 0;
  var disabled = 0;
  @override
  Future<void> enable() async => enabled++;
  @override
  Future<void> disable() async => disabled++;
}

/// Use case de roteiro: emite progresso, espera o `gate` e devolve o resultado.
class _ScriptedDownload implements DownloadColdigomMaterials {
  _ScriptedDownload({this.gate, this.result, this.error});
  final Completer<void>? gate;
  final ColdigomDownloadResult? result;
  final Object? error;
  Set<String>? kindIds;
  CancelToken? token;

  @override
  Future<ColdigomDownloadResult> call({
    required Set<String> kindIds,
    CancelToken? cancelToken,
    void Function(ColdigomDownloadProgress)? onProgress,
  }) async {
    this.kindIds = kindIds;
    token = cancelToken;
    onProgress?.call(const ColdigomDownloadProgress(
      kindId: 'k', doneInKind: 1, totalInKind: 2, doneTotal: 1, total: 2, currentTitle: '001 · x',
    ));
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result ??
        ColdigomDownloadResult(
          done: 1, skipped: 0, failed: const [], bytes: 10,
          cancelled: cancelToken?.isCancelled ?? false,
        );
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Remove implements RemoveColdigomDownloads {
  var calls = 0;
  @override
  Future<RemoveColdigomDownloadsResult> call() async {
    calls++;
    return const RemoveColdigomDownloadsResult(removedPdfs: 2, removedAudios: 3);
  }
}

void main() {
  late _Wakelock wakelock;

  ProviderContainer container(_ScriptedDownload download, {bool isar = true, _Remove? remove}) {
    wakelock = _Wakelock();
    final c = ProviderContainer(
      overrides: [
        isarAvailableProvider.overrideWithValue(isar),
        downloadColdigomMaterialsProvider.overrideWithValue(download),
        removeColdigomDownloadsProvider.overrideWithValue(remove ?? _Remove()),
        bulkDownloadWakelockProvider.overrideWithValue(wakelock),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('start: lock + wakelock, progresso, done com resultado, revisão de cifra/gestos sobe', () async {
    final gate = Completer<void>();
    final download = _ScriptedDownload(gate: gate);
    final c = container(download);
    final notifier = c.read(offlineColdigomDownloadProvider.notifier);

    final future = notifier.start({'k'});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(offlineColdigomDownloadProvider).status, OfflineColdigomDownloadStatus.running);
    expect(c.read(offlineColdigomDownloadProvider).progress!.doneTotal, 1);
    expect(c.read(offlineMaintenanceLockProvider), OfflineMaintenanceOwner.coldigom);
    expect(wakelock.enabled, 1);

    gate.complete();
    await future;
    final state = c.read(offlineColdigomDownloadProvider);
    expect(state.status, OfflineColdigomDownloadStatus.done);
    expect(state.result!.done, 1);
    expect(download.kindIds, {'k'});
    expect(c.read(offlineMaintenanceLockProvider), isNull);
    expect(wakelock.disabled, 1);
    expect(c.read(chordGestureCacheRevisionProvider), 1);
  });

  test('stop cancela o token e o estado fica done com parcial cancelado', () async {
    final gate = Completer<void>();
    final download = _ScriptedDownload(gate: gate);
    final c = container(download);
    final notifier = c.read(offlineColdigomDownloadProvider.notifier);

    final future = notifier.start({'k'});
    await Future<void>.delayed(Duration.zero);
    notifier.stop();
    expect(c.read(offlineColdigomDownloadProvider).status, OfflineColdigomDownloadStatus.cancelling);
    expect(download.token!.isCancelled, isTrue);
    gate.complete();
    await future;

    expect(c.read(offlineColdigomDownloadProvider).status, OfflineColdigomDownloadStatus.done);
    expect(c.read(offlineColdigomDownloadProvider).result!.cancelled, isTrue);
  });

  test('sem Isar → failed sem tocar no use case; lock ocupado → não inicia', () async {
    final download = _ScriptedDownload();
    final c = container(download, isar: false);
    await c.read(offlineColdigomDownloadProvider.notifier).start({'k'});
    expect(c.read(offlineColdigomDownloadProvider).status, OfflineColdigomDownloadStatus.failed);
    expect(download.kindIds, isNull);

    final c2 = container(_ScriptedDownload());
    c2.read(offlineMaintenanceLockProvider.notifier).tryAcquire(OfflineMaintenanceOwner.bulk);
    await c2.read(offlineColdigomDownloadProvider.notifier).start({'k'});
    expect(c2.read(offlineColdigomDownloadProvider).status, OfflineColdigomDownloadStatus.idle);
  });

  test('erro inesperado → failed com AppFailure e lock/wakelock libertados', () async {
    final c = container(_ScriptedDownload(error: StateError('boom')));
    await c.read(offlineColdigomDownloadProvider.notifier).start({'k'});

    expect(c.read(offlineColdigomDownloadProvider).status, OfflineColdigomDownloadStatus.failed);
    expect(c.read(offlineColdigomDownloadProvider).failure, isNotNull);
    expect(c.read(offlineMaintenanceLockProvider), isNull);
    expect(wakelock.disabled, 1);
  });

  test('removeDownloads usa o lock e devolve o resultado', () async {
    final remove = _Remove();
    final c = container(_ScriptedDownload(), remove: remove);

    final result = await c.read(offlineColdigomDownloadProvider.notifier).removeDownloads();

    expect(result!.removedAudios, 3);
    expect(remove.calls, 1);
    expect(c.read(offlineMaintenanceLockProvider), isNull);
  });
}
```

Correr → falha.

- [ ] **Step 2: Dono do lock**

`offline_maintenance_lock_provider.dart` linha 5: `enum OfflineMaintenanceOwner { bulk, missing, clear, reconcile, coldigom }` e no doc-comment da classe: «… e o download/remoção Coldigom mexem no mesmo par índice+disco».

- [ ] **Step 3: Notifier**

`lib/features/offline/presentation/providers/offline_coldigom_download_provider.dart`:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/failures/app_failure.dart';
import '../../data/providers/offline_coldigom_providers.dart';
import '../../domain/entities/coldigom_download_progress.dart';
import '../../domain/usecases/remove_coldigom_downloads.dart';
import 'offline_bulk_download_provider.dart' show bulkDownloadWakelockProvider;
import 'offline_coldigom_stats_provider.dart';
import 'offline_maintenance_lock_provider.dart';

enum OfflineColdigomDownloadStatus { idle, running, cancelling, done, failed }

/// Estado do download Coldigom por kind na tela `/offline` (§5.4).
class OfflineColdigomDownloadState {
  const OfflineColdigomDownloadState({
    this.status = OfflineColdigomDownloadStatus.idle,
    this.progress,
    this.result,
    this.failure,
  });

  final OfflineColdigomDownloadStatus status;
  final ColdigomDownloadProgress? progress;

  /// Resultado da última execução (inclui o parcial de um cancelamento).
  final ColdigomDownloadResult? result;
  final AppFailure? failure;

  bool get isRunning => status == OfflineColdigomDownloadStatus.running;
  bool get isActive =>
      isRunning || status == OfflineColdigomDownloadStatus.cancelling;

  OfflineColdigomDownloadState copyWith({
    OfflineColdigomDownloadStatus? status,
    ColdigomDownloadProgress? progress,
    ColdigomDownloadResult? result,
    AppFailure? failure,
    bool clearProgress = false,
  }) {
    return OfflineColdigomDownloadState(
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      result: result ?? this.result,
      failure: failure ?? this.failure,
    );
  }
}

final offlineColdigomDownloadProvider =
    NotifierProvider<OfflineColdigomDownloadNotifier, OfflineColdigomDownloadState>(
      OfflineColdigomDownloadNotifier.new,
    );

/// Orquestra [DownloadColdigomMaterials] com lock de manutenção, wakelock e
/// cancelamento (§5.2). Bulk PLPCG e este são mutuamente exclusivos pelo
/// lock. Sem checkpoint (O12): parar guarda o parcial e «Tentar de novo»
/// simplesmente re-executa — o use case salta o que já está.
class OfflineColdigomDownloadNotifier extends Notifier<OfflineColdigomDownloadState> {
  CancelToken? _cancelToken;
  var _wakelockHeld = false;

  @override
  OfflineColdigomDownloadState build() {
    ref.onDispose(() {
      _cancelToken?.cancel();
      unawaited(_releaseWakelock());
    });
    return const OfflineColdigomDownloadState();
  }

  Future<void> start(Set<String> kindIds) async {
    if (state.isActive || kindIds.isEmpty) return;
    if (!ref.read(isarAvailableProvider)) {
      state = state.copyWith(
        status: OfflineColdigomDownloadStatus.failed,
        failure: const StorageFailure(StorageUnavailableException('offline.coldigom')),
      );
      return;
    }
    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    if (!lock.tryAcquire(OfflineMaintenanceOwner.coldigom)) return;

    try {
      _cancelToken = CancelToken();
      state = const OfflineColdigomDownloadState(status: OfflineColdigomDownloadStatus.running);
      await _acquireWakelock();

      final result = await ref.read(downloadColdigomMaterialsProvider).call(
        kindIds: kindIds,
        cancelToken: _cancelToken,
        onProgress: (progress) {
          if (!state.isActive) return;
          state = state.copyWith(progress: progress);
        },
      );
      state = OfflineColdigomDownloadState(
        status: OfflineColdigomDownloadStatus.done,
        result: result,
      );
    } on Object catch (error) {
      debugPrint('[offline] download coldigom falhou: $error');
      state = OfflineColdigomDownloadState(
        status: OfflineColdigomDownloadStatus.failed,
        failure: AppFailure.from(error),
      );
    } finally {
      await _releaseWakelock();
      lock.release(OfflineMaintenanceOwner.coldigom);
      // Cifras/gestos gravados em lote não avisam ninguém: sobe a revisão
      // para o mapa de disponibilidade e as stats re-derivarem.
      ref.read(chordGestureCacheRevisionProvider.notifier).bump();
    }
  }

  /// Pede paragem; o use case devolve o parcial e o estado vira `done`.
  void stop() {
    if (!state.isRunning) return;
    _cancelToken?.cancel();
    state = state.copyWith(status: OfflineColdigomDownloadStatus.cancelling);
  }

  /// iOS suspende o app em background: parar aqui evita um download «a
  /// meio» que só falharia (o parcial fica; retomar é re-executar, O12).
  void pauseForBackground() => stop();

  /// «Remover áudios e PDFs baixados do Coldigom»; `null` se o lock estiver
  /// ocupado ou não houver Isar.
  Future<RemoveColdigomDownloadsResult?> removeDownloads() async {
    if (state.isActive || !ref.read(isarAvailableProvider)) return null;
    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    if (!lock.tryAcquire(OfflineMaintenanceOwner.coldigom)) return null;
    try {
      return await ref.read(removeColdigomDownloadsProvider).call();
    } finally {
      lock.release(OfflineMaintenanceOwner.coldigom);
    }
  }

  Future<void> _acquireWakelock() async {
    if (_wakelockHeld) return;
    await ref.read(bulkDownloadWakelockProvider).enable();
    _wakelockHeld = true;
  }

  Future<void> _releaseWakelock() async {
    if (!_wakelockHeld) return;
    await ref.read(bulkDownloadWakelockProvider).disable();
    _wakelockHeld = false;
  }
}
```

Correr: `flutter test test/unit/features/offline/offline_coldigom_download_provider_test.dart test/unit/features/offline/offline_maintenance_lock_test.dart` → verdes.

- [ ] **Step 4: Commit**

```bash
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(offline): offlineColdigomDownloadProvider — lock de manutenção, wakelock, parar/retomar sem checkpoint

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 10: Secção Coldigom no `/offline` + l10n

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (fim do ficheiro)
- Create: `lib/features/offline/presentation/providers/offline_coldigom_kind_selection_provider.dart`
- Create: `lib/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart`
- Modify: `lib/features/offline/presentation/pages/offline_settings_screen.dart` (`didChangeAppLifecycleState` linhas 69–73; `_maintenanceBusy` linhas 75–80; `build` linhas 225–283)
- Test: `test/widget/features/offline/offline_settings_screen_coldigom_test.dart`

**Interfaces:**
- Consumes: `coldigomCatalogSyncProvider` (plano 1), `authStateProvider`, `favoriteMaterialKindRankProvider`, `offlineColdigomStatsProvider` (Task 8), `offlineColdigomKindSelectionStoreProvider` (Task 7), `offlineColdigomDownloadProvider` (Task 9), `offlineMaintenanceLockProvider`, `estimateFreeStorageBytes`, `formatCompactBytes`, `GoogleSignInButton`, `showConfirmDialog`, `failureMessage`.
- Produces:
  - `offlineColdigomKindSelectionProvider` — `NotifierProvider<OfflineColdigomKindSelectionNotifier, Set<String>>`: estado inicial = `store.read()` se `hasDecision`, senão vazio; `Set<String> effectiveSelection({required List<String> favoriteKindIds, required Set<String> availableKindIds})` devolve a pré-marcação (favoritos ∩ disponíveis) enquanto não há decisão (O11); `Future<void> toggle(String kindId, {required Set<String> currentEffective})` grava a decisão.
  - `class ColdigomOfflineSection extends ConsumerWidget { const ColdigomOfflineSection({required bool maintenanceBusy}); }`.
  - `String coldigomSizeLabel(int bytes, {required bool estimated})` → `'~1,2 MB'`/`'1,2 MB'`.
  - l10n: `offlineColdigomPlpcgSection`, `offlineColdigomSection`, `offlineColdigomCatalogStatus(count, ago)`, `offlineColdigomCatalogMissing`, `offlineColdigomAgoJustNow`, `offlineColdigomAgoMinutes(n)`, `offlineColdigomAgoHours(n)`, `offlineColdigomAgoDays(n)`, `offlineColdigomSignInPrompt`, `offlineColdigomFavoriteKinds`, `offlineColdigomNoFavorites`, `offlineColdigomOtherKinds`, `offlineColdigomKindSummary(count, size)`, `offlineColdigomDownloadSelected(size)`, `offlineColdigomStop`, `offlineColdigomProgress(kind, done, total)`, `offlineColdigomDone(count)`, `offlineColdigomFailures(count)`, `offlineColdigomRetry`, `offlineColdigomRemove`, `offlineColdigomRemoveNote`, `offlineColdigomRemoveConfirmTitle`, `offlineColdigomRemoved(pdfs, audios)`, `offlineColdigomSpaceWarning(size, free)`.

- [ ] **Step 1: l10n**

`app_pt.arb` (antes do `}` final):

```json
  "offlineColdigomPlpcgSection": "Acervo PLPCG (PDFs)",
  "offlineColdigomSection": "Coldigom por tipo de material",
  "offlineColdigomCatalogStatus": "Catálogo: {count} louvores · atualizado {ago}",
  "@offlineColdigomCatalogStatus": {
    "placeholders": {
      "count": { "type": "int" },
      "ago": { "type": "String" }
    }
  },
  "offlineColdigomCatalogMissing": "Ligue-se à internet para baixar o catálogo",
  "offlineColdigomAgoJustNow": "agora mesmo",
  "offlineColdigomAgoMinutes": "há {n} min",
  "@offlineColdigomAgoMinutes": { "placeholders": { "n": { "type": "int" } } },
  "offlineColdigomAgoHours": "há {n} h",
  "@offlineColdigomAgoHours": { "placeholders": { "n": { "type": "int" } } },
  "offlineColdigomAgoDays": "há {n} d",
  "@offlineColdigomAgoDays": { "placeholders": { "n": { "type": "int" } } },
  "offlineColdigomSignInPrompt": "Entre com Google para baixar os seus tipos favoritos",
  "offlineColdigomFavoriteKinds": "Seus tipos favoritos",
  "offlineColdigomNoFavorites": "Sem favoritos — escolha em Materiais favoritos ou abra «Outros tipos»",
  "offlineColdigomOtherKinds": "Outros tipos",
  "offlineColdigomKindSummary": "{count} materiais · {size}",
  "@offlineColdigomKindSummary": {
    "placeholders": {
      "count": { "type": "int" },
      "size": { "type": "String" }
    }
  },
  "offlineColdigomDownloadSelected": "Baixar selecionados ({size})",
  "@offlineColdigomDownloadSelected": { "placeholders": { "size": { "type": "String" } } },
  "offlineColdigomStop": "Parar",
  "offlineColdigomProgress": "{kind} · {done}/{total}",
  "@offlineColdigomProgress": {
    "placeholders": {
      "kind": { "type": "String" },
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "offlineColdigomDone": "{count, plural, =0{Nada novo para baixar} one{1 material baixado} other{{count} materiais baixados}}",
  "@offlineColdigomDone": { "placeholders": { "count": { "type": "int" } } },
  "offlineColdigomFailures": "{count, plural, one{1 não baixado} other{{count} não baixados}}",
  "@offlineColdigomFailures": { "placeholders": { "count": { "type": "int" } } },
  "offlineColdigomRetry": "Tentar de novo",
  "offlineColdigomRemove": "Remover áudios e PDFs baixados do Coldigom",
  "offlineColdigomRemoveNote": "Cifras, gestos e letras ficam no aparelho.",
  "offlineColdigomRemoveConfirmTitle": "Remover baixados do Coldigom?",
  "offlineColdigomRemoved": "{pdfs} PDFs e {audios} áudios removidos",
  "@offlineColdigomRemoved": {
    "placeholders": {
      "pdfs": { "type": "int" },
      "audios": { "type": "int" }
    }
  },
  "offlineColdigomSpaceWarning": "Estimativa de {size} acima do espaço livre ({free}) — o download pode parar a meio.",
  "@offlineColdigomSpaceWarning": {
    "placeholders": {
      "size": { "type": "String" },
      "free": { "type": "String" }
    }
  }
```

`app_en.arb` (mesmas chaves, sem os `@` de placeholders — o template é o pt):

```json
  "offlineColdigomPlpcgSection": "PLPCG collection (PDFs)",
  "offlineColdigomSection": "Coldigom by material type",
  "offlineColdigomCatalogStatus": "Catalog: {count} hymns · updated {ago}",
  "offlineColdigomCatalogMissing": "Connect to the internet to download the catalog",
  "offlineColdigomAgoJustNow": "just now",
  "offlineColdigomAgoMinutes": "{n} min ago",
  "offlineColdigomAgoHours": "{n} h ago",
  "offlineColdigomAgoDays": "{n} d ago",
  "offlineColdigomSignInPrompt": "Sign in with Google to download your favorite types",
  "offlineColdigomFavoriteKinds": "Your favorite types",
  "offlineColdigomNoFavorites": "No favorites — pick some in Favorite materials or open “Other types”",
  "offlineColdigomOtherKinds": "Other types",
  "offlineColdigomKindSummary": "{count} materials · {size}",
  "offlineColdigomDownloadSelected": "Download selected ({size})",
  "offlineColdigomStop": "Stop",
  "offlineColdigomProgress": "{kind} · {done}/{total}",
  "offlineColdigomDone": "{count, plural, =0{Nothing new to download} one{1 material downloaded} other{{count} materials downloaded}}",
  "offlineColdigomFailures": "{count, plural, one{1 not downloaded} other{{count} not downloaded}}",
  "offlineColdigomRetry": "Try again",
  "offlineColdigomRemove": "Remove downloaded Coldigom audio and PDFs",
  "offlineColdigomRemoveNote": "Chords, gestures and lyrics stay on the device.",
  "offlineColdigomRemoveConfirmTitle": "Remove Coldigom downloads?",
  "offlineColdigomRemoved": "{pdfs} PDFs and {audios} audios removed",
  "offlineColdigomSpaceWarning": "Estimated {size} exceeds free space ({free}) — the download may stop midway."
```

Correr `flutter gen-l10n`.

- [ ] **Step 2: Teste que falha**

`test/widget/features/offline/offline_settings_screen_coldigom_test.dart`:

```dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_progress.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(googleSub: 's', sessionToken: 't');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _FixedSync extends ColdigomCatalogSyncNotifier {
  _FixedSync(this.fixed);
  final ColdigomCatalogSyncState fixed;
  @override
  ColdigomCatalogSyncState build() => fixed;
  var syncCalls = 0;
  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    syncCalls++;
    return const ColdigomCatalogSyncNoop();
  }
}

class _FixedDownload extends OfflineColdigomDownloadNotifier {
  _FixedDownload(this.fixed);
  final OfflineColdigomDownloadState fixed;
  final started = <Set<String>>[];
  var stops = 0;
  var removes = 0;
  @override
  OfflineColdigomDownloadState build() => fixed;
  @override
  Future<void> start(Set<String> kindIds) async => started.add(kindIds);
  @override
  void stop() => stops++;
  @override
  Future<RemoveColdigomDownloadsResult?> removeDownloads() async {
    removes++;
    return const RemoveColdigomDownloadsResult(removedPdfs: 1, removedAudios: 2);
  }
}

class _BusyLock extends OfflineMaintenanceLock {
  @override
  OfflineMaintenanceOwner? build() => OfflineMaintenanceOwner.bulk;
}

const _stats = OfflineColdigomStats({
  'k-grade': ColdigomKindStats(kindId: 'k-grade', kindName: 'Grade', total: 10, downloaded: 4, bytesKnown: 0, bytesEstimated: 10 * 350 * 1024, pendingBytes: 6 * 350 * 1024),
  'k-play': ColdigomKindStats(kindId: 'k-play', kindName: 'Playback', total: 5, downloaded: 0, bytesKnown: 0, bytesEstimated: 5 * 4 * 1024 * 1024, pendingBytes: 5 * 4 * 1024 * 1024),
  'k-cifra': ColdigomKindStats(kindId: 'k-cifra', kindName: 'Cifra', total: 3, downloaded: 3, bytesKnown: 0, bytesEstimated: 3 * 1024, pendingBytes: 0),
});

late SharedPreferences _prefs;

Future<({_FixedSync sync, _FixedDownload download})> _pump(
  WidgetTester tester, {
  bool loggedIn = true,
  ColdigomCatalogSyncState syncState = const ColdigomCatalogSyncState(count: 1690),
  OfflineColdigomDownloadState downloadState = const OfflineColdigomDownloadState(),
  Map<String, int> rank = const {'k-grade': 0, 'k-play': 1},
  List<Override> extra = const [],
}) async {
  final sync = _FixedSync(syncState);
  final download = _FixedDownload(downloadState);
  await pumpApp(
    tester,
    const SingleChildScrollView(child: ColdigomOfflineSection(maintenanceBusy: false)),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      authStateProvider.overrideWith(loggedIn ? _LoggedIn.new : _LoggedOut.new),
      favoriteMaterialKindRankProvider.overrideWithValue(rank),
      offlineColdigomStatsProvider.overrideWith((ref) async => _stats),
      coldigomCatalogSyncProvider.overrideWith(() => sync),
      offlineColdigomDownloadProvider.overrideWith(() => download),
      ...extra,
    ],
  );
  await tester.pumpAndSettle();
  return (sync: sync, download: download);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('deslogado: convite + botão Google; sem lista de kinds', (tester) async {
    await _pump(tester, loggedIn: false);

    expect(find.text('Entre com Google para baixar os seus tipos favoritos'), findsOneWidget);
    expect(find.byType(GoogleSignInButton), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('linha do catálogo com contagem e botão Atualizar; sem catálogo mostra o aviso', (tester) async {
    final handles = await _pump(tester);
    expect(find.textContaining('Catálogo: 1690 louvores'), findsOneWidget);
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();
    expect(handles.sync.syncCalls, 1);

    await _pump(tester, syncState: const ColdigomCatalogSyncState(count: 0));
    expect(find.text('Ligue-se à internet para baixar o catálogo'), findsOneWidget);
  });

  testWidgets('logado: favoritos pré-marcados na ordem do rank, «Outros tipos» fechado', (tester) async {
    await _pump(tester);

    final tiles = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(tiles.map((t) => (t.title as Text).data), ['Grade', 'Playback']);
    expect(tiles.every((t) => t.value == true), isTrue);
    expect(find.text('Outros tipos'), findsOneWidget);
    expect(find.text('Cifra'), findsNothing);
    expect(find.textContaining('10 materiais · ~'), findsOneWidget);
    expect(find.textContaining('Baixar selecionados (~'), findsOneWidget);

    await tester.tap(find.text('Outros tipos'));
    await tester.pumpAndSettle();
    expect(find.text('Cifra'), findsOneWidget);
  });

  testWidgets('desmarcar grava a decisão local (O11) e o botão inicia só com os marcados', (tester) async {
    final handles = await _pump(tester);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Playback'));
    await tester.pumpAndSettle();
    expect(_prefs.getString('offlineColdigomKindIds'), '["k-grade"]');

    await tester.tap(find.textContaining('Baixar selecionados'));
    await tester.pumpAndSettle();
    expect(handles.download.started.single, {'k-grade'});
  });

  testWidgets('lock ocupado por outro dono desabilita os botões', (tester) async {
    await _pump(tester, extra: [offlineMaintenanceLockProvider.overrideWith(_BusyLock.new)]);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(find.textContaining('Baixar selecionados (~'), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets('em execução mostra progresso e Parar; concluído com falhas mostra Tentar de novo', (tester) async {
    final running = await _pump(
      tester,
      downloadState: const OfflineColdigomDownloadState(
        status: OfflineColdigomDownloadStatus.running,
        progress: ColdigomDownloadProgress(
          kindId: 'k-grade', doneInKind: 3, totalInKind: 10, doneTotal: 120, total: 1690, currentTitle: '001 · x',
        ),
      ),
    );
    expect(find.text('Grade · 3/10'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    expect(running.download.stops, 1);

    final done = await _pump(
      tester,
      downloadState: OfflineColdigomDownloadState(
        status: OfflineColdigomDownloadStatus.done,
        result: ColdigomDownloadResult(
          done: 8, skipped: 2, bytes: 1, failed: [ColdigomDownloadFailure(materialId: 'x', cause: StateError('x'))],
        ),
      ),
    );
    expect(find.text('1 não baixado'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(done.download.started, hasLength(1));
  });

  testWidgets('remover pede confirmação e mostra o resultado', (tester) async {
    final handles = await _pump(tester);

    await tester.tap(find.text('Remover áudios e PDFs baixados do Coldigom'));
    await tester.pumpAndSettle();
    expect(find.text('Remover baixados do Coldigom?'), findsOneWidget);
    expect(find.text('Cifras, gestos e letras ficam no aparelho.'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(handles.download.removes, 1);
    expect(find.text('1 PDFs e 2 áudios removidos'), findsOneWidget);
  });
}
```

(`'Confirmar'` é o rótulo literal do botão positivo de `showConfirmDialog` em `lib/core/widgets/confirm_dialog.dart`.)

Correr → falha.

- [ ] **Step 3: Provider de seleção**

`lib/features/offline/presentation/providers/offline_coldigom_kind_selection_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/offline_coldigom_providers.dart';

/// Kinds marcados para download (O11).
///
/// Enquanto o utilizador nunca decidiu, o estado é vazio e a UI mostra a
/// pré-marcação ([effectiveSelection]: favoritos ∩ kinds com material
/// baixável). O primeiro toque grava a decisão inteira em prefs — a partir
/// daí os favoritos deixam de influenciar.
final offlineColdigomKindSelectionProvider =
    NotifierProvider<OfflineColdigomKindSelectionNotifier, Set<String>>(
      OfflineColdigomKindSelectionNotifier.new,
    );

class OfflineColdigomKindSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final store = ref.read(offlineColdigomKindSelectionStoreProvider);
    return store.hasDecision ? store.read() : const {};
  }

  bool get hasDecision =>
      ref.read(offlineColdigomKindSelectionStoreProvider).hasDecision;

  Set<String> effectiveSelection({
    required List<String> favoriteKindIds,
    required Set<String> availableKindIds,
  }) {
    if (hasDecision) return state;
    return {for (final id in favoriteKindIds) if (availableKindIds.contains(id)) id};
  }

  /// [currentEffective] é o que a UI mostrava (pré-marcação ou decisão): o
  /// primeiro toque transforma a pré-marcação em decisão gravada.
  Future<void> toggle(String kindId, {required Set<String> currentEffective}) async {
    final next = {...currentEffective};
    if (!next.remove(kindId)) next.add(kindId);
    state = next;
    await ref.read(offlineColdigomKindSelectionStoreProvider).write(next);
  }
}
```

- [ ] **Step 4: Secção**

`lib/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/failure_message.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/utils/byte_format.dart';
import '../../../../../core/widgets/confirm_dialog.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../../auth/presentation/widgets/google_sign_in_button.dart';
import '../../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../../data/utils/storage_quota_estimator.dart';
import '../../providers/offline_coldigom_download_provider.dart';
import '../../providers/offline_coldigom_kind_selection_provider.dart';
import '../../providers/offline_coldigom_stats_provider.dart';
import '../../providers/offline_maintenance_lock_provider.dart';

/// `~1,2 MB` quando há estimativa (O13), `1,2 MB` quando tudo é conhecido.
String coldigomSizeLabel(int bytes, {required bool estimated}) =>
    '${estimated ? '~' : ''}${formatCompactBytes(bytes)}';

/// Secção «Coldigom por tipo de material» do `/offline` (spec §5.4).
class ColdigomOfflineSection extends ConsumerWidget {
  const ColdigomOfflineSection({required this.maintenanceBusy, super.key});

  /// Bulk/reconcile/limpeza PLPCG em curso — desabilita tudo aqui também.
  final bool maintenanceBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;
    final sync = ref.watch(coldigomCatalogSyncProvider);
    final lockOwner = ref.watch(offlineMaintenanceLockProvider);
    final download = ref.watch(offlineColdigomDownloadProvider);
    // O lock nosso não nos desabilita: é o «Parar» que fica ativo.
    final busy = maintenanceBusy ||
        (lockOwner != null && lockOwner != OfflineMaintenanceOwner.coldigom);

    ref.listen(offlineColdigomDownloadProvider, (previous, next) {
      if (next.failure != null && next.failure != previous?.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, next.failure!))),
        );
      }
      if (next.status == OfflineColdigomDownloadStatus.done &&
          previous?.status != next.status &&
          next.result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offlineColdigomDone(next.result!.done))),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogStatusLine(sync: sync, l10n: l10n, busy: busy),
        const SizedBox(height: 12),
        if (user == null)
          _SignInCard(l10n: l10n)
        else
          _KindsBody(l10n: l10n, busy: busy, download: download),
      ],
    );
  }
}

class _CatalogStatusLine extends ConsumerWidget {
  const _CatalogStatusLine({required this.sync, required this.l10n, required this.busy});

  final ColdigomCatalogSyncState sync;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = sync.count == 0
        ? l10n.offlineColdigomCatalogMissing
        : l10n.offlineColdigomCatalogStatus(sync.count, _ago(sync.lastSyncedAt));
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(color: AppColors.title.withValues(alpha: 0.75)),
          ),
        ),
        if (sync.isSyncing)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        else
          TextButton.icon(
            onPressed: busy
                ? null
                : () => unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync()),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.offlineRefreshStats),
          ),
      ],
    );
  }
}

/// Deslogado (O9): a mesma chamada da tela de favoritos (D10).
class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          l10n.offlineColdigomSignInPrompt,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.title),
        ),
        const SizedBox(height: 12),
        const GoogleSignInButton(),
      ],
    );
  }
}

class _KindsBody extends ConsumerWidget {
  const _KindsBody({required this.l10n, required this.busy, required this.download});

  final AppLocalizations l10n;
  final bool busy;
  final OfflineColdigomDownloadState download;

  Future<void> _start(BuildContext context, WidgetRef ref, Set<String> kindIds, int bytes, bool estimated) async {
    // Aviso de espaço (O13): informa, não bloqueia — o download para limpo
    // em `InsufficientDiskSpaceException` se o navegador negar.
    final free = await estimateFreeStorageBytes();
    if (free != null && bytes > free && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.offlineColdigomSpaceWarning(
              coldigomSizeLabel(bytes, estimated: estimated),
              formatCompactBytes(free),
            ),
          ),
        ),
      );
    }
    await ref.read(offlineColdigomDownloadProvider.notifier).start(kindIds);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.offlineColdigomRemoveConfirmTitle,
      message: l10n.offlineColdigomRemoveNote,
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(offlineColdigomDownloadProvider.notifier).removeDownloads();
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.offlineColdigomRemoved(result.removedPdfs, result.removedAudios))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(offlineColdigomStatsProvider).value ?? OfflineColdigomStats.empty;
    final rank = ref.watch(favoriteMaterialKindRankProvider);
    final favoriteIds = rank.keys.toList()..sort((a, b) => rank[a]!.compareTo(rank[b]!));
    final favorites = [for (final id in favoriteIds) if (stats.byKind.containsKey(id)) stats.byKind[id]!];
    final others = [for (final s in stats.byKind.values) if (!rank.containsKey(s.kindId)) s]
      ..sort((a, b) => a.kindName.toLowerCase().compareTo(b.kindName.toLowerCase()));

    ref.watch(offlineColdigomKindSelectionProvider);
    final selection = ref.read(offlineColdigomKindSelectionProvider.notifier).effectiveSelection(
      favoriteKindIds: favoriteIds,
      availableKindIds: stats.byKind.keys.toSet(),
    );
    final pendingBytes = stats.pendingBytes(selection);
    final estimated = selection.any((id) => stats.byKind[id]?.hasEstimate ?? false);

    Widget tile(ColdigomKindStats kind) => _KindTile(
      kind: kind,
      l10n: l10n,
      checked: selection.contains(kind.kindId),
      enabled: !busy && !download.isActive,
      onChanged: () => unawaited(
        ref
            .read(offlineColdigomKindSelectionProvider.notifier)
            .toggle(kind.kindId, currentEffective: selection),
      ),
    );

    final result = download.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(l10n.offlineColdigomFavoriteKinds),
        if (favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(l10n.offlineColdigomNoFavorites, style: AppTypography.hint()),
          )
        else
          for (final kind in favorites) tile(kind),
        if (others.isNotEmpty)
          ExpansionTile(
            title: Text(l10n.offlineColdigomOtherKinds, style: AppTypography.label),
            tilePadding: EdgeInsets.zero,
            children: [for (final kind in others) tile(kind)],
          ),
        const SizedBox(height: 12),
        if (download.isActive && download.progress != null) ...[
          Text(
            l10n.offlineColdigomProgress(
              stats.byKind[download.progress!.kindId]?.kindName ?? '',
              download.progress!.doneInKind,
              download.progress!.totalInKind,
            ),
            style: AppTypography.body.copyWith(color: AppColors.title),
          ),
          Text(download.progress!.currentTitle, style: AppTypography.hint()),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: download.progress!.total == 0
                ? null
                : download.progress!.doneTotal / download.progress!.total,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy || download.isActive || selection.isEmpty
                    ? null
                    : () => unawaited(_start(context, ref, selection, pendingBytes, estimated)),
                child: Text(
                  l10n.offlineColdigomDownloadSelected(
                    coldigomSizeLabel(pendingBytes, estimated: estimated),
                  ),
                ),
              ),
            ),
            if (download.isActive) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: download.isRunning
                    ? ref.read(offlineColdigomDownloadProvider.notifier).stop
                    : null,
                child: Text(l10n.offlineColdigomStop),
              ),
            ],
          ],
        ),
        if (!download.isActive && result != null && result.hasFailures) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.offlineColdigomFailures(result.failed.length), style: AppTypography.hint()),
              TextButton(
                onPressed: busy || selection.isEmpty
                    ? null
                    : () => unawaited(_start(context, ref, selection, pendingBytes, estimated)),
                child: Text(l10n.offlineColdigomRetry),
              ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: busy || download.isActive ? null : () => unawaited(_remove(context, ref)),
            style: TextButton.styleFrom(foregroundColor: AppColors.title),
            child: Text(l10n.offlineColdigomRemove),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Text(
      text,
      style: AppTypography.label.copyWith(color: AppColors.title, fontWeight: FontWeight.w600),
    ),
  );
}

/// Uma linha por kind: nome, «N materiais · ~X MB», barra fina baixados/total.
class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.l10n,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final ColdigomKindStats kind;
  final AppLocalizations l10n;
  final bool checked;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      enabled: enabled,
      onChanged: (_) => onChanged(),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(kind.kindName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.offlineColdigomKindSummary(
              kind.total,
              coldigomSizeLabel(kind.bytesTotal, estimated: kind.hasEstimate),
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            minHeight: 2,
            value: kind.total == 0 ? 0 : kind.downloaded / kind.total,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Ecrã com duas secções**

Em `offline_settings_screen.dart`:
1. `didChangeAppLifecycleState`: acrescentar `ref.read(offlineColdigomDownloadProvider.notifier).pauseForBackground();` ao lado do `pauseForBackground()` do bulk.
2. `_maintenanceBusy`: incluir `|| ref.watch(offlineColdigomDownloadProvider).isActive`.
3. `build`: o `GoldenTaggedContainer` existente passa a `label: l10n.offlineColdigomPlpcgSection` (a chave `offlineStatsTitle` continua a existir para os testes antigos — troque os `expect(find.text('PDFs armazenados'))` de `offline_settings_screen_test.dart` para `find.text('Acervo PLPCG (PDFs)')`), e logo a seguir, dentro do `ListView`:

```dart
          const SizedBox(height: 16),
          GoldenTaggedContainer(
            label: l10n.offlineColdigomSection,
            child: ColdigomOfflineSection(maintenanceBusy: _maintenanceBusy),
          ),
```

(imports: `../providers/offline_coldigom_download_provider.dart`, `offline_settings_widgets/coldigom_section.dart`.) O `_maintenanceBusy` que a secção recebe deve **excluir** o próprio download Coldigom (senão «Parar» fica desabilitado): passe `maintenanceBusy: bulk.isActive || reconcile.isRunning || cacheStatus.isRefreshing` calculado num getter separado `_plpcgMaintenanceBusy`, e mantenha `_maintenanceBusy` (com o Coldigom) para os botões PLPCG.

Os testes antigos de `offline_settings_screen_test.dart` passam a precisar de overrides para a secção nova: acrescente ao `_offlineTestApp` daquele ficheiro `sharedPreferencesProvider.overrideWithValue(prefs)` (com `SharedPreferences.setMockInitialValues({})` num `setUp`), `authStateProvider.overrideWith(_LoggedOut.new)` (classe copiada do teste novo), `coldigomCatalogSyncProvider.overrideWith(() => _FixedSync(const ColdigomCatalogSyncState()))`, e `offlineColdigomStatsProvider.overrideWith((ref) async => OfflineColdigomStats.empty)`.

Correr: `flutter test test/widget/features/offline` → verdes.

- [ ] **Step 6: Commit**

```bash
flutter gen-l10n
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(offline): secção Coldigom no /offline — catálogo, favoritos pré-marcados, outros tipos, baixar/parar, remover

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 11: Sheet desabilitado offline, badge do card e empty state da Home

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart` (`_materialTile` linhas 175–216; `build` linhas 219–300)
- Modify: `lib/features/catalog/presentation/widgets/louvor_group_card.dart` (linhas 327–335)
- Modify: `lib/features/catalog/presentation/widgets/home_empty_state.dart` (linhas 203–205)
- Test: `test/widget/features/catalog/material_sheet_offline_test.dart`
- Test (existente, acrescentar caso): `test/widget/features/catalog/louvor_group_card_offline_badge_test.dart`
- Test (existente, acrescentar caso): `test/widget/features/catalog/home_empty_state_test.dart`

**Interfaces:**
- Consumes: `connectivityStreamProvider`, `materialAvailabilityMapProvider` (Task 8), `coldigomSearchIndexProvider` (plano 1), `LyricsMaterial`, `YoutubeMaterialRef`.
- Produces:
  - l10n: `materialNotDownloadedOffline` («Não baixado · sem ligação»), `materialNeedsConnection` («Precisa de ligação»), `materialSheetOfflineBanner` («Sem ligação · só o que está no aparelho abre»).
  - `_materialTile({…, bool enabled = true})` — `ListTile(enabled:)`; `subtitle` já existe. Regras O14 em `_MaterialSheetState._availabilityFor(material)`.
  - Card: `offlineAvailability` = melhor disponibilidade entre **todos** os materiais do grupo (`persistentOffline` > `cachedLru` > `notAvailable`).
  - Home: «Coldigom offline» só quando `remoteFailed && isOffline && coldigomSearchIndexProvider.isEmpty`.

- [ ] **Step 1: l10n**

`app_pt.arb`:

```json
  "materialNotDownloadedOffline": "Não baixado · sem ligação",
  "materialNeedsConnection": "Precisa de ligação",
  "materialSheetOfflineBanner": "Sem ligação · só o que está no aparelho abre"
```

`app_en.arb`:

```json
  "materialNotDownloadedOffline": "Not downloaded · offline",
  "materialNeedsConnection": "Needs a connection",
  "materialSheetOfflineBanner": "Offline · only what is on the device opens"
```

`flutter gen-l10n`.

- [ ] **Step 2: Teste do sheet que falha**

`test/widget/features/catalog/material_sheet_offline_test.dart` — reutilize o `_pumpSheet` de `material_sheet_lyrics_test.dart` (plano 1, Task 11) copiando-o para este ficheiro com um parâmetro `overrides` extra:

```dart
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/offline/presentation/providers/material_availability_map_provider.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

final _pdfDownloaded = encodePdfId('assets/praises/p1/a.pdf');
final _pdfMissing = encodePdfId('assets/praises/p1/b.pdf');
final _audioId = encodePdfId('assets/praises/p1/c.mp3');

Louvor _pdf(String id, String categoria) => Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '692',
  categoria: categoria,
  classificacao: 'Básico',
  pdf: '$id.pdf',
  pdfId: id,
  groupId: 'p1',
  source: LouvorDataSource.coldigom,
);

final _track = AudioTrack(
  audioId: _audioId,
  r2Key: 'assets/praises/p1/c.mp3',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'p1',
  categoria: 'Playback',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

const _youtube = YoutubeMaterial(
  id: 'yt1',
  url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'p1',
  categoria: 'Vídeo',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

const _lyrics = LyricsMaterial(praiseId: 'p1', nome: 'Comigo habita', numero: '692', text: 't');

class _OpenSpy extends OpenMaterial {
  final opened = <CatalogMaterial>[];
  @override
  Future<void> open(BuildContext context, WidgetRef ref, CatalogMaterial material, {List<AudioTrack>? audioQueue}) async {
    opened.add(material);
  }
}

LouvorGroup _group() => LouvorGroup.fromLouvores(
  [_pdf(_pdfDownloaded, 'Grade'), _pdf(_pdfMissing, 'Partitura')],
  audioTracks: [_track],
  youtubeMaterials: const [_youtube],
  lyricsByGroupId: const {'p1': _lyrics},
).single;

Future<_OpenSpy> _pumpSheet(WidgetTester tester, {required bool online}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final spy = _OpenSpy();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        activeEntriesProvider.overrideWithValue(const []),
        openMaterialProvider.overrideWithValue(spy),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
        materialAvailabilityMapProvider.overrideWithValue({
          _pdfDownloaded: PdfOfflineAvailability.persistentOffline,
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMaterialSheet(context, ref, _group()),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return spy;
}

ListTile _tile(WidgetTester tester, String title) =>
    tester.widget<ListTile>(find.widgetWithText(ListTile, title));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offline: baixado ativo, não baixado desabilitado com subtítulo, + continua ativo', (tester) async {
    final spy = await _pumpSheet(tester, online: false);

    expect(find.text('Sem ligação · só o que está no aparelho abre'), findsOneWidget);
    expect(_tile(tester, 'Grade').enabled, isTrue);
    expect(_tile(tester, 'Partitura').enabled, isFalse);
    expect(find.text('Não baixado · sem ligação'), findsOneWidget);
    expect(
      find.descendant(of: find.widgetWithText(ListTile, 'Partitura'), matching: find.byType(MaterialAddTrailing)),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ListTile, 'Partitura'));
    await tester.pumpAndSettle();
    expect(spy.opened, isEmpty);
  });

  testWidgets('offline: áudio não baixado desabilitado; YouTube «Precisa de ligação»; letra ativa', (tester) async {
    await _pumpSheet(tester, online: false);

    await _openTab(tester, 'Áudio');
    expect(_tile(tester, 'Playback').enabled, isFalse);

    await _openTab(tester, 'YouTube');
    expect(_tile(tester, 'Vídeo').enabled, isFalse);
    expect(find.text('Precisa de ligação'), findsOneWidget);

    await _openTab(tester, 'Letra');
    expect(_tile(tester, 'Letra').enabled, isTrue);
  });

  testWidgets('online: tudo ativo e sem banner', (tester) async {
    await _pumpSheet(tester, online: true);

    expect(find.text('Sem ligação · só o que está no aparelho abre'), findsNothing);
    expect(_tile(tester, 'Partitura').enabled, isTrue);
    expect(find.text('Não baixado · sem ligação'), findsNothing);
  });
}
```

(Os rótulos das abas — `'Áudio'`, `'YouTube'`, `'Letra'` — são `audioMaterialSection`/`youtubeMaterialSection`/`lyricsTab` em `app_pt.arb`; confirme o texto exato de `audioMaterialSection` e `youtubeMaterialSection` no ARB e ajuste se diferirem.)

Correr → falha.

- [ ] **Step 3: Sheet**

Em `material_sheet.dart`:

1. Imports: `../../../../core/network/connectivity_stream_provider.dart`, `../../../offline/presentation/providers/material_availability_map_provider.dart`, `../../../pdf_opening/domain/entities/pdf_offline_availability.dart`.
2. `_materialTile`: parâmetro `bool enabled = true,` e `ListTile(enabled: enabled, …)`. O `trailing` (`MaterialAddTrailing`) não depende de `enabled` — `+`/`×` continuam ativos (O14).
3. Método novo no `_MaterialSheetState`:

```dart
  /// O14: sem rede, só o que está no aparelho abre. Letra nunca desabilita
  /// (vive no Isar); YouTube precisa de rede sempre; o resto consulta o mapa
  /// de disponibilidade. Online nada muda — e se a deteção de rede errar,
  /// o tile fica ativo e o erro de abertura já existente aparece.
  ({bool enabled, String? subtitle}) _availabilityFor(
    CatalogMaterial material, {
    required bool online,
    required Map<String, PdfOfflineAvailability> availability,
    required AppLocalizations l10n,
  }) {
    if (online) return (enabled: true, subtitle: null);
    return switch (material) {
      LyricsMaterial() => (enabled: true, subtitle: null),
      YoutubeMaterialRef() => (
        enabled: false,
        subtitle: l10n.materialNeedsConnection,
      ),
      PdfMaterial() || ChordMaterialRef() || GestureMaterialRef() || AudioMaterial() =>
        availability.containsKey(material.id)
            ? (enabled: true, subtitle: null)
            : (enabled: false, subtitle: l10n.materialNotDownloadedOffline),
    };
  }
```

4. No `build`, logo depois de `final rank = …`:

```dart
    final online = ref.watch(connectivityStreamProvider).value ?? true;
    final availability = ref.watch(materialAvailabilityMapProvider);
```

e em **cada** chamada a `_materialTile` (PDF em `_pdfTiles`, cifras em `_chordTiles`, gestos, áudio, YouTube, letra) passar a disponibilidade. Para não repetir o cálculo em seis sítios, troque as chamadas para um helper local `_tileFor(material, {icon, iconColor, subtitle})` definido no `build` (closure) que faz:

```dart
    Widget tileFor(
      CatalogMaterial material, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    }) {
      final state = _availabilityFor(
        material,
        online: online,
        availability: availability,
        l10n: l10n,
      );
      return _materialTile(
        material: material,
        icon: icon,
        iconColor: iconColor,
        activeMaterialIds: activeMaterialIds,
        l10n: l10n,
        enabled: state.enabled,
        // O subtítulo de indisponibilidade ganha do autor do áudio: é a
        // informação acionável.
        subtitle: state.subtitle ?? subtitle,
      );
    }
```

`_pdfTiles` e `_chordTiles` passam a receber `tileFor` como parâmetro (`Widget Function(CatalogMaterial, {required Color iconColor, IconData? icon, String? subtitle}) tileFor`) em vez de chamarem `_materialTile`.

5. Banner: entre o `Divider` e `if (showSegments)`:

```dart
            if (!online) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.cloud_off, size: 16, color: AppColors.title.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.materialSheetOfflineBanner,
                      style: AppTypography.label.copyWith(
                        color: AppColors.title.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
```

Correr: `flutter test test/widget/features/catalog/material_sheet_offline_test.dart test/widget/features/catalog/material_sheet_test.dart test/widget/features/catalog/material_sheet_favorites_test.dart test/widget/features/catalog/material_sheet_lyrics_test.dart` → verdes (os testes antigos não sobrescrevem `connectivityStreamProvider`: o `.value ?? true` cobre o `AsyncLoading` inicial; `materialAvailabilityMapProvider` real lê datasources degradados sem Isar → mapa vazio, e online nada muda).

- [ ] **Step 4: Badge do card**

Em `louvor_group_card.dart` (linhas 327–335), substituir por:

```dart
    // §5.5: o grupo é «disponível» se **algum** material dele está no
    // aparelho — PDF, áudio, cifra ou gestos. Persistente ganha de LRU.
    final materialIds = [for (final m in widget.group.materials) m.id];
    final offlineAvailability = ref.watch(
      materialAvailabilityMapProvider.select((map) {
        var best = PdfOfflineAvailability.notAvailable;
        for (final id in materialIds) {
          final value = map[id];
          if (value == PdfOfflineAvailability.persistentOffline) return value;
          if (value == PdfOfflineAvailability.cachedLru) best = value;
        }
        return best;
      }),
    );
```

(import `material_availability_map_provider.dart` no lugar de `offline_availability_map_provider.dart`.)

Em `louvor_group_card_offline_badge_test.dart`: no `pumpCard`, o override `offlineAvailabilityMapProvider.overrideWith((ref) => ref.watch(_mapProvider))` passa a `materialAvailabilityMapProvider.overrideWith((ref) => ref.watch(_mapProvider))` (troque o import), e `pumpCard` ganha um parâmetro opcional `LouvorGroup? group` usado em `LouvorGroupCard(group: group ?? pdfOnlyGroup())`. Acrescente no fim de `main`:

```dart
  testWidgets('grupo com áudio baixado (sem PDF baixado) mostra a badge', (
    tester,
  ) async {
    final group = LouvorGroup(
      groupId: '001:aleluia',
      numero: '001',
      nome: 'Aleluia',
      sections: pdfOnlyGroup().sections,
      audioTracks: const [
        AudioTrack(
          audioId: 'aud-1',
          r2Key: 'assets/praises/p/a.mp3',
          nome: 'Aleluia',
          numero: '001',
          groupId: '001:aleluia',
          categoria: 'Áudio',
          classificacao: 'Coro',
        ),
      ],
    );

    await pumpCard(
      tester,
      {'aud-1': PdfOfflineAvailability.persistentOffline},
      group: group,
    );

    expect(badgeOf(tester), PdfOfflineAvailability.persistentOffline);
  });
```

(import `package:coldigui/features/audio_player/domain/entities/audio_track.dart`.)

- [ ] **Step 5: Home**

Em `home_empty_state.dart`, `_NoResultsContent.build` (linhas 203–205):

```dart
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOffline = connectivity.value == false;
    // §5.5: com catálogo Coldigom local a busca já respondeu do índice — o
    // aviso só faz sentido quando não há catálogo nenhum no aparelho.
    final hasLocalColdigom = !ref.watch(coldigomSearchIndexProvider).isEmpty;
    final showColdigomOffline = state.remoteFailed && isOffline && !hasLocalColdigom;
```

(import `../../../coldigom/presentation/providers/coldigom_catalog_providers.dart`.) Em `home_empty_state_test.dart`, no caso que espera o aviso «Coldigom offline», acrescente o override `coldigomSearchIndexProvider.overrideWithValue(ColdigomSearchIndex.empty)` e um caso novo com um índice não vazio (`ColdigomSearchIndex.build([ColdigomIndexedPraise.build(praiseId: 'p', numero: '', nome: 'x', searchTokens: 'x', group: LouvorGroup(groupId: 'p', numero: '', nome: 'x', sections: const []))])`) a esperar `findsNothing`.

Correr: `flutter test test/widget/features/catalog` → verdes.

- [ ] **Step 6: Commit**

```bash
flutter gen-l10n
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(catalog): sheet desabilita o que não está no aparelho sem rede (O14); badge por qualquer material; aviso Coldigom só sem catálogo local

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 12: Docs (UC-09, UC-10, FEATURE_INDEX)

**Files:**
- Modify: `docs/use-cases/UC-09-configure-offline.md`
- Modify: `docs/use-cases/UC-10-offline-maintenance.md`
- Modify: `docs/features/FEATURE_INDEX.md`

- [ ] **Step 1: UC-09**

«Fluxo principal»: acrescentar `6. Coldigom (logado): no /offline marca kinds (favoritos pré-marcados + «Outros tipos») → «Baixar selecionados (~X MB)» → PDFs/áudios/cifras/gestos desses kinds ficam no aparelho (DownloadColdigomMaterials).`

«Regras de negócio»: acrescentar `Coldigom por tipo (C1/O7): PDF → OfflinePdfIndex persistente; áudio → OfflineAudioIndex + AudioStoragePort (documents/plpcg_audio, Cache API plpcg-audio-store-v1); cifra/gestos → caches Isar existentes. Só logado (O9); seleção local em prefs offlineColdigomKindIds (O11); idempotente sem checkpoint (O12); estimativas por tipo quando o dump não traz size (O13).`

«Componentes Flutter alvo»: acrescentar `DownloadColdigomMaterials, RemoveColdigomDownloads, ColdigomOfflineSection, offlineColdigomDownloadProvider`.

- [ ] **Step 2: UC-10**

«Fluxo principal»: acrescentar `7. Coldigom: «Tentar de novo» re-executa o download (salta o que já está); «Remover áudios e PDFs baixados do Coldigom» apaga OfflineAudioIndex + store e PDFs Coldigom persistentes — cifras, gestos e letras ficam (O8).`

«Regras de negócio»: acrescentar `Lock de manutenção: bulk, faltantes, limpar, reconcile e coldigom são mutuamente exclusivos (OfflineMaintenanceOwner.coldigom). Sem rede o sheet desabilita o que não está em materialAvailabilityMapProvider (O14); o player toca do aparelho primeiro e sem rede diz «Este áudio não foi baixado».`

- [ ] **Step 3: FEATURE_INDEX**

Linha `offline`: acrescentar `; **offline Coldigom parte 2 set/2026** — [OfflineAudioIndex] + [AudioStoragePort] (áudio persistente), [DownloadColdigomMaterials] por kind (O7–O13), [RemoveColdigomDownloads], [materialAvailabilityMapProvider] (PDF + áudio + cifra + gestos), secção Coldigom no [OfflineSettingsScreen] ([ColdigomOfflineSection]); sheet desabilitado sem rede (O14)`.

Linha `audio_player` (ou a linha em que o player está listado — procure `AudioPlayerSession`): acrescentar `; **local-first set/2026** — [OfflineAudioRepository.lookup] antes da rede; `AudioNotDownloadedException` sem rede`.

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "docs(offline): UC-09/10 e FEATURE_INDEX — download Coldigom por kind, áudio persistente, sheet offline

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

## Checklist manual (§8 da spec — Parte 2)

**Pré-requisito:** Parte 1 no ar (catálogo local hidratado) e conta Google.

**Web dev (`flutter run -d chrome --dart-define-from-file=dart_defines/dev.json`):**
- [ ] `/offline` deslogado: secção «Coldigom por tipo de material» mostra a linha do catálogo (1690 louvores · atualizado há …) e o card «Entre com Google…» com o botão; sem checkboxes.
- [ ] Entrar: favoritos (da tela Materiais favoritos) aparecem pré-marcados e na ordem do rank; «Outros tipos» fechado; cada linha com «N materiais · ~X MB» e barra fina.
- [ ] Desmarcar um favorito → recarregar a página → continua desmarcado (decisão local, O11); mudar favoritos na outra tela não altera a seleção.
- [ ] Marcar 2 kinds pequenos (ex.: «Cifra» + «Gestos») → «Baixar selecionados (~X MB)»: progresso «Kind · n/total · 001 · Nome» em ordem de número; DevTools → Application → Cache Storage mostra `plpcg-audio-store-v1` (se um kind de áudio) e IndexedDB com `OfflineAudioIndex`/`ChordContentCache`/`GestureDocumentCache` a crescer; `flutter analyze` sem jank visível (fatias de 300).
- [ ] «Parar» a meio → «N não baixados · Tentar de novo» → tentar de novo salta o que já está (Network mostra só os que faltavam).
- [ ] Marcar um kind de áudio com quota baixa (DevTools → Application → Storage → simular quota) → SnackBar de aviso de espaço antes de iniciar; se o navegador negar, o download para com o parcial guardado.
- [ ] Network → Offline: abrir um louvor baixado → sheet com banner «Sem ligação · só o que está no aparelho abre»; tiles baixados ativos, os outros «Não baixado · sem ligação», YouTube «Precisa de ligação», Letra ativa; `+` continua a adicionar à lista. Abrir PDF/cifra/gestos/áudio baixados: tudo abre; áudio não baixado → «Este áudio não foi baixado».
- [ ] **v2.plpcg.com** (produção, não `flutter build web` local): fila com ≥3 faixas Coldigom baixadas → todas tocam por `blob:` (DevTools → Network sem request pro áudio de cada uma); pular entre as 3 faixas repetidamente não corta o áudio nem lança erro (fix round 1 — blob da faixa inicial não pode ser revogado pelo trim de outra faixa da mesma fila).
- [ ] Card do louvor com áudio baixado (sem PDF): badge de nuvem visível.
- [ ] «Remover áudios e PDFs baixados do Coldigom» → confirmação com nota «Cifras, gestos e letras ficam» → snackbar «N PDFs e M áudios removidos»; cifras/gestos continuam a abrir offline.
- [ ] Bulk PLPCG em curso → botões da secção Coldigom desabilitados (lock); e vice-versa.

**iPhone real (build homolog):**
- [ ] Baixar 2 kinds (um de áudio) → ficheiros em `Documents/plpcg_audio/` (Xcode → Devices → container); progresso mantém a tela acesa (wakelock).
- [ ] Mandar o app para background a meio → volta como «N não baixados · Tentar de novo» (pausa em background, O12).
- [ ] Modo de avião: abrir PDF, áudio (toca do ficheiro), cifra, gestos (figuras já em cache), letra; sheet com tiles desabilitados corretos; pesquisar continua a responder.
- [ ] Voltar online: tudo volta a ativo sem reabrir o app.
