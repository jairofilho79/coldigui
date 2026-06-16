# Backlog de Confiabilidade e Performance — Modo Offline (PLPCG Flutter)

**Criado em:** 2026-06-13  
**Origem:** auditoria estática do pipeline completo offline — persistência do catálogo (D1→Isar), download bulk de pacotes ZIP, download individual de PDFs faltantes, consumo local pelo leitor PDF, gestão de espaço e integridade de dados  
**Público:** agentes de correção / engenheiros responsáveis pela feature `offline`

O modo offline é o diferencial competitivo do app: garante acesso ao acervo completo durante cultos, sem dependência de internet. Qualquer falha silenciosa de integridade, crash não recuperável ou dado corrompido invisível impede esse objetivo.

---

## Priorização

| #  | Item | Categoria | Impacto | Esforço |
|----|------|-----------|---------|---------|
| 1  | Validação de integridade inconsistente — reconcile/missing não verificam magic bytes `%PDF` | Confiabilidade | Alto | Baixo |
| 2  | Checkpoint intra-part não persiste `extractedPdfCount` durante extração — crash reprocessa part completa | Confiabilidade | Alto | Médio |
| 3  | ZIP cacheado sem re-validação de integridade/tamanho — bulk aceita ZIP corrompido como válido | Confiabilidade | Médio | Baixo |
| 4  | `unmatchedEntries` do ZIP ignorado silenciosamente — PDFs faltantes nunca detectados no bulk | Confiabilidade | Médio | Baixo |
| 5  | `GetOfflineStatsByCategory` engole falha de manifest — UI exibe "0 faltantes" com rede indisponível | UX / Confiabilidade | Médio | Baixo |
| 6  | Sem TTL nem re-sync incremental do catálogo Isar — `LouvorCache` pode ficar obsoleto indefinidamente | Confiabilidade | Médio | Médio |
| 7  | ZIP inteiro carregado em memória no isolate de extração — risco de OOM em pacotes grandes | Performance / Memória | Médio | Médio |
| 8  | Quota LRU não se aplica ao bulk — acúmulo irrestrito de PDFs no disco pós-bulk | Confiabilidade | Médio | Médio |
| 9  | `findByPdfIds` com N queries Isar sequenciais — O(N) round-trips no bulk skip lookup | Performance | Baixo | Baixo |
| 10 | `evictOldestPdfs` carrega todos os registros em memória para sort | Performance | Baixo | Baixo |
| 11 | `touchLastAccessed` emite write txn Isar a cada abertura de PDF | Performance | Baixo | Baixo |
| 12 | Reconcile faz scan recursivo do filesystem a cada foreground (sem debounce pós-evento) | Performance | Baixo | Médio |
| 13 | Arquivos `.tmp` órfãos do `ZipPackageDownloader` não são limpos no cold start | Confiabilidade | Baixo | Baixo |
| 14 | `DiskSpaceChecker` retorna `null` → verificação de espaço ignorada em edge cases | Confiabilidade | Baixo | Baixo |
| 15 | `PollManifestChecksum` (UC-12) não implementado — sem detecção automática de catálogo desatualizado | Confiabilidade | Baixo | Alto |

**Ordem sugerida de correção:** 1 → 3 → 4 → 2 → 5 → 13 → 14 → 9 → 10 → 11 → 6 → 7 → 8 → 12 → 15

---

## #1 — Validação de integridade inconsistente — reconcile/missing não verificam magic bytes `%PDF`

**Categoria:** Confiabilidade  
**Impacto:** Alto  
**Esforço:** Baixo  
**Arquivos principais:**
- `lib/features/offline/data/utils/reconcile_path_validator.dart`
- `lib/features/offline/domain/usecases/download_missing_pdfs.dart`
- `lib/features/offline/data/utils/zip_pdf_extractor.dart`

### Problema

Há quatro validações de "arquivo PDF válido" no sistema, mas apenas uma verifica magic bytes:

| Camada | Validação | Magic bytes? |
|--------|-----------|:---:|
| `OfflinePdfRepositoryImpl._validateIndexFile` (lookup normal) | FileStat + magic bytes `%PDF` | ✅ |
| `reconcile_path_validator.dart` | `exists()` + `length() > 0` | ❌ |
| `DownloadMissingPdfs._hasValidFile` | `exists()` + `length() > 0` | ❌ |
| `zip_pdf_extractor.dart` (pós-extração) | extensão `.pdf` + bytes não vazios | ❌ |

Isso cria uma janela crítica:

1. Uma resposta HTTP de erro (ex.: HTML com `<html>...`) é escrita no disco com tamanho > 0.
2. `reconcile_path_validator` considera o arquivo **válido** e mantém no índice.
3. `DownloadMissingPdfs` verifica `_hasValidFile` → **válido** → não re-baixa.
4. Usuário tenta abrir → `PdfDocument.openFile` falha com erro nativo → UX degradada.

O `lookup` normal purga esse arquivo quando o usuário tenta abrir, mas o ciclo `reconcile → missing download` nunca o detecta, criando uma entrada "fantasma" permanente enquanto o usuário não abrir aquele PDF específico.

```dart
// reconcile_path_validator.dart — validação incompleta
static Future<bool> isValidPdfFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  return await file.length() > 0; // Aceita qualquer conteúdo não-vazio!
}
```

```dart
// OfflinePdfRepositoryImpl._validateIndexFile — validação completa (referência)
static Future<bool> _validateIndexFile(OfflinePdfIndex index) async {
  final stat = await FileStat.stat(index.storagePath);
  if (stat.type != FileSystemEntityType.file || stat.size < 4) return false;
  final bytes = await File(index.storagePath).openRead(0, 4).first;
  return bytes.length == 4 &&
      bytes[0] == 0x25 && bytes[1] == 0x50 &&   // %P
      bytes[2] == 0x44 && bytes[3] == 0x46;       // DF
}
```

