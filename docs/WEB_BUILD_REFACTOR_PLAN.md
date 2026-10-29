# Plano de refatoração — desbloqueio do build Flutter Web

**Status:** **Implementado** — concluído em 04/07/2026; branch de integração `web/integration`
**Data:** julho de 2026 (execução Fase 8: 04/07/2026)
**Contexto:** O app hoje só está habilitado para Android/iOS (`.metadata` sem `platform: web`; sem pasta `web/`). Este documento mapeia **todos** os pontos de código, dependências e infraestrutura que bloqueiam ou arriscam o `flutter build web`, para que agentes futuros implementem em PRs pequenos e escopados — uma fase por vez, seguindo o padrão de [MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md).

Plano executado nas fases 0–8; relatório final de build: [web_phase8_build_report.md](web_phase8_build_report.md).

---

## Decisões do mantenedor

Registradas em jul/2026. **Agentes devem seguir estas decisões** — não reabrir escopo funcional sem nova confirmação do mantenedor.

| ID | Decisão | Escolha | Implicação para implementação |
|---|---|---|---|
| **D1** | Escopo offline na web (Fase 4) | **O3** — persistência real (paridade nativa) | Reimplementar `PdfLocalStore` web (OPFS ou IndexedDB); bulk UC-09/UC-10 disponível na web; maior esforço e mais PRs; ver [Fase 4](#fase-4--sistema-offline-nativo-uc-09uc-10-na-web). |
| **D2** | PDF local / abertura no leitor (Fase 3.1) | **OA** — adapter via bytes | Na web, **nunca** `PdfDocument.openFile(path)`; sempre `PdfDocument.openData(bytes)` no `PdfrxViewerAdapter`. Com D1 O3, bytes vêm do store persistente web (não de path de filesystem). |
| **D3** | “Salvar PDF” na web (Fase 3.2) | **OA** — download do browser | Disparar download do `.pdf` via blob/`anchor download`; não gravar em `ApplicationDocumentsDirectory`. |
| **D4** | Share PDF / folheto (Fase 3.2–3.3) | **OA** — `XFile.fromData` em todas as plataformas | Eliminar temp files para share onde possível; unificar nativo + web com `XFile.fromData(bytes, name:, mimeType:)`. |
| **D5** | Target de build web (Fase 6) | **`flutter build web --wasm`** | Usar renderer WASM; validar versão Flutter mínima; assets WASM de pdfrx/isar incluídos no artefato. |
| **D6** | Cabeçalhos COOP/COEP (Fase 6) | **OA** — configurar no hosting | `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` (ou `credentialless`) em **plpcjf.org**. |
| **D7** | Domínio de deploy (Fase 6) | **plpcjf.org** | Deploy inicial **não** altera `plpcg.com`; API pode continuar em `https://plpcg.com` (cross-origin) — validar CORS no worker. Criar `dart_defines/plpcjf.json` (ou equivalente) com `PLPCG_API_BASE_URL` apontando para a API correta. |
| **D8** | Branding PWA (Fase 6) | Nome completo **sim**; `short_name`: **PLPCG**; cores **confirmadas** (tokens `AppColors`); ícones **sim** (mesma fonte `assets/branding/app_icon_source.png`) | Preencher `web/manifest.json` e ícones 192/512 na Fase 6. |
| **D9** | CI e testes web (Fase 7) | **A + A** | Job `flutter build web --wasm` em **todo PR**; investir em `flutter test --platform chrome` **agora** (escopo mínimo: smoke dos fluxos críticos web). |
| **D10** | Ordem Fases 1 e 2 | **OA** — Fase 2 antes da Fase 1 | Sequência: **0 → 2 → 1 → 3 → 4 → 5 → 6 → 7**. |

### Nota D1 + D2 (interpretação unificada)

D1 O3 exige **storage persistente** de PDFs na web. D2 OA exige **abertura por bytes** no adapter (sem paths de filesystem). Implementação combinada:

```text
ResolvePdfForReader (web) → PdfWebStore (OPFS/IndexedDB) → Uint8List
  → PdfrxViewerAdapter → PdfDocument.openData(bytes)
```

Paths absolutos (`LocalPdfSource.absolutePath`) permanecem no contrato de domínio para nativo; na web, o adapter/resolver obtém bytes do store — **não** repassar path ao pdfrx.

### Comandos de build (pós-D5/D7)

```bash
flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json --release
flutter test --platform chrome   # D9
```

Criar `dart_defines/plpcjf.json` na Fase 6 (ou antes, se necessário para testes):

```json
{
  "PLPCG_API_BASE_URL": "https://plpcg.com"
}
```

> Ajustar URL se a API for publicada também em `plpcjf.org`. Enquanto o frontend estiver em `plpcjf.org` e a API em `plpcg.com`, **CORS é obrigatório** no worker `plpcg-catalog`.

---

## Instruções gerais para agentes futuros

1. Ler este documento **inteiro** antes de tocar em qualquer fase.
2. Ler [FEATURE_INDEX.md](features/FEATURE_INDEX.md) nas seções afetadas antes de codar.
4. Regra anti-overengineering do projeto: alterar só o necessário para a fase atual.
5. **Domínio** (`lib/features/*/domain/`) não deve importar pacotes de plataforma (`dart:io`, `path_provider`, `pdfrx`, etc.) — isso já é violado hoje em alguns usecases (ver Fase 2) e deve ser corrigido como parte da própria migração, não abstraído "por enquanto".
6. Toda abstração de plataforma introduzida deve seguir o padrão **já usado no projeto**: callback injetável (`typedef ...Fn`) ou porta de domínio (`abstract interface class`) — ver `GetApplicationDocumentsDirectoryFn`, `PdfReaderControllerPort` como referência.
7. Antes de entregar cada fase:
   ```bash
   flutter analyze
   flutter test
   flutter test --platform chrome   # D9 — smoke mínimo quando a fase tocar UI web
   flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json
   ```
8. Commit a cada fase concluída (após entregar a fase).
9. Não atualizar dependências não relacionadas à fase (Riverpod, go_router etc.) — ver [DEP_UPGRADE_BACKLOG.md](DEP_UPGRADE_BACKLOG.md).
10. Escopo funcional na web está **fechado** — ver [Decisões do mantenedor](#decisões-do-mantenedor). Não desviar (ex.: desabilitar offline bulk) sem nova confirmação.
11. Ordem de fases: **0 → 2 → 1 → 3 → 4a→4e → 5 → 6 → 7 → 8** (D10 + verificação final).

---

## Sumário executivo

| Categoria de bloqueio | Severidade | Fase proposta |
|---|---|---|
| Plataforma web nunca habilitada (`flutter create --platforms=web`) | Bloqueante | Fase 0 |
| `main.dart` — bootstrap Isar/pdfrx assume filesystem nativo | Bloqueante | Fase 1 |
| `path_provider` sem suporte web (`dart:io.Directory`) | Bloqueante | Fase 2 |
| 12 arquivos com `import 'dart:io'` em `lib/` | Bloqueante | Fase 2 / Fase 3 |
| `dart:isolate` (`Isolate.spawn`) na extração de ZIP bulk | Bloqueante | Fase 4 |
| `archive` (`InputFileStream`/`ZipDecoder`) baseado em `dart:io` | Bloqueante | Fase 4 |
| Storage local de PDFs (`PdfLocalStore`, `OfflinePdfIndex`) todo em disco | Bloqueante (para UC-09/UC-10 na web) | Fase 4 |
| Leitor PDF (`pdfrx`) abre `File` local — sem equivalente na web | Bloqueante | Fase 3 |
| Share/Save de PDF (`share_plus`, `SavePdf`) via `File`/`XFile(path)` | Bloqueante parcial | Fase 3 |
| Folheto (`leaflet_capture.dart`) grava PNG em `getTemporaryDirectory` | Bloqueante parcial | Fase 3 |
| `isar_plus` — precisa `Isar.initialize()` explícito + `directory` opcional na web | Risco médio | Fase 1 |
| `connectivity_plus` — suporte web limitado (`navigator.onLine`) | Risco baixo | Fase 5 |
| `app_links` — `app_links_web` cobre deep links via URL | Risco baixo | Fase 5 |
| `wakelock_plus` — usa `no_sleep.js`, requer autoplay/gesture em alguns browsers | Risco baixo | Fase 5 |
| `pdfrx` WASM — requer cabeçalhos COOP/COEP para `SharedArrayBuffer` (performance) | Risco médio | Fase 6 (infra/deploy) |
| PWA manifest/ícones/service worker | Necessário, não bloqueante para compilar | Fase 6 |
| CI/scripts assumem apenas iOS/Android | Risco baixo | Fase 7 |

---

## Fase 0 — Habilitar a plataforma web

**Objetivo:** permitir que `flutter build web` exista como target, sem ainda compilar com sucesso.

### Checklist

- [ ] Confirmar Flutter/Dart channel suporta web (`flutter doctor`, já deve suportar em stable).
- [ ] Rodar `flutter create . --platforms=web` na raiz do projeto.
- [ ] Revisar arquivos gerados:
  - `web/index.html`
  - `web/manifest.json`
  - `web/favicon.png`, `web/icons/*`
  - `.metadata` (nova entrada `platform: web`)
- [ ] Confirmar que `pubspec.yaml` não precisa de mudança de `environment.sdk` (`>=3.12.0 <4.0.0` já é compatível).
- [ ] Rodar `flutter build web` uma primeira vez **só para levantar a lista real de erros de compilação** — usar como checklist de validação cruzada com as fases seguintes (não corrigir nada nesta fase).

### Critérios de aceite

- [ ] Pasta `web/` presente e versionada.
- [ ] `.metadata` inclui plataforma `web`.
- [ ] Lista de erros do primeiro `flutter build web` documentada (anexar ao PR ou a um arquivo de log temporário) para comparação com as fases seguintes.

### Cuidados

- Não usar `--platforms=web,android,ios` sozinho sem revisar diffs em `android/` e `ios/` — preferir apenas `web` para minimizar ruído no diff.
- `flutter create` pode sobrescrever `.metadata`; revisar diff antes de commitar.

---

## Fase 1 — Bootstrap (`main.dart`) e inicialização de storage

**Objetivo:** `main()` funciona em ambos os mundos (nativo e web) sem duplicar lógica de negócio.

### Bloqueio atual

```16:30:lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();

  final dir = await getApplicationDocumentsDirectory();
  final isar = Isar.open(
    schemas: [...],
    directory: dir.path,
    name: 'plpcg_plus',
  );
  ...
}
```

`getApplicationDocumentsDirectory()` (`path_provider`) **não existe** na web (ver Fase 2). `Isar.open` sem `Isar.initialize()` prévio também falha na web — `isar_plus` documenta: *"Initialize Isar manually. This is required if you target web."*

### O que verificar/implementar

- [ ] Adicionar `await Isar.initialize()` condicional a `kIsWeb` (ou incondicional, se for no-op em nativo — checar changelog `isar_plus` 1.3.x).
- [ ] Abstrair obtenção de diretório do Isar:
  - Nativo: `getApplicationDocumentsDirectory().path` (comportamento atual).
  - Web: `directory` **omitido** ou vazio, conforme API `Isar.open` web (checar doc oficial `isarplus.ahmetaydin.dev` antes de codar — API pode exigir `directory: null` ou nome de "banco" IndexedDB diferente).
- [ ] Confirmar se `pdfrxFlutterInitialize()` precisa de flags/opções diferentes na web (ver Fase 3 — WASM/COOP-COEP).
- [ ] Isolar a lógica de bootstrap em uma função testável (ex.: `Future<Isar> openAppIsar()`) com implementação condicional por import condicional (`isar_bootstrap_native.dart` / `isar_bootstrap_web.dart` com `import ... if (dart.library.io) ...` ou `if (dart.library.js_interop) ...`), seguindo o padrão de conditional imports do Dart — **não** usar `kIsWeb` para decidir *qual `path_provider` chamar*, já que a chamada em si não compila na web (ver Fase 2).

### Critérios de aceite

- [ ] `main.dart` compila e roda em `flutter run -d chrome` sem lançar exceção no boot.
- [ ] Isar abre e persiste entre reloads (IndexedDB) — validado manualmente.
- [ ] Nenhuma regressão no boot nativo (iOS/Android) — `flutter test`, smoke manual.

### Cuidados

- **Não** misturar essa fase com a Fase 2 (path_provider) — mas note a dependência: Fase 1 só fecha de verdade depois que a Fase 2 fornecer a abstração de diretório usada aqui.
- Ler ADR-001 (Isar) antes de alterar; atualizar ADR-001 ao final com nota sobre suporte web.

---

## Fase 2 — Abstrair `path_provider` e uso de `dart:io` fora do storage de PDFs

**Objetivo:** remover a dependência direta de `dart:io`/`path_provider` das camadas que **não são** o núcleo do storage de PDFs offline (Fase 4), tornando-as web-compatíveis primeiro, por serem menores e mais isoladas.

### Por que `path_provider` bloqueia

`path_provider` é oficialmente **sem suporte a Flutter Web** (retorna erro em runtime; a API é baseada em `dart:io.Directory`, que não existe no compilador web). Isso não é um erro de compilação direto (o pacote resolve via plugin platform interface), mas **qualquer chamada em runtime na web falha** — e o uso de `Directory`/`File` diretamente (`dart:io`) **impede a compilação** do target web.

### Inventário completo de `dart:io` em `lib/`

| Arquivo | Uso principal | Fase de tratamento |
|---|---|---|
| `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart` | `AssetBundle`/remoto — só usa `Uint8List`, `dart:io` importado mas não estritamente necessário no fluxo remoto/asset | Fase 2 |
| `lib/features/pdf_opening/domain/usecases/save_pdf.dart` | `Directory`, `File.copy`, `writeAsBytes` — salvar PDF em disco | Fase 3 |
| `lib/features/pdf_opening/domain/usecases/share_pdf.dart` | `File`, `Directory` temp — share de PDF local | Fase 3 |
| `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart` | `File` do folheto para share | Fase 3 |
| `lib/features/leaflet/presentation/providers/leaflet_actions_provider.dart` | `File` do folheto para share | Fase 3 |
| `lib/features/leaflet/presentation/utils/leaflet_capture.dart` | `Directory` temp para PNG do folheto | Fase 3 |
| `lib/features/offline/data/datasources/pdf_local_store.dart` | `Directory`/`File` — store raiz de PDFs offline | Fase 4 |
| `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart` | `File`, `FileStat` — validação de magic bytes no disco | Fase 4 |
| `lib/features/offline/data/utils/pdf_integrity_validator.dart` | `File`, `FileStat` — validação síncrona/assíncrona | Fase 4 |
| `lib/features/offline/data/datasources/zip_package_downloader.dart` | `File`, `Directory` — download + resume via Range | Fase 4 |
| `lib/features/offline/data/utils/zip_pdf_extractor.dart` | `File`, `dart:isolate` — extração ZIP em isolate | Fase 4 |
| `lib/features/offline/domain/usecases/download_offline_packages.dart` | `dart:developer` + `dart:io` (indireto via chain) | Fase 4 |

> Nota: `pdf_bytes_datasource.dart` importa `dart:io` mas **não usa `File`/`Directory` diretamente no trecho revisado** — confirmar com `dart analyze` se o import é necessário (pode ser resquício); se não for usado, é candidato a remoção **nesta fase**, isolado, sem tocar no resto do arquivo.

### O que verificar/implementar nesta fase

- [ ] Rodar `grep -rn "import 'dart:io'" lib/` e `grep -rn "path_provider" lib/` para revalidar a lista acima antes de iniciar (o código pode ter mudado).
- [ ] Definir a estratégia de abstração de diretórios temporários usada pelo folheto/share (Fase 3) e documentá-la aqui antes de implementar — ver opções na Fase 3.
- [ ] Confirmar se `pdf_bytes_datasource.dart` precisa mesmo de `dart:io` — se não, remover import nesta fase como "quick win" isolado.
- [ ] Não alterar comportamento nativo — toda abstração deve manter 100% de paridade em iOS/Android.

### Critérios de aceite

- [ ] Import `dart:io` removido de `pdf_bytes_datasource.dart` (se confirmado não usado) ou justificado em comentário.
- [ ] Nenhuma outra mudança funcional nesta fase — é preparatória.
- [ ] `flutter test` verde.

---

## Fase 3 — Leitor de PDF, Share/Save e Folheto na web

**Objetivo:** tornar a UX central (abrir, compartilhar, salvar PDF; gerar folheto) funcional na web, mesmo que com fluxo diferente do nativo.

### 3.1 — Leitor PDF (`pdfrx`)

**Bloqueio:**

```68:78:lib/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart
    final documentFuture = switch (source.kind) {
      PdfSourceKind.remoteUrl => _openRemote(source.value),
      PdfSourceKind.asset => PdfDocument.openAsset(source.value),
      PdfSourceKind.localFile => PdfDocument.openFile(source.value),
    };
```

`PdfDocument.openFile` (path absoluto no filesystem) não existe conceito equivalente na web — não há filesystem nativo acessível por path. Isso só é atingido quando `PdfSourceKind.localFile` é resolvido — o que acontece **sempre** que o PDF já está no cache offline (Fase 4) ou salvo localmente.

**O que verificar/implementar:**

- [ ] Mapear todos os callers de `PdfrxViewerAdapter.openDocument` / `ResolvePdfForReader` que podem produzir `PdfSourceKind.localFile` na web.
- [ ] **Decisão D2 OA:** na web, adapter usa **sempre** `PdfDocument.openData(bytes)` — nunca `openFile(path)`. Com **D1 O3**, bytes vêm do store persistente web (Fase 4), não de rede direta em hit de cache.
- [ ] Qualquer que seja a plataforma, o adapter (`PdfrxViewerAdapter`) deve permanecer a **única** peça que sabe abrir documentos — não vazar `dart:io`/paths para o domínio.
- [ ] Confirmar inicialização WASM do pdfrx (`pdfrxFlutterInitialize()`) e necessidade de assets `pdfium.wasm` (empacotados automaticamente pelo pacote desde a versão usada — confirmar changelog).

### 3.2 — Compartilhar PDF (`share_plus`) e salvar (`SavePdf`)

**Bloqueio:**

```1:60:lib/features/pdf_opening/domain/usecases/save_pdf.dart
import 'dart:io';
...
    final docsDir = await _getApplicationDocumentsDirectory();
    final targetDir = Directory('${docsDir.path}/$savedPdfsSubdir');
    ...
    if (isLocalPdfPath(filePath)) {
      await File(filePath).copy(targetFile.path);
      return targetFile.path;
    }
    final bytes = await _bytesDatasource.fetchBytes(filePath);
    await targetFile.writeAsBytes(bytes, flush: true);
```

`share_pdf.dart` tem o mesmo padrão (`Directory`, `File`, `XFile(path)`).

**O que verificar/implementar:**

- [ ] **Decisão D3 OA:** “Salvar PDF” na web = **download do browser** (blob + `anchor download`), não gravar em documents.
- [ ] **Decisão D4 OA:** usar `XFile.fromData(bytes, name: ...)` em **todas** as plataformas para share de PDF e folheto — eliminar dependência de temp dir onde possível.
- [ ] Validar se `share_plus` versão fixada (`^13.2.0`) já suporta `XFile.fromData` de forma consistente entre nativo/web (checar changelog/testes do pacote).

### 3.3 — Folheto (leaflet)

**Bloqueio:**

```234:266:lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart
    return writeLeafletPngToTempFile(
      pngBytes,
      getTemporaryDirectory:
          getTemporaryDirectory ?? path_provider.getTemporaryDirectory,
    );
```

A captura em si (`captureWidgetToPng` via `RepaintBoundary.toImage()`) é **100% compatível com web** (usa `dart:ui`, sem `dart:io`). O bloqueio é só na etapa de **persistir o PNG em arquivo temporário** antes de compartilhar.

**O que verificar/implementar:**

- [ ] Localizar `writeLeafletPngToTempFile` antes de implementar.
- [ ] **Decisão D4 OA:** substituir fluxo temp-file por `XFile.fromData(pngBytes, name: kLeafletPngFileName, mimeType: 'image/png')` em nativo **e** web.

### Critérios de aceite (Fase 3)

- [ ] Leitor abre PDF remoto e asset na web (sem cache local ainda, se Fase 4 não estiver pronta).
- [ ] Share de PDF remoto/asset funciona na web (Web Share API ou fallback de download).
- [ ] Folheto é gerado e compartilhado/baixado na web.
- [ ] Nenhuma regressão nativa.

### Cuidados

- Ler ADR-002 (pdfrx) e UC-11 antes de tocar no adapter.
- Preservar a regra "domínio não importa pacote de viewer/storage" — qualquer `if (kIsWeb)` deve ficar em `data/adapters` ou `data/datasources`, nunca em `domain/usecases`.

---

## Fase 4 — Sistema offline nativo (UC-09/UC-10) na web

**Objetivo:** implementar offline com **persistência real** na web (**D1 O3**) — paridade com nativo, incluindo bulk download e reconcile.

> **Decisão fechada:** D1 O3. Não implementar variante “online-only” ou “cache em memória apenas”.

### Por que é o maior bloqueio

O sistema offline foi desenhado **deliberadamente** como filesystem nativo + índice Isar (ver MVP Roadmap §Fase 3), em substituição ao par Service Worker + Cache Storage da PWA antiga. Isso significa:

- `PdfLocalStore` grava em `ApplicationDocumentsDirectory/plpcg_pdfs/` com escrita atômica (`.tmp` → `rename`) — conceito de filesystem que não existe na web.
- `ZipPackageDownloader` baixa ZIP para disco, com resume via HTTP Range em arquivo parcial (`.part`) — o pacote `archive` usado (`InputFileStream`) é baseado em `dart:io` e não compila para web sem substituição.
- `ExtractAndStorePdfs` usa `Isolate.spawn`/`compute` para descompactar ZIP fora da main thread. **`dart:isolate` não é suportado no compilador web** (`Isolate.spawn` lança em runtime nas versões antigas; hoje o import sequer compila para o target `web` sem tratamento condicional). `compute()` do Flutter tem shim para web (não usa isolate real, roda na mesma thread), mas `Isolate.spawn`/`ReceivePort` direto **não têm equivalente**.
- `ReconcileOfflineIndex` usa `compute(validatePdfPathsChunk, ...)` — mesma ressalva de `compute` acima (funciona via shim, mas a função `validatePdfPathsChunk` provavelmente chama `dart:io` internamente — confirmar).
- `PdfIntegrityValidator` valida magic bytes com `File.openSync`/`FileStat.statSync` — sem equivalente web.

### Decisão do mantenedor (D1 O3) — escopo de implementação

Substituir filesystem nativo por storage web equivalente:

1. **`PdfLocalStore` web** — OPFS (preferencial para blobs grandes) ou IndexedDB; manter contrato de domínio (`upsert`, `lookup`, eviction LRU, `isPersistent`).
2. **Bulk UC-09** — baixar ZIP em memória ou OPFS temp; decodificar com `ZipDecoder().decodeBytes(Uint8List)` (web-safe), **não** `InputFileStream`.
3. **Isolates** — substituir `Isolate.spawn` por `compute()` (shim web) ou Web Worker dedicado; extração ZIP não pode importar `dart:isolate`/`dart:io` na árvore web.
4. **`PdfIntegrityValidator`** — validar magic bytes em `Uint8List`, não em `File`.
5. **`OfflinePdfIndex.storagePath`** — na web, armazenar chave lógica (ex.: `pdfId` ou path relativo normalizado), não path absoluto de OS.
6. **UC-10 reconcile** — adaptar `validatePdfPathsChunk` para checar existência no store web, não `FileStat`.

### Sub-fases sugeridas (D1 O3 é grande — quebrar em PRs)

| Sub-fase | Escopo |
|---|---|
| 4a | Porta `PdfStoragePort` + implementação nativa (wrapper do `PdfLocalStore` atual) + stub web que compila |
| 4b | Implementação web OPFS/IndexedDB + `ResolvePdfForReader` + adapter `openData` (D2) |
| 4c | Fetch on-demand (`FetchAndStorePdf`) na web |
| 4d | Bulk download UC-09 (ZIP em bytes, sem `Isolate.spawn`) |
| 4e | UC-10 reconcile + stats + UI offline settings na web |

### O que verificar/implementar
- [ ] `ResolvePdfForReader` + store web: hit → bytes do OPFS/IndexedDB → adapter `openData` (D1 O3 + D2 OA).
- [ ] `OfflineSettingsScreen`: **manter** UC-09/UC-10 visíveis e funcionais na web (D1 O3).
- [ ] `offlineCacheStatusProvider`, `OfflineAvailableStore`: comportamento equivalente ao nativo na web.

### Critérios de aceite

- [ ] `flutter build web --wasm` compila sem `dart:isolate`/`dart:io` na árvore de import ativa (conditional imports ou sub-fases 4a–4e).
- [ ] UC-09 bulk e UC-10 reconcile funcionam na web (smoke manual).
- [ ] PDFs persistem entre reloads da aba (D1 O3).
- [ ] Nenhuma regressão no offline nativo (iOS/Android).

### Cuidados

- Este é o único ponto do plano onde "checar" pode significar "decidir não implementar agora, documentar por quê".
- Não remover código nativo funcional para "simplificar" — a regra anti-overengineering do projeto proíbe alterar o que não foi pedido.

---

## Fase 5 — Plugins nativos com suporte web parcial (baixo risco, checagem)

**Objetivo:** validar comportamento em runtime (não são bloqueios de compilação) e ajustar UX onde necessário.

### `connectivity_plus` (^7.2.0)

- [ ] Web usa `navigator.onLine` — detecta oscilações de rede com menos granularidade que nativo (sem diferenciar wifi/celular).
- [ ] Checar `ConnectivityDeviceConnectivity` e `ConnectivityNetworkConnectionChecker` (`lib/core/network/device_connectivity.dart`, `lib/features/pdf_reader/data/datasources/connectivity_network_connection_checker.dart`) — a lógica de "unmetered" (`wifi`/`ethernet`/`vpn`) deve ter fallback sensato quando o browser só informa `online`/`offline` genérico.
- [ ] Sem ação de compilação necessária — plugin já registra implementação web (`ConnectivityPlusWebPlugin`).

### `app_links` (^7.0.0)

- [ ] `app_links_web` já é a implementação padrão registrada para `web` no `pubspec.yaml` do pacote — deep links via query string (`/?sharepdfs=...&sharename=...`) devem funcionar nativamente pela própria URL do browser, tornando `AppLinks.getInitialLink()`/stream potencialmente redundante na web (a app já nasce na URL correta).
- [ ] Checar `DeepLinkListener`/`SyncDeepLinkState` — confirmar que não há suposição de esquema customizado (`plpcg://`) sendo exigida na web.
- [ ] Validar fluxo de import de playlist compartilhada abrindo a URL direto no browser (equivalente ao fluxo `/?sharepdfs=` da PWA antiga, que é a motivação original do formato de URL — ver `MAPEAMENTO_PLPCG_FLUTTER.md`).

### `wakelock_plus` (^1.5.2)

- [ ] Web usa `no_sleep.js` (asset do próprio pacote) — em alguns browsers exige interação do usuário (gesto) antes de manter a tela acordada; validar se `BulkDownloadWakelock` (usado só durante UC-09 bulk) tem sentido na web dado que UC-09 pode estar desabilitado (Fase 4) — se desabilitado, este plugin some do fluxo web automaticamente.

### `pdfrx` / `pdfrx_engine` (^2.4.4) — comportamento web

- [ ] Confirmar assets WASM (`pdfium.wasm`, `pdfium_worker.js`) são incluídos automaticamente no build web pelo próprio pacote (`flutter:` `assets:` com `platforms: [web]` no `pubspec.yaml` do pacote — já confirmado via inspeção do pacote).
- [ ] Validar `isSharedArrayBufferSupported` (`lib/src/wasm/js_utils.dart` do pacote) — sem `SharedArrayBuffer` (que depende de cabeçalhos COOP/COEP, ver Fase 6), o pdfrx deve cair em modo single-thread mais lento, mas **não deve quebrar** — apenas medir performance.

### `isar_plus` — comportamento web

- [ ] Validar que os 4 schemas (`LouvorCache`, `CarouselEntry`, `Playlist`, `OfflinePdfIndex`) abrem corretamente via IndexedDB/WASM (o pacote anuncia *"Persistent web storage — IndexedDB for Flutter Web"*).
- [ ] Medir tamanho do banco (~4600+ louvores) e tempo de boot na web — pode divergir do nativo.

### `shared_preferences` (^2.3.4)

- [ ] Já web-safe (usa `window.localStorage`); sem ação necessária além de smoke test.

### `dio` (^5.7.0), `flutter_svg` (^2.2.0), `archive` (^4.0.0, uso fora do offline), `go_router` (^17.3.0), `flutter_riverpod` (^3.3.2)

- [ ] Sem bloqueios conhecidos para web; `archive` só é problemático no uso específico de `InputFileStream` (Fase 4) — o resto do pacote (decode de bytes) é web-safe.

### Critérios de aceite

- [ ] Cada item acima validado manualmente em `flutter run -d chrome` e anotado (ok / ajuste necessário) antes de fechar a fase.

---

## Fase 6 — Infraestrutura de deploy e PWA

**Objetivo:** o artefato de build web funciona como PWA instalável, servido corretamente.

### Build

- [ ] **D5:** usar sempre `flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json --release`.
- [ ] Criar `dart_defines/plpcjf.json` e `scripts/web_build.sh` (espelhar `scripts/ios_*`).

### Cabeçalhos HTTP (hosting)

- [ ] **D6 OA:** COOP/COEP em **plpcjf.org** (Cloudflare Pages `_headers` ou wrangler).
- [ ] HTTPS obrigatório — plpcjf.org.
- [ ] Validar cache-control do `flutter_service_worker.js`.

### Manifest / branding PWA

- [ ] **D8:** `web/manifest.json` — nome completo PLPCG; `short_name`: **PLPCG**; cores de `AppColors`; ícones 192/512 de `assets/branding/app_icon_source.png`.
- [ ] `web/index.html` — título, meta tags; `<base href="/">` na raiz de plpcjf.org.

### Deep links / share URL na web

- [ ] URLs `/?sharepdfs=...&sharename=...` em **plpcjf.org** (não alterar plpcg.com por enquanto — D7).

### Backend

- [ ] **D7:** deploy frontend em **plpcjf.org**; API provavelmente continua em `https://plpcg.com` → **configurar CORS** no worker `plpcg-catalog` para `Origin: https://plpcjf.org`.
- [ ] `/offline-manifest.json` continua servido pela API (bulk UC-09 na web — D1 O3).

### Critérios de aceite

- [ ] `flutter build web` gera artefato válido, testável localmente via `flutter run -d chrome` e servidor estático simples.
- [ ] Lighthouse/PWA checklist básico (installable, HTTPS, manifest válido) passa.
- [ ] Deep link de compartilhamento abre corretamente numa aba nova.

---

## Fase 7 — CI, scripts e testes

**Objetivo:** garantir que a nova plataforma não regressa silenciosamente (**D9 A+A**).

- [ ] Job CI: `flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json` em **todo PR** (D9).
- [ ] Job CI: `flutter test --platform chrome` — smoke mínimo (boot, catálogo, abrir PDF remoto); expandir cobertura incrementalmente (D9).
- [ ] `scripts/setup_deps.sh`: não assumir só mobile.
- [ ] Testes unit/widget existentes (`test/unit`, `test/widget`) permanecem verdes após fases 1–6.

### Critérios de aceite

- [ ] Pipeline documentada (mesmo que só localmente, via comando manual) para validar build web antes de merge.
- [ ] Nenhum teste unit/widget existente quebrado pelas fases 1–6.

---

## Fase 8 — Verificação multi-plataforma (build final)

**Objetivo:** confirmar que **iOS, Android e Web** compilam com sucesso após todas as fases anteriores, sem regressão nativa.

**Depende de:** Fases 0–7 concluídas e integradas na branch `web/integration` (ou equivalente).

### Checklist

- [x] `flutter analyze` — zero issues novos.
- [x] `flutter test` — suite unit/widget verde.
- [x] `flutter test --platform chrome` — smoke web verde (D9).
- [x] `flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json --release`
- [x] `flutter build ios --simulator --dart-define-from-file=dart_defines/plpcg.json` (ou device configurado no projeto)
- [ ] `flutter build apk --dart-define-from-file=dart_defines/plpcg.json` (ou `appbundle` conforme pipeline do projeto) — **pendente neste host** (sem JRE); ver [web_phase8_build_report.md](web_phase8_build_report.md)
- [x] Documentar versão Flutter/Dart usada e tempo de cada build.
- [x] Atualizar `WEB_BUILD_REFACTOR_PLAN.md` — status → **Implementado** (ou listar pendências remanescentes).

### Critérios de aceite

- [ ] Três targets (iOS simulador, Android APK, Web WASM) compilam sem erro. — **2/3** neste ambiente (APK bloqueado por JDK).
- [x] Nenhuma regressão nos testes existentes.
- [x] Commit final: `chore(web): multi-platform build verification (phase 8)`

---

## Orquestração de branches (agentes)

Cada fase = **uma branch** encadeada; agente **não** reutiliza working tree suja de outra fase.

| Fase | Branch | Base (merge de) |
|---|---|---|
| 0 | `web/phase-0` | `main` |
| 2 | `web/phase-2` | `web/phase-0` |
| 1 | `web/phase-1` | `web/phase-2` |
| 3 | `web/phase-3` | `web/phase-1` |
| 4a | `web/phase-4a` | `web/phase-3` |
| 4b | `web/phase-4b` | `web/phase-4a` |
| 4c | `web/phase-4c` | `web/phase-4b` |
| 4d | `web/phase-4d` | `web/phase-4c` |
| 4e | `web/phase-4e` | `web/phase-4d` |
| 5 | `web/phase-5` | `web/phase-4e` |
| 6 | `web/phase-6` | `web/phase-5` |
| 7 | `web/phase-7` | `web/phase-6` |
| 8 | `web/phase-8` | `web/phase-7` |
| integração | `web/integration` | merge linear de todas |

Prompt padrão para cada agente:

```text
Siga docs/WEB_BUILD_REFACTOR_PLAN.md — Decisões do mantenedor (D1–D10).
Fase deste PR: [N]
Branch: web/phase-[N] (criar a partir de web/phase-[N-1] ou main para fase 0)
Build: flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json
D1 O3 · D2 OA · D3 OA · D4 OA · D7 plpcjf.org · D9 CI+Chrome tests
Commit ao concluir a fase.
```

---

## Matriz de risco consolidada

| Fase | Risco principal | Mitigação |
|---|---|---|
| 0 | `flutter create` sobrescrever arquivos existentes | Revisar diff antes de commitar; usar apenas `--platforms=web` |
| 1 | API `Isar.open` para web diferente do esperado (doc pode estar desatualizada) | Consultar `isarplus.ahmetaydin.dev` no início da fase, como já indicado em MIGRATION_NATIVE_DEPS.md para outras fases Isar |
| 2 | Remoção de import "morto" na verdade estar em uso indireto | `flutter analyze` + `flutter test` antes de remover qualquer import |
| 3 | UX de share/save divergente do nativo gerar confusão | Validar com mantenedor textos/fluxo de download no browser antes de finalizar |
| 4 | D1 O3 — escopo grande; OPFS/quota browser | Sub-fases 4a–4e; uma sub-fase por PR |
| 5 | Comportamento sutil divergente (ex.: connectivity) só aparece em produção | Testar em pelo menos 2 browsers (Chrome + Safari, dado histórico de bugs iOS no doc) |
| 6 | Performance ruim sem COOP/COEP configurado no host | Validar cabeçalhos antes de anunciar o deploy como pronto |
| 7 | CI cresce em tempo sem ganho proporcional | Rodar build web só em PRs que tocam `lib/`, `pubspec.yaml` ou `web/` |

---

## Referências

- [MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md) — padrão de fases/PRs usado como modelo para este documento.
- [MVP Roadmap.md](MVP%20Roadmap.md) — arquitetura offline nativa (Fase 3) e motivação de divergir da PWA antiga.
- [MAPEAMENTO_PLPCG_FLUTTER.md](../MAPEAMENTO_PLPCG_FLUTTER.md) — mapeamento original PWA SvelteKit → Flutter, inclusive §10 (equivalências) e §11 (endpoints).
- [ADR-001-isar-storage.md](adr/ADR-001-isar-storage.md), [ADR-002-pdfx-reader.md](adr/ADR-002-pdfx-reader.md).
- [deep-links-setup.md](deep-links-setup.md) — Universal Links/App Links nativos (não aplicável 1:1 à web).
- [Flutter — Web platform support](https://docs.flutter.dev/platform-integration/web) (consultar versão vigente no início da implementação).
- [isar_plus web support](https://pub.dev/packages/isar_plus) — changelog e docs oficiais.
- [pdfrx](https://pub.dev/packages/pdfrx) — suporte Web/WASM.
