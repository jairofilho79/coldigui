# Backlog de Confiabilidade e Performance — Download Offline (PLPCG Flutter)

**Criado em:** 2026-06-13  
**Origem:** incidente em produção — downloads bulk lentos, aparentemente travados, interrompidos com mensagem *"Há um download offline interrompido"*; auditoria do pipeline `ZipPackageDownloader` → `DownloadOfflinePackages` → `ExtractAndStorePdfs`  
**Complementa:** `docs/OFFLINE_PERFORMANCE_BACKLOG.md` (integridade, checkpoints, LRU — já parcialmente implementados)  
**Público:** agentes de correção / skill `plpcg-performance-auditor`

O modo offline depende de baixar pacotes ZIP de dezenas a centenas de MB via rede móvel. O backlog anterior tratou integridade pós-download; **este documento trata o pipeline de transferência em si** — timeouts, retries, progresso, resume e persistência confiável dos PDFs.

---

## Diagnóstico resumido

| Sintoma relatado | Causa provável no código |
|------------------|--------------------------|
| Download "travado" (barra parada) | Fase `fetching` não atualiza `donePdfs`; ZIP de 50–200 MB baixa sem `onReceiveProgress` |
| Download interrompido | `ZipPackageDownloader` herda `receiveTimeout: 30s` do Dio global; stall de rede > 30s entre chunks → `DioExceptionType.receiveTimeout` |
| Lentidão geral | Sem retry com backoff; falha no primeiro timeout; recomeço do zero (sem resume HTTP Range) |
| PDFs não salvos | Falhas silenciosas em `_writeEntryAtomic` (`return null`); extração inteira em `compute` sem progresso intermediário |

**Contraste com PDF on-demand:** `PdfBytesDatasource._fetchRemote` já usa `receiveTimeout: 120s` via `OfflineConfig.pdfDownloadReceiveTimeout`. O bulk ZIP **não** aplica override — usa apenas `_dio.download(url, path)` sem `Options`.

```dart
// lib/core/providers/dio_provider.dart — timeout global herdado pelo bulk
receiveTimeout: const Duration(seconds: 30),

// lib/features/offline/data/datasources/zip_package_downloader.dart — sem Options
await _dio.download(absoluteUrl, tmp.path, cancelToken: cancelToken);

// lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart — on-demand OK
options: Options(receiveTimeout: OfflineConfig.pdfDownloadReceiveTimeout), // 120s
```

---

## Priorização

| #  | Item | Categoria | Impacto | Esforço |
|----|------|-----------|---------|---------|
| 1  | Bulk ZIP herda `receiveTimeout` de 30s — pacotes grandes falham em rede instável | Confiabilidade | **Crítico** | Baixo |
| 2  | Sem retry com backoff no download de ZIP (on-demand PDF já retenta) | Confiabilidade | **Alto** | Baixo |
| 3  | Sem progresso byte-a-byte na fase `fetching` — UI parece travada | UX / Performance | **Alto** | Médio |
| 4  | Sem validação de tamanho pós-download antes do `rename` `.tmp` → `.zip` | Confiabilidade | **Alto** | Baixo |
| 5  | Extração ZIP monolítica em `compute` — barra parada na fase `extracting` | UX / Performance | Médio | Médio |
| 6  | Erros de rede/timeout mapeados para mensagem genérica `offlineDownloadError` | UX | Médio | Baixo |
| 7  | Falhas de escrita/validação de PDF na extração descartadas silenciosamente | Confiabilidade | Médio | Baixo |
| 8  | Sem resume HTTP Range — download parcial reinicia do zero | Performance | Médio | Alto |
| 9  | App em background (iOS) pode suspender socket → stall > timeout | Confiabilidade | Médio | Médio |
| 10 | `DownloadMissingPdfs` sequencial — N PDFs = N round-trips sem paralelismo | Performance | Baixo | Médio |
| 11 | Reconcile pós-categoria compete por I/O com extração em andamento | Performance | Baixo | Baixo |
| 12 | Sem wakelock/foreground service durante bulk prolongado | UX | Baixo | Médio |