### Solução recomendada

Extrair `_validateIndexFile` para uma função utilitária compartilhada em `lib/features/offline/data/utils/pdf_integrity_validator.dart`:

```dart
// pdf_integrity_validator.dart
abstract final class PdfIntegrityValidator {
  static const _pdfMagic = [0x25, 0x50, 0x44, 0x46]; // %PDF

  static Future<bool> isValidPdfFile(String path) async {
    final stat = await FileStat.stat(path);
    if (stat.type != FileSystemEntityType.file || stat.size < 4) return false;
    try {
      final bytes = await File(path).openRead(0, 4).first;
      return bytes.length == 4 &&
          bytes[0] == _pdfMagic[0] && bytes[1] == _pdfMagic[1] &&
          bytes[2] == _pdfMagic[2] && bytes[3] == _pdfMagic[3];
    } on FileSystemException {
      return false;
    }
  }
}
```

Substituir todas as validações pontuais por `PdfIntegrityValidator.isValidPdfFile`:

- `reconcile_path_validator.dart` → usa `PdfIntegrityValidator.isValidPdfFile`
- `DownloadMissingPdfs._hasValidFile` → usa `PdfIntegrityValidator.isValidPdfFile`
- `zip_pdf_extractor.dart` → valida magic bytes após escrever cada PDF extraído
- `OfflinePdfRepositoryImpl._validateIndexFile` → delega para `PdfIntegrityValidator`

### Critério de aceite

- Um arquivo com bytes `<html>...` de tamanho > 0 **não** passa na validação de nenhuma camada.
- `DownloadMissingPdfs` re-baixa PDFs que possuem conteúdo não-PDF no disco.
- `ReconcileOfflineIndex` remove do índice entradas com arquivo inválido (não-PDF).
- Testes unitários de `reconcile_path_validator`, `DownloadMissingPdfs` e `ZipPdfExtractor` cobrem o caso de arquivo com conteúdo inválido.

### Referências

- `lib/features/offline/data/utils/reconcile_path_validator.dart`
- `lib/features/offline/domain/usecases/download_missing_pdfs.dart`
- `lib/features/offline/data/utils/zip_pdf_extractor.dart`
- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`

---

## #2 — Checkpoint intra-part não persiste `extractedPdfCount` — crash reprocessa part completa

**Categoria:** Confiabilidade  
**Impacto:** Alto  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`

### Problema

O checkpoint de resume do bulk download é salvo **após cada part ZIP concluída** (categoria + part index). Dentro de uma part, o campo `extractedPdfCount` existe no modelo, mas **nunca é atualizado incrementalmente** — é sempre zerado ao salvar pós-part:

```dart
// download_offline_packages.dart — checkpoint salvo pós-part
await _checkpointStore.save(OfflineBulkCheckpoint(
  categoryIndex: catIdx,
  partIndex: partIdx + 1,
  extractedPdfCount: 0, // sempre 0 — intra-part não rastreado
));
```

```dart
// extract_and_store_pdfs.dart — skip de PDFs já indexados no resume
// startFromPdfIndex é lido do checkpoint, mas nunca salvo incrementalmente
for (var i = startFromPdfIndex; i < entries.length; i++) {
  // extrai PDF...
  // sem salvar checkpoint aqui
}
```

Para um pacote ZIP com 500 PDFs (categoria completa), um crash após o PDF #450 significa re-extração completa dos 500 PDFs no próximo resume. O ZIP já está em disco (evita re-download), mas a extração e indexação Isar são repetidas.

### Solução recomendada

Persistir `extractedPdfCount` incrementalmente, em intervalos regulares, durante a extração:

```dart
// extract_and_store_pdfs.dart
const _checkpointInterval = 50; // salvar a cada N PDFs extraídos

for (var i = startFromPdfIndex; i < entries.length; i++) {
  // ... extrai e indexa PDF ...

  if ((i + 1) % _checkpointInterval == 0) {
    await onProgressCheckpoint?.call(i + 1); // callback para salvar checkpoint
  }
}
```

```dart
// download_offline_packages.dart — callback de checkpoint intra-part
await _extractAndStorePdfs(
  zipPath: zipPath,
  startFromPdfIndex: checkpoint?.extractedPdfCount ?? 0,
  onProgressCheckpoint: (count) async {
    await _checkpointStore.save(OfflineBulkCheckpoint(
      categoryIndex: catIdx,
      partIndex: partIdx,
      extractedPdfCount: count,
    ));
  },
);
```

O skip de PDFs já extraídos já funciona via `ExtractAndStorePdfs._isAlreadyIndexed` — o checkpoint apenas permite que o isolate inicie no índice correto sem re-processar o início do ZIP.

### Critério de aceite

- Crash após PDF #300 de 500 → resume retoma do PDF #300 (tolerância de ±`_checkpointInterval`).
- `extractedPdfCount` no checkpoint é atualizado a cada N PDFs durante a extração.
- PDFs já extraídos e indexados não são re-escritos no disco no resume.
- Testes de `DownloadOfflinePackages` simulam crash intra-part e verificam que o resume não re-extrai PDFs já indexados.

### Referências

- `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`
- `lib/features/offline/domain/usecases/download_offline_packages.dart`
- `lib/features/offline/data/datasources/offline_bulk_checkpoint_store.dart`
- `lib/features/offline/domain/entities/offline_bulk_checkpoint.dart`

---

