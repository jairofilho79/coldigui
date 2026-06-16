# Backlog — Modo Offline: Catálogo como SSOT, LRU e Leitor (PLPCG Flutter)

**Criado em:** 2026-06-16  
**Origem:** auditoria do ciclo de vida completo do modo offline — PDFs fora de packages, cache LRU, manifest entre cold starts e comportamento do leitor em fullOfflineMode  
**Complementa:**
- `docs/OFFLINE_PERFORMANCE_BACKLOG.md` (integridade, reconcile, Isar)
- `docs/OFFLINE_DOWNLOAD_RELIABILITY_BACKLOG.md` (pipeline HTTP bulk, timeouts, retry)  
**Público:** agentes de correção / engenheiros da feature `offline`

---

## Diagnóstico resumido

| Sintoma | Causa raiz |
|---------|-----------|
| Louvores adicionados ao D1 após geração dos packages nunca aparecem como faltantes | `GetOfflineStatsByCategory` e `DownloadMissingPdfs` usam apenas `manifest.packages` — não o catálogo Isar (D1) |
| "Baixar faltantes" não baixa louvores novos | `DownloadMissingPdfs._collectPdfIds` itera só sobre `manifest.packages.parts` |
| Leitor fica travado ~120s antes de informar erro offline | `ResolvePdfForReader` tenta fetch HTTP mesmo quando `isFullOfflineMode = true` |
| Stats "não foi possível calcular faltantes" sempre no primeiro boot offline | Manifest in-memory (`OfflineManifestRemoteDatasource`) perdido a cada cold start |
| PDFs do bulk podem ser removidos silenciosamente por download on-demand | `OfflinePdfIndex` sem campo `isPersistent` — `evictOldestPdfs` não distingue bulk de LRU |
| Usuário não sabe que PDF "offline" pode sumir | Badge/ícone de offline não diferencia PDFs permanentes de PDFs em cache LRU |

**Escopo dos arquivos-chave afetados:**

```
lib/features/offline/
  domain/usecases/get_offline_stats_by_category.dart   ← #N1
  domain/usecases/download_missing_pdfs.dart           ← #N1
  domain/usecases/resolve_pdf_for_reader.dart          ← #N2
  data/datasources/offline_manifest_remote_datasource.dart ← #N3
  data/datasources/offline_pdf_local_datasource.dart   ← #N4
  data/repositories/offline_pdf_repository_impl.dart   ← #N4
lib/core/database/collections/offline_pdf_index.dart   ← #N4 (schema Isar)
lib/features/catalog/presentation/ (badges offline)    ← #N5
```

---

## Priorização

| #   | Item | Categoria | Impacto | Esforço |
|-----|------|-----------|---------|---------|
| N1  | D1/Catálogo Isar deve ser SSOT para PDFs faltantes — manifest de packages é incompleto | Confiabilidade / SSOT | **Crítico** | Médio |
| N2  | Leitor aguarda timeout completo (~120s) antes de falhar em fullOfflineMode | Confiabilidade / UX | **Crítico** | Baixo |
| N3  | Manifest remoto não persiste entre cold starts — stats sempre quebradas no primeiro boot offline | Confiabilidade / UX | **Alto** | Médio |
| N4  | PDFs do bulk podem ser evictados por downloads on-demand (sem `isPersistent` no Isar) | Confiabilidade | **Alto** | Médio |
| N5  | UI não diferencia "PDF permanente offline" de "PDF em cache LRU transitório" | UX | **Alto** | Médio |
| N6  | Mensagem de erro no leitor não orienta o usuário à tela offline para baixar o PDF | UX | Médio | Baixo |

**Ordem sugerida de implementação:** N2 → N3 → N1 → N4 → N5 → N6

**Quick win (travar leitor resolve urgência imediata):** item **N2** — estimativa < 1h.

---

## #N1 — D1/Catálogo Isar deve ser SSOT para PDFs faltantes

**Categoria:** Confiabilidade / SSOT  
**Impacto:** Crítico  
**Esforço:** Médio  
**Arquivos principais:**
- `lib/features/offline/domain/usecases/get_offline_stats_by_category.dart`
- `lib/features/offline/domain/usecases/download_missing_pdfs.dart`
- `lib/features/catalog/data/datasources/catalog_local_datasource.dart`

