# Backlog de Performance e Estabilidade — `/leitor` (PLPCG Flutter)

**Criado em:** 2026-06-13  
**Origem:** auditoria estática do pipeline completo do leitor PDF — armazenamento, resolução, download, abertura, renderização, cache, carousel e offline  
**Público:** agentes de correção / engenheiros responsáveis pela feature `pdf_reader` e `offline`

O `/leitor` é a feature mais crítica do app: é o motivo principal pelo qual o usuário abre o aplicativo. Falhas aqui equivalem a falha total do produto.

---

## Priorização

| #  | Item | Categoria | Impacto | Esforço |
|----|------|-----------|---------|---------|
| 1  | `Uint8List.fromList` duplica buffer completo do PDF em memória | Performance / Memória | Alto | Baixo |
| 2  | `ResolvePdfForReader` faz dois queries Isar separados no miss com rede | Performance | Alto | Baixo |
| 3  | `ensurePlaylistForLouvor` executa sequencialmente antes de navegar | Performance (UX) | Alto | Baixo |
| 4  | `PdfDocument.openFile` no thread principal — parse bloqueia UI | Performance / Jank | Alto | Médio |
| 5  | Sem indicador de progresso de download antes de entrar no `/leitor` | UX / Estabilidade | Alto | Médio |
| 6  | `pdfReaderSessionProvider` descarta e re-parseia PDF a cada troca no carousel | Performance | Médio | Médio |
| 7  | `_hasValidIndexFile` faz dois syscalls separados (`exists` + `length`) | Performance | Médio | Baixo |
| 8  | Sem prefetch do próximo/anterior PDF no carousel in-reader | Performance (UX) | Médio | Médio |
| 9  | Sem verificação de integridade do PDF em disco (magic bytes `%PDF`) | Confiabilidade | Médio | Baixo |
| 10 | Sem LRU / quota de disco para o cache de PDFs | Confiabilidade | Médio | Alto |
| 11 | Retry com backoff linear — deveria ser exponencial com jitter | Confiabilidade | Médio | Baixo |
| 12 | `applyFitMode` tem `catch (Object)` silencioso — esconde erros reais | Estabilidade | Médio | Baixo |
| 13 | PDF corrompido em disco → retry infinito sem recuperação | Confiabilidade | Médio | Baixo |
| 14 | Swipe horizontal sem feedback visual durante o arraste | UX | Baixo | Médio |
| 15 | Sem timeout específico no download de PDF (herda global do Dio) | Confiabilidade | Baixo | Baixo |
| 16 | Skeleton/shimmer ausente enquanto `pdfReaderSessionProvider` carrega | UX | Baixo | Baixo |

**Ordem sugerida de correção:** 1 → 2 → 3 → 9 → 13 → 12 → 11 → 15 → 7 → 4 → 5 → 6 → 8 → 10 → 14 → 16

---

## #1 — `Uint8List.fromList` duplica buffer completo do PDF em memória