**Ordem sugerida de correção:** 1 → 4 → 2 → 3 → 6 → 7 → 5 → 9 → 8 → 10 → 11 → 12

**Quick win (resolver incidente hoje):** itens **#1 + #4 + #2** — estimativa < 2h de implementação + testes.

---

## #1 — Bulk ZIP herda `receiveTimeout` de 30s

**Categoria:** Confiabilidade  
**Impacto:** Crítico  
**Esforço:** Baixo  
**Arquivos principais:**
- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `lib/core/constants/offline_config.dart`
- `lib/core/providers/dio_provider.dart`

### Problema

`ZipPackageDownloader.download` chama `_dio.download()` **sem `Options`**, herdando `receiveTimeout: Duration(seconds: 30)` do `dioProvider`.

No Dio 5.x, `receiveTimeout` é um watchdog **entre eventos de dados** (não tempo total). Porém, em redes móveis instáveis, backgrounding do app, ou buffering do CDN R2, é comum haver gaps > 30s entre chunks — especialmente no **primeiro byte** (handshake TLS + cold CDN).

Pacotes ZIP típicos: **50–200 MB** por part. Um PDF on-demand (1–5 MB) tolera 120s; um ZIP de 150 MB na mesma rede **não pode** usar timeout mais restritivo que o de PDF.

Cenário reproduzível:
1. Usuário inicia bulk de Partitura (3+ parts, ~80 MB cada).
2. Fase `fetching` — barra não se move (`donePdfs` estático).
3. Após ~30s sem chunk (rede lenta ou app minimizado), Dio lança `receiveTimeout`.
4. `OfflineBulkDownloadNotifier` captura `Object` genérico → `offlineDownloadError` + checkpoint salvo → banner *"download interrompido"*.

### Solução recomendada

**Fase 1 (mínimo):** constantes dedicadas e override por request:

```dart
// offline_config.dart
/// Watchdog inter-chunk para download de ZIP bulk (UC-09).
/// `Duration.zero` = sem limite (recomendado para arquivos grandes).
static const Duration zipDownloadReceiveTimeout = Duration.zero;
static const Duration zipDownloadConnectTimeout = Duration(seconds: 60);
static const Duration zipDownloadSendTimeout = Duration(seconds: 30);
```

```dart
// zip_package_downloader.dart
await _dio.download(
  absoluteUrl,
  tmp.path,
  cancelToken: cancelToken,
  options: Options(
    receiveTimeout: OfflineConfig.zipDownloadReceiveTimeout,
    sendTimeout: OfflineConfig.zipDownloadSendTimeout,
  ),
);
```

**Fase 2 (opcional):** Dio dedicado para bulk (clone com timeouts distintos) para não afetar requests REST rápidos.

### Critério de aceite

- Download de ZIP de 100 MB em rede simulada com latência 5s entre chunks **não** falha por timeout.
- `ZipPackageDownloader` não herda `receiveTimeout` global de 30s.
- Teste unitário verifica que `Options.receiveTimeout` passado ao `download` é `OfflineConfig.zipDownloadReceiveTimeout`.
- Teste de integração (ou mock com adapter fake) simula stall de 45s entre chunks e confirma que download **continua** (com `Duration.zero`).

### Referências

- `lib/core/providers/dio_provider.dart`
- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart` (padrão de referência)
- [Dio README — receiveTimeout semantics](https://github.com/cfug/dio/blob/main/dio/README.md)

---

## #2 — Sem retry com backoff no download de ZIP

**Categoria:** Confiabilidade  
**Impacto:** Alto  
**Esforço:** Baixo  
**Arquivos principais:**
- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart` (padrão existente)

### Problema

`FetchAndStorePdf._fetchBytesWithRetry` retenta até `OfflineConfig.maxRetryAttempts` (3) com backoff exponencial para `connectionTimeout`, `receiveTimeout`, `connectionError` e HTTP ≥ 500.

`ZipPackageDownloader.download` **não retenta**: qualquer `DioException` transitória aborta a part inteira e propaga para `DownloadOfflinePackages`, que salva checkpoint mas força o usuário a retomar manualmente.

Em culto/ensaio com rede instável, uma falha momentânea no meio de um ZIP de 80 MB significa perder o progresso da part (`.tmp` é deletado no `catch`).