### Problema

`GetOfflineStatsByCategory._countMissing()` conta como "faltantes" apenas PDFs que existem em `manifest.packages`:

```dart
// get_offline_stats_by_category.dart
for (final material in CatalogMaterials.uiMaterials) {
  final package = manifest.packages[material];
  if (package == null) continue;              // ← ignora qualquer louvor fora dos packages
  for (final part in package.parts) {
    for (final pdfId in part.pdfs) {          // ← apenas pdfIds listados no ZIP manifest
      if (!indexedPdfIds.contains(pdfId)) { ... }
    }
  }
}
```

Da mesma forma, `DownloadMissingPdfs._collectPdfIds()` só coleta IDs de `manifest.packages`.

O manifest de packages (`/offline-manifest.json`) é gerado com base no acervo atual no momento da geração. **Louvores adicionados ao D1 depois da última geração dos packages não estarão em nenhum package** e portanto:

1. Não aparecem como faltantes nas stats da tela offline.
2. O botão "Baixar faltantes" não os inclui.
3. O usuário descobre a ausência ao tentar abrir o louvor sem rede → `PdfOfflineUnavailableException` — sem possibilidade de remediar naquele momento.

O catálogo Isar (`CatalogLocalDatasource`), sincronizado do D1 no boot com rede, já contém **todos** os louvores com seus `pdfId`. Ele deve ser a SSOT para determinar o conjunto completo de PDFs esperados no modo offline.

### Diagnóstico técnico

```dart
// catalog_local_datasource.dart — tem todos os pdfIds
Future<Map<String, String>> loadPdfIdToCategoriaMap() async {
  final caches = await _isar.louvorCaches.where().findAll();
  return {for (final cache in caches) cache.pdfId: cache.categoria};
}
```

`GetOfflineStatsByCategory` já recebe `_catalogLocal: CatalogLocalDatasource` e já usa `loadPdfIdToCategoriaMap()` para mapear categorias dos PDFs indexados — mas **não usa esse mapa para calcular faltantes**. Usa apenas o manifest.

**Gap:** se o catálogo Isar tem 4700 louvores e o manifest de packages tem 4600, os 100 novos nunca aparecem como faltantes.

### Solução recomendada

**Fase 1 — Statísticas de faltantes via catálogo Isar:**

```dart
// get_offline_stats_by_category.dart — _countMissing revisado
Future<Map<String, int>> _countMissing({
  required Set<String> indexedPdfIds,
}) async {
  // D1 (via catálogo Isar local) é a SSOT de quais pdfIds devem existir
  final pdfIdToCategoria = await _catalogLocal.loadPdfIdToCategoriaMap();

  final missingByCategory = {
    for (final material in CatalogMaterials.uiMaterials) material: 0,
  };

  for (final entry in pdfIdToCategoria.entries) {
    final pdfId = entry.key;
    if (indexedPdfIds.contains(pdfId)) continue;   // já baixado
    final material = OfflineMaterialResolver.toUiMaterial(entry.value);
    if (material == null) continue;
    missingByCategory[material] = missingByCategory[material]! + 1;
  }

  return missingByCategory;
}
```

Remover a dependência de `OfflineManifestRemoteDatasource` no cálculo de faltantes (o manifest ainda é necessário para o bulk download, mas não para a contagem de faltantes).

**Fase 2 — "Baixar faltantes" cobre louvores fora dos packages:**

```dart
// download_missing_pdfs.dart — _collectPdfIds revisado
Future<List<String>> _collectPdfIds({Set<String>? materialCategories}) async {
  // D1 como SSOT — todos os louvores do catálogo local
  final pdfIdToCategoria = await _catalogLocal.loadPdfIdToCategoriaMap();

  if (materialCategories == null) {
    return pdfIdToCategoria.keys.toList();
  }

  return [
    for (final entry in pdfIdToCategoria.entries)
      if (materialCategories.contains(
        OfflineMaterialResolver.toUiMaterial(entry.value),
      ))
        entry.key,
  ];
}
```

`DownloadMissingPdfs` precisa receber `CatalogLocalDatasource` como dependência adicional.

### Impacto em DI