## #3 — ZIP cacheado sem re-validação de integridade/tamanho — bulk aceita ZIP corrompido como válido

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/datasources/zip_package_downloader.dart`

### Problema

`ZipPackageDownloader.download` verifica se o ZIP já existe no disco antes de baixar:

```dart
// zip_package_downloader.dart — cache sem validação
final cachedZip = File(zipPath);
if (await cachedZip.exists()) {
  return zipPath; // retorna imediatamente, sem verificar tamanho ou integridade
}
// ... apenas se não existir: baixa e renomeia de .tmp
```

Cenários problemáticos:
- Download anterior foi interrompido antes do `rename` de `.tmp` → `.zip` (o `.tmp` foi limpo, mas o `.zip` ficou parcial em outra execução).
- Filesystem corrompeu o ZIP (problema de storage, queda de energia).
- O manifest foi atualizado com nova versão do ZIP (tamanho diferente), mas o ZIP antigo ainda existe.

Em qualquer caso, o `ZipDecoder` no isolate falha com exceção de parse, abortando a extração da part com erro opaco.

### Solução recomendada

Validar o ZIP cacheado contra o tamanho esperado do manifest antes de reutilizá-lo:

```dart
// zip_package_downloader.dart
Future<String> download(OfflinePackagePart part, {required String destDir}) async {
  final zipPath = p.join(destDir, part.filename);
  final cachedZip = File(zipPath);

  if (await cachedZip.exists()) {
    final stat = await FileStat.stat(zipPath);
    // Reutiliza apenas se tamanho bate com o manifest
    if (stat.size == part.size) return zipPath;
    // Tamanho divergente → apaga e re-baixa
    await cachedZip.delete();
  }

  // ... download normal via Dio + rename atômico
}
```

**Opcional** (maior confiabilidade, custo maior): validar CRC32 do primeiro entry do ZIP para detectar corrupção parcial sem baixar tudo novamente.

### Critério de aceite

- ZIP com tamanho diferente do `part.size` é re-baixado, não reutilizado.
- ZIP com tamanho correto é reutilizado sem novo download.
- Falha de parse no `ZipDecoder` por ZIP corrompido → mensagem de erro informativa (não erro genérico de objeto).

### Referências

- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `lib/features/offline/domain/entities/offline_manifest.dart` (`OfflinePackagePart.size`)

---

## #4 — `unmatchedEntries` do ZIP ignorado silenciosamente — PDFs faltantes nunca detectados no bulk

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`

### Problema

`ZipPdfExtractor.extract` retorna `ZipExtractResult` com o campo `unmatchedEntries`:

```dart
class ZipExtractResult {
  final List<String> extractedPdfIds;  // extraídos com sucesso
  final List<String> unmatchedEntries; // entries no ZIP sem pdfId correspondente no manifest
  // ...
}
```

Em `ExtractAndStorePdfs`, o resultado é processado, mas `unmatchedEntries` **nunca é consultado**:

```dart
// extract_and_store_pdfs.dart — unmatchedEntries ignorado
final result = await compute(_extractInIsolate, args);
// result.extractedPdfIds → indexado no Isar ✅
// result.unmatchedEntries → descartado ❌
```

Isso pode indicar:
- PDFs presentes no manifest mas ausentes no ZIP (manifest desatualizado).
- Erro na geração do ZIP no servidor.
- Renomeação de pdfId sem atualização do ZIP.

Esses PDFs nunca serão extraídos e **não aparecem como "faltantes"** nas stats (pois o manifest foi marcado como processado), criando inconsistência silenciosa entre o manifest e o índice local.

### Solução recomendada

Propagar e reportar `unmatchedEntries` no progresso do bulk download:

```dart
// extract_and_store_pdfs.dart — propagar unmatchedEntries
return ExtractResult(
  indexedCount: indexedIds.length,
  skippedCount: skippedIds.length,
  unmatchedPdfIds: result.unmatchedEntries, // ← exposto
);
```

```dart
// download_offline_packages.dart — logar e acumular
if (extractResult.unmatchedPdfIds.isNotEmpty) {
  _log.warning(
    'Part ${part.filename}: ${extractResult.unmatchedPdfIds.length} '
    'entries no ZIP sem correspondência no manifest: '
    '${extractResult.unmatchedPdfIds.take(5)}...',
  );
  unmatchedAccumulator.addAll(extractResult.unmatchedPdfIds);
}
```

Ao final do bulk, se `unmatchedAccumulator` não estiver vazio, o estado final pode expor `OfflineBulkState.completedWithWarnings` com lista dos IDs para diagnóstico.

### Critério de aceite

- `unmatchedEntries` é propagado até o nível do orquestrador `DownloadOfflinePackages`.
- Log de warning contém os pdfIds não encontrados no ZIP.
- Estado final do bulk distingue `completedOk` de `completedWithWarnings`.
- Testes de `ExtractAndStorePdfs` verificam que `unmatchedEntries` não é descartado.

### Referências

- `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`
- `lib/features/offline/data/utils/zip_pdf_extractor.dart`
- `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`

---

## #5 — `GetOfflineStatsByCategory` engole falha de manifest — UI exibe "0 faltantes" com rede indisponível

**Categoria:** UX / Confiabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/domain/usecases/get_offline_stats_by_category.dart`

### Problema

`GetOfflineStatsByCategory` busca o manifest remoto para calcular quantos PDFs estão faltando. Quando a rede está indisponível (exatamente quando o usuário está no modo offline), a busca falha silenciosamente:

```dart
// get_offline_stats_by_category.dart
try {
  final manifest = await _manifestDatasource.fetchManifest();
  // ... calcula missingByCategory
} catch (_) {
  // falha silenciosa — missingByCategory fica vazio
  return OfflineStats(availableByCategory: {...}, missingByCategory: {});
}
```

O resultado: a tela `OfflineSettingsScreen` exibe "0 PDFs faltantes" quando o usuário está offline, dando a falsa impressão de que o acervo está completo.

### Solução recomendada

**Fase 1** — Cachear o manifest offline em memória ou persistência leve (SharedPreferences JSON):

```dart
// offline_manifest_remote_datasource.dart — cache em memória
OfflineManifest? _cachedManifest;
DateTime? _cacheTime;