**Categoria:** Performance / Memória  
**Impacto:** Alto  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart`

### Problema

```dart
// _fetchRemote — linha 33–41
final response = await _dio.get<List<int>>(
  url,
  options: Options(responseType: ResponseType.bytes),
);
final data = response.data; // List<int> alocado internamente pelo Dio
return Uint8List.fromList(data); // CÓPIA COMPLETA do buffer!
```

`Dio` com `ResponseType.bytes` retorna internamente um `List<int>` que pode ou não ser um `Uint8List`. `Uint8List.fromList(List<int>)` **sempre cria uma cópia completa**. Para um PDF de 2 MB há portanto 4 MB alocados simultaneamente na heap Dart — o original da resposta Dio e a cópia. Para downloads simultâneos (ex.: carousel prefetch) isso se multiplica.

### Solução recomendada

Tipar a resposta como `Uint8List` diretamente:

```dart
final response = await _dio.get<List<int>>(
  url,
  options: Options(responseType: ResponseType.bytes),
);
final data = response.data;
if (data == null || data.isEmpty) throw Exception('Resposta PDF vazia');
// Se Dio já retornou Uint8List, evita cópia; caso contrário, copia uma única vez.
return data is Uint8List ? data : Uint8List.fromList(data);
```

Verificar também se em Dio 5+ `responseType: ResponseType.bytes` com `List<int>` genérico já retorna `Uint8List` internamente (confirmar via `data.runtimeType`). Se sim, o cast elimina a cópia sem modificar comportamento.

### Critério de aceite

- Nenhum `Uint8List.fromList` executado quando Dio já retorna `Uint8List`.
- Testes existentes de `PdfBytesDatasource` continuam passando.
- Memory profiler mostra pico de alocação reduzido em ~50% para download de PDF.

### Referências

- `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart` (linha 32–41)
- `test/unit/features/pdf_opening/pdf_bytes_datasource_test.dart`

---

## #2 — `ResolvePdfForReader` faz dois queries Isar separados no miss com rede

**Categoria:** Performance  
**Impacto:** Alto  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart`

### Problema

```dart
// resolve_pdf_for_reader.dart — linhas 23–32
final entry = await _repository.lookup(pdfId);   // query Isar #1 + File.exists + File.length
if (entry != null) { return ...; }

final hasStaleIndex = await _repository.findIndexEntry(pdfId) != null; // query Isar #2!
```

Quando há um **miss de cache** e **falha de rede**, o código executa duas queries Isar para o mesmo `pdfId`:

1. `lookup` → Isar + filesystem (entry existe mas arquivo inválido → `null`)
2. `findIndexEntry` → Isar novamente (sem filesystem) para saber se havia entrada

Na sequência comum (hit de cache), `lookup` retorna na primeira consulta. Mas no cenário de arquivo corrompido/apagado sem rede — exatamente o mais crítico —, paga-se o custo de dois round-trips ao Isar.

Além disso, `lookup` já tem o resultado da query Isar internamente mas descarta a entrada quando o arquivo não existe, obrigando `findIndexEntry` a re-consultar.

### Solução recomendada

Modificar `OfflinePdfRepository.lookup` para retornar um tipo discriminado que exponha tanto o estado do índice quanto do arquivo:

```dart
// Opção A — retornar tupla (indexEntry, isFileValid)
Future<(OfflinePdfEntry?, bool hasIndex)> lookupWithIndexState(String pdfId);

// Opção B — modificar ResolvePdfForReader para receber o resultado de lookup
// internamente com acesso ao índice bruto
```

Ou, mais simples: modificar `OfflinePdfRepositoryImpl.lookup` para retornar `OfflinePdfEntry?` mesmo quando o arquivo está inválido e adicionar um campo `isFileValid` — assim o resolver toma decisão com um único round-trip.

### Critério de aceite

- Apenas **uma** query Isar por `pdfId` no caminho de falha de rede.
- Comportamento de exceções (`PdfExternallyDeletedException` vs `PdfOfflineUnavailableException`) preservado.
- Testes unitários de `ResolvePdfForReader` e `OfflinePdfRepositoryImpl` continuam passando.

### Referências

- `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart`
- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`
- `test/unit/features/offline/`

---

## #3 — `ensurePlaylistForLouvor` executa sequencialmente antes de navegar

**Categoria:** Performance (UX — latência percebida)  
**Impacto:** Alto  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/catalog/presentation/utils/open_louvor_in_reader.dart`

### Problema

```dart
// open_louvor_in_reader.dart — linhas 21–38
final source = await ref.read(resolvePdfForReaderProvider)(...);  // (1) pode incluir download
if (!context.mounted) return;

await ref.read(playlistsProvider.notifier).ensurePlaylistForLouvor(louvor.pdfId); // (2) Isar
if (!context.mounted) return;

await context.push(location); // (3) navegação
```