- `GetOfflineStatsByCategory` já recebe `CatalogLocalDatasource` → sem quebra de assinatura.
- `DownloadMissingPdfs` precisa de nova dependência `CatalogLocalDatasource`.
- `downloadMissingPdfsProvider` em `offline_providers.dart` precisa injetar `catalogLocalDatasourceProvider`.
- `OfflineManifestRemoteDatasource` pode ser removido de `GetOfflineStatsByCategory` (ainda necessário em `DownloadOfflinePackages` para o bulk).

### Critério de aceite

- Louvor adicionado ao D1 (mas ausente no manifest de packages) **aparece como faltante** nas stats.
- "Baixar faltantes" baixa esse louvor via `FetchAndStorePdf` com `persistentDownload: true`.
- Stats de faltantes funcionam offline (sem rede) pois usam apenas catálogo Isar local — `missingCountReliable` é `true` mesmo sem manifest remoto.
- Testes de `GetOfflineStatsByCategory` cobrem cenário: louvor no Isar, ausente no índice offline, ausente no manifest.
- Testes de `DownloadMissingPdfs` cobrem: pdf no catálogo Isar mas fora de qualquer package → incluído no download.

### Referências

- `lib/features/offline/domain/usecases/get_offline_stats_by_category.dart`
- `lib/features/offline/domain/usecases/download_missing_pdfs.dart`
- `lib/features/catalog/data/datasources/catalog_local_datasource.dart`
- `lib/features/offline/data/providers/offline_providers.dart`

---

## #N2 — Leitor aguarda timeout completo antes de falhar em fullOfflineMode

**Categoria:** Confiabilidade / UX  
**Impacto:** Crítico  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart`

### Problema

Quando `isFullOfflineMode = true` (`OFFLINE_AVAILABLE=TRUE`) e o PDF não está no índice local, `ResolvePdfForReader` ainda chama `_fetchAndStore()`:

```dart
// resolve_pdf_for_reader.dart
final (entry, hasIndexEntry) =
    await _repository.lookupWithIndexState(pdfId);
if (entry != null) {
  return LocalPdfSource(...); // cache hit — OK
}