Future<OfflineManifest> fetchManifest() async {
  if (_cachedManifest != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < const Duration(hours: 24)) {
    return _cachedManifest!;
  }
  final manifest = await _fetchFromNetwork();
  _cachedManifest = manifest;
  _cacheTime = DateTime.now();
  return manifest;
}
```

**Fase 2** — Distinguir "sem dados" de "dados desconhecidos" no estado de stats:

```dart
// OfflineStats — adicionar flag de confiabilidade
class OfflineStats {
  final bool missingCountReliable; // false se manifest não foi obtido
  final Map<OfflineMaterial, int> missingByCategory;
  // ...
}
```

Na UI, exibir "— faltantes (sem conexão)" quando `missingCountReliable == false`.

### Critério de aceite

- Sem rede: UI exibe indicador de "não foi possível calcular faltantes" em vez de "0 faltantes".
- Com rede: comportamento atual mantido.
- Após uma busca bem-sucedida, o manifest é reutilizado por até 24h sem nova rede.
- Testes de `GetOfflineStatsByCategory` cobrem cenário de falha de manifest com estado correto.

### Referências

- `lib/features/offline/domain/usecases/get_offline_stats_by_category.dart`
- `lib/features/offline/data/datasources/offline_manifest_remote_datasource.dart`
- `lib/features/offline/presentation/pages/offline_settings_screen.dart`

---

## #6 — Sem TTL nem re-sync incremental do catálogo Isar — `LouvorCache` pode ficar obsoleto indefinidamente

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/catalog/data/repositories/catalog_repository_impl.dart`

### Problema

O sync do catálogo ocorre a cada boot com rede disponível, fazendo `clear()` + `putAll()` (full-replace):

```dart
// catalog_repository_impl.dart — sem controle de freshness
Future<LouvoresManifest> loadManifest() async {
  try {
    final louvores = await _remote.fetchLouvores(); // GET /api/catalog/louvores
    await _local.saveLouvores(louvores);            // clear + putAll
    return LouvoresManifest(louvores: louvores);
  } catch (_) {
    final cached = await _local.loadLouvores();    // fallback silencioso
    return LouvoresManifest(louvores: cached);
  }
}
```

Problemas:
1. **Sem timestamp de última sync**: se o dispositivo fica offline por semanas, o catálogo Isar pode ter louvores desatualizados (renomeados, removidos, adicionados) sem qualquer aviso.
2. **Sem versionamento incremental**: full-replace reescreve todos os ~4600 itens a cada boot com rede — custo desnecessário quando nada mudou.
3. **`PollManifestChecksum` (UC-12) não implementado**: o endpoint de checksum existe mas nunca é chamado.
4. **Fallback silencioso**: usuário não sabe que está vendo dados desatualizados.

### Solução recomendada

**Fase 1 (mínimo viável)** — Persistir timestamp do último sync e exibir aviso se > N dias:

```dart
// CatalogSyncMetadataStore (SharedPreferences)
class CatalogSyncMetadataStore {
  static const _key = 'catalogLastSyncAt';

  Future<void> markSyncedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return value != null ? DateTime.tryParse(value) : null;
  }
}
```

```dart
// catalog_repository_impl.dart — expor freshness
final lastSync = await _syncMetadata.getLastSyncAt();
final isStale = lastSync == null ||
    DateTime.now().difference(lastSync) > const Duration(days: 7);
return LouvoresManifest(louvores: cached, isStale: isStale);
```

Na UI (`HomeScreen`), exibir banner discreto quando `isStale == true`:
> "Catálogo atualizado há mais de 7 dias. Conecte-se para atualizar."

**Fase 2 (melhoria)** — Implementar `PollManifestChecksum` (UC-12) para detecção rápida de mudanças sem re-download completo do catálogo.

### Critério de aceite

- Timestamp de sync é salvo após cada sync bem-sucedido.
- `LouvoresManifest.isStale` é `true` se `lastSyncAt` > 7 dias ou nunca sincronizado com rede.
- UI exibe banner de alerta quando catálogo está obsoleto.
- Testes de `CatalogRepositoryImpl` verificam `isStale` correto em cenários de sync recente e ausente.

### Referências

- `lib/features/catalog/data/repositories/catalog_repository_impl.dart`
- `lib/features/catalog/domain/usecases/poll_manifest_checksum.dart`
- `lib/features/catalog/presentation/providers/louvores_manifest_provider.dart`

---

## #7 — ZIP inteiro carregado em memória no isolate de extração — risco de OOM em pacotes grandes