### Solução recomendada

Extrair lógica de retry compartilhada ou replicar o padrão de `FetchAndStorePdf`:

```dart
// zip_package_downloader.dart
Future<String> download({...}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= OfflineConfig.maxRetryAttempts; attempt++) {
    try {
      return await _downloadOnce(...);
    } on DioException catch (e) {
      lastError = e;
      if (!_isRetryable(e) || attempt >= OfflineConfig.maxRetryAttempts) rethrow;
      await Future<void>.delayed(retryDelayForAttempt(attempt));
      // Limpar .tmp parcial antes de retentar
      if (await tmp.exists()) await tmp.delete();
    }
  }
  throw lastError ?? StateError('download falhou');
}
```

Reutilizar `retryDelayForAttempt` e `_isRetryable` de `fetch_and_store_pdf.dart` (extrair para `lib/features/offline/domain/utils/download_retry.dart`).

### Critério de aceite

- Falha `receiveTimeout` na 1ª tentativa + sucesso na 2ª → ZIP salvo corretamente.
- Após 3 falhas consecutivas, exceção propagada (comportamento atual de abort).
- `.tmp` parcial removido entre tentativas.
- Testes cobrem retry em timeout e sucesso na segunda tentativa.

### Referências

- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart`
- `lib/features/offline/data/datasources/zip_package_downloader.dart`

---

## #3 — Sem progresso byte-a-byte na fase `fetching`

**Categoria:** UX / Performance  
**Impacto:** Alto  
**Esforço:** Médio  
**Arquivos principais:**
- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `lib/features/offline/domain/entities/offline_download_progress.dart`
- `lib/features/offline/domain/usecases/download_offline_packages.dart`
- `lib/features/offline/presentation/pages/offline_settings_screen.dart`

### Problema

Durante `OfflineDownloadPhase.fetching`, `OfflineDownloadProgress.donePdfs` **não avança** — só muda quando a extração começa. A barra (`pdfFraction`) fica congelada por minutos enquanto um ZIP de 50–200 MB baixa.

O usuário interpreta como travamento e cancela (ou o SO mata o app em background), gerando o banner de *download interrompido*.

`_ProgressSection` usa apenas `progress.pdfFraction` — não há indicador de bytes do ZIP atual.

### Solução recomendada

**Fase 1:** adicionar campos opcionais de progresso de transferência:

```dart
class OfflineDownloadProgress {
  // ... campos existentes ...
  final int? zipBytesReceived;
  final int? zipBytesTotal;
}
```

**Fase 2:** propagar `onReceiveProgress` do Dio:

```dart
// zip_package_downloader.dart
Future<String> download({
  ...
  void Function(int received, int total)? onReceiveProgress,
}) async {
  await _dio.download(
    absoluteUrl,
    tmp.path,
    onReceiveProgress: onReceiveProgress,
    ...
  );
}
```

```dart
// download_offline_packages.dart — durante fetching
onProgress?.call(OfflineDownloadProgress(
  phase: OfflineDownloadPhase.fetching,
  zipBytesReceived: received,
  zipBytesTotal: total > 0 ? total : part.size,
  ...
));
```

**Fase 3:** na UI, usar `zipBytesReceived / zipBytesTotal` quando `phase == fetching`, senão `pdfFraction`.

### Critério de aceite

- Durante download de ZIP, barra de progresso se move continuamente.
- Texto exibe "Baixando pacote X/Y — 45 MB / 82 MB" (ou equivalente l10n).
- Fases `extracting`/`storing` mantêm progresso por PDF como hoje.
- Teste de widget ou provider verifica atualização de progresso com mock de `onReceiveProgress`.

### Referências

- `lib/features/offline/domain/entities/offline_download_progress.dart`
- `lib/features/offline/presentation/pages/offline_settings_screen.dart` (`_ProgressSection`)

---

## #4 — Sem validação de tamanho pós-download antes do `rename`

**Categoria:** Confiabilidade  
**Impacto:** Alto  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/datasources/zip_package_downloader.dart`

### Problema