// PDF não indexado localmente
try {
  return await _fetchAndStore(
    pdfId: pdfId,
    remotePath: remotePath,
    onProgress: onProgress,
    persistentDownload: _isFullOfflineMode(), // true — mas tenta rede!
  );
} on DioException catch (e) {
  if (_isNetworkError(e)) {
    // Após 120s de timeout → chega aqui
    throw PdfOfflineUnavailableException(pdfId: pdfId);
  }
```

`PdfBytesDatasource._fetchRemote` usa `receiveTimeout: OfflineConfig.pdfDownloadReceiveTimeout` (120s). O app fica **2 minutos** com spinner sem feedback útil antes de apresentar o erro — exatamente quando o usuário está no culto sem internet.

O modo `OFFLINE_AVAILABLE=TRUE` significa que o usuário completou o bulk download. Um PDF ausente do índice indica que ele não foi baixado previamente (ou foi evictado). Tentar rede nesse cenário é incorreto e frustrante.

### Solução recomendada

Fail fast quando `isFullOfflineMode = true` e PDF não está no índice local:

```dart
// resolve_pdf_for_reader.dart
Future<LocalPdfSource> call({
  required String pdfId,
  required String remotePath,
  ProgressCallback? onProgress,
}) async {
  final (entry, hasIndexEntry) =
      await _repository.lookupWithIndexState(pdfId);
  if (entry != null) {
    return LocalPdfSource(
      pdfId: pdfId,
      absolutePath: entry.absolutePath,
      fromCache: true,
    );
  }

  // Modo offline completo: não tentar rede, falhar imediatamente
  if (_isFullOfflineMode()) {
    if (hasIndexEntry) {
      // PDF estava indexado mas arquivo removido do disco
      throw PdfExternallyDeletedException(pdfId: pdfId);
    }
    throw PdfOfflineUnavailableException(pdfId: pdfId);
  }

  // Modo online ou híbrido: fetch on-demand normal
  try { ... }
```

O `hasIndexEntry = true` (entrada no Isar, arquivo ausente no disco) deve lançar `PdfExternallyDeletedException` para orientar o usuário que o PDF precisa ser re-baixado.

### Critério de aceite

- Em fullOfflineMode, PDF não indexado → `PdfOfflineUnavailableException` em < 100ms (sem tentar rede).
- Em fullOfflineMode, PDF indexado + arquivo ausente no disco → `PdfExternallyDeletedException` em < 100ms.
- Modo online (não fullOfflineMode) preserva comportamento atual de fetch on-demand.
- Testes unitários cobrem os dois caminhos de fail-fast.

### Referências

- `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart`
- `lib/features/offline/domain/exceptions/pdf_resolve_exceptions.dart`
- `lib/features/offline/data/providers/offline_providers.dart` (injeção de `isFullOfflineMode`)

---

## #N3 — Manifest remoto não persiste entre cold starts

**Categoria:** Confiabilidade / UX  
**Impacto:** Alto  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/offline/data/datasources/offline_manifest_remote_datasource.dart`

### Problema

`OfflineManifestRemoteDatasource` usa cache in-memory com TTL de 24h:

```dart
// offline_manifest_remote_datasource.dart
OfflineManifest? _cachedManifest;
DateTime? _cacheTime;

Future<OfflineManifest> fetchManifest() async {
  if (_cachedManifest != null && ... DateTime.now().difference(_cacheTime!) < _cacheTtl) {
    return _cachedManifest!; // hit — só funciona na mesma sessão
  }
  final manifest = await _fetchFromNetwork(); // falha offline
  ...
}
```

O cache in-memory é destruído a cada kill do app. No cold start offline:
1. `GetOfflineStatsByCategory.call()` → `_manifestDatasource.fetchManifest()` → lança exceção de rede
2. `missingCountReliable = false` → UI exibe "Não foi possível calcular faltantes"

Isso ocorre **toda vez** que o usuário abre o app offline, tornando as stats de faltantes sempre inacessíveis no cenário de uso mais crítico.

**Nota:** com a correção de #N1, `GetOfflineStatsByCategory` pode deixar de depender do manifest remoto para calcular faltantes (usando catálogo Isar como SSOT). Porém o manifest ainda é usado por `DownloadMissingPdfs` (para construir remote paths) e pelo bulk download (`DownloadOfflinePackages`). A persistência do manifest continua sendo necessária para esses fluxos.

### Solução recomendada

Persistir o manifest serializado em SharedPreferences após cada busca bem-sucedida:

```dart
// offline_manifest_remote_datasource.dart
static const _manifestKey = 'offline_manifest_json';
static const _manifestCacheTimeKey = 'offline_manifest_cache_time';

Future<OfflineManifest> fetchManifest() async {
  // 1. Tenta cache in-memory (mesmo processo)
  if (_cachedManifest != null && _isMemoryCacheFresh()) {
    return _cachedManifest!;
  }

  // 2. Tenta buscar da rede
  try {
    final manifest = await _fetchFromNetwork();
    _cachedManifest = manifest;
    _cacheTime = DateTime.now();
    await _persistManifest(manifest); // salva em SharedPreferences
    return manifest;
  } on Object {
    // 3. Fallback: manifest persistido em disco
    final persisted = await _loadPersistedManifest();
    if (persisted != null) return persisted;
    rethrow; // sem rede E sem cache em disco → lança normalmente
  }
}
```

A serialização deve reutilizar `OfflineManifestDto.toJson()` (ou equivalente). O manifest persistido não tem TTL rígido — é melhor um manifest desatualizado que nenhum para fins de fallback.

### Critério de aceite

- Cold start offline após ter tido rede: manifest carregado de disco sem erro.
- `DownloadMissingPdfs` funciona offline (usando manifest em disco) para construir remote paths.
- Testes unitários: mock de rede falhando + manifest persistido → `fetchManifest()` retorna manifest de disco.
- `missingCountReliable` não se aplica ao catálogo Isar (pós #N1), mas o manifest de disco garante que os bulk paths continuem funcionando.

### Referências

- `lib/features/offline/data/datasources/offline_manifest_remote_datasource.dart`
- `lib/features/offline/data/models/offline_manifest_dto.dart` (serialização)
- `lib/core/constants/storage_keys.dart` (nova chave)

---

## #N4 — PDFs do bulk podem ser evictados por downloads on-demand

**Categoria:** Confiabilidade  
**Impacto:** Alto  
**Esforço:** Médio  
**Arquivos principais:**
- `lib/core/database/collections/offline_pdf_index.dart`
- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`
- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart`

### Problema

`FetchAndStorePdf` tem flag `persistentDownload` que quando `true` pula a eviction LRU:

```dart
// fetch_and_store_pdf.dart
if (!persistentDownload) {
  await _ensureCacheQuota(excludePdfIds: excludePdfIds);
}
// ...
if (!persistentDownload) {
  await _trimCacheToQuota(excludePdfIds: excludePdfIds);
}
```

Essa flag é `true` para bulk downloads e "baixar faltantes" — correto durante o download. Porém, a flag **não é persistida** no schema `OfflinePdfIndex`. Após o download, todos os PDFs no índice são indistinguíveis.

O problema surge quando o usuário usa o app online (antes ou depois de ter ativado o modo offline):
- Abre PDFs on-demand → `persistentDownload = false` → `_ensureCacheQuota` é chamado
- `evictOldestPdfs` usa `lastAccessedAt` como critério — pode evictar PDFs do bulk que há mais tempo não são acessados
- Resultado: PDFs que o usuário baixou explicitamente para o culto são removidos silenciosamente para dar lugar a PDFs abertos casualmente

**Exceção atual:** PDFs em playlists favoritas são protegidos via `favoritePdfIdsResolver`. Mas a maioria dos ~4600 PDFs do acervo não está em playlists.

**Cenário real:**
1. Usuário faz bulk de Partitura (2000 PDFs) — marca `OFFLINE_AVAILABLE=TRUE`
2. Nos próximos dias usa o app online e abre 200 PDFs de Cifra on-demand
3. No culto (offline), tenta abrir uma partitura que não estava nos 200 recentes → `PdfOfflineUnavailableException`

### Solução recomendada

**Fase 1 — Adicionar campo `isPersistent` ao schema Isar (migration):**

```dart
// offline_pdf_index.dart
@collection
class OfflinePdfIndex {
  // ... campos existentes ...
  bool isPersistent = false; // true = bulk/missing download; false = LRU on-demand
}
```

**Fase 2 — Persistir a flag no upsert:**

```dart
// offline_pdf_repository_impl.dart — upsert
final index = OfflinePdfIndex()
  ..pdfId = pdfId
  // ... outros campos ...
  ..isPersistent = isPersistent; // novo parâmetro
```

**Fase 3 — `evictOldestPdfs` exclui PDFs persistentes:**

```dart
// offline_pdf_local_datasource.dart — findOldestForEviction
Future<List<OfflinePdfIndex>> findOldestForEviction({
  required int limit,
  required int offset,
}) async {
  return _isar.offlinePdfIndexes
      .where()
      .isPersistentEqualTo(false) // ← exclui bulk/missing
      .sortByLastAccessedAt()
      .offset(offset)
      .limit(limit)
      .findAll();
}
```

**Nota de migration Isar:** adicionar novo campo com `@Index` ao schema exige incrementar a versão do schema e escrever migration (ver `MigrateOfflineStorage`).

### Critério de aceite

- PDFs baixados via bulk ou "baixar faltantes" têm `isPersistent = true` no índice Isar.
- `evictOldestPdfs` nunca evicta PDFs com `isPersistent = true` (exceto via `ClearOfflineCache`).
- PDFs abertos on-demand (não bulk) têm `isPersistent = false` e são elegíveis para eviction.
- Migration Isar compatível com índices existentes (campo `false` por padrão).
- Testes: bulk download → `isPersistent = true`; on-demand → `isPersistent = false`; eviction não toca persistentes.

### Referências

- `lib/core/database/collections/offline_pdf_index.dart`
- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`
- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart`
- `lib/features/offline/domain/usecases/migrate_offline_storage.dart`

---

## #N5 — UI não diferencia "PDF permanente offline" de "PDF em cache LRU transitório"

**Categoria:** UX  
**Impacto:** Alto  
**Esforço:** Médio  
**Arquivos principais:**
- `lib/features/catalog/presentation/` (badges de disponibilidade offline)
- `lib/features/offline/domain/repositories/offline_pdf_repository.dart`
- `lib/features/pdf_opening/domain/usecases/validate_pdf_availability.dart`

### Problema

O badge "disponível offline" no catálogo (ícone de nuvem com check, ou indicador equivalente) aparece para **todos os PDFs no índice Isar**, independente de serem:
- **Permanentes** (`isPersistent = true`, pós #N4): baixados via bulk/missing — garantidos offline
- **LRU temporários** (`isPersistent = false`): cacheados ao abrir on-demand — podem ser removidos

O usuário que abriu um louvor on-demand em casa (com WiFi) vê o badge "offline" no culto e tenta abrir — mas o PDF pode ter sido evictado. A experiência é de falha inexplicável justamente no momento mais crítico.

**Contexto de `ValidatePdfAvailability`:**

```dart
// validate_pdf_availability.dart — usado para o badge
class ValidatePdfAvailability {
  Future<bool> call(String pdfId) async {
    final validIds = await _repository.lookupBatch({pdfId});
    return validIds.contains(pdfId);
  }
}
```

Retorna `true/false` sem distinguir `isPersistent`. O badge binário engana o usuário.

### Solução recomendada

**Fase 1 — Enum de disponibilidade offline:**

```dart
enum PdfOfflineAvailability {
  notAvailable,   // não no índice
  cachedLru,      // no índice, isPersistent = false — pode ser evictado
  persistentOffline, // no índice, isPersistent = true — garantido offline
}
```

**Fase 2 — `ValidatePdfAvailability` retorna enum:**

```dart
Future<PdfOfflineAvailability> call(String pdfId) async {
  final entry = await _repository.findIndexEntry(pdfId);
  if (entry == null) return PdfOfflineAvailability.notAvailable;
  return entry.isPersistent
      ? PdfOfflineAvailability.persistentOffline
      : PdfOfflineAvailability.cachedLru;
}
```

**Fase 3 — Badge no catálogo diferenciado:**
- `persistentOffline` → ícone sólido de nuvem com check (download garantido)
- `cachedLru` → ícone de nuvem com check mais sutil (cor ou opacidade diferente) + tooltip "Cache temporário — pode ser removido"
- `notAvailable` → sem badge

### Critério de aceite

- PDFs `isPersistent = true` mostram badge "permanente offline" diferente de PDFs `cachedLru`.
- Tooltip ou label explica que cache temporário pode ser removido.
- Badge `notAvailable` permanece igual ao atual.
- Testes de widget verificam renderização correta dos três estados.

**Nota:** esta task depende de #N4 (campo `isPersistent` no schema).

### Referências

- `lib/features/pdf_opening/domain/usecases/validate_pdf_availability.dart`
- `lib/features/offline/domain/repositories/offline_pdf_repository.dart`
- `lib/features/catalog/presentation/` (componentes de badge)

---

## #N6 — Mensagem de erro no leitor não orienta o usuário à tela offline

**Categoria:** UX  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivos principais:**
- `lib/features/offline/domain/exceptions/pdf_resolve_exceptions.dart`
- Tela/widget que apresenta os erros do leitor (handler de `PdfOfflineUnavailableException`)

### Problema

```dart
// pdf_resolve_exceptions.dart
class PdfOfflineUnavailableException implements Exception {
  const PdfOfflineUnavailableException({
    required this.pdfId,
    this.message =
        'Este PDF não está disponível offline. Conecte-se à internet para abri-lo.',
  });
```

A mensagem orienta o usuário a "conectar-se à internet" — mas o PDF pode estar ausente porque:
1. Nunca foi baixado (louvor novo no D1 fora dos packages — Issue #N1)
2. Foi evictado do LRU cache

Em ambos os casos, a **ação correta não é conectar à internet em tempo real**, mas sim:
- Para (1): ir à tela "Configurações Offline" → "Baixar faltantes"
- Para (2): abrir o PDF na próxima vez que tiver rede (e ele será re-cacheado) OU ir a offline settings para garantir download persistente

A mensagem atual não dá essa orientação.

**`PdfExternallyDeletedException`** tem mensagem similar: "O PDF foi removido do dispositivo. Conecte-se à internet para baixá-lo novamente." — também não menciona a tela offline.

### Solução recomendada

**Fase 1 — Melhorar mensagens:**

```dart
class PdfOfflineUnavailableException implements Exception {
  const PdfOfflineUnavailableException({
    required this.pdfId,
    this.message =
        'Este PDF não foi baixado para uso offline. '
        'Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.',
  });
```

**Fase 2 — Ação navegável no leitor:**
No widget/handler que intercepta `PdfOfflineUnavailableException`, exibir snackbar/dialog com botão de ação que navega diretamente à tela de configurações offline:

```dart
// Handler no leitor
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(l10n.pdfOfflineUnavailableMessage),
    action: SnackBarAction(
      label: l10n.pdfOfflineGoToSettings, // "Baixar"
      onPressed: () => context.push(RoutePaths.offlineSettings),
    ),
  ),
);
```

### Critério de aceite

- `PdfOfflineUnavailableException.message` menciona a opção de baixar na tela offline.
- Snackbar/dialog no leitor tem botão de ação que navega para `/offline-settings` (GoRouter).
- Strings localizadas em `app_pt.arb` e `app_en.arb`.
- Testes de widget verificam que a ação de navegação é exibida.

### Referências

- `lib/features/offline/domain/exceptions/pdf_resolve_exceptions.dart`
- `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Handler de erro do leitor PDF

---

## Divisão sugerida por subagente

| Subagente | Items | Descrição | Dependências |
|-----------|-------|-----------|-------------|
| **offline-ssot-agent** | #N1 | D1/Isar como SSOT para faltantes — refatorar `GetOfflineStatsByCategory` e `DownloadMissingPdfs` | Nenhuma — **prioridade máxima para completar a feature** |
| **offline-reader-failfast-agent** | #N2 | Fail-fast em fullOfflineMode no `ResolvePdfForReader` | Nenhuma — **quick win crítico** |
| **offline-manifest-persist-agent** | #N3 | Persistir manifest em SharedPreferences entre cold starts | Nenhuma |
| **offline-lru-persistent-agent** | #N4 | Adicionar `isPersistent` ao schema Isar + migration + excluir de eviction | Nenhuma (Isar schema migration é isolada) |
| **offline-ui-badge-agent** | #N5 | Diferenciar badge permanente vs LRU na UI | #N4 deve estar completo (depende de `isPersistent`) |
| **offline-ux-error-agent** | #N6 | Mensagens de erro e navegação para tela offline no leitor | Nenhuma |

---

## Métricas de sucesso (pós-correção)

| Métrica | Atual | Meta |
|---------|-------|------|
| Louvores novos no D1 (fora de packages) mostrados como faltantes | 0% (invisíveis) | 100% |
| Tempo de espera ao abrir PDF não-baixado em fullOfflineMode | ~120s (timeout) | < 200ms (fail-fast) |
| Stats de faltantes disponíveis no primeiro boot offline | 0% (manifest in-memory) | 100% (manifest em disco) |
| PDFs do bulk evictados por downloads on-demand | Possível | Impossível (`isPersistent = true`) |
| Usuário informado de risco de eviction para PDFs LRU | 0% | 100% (badge diferenciado) |
| Erro no leitor orienta à tela offline | ❌ | ✅ (ação navegável no snackbar) |

---

## Relação com backlogs anteriores

| Backlog | Item | Relação |
|---------|------|---------|
| `OFFLINE_PERFORMANCE_BACKLOG.md` #5 | `GetOfflineStatsByCategory` sem rede exibe "0 faltantes" | #N1 e #N3 complementam e superam — SSOT via Isar elimina dependência da rede para stats |
| `OFFLINE_PERFORMANCE_BACKLOG.md` #8 | Quota LRU não se aplica ao bulk | #N4 resolve pelo outro lado — protege PDFs do bulk da eviction |
| `OFFLINE_PERFORMANCE_BACKLOG.md` #11 | `touchLastAccessed` com debounce | Já implementado — #N4 complementa com `isPersistent` |
| `OFFLINE_DOWNLOAD_RELIABILITY_BACKLOG.md` #6 | Mensagens de erro genéricas | #N6 complementa no contexto do leitor (não do download bulk) |

---

## Histórico

| Versão | Data | Alterações |
|--------|------|------------|
| 1.0 | 2026-06-16 | Documento inicial — auditoria D1/SSOT, LRU e leitor em fullOfflineMode |