O `ensurePlaylistForLouvor` — operação de escrita no Isar para registrar histórico — é **aguardada** antes da navegação para `/leitor`. O usuário experimenta a latência combinada de `resolve` + `ensurePlaylist` antes de ver qualquer coisa. Esta operação Isar não precisa completar antes de abrir o leitor.

### Solução recomendada

Executar `ensurePlaylistForLouvor` de forma **fire-and-forget** (ou `unawaited`) após o push:

```dart
final source = await ref.read(resolvePdfForReaderProvider)(...);
if (!context.mounted) return;

final location = ref.read(openPdfInReaderProvider).call(...);
unawaited(context.push(location)); // navega imediatamente
// fire-and-forget: não bloqueia UX
ref.read(playlistsProvider.notifier).ensurePlaylistForLouvor(louvor.pdfId).ignore();
```

Verificar se `ensurePlaylistForLouvor` é idempotente e não pode falhar de forma que afete o leitor. Se sim, `ignore()` é seguro.

### Critério de aceite

- Navegação para `/leitor` ocorre sem aguardar `ensurePlaylistForLouvor`.
- O histórico/playlist é registrado corretamente (mesmo que com pequeno delay).
- Testes de integração de abertura do leitor validam que navegação não regride.

### Referências

- `lib/features/catalog/presentation/utils/open_louvor_in_reader.dart`
- `lib/features/playlists/`

---

## #4 — `PdfDocument.openFile` no thread principal bloqueia UI

**Categoria:** Performance / Jank  
**Impacto:** Alto  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart`

### Problema

```dart
// pdfrx_viewer_adapter.dart — linhas 69–75
Future<PdfDocument> _openDocument(ResolvedPdfSource source) {
  return switch (source.kind) {
    PdfSourceKind.localFile => PdfDocument.openFile(source.value),
    // ...
  };
}
```

`PdfDocument.openFile` realiza I/O e parsing inicial do arquivo PDF. Para PDFs com muitas páginas ou estrutura complexa, esse parse inicial pode levar dezenas a centenas de milissegundos. Em Flutter, **qualquer operação assíncrona que use plataform channels ainda tem overhead no thread principal** de Dart. O método retorna um `Future`, mas a inicialização do plugin nativo pode inserir frames lentos.

Adicionalmente, `pdfReaderSessionProvider` awaita o `openDocument` antes de retornar a sessão — enquanto carrega, a tela exibe apenas `CircularProgressIndicator`, sem contexto ao usuário.

### Solução recomendada

1. Garantir que a abertura ocorra o mais próximo possível do momento da navegação (já é assim), mas adicionar instrumentação com `Timeline.startSync`/`finish` para medir o custo real no profiler.
2. Investigar se `PDFx` expõe API para pré-alocar o documento em background (via `Isolate` ou channel separado).
3. Se o tempo de parse for > 100ms para PDFs comuns, avaliar migração para `PdfDocument.openData` com bytes pré-carregados via `Isolate.run` antes da navegação.

### Critério de aceite

- Time-to-first-page (desde tap até primeira página visível) < 500ms para PDFs já em cache.
- Sem frames dropped (janks) durante a abertura medidos no DevTools.

### Referências

- `lib/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart`
- `lib/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart`

---

## #5 — Sem indicador de progresso de download antes de entrar no `/leitor`

**Categoria:** UX / Estabilidade  
**Impacto:** Alto  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/catalog/presentation/utils/open_louvor_in_reader.dart`

### Problema

Quando o PDF não está em cache e precisa ser baixado, `openLouvorInReader` bloqueia silenciosamente enquanto `ResolvePdfForReader` → `FetchAndStorePdf` → `PdfBytesDatasource.fetchBytes` executa o download. Para conexões lentas (3G, 50–200 KB/s), um PDF de 1–3 MB leva 5–60 segundos. Durante todo esse tempo:

- O card do louvor não tem feedback visual de carregamento.
- O usuário não sabe se o app travou ou se está baixando.
- O botão pode ser tocado múltiplas vezes (sem debounce), iniciando downloads duplicados.