**Categoria:** Performance / Memória  
**Impacto:** Médio  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/offline/data/utils/zip_pdf_extractor.dart`

### Problema

A extração de ZIP usa `readAsBytesSync()` dentro de um `Isolate.run` (via `compute`):

```dart
// zip_pdf_extractor.dart — isolate
static ZipExtractResult _extractInIsolate(_ZipExtractArgs args) {
  final bytes = File(args.zipPath).readAsBytesSync(); // ZIP inteiro em RAM!
  final archive = ZipDecoder().decodeBytes(bytes);
  // ...
}
```

Para pacotes ZIP de 50–200 MB (tamanho típico de uma categoria completa), isso alocará 50–200 MB adicionais na heap do isolate além do que já está na memória principal do app. Em dispositivos Android com limite de heap de 256 MB, isso pode resultar em `OutOfMemoryError` e crash do processo.

Adicionalmente, `ZipDecoder().decodeBytes()` descomprime e retém **todas** as entries do ZIP em memória antes de escrever qualquer arquivo — duplicando o uso de memória.

### Solução recomendada

Usar a API de streaming do pacote `archive` que permite processar entries sem carregar o ZIP inteiro:

```dart
// zip_pdf_extractor.dart — streaming
static ZipExtractResult _extractInIsolate(_ZipExtractArgs args) {
  final inputStream = InputFileStream(args.zipPath); // lê em chunks
  final archive = ZipDecoder().decodeStream(inputStream);

  final extractedPdfIds = <String>[];
  final unmatchedEntries = <String>[];

  for (final entry in archive) {
    if (!entry.isFile || !entry.name.endsWith('.pdf')) continue;
    // Processa entry sem manter todas em memória simultaneamente
    final pdfId = _pdfIdFromEntry(entry.name, args.manifest);
    if (pdfId == null) {
      unmatchedEntries.add(entry.name);
      continue;
    }
    if (args.alreadyIndexedIds.contains(pdfId)) continue;

    final outPath = p.join(args.destDir, '$pdfId.pdf');
    final outStream = OutputFileStream(outPath);
    entry.writeContent(outStream); // escreve diretamente em disco
    outStream.close();

    extractedPdfIds.add(pdfId);
  }

  inputStream.close();
  return ZipExtractResult(extractedPdfIds: extractedPdfIds, unmatchedEntries: unmatchedEntries);
}
```

**Nota:** Verificar se `InputFileStream` está disponível na versão do pacote `archive` em uso. Se não, avaliar upgrade ou alternativa via `dart:io` `ZipFile`.

### Critério de aceite

- Extração de ZIP de 100 MB não ultrapassa 30 MB de uso de heap adicional no isolate (medido via DevTools Memory).
- Comportamento de extração (pdfIds extraídos, unmatchedEntries) é idêntico à implementação atual.
- Testes de `ZipPdfExtractor` usam arquivo ZIP real e passam com a nova implementação.

### Referências

- `lib/features/offline/data/utils/zip_pdf_extractor.dart`
- `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`

---

## #8 — Quota LRU não se aplica ao bulk — acúmulo irrestrito de PDFs no disco pós-bulk

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/offline/domain/usecases/download_offline_packages.dart`

### Problema

A quota LRU de 500 MB (`OfflineConfig.defaultPdfCacheQuotaBytes`) é aplicada **somente** em downloads on-demand via `FetchAndStorePdf`:

```dart
// fetch_and_store_pdf.dart — aplica LRU
await _repository.evictOldestPdfs(
  quotaBytes: _config.pdfCacheQuotaBytes,
  excludePdfIds: {pdfId, ...favoritePdfIds},
);
```

O bulk download (`DownloadOfflinePackages`) **não aplica quota nem LRU**. PDFs extraídos de ZIPs ficam permanentes até:
1. Clear manual via `ClearOfflineCache`.
2. Uma eviction de download on-demand posterior (improvável se bulk cobriu tudo).

Cenário real: usuário faz bulk de todas as categorias (ex.: 4000 PDFs, 8 GB), depois baixa manualmente mais alguns. Disco fica cheio silenciosamente. O `DiskSpaceChecker` verifica apenas *antes* do bulk, mas não monitora durante ou após.

### Solução recomendada

Adicionar verificação de quota pós-bulk e expor tamanho total ocupado na tela de configurações:

```dart
// clear_offline_cache.dart (ou novo use case) — auditoria de uso
Future<int> getTotalOfflineBytes() async {
  final dir = Directory(await _localStore.pdfStoreDirectory);
  if (!await dir.exists()) return 0;
  int total = 0;
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) total += await entity.length();
  }
  return total;
}
```

Na `OfflineSettingsScreen`, exibir o espaço ocupado e o espaço livre restante:
> "Acervo offline: 6,2 GB  |  Disponível: 12,4 GB"

Para eviction progressiva do bulk (se necessário no futuro), o `ReconcileOfflineIndex` pode receber parâmetro de quota que aciona LRU pós-reconcile — mas isso é escopo de uma issue separada de maior esforço.

### Critério de aceite

- `OfflineSettingsScreen` exibe bytes totais em uso pelo acervo offline.
- Bytes livres são exibidos para o usuário tomar decisão consciente de liberar espaço.
- Cálculo de uso é feito de forma assíncrona sem bloquear a UI.
- Testes de `GetOfflineStatsByCategory` incluem `totalBytes` no retorno.

### Referências

- `lib/features/offline/domain/usecases/download_offline_packages.dart`
- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart`
- `lib/features/offline/presentation/pages/offline_settings_screen.dart`
- `lib/features/offline/data/datasources/disk_space_checker.dart`

---

## #9 — `findByPdfIds` com N queries Isar sequenciais — O(N) round-trips no bulk skip lookup

**Categoria:** Performance  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/datasources/offline_pdf_local_datasource.dart`

### Problema

Em `ExtractAndStorePdfs._buildAlreadyIndexedSet`, o datasource é consultado para verificar quais pdfIds já estão no índice antes da extração:

```dart
// offline_pdf_local_datasource.dart — N queries sequenciais
Future<Set<String>> findIndexedPdfIds(List<String> pdfIds) async {
  final result = <String>{};
  for (final id in pdfIds) {                    // loop O(N)
    final entry = await _isar.offlinePdfIndexes  // query Isar por pdfId
        .where()
        .pdfIdEqualTo(id)
        .findFirst();
    if (entry != null) result.add(id);
  }
  return result;
}
```