Após `_dio.download` para `.tmp`, o código faz `rename` imediato para `.zip` **sem verificar** se o tamanho no disco corresponde a `expectedSize` do manifest.

Cenários:
- Resposta HTTP truncada (conexão caiu no último chunk mas Dio não lançou exceção).
- Proxy/CDN retorna HTML de erro com status 200 (corpo pequeno).
- Timeout parcial deixa `.tmp` incompleto se retry não limpar corretamente.

O cache hit (`stat.size == expectedSize`) valida ZIPs **antigos**, mas o **recém-baixado** não é validado antes de ser aceito. `ZipDecoder` falha depois, na extração — erro opaco e part perdida.

### Solução recomendada

```dart
await _dio.download(...);

final stat = await FileStat.stat(tmp.path);
if (expectedSize != null && stat.size != expectedSize) {
  await tmp.delete();
  throw ZipDownloadSizeMismatchException(
    expected: expectedSize,
    actual: stat.size,
    filename: filename,
  );
}

await tmp.rename(target.path);
```

Tratar `ZipDownloadSizeMismatchException` como retryable em #2.

### Critério de aceite

- `.tmp` com tamanho ≠ `part.size` é rejeitado e não renomeado.
- Mismatch dispara retry (item #2) antes de falhar definitivamente.
- Teste: mock retorna 50% dos bytes → exceção de mismatch.

### Referências

- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `docs/OFFLINE_PERFORMANCE_BACKLOG.md` #3 (validação de cache — complementar)

---

## #5 — Extração ZIP monolítica em `compute` — barra parada na fase `extracting`

**Categoria:** UX / Performance  
**Impacto:** Médio  
**Esforço:** Médio  
**Arquivos principais:**
- `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`
- `lib/features/offline/data/utils/zip_pdf_extractor.dart`

### Problema

`ExtractAndStorePdfs` chama `compute(extractZipPdfs, ...)` **uma vez** por part. Todo o ZIP é processado no isolate antes de retornar à main thread. Durante `OfflineDownloadPhase.extracting`, a UI não recebe callbacks — só passa para `storing` quando o isolate termina.

Para uma part com 500 PDFs (~80 MB ZIP), a extração pode levar 30–120s sem feedback. Combinado com #3, o usuário vê **dois períodos longos** sem movimento da barra (fetch + extract).

Nota: `zip_pdf_extractor.dart` já usa `InputFileStream` (streaming de entrada), mas `ZipDecoder().decodeStream` ainda materializa entries e o loop escreve todos os PDFs antes de retornar.

### Solução recomendada

**Fase 1 (rápida):** reportar progresso sintético — ao iniciar `compute`, emitir `extracting` com mensagem "Preparando extração..."; ao retornar, transicionar para `storing` com contagem real (já existe).

**Fase 2 (ideal):** extração incremental com `Isolate.run` + `SendPort` para reportar a cada N PDFs extraídos (sem esperar o ZIP inteiro):

```dart
// Padrão: ReceivePort no main, SendPort no isolate
void extractZipPdfsWithProgress(ZipExtractParams params, SendPort progressPort) {
  var count = 0;
  for (final entry in archive) {
    // ... extrai PDF ...
    count++;
    if (count % 25 == 0) {
      progressPort.send(ExtractProgress(count, params.expectedPdfIds.length));
    }
  }
}
```

Alternativa mais simples: mover extração para `Isolate.run` com callback via `Stream` (Riverpod `onProgress` no use case).

### Critério de aceite

- Fase `extracting` atualiza contador pelo menos a cada 25 PDFs ou 5s.
- Tempo total de extração não aumenta > 10% vs. implementação atual.
- Teste de benchmark existente (`reconcile_offline_index_benchmark_test.dart`) continua passando.

### Referências

- `lib/features/offline/data/utils/zip_pdf_extractor.dart`
- `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`
- `docs/OFFLINE_PERFORMANCE_BACKLOG.md` #7 (OOM — relacionado)

---

## #6 — Erros de rede/timeout mapeados para mensagem genérica

**Categoria:** UX  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivos principais:**
- `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`
- `lib/l10n/app_pt.arb`

### Problema

```dart
// offline_bulk_download_provider.dart
} on Object catch (_) {
  state = state.copyWith(
    status: OfflineBulkDownloadStatus.failed,
    errorMessage: 'offlineDownloadError', // genérico
    checkpoint: checkpoint,
  );
}
```

`DioExceptionType.receiveTimeout`, `connectionError` e `InsufficientDiskSpaceException` recebem a mesma mensagem. O usuário não sabe se deve tentar de novo, trocar de rede, ou liberar espaço.

O banner de resume (`offlineResumeBanner` = *"Há um download offline interrompido"*) aparece tanto para cancelamento manual quanto para timeout — sem distinção.

### Solução recomendada

Tratar exceções específicas:

```dart
} on DioException catch (e) {
  final key = switch (e.type) {
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionTimeout => 'offlineDownloadTimeout',
    DioExceptionType.connectionError => 'offlineDownloadNetworkError',
    _ => 'offlineDownloadError',
  };
  // ...
}
```

Adicionar strings l10n com orientação acionável:
- `offlineDownloadTimeout`: "Conexão lenta. Toque em Retomar quando a rede melhorar."
- `offlineDownloadNetworkError`: "Sem conexão. Verifique a internet e retome."

### Critério de aceite

- Timeout exibe mensagem específica (não genérica).
- Checkpoint permanece disponível para resume após timeout.
- Testes do notifier cobrem `DioException.receiveTimeout` → chave correta.

### Referências

- `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`
- `lib/l10n/app_pt.arb`

---

## #7 — Falhas de escrita/validação de PDF descartadas silenciosamente na extração

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/utils/zip_pdf_extractor.dart`

### Problema

`_writeEntryAtomic` retorna `null` em falha de escrita, magic bytes inválidos, ou `rename` — e o caller faz `continue` sem registrar:

```dart
final absolutePath = _writeEntryAtomic(entry, params.rootPath, relPath);
if (absolutePath == null) continue; // PDF esperado perdido silenciosamente
```

O bulk marca a part como concluída (`donePdfsGlobal += part.pdfs.length - startPdfIdx`) **sem verificar** quantos PDFs foram efetivamente extraídos vs. esperados. Stats posteriores mostram faltantes, mas o usuário acredita que o download terminou.

### Solução recomendada

Rastrear falhas na extração:

```dart
class ZipExtractResult {
  final List<ExtractedPdfItem> items;
  final List<String> unmatchedEntries;
  final List<String> failedPdfIds; // novo
  final List<String> failedReasons; // opcional, para log
}
```

Em `DownloadOfflinePackages`, comparar `extractResult.storedCount + skipped` com `part.pdfs.length`. Divergência → warning log + incluir em `completedWithWarnings`.

Reconcile pós-categoria já detecta faltantes, mas **após** o usuário ver "concluído".

### Critério de aceite

- PDF com magic bytes inválidos no ZIP aparece em `failedPdfIds`, não é contado como `done`.
- Estado final `completedWithWarnings` quando `failedPdfIds.isNotEmpty`.
- Teste: ZIP com 1 PDF corrompido → warning, não `completed` silencioso.

### Referências

- `lib/features/offline/data/utils/zip_pdf_extractor.dart`
- `lib/features/offline/domain/usecases/download_offline_packages.dart`

---

## #8 — Sem resume HTTP Range — download parcial reinicia do zero

**Categoria:** Performance  
**Impacto:** Médio  
**Esforço:** Alto  
**Arquivo principal:** `lib/features/offline/data/datasources/zip_package_downloader.dart`

### Problema

Quando download falha com `.tmp` parcial (ex.: 40 MB de 80 MB), o retry de #2 **deleta** o `.tmp` e recomeça do byte 0. Em rede instável, o mesmo ZIP pode ser baixado múltiplas vezes parcialmente — experiência lenta e frustante.

Cloudflare R2 suporta `Range: bytes=N-` em objetos estáticos servidos via `/packages/*.zip`.

### Solução recomendada

**Fase 1:** preservar `.tmp` parcial entre retries se tamanho < expectedSize:

```dart
if (await tmp.exists()) {
  final partial = await tmp.length();
  if (partial > 0 && partial < expectedSize!) {
  options: Options(headers: {'Range': 'bytes=$partial-'});
  // append mode ou download para temp e concatenar
  }
}
```

**Fase 2:** validar suporte a Range via `Accept-Ranges: bytes` no HEAD request antes de tentar.

### Critério de aceite

- Retry após falha aos 50% retoma do byte 50%, não do zero.
- ZIP final validado por tamanho (#4).
- Fallback para download completo se servidor não suportar Range.

### Referências

- `lib/features/offline/data/datasources/zip_package_downloader.dart`
- `MAPEAMENTO_PLPCG_FLUTTER.md` §2.3 — `/packages/**/*.zip`

---

## #9 — App em background suspende download (iOS)

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Médio  
**Arquivos principais:**
- `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart`
- `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`

### Problema

Bulk download roda no isolate principal do app (não é background task nativa). No iOS, ao minimizar o app:
- URLSession pode pausar por > 30s (antes do fix #1) ou indefinidamente.
- Ao retornar, download pode ter falhado silenciosamente ou socket resetado.

`OfflineLifecycleListener` não coordena com bulk download — apenas flush de `touchLastAccessed` no `paused`.

### Solução recomendada

**Fase 1:** banner na UI: "Mantenha o app aberto durante o download."

**Fase 2:** ao detectar `AppLifecycleState.paused` com bulk `running`, pausar graciosamente e salvar checkpoint (não deixar Dio pendurado).

**Fase 3 (longo prazo):** `background_downloader` ou `NSURLSession` background configuration para iOS; `WorkManager` no Android.

Combinar com #1 (`Duration.zero`) para que stalls temporâneos ao voltar ao foreground não abortem imediatamente.

### Critério de aceite

- Minimizar app durante bulk → ao retornar, estado é `failed` com checkpoint OU download continua (Fase 3).
- Documentação de limitação iOS na tela offline (Fase 1).
- Teste manual em dispositivo iOS real documentado no PR.

### Referências

- `lib/features/offline/presentation/widgets/offline_lifecycle_listener.dart`
- `MAPEAMENTO_PLPCG_FLUTTER.md` §9.2 — background download como motivação Flutter

---

## #10 — `DownloadMissingPdfs` sequencial sem paralelismo

**Categoria:** Performance  
**Impacto:** Baixo  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/offline/domain/usecases/download_missing_pdfs.dart`

### Problema

Loop sequencial com `await _fetchAndStorePdf(...)` por pdfId. Para 200 PDFs faltantes a ~2s cada = **6+ minutos**. Cada fetch já tem retry e timeout de 120s.

Não é a causa do incidente bulk ZIP, mas agrava percepção de lentidão na manutenção offline (UC-10).

### Solução recomendada

Pool de concorrência limitada (ex.: 3–5 downloads paralelos):

```dart
const _concurrency = 3;
await for (final result in Stream.fromIterable(missingPdfIds)
    .map((id) => _downloadOne(id))
    .bufferCount(_concurrency)) {
  // atualizar progresso
}
```

Ou pacote `pool` / semáforo manual. Respeitar quota LRU e espaço em disco.

### Critério de aceite

- 10 PDFs faltantes baixam em paralelo (≤ 4 conexões simultâneas).
- Falha em um PDF não aborta os demais.
- Testes de `DownloadMissingPdfs` passam com mock de concorrência.

### Referências

- `lib/features/offline/domain/usecases/download_missing_pdfs.dart`
- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart`

---

## #11 — Reconcile pós-categoria compete por I/O durante bulk

**Categoria:** Performance  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/domain/usecases/download_offline_packages.dart`

### Problema

Após cada categoria, `DownloadOfflinePackages` chama `_reconcileOfflineIndex` (scan filesystem + N × `FileStat`). Com 1500 PDFs recém-extraídos, isso adiciona segundos de I/O síncrono antes da próxima categoria — período em que a UI mostra `syncing` sem avançar PDFs.

### Solução recomendada

Adiar reconcile consolidado para o **final** do bulk (uma vez), ou executar em `unawaited` com flag de "reconcile pendente":

```dart
// Ao final de todas as categorias:
await _reconcileOfflineIndex.forAllProcessed(manifest, categories);
```

Manter reconcile por categoria apenas se necessário para stats intermediárias (avaliar remoção).

### Critério de aceite

- Bulk de 3 categorias executa ≤ 1 reconcile completo (não 3).
- Stats finais corretos após reconcile único.
- Tempo entre categorias reduzido (medir em benchmark).

### Referências

- `lib/features/offline/domain/usecases/download_offline_packages.dart`
- `docs/OFFLINE_PERFORMANCE_BACKLOG.md` #12 (throttle reconcile foreground)

---

## #12 — Sem wakelock durante bulk prolongado

**Categoria:** UX  
**Impacto:** Baixo  
**Esforço:** Médio  
**Arquivos principais:**
- `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`
- `pubspec.yaml` (nova dep `wakelock_plus` — requer aprovação)

### Problema

Tela do dispositivo desliga após timeout de inatividade. Em Android, isso pode reduzir prioridade de rede; usuário não vê progresso (#3) e assume falha.

### Solução recomendada

```dart
// Ao iniciar bulk:
await WakelockPlus.enable();
// Ao concluir/cancelar/falhar:
await WakelockPlus.disable();
```

Apenas enquanto `OfflineBulkDownloadStatus.running` e tela offline visível (opcional: só com flag "manter tela ligada").

### Critério de aceite

- Tela permanece ligada durante bulk ativo.
- Wakelock liberado em `dispose`, cancel e complete.
- Sem nova dep sem aprovação explícita do mantenedor.

### Referências

- `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`

---

## Divisão sugerida por subagente

| Subagente | Items | Descrição | Dependências |
|-----------|-------|-----------|-------------|
| **offline-download-timeout-agent** | #1, #4, #2 | Timeouts dedicados, validação pós-download, retry com backoff | Nenhuma — **prioridade máxima** |
| **offline-download-progress-agent** | #3, #5 | Progresso byte-a-byte no fetch + extração incremental | #1 recomendado antes (downloads não falham durante teste de UI) |
| **offline-download-ux-agent** | #6, #12 | Mensagens de erro específicas + wakelock | #1 |
| **offline-download-integrity-agent** | #7 | Rastrear PDFs falhos na extração | Nenhuma |
| **offline-download-resume-agent** | #8, #9 | HTTP Range resume + lifecycle background | #1, #2 |
| **offline-download-perf-agent** | #10, #11 | Paralelismo missing PDFs + reconcile adiado | Nenhuma |

---

## Métricas de sucesso (pós-correção)

| Métrica | Atual (estimado) | Meta |
|---------|------------------|------|
| Taxa de falha bulk em rede 4G instável | Alta (timeout 30s) | < 5% com retry |
| Tempo com barra congelada (fetch 80 MB) | 100% do download | 0% (progresso byte-a-byte) |
| ZIP truncado aceito como válido | Possível | 0 (validação tamanho) |
| PDFs perdidos silenciosamente na extração | Desconhecido | 0 (rastreados em warnings) |
| Retomada após falha parcial | Re-download completo | Resume do checkpoint + Range (fase 2) |

---

## Relação com backlog anterior

| Item `OFFLINE_PERFORMANCE_BACKLOG.md` | Status | Relação com este doc |
|---------------------------------------|--------|----------------------|
| #1 Magic bytes | ✅ Implementado | Complementa #7 (falhas na extração) |
| #2 Checkpoint intra-part | ✅ Implementado | Resume após timeout depende de #1 não falhar |
| #3 ZIP cache validação tamanho | ✅ Implementado | Complementa #4 (validação pós-download fresh) |
| #7 ZIP streaming | ✅ Parcial (`InputFileStream`) | #5 pede progresso incremental além do streaming |
| #13 Limpeza `.tmp` órfãos | ✅ Implementado | #2 limpa `.tmp` entre retries |

**Conclusão:** o backlog anterior melhorou integridade e resume de **extração**, mas não tratou **transferência HTTP** — gap que explica o incidente atual.

---

## Histórico

| Versão | Data | Alterações |
|--------|------|------------|
| 1.0 | 2026-06-13 | Documento inicial — auditoria pós-incidente de timeout/lentidão no bulk offline |