`FetchAndStorePdf` já tem retry mas **não expõe progresso de bytes**.

### Solução recomendada

1. Adicionar estado de loading no card/botão de abertura enquanto `resolve` está em andamento:

```dart
// LouvorGroupCard ou similar
ref.watch(loadingLouvorProvider(louvor.pdfId)) // AsyncValue<void>
```

2. Modificar `PdfBytesDatasource._fetchRemote` para aceitar `ProgressCallback` do Dio:

```dart
final response = await _dio.get<List<int>>(
  url,
  options: Options(responseType: ResponseType.bytes),
  onReceiveProgress: onProgress, // bytes recebidos / total
);
```

3. Expor progresso via `StreamProvider` ou `StateProvider` para o card.

4. Debounce no tap (guard `_isLoading` no card) para evitar downloads duplicados.

### Critério de aceite

- Card mostra loading indicator durante download.
- Download duplicado para o mesmo `pdfId` não é iniciado enquanto um está em andamento.
- Progresso em bytes é exibido (ex.: "Baixando... 45%") para downloads > 500ms.

### Referências

- `lib/features/catalog/presentation/utils/open_louvor_in_reader.dart`
- `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart`
- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart`

---

## #6 — `pdfReaderSessionProvider` descarta e re-parseia PDF a cada troca no carousel

**Categoria:** Performance  
**Impacto:** Médio  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart`

### Problema

```dart
final pdfReaderSessionProvider = FutureProvider.autoDispose
    .family<PdfReaderSession, String>((ref, filePath) async { ... });
```

`autoDispose` garante que ao sair do leitor o controller seja descartado (correto). Porém, ao trocar de PDF no carousel, o fluxo é:

1. `readerCarouselActionsProvider.navigateToPdfId` → nova rota `/leitor?file=novo_path`
2. Widget rebuilda com novo `filePath` → novo `pdfReaderSessionProvider(novoPath)`
3. Provider anterior é descartado (dispose do controller antigo)
4. Novo provider abre `PdfDocument` do zero — parse completo novamente

Para uso típico de carousel (tocar músicas adjacentes durante culto), o usuário frequentemente volta ao PDF anterior. Não há retenção mínima de sessões recentes.

### Solução recomendada

Implementar um **cache LRU de sessões** com capacidade pequena (ex.: 2–3 entradas):

```dart
// Manter últimas N sessões abertas sem dispose imediato
final pdfSessionCacheProvider = Provider<PdfSessionCache>((ref) => PdfSessionCache(maxSize: 2));
```

O cache retém `PdfReaderViewerHandle` para os últimos N PDFs visitados, descartando o mais antigo quando a capacidade é excedida. O `pdfReaderSessionProvider` consulta o cache antes de `openDocument`.

**Nota:** O FEATURE_INDEX documenta que reutilizar controller causa canvas vazio — isso se aplica ao mesmo controller em duas instâncias do widget. Um cache de sessões por `filePath` (com controller dedicado por path) não tem esse problema.

### Critério de aceite

- Voltar para PDF anterior no carousel não re-parseia o documento (tempo < 50ms).
- Máximo de 2–3 PDFs em memória simultaneamente.
- `autoDispose` ainda funciona ao sair completamente do `/leitor`.

### Referências

- `lib/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart`
- `lib/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart`

---

## #7 — `_hasValidIndexFile` faz dois syscalls separados (`exists` + `length`)