Para uma part ZIP com 500 PDFs, isso executa 500 queries Isar sequenciais. Cada query tem overhead de abertura de transação + índice lookup. Para 4000 PDFs (bulk completo), são 4000 round-trips antes de iniciar a extração.

### Solução recomendada

Usar query batch com `filter().anyOf()` ou buscar todos os pdfIds presentes e fazer diff em memória:

```dart
// offline_pdf_local_datasource.dart — query única
Future<Set<String>> findIndexedPdfIds(List<String> pdfIds) async {
  // Isar suporta anyOf para índices únicos
  final entries = await _isar.offlinePdfIndexes
      .where()
      .anyOf(pdfIds, (q, id) => q.pdfIdEqualTo(id))
      .findAll();
  return entries.map((e) => e.pdfId).toSet();
}
```

**Alternativa** (se `anyOf` não suportar o índice do `pdfId`): buscar todos os pdfIds do escopo da categoria com uma única query e fazer intersecção em memória:

```dart
final allInCategory = await _isar.offlinePdfIndexes
    .where()
    .categoryEqualTo(category)
    .findAll();
return allInCategory.map((e) => e.pdfId).toSet().intersection(pdfIds.toSet());
```

### Critério de aceite

- `findIndexedPdfIds(500 ids)` executa no máximo 2 queries Isar (independentemente do N).
- Resultado idêntico ao atual: retorna apenas pdfIds que estão no índice.
- Testes de `OfflinePdfLocalDatasource` verificam batch query.

### Referências

- `lib/features/offline/data/datasources/offline_pdf_local_datasource.dart`
- `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`

---

## #10 — `evictOldestPdfs` carrega todos os registros em memória para sort

**Categoria:** Performance  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`

### Problema

```dart
// offline_pdf_repository_impl.dart
Future<void> evictOldestPdfs({...}) async {
  final all = await _datasource.findAll(); // todos os registros do índice!
  all.sort((a, b) => (a.lastAccessedAt ?? a.downloadedAt)
      .compareTo(b.lastAccessedAt ?? b.downloadedAt));
  // ... remove os mais antigos
}
```

`findAll()` carrega todos os `OfflinePdfIndex` do Isar para a heap Dart. Com 4000+ PDFs, isso representa 4000 objetos Dart. O sort em memória tem custo O(N log N) e pressiona o GC.

### Solução recomendada

Usar a ordenação nativa do Isar e aplicar `limit` para trazer apenas os candidatos à eviction:

```dart
Future<void> evictOldestPdfs({
  required int quotaBytes,
  required Set<String> excludePdfIds,
}) async {
  // Calcula bytes em excesso
  final currentBytes = await _datasource.getTotalStoredBytes();
  if (currentBytes <= quotaBytes) return;

  final targetEvict = currentBytes - quotaBytes;
  int evictedBytes = 0;

  // Busca em lotes ordenados, do mais antigo ao mais novo
  const batchSize = 100;
  int offset = 0;

  while (evictedBytes < targetEvict) {
    final batch = await _datasource.findOldestNotIn(
      excludePdfIds: excludePdfIds,
      limit: batchSize,
      offset: offset,
    );
    if (batch.isEmpty) break;

    for (final entry in batch) {
      await _removeEntry(entry);
      evictedBytes += entry.fileSize;
      if (evictedBytes >= targetEvict) break;
    }
    offset += batchSize;
  }
}
```

Implementar `findOldestNotIn` no datasource usando `sortBy(lastAccessedAt).offset(offset).limit(limit)` do Isar.

### Critério de aceite

- `evictOldestPdfs` não carrega mais do que `batchSize` registros por iteração.
- Resultado de eviction (bytes removidos, PDFs removidos) é equivalente ao atual.
- Testes verificam que PDFs favoritos (`excludePdfIds`) não são evictados.

### Referências

- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`
- `lib/features/offline/data/datasources/offline_pdf_local_datasource.dart`

---

## #11 — `touchLastAccessed` emite write txn Isar a cada abertura de PDF

**Categoria:** Performance  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`

### Problema

```dart
// offline_pdf_repository_impl.dart
Future<LocalPdfSource?> lookup(String pdfId) async {
  final entry = await _datasource.findByPdfId(pdfId);
  if (entry == null) return null;
  final isValid = await _validateIndexFile(entry);
  if (!isValid) { ... }

  // Write txn Isar a cada abertura!
  await _datasource.touchLastAccessed(pdfId, DateTime.now());
  return LocalPdfSource(path: entry.storagePath, fromCache: true);
}
```

Cada abertura de PDF (incluindo no carousel) dispara uma **transação de escrita** no Isar para atualizar `lastAccessedAt`. Para o carousel em modo performance (sequência rápida de louvores no culto), isso gera várias write txns em sequência.

### Solução recomendada

Aplicar debounce no `touchLastAccessed` — atualizar apenas se a última atualização foi há mais de N minutos:

```dart
// offline_pdf_repository_impl.dart
static const _touchDebounce = Duration(minutes: 5);

Future<LocalPdfSource?> lookup(String pdfId) async {
  final entry = await _datasource.findByPdfId(pdfId);
  // ...
  final shouldTouch = entry.lastAccessedAt == null ||
      DateTime.now().difference(entry.lastAccessedAt!) > _touchDebounce;

  if (shouldTouch) {
    unawaited(_datasource.touchLastAccessed(pdfId, DateTime.now()));
  }

  return LocalPdfSource(path: entry.storagePath, fromCache: true);
}
```

O LRU continua funcionando corretamente: PDFs acessados recentemente têm `lastAccessedAt` atualizado, apenas com menor granularidade temporal.

### Critério de aceite

- Abrir o mesmo PDF múltiplas vezes em 5 minutos gera apenas **uma** write txn Isar.
- `lastAccessedAt` é atualizado corretamente para fins de LRU eviction.
- Testes de `OfflinePdfRepositoryImpl.lookup` verificam o comportamento de debounce.

### Referências

- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`
- `lib/features/offline/data/datasources/offline_pdf_local_datasource.dart`