**Categoria:** Performance  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`

### Problema

```dart
static Future<bool> _hasValidIndexFile(OfflinePdfIndex index) async {
  final file = File(index.storagePath);
  if (!await file.exists()) return false;   // syscall 1: stat()
  return await file.length() > 0;           // syscall 2: stat() de novo
}
```

`File.exists()` e `File.length()` são implementados como chamadas separadas ao SO (via `dart:io`). Em `lookupBatch`, isso é chamado em paralelo para grupos de 50 arquivos — 100 syscalls por batch. Ambas as informações estão disponíveis em uma única chamada `FileStat.stat()`.

### Solução recomendada

```dart
static Future<bool> _hasValidIndexFile(OfflinePdfIndex index) async {
  final stat = await FileStat.stat(index.storagePath);
  return stat.type == FileSystemEntityType.file && stat.size > 0;
}
```

`FileStat.stat` faz um único `lstat` syscall e retorna tipo + tamanho.

### Critério de aceite

- `_hasValidIndexFile` realiza apenas um syscall por arquivo.
- `lookupBatch` mantém resultado idêntico ao atual.
- Testes existentes de `OfflinePdfRepositoryImpl` continuam passando.

### Referências

- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart` (linha 162–166)

---

## #8 — Sem prefetch do próximo/anterior PDF no carousel in-reader

**Categoria:** Performance (UX)  
**Impacto:** Médio  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart`

### Problema

Ao navegar no carousel (`CarouselChips`), o próximo PDF só começa a ser resolvido/baixado **após** o usuário tocar no item. Para PDFs não em cache, isso introduz a latência completa de download antes de qualquer conteúdo ser exibido.

O `readerCarouselPositionProvider(pdfId)` já conhece a posição atual no carousel e, portanto, quais são os vizinhos imediatos.

### Solução recomendada

Quando o leitor está ativo em `/leitor`, observar a posição do carousel e iniciar `ValidatePdfAvailability` + `ResolvePdfForReader` (sem navegar) para os N vizinhos do PDF atual:

```dart
// Em pdfReaderSessionProvider ou notifier dedicado:
// Quando sessão carrega, disparar prefetch dos vizinhos
ref.listen(pdfReaderSessionProvider(filePath), (_, next) {
  next.whenData((_) {
    _prefetchAdjacentPdfs(ref, currentPdfId);
  });
});
```

O prefetch deve ser **fire-and-forget** com prioridade baixa (após o PDF atual estar visível) e respeitar modo de rede (não prefetch em dados móveis sem consentimento).

### Critério de aceite

- PDF seguinte no carousel está em cache local antes de o usuário tocar nele (para WiFi).
- Prefetch não atrasa abertura do PDF atual.
- Sem prefetch automático em conexão de dados móveis (configurável).

### Referências

- `lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart`
- `lib/features/pdf_reader/domain/usecases/navigate_carousel_in_reader.dart`
- `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart`

---

## #9 — Sem verificação de integridade do PDF em disco (magic bytes)

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`

### Problema

`_hasValidIndexFile` valida apenas existência + tamanho > 0:

```dart
if (!await file.exists()) return false;
return await file.length() > 0;
```

Um arquivo de 1 byte não-PDF passará nessa validação. Corrupção de escrita (interrupção durante `writeAtomic`, filesystem cheio, bug de sistema) pode resultar em arquivo com tamanho > 0 mas conteúdo inválido. Nesse caso:

- `lookup` retorna entrada "válida"
- `pdfReaderSessionProvider` tenta `PdfDocument.openFile` e **falha com erro nativo**
- Usuário vê mensagem de erro e botão "Tentar novamente" — mas o retry lê o mesmo arquivo corrompido novamente (ver #13)

### Solução recomendada

Adicionar verificação do header PDF (4 bytes: `%PDF`):

```dart
static Future<bool> _hasValidIndexFile(OfflinePdfIndex index) async {
  final stat = await FileStat.stat(index.storagePath);
  if (stat.type != FileSystemEntityType.file || stat.size < 4) return false;

  final raf = await File(index.storagePath).open();
  try {
    final header = await raf.read(4);
    return header.length == 4 &&
        header[0] == 0x25 && // %
        header[1] == 0x50 && // P
        header[2] == 0x44 && // D
        header[3] == 0x46;   // F
  } finally {
    await raf.close();
  }
}
```

### Critério de aceite

- PDF corrompido (header inválido) é detectado em `lookup` antes de abrir no PDFx.
- Arquivo inválido é removido do índice e do disco automaticamente ao ser detectado.
- Testes cobrem: arquivo vazio, arquivo com bytes aleatórios, PDF válido, PDF truncado.

### Referências

- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart` (linha 162–166)
- `lib/features/offline/data/datasources/pdf_local_store.dart`

---

## #10 — Sem LRU / quota de disco para o cache de PDFs

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Alto  
**Arquivo principal:** `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`

### Problema

PDFs são baixados on-demand e armazenados em `documents/plpcg_pdfs/` sem limite. Com ~4600 louvores e PDFs de ~500 KB a 2 MB cada, o cache pode crescer para **2–9 GB**. Sem gestão de quota:

- O dispositivo pode ficar sem espaço em disco.
- Usuários não têm como controlar o uso de armazenamento além de "Limpar cache offline" (wipe total).
- Não há diferenciação entre PDFs "quentes" (acesso recente) e "frios" (nunca mais abertos).

O `OfflinePdfIndex` já armazena `downloadedAt` mas não `lastAccessedAt`.

### Solução recomendada

1. Adicionar campo `lastAccessedAt` ao `OfflinePdfIndex` — atualizado a cada `lookup` bem-sucedido.
2. Implementar `EvictOldestPdfs(targetBytes)` baseado em LRU sobre `lastAccessedAt`.
3. Verificar espaço disponível antes de cada download em `FetchAndStorePdf`.
4. Configurar quota máxima padrão (ex.: 500 MB) com override nas configurações do app.

### Critério de aceite

- Cache não ultrapassa quota configurada.
- Eviction remove PDFs menos recentes sem afetar os favoritos/marcados pelo usuário.
- `GetOfflineStatsByCategory` inclui uso total de disco.

### Referências

- `lib/core/database/collections/offline_pdf_index.dart`
- `lib/features/offline/domain/usecases/`
- `lib/features/offline/data/datasources/pdf_local_store.dart`

---

## #11 — Retry com backoff linear — deveria ser exponencial com jitter

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart`

### Problema

```dart
// fetch_and_store_pdf.dart — linha 70
await Future<void>.delayed(OfflineConfig.retryBackoffBase * attempt);
// attempt=1 → 1× base; attempt=2 → 2× base; attempt=3 → 3× base
```

Backoff linear (`base * attempt`) em cenários de sobrecarga do servidor resulta em múltiplos clientes tentando ao mesmo tempo nos mesmos intervalos (thundering herd). Sem jitter, todos os retries chegam sincronizados.

### Solução recomendada

Backoff exponencial com jitter:

```dart
final jitter = Random().nextDouble() * 0.3; // ±30%
final delay = OfflineConfig.retryBackoffBase * (1 << (attempt - 1)) * (1.0 + jitter);
await Future<void>.delayed(delay.clamp(Duration.zero, OfflineConfig.maxRetryDelay));
```

Adicionar `OfflineConfig.maxRetryDelay` (ex.: 30 segundos) como teto.

### Critério de aceite

- Delay entre retries é exponencial (dobra a cada tentativa).
- Jitter de ±30% aplicado a cada delay.
- Delay não ultrapassa `maxRetryDelay`.
- Testes de `FetchAndStorePdf` adaptados para mock de tempo.

### Referências

- `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart` (linha 57–80)
- `lib/core/constants/offline_config.dart`

---

## #12 — `applyFitMode` tem `catch (Object)` silencioso

**Categoria:** Estabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart`

### Problema

```dart
// pdfrx_viewer_adapter.dart — linhas 117–133
try {
  // cálculo e aplicação do fit mode...
} on Object {
  // Controller ainda não anexado ao PdfViewer (pdfrx).
}
```

O comentário justifica o catch para o caso do controller não estar ainda anexado — caso válido. Porém, o catch genérico `on Object` captura **qualquer** exceção, incluindo erros de programação (`StateError`, `RangeError`, null pointer de `getPageRect`, etc.). Erros reais em `_calculatePageHeightFitMatrix` (ex.: `pageRect.height == 0`, overflow em `scale`) passam silenciosamente.

### Solução recomendada

Restringir o catch ao erro específico esperado ou logar o erro:

```dart
try {
  // ...
} on AssertionError {
  // Controller não anexado ainda — esperado, ignorar silenciosamente.
} on Object catch (e, st) {
  // Logar para rastreabilidade sem propagar (melhor que suprimir completamente).
  debugPrint('[PdfrxViewerAdapter.applyFitMode] $e\n$st');
}
```

Ou, preferível, verificar o estado do controller antes do try:

```dart
if (!_isControllerReady(controller)) return; // sem try/catch
final matrix = _calculate...;
await controller.goTo(destination: matrix!);
```

### Critério de aceite

- Erros reais em `applyFitMode` são logados (não suprimidos).
- O caso legítimo de "controller não anexado" continua sem propagar.
- Testes cobrem cenário de pageRect nulo, height zero.

### Referências

- `lib/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart` (linhas 110–133)

---

## #13 — PDF corrompido em disco → retry infinito sem recuperação automática

**Categoria:** Confiabilidade  
**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart`

### Problema

```dart
// pdf_reader_screen.dart — linha 175–177
error: (error, _) => _ReaderMessage(
  onRetry: () => ref.invalidate(pdfReaderSessionProvider(filePath)),
),
```

Ao `invalidate`, o provider re-abre o mesmo `filePath`. Se o PDF em disco está corrompido (arquivo existe com tamanho > 0 mas inválido), o retry tentará `PdfDocument.openFile` do mesmo arquivo corrompido, falhará novamente, e o usuário ficará preso em um loop de "Tentar novamente" sem saída.

O correto é, na falha de abertura de arquivo local, marcar o arquivo como inválido (remover do índice e disco) e acionar re-download.

### Solução recomendada

Em `pdfReaderSessionProvider`, ao capturar falha de `openDocument` para arquivos locais, tentar recuperação:

```dart
try {
  final controller = await adapter.openDocument(filePath);
  // ...
} on PdfCorruptedException catch (_) {
  // Arquivo local corrompido → invalidar cache e re-resolver
  await ref.read(offlinePdfRepositoryProvider).remove(pdfId);
  // Re-lançar com tipo específico para UI oferecer "Baixar novamente"
  throw PdfLocalCorruptedException(pdfId: pdfId);
}
```

A UI diferencia `PdfLocalCorruptedException` (oferecer "Baixar novamente") de `PdfOfflineUnavailableException` (sem rede).

### Critério de aceite

- PDF corrompido em disco é detectado, removido do cache e re-baixado automaticamente ou com prompt ao usuário.
- Usuário não fica em loop infinito de retry para o mesmo arquivo corrompido.
- Testes cobrem cenário de arquivo corrompido → recovery.

### Referências

- `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` (linha 170–177)
- `lib/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart`
- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`

---

## #14 — Swipe horizontal sem feedback visual durante o arraste

**Categoria:** UX  
**Impacto:** Baixo  
**Esforço:** Médio  
**Arquivo principal:** `lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart`

### Problema

O swipe horizontal (troca de página) só produz efeito no `onPointerUp` — sem nenhum feedback visual durante o arraste. Para um gesto que o usuário precisa "aprender" (direita→esquerda = próxima página), a ausência de feedback reduz a descoberta e a confiança no gesto. Além disso, `_pageTurnInProgress` bloqueia novos swipes mas sem indicar ao usuário que a transição está ocorrendo.

### Solução recomendada

Adicionar feedback visual sutil durante o arraste horizontal:

1. Sobrepor indicador direcional (`>` / `<`) com `Opacity` reduzida quando `_accumulatedDelta.dx` ultrapassa o threshold de `PdfPageSwipePolicy.minHorizontalDx`.
2. Ou usar `HapticFeedback.lightImpact()` ao atingir o threshold de swipe.

### Critério de aceite

- Usuário recebe feedback tátil ou visual ao atingir threshold de swipe.
- Indicador não interfere com pan/zoom (aparece apenas durante swipe puro).

### Referências

- `lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart`
- `lib/features/pdf_reader/presentation/utils/pdf_page_swipe_policy.dart`

---

## #15 — Sem timeout específico no download de PDF

**Categoria:** Confiabilidade  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart`

### Problema

`PdfBytesDatasource._fetchRemote` usa o timeout global configurado no `Dio` compartilhado. Se o timeout global for alto (ou ausente), downloads de PDF pendurados podem bloquear a abertura por tempo indefinido sem feedback ao usuário.

PDFs podem ser grandes (1–5 MB). Um timeout de `receiveTimeout` de 30s pode ser insuficiente em conexões lentas; um de 60s pode parecer freeze ao usuário.

### Solução recomendada

Passar `Options` com timeout específico por request de PDF:

```dart
Future<Uint8List> _fetchRemote(String url) async {
  final response = await _dio.get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      receiveTimeout: const Duration(seconds: 120), // ajustar conforme tamanho médio
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  // ...
}
```

Integrar com `OfflineConfig` para tornar configurável.

### Critério de aceite

- Timeout de download de PDF é independente do timeout global do Dio.
- Timeout configurável em `OfflineConfig`.

### Referências

- `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart` (linha 31–42)
- `lib/core/constants/offline_config.dart`

---

## #16 — Skeleton/shimmer ausente enquanto `pdfReaderSessionProvider` carrega

**Categoria:** UX  
**Impacto:** Baixo  
**Esforço:** Baixo  
**Arquivo principal:** `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart`

### Problema

```dart
loading: () => const Center(
  child: CircularProgressIndicator(color: AppColors.gold),
),
```

Durante o loading do `pdfReaderSessionProvider` (parse do `PdfDocument`), a tela exibe apenas um spinner centralizado em fundo preto. Para PDFs em cache com abertura rápida (< 300ms), este estado é imperceptível. Para PDFs grandes ou dispositivos lentos, o usuário vê fundo preto + spinner por 500ms–2s, sem contexto do que está carregando.

### Solução recomendada

Adicionar skeleton de página PDF: um `Container` com proporção A4 (210:297), cor de fundo levemente cinza/sépia, e shimmer animation — simula a aparência de uma página PDF enquanto carrega. Exibir também o título do louvor na toolbar durante loading (atualmente `showTitle: false`).

```dart
loading: () => const PdfPageSkeleton(), // widget shimmer proporção A4
```

### Critério de aceite

- Loading state exibe skeleton contextual (não spinner genérico).
- Título do louvor é visível na toolbar durante loading.
- Skeleton não adiciona dependência externa além das já existentes.

### Referências

- `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` (linha 170–175)

---

## Notas de implementação

### Prioridade absoluta: #9 e #13

Os itens #9 (integridade do arquivo) e #13 (recovery de arquivo corrompido) são pré-requisitos de confiabilidade: sem eles, qualquer falha de escrita em disco resulta em estado irrecuperável pelo usuário. Devem ser implementados antes dos itens de performance.

### Itens que se complementam

- **#9 + #13**: verificar integridade em `lookup` elimina o cenário de #13 antes de abrir o PDFx.
- **#2 + #7**: ambos reduzem I/O no hot path de abertura — implementar juntos.
- **#1 + #15**: ambos estão em `PdfBytesDatasource` — implementar na mesma PR.
- **#6 + #8**: cache de sessão e prefetch são complementares para UX de carousel fluído.

### Não regredir

- A escrita atômica (`.tmp` → rename) em `PdfLocalStore.writeAtomic` é correta e não deve ser alterada.
- O `autoDispose` do `pdfReaderSessionProvider` é necessário e não deve ser removido — apenas complementado com cache de sessão (#6).
- O `ValueKey(controller)` em `PdfReaderPdfView` é intencional (evita canvas vazio) — manter.
- Não reutilizar o mesmo `PdfReaderViewerHandle` em duas instâncias de widget.