---

## #12 — Reconcile faz scan recursivo do filesystem a cada foreground

**Categoria:** Performance  
**Impacto:** Baixo  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart`

### Problema

`OfflineLifecycleListener` dispara `ReconcileOfflineIndex` ao retornar ao foreground (debounce de 3s):

```dart
// offline_lifecycle_listener.dart
void _onResumed() {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(seconds: 3), () {
    ref.read(offlineReconcileProvider.notifier).reconcile();
  });
}
```

`ReconcileOfflineIndex` executa:
1. `_datasource.findAll()` — todos os registros Isar
2. Para cada entrada: `FileStat.stat()` (N syscalls)
3. `Directory.list(recursive: true)` — scan completo do diretório `plpcg_pdfs/`

Para 4000 PDFs, são 4000 syscalls + scan recursivo do filesystem. Isso ocorre **toda vez** que o usuário sai e volta ao app (lock/unlock, troca de app, notificações), mesmo que nenhum arquivo tenha mudado.

### Solução recomendada

Adicionar controle de frequência mínima entre reconciles (TTL de reconcile):

```dart
// offlineReconcileProvider — throttle de reconcile
static const _reconcileMinInterval = Duration(minutes: 30);
DateTime? _lastReconcileAt;

Future<void> reconcile() async {
  if (_lastReconcileAt != null &&
      DateTime.now().difference(_lastReconcileAt!) < _reconcileMinInterval) {
    return; // skip — reconcile recente
  }
  _lastReconcileAt = DateTime.now();
  // ... executa reconcile
}
```

Persistir `lastReconcileAt` em SharedPreferences para sobreviver a restarts do app.

**Opcional (melhoria de longo prazo):** usar `Directory.watch()` para detectar mudanças no filesystem em vez de scan periódico — mas esta API tem suporte limitado em plataformas móveis.

### Critério de aceite

- Reconcile não é executado mais de uma vez por 30 minutos.
- Primeira execução após cold start sempre executa (sem lastReconcileAt persistido).
- Após mudança real no filesystem (arquivo deletado externamente), reconcile detecta na próxima janela de 30 min.
- Testes de `OfflineReconcileNotifier` verificam skip de reconcile recente.

### Referências

- `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart`
- `lib/features/offline/presentation/providers/offline_reconcile_provider.dart`
- `lib/features/offline/domain/usecases/reconcile_offline_index.dart`

---

## #13 — Arquivos `.tmp` órfãos do `ZipPackageDownloader` não são limpos no cold start

**Categoria:** Confiabilidade  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/datasources/zip_package_downloader.dart`

### Problema

O `ZipPackageDownloader` usa escrita atômica: baixa para `{filename}.tmp` e renomeia para `{filename}.zip` ao concluir. Em caso de crash ou force-quit durante o download:

```dart
// zip_package_downloader.dart
final tmpFile = File('$zipPath.tmp');
// ... download para tmpFile ...
await tmpFile.rename(zipPath); // crash aqui? .tmp fica no disco
```

O arquivo `.tmp` é deletado apenas se a operação atual falha — não se o app foi morto antes de entrar no catch. No próximo cold start, o arquivo `.tmp` fica como lixo no diretório `_bulk_zips/`, acumulando ao longo do tempo (cada attempt de download gera um novo `.tmp`).

### Solução recomendada

Adicionar limpeza de `.tmp` órfãos no boot do app ou na inicialização do `OfflineProviders`:

```dart
// lib/features/offline/data/datasources/zip_package_downloader.dart
Future<void> cleanOrphanedTempFiles() async {
  final bulkZipsDir = Directory(await _bulkZipsDirectory);
  if (!await bulkZipsDir.exists()) return;
  await for (final entity in bulkZipsDir.list()) {
    if (entity is File && entity.path.endsWith('.tmp')) {
      try {
        await entity.delete();
      } on FileSystemException {
        // ignora — arquivo pode ter sido deletado concorrentemente
      }
    }
  }
}
```

Chamar `cleanOrphanedTempFiles()` durante a inicialização do provider ou no primeiro acesso ao `ZipPackageDownloader` (lazy init).

### Critério de aceite

- Arquivos `.tmp` no diretório `_bulk_zips/` são removidos no próximo cold start.
- Limpeza é assíncrona e não bloqueia o boot.
- Testes verificam que `.tmp` são removidos na inicialização.

### Referências

- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `lib/features/offline/data/providers/offline_providers.dart`

---

## #14 — `DiskSpaceChecker` retorna `null` → verificação de espaço ignorada em edge cases

**Categoria:** Confiabilidade  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/datasources/disk_space_checker.dart`

### Problema

```dart
// disk_space_checker.dart
Future<int?> getFreeBytes() async {
  try {
    return await DiskSpacePlus.getFreeDiskSpace; // null em simulador/edge cases
  } catch (_) {
    return null;
  }
}
```

```dart
// download_offline_packages.dart — null → skip
final freeBytes = await _diskSpaceChecker.getFreeBytes();
if (freeBytes == null) {
  // "Não foi possível verificar espaço — continua assim mesmo"
  return;
}
if (freeBytes < requiredBytes) throw InsufficientDiskSpaceException(...);
```

Em produção, `DiskSpacePlus` pode retornar `null` em alguns modelos Android ou em edge cases de filesystem. Quando `null`, o download prossegue **sem qualquer verificação de espaço**, podendo resultar em `IOException: No space left on device` durante a extração — erro muito mais difícil de recuperar do que `InsufficientDiskSpaceException`.

### Solução recomendada

Tratar `null` como "verificação indisponível" e aplicar política conservadora:

```dart
// download_offline_packages.dart
final freeBytes = await _diskSpaceChecker.getFreeBytes();
if (freeBytes != null && freeBytes < requiredBytes) {
  throw InsufficientDiskSpaceException(
    requiredBytes: requiredBytes,
    availableBytes: freeBytes,
  );
}
// freeBytes == null → log de aviso mas prossegue
if (freeBytes == null) {
  _log.warning('DiskSpaceChecker retornou null — verificação de espaço ignorada');
}
```

**Adicional:** capturar `IOException` com mensagem `No space left on device` durante download/extração e convertê-lo em `InsufficientDiskSpaceException` com `availableBytes: 0` para UI tratar adequadamente:

```dart
try {
  await _extractAndStorePdfs(...);
} on FileSystemException catch (e) {
  if (e.osError?.errorCode == 28 /* ENOSPC */) {
    throw const InsufficientDiskSpaceException(requiredBytes: -1, availableBytes: 0);
  }
  rethrow;
}
```

### Critério de aceite

- `DiskSpaceChecker` retornando `null` produz log de aviso mas não bloqueia download.
- `ENOSPC` durante extração é convertido em `InsufficientDiskSpaceException` com mensagem de UI adequada.
- Testes de `DownloadOfflinePackages` cobrem cenário de `getFreeBytes() == null`.

### Referências

- `lib/features/offline/data/datasources/disk_space_checker.dart`
- `lib/features/offline/domain/usecases/download_offline_packages.dart`
- `lib/features/offline/domain/exceptions/offline_bulk_exceptions.dart`

---

## #15 — `PollManifestChecksum` (UC-12) não implementado — sem detecção automática de catálogo desatualizado

**Categoria:** Confiabilidade  
**Impacto:** Baixo  
**Esforço:** Alto  
**Arquivo principal:** `lib/features/catalog/domain/usecases/poll_manifest_checksum.dart`

### Problema

```dart
// poll_manifest_checksum.dart
class PollManifestChecksum {
  Future<void> call() {
    throw UnimplementedError('UC-12');
  }
}
```

O endpoint `GET /api/catalog/checksum` já existe em `CatalogRemoteDatasource.fetchChecksum()`, mas nenhum código o chama. Sem polling de checksum:

- O catálogo só é atualizado no boot (full-replace).
- Não há detecção de mudança se o servidor atualizar o catálogo enquanto o app está em uso.
- Não há re-sync incremental: ou baixa tudo ou não baixa nada.

Este item é de menor urgência pois o catálogo tem refresh no boot, mas torna-se crítico para usuários que ficam dias sem reiniciar o app (ex.: líderes de louvor que deixam o app aberto).

### Solução recomendada

Implementar `PollManifestChecksum` com comparação de ETag ou hash:

```dart
// poll_manifest_checksum.dart
class PollManifestChecksum {
  Future<bool> call() async {
    final remoteChecksum = await _remote.fetchChecksum();
    final localChecksum = await _checksumStore.getLastKnownChecksum();

    if (remoteChecksum == localChecksum) return false; // sem mudança

    // Catálogo mudou — disparar sync
    await _catalogRepo.syncFromRemote();
    await _checksumStore.saveChecksum(remoteChecksum);
    return true;
  }
}
```

Chamar `PollManifestChecksum` via `OfflineLifecycleListener` ao retornar ao foreground (após o debounce), paralelamente ao reconcile.

### Critério de aceite

- `GET /api/catalog/checksum` é chamado ao retornar ao foreground (máximo 1x por 30 min).
- Catálogo é re-sincronizado automaticamente quando checksum remoto difere do local.
- Sem mudança de checksum → nenhum download adicional.
- Testes de `PollManifestChecksum` cobrem cenários: checksum igual, checksum diferente, falha de rede.

### Referências

- `lib/features/catalog/domain/usecases/poll_manifest_checksum.dart`
- `lib/features/catalog/data/datasources/catalog_remote_datasource.dart`
- `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart`

---

## Divisão sugerida por subagente

Para execução paralela, os itens podem ser agrupados em tarefas independentes:

| Subagente | Items | Descrição | Dependências |
|-----------|-------|-----------|-------------|
| **offline-integrity-agent** | #1, #3, #4 | Centraliza validação de integridade (magic bytes), re-validação de ZIP cacheado e propagação de `unmatchedEntries` | Nenhuma — pode rodar imediatamente |
| **offline-checkpoint-agent** | #2 | Implementa checkpoint intra-part com `onProgressCheckpoint` callback | Nenhuma |
| **offline-ux-stats-agent** | #5, #6 | Cache do manifest offline + TTL/staleness do catálogo com banner UI | Nenhuma |
| **offline-perf-queries-agent** | #9, #10, #11 | Otimiza queries Isar: batch `findByPdfIds`, paginação `evictOldestPdfs`, debounce `touchLastAccessed` | Nenhuma |
| **offline-memory-bulk-agent** | #7, #8 | ZIP streaming no isolate + auditoria de uso de disco na UI | #1 deve estar completo para que extração streaming também valide magic bytes |
| **offline-housekeeping-agent** | #12, #13, #14 | Throttle de reconcile + limpeza de `.tmp` no boot + ENOSPC handling | Nenhuma |
| **offline-checksum-poll-agent** | #15 | Implementa `PollManifestChecksum` UC-12 completo | #6 (TTL de catálogo) deve estar completo para coordenação |
