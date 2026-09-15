# PWA — Shell Offline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O PWA instalado (iPhone/iPad/Android/desktop) e a aba normal de `v2.plpcg.com` **abrem sem rede**: um service worker próprio precacheia o shell (`index.html`, bootstrap, wasm/js, engine, fontes, ícones), serve a navegação a partir do cache quando a rede falha, e o Dart pede `navigator.storage.persist()` no boot. Catálogo e materiais continuam a cargo do Dart (Isar / Cache API) — o SW não lhes toca.

**Architecture:** `web/sw.js` é um template com três placeholders (`__PLPCG_TAG__`, `__PLPCG_CRITICAL__`, `__PLPCG_WARM__`) que o Flutter copia para `build/web/`; o pós-build (`scripts/cache_bust_web_entrypoints.sh` → novo `scripts/generate_sw_manifest.py`) percorre `build/web` e classifica cada ficheiro em três classes: `CRITICAL` (precache no `install`, all-or-nothing, ≈ 3 MB: index, bootstrap, isar, manifests, fontes, ícones), `ENGINE` (`main.dart.*` e `canvaskit/<hash>/**` — **nunca listado** no `sw.js`, porque o `flutter_bootstrap.js` escolhe a variante por browser e só a usada interessa) e `WARM` (o resto carregável, aquecido em background). Depois do `flutter-first-frame`, `index.html` regista `sw.js?v=<tag>` e envia `{type:'warm', used:[URLs same-origin que a página carregou], full:<sem Save-Data/2g>}`: o SW mete `used` no cache (vem do cache HTTP, ≈ 0 rede — é assim que o engine realmente usado entra) e, só com `full`, percorre `WARM`. Um cache por deploy (`plpcg-shell-<web_cache_tag>`); `activate` apaga os outros. Navegação e `version.json`/`manifest.json` são network-first com fallback ao cache; o resto do shell same-origin é cache-first com preenchimento em runtime. `web/flutter_bootstrap.js` deixa de registar o stub do Flutter. No Dart, `requestPersistentStorage()` (conditional import web/nativo) é disparado por um `FutureProvider` observado em `BootstrapApp`. Um script CDP (`scripts/verify_web_sw.py`) prova no CI que o engine usado foi aquecido e que o app arranca com o servidor em baixo.

**Tech Stack:** Flutter 3.47 web (`--wasm`), `package:web` 1.1.1 + `dart:js_interop`, Riverpod 3, service worker em JS puro (sem dependências), Python 3.9+ (stdlib) para pós-build e verificação via Chrome DevTools Protocol, bash, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-14-pwa-shell-offline-design.md`

## Global Constraints

- Todos os comandos rodam a partir da raiz da worktree `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/pwa-shell-offline`.
- O SW cobre só o shell same-origin; nunca chama `respondWith` para outras origens.
- `install` precacheia só `CRITICAL`; `WARM` corre só por mensagem `{type:'warm'}` e nunca com Save-Data / 2g (`full: false`).
- ENGINE (`main.dart.wasm|mjs|js` e `canvaskit/<hash>/**`) nunca entra em `CRITICAL`/`WARM`; chega ao cache pela lista `used` da página (enviada **sempre**, mesmo com Save-Data — vem do cache HTTP) ou por `cacheFirst` em runtime.
- Cache por versão `plpcg-shell-<web_cache_tag>`; `activate` apaga as outras e faz `clients.claim()`.
- `activate` **nunca** apaga `plpcg-pdfs-store-v1` (Cache API dos PDFs offline, `OfflineConfig.pdfCacheStoreName`) — só `plpcg-shell-*` de outras tags e os três nomes legados do SW do Flutter (`flutter-app-cache`, `flutter-temp-cache`, `flutter-app-manifest`).
- Registo do SW só depois de `flutter-first-frame`.
- `sw.js` e `index.html` continuam `Cache-Control: no-cache`; `/canvaskit/*` e `/assets/*` continuam `immutable`.
- `web/flutter_bootstrap.js` deixa de ter `serviceWorkerSettings` (o stub `flutter_service_worker.js` faz `unregister` + `client.navigate` e conflitaria com o `sw.js` no mesmo scope). O ficheiro `flutter_service_worker.js` continua no build e no `_headers`; nunca entra em `CRITICAL`/`WARM`.
- Nomes de ficheiro em `build/web` já são URL-safe (o Flutter grava `EBGaramond%5Bwght%5D.ttf` literalmente); o gerador aplica `urllib.parse.quote(path, safe="/")` — o URL correto é `…%255Bwght%255D.ttf` (é o que o engine e a produção usam).
- Ordem do pós-build: `flutter build web` → `cache_bust_web_entrypoints.sh` (que chama `generate_sw_manifest.py`) → `verify_web_headers_artifact.sh`. O CI passa a correr o cache-bust.
- Antes de cada commit: `dart format` nos ficheiros Dart tocados, `flutter analyze` sem erros novos; testes web com `flutter test --platform chrome test/web/<ficheiro>` para os `@TestOn('browser')` e `flutter test test/web/<ficheiro>` para os `@TestOn('vm')` (ver `scripts/test_all.sh`).
- Comentários de código e strings em português, no tom do código vizinho (explicam o porquê).
- Commits terminam com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP
  ```
- Baseline conhecido: `pdfrx_viewer_adapter_test` e `reconcile_offline_index_benchmark_test` falham por timeout sob carga — pré-existente, não corrigir.

## Precisões face à spec (verificadas no repo e no build)

| # | Ponto da spec | O que o plano faz e porquê |
|---|---|---|
| P1 | §3.1 `CRITICAL` lista `main.dart.*` e `canvaskit/<hash>/skwasm.*` + `canvaskit.*` como "o par que o `flutter_bootstrap` pode escolher". | O `flutter_bootstrap.js` 3.47 escolhe a variante do engine **por browser** (`skwasm` no Chrome/Edge/Android; `skwasm_heavy` no Safari/Firefox, que não têm `ImageDecoder`/`v8BreakIterator`; `canvaskit` ou `chromium/canvaskit` + `main.dart.js` sem WasmGC, iOS ≤ 17). Listar um par fixo deixava o iPhone sem engine offline; listar todos custava ≈ 33 MB por deploy em 4G. Por isso existe uma terceira classe, **ENGINE** (`main.dart.wasm|mjs|js?v=` e tudo em `canvaskit/<hash>/**`), que **não entra** em `CRITICAL` nem em `WARM`: depois do primeiro frame o `index.html` envia ao SW a lista `used` (`performance.getEntriesByType('resource')`, same-origin) e o SW copia-a para o cache — só a variante realmente carregada, e vinda do cache HTTP (≈ 0 rede). `cacheFirst` em runtime cobre o resto. Custo: install ≈ 3 MB (bootstrap, isar 1,4, fontes/ícones/manifests); `used` ≈ 8–10 MB do cache HTTP (`main.dart.wasm` 4,4 + skwasm 3,6 ou skwasm_heavy 5,2); nada das variantes não usadas. Risco aceite: fechar a aba < ~2 s após o primeiro frame pode deixar o engine fora do cache — a próxima abertura online corrige. |
| P2 | §3.1 `assets/packages/**` em `CRITICAL` "(ícones/fontes de pacotes)". | Fontes (`.otf/.ttf/.woff/.woff2`) em qualquer subpasta de `assets/` → `CRITICAL`; o resto de `assets/packages/**` (`pdfium.wasm` 5,2 MB, `pdfium_*.js`, shaders, `no_sleep.js`) → `WARM`. O `pdfium.wasm` só é pedido pelo chunk do leitor. |
| P3 | §3.1 `WARM` = "tudo o resto carregável em runtime". | `*.symbols` (≈ 10 MB de mapas do engine) não são carregáveis em runtime — excluídos das duas listas, junto com `sw.js`, `flutter_service_worker.js`, `.last_build_id`, `_headers`, `_redirects`. |
| P4 | §3.2 "passo novo no bloco Python". | O gerador é um módulo próprio, `scripts/generate_sw_manifest.py`, chamado por `cache_bust_web_entrypoints.sh` logo a seguir ao bloco Python (depois de `version.json` ter as três tags). Mesmo efeito, testável isoladamente. |
| P5 | §3.2 `verify_web_headers_artifact.sh` exige placeholders substituídos. | Hoje o verify corre **antes** do cache-bust em `web_build.sh` (l.44–45) e o CI não corre o cache-bust. `web_build.sh` inverte a ordem e o CI ganha o passo de cache-bust antes do verify. |
| P6 | §3.3 registo com `register('sw.js?v=__PLPCG_TAG__')`. | O `index.html` guarda a tag em `var swTag = '__PLPCG_TAG__';` e regista `'sw.js?v=' + swTag`; se a tag não tiver 12 hex (`flutter run`, placeholder intacto) não regista. Evita deixar o literal `__PLPCG_` no `index.html` gerado (o verify falharia) e evita registar um template com `SyntaxError`. |
| P7 | §5 "`chrome_smoke_test.dart` ganha uma asserção… apenas quando servido pelo servidor local". | `flutter test --platform chrome` serve o harness de testes, não `build/web` — lá não existe `sw.js`. A asserção vive em `scripts/verify_web_sw.py` (CDP, mesmo cliente de `measure_web_boot.py`): boot online → `getRegistration().active.state === 'activated'` e `caches.keys()` ⊇ `plpcg-shell-<tag>` → o cache contém `main.dart.wasm?v=` ou `main.dart.js?v=` **e** um `canvaskit/<hash>/*.wasm` (prova de que `used` foi aquecido) → **servidor em baixo** → nova navegação → `flutter-first-frame` a partir do cache com `crossOriginIsolated === true`. Corre no CI depois do gate de performance. |
| P8 | §3.6 assinatura `Future<void> requestPersistentStorage()`. | Devolve `Future<bool?>` (`true` persistente, `false` recusado, `null` sem API/erro) e memoriza o `Future` (uma chamada por sessão). Mesmo `debugPrint`; o valor só serve aos testes. |
| P9 | Spec não fala de `web/flutter_bootstrap.js`. | É template custom com `serviceWorkerSettings` → o loader regista o stub do Flutter a cada boot. Removido (Task 3). |

---

## File map

**Web (`web/`)**
- Create `web/sw.js` — template do service worker (install/activate/message `{type:'warm', used, full}`/fetch) com os três placeholders.
- Modify `web/flutter_bootstrap.js` — remove `serviceWorkerSettings` (não registar o stub).
- Modify `web/manifest.json` — `id: "/"`, `scope: "/"`.
- Modify `web/_headers` — `/sw.js` → `Cache-Control: no-cache`.
- Modify `web/index.html` — `setResourceTimingBufferSize(600)` no início do `<head>`; registo do SW após `flutter-first-frame` + `{type:'warm', used, full}` (l.277→).

**Scripts (`scripts/`)**
- Create `scripts/generate_sw_manifest.py` — classifica `build/web` em `CRITICAL`/`ENGINE`/`WARM` (ENGINE fica fora do `sw.js`), substitui placeholders, falha se faltar crítico.
- Modify `scripts/cache_bust_web_entrypoints.sh` — substitui `swTag` no `index.html`; chama o gerador.
- Modify `scripts/verify_web_headers_artifact.sh` — exige `/sw.js` no-cache e nenhum `__PLPCG_` em `sw.js`/`index.html`.
- Modify `scripts/web_frontend_server.py` — `sw.js` no-cache (espelha `_headers`; `web_local_dev.py` herda).
- Modify `scripts/web_build.sh` — cache-bust antes do verify.
- Modify `scripts/validate_web_coop_coep.sh` — checa `sw.js` na produção.
- Create `scripts/verify_web_sw.py` — boot online + boot sem servidor via CDP.

**Dart (`lib/core/platform/`)**
- Create `web_storage_persistence.dart` (export condicional), `web_storage_persistence_web.dart`, `web_storage_persistence_native.dart`, `web_storage_persistence_provider.dart`.
- Modify `lib/bootstrap_app.dart` — `ref.watch(persistentStorageProvider)`.

**Testes**
- Create `test/support/web_build_fixture.dart` — `build/web` mínimo partilhado.
- Modify `test/web/cache_bust_web_entrypoints_test.dart` — usa o fixture partilhado.
- Create `test/web/sw_manifest_generation_test.dart`, `test/web/sw_template_test.dart`, `test/web/web_manifest_test.dart`, `test/web/web_index_sw_registration_test.dart`, `test/web/web_storage_persistence_test.dart` (browser), `test/unit/core/platform/web_storage_persistence_native_test.dart`.
- Modify `test/web/web_headers_test.dart`, `test/widget/bootstrap_app_test.dart`.

**CI e docs**
- Modify `.github/workflows/web.yml` — passos cache-bust, verify, SW offline.
- Modify `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md` (A9), `docs/WEB_PERFORMANCE_AND_LOADING.md` (Fase C + changelog).

---

### Task 1: `manifest.json` com identidade estável (S8)

**Files:**
- Modify: `web/manifest.json` (após a linha 4, `"start_url": "."`)
- Test: `test/web/web_manifest_test.dart`

**Interfaces:**
- Produces: `web/manifest.json` com `id: "/"` e `scope: "/"`; `start_url` continua `"."`.

- [ ] **Step 1: Teste que falha**

`test/web/web_manifest_test.dart`:

```dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `id`/`scope` fixam a identidade do PWA instalado (spec S8): sem `id`, o
/// browser deriva-a do `start_url`, e uma mudança de query no arranque
/// passaria por um app diferente no ecrã inicial.
void main() {
  late Map<String, dynamic> manifest;

  setUp(() {
    manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
  });

  test('id e scope na raiz', () {
    expect(manifest['id'], '/');
    expect(manifest['scope'], '/');
  });

  test('start_url continua relativo', () {
    expect(manifest['start_url'], '.');
    expect(manifest['display'], 'standalone');
  });
}
```

Run: `flutter test test/web/web_manifest_test.dart 2>&1 | tail -5`
Expected: FAIL — `Expected: '/'  Actual: <null>`.

- [ ] **Step 2: Implementar**

Em `web/manifest.json`, depois da linha 4 (`"start_url": ".",`) inserir:

```json
    "id": "/",
    "scope": "/",
```

Run: `flutter test test/web/web_manifest_test.dart 2>&1 | tail -3`
Expected: `All tests passed!`

- [ ] **Step 3: Commit**

```bash
dart format test/web/web_manifest_test.dart
git add web/manifest.json test/web/web_manifest_test.dart
git commit -m "feat(web): manifest.json com id e scope na raiz (identidade estável do PWA)"
```

---

### Task 2: `/sw.js` no-cache no `_headers`, no servidor local e no verify

**Files:**
- Modify: `web/_headers` (após a linha 36, bloco `/flutter_service_worker.js`)
- Modify: `scripts/web_frontend_server.py` (tupla `entry_points`, l.30–42)
- Modify: `scripts/verify_web_headers_artifact.sh`
- Modify: `test/web/web_headers_test.dart`

**Interfaces:**
- Produces: regra `_headers` `/sw.js` → `Cache-Control: no-cache`; `verify_web_headers_artifact.sh <_headers>` falha sem ela.

- [ ] **Step 1: Testes que falham**

Em `test/web/web_headers_test.dart`, depois do teste `'servidor local envia o mesmo COOP'` (l.35), acrescentar:

```dart
  test('sw.js é no-cache no _headers (registo por ?v=<tag>)', () {
    // A tag na query só deteta SW novo se o próprio sw.js não ficar preso
    // na CDN: o SW velho continuaria a servir o shell velho.
    final at = lines.indexOf('/sw.js');
    expect(at, greaterThan(0), reason: 'falta a regra /sw.js');
    expect(lines[at + 1], 'Cache-Control: no-cache');
  });

  test('servidor local espelha o no-cache do sw.js', () {
    final py = File('scripts/web_frontend_server.py').readAsStringSync();
    expect(py, contains('"sw.js",'));
  });

  test('verify_web_headers_artifact.sh rejeita _headers sem /sw.js', () async {
    final tmp = Directory.systemTemp.createTempSync('headers_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final headers = File('${tmp.path}/_headers')
      ..writeAsStringSync(
        File('web/_headers')
            .readAsStringSync()
            .replaceFirst('/sw.js\n  Cache-Control: no-cache\n', ''),
      );
    final result = await Process.run('bash', [
      'scripts/verify_web_headers_artifact.sh',
      headers.path,
    ]);
    expect(result.exitCode, isNot(0));
  });
```

Run: `flutter test test/web/web_headers_test.dart 2>&1 | tail -8`
Expected: FAIL nos três novos (`at` = -1; `py` sem `"sw.js",`; verify sai 0).

- [ ] **Step 2: `_headers`**

Em `web/_headers`, depois da linha 36 (`  Cache-Control: no-cache` do bloco `/flutter_service_worker.js`) inserir:

```
# SW próprio (web/sw.js): registado por ?v=<tag>; no-cache para a CDN nunca
# prender um deploy no SW velho.
/sw.js
  Cache-Control: no-cache
```

- [ ] **Step 3: Servidor local**

Em `scripts/web_frontend_server.py`, na tupla `entry_points` (l.30–42), depois de `"flutter_service_worker.js",` acrescentar a linha `"sw.js",`.

- [ ] **Step 4: Verify (só a regra de headers; os placeholders entram na Task 5)**

Substituir o conteúdo de `scripts/verify_web_headers_artifact.sh` por:

```bash
#!/usr/bin/env bash
# Verifica build/web/_headers após flutter build web (Fase D — gate CI/local).
set -euo pipefail

HEADERS_FILE="${1:-build/web/_headers}"

test -f "$HEADERS_FILE"
grep -qx '  Cross-Origin-Opener-Policy: same-origin' "$HEADERS_FILE"
grep -q 'Cross-Origin-Embedder-Policy: require-corp' "$HEADERS_FILE"
grep -q 'flutter_service_worker.js' "$HEADERS_FILE"
grep -A1 'flutter_service_worker.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'
# sw.js é registado por ?v=<tag>: se a CDN o cacheasse, um deploy novo ficaria
# preso no SW velho até o objeto expirar.
grep -qx '/sw.js' "$HEADERS_FILE"
grep -A1 -x '/sw.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'

echo "OK: $HEADERS_FILE contém COOP/COEP e no-cache dos service workers."
```

Run: `flutter test test/web/web_headers_test.dart 2>&1 | tail -3 && ./scripts/verify_web_headers_artifact.sh web/_headers`
Expected: `All tests passed!` e `OK: web/_headers contém COOP/COEP e no-cache dos service workers.`

- [ ] **Step 5: Commit**

```bash
dart format test/web/web_headers_test.dart
git add web/_headers scripts/web_frontend_server.py scripts/verify_web_headers_artifact.sh test/web/web_headers_test.dart
git commit -m "chore(web): sw.js no-cache no _headers, no servidor local e no verify do artefacto"
```

---

### Task 3: Template `web/sw.js` e bootstrap sem o stub do Flutter

**Files:**
- Create: `web/sw.js`
- Modify: `web/flutter_bootstrap.js` (remover l.9–11 `serviceWorkerSettings`)
- Test: `test/web/sw_template_test.dart`

**Interfaces:**
- Produces: `web/sw.js` com `const TAG = '__PLPCG_TAG__'; const CRITICAL = __PLPCG_CRITICAL__; const WARM = __PLPCG_WARM__;` (cada placeholder exatamente uma vez); eventos `install`, `activate`, `message {type:'warm', used?: string[], full?: boolean}`, `fetch`; função `warm(used, full)`.
- Consumido pela Task 4 (substituição) e pela Task 5 (registo).

- [ ] **Step 1: Teste que falha**

`test/web/sw_template_test.dart`:

```dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garante a forma do template `web/sw.js` que `scripts/generate_sw_manifest.py`
/// preenche e o contrato com o Dart (nunca tocar no cache dos PDFs offline).
/// O comportamento em runtime é provado por `scripts/verify_web_sw.py`.
void main() {
  late String sw;

  setUp(() {
    sw = File('web/sw.js').readAsStringSync();
  });

  int count(String needle) => needle.allMatches(sw).length;

  test('placeholders exatamente uma vez cada', () {
    expect(sw, contains("const TAG = '__PLPCG_TAG__';"));
    expect(sw, contains('const CRITICAL = __PLPCG_CRITICAL__;'));
    expect(sw, contains('const WARM = __PLPCG_WARM__;'));
    expect(count('__PLPCG_TAG__'), 1);
    expect(count('__PLPCG_CRITICAL__'), 1);
    expect(count('__PLPCG_WARM__'), 1);
  });

  test('um cache por tag, skipWaiting e claim', () {
    expect(sw, contains('plpcg-shell-'));
    expect(sw, contains('self.skipWaiting()'));
    expect(sw, contains('self.clients.claim()'));
    expect(sw, contains('caches.delete('));
  });

  test('só GET same-origin; navegação network-first; warm por mensagem', () {
    expect(sw, contains("request.method !== 'GET'"));
    expect(sw, contains('url.origin !== self.location.origin'));
    expect(sw, contains("request.mode === 'navigate'"));
    expect(sw, contains("event.data.type !== 'warm'"));
  });

  test('warm aquece a lista used da página e só percorre WARM com full', () {
    // O engine (main.dart.*, canvaskit/<hash>/) não está em nenhuma lista:
    // é a página que diz o que carregou, e só isso entra no cache.
    expect(sw, contains('event.data.used'));
    expect(sw, contains('event.data.full'));
    expect(sw, contains('async function warm(used, full)'));
    expect(sw, contains('if (!full) return;'));
    expect(sw, contains("cache: 'force-cache'"));
  });

  test('nunca apaga o cache dos PDFs offline do Dart', () {
    expect(sw, isNot(contains('plpcg-pdfs-store')));
    expect(sw, contains("startsWith('plpcg-shell-')"));
  });

  test('flutter_bootstrap.js não regista o stub do Flutter', () {
    // O stub flutter_service_worker.js faz unregister + client.navigate:
    // no mesmo scope que o sw.js seria um loop de reload a cada boot.
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, contains('wasmAllowList: { webkit: true }'));
  });
}
```

Run: `flutter test test/web/sw_template_test.dart 2>&1 | tail -6`
Expected: FAIL — `web/sw.js` não existe (`FileSystemException`) e `serviceWorkerSettings` presente.

- [ ] **Step 2: `web/flutter_bootstrap.js`**

Substituir o conteúdo inteiro por:

```js
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
    // WebKit (Safari/iPad) usa dart2js por padrão; habilita skwasm quando WasmGC existe.
    wasmAllowList: { webkit: true },
  },
  // Sem serviceWorkerSettings: o flutter_service_worker.js do Flutter 3.47 é
  // um stub que se desregista e faz client.navigate (reload) — no mesmo scope
  // que o sw.js próprio (registado em index.html após o primeiro frame) seria
  // um loop. O shell offline é do web/sw.js.
});
```

- [ ] **Step 3: `web/sw.js`**

```js
'use strict';
// Service worker do shell do PLPCG (spec 2026-09-14-pwa-shell-offline).
//
// Cobre só o shell same-origin: index.html, flutter_bootstrap, main.dart.*,
// engine (canvaskit/<hash>/), isar, fontes, ícones, manifest. Catálogo e
// materiais continuam a cargo do Dart (Isar + Cache API "plpcg-pdfs-store-v1"):
// requests para outras origens nunca passam por respondWith e o cache dos
// PDFs nunca é tocado aqui.
//
// Três classes de ficheiro:
//  - CRITICAL: precache no install, all-or-nothing (~3 MB).
//  - ENGINE (main.dart.wasm|mjs|js e canvaskit/<hash>/**): NÃO está em lista
//    nenhuma. O flutter_bootstrap.js escolhe a variante por browser (skwasm no
//    Chrome, skwasm_heavy no Safari/Firefox, canvaskit/chromium + main.dart.js
//    sem WasmGC) e só a usada interessa: a página manda-nos a lista `used`
//    do que carregou e nós copiamo-la para o cache — vem do cache HTTP,
//    custa ~0 rede. Precachear todas as variantes eram ~33 MB por deploy.
//  - WARM: o resto carregável, em background e só sem Save-Data/2g.
//
// Os três placeholders são substituídos por scripts/generate_sw_manifest.py
// no pós-build (cache_bust_web_entrypoints.sh). Em `flutter run` ficam
// intactos e o index.html não regista este ficheiro.
const TAG = '__PLPCG_TAG__';
const CRITICAL = __PLPCG_CRITICAL__;
const WARM = __PLPCG_WARM__;
const CACHE = `plpcg-shell-${TAG}`;
// Caches do flutter_service_worker.js de versões antigas do Flutter: já não
// há quem os limpe (o stub 3.47 só se desregista).
const LEGACY_CACHES = ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'];
const SCOPE_PATH = new URL(self.registration.scope).pathname;
// Mudam de conteúdo sem mudar de nome: rede primeiro, cache só sem rede (S10).
const NETWORK_FIRST = new Set([SCOPE_PATH + 'version.json', SCOPE_PATH + 'manifest.json']);
// Nunca entram no cache mesmo que a página os tenha carregado: o próprio SW
// (congelaria a versão) e o stub do Flutter.
const NEVER_CACHED = new Set([SCOPE_PATH + 'sw.js', SCOPE_PATH + 'flutter_service_worker.js']);
const USED_PARALLEL = 4;

// Falhar um item de CRITICAL falha o install inteiro e o SW anterior continua
// a servir — é o comportamento desejado (S3).
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(CRITICAL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((key) => (key.startsWith('plpcg-shell-') && key !== CACHE) || LEGACY_CACHES.includes(key))
          .map((key) => caches.delete(key)),
      ))
      .then(() => self.clients.claim()),
  );
});

// index.html envia {type:'warm', used:[...], full:bool} depois do
// flutter-first-frame. `used` = URLs same-origin que a página carregou
// (performance resource timing) — inclui o engine escolhido; vem sempre.
// `full` = false com Save-Data / 2g: aquece só `used`, não WARM. Chega mesmo
// com o SW ainda em install: corre em paralelo.
self.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'warm') return;
  const used = Array.isArray(event.data.used) ? event.data.used : [];
  const full = event.data.full === true;
  event.waitUntil(warm(used, full));
});

async function warm(used, full) {
  const cache = await caches.open(CACHE);
  await warmUsed(cache, used);
  if (!full) return;
  // Sequencial: a warm corre enquanto o app está em uso; não disputa banda.
  for (const url of WARM) {
    if (await cache.match(url)) continue;
    try {
      const response = await fetch(url);
      if (response.ok) await cache.put(url, response);
    } catch (e) {
      // Uma falha individual nunca impede as restantes nem o boot (S3).
    }
  }
}

// Só same-origin e nunca o SW/stub; até USED_PARALLEL em paralelo porque as
// respostas vêm do cache HTTP. `force-cache`: o conteúdo de um URL com ?v=
// ou hash nunca muda dentro da tag, logo não vale a pena revalidar os
// entrypoints no-cache (main.dart.wasm?v=…) — poupa um round-trip por ficheiro.
async function warmUsed(cache, used) {
  const queue = [];
  for (const entry of used) {
    let url;
    try {
      url = new URL(entry);
    } catch (e) {
      continue;
    }
    if (url.origin !== self.location.origin || NEVER_CACHED.has(url.pathname)) continue;
    queue.push(url.href);
  }
  const worker = async () => {
    while (queue.length) {
      const href = queue.shift();
      if (await cache.match(href)) continue;
      try {
        const response = await fetch(href, { cache: 'force-cache' });
        if (response.ok && response.status === 200 && response.type === 'basic') {
          await cache.put(href, response);
        }
      } catch (e) {
        // Falha individual (ex.: 404 de um preload errado) nunca trava o resto.
      }
    }
  };
  await Promise.all(Array.from({ length: USED_PARALLEL }, worker));
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  // Range (áudio/PDF por partes) tem de ir à rede: uma resposta 200 inteira
  // vinda do cache confunde os consumidores de media.
  if (request.method !== 'GET' || request.headers.has('range')) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate' || url.pathname === SCOPE_PATH || url.pathname === SCOPE_PATH + 'index.html') {
    event.respondWith(networkFirst(request, './'));
  } else if (NETWORK_FIRST.has(url.pathname)) {
    event.respondWith(networkFirst(request, request));
  } else {
    event.respondWith(cacheFirst(request));
  }
});

// Rede primeiro sem atualizar o cache: o index.html em cache é sempre o da
// própria tag (consistente com os chunks precacheados). Um deploy novo chega
// por um sw.js?v=<tag nova>, nunca por este cache.
async function networkFirst(request, fallbackKey) {
  try {
    return await fetch(request);
  } catch (e) {
    const cached = await caches.match(fallbackKey, { cacheName: CACHE, ignoreSearch: true });
    if (cached) return cached;
    // Sem rede e sem index.html em cache: o browser mostra o erro nativo.
    throw e;
  }
}

// Ficheiros com hash / ?v= / canvaskit/<hash>/ / assets: o conteúdo de um URL
// nunca muda dentro da mesma tag. Preenche no primeiro fetch controlado
// (chunks deferidos, engine numa visita em que a lista `used` não chegou).
async function cacheFirst(request) {
  const cached = await caches.match(request, { cacheName: CACHE });
  if (cached) return cached;
  const response = await fetch(request);
  // Só respostas completas e same-origin entram — nunca opaque, erro ou 206.
  if (response.ok && response.status === 200 && response.type === 'basic') {
    const cache = await caches.open(CACHE);
    await cache.put(request, response.clone());
  }
  return response;
}
```

Run: `flutter test test/web/sw_template_test.dart 2>&1 | tail -3`
Expected: `All tests passed!`

- [ ] **Step 4: Sintaxe do template (Node, se existir)**

Run: `command -v node >/dev/null && node --check web/sw.js && echo "sintaxe OK" || echo "node ausente — a Task 7 valida em Chrome"`
Expected: `sintaxe OK` (os placeholders são identificadores válidos; só falhariam em runtime).

- [ ] **Step 5: Commit**

```bash
dart format test/web/sw_template_test.dart
git add web/sw.js web/flutter_bootstrap.js test/web/sw_template_test.dart
git commit -m "feat(web): template do service worker do shell; bootstrap deixa de registar o stub do Flutter"
```

---

### Task 4: Gerador `CRITICAL`/`WARM` no pós-build

**Files:**
- Create: `scripts/generate_sw_manifest.py`
- Modify: `scripts/cache_bust_web_entrypoints.sh` (l.13 `SCRIPT_DIR`; depois da l.116 `PY`)
- Create: `test/support/web_build_fixture.dart`
- Modify: `test/web/cache_bust_web_entrypoints_test.dart` (reescrito com o fixture)
- Test: `test/web/sw_manifest_generation_test.dart`

**Interfaces:**
- Consumes: `build/web/version.json` com `web_cache_tag`, `material_icons_tag`, `canvaskit_tag` (gravados pelo bloco Python existente); `build/web/sw.js` (Task 3).
- Produces: CLI `python3 scripts/generate_sw_manifest.py [build/web]` (exit ≠ 0 se faltar `sw.js`, tags, placeholders ou um ficheiro de `CRITICAL`); funções `classify(web_dir: Path, tag: str, icons_tag: str) -> tuple[list[str], list[str]]` (devolve `(critical, warm)`; a classe ENGINE — `main.dart.*` e `canvaskit/**` — fica fora das duas), `is_engine(posix: str) -> bool`, `disk_path(url: str) -> str`, `render(template: str, tag: str, critical: list[str], warm: list[str]) -> str`. Stdout: `OK: sw.js tag=<tag> CRITICAL=<n> (<x> MB) WARM=<n> (<y> MB) ENGINE fora das listas=<n>`.

- [ ] **Step 1: Fixture partilhado**

`test/support/web_build_fixture.dart`:

```dart
import 'dart:io';

/// `build/web` mínimo para os testes dos scripts de pós-build
/// (`cache_bust_web_entrypoints.sh` + `generate_sw_manifest.py`).
///
/// Tem tudo o que o gerador do service worker exige em `CRITICAL`: sem um
/// destes ficheiros o script falha de propósito (spec §3.2). Os conteúdos são
/// marcadores curtos — os testes só olham para nomes, tags e listas.
const kFixtureBootstrap = '''
{"engineRevision":"abc","mainWasmPath":"main.dart.wasm","jsSupportRuntimePath":"main.dart.mjs","mainJsPath":"main.dart.js"}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
  },
});
''';

const kFixtureIndex = '''
<link rel="preload" href="main.dart.wasm" as="fetch" crossorigin>
<script>
  link.href = 'canvaskit/skwasm.wasm';
</script>
<script>
  var swTag = '__PLPCG_TAG__';
  navigator.serviceWorker.register('sw.js?v=' + swTag);
</script>
<script src="flutter_bootstrap.js" async></script>
''';

void writeWebFile(Directory webDir, String relative, String content) {
  final file = File('${webDir.path}/$relative');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Engine plano (`canvaskit/` sem hash), como sai do `flutter build web`:
/// duas variantes (o gerador tem de deixar todas fora das listas) e um
/// `.symbols` que também nunca entra.
void writeFixtureCanvaskit(Directory webDir, {String skwasmJs = 'skwasm v1'}) {
  writeWebFile(webDir, 'canvaskit/skwasm.js', skwasmJs);
  writeWebFile(webDir, 'canvaskit/skwasm.wasm', 'skwasm wasm v1');
  writeWebFile(webDir, 'canvaskit/skwasm.js.symbols', 'symbols');
  writeWebFile(webDir, 'canvaskit/chromium/canvaskit.js', 'canvaskit chromium v1');
  writeWebFile(
    webDir,
    'canvaskit/chromium/canvaskit.wasm',
    'canvaskit chromium wasm v1',
  );
}

/// Escreve o build inteiro (entrypoints, engine, assets, `sw.js` real e
/// `_headers` real). Chamar de novo depois de apagar a pasta para simular um
/// build novo.
void writeFixtureWebBuild(Directory webDir) {
  writeWebFile(webDir, 'index.html', kFixtureIndex);
  writeWebFile(webDir, 'flutter_bootstrap.js', kFixtureBootstrap);
  writeWebFile(webDir, 'flutter.js', 'flutter js');
  writeWebFile(webDir, 'main.dart.js', 'js');
  writeWebFile(webDir, 'main.dart.wasm', 'wasm');
  writeWebFile(webDir, 'main.dart.mjs', 'mjs');
  writeWebFile(webDir, 'isar_plus.js', 'isar js');
  writeWebFile(webDir, 'isar_plus.wasm', 'isar wasm');
  writeWebFile(webDir, 'manifest.json', '{"id":"/"}');
  writeWebFile(webDir, 'version.json', '{"version":"1.0.0"}');
  writeWebFile(webDir, 'flutter_service_worker.js', 'stub');
  writeWebFile(webDir, '.last_build_id', 'abc');
  writeWebFile(webDir, '_headers', File('web/_headers').readAsStringSync());
  writeWebFile(webDir, 'sw.js', File('web/sw.js').readAsStringSync());
  writeWebFile(webDir, 'favicon.png', 'png');
  writeWebFile(webDir, 'icons/Icon-192.png', 'png');
  writeWebFile(webDir, 'assets/AssetManifest.bin', 'bin');
  writeWebFile(webDir, 'assets/AssetManifest.bin.json', '"bin"');
  writeWebFile(
    webDir,
    'assets/FontManifest.json',
    '[{"family":"MaterialIcons","fonts":[{"asset":"fonts/MaterialIcons-Regular.otf"}]}]',
  );
  writeWebFile(webDir, 'assets/fonts/MaterialIcons-Regular.otf', 'otf');
  // Nome literal com %5B: é assim que o Flutter grava a fonte variável.
  writeWebFile(webDir, 'assets/assets/fonts/EBGaramond%5Bwght%5D.ttf', 'ttf');
  writeWebFile(webDir, 'assets/assets/branding/logo.svg', '<svg/>');
  writeWebFile(webDir, 'assets/NOTICES', 'notices');
  writeWebFile(webDir, 'assets/packages/pdfrx/assets/pdfium.wasm', 'pdfium');
  writeWebFile(webDir, 'main_deferred.part.js', 'chunk');
  writeFixtureCanvaskit(webDir);
}
```

- [ ] **Step 2: Reescrever `test/web/cache_bust_web_entrypoints_test.dart` com o fixture**

Conteúdo inteiro:

```dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/web_build_fixture.dart';

/// Valida [scripts/cache_bust_web_entrypoints.sh] sobre um `build/web` mínimo.
///
/// O `_headers` serve `/canvaskit/*` como `immutable` por 1 ano e o nome dos
/// arquivos do engine (`skwasm.js`, `skwasm.wasm`…) não muda entre versões do
/// Flutter: sem hash no caminho, um upgrade de engine deixa o navegador com o
/// `skwasm.js` velho e o `main.dart.wasm` novo (LinkError no boot).
void main() {
  late Directory tmp;
  late Directory webDir;

  Future<ProcessResult> runScript() => Process.run('bash', [
    'scripts/cache_bust_web_entrypoints.sh',
    webDir.path,
  ]);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cache_bust_test');
    webDir = Directory('${tmp.path}/web')..createSync();
    writeFixtureWebBuild(webDir);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, dynamic> readVersion() =>
      jsonDecode(File('${webDir.path}/version.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'move canvaskit/ para canvaskit/<hash>/ e reaponta loader e preload',
    () async {
      final result = await runScript();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      final tag = readVersion()['canvaskit_tag'];
      expect(tag, isA<String>());
      expect(tag, matches(RegExp(r'^[0-9a-f]{12}$')));

      expect(File('${webDir.path}/canvaskit/skwasm.js').existsSync(), isFalse);
      expect(
        File('${webDir.path}/canvaskit/$tag/skwasm.js').readAsStringSync(),
        'skwasm v1',
      );
      expect(
        File('${webDir.path}/canvaskit/$tag/chromium/canvaskit.js')
            .existsSync(),
        isTrue,
      );

      final bootstrapOut = File('${webDir.path}/flutter_bootstrap.js')
          .readAsStringSync();
      expect(bootstrapOut, contains('canvasKitBaseUrl: "canvaskit/$tag"'));

      final indexOut = File('${webDir.path}/index.html').readAsStringSync();
      expect(indexOut, contains("link.href = 'canvaskit/$tag/skwasm.wasm'"));
      expect(indexOut, isNot(contains("'canvaskit/skwasm.wasm'")));
    },
  );

  test('hash do canvaskit muda quando o engine muda', () async {
    final first = await runScript();
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    final tagV1 = readVersion()['canvaskit_tag'] as String;

    // Novo build: tudo plano outra vez, com skwasm.js de outro engine.
    webDir.deleteSync(recursive: true);
    webDir.createSync();
    writeFixtureWebBuild(webDir);
    writeWebFile(webDir, 'canvaskit/skwasm.js', 'skwasm v2');

    final second = await runScript();
    expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
    final tagV2 = readVersion()['canvaskit_tag'] as String;

    expect(tagV2, isNot(tagV1));
    expect(
      File('${webDir.path}/canvaskit/$tagV2/skwasm.js').readAsStringSync(),
      'skwasm v2',
    );
  });

  test(
    'mantém o cache-bust já existente dos entrypoints e do MaterialIcons',
    () async {
      final result = await runScript();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      final version = readVersion();
      final tag = version['web_cache_tag'] as String;
      final bootstrapOut = File('${webDir.path}/flutter_bootstrap.js')
          .readAsStringSync();
      expect(bootstrapOut, contains('"mainWasmPath":"main.dart.wasm?v=$tag"'));

      final icons = version['material_icons_tag'] as String;
      expect(
        File('${webDir.path}/assets/fonts/MaterialIcons-Regular.$icons.otf')
            .existsSync(),
        isTrue,
      );
    },
  );
}
```

Run: `flutter test test/web/cache_bust_web_entrypoints_test.dart 2>&1 | tail -3`
Expected: `All tests passed!` (o script ainda não gera o SW; o fixture só acrescentou ficheiros).

- [ ] **Step 3: Teste do gerador que falha**

`test/web/sw_manifest_generation_test.dart`:

```dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/web_build_fixture.dart';

/// Valida `scripts/generate_sw_manifest.py` (chamado por
/// `cache_bust_web_entrypoints.sh`) sobre um `build/web` mínimo: as listas
/// `CRITICAL`/`WARM` do `sw.js`, o engine fora das duas (é a página que diz
/// ao SW qual variante carregou), a substituição dos placeholders e a falha
/// quando um ficheiro crítico não existe (spec §3.2, §5; plano P1).
void main() {
  late Directory tmp;
  late Directory webDir;

  Future<ProcessResult> runScript() => Process.run('bash', [
    'scripts/cache_bust_web_entrypoints.sh',
    webDir.path,
  ]);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sw_manifest_test');
    webDir = Directory('${tmp.path}/web')..createSync();
    writeFixtureWebBuild(webDir);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, dynamic> readVersion() =>
      jsonDecode(File('${webDir.path}/version.json').readAsStringSync())
          as Map<String, dynamic>;

  String readSw() => File('${webDir.path}/sw.js').readAsStringSync();

  /// Extrai o array JSON atribuído a `const <name> = [...];` no sw.js gerado.
  List<String> listFromSw(String sw, String name) {
    final match = RegExp('const $name = (\\[.*?\\]);').firstMatch(sw);
    expect(match, isNotNull, reason: 'sw.js sem const $name = [...]');
    return (jsonDecode(match!.group(1)!) as List).cast<String>();
  }

  test('substitui os placeholders e CRITICAL cobre o shell sem o engine', () async {
    final result = await runScript();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final version = readVersion();
    final tag = version['web_cache_tag'] as String;
    final icons = version['material_icons_tag'] as String;

    final sw = readSw();
    expect(sw, isNot(contains('__PLPCG_')));
    expect(sw, contains("const TAG = '$tag';"));

    final critical = listFromSw(sw, 'CRITICAL');
    expect(critical.first, './');
    expect(
      critical,
      containsAll([
        'flutter_bootstrap.js?v=$tag',
        'flutter.js',
        'isar_plus.js',
        'isar_plus.wasm',
        'manifest.json',
        'version.json',
        'assets/FontManifest.json',
        'assets/AssetManifest.bin.json',
        'assets/AssetManifest.bin',
        'assets/fonts/MaterialIcons-Regular.$icons.otf?v=$tag',
        // %5B no disco → %255B no URL: é o que o engine pede (FontManifest).
        'assets/assets/fonts/EBGaramond%255Bwght%255D.ttf',
        'icons/Icon-192.png',
        'favicon.png',
      ]),
    );
    expect(critical.toSet().length, critical.length, reason: 'sem duplicados');
    expect(result.stdout, contains('CRITICAL='));
    expect(result.stdout, contains('WARM='));
    expect(result.stdout, contains('ENGINE fora das listas='));
  });

  test('engine (main.dart.* e canvaskit/) fica fora das duas listas', () async {
    // A variante do engine é escolhida por browser pelo flutter_bootstrap.js;
    // só a usada entra no cache, via a lista `used` que o index.html envia.
    final result = await runScript();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final sw = readSw();
    final ck = readVersion()['canvaskit_tag'] as String;
    final all = [...listFromSw(sw, 'CRITICAL'), ...listFromSw(sw, 'WARM')];
    expect(all.where((u) => u.startsWith('main.dart.')), isEmpty);
    expect(all.where((u) => u.startsWith('canvaskit/')), isEmpty);
    // O engine existe no build (o cache-bust moveu-o para canvaskit/<hash>/):
    // não está nas listas por decisão, não por ausência.
    expect(File('${webDir.path}/canvaskit/$ck/skwasm.wasm').existsSync(), isTrue);
    expect(File('${webDir.path}/main.dart.wasm').existsSync(), isTrue);
  });

  test('WARM tem o resto carregável e exclui SW, stub, symbols e metadados', () async {
    final result = await runScript();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final sw = readSw();
    final critical = listFromSw(sw, 'CRITICAL');
    final warm = listFromSw(sw, 'WARM');
    expect(
      warm,
      containsAll([
        'assets/assets/branding/logo.svg',
        'assets/NOTICES',
        'assets/packages/pdfrx/assets/pdfium.wasm',
        'main_deferred.part.js',
      ]),
    );
    for (final excluded in [
      'sw.js',
      'flutter_service_worker.js',
      '.last_build_id',
      '_headers',
      '.symbols',
    ]) {
      expect(
        [...critical, ...warm].where((u) => u.endsWith(excluded)),
        isEmpty,
        reason: '$excluded não pode entrar em nenhuma lista',
      );
    }
    expect(critical.toSet().intersection(warm.toSet()), isEmpty);
  });

  test('ficheiro crítico ausente faz o pós-build falhar', () async {
    // isar_plus.wasm continua em CRITICAL e o cache-bust não o exige (só o
    // gerador): a falha vem mesmo da verificação das listas.
    File('${webDir.path}/isar_plus.wasm').deleteSync();
    final result = await runScript();
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}${result.stderr}', contains('isar_plus.wasm'));
  });

  test('sw.js sem placeholders (build já processado) faz o pós-build falhar', () async {
    writeWebFile(webDir, 'sw.js', "const TAG = 'x';");
    final result = await runScript();
    expect(result.exitCode, isNot(0));
    // O gerador acusa o primeiro placeholder em falta (__PLPCG_TAG__).
    expect('${result.stdout}${result.stderr}', contains('sem placeholder'));
  });
}
```

Run: `flutter test test/web/sw_manifest_generation_test.dart 2>&1 | tail -8`
Expected: FAIL — `sw.js` ainda com `__PLPCG_` (três testes); os dois testes de falha esperam exit ≠ 0 e o script sai 0 → cinco falhas.

- [ ] **Step 4: `scripts/generate_sw_manifest.py`**

```python
#!/usr/bin/env python3
"""Gera as listas CRITICAL/WARM do service worker e preenche build/web/sw.js.

Spec: docs/superpowers/specs/2026-09-14-pwa-shell-offline-design.md (§3.1, §3.2);
plano 2026-09-14-pwa-shell-offline.md, precisão P1 (classe ENGINE).

Corre depois de cache_bust_web_entrypoints.sh ter reescrito os ?v=<tag>,
renomeado MaterialIcons-Regular.<hash>.otf e movido canvaskit/ → canvaskit/<hash>/:
lê as tags de version.json e classifica todos os ficheiros de build/web em
CRITICAL (install), ENGINE (fora do sw.js) e WARM (background).

Uso: python3 scripts/generate_sw_manifest.py [build/web]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from urllib.parse import quote, unquote

# Nunca entram em nenhuma lista: o próprio SW (cachear-se a si mesmo congelaria
# a versão), o stub do Flutter, e metadados que o browser nunca pede.
EXCLUDED_NAMES = frozenset(
    {"sw.js", "flutter_service_worker.js", ".last_build_id", "_headers", "_redirects"}
)
# Mapas de símbolos do engine (~10 MB): só para depuração; nada os carrega.
EXCLUDED_SUFFIXES = (".symbols",)
FONT_SUFFIXES = (".otf", ".ttf", ".woff", ".woff2")
# ENGINE: o flutter_bootstrap.js 3.47 escolhe a variante por browser (skwasm no
# Chrome/Edge/Android; skwasm_heavy no Safari/Firefox, sem ImageDecoder nem
# v8BreakIterator; canvaskit ou chromium/canvaskit + main.dart.js sem WasmGC,
# iOS ≤ 17). Listar um par fixo deixava o iPhone sem engine offline; listar
# todos eram ~33 MB por deploy. Por isso main.dart.* e canvaskit/<hash>/**
# ficam FORA das duas listas: a página manda ao SW a lista `used` do que
# carregou (resource timing) e só essa variante entra no cache.
ENGINE_NAMES = frozenset({"main.dart.wasm", "main.dart.mjs", "main.dart.js"})
ENGINE_PREFIX = "canvaskit/"
PLACEHOLDERS = ("__PLPCG_TAG__", "__PLPCG_CRITICAL__", "__PLPCG_WARM__")


def is_engine(posix: str) -> bool:
    return posix in ENGINE_NAMES or posix.startswith(ENGINE_PREFIX)


def url_for(relative: Path) -> str:
    # Os nomes em build/web já são URL-safe (o Flutter grava
    # `EBGaramond%5Bwght%5D.ttf` literalmente); quote() codifica o `%` → `%25`,
    # que é exatamente o URL que o engine pede (FontManifest.json + encode) e
    # que a produção serve.
    return quote(relative.as_posix(), safe="/")


def disk_path(url: str) -> str:
    """URL relativa (com ou sem ?v=) → caminho relativo no disco."""
    path = url.split("?", 1)[0]
    if path == "./":
        return "index.html"
    return unquote(path)


def classify(web_dir: Path, tag: str, icons_tag: str) -> tuple[list[str], list[str]]:
    """Devolve (critical, warm). CRITICAL por ordem de importância; WARM = o
    resto carregável; ENGINE (main.dart.*, canvaskit/**) fica fora de ambas."""
    query = f"?v={tag}"
    critical = [
        "./",
        f"flutter_bootstrap.js{query}",
        "flutter.js",
        "isar_plus.js",
        "isar_plus.wasm",
        "manifest.json",
        "version.json",
        "assets/FontManifest.json",
        f"assets/fonts/MaterialIcons-Regular.{icons_tag}.otf{query}",
    ]
    # AssetManifest: o nome varia entre versões do Flutter (.bin.json, .bin,
    # .json); entra o que existir.
    for manifest in ("assets/AssetManifest.bin.json", "assets/AssetManifest.bin", "assets/AssetManifest.json"):
        if (web_dir / manifest).is_file():
            critical.append(manifest)
    listed = {disk_path(u) for u in critical}

    fonts: list[str] = []
    icons: list[str] = []
    warm: list[str] = []
    for path in sorted(p for p in web_dir.rglob("*") if p.is_file()):
        rel = path.relative_to(web_dir)
        posix = rel.as_posix()
        if posix in listed or rel.name in EXCLUDED_NAMES or rel.name.endswith(EXCLUDED_SUFFIXES):
            continue
        if is_engine(posix):
            continue
        url = url_for(rel)
        if posix.startswith("assets/") and rel.suffix in FONT_SUFFIXES:
            fonts.append(url)
        elif (posix.startswith("icons/") and rel.suffix == ".png") or posix == "favicon.png":
            icons.append(url)
        else:
            warm.append(url)
    return critical + fonts + icons, warm


def count_engine(web_dir: Path) -> int:
    return sum(
        1
        for p in web_dir.rglob("*")
        if p.is_file() and is_engine(p.relative_to(web_dir).as_posix())
    )


def render(template: str, tag: str, critical: list[str], warm: list[str]) -> str:
    for placeholder in PLACEHOLDERS:
        if placeholder not in template:
            raise SystemExit(f"sw.js sem placeholder {placeholder} (já processado? template alterado?)")
    out = (
        template.replace("__PLPCG_TAG__", tag)
        .replace("__PLPCG_CRITICAL__", json.dumps(critical))
        .replace("__PLPCG_WARM__", json.dumps(warm))
    )
    if "__PLPCG_" in out:
        raise SystemExit("sw.js ainda com placeholder __PLPCG_ depois da substituição")
    return out


def size_mb(web_dir: Path, urls: list[str]) -> float:
    return sum((web_dir / disk_path(u)).stat().st_size for u in urls) / 1_000_000


def main(argv: list[str]) -> int:
    web_dir = Path(argv[1] if len(argv) > 1 else "build/web")
    sw = web_dir / "sw.js"
    if not sw.is_file():
        raise SystemExit(f"{sw} ausente — web/sw.js não foi copiado pelo flutter build?")
    version = json.loads((web_dir / "version.json").read_text())
    try:
        tag = version["web_cache_tag"]
        icons_tag = version["material_icons_tag"]
    except KeyError as err:
        raise SystemExit(f"version.json sem {err}: corra cache_bust_web_entrypoints.sh antes")
    # O engine não entra nas listas, mas o build tem de o ter movido para
    # canvaskit/<hash>/ (senão o cache-bust não correu e o ?v= está errado).
    if "canvaskit_tag" not in version or not (web_dir / "canvaskit" / version["canvaskit_tag"]).is_dir():
        raise SystemExit("canvaskit/<hash>/ ausente: corra cache_bust_web_entrypoints.sh antes")

    critical, warm = classify(web_dir, tag, icons_tag)
    missing = [u for u in critical if not (web_dir / disk_path(u)).is_file()]
    if missing:
        raise SystemExit("CRITICAL referencia ficheiros inexistentes:\n  " + "\n  ".join(missing))

    sw.write_text(render(sw.read_text(), tag, critical, warm))
    print(
        f"OK: sw.js tag={tag} "
        f"CRITICAL={len(critical)} ({size_mb(web_dir, critical):.1f} MB) "
        f"WARM={len(warm)} ({size_mb(web_dir, warm):.1f} MB) "
        f"ENGINE fora das listas={count_engine(web_dir)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
```

- [ ] **Step 5: Chamar o gerador em `scripts/cache_bust_web_entrypoints.sh`**

1. Depois da linha 13 (`set -euo pipefail`) inserir:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

2. Depois da linha `PY` que fecha o heredoc (l.116 original) e antes do `echo "OK: cache-bust aplicado…"` inserir:

```bash
# Listas CRITICAL/WARM do sw.js: precisa das três tags já gravadas em
# version.json pelo bloco acima. Falha se um ficheiro crítico não existir.
python3 "$SCRIPT_DIR/generate_sw_manifest.py" "$WEB_DIR"
```

Run: `chmod +x scripts/generate_sw_manifest.py && flutter test test/web/sw_manifest_generation_test.dart test/web/cache_bust_web_entrypoints_test.dart 2>&1 | tail -3`
Expected: `All tests passed!` (8 testes).

- [ ] **Step 6: Commit**

```bash
dart format test/support/web_build_fixture.dart test/web/cache_bust_web_entrypoints_test.dart test/web/sw_manifest_generation_test.dart
git add scripts/generate_sw_manifest.py scripts/cache_bust_web_entrypoints.sh test/support/web_build_fixture.dart test/web/cache_bust_web_entrypoints_test.dart test/web/sw_manifest_generation_test.dart
git commit -m "feat(web): gerador das listas CRITICAL/WARM do sw.js no pós-build (engine fica fora; falha se faltar crítico)"
```

---

### Task 5: Registo em `index.html`, tag no pós-build e verify com placeholders

**Files:**
- Modify: `web/index.html` (novo `<script>` logo depois da l.3 `<head>`; novo `<script>` depois da l.277 `</script>`, antes do comentário `You can customize the "flutter_bootstrap.js"`)
- Modify: `scripts/cache_bust_web_entrypoints.sh` (bloco Python, depois de `content = content.replace(preload_old, …)`, l.77 original)
- Modify: `scripts/verify_web_headers_artifact.sh`
- Modify: `scripts/web_build.sh` (l.44–45)
- Test: `test/web/web_index_sw_registration_test.dart`; acrescentos em `test/web/sw_manifest_generation_test.dart`

**Interfaces:**
- Consumes: `sw.js` gerado (Task 4).
- Produces: `index.html` chama `performance.setResourceTimingBufferSize(600)` antes de qualquer outro script; regista `'sw.js?v=' + swTag` após `flutter-first-frame` e envia `{ type: 'warm', used: <URLs same-origin do resource timing>, full: <sem Save-Data/2g> }` (também em `controllerchange`); `verify_web_headers_artifact.sh <_headers>` exige `sw.js` e `index.html` sem `__PLPCG_` no mesmo diretório.

- [ ] **Step 1: Testes que falham**

`test/web/web_index_sw_registration_test.dart`:

```dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Registo do service worker em [web/index.html] (spec S6, S9): só depois do
/// `flutter-first-frame`, com a tag do build, e `warm` só sem Save-Data/2g.
void main() {
  late String html;

  setUp(() {
    html = File('web/index.html').readAsStringSync();
  });

  test('regista sw.js?v=<tag> depois do handler do loader', () {
    final register = html.indexOf(
      "navigator.serviceWorker.register('sw.js?v=' + swTag)",
    );
    expect(register, greaterThan(0));
    // A tag é substituída pelo cache_bust_web_entrypoints.sh; em flutter run
    // fica o placeholder e o registo é saltado.
    expect(html, contains("var swTag = '__PLPCG_TAG__';"));
    expect(html, contains(r'/^[0-9a-f]{12}$/.test(swTag)'));

    final hideLoader = html.indexOf(
      "window.addEventListener('flutter-first-frame', hideLoader",
    );
    expect(register, greaterThan(hideLoader));
    final listener = html.lastIndexOf(
      "addEventListener('flutter-first-frame'",
      register,
    );
    expect(listener, greaterThan(hideLoader));
  });

  test('warm envia a lista used sempre e full só sem Save-Data / 2g', () {
    expect(html, contains('navigator.connection'));
    expect(html, contains('saveData'));
    expect(html, contains(r"/(^|-)2g$/"));
    expect(html, contains("performance.getEntriesByType('resource')"));
    expect(html, contains("n.indexOf(location.origin + '/') === 0"));
    expect(html, contains("{ type: 'warm', used: used, full: full }"));
    expect(html, contains("'controllerchange'"));
  });

  test('buffer de resource timing alargado antes de qualquer script', () {
    // O default (250 entradas) enche durante o boot; sem isto a lista `used`
    // perdia o engine e o app não abria offline.
    final buffer = html.indexOf('performance.setResourceTimingBufferSize(600)');
    expect(buffer, greaterThan(0));
    expect(buffer, lessThan(html.indexOf('<base href')));
    expect(buffer, lessThan(html.indexOf('supportsSkwasmPreload')));
  });
}
```

Em `test/web/sw_manifest_generation_test.dart`, antes do teste `'ficheiro crítico ausente…'`, acrescentar:

```dart
  test('index.html fica com a tag do registo e sem placeholder', () async {
    final result = await runScript();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final tag = readVersion()['web_cache_tag'] as String;
    final indexOut = File('${webDir.path}/index.html').readAsStringSync();
    expect(indexOut, contains("var swTag = '$tag';"));
    expect(indexOut, isNot(contains('__PLPCG_')));
  });

  test('verify_web_headers_artifact.sh rejeita placeholders e aceita o gerado', () async {
    Future<ProcessResult> verify() => Process.run('bash', [
      'scripts/verify_web_headers_artifact.sh',
      '${webDir.path}/_headers',
    ]);
    final before = await verify();
    expect(before.exitCode, isNot(0), reason: 'sw.js ainda com __PLPCG_');

    final generated = await runScript();
    expect(generated.exitCode, 0, reason: '${generated.stdout}\n${generated.stderr}');
    final after = await verify();
    expect(after.exitCode, 0, reason: '${after.stdout}\n${after.stderr}');
  });
```

Run: `flutter test test/web/web_index_sw_registration_test.dart test/web/sw_manifest_generation_test.dart 2>&1 | tail -8`
Expected: FAIL — `register` = -1; `index.html` do fixture mantém `__PLPCG_TAG__`; `verify` sai 0 antes de gerar.

- [ ] **Step 2: `web/index.html`**

1. Logo depois da linha 3 (`<head>`), antes do comentário do `<base href>`, inserir:

```html
  <!-- O sw.js aquece o que a página carregou (performance resource timing);
       o buffer default (250) enche durante o boot e perderia o engine. Tem
       de vir antes de qualquer outro pedido. -->
  <script>performance.setResourceTimingBufferSize(600);</script>
```

2. Depois da linha `</script>` que fecha o IIFE do loader (l.277 original) e antes de `<!--` / `You can customize the "flutter_bootstrap.js" script.`, inserir:

```html
  <script>
    // Service worker do shell (web/sw.js — spec 2026-09-14-pwa-shell-offline).
    // Registado só depois do primeiro frame: o boot é o caminho crítico e o
    // SW não ajuda na primeira visita. A tag vem do cache_bust_web_entrypoints.sh
    // (12 hex); em `flutter run` fica o placeholder e não registamos nada —
    // o template tem SyntaxError em runtime.
    (function () {
      var swTag = '__PLPCG_TAG__';
      if (!('serviceWorker' in navigator)) return;
      if (!/^[0-9a-f]{12}$/.test(swTag)) return;
      window.addEventListener('flutter-first-frame', function () {
        navigator.serviceWorker.register('sw.js?v=' + swTag).then(function (reg) {
          // `used`: tudo o que esta página carregou da nossa origem — inclui
          // main.dart.* e a variante do engine que o flutter_bootstrap
          // escolheu para este browser. O SW copia-a do cache HTTP (~0 rede),
          // por isso vai SEMPRE, mesmo com Save-Data. `full` liga a lista
          // WARM (resto do shell), que custa rede: só sem Save-Data / 2g.
          var c = navigator.connection || {};
          var full = !(c.saveData || /(^|-)2g$/.test(c.effectiveType || ''));
          var used = performance.getEntriesByType('resource')
            .map(function (e) { return e.name; })
            .filter(function (n) { return n.indexOf(location.origin + '/') === 0; });
          var post = function (sw) {
            if (sw) sw.postMessage({ type: 'warm', used: used, full: full });
          };
          // Primeiro registo: o worker ainda está em install e a mensagem
          // corre em paralelo. Deploy novo: o controller troca depois do
          // activate e voltamos a mandar a mesma lista ao SW novo.
          post(reg.active || reg.waiting || reg.installing);
          navigator.serviceWorker.addEventListener('controllerchange', function () {
            post(navigator.serviceWorker.controller);
          });
        }).catch(function () {});
      }, { once: true });
    })();
  </script>

```

- [ ] **Step 3: Tag no bloco Python de `scripts/cache_bust_web_entrypoints.sh`**

Depois de `content = content.replace(preload_old, f"'{canvaskit_base}/skwasm.wasm'")` e antes de `index.write_text(content)` inserir:

```python
# Registo do service worker: a tag no ?v= é o que faz o browser detetar um
# sw.js novo a cada deploy. Sem o marcador o index.html não é o do repo.
sw_tag_old = "var swTag = '__PLPCG_TAG__';"
if sw_tag_old not in content:
    raise SystemExit(f"index.html sem {sw_tag_old}")
content = content.replace(sw_tag_old, f"var swTag = '{tag}';")
```

- [ ] **Step 4: Placeholders no verify**

Substituir o conteúdo de `scripts/verify_web_headers_artifact.sh` por:

```bash
#!/usr/bin/env bash
# Verifica build/web/_headers e o service worker gerado — gate CI/local
# (Fase D + shell offline). Corre DEPOIS de cache_bust_web_entrypoints.sh.
set -euo pipefail

HEADERS_FILE="${1:-build/web/_headers}"
WEB_DIR="$(dirname "$HEADERS_FILE")"
SW_FILE="$WEB_DIR/sw.js"
INDEX_FILE="$WEB_DIR/index.html"

test -f "$HEADERS_FILE"
grep -qx '  Cross-Origin-Opener-Policy: same-origin' "$HEADERS_FILE"
grep -q 'Cross-Origin-Embedder-Policy: require-corp' "$HEADERS_FILE"
grep -q 'flutter_service_worker.js' "$HEADERS_FILE"
grep -A1 'flutter_service_worker.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'
# sw.js é registado por ?v=<tag>: se a CDN o cacheasse, um deploy novo ficaria
# preso no SW velho até o objeto expirar.
grep -qx '/sw.js' "$HEADERS_FILE"
grep -A1 -x '/sw.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'

# O SW só é válido depois de generate_sw_manifest.py substituir os
# placeholders; um __PLPCG_ restante é erro em runtime e o registo falha em
# silêncio — o app "funcionaria" mas nunca abriria offline.
test -f "$SW_FILE"
test -f "$INDEX_FILE"
if grep -q '__PLPCG_' "$SW_FILE" "$INDEX_FILE"; then
  echo "ERRO: placeholder __PLPCG_ por substituir em $SW_FILE / $INDEX_FILE — corra scripts/cache_bust_web_entrypoints.sh antes." >&2
  exit 1
fi

echo "OK: $HEADERS_FILE contém COOP/COEP e no-cache dos service workers; $SW_FILE sem placeholders."
```

- [ ] **Step 5: Ordem em `scripts/web_build.sh`**

Trocar as linhas 44–45 para que o cache-bust corra primeiro:

```bash
echo "==> Artefato em build/web/"
"$ROOT_DIR/scripts/cache_bust_web_entrypoints.sh"
"$ROOT_DIR/scripts/verify_web_headers_artifact.sh"
```

Run: `flutter test test/web/ 2>&1 | tail -3`
Expected: `All tests passed!` — inclui `web_headers_test.dart` (o teste `rejeita _headers sem /sw.js` da Task 2 continua a passar: o verify falha antes de chegar ao `sw.js`), `web_index_perf_test.dart` (o `index.html` mantém tudo o que ele exige), e os novos.

- [ ] **Step 6: Commit**

```bash
dart format test/web/web_index_sw_registration_test.dart test/web/sw_manifest_generation_test.dart
git add web/index.html scripts/cache_bust_web_entrypoints.sh scripts/verify_web_headers_artifact.sh scripts/web_build.sh test/web/web_index_sw_registration_test.dart test/web/sw_manifest_generation_test.dart
git commit -m "feat(web): index.html regista sw.js?v=<tag> após o primeiro frame e manda a lista used; verify exige placeholders substituídos"
```

---

### Task 6: `navigator.storage.persist()` no boot (S7)

**Files:**
- Create: `lib/core/platform/web_storage_persistence.dart`
- Create: `lib/core/platform/web_storage_persistence_web.dart`
- Create: `lib/core/platform/web_storage_persistence_native.dart`
- Create: `lib/core/platform/web_storage_persistence_provider.dart`
- Modify: `lib/bootstrap_app.dart` (import + `ref.watch` na l.23)
- Test: `test/unit/core/platform/web_storage_persistence_native_test.dart`, `test/web/web_storage_persistence_test.dart`, `test/widget/bootstrap_app_test.dart`

**Interfaces:**
- Produces: `Future<bool?> requestPersistentStorage()` (web: memoizado por sessão; nativo: `null`); `final persistentStorageProvider = FutureProvider<bool?>`.
- Consumes: `package:web` `window.navigator.storage.persisted()/persist()` (`JSPromise<JSBoolean>`).

- [ ] **Step 1: Testes que falham**

`test/unit/core/platform/web_storage_persistence_native_test.dart`:

```dart
import 'package:coldigui/core/platform/web_storage_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

/// No VM o conditional import resolve para o stub nativo: o SO não apaga o
/// storage do app por inatividade, logo não há nada a pedir.
void main() {
  test('nativo devolve null sem lançar', () async {
    expect(await requestPersistentStorage(), isNull);
  });
}
```

`test/web/web_storage_persistence_test.dart`:

```dart
@TestOn('browser')
library;

import 'package:coldigui/core/platform/web_storage_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

/// `navigator.storage.persist()` existe no Chrome do harness; conceder ou não
/// depende do perfil, mas o resultado nunca é `null` nem a chamada lança.
void main() {
  test('resolve com bool no Chrome', () async {
    expect(await requestPersistentStorage(), isNotNull);
  });

  test('uma chamada por sessão: o Future é reutilizado', () {
    expect(
      identical(requestPersistentStorage(), requestPersistentStorage()),
      isTrue,
    );
  });
}
```

Em `test/widget/bootstrap_app_test.dart`, acrescentar o import `import 'package:coldigui/core/platform/web_storage_persistence_provider.dart';` (ordem alfabética, depois de `isar_provider.dart`) e, no fim do `main`, o teste:

```dart
  testWidgets('pede storage persistente no boot (S7), fora do caminho crítico', (
    tester,
  ) async {
    var requested = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarOpenerProvider.overrideWithValue(() async => FakeIsar()),
          persistentStorageProvider.overrideWith((ref) async {
            requested = true;
            return true;
          }),
        ],
        child: const BootstrapApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(ColdiguiApp), findsOneWidget);
    expect(requested, isTrue, reason: 'BootstrapApp observa o provider no boot');
    await tester.pumpAndSettle();
  });
```

Run: `flutter test test/unit/core/platform/web_storage_persistence_native_test.dart test/widget/bootstrap_app_test.dart 2>&1 | tail -5`
Expected: FAIL a compilar — `web_storage_persistence.dart` / `..._provider.dart` não existem.

- [ ] **Step 2: Implementar**

`lib/core/platform/web_storage_persistence.dart`:

```dart
export 'web_storage_persistence_native.dart'
    if (dart.library.js_interop) 'web_storage_persistence_web.dart';
```

`lib/core/platform/web_storage_persistence_native.dart`:

```dart
/// Nativo: o SO não apaga o storage do app por inatividade — nada a pedir.
Future<bool?> requestPersistentStorage() async => null;
```

`lib/core/platform/web_storage_persistence_web.dart`:

```dart
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

Future<bool?>? _request;

/// Pede `navigator.storage.persist()` uma vez por sessão (best-effort, S7).
///
/// Sem persistência, o Safari pode apagar Cache API/OPFS de uma origem após
/// 7 dias sem uso (na aba normal; o PWA no ecrã inicial é isento) — e com
/// isso o shell precacheado pelo `sw.js`, o catálogo e os PDFs offline.
/// Devolve `true` se a origem já era/ficou persistente, `false` se o browser
/// recusou e `null` se a API não existe ou falhou. Nunca lança; o resultado
/// só vai para `debugPrint`.
Future<bool?> requestPersistentStorage() => _request ??= _requestOnce();

Future<bool?> _requestOnce() async {
  try {
    final storage = window.navigator.storage;
    if ((await storage.persisted().toDart).toDart) return true;
    final granted = (await storage.persist().toDart).toDart;
    debugPrint('[storage] persist() → $granted');
    return granted;
  } on Object catch (e) {
    debugPrint('[storage] persist() falhou: $e');
    return null;
  }
}
```

`lib/core/platform/web_storage_persistence_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_storage_persistence.dart';

/// Pedido de storage persistente disparado no boot por `BootstrapApp` via
/// `ref.watch` (mesmo padrão do `isarStatusProvider`): fora do caminho
/// crítico e sem ninguém esperar o resultado. Overridável nos testes.
final persistentStorageProvider = FutureProvider<bool?>(
  (_) => requestPersistentStorage(),
);
```

`lib/bootstrap_app.dart` — acrescentar o import `import 'core/platform/web_storage_persistence_provider.dart';` depois de `import 'core/database/isar_provider.dart';` e trocar o `build` por:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(isarStatusProvider);
    // Mesmo motivo: só para o pedido sair no boot (web); nativo é no-op.
    ref.watch(persistentStorageProvider);
    return const ColdiguiApp();
  }
```

Run: `flutter test test/unit/core/platform/web_storage_persistence_native_test.dart test/widget/bootstrap_app_test.dart 2>&1 | tail -3 && flutter test --platform chrome --dart-define-from-file=dart_defines/plpcjf.json test/web/web_storage_persistence_test.dart 2>&1 | tail -3`
Expected: `All tests passed!` nas duas invocações.

- [ ] **Step 3: Analyze e commit**

```bash
dart format lib/core/platform/web_storage_persistence.dart lib/core/platform/web_storage_persistence_web.dart lib/core/platform/web_storage_persistence_native.dart lib/core/platform/web_storage_persistence_provider.dart lib/bootstrap_app.dart test/unit/core/platform/web_storage_persistence_native_test.dart test/web/web_storage_persistence_test.dart test/widget/bootstrap_app_test.dart
flutter analyze 2>&1 | tail -3
git add lib/core/platform/web_storage_persistence.dart lib/core/platform/web_storage_persistence_web.dart lib/core/platform/web_storage_persistence_native.dart lib/core/platform/web_storage_persistence_provider.dart lib/bootstrap_app.dart test/unit/core/platform/web_storage_persistence_native_test.dart test/web/web_storage_persistence_test.dart test/widget/bootstrap_app_test.dart
git commit -m "feat(web): pede navigator.storage.persist() uma vez por sessão no boot"
```

---

### Task 7: Prova em Chrome — boot online, SW ativo, boot sem servidor (CI)

**Files:**
- Create: `scripts/verify_web_sw.py`
- Modify: `.github/workflows/web.yml` (entre `Build web (WASM)` e `Web boot performance gate`; passo novo no fim do job `web`)
- Modify: `scripts/validate_web_coop_coep.sh` (dentro de `check_url`)

**Interfaces:**
- Consumes: `measure_web_boot.py` (`SimpleWebSocket`, `find_chrome`, `http_json`, `wait_for_cdp`, `CdpError`, `BOOT_TIMEOUT_S`, `POLL_INTERVAL_S`), `web_frontend_server.serve_frontend`, `window.__plpcgPerf` do `index.html`.
- Produces: `python3 scripts/verify_web_sw.py [--web-dir build/web]` → exit 0 e quatro linhas `online: …`, `service worker ativo; …`, `engine aquecido: …`, `offline: … OK`; exit 1 com `Erro: …` caso contrário.

- [ ] **Step 1: `scripts/verify_web_sw.py`**

```python
#!/usr/bin/env python3
"""Prova que o shell abre sem rede (spec 2026-09-14-pwa-shell-offline, §5).

Sobe build/web no servidor local (mesmos headers do _headers), deixa o
index.html registar o sw.js, o install precachear CRITICAL e a mensagem
`used` aquecer o engine realmente carregado (main.dart.* + canvaskit/<hash>/),
derruba o servidor e navega outra vez: o flutter-first-frame tem de chegar só
com o cache do service worker — e com COOP/COEP preservados
(crossOriginIsolated).

Uso:
  python3 scripts/verify_web_sw.py [--web-dir build/web]

Requer build/web pós-processado (scripts/web_build.sh, ou
flutter build web --wasm + scripts/cache_bust_web_entrypoints.sh).
"""
from __future__ import annotations

import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

import argparse
import json
import os
import shutil
import subprocess
import time
from typing import Any

from measure_web_boot import (
    BOOT_TIMEOUT_S,
    POLL_INTERVAL_S,
    CdpError,
    SimpleWebSocket,
    find_chrome,
    http_json,
    wait_for_cdp,
)
from web_frontend_server import DEFAULT_WEB_DIR, serve_frontend

# O install baixa CRITICAL (~3 MB) e a mensagem `used` copia o engine (~10 MB)
# do servidor local; o runner do CI é lento e --disable-cache obriga tudo a
# vir pela rede (sem cache HTTP, o `used` também custa rede aqui).
SW_TIMEOUT_S = 120


def evaluate(ws: SimpleWebSocket, expression: str, timeout: float = 10) -> Any:
    result = ws.call(
        "Runtime.evaluate",
        {"expression": expression, "returnByValue": True, "awaitPromise": True},
        timeout=timeout,
    )
    if "exceptionDetails" in result:
        text = result["exceptionDetails"].get("text", "exceção JS")
        raise CdpError(f"{text} em: {expression}")
    return result.get("result", {}).get("value")


def wait_first_frame(ws: SimpleWebSocket) -> dict[str, Any]:
    """Espera o flutter-first-frame do documento atual.

    `__plpcgSwProbe` marca o documento anterior antes de cada navegação:
    Page.navigate volta antes do commit e o poll podia ler o __plpcgPerf velho.
    """
    expression = (
        "(window.__plpcgSwProbe === undefined && window.__plpcgPerf"
        " && window.__plpcgPerf.firstFrameMs != null) ? window.__plpcgPerf : null"
    )
    deadline = time.monotonic() + BOOT_TIMEOUT_S
    while time.monotonic() < deadline:
        try:
            perf = evaluate(ws, expression, timeout=5)
        except CdpError:
            perf = None  # contexto destruído a meio da navegação: tenta outra vez
        if isinstance(perf, dict):
            return perf
        time.sleep(POLL_INTERVAL_S)
    raise CdpError(f"timeout ({BOOT_TIMEOUT_S}s) à espera do flutter-first-frame")


def wait_service_worker(ws: SimpleWebSocket, cache_name: str) -> None:
    state_expr = (
        "navigator.serviceWorker.getRegistration().then(function (r) {"
        " if (!r) return 'sem registo';"
        " if (r.active) return r.active.state;"
        " return r.installing ? 'installing' : 'waiting'; })"
    )
    state: Any = None
    keys: Any = []
    deadline = time.monotonic() + SW_TIMEOUT_S
    while time.monotonic() < deadline:
        state = evaluate(ws, state_expr)
        keys = evaluate(ws, "caches.keys()") or []
        if state == "activated" and cache_name in keys:
            return
        time.sleep(POLL_INTERVAL_S)
    raise CdpError(
        f"timeout ({SW_TIMEOUT_S}s): service worker não ativou com o cache "
        f"{cache_name} (estado={state}, caches={keys})"
    )


def cached_urls(ws: SimpleWebSocket, cache_name: str) -> list[str]:
    return evaluate(
        ws,
        f"caches.open('{cache_name}').then(function (c) {{ return c.keys(); }})"
        ".then(function (ks) { return ks.map(function (r) { return r.url; }); })",
    ) or []


def wait_engine_warm(ws: SimpleWebSocket, cache_name: str) -> list[str]:
    """Espera a lista `used` da página entrar no cache.

    O engine (main.dart.* e canvaskit/<hash>/) não está em CRITICAL: chega
    pela mensagem {type:'warm', used} depois do primeiro frame. Sem ele o
    boot offline não tem como arrancar, por isso é condição para desligar o
    servidor. Risco aceite em produção: fechar a aba < ~2 s após o primeiro
    frame deixa o engine fora do cache; a próxima abertura online corrige.
    """
    urls: list[str] = []
    deadline = time.monotonic() + SW_TIMEOUT_S
    while time.monotonic() < deadline:
        urls = cached_urls(ws, cache_name)
        has_main = any("/main.dart.wasm?v=" in u or "/main.dart.js?v=" in u for u in urls)
        has_engine = any("/canvaskit/" in u and u.endswith(".wasm") for u in urls)
        if has_main and has_engine:
            return urls
        time.sleep(POLL_INTERVAL_S)
    engine = [u for u in urls if "/main.dart." in u or "/canvaskit/" in u]
    raise CdpError(
        f"timeout ({SW_TIMEOUT_S}s): a lista `used` não pôs o engine no cache "
        f"{cache_name} (entradas de engine: {engine})"
    )


def launch_chrome(chrome: str, cdp_port: int, user_data: Path) -> subprocess.Popen[bytes]:
    return subprocess.Popen(
        [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--remote-allow-origins=*",
            "--no-first-run",
            "--no-default-browser-check",
            # Sem cache HTTP: offline, cada byte tem de vir do Cache API do SW.
            "--disable-cache",
            "--disable-application-cache",
            f"--remote-debugging-port={cdp_port}",
            f"--user-data-dir={user_data}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def verify(web_dir: Path, chrome: str) -> None:
    sw = web_dir / "sw.js"
    if not sw.is_file() or "__PLPCG_" in sw.read_text():
        raise CdpError(f"{sw} ausente ou com placeholders — corra scripts/cache_bust_web_entrypoints.sh")
    tag = json.loads((web_dir / "version.json").read_text())["web_cache_tag"]
    cache_name = f"plpcg-shell-{tag}"

    cdp_port = 9800 + (os.getpid() % 500)
    user_data = Path("/tmp") / f"plpcg-sw-{os.getpid()}-{time.time_ns()}"
    user_data.mkdir(parents=True, exist_ok=True)
    proc = launch_chrome(chrome, cdp_port, user_data)
    ws: SimpleWebSocket | None = None
    try:
        wait_for_cdp(cdp_port)
        target = http_json(f"http://127.0.0.1:{cdp_port}/json/new", method="PUT")
        ws = SimpleWebSocket.connect(target["webSocketDebuggerUrl"])
        ws.call("Page.enable")
        ws.call("Runtime.enable")

        with serve_frontend(web_dir=web_dir) as (_httpd, port):
            app_url = f"http://127.0.0.1:{port}/"
            ws.call("Page.navigate", {"url": app_url})
            online = wait_first_frame(ws)
            print(
                f"online: first frame {online['firstFrameMs']} ms, "
                f"crossOriginIsolated={online.get('crossOriginIsolated')}"
            )
            wait_service_worker(ws, cache_name)
            cached = cached_urls(ws, cache_name)
            if app_url not in cached:
                raise CdpError(f"index.html ('./') não está no cache {cache_name}: {cached[:5]}…")
            print(f"service worker ativo; {cache_name} com {len(cached)} entradas")
            warmed = wait_engine_warm(ws, cache_name)
            engine = sorted(u.split("/", 3)[-1] for u in warmed if "/main.dart." in u or "/canvaskit/" in u)
            print(f"engine aquecido pela lista used: {engine}")
            evaluate(ws, "window.__plpcgSwProbe = 'stale'; true")

        # Servidor em baixo: a navegação só pode ser servida pelo SW.
        ws.call("Page.navigate", {"url": app_url})
        offline = wait_first_frame(ws)
        if offline.get("crossOriginIsolated") is not True:
            raise CdpError(
                "sem rede o documento perdeu COOP/COEP (crossOriginIsolated != true): "
                "o cache não preservou os headers do index.html"
            )
        print(f"offline: first frame {offline['firstFrameMs']} ms a partir do cache — OK")
    finally:
        if ws is not None:
            ws.close()
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        shutil.rmtree(user_data, ignore_errors=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prova o boot offline do shell PLPCG")
    parser.add_argument("--web-dir", type=Path, default=DEFAULT_WEB_DIR, help="Diretório build/web")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    web_dir = args.web_dir.resolve()
    if not web_dir.is_dir():
        print(f"Erro: {web_dir} não existe. Rode scripts/web_build.sh primeiro.", file=sys.stderr)
        return 1
    try:
        verify(web_dir, find_chrome())
    except CdpError as err:
        print(f"Erro: {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Negativo primeiro — build sem `sw.js` tem de falhar**

Build completo (o `build/web` atual já foi pós-processado por um build antigo; o cache-bust recusa-se a correr duas vezes):

Run: `./scripts/web_build.sh 2>&1 | tail -6`
Expected: termina com `OK: sw.js tag=<tag> CRITICAL=<n> (~3 MB) WARM=<n> (…) ENGINE fora das listas=<n>`, `OK: build/web/_headers contém COOP/COEP … sem placeholders.` e `Build OK — Commit: … | Cache tag: …`.

Depois:

```bash
rm -rf /tmp/plpcg-web-sem-sw && cp -R build/web /tmp/plpcg-web-sem-sw && rm /tmp/plpcg-web-sem-sw/sw.js
chmod +x scripts/verify_web_sw.py
python3 scripts/verify_web_sw.py --web-dir /tmp/plpcg-web-sem-sw; echo "exit=$?"
```

Expected: `Erro: /tmp/plpcg-web-sem-sw/sw.js ausente ou com placeholders …` e `exit=1`. Depois, para provar que o registo em si é vigiado: `cp web/sw.js /tmp/plpcg-web-sem-sw/sw.js` (template com placeholders, 404 evitado) — o script recusa de novo por placeholders (`exit=1`). Por fim (opcional, ~2 min), com um `sw.js` sintaticamente válido mas sem install (`echo "'use strict';" > /tmp/plpcg-web-sem-sw/sw.js`), o script deve falhar em `timeout (120s): service worker não ativou com o cache plpcg-shell-<tag> (estado=activated, caches=[…])` — o SW regista e ativa mas nunca cria o cache.

- [ ] **Step 3: Positivo**

Run: `python3 scripts/verify_web_sw.py; echo "exit=$?"`
Expected:

```
online: first frame <n> ms, crossOriginIsolated=True
service worker ativo; plpcg-shell-<tag> com <≥ 15> entradas
engine aquecido pela lista used: ['canvaskit/<hash>/skwasm.js', 'canvaskit/<hash>/skwasm.wasm', 'main.dart.mjs?v=<tag>', 'main.dart.wasm?v=<tag>']
offline: first frame <n> ms a partir do cache — OK
exit=0
```

(No Chrome headless a variante é `skwasm`; num Safari seria `skwasm_heavy` — é exatamente por isso que o engine não está numa lista fixa.) Se falhar em `wait_service_worker` com `estado=sem registo`, o `index.html` do build não tem a tag (ver Task 5) ou o Chrome não é o do `CHROME_EXECUTABLE`; se falhar em `wait_engine_warm`, o `postMessage` não chegou (ver `used`/`full` no `index.html`) ou o buffer de resource timing encheu antes do engine (`setResourceTimingBufferSize` tem de ser o primeiro script); se falhar no `offline` com timeout, abrir `http://127.0.0.1:<porta>` manualmente com `python3 scripts/web_local_dev.py`, DevTools → Application → Service Workers → Offline → reload, e ler o erro do SW na consola.

- [ ] **Step 4: CI**

Em `.github/workflows/web.yml`, substituir o bloco entre `Build web (WASM)` e o fim do job `web` por:

```yaml
      - name: Build web (WASM)
        run: |
          flutter build web \
            --wasm \
            --dart-define-from-file=dart_defines/plpcjf.json

      # Mesmo pós-build do deploy (scripts/web_build.sh): ?v=<tag>, canvaskit/<hash>/
      # e as listas CRITICAL/WARM do sw.js. O verify a seguir exige-o.
      - name: Cache-bust entrypoints + service worker manifest
        run: ./scripts/cache_bust_web_entrypoints.sh

      - name: Verify headers artifact and service worker
        run: ./scripts/verify_web_headers_artifact.sh

      - name: Web boot performance gate
        env:
          CHROME_EXECUTABLE: ${{ steps.setup-chrome.outputs.chrome-path }}
        run: ./scripts/measure_web_boot.sh --check

      # Boot online → sw.js ativo com plpcg-shell-<tag> → engine aquecido pela
      # lista `used` → servidor em baixo → boot outra vez só do cache
      # (spec 2026-09-14-pwa-shell-offline, §5).
      - name: Service worker offline boot
        env:
          CHROME_EXECUTABLE: ${{ steps.setup-chrome.outputs.chrome-path }}
        run: python3 scripts/verify_web_sw.py
```

- [ ] **Step 5: `sw.js` na validação de produção**

Em `scripts/validate_web_coop_coep.sh`, dentro de `check_url`, na linha `local coop coep sw_cache wasm_status` acrescentar `own_sw_cache own_sw_type`, e depois de `wasm_status="$(http_status "$base/isar_plus.wasm")"` inserir:

```bash
  own_sw_cache="$(header_value "$base/sw.js" "cache-control")"
  own_sw_type="$(header_value "$base/sw.js" "content-type")"
```

Antes do `echo` final de `check_url` (linha em branco `echo`), inserir:

```bash
  # sw.js próprio: tem de ser JS (não o index.html do fallback SPA) e no-cache;
  # o ?v=<tag> protege o registo, mas um objeto preso na zone atrasaria o WARM.
  if [[ "$own_sw_type" == *"javascript"* && "$own_sw_cache" == *"no-cache"* ]]; then
    echo "  OK  sw.js: $own_sw_type; Cache-Control: $own_sw_cache"
  else
    echo "  FAIL sw.js: esperado javascript + no-cache, obtido '${own_sw_type:-<ausente>}' / '${own_sw_cache:-<ausente>}'" >&2
    failures=$((failures + 1))
  fi
```

Run: `bash -n scripts/validate_web_coop_coep.sh && echo "sintaxe OK"`
Expected: `sintaxe OK` (contra a produção só depois do deploy — hoje `/sw.js` devolve o `index.html`, logo FAIL é o esperado antes do deploy).

- [ ] **Step 6: Commit**

```bash
git add scripts/verify_web_sw.py .github/workflows/web.yml scripts/validate_web_coop_coep.sh
git commit -m "ci(web): prova de boot offline do shell via CDP; cache-bust e verify do sw.js no workflow"
```

---

### Task 8: Verificação final, docs e checklist

**Files:**
- Modify: `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md` (A9, após a l.102)
- Modify: `docs/WEB_PERFORMANCE_AND_LOADING.md` (Fase C «Estado atual», l.205–209; tabela de histórico, após a l.502)

- [ ] **Step 1: Suites**

Run: `flutter analyze 2>&1 | tail -3 && dart format --set-exit-if-changed lib test 2>&1 | tail -2`
Expected: `No issues found!` e formatação limpa.

Run: `flutter test 2>&1 | tail -4`
Expected: só as falhas de baseline (`pdfrx_viewer_adapter_test`, `reconcile_offline_index_benchmark_test`). Qualquer outra é desta feature — corrigir.

Run: `flutter test --platform chrome --dart-define-from-file=dart_defines/plpcjf.json test/web/ 2>&1 | tail -3`
Expected: `All tests passed!` (inclui `web_storage_persistence_test.dart` e o smoke existente).

Run: `./scripts/web_build.sh 2>&1 | tail -4 && python3 scripts/verify_web_sw.py`
Expected: build OK, `sw.js` sem placeholders, `offline: … OK`.

- [ ] **Step 2: Docs — A9**

Em `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md`, depois da linha `- **Esforço:** M–L · **Conf.:** média (decisão anterior foi deliberada; validar na CDN)` do A9, acrescentar:

```markdown
- ✅ **Implementado (2026-09-14)** — spec `docs/superpowers/specs/2026-09-14-pwa-shell-offline-design.md`, plano `docs/superpowers/plans/2026-09-14-pwa-shell-offline.md`: `web/sw.js` próprio (precache `CRITICAL` no `install`, `WARM` por mensagem após o primeiro frame, navegação network-first com fallback ao `index.html`, cache-first para o resto do shell; um cache `plpcg-shell-<tag>` por deploy), listas geradas por `scripts/generate_sw_manifest.py` no pós-build; `web/flutter_bootstrap.js` sem `serviceWorkerSettings` (o stub fazia `unregister` + reload); registo em `index.html` depois do `flutter-first-frame`; `navigator.storage.persist()` no boot; `manifest.json` com `id`/`scope`; gate CI `scripts/verify_web_sw.py` (boot com o servidor em baixo). Os entrypoints continuam `no-cache` — o `?v=` já resolve e a variante `stale-while-revalidate` foi descartada (spec S10). O engine (`main.dart.*`, `canvaskit/<hash>/**`) não está em lista nenhuma: o `flutter_bootstrap` escolhe a variante por browser, e o `index.html` manda ao SW a lista `used` (resource timing) do que carregou — só essa variante entra no cache, vinda do cache HTTP (install ≈ 3 MB; `used` ≈ 8–10 MB sem rede). Checklist iPhone/iPad/Android (spec §5): _a registar pelo dono após o deploy_.
```

- [ ] **Step 3: Docs — Fase C**

Em `docs/WEB_PERFORMANCE_AND_LOADING.md`, substituir os três bullets de «Estado atual» da Fase C (l.207–209) por:

```markdown
- `web/_headers` define COOP/COEP global; entrypoints (`index.html`, `main.dart.*`, `flutter_bootstrap.js`, `version.json`, `manifest.json`, `sw.js`, `flutter_service_worker.js`) são `no-cache` e levam `?v=<web_cache_tag>`; `/canvaskit/<hash>/*` e `/assets/*` são `immutable`.
- **Service worker próprio (`web/sw.js`, set/2026 — A9):** precache do shell (`CRITICAL`, ≈ 3 MB) no `install`; o engine realmente carregado (`main.dart.*` + variante de `canvaskit/<hash>/`) entra pela lista `used` que o `index.html` envia após o primeiro frame (resource timing, vem do cache HTTP); `WARM` em background; navegação network-first com fallback ao `index.html` em cache; um cache `plpcg-shell-<tag>` por deploy. O PWA instalado abre sem rede. Listas geradas por `scripts/generate_sw_manifest.py`; prova em CI por `scripts/verify_web_sw.py`.
- `scripts/web_local_dev.py` / `web_frontend_server.py` espelham as mesmas regras de cache para validação local.
```

Na tabela de histórico, depois da linha `| set/2026 | **Tarefa 5 (Top 12 web, A2):** …` acrescentar:

```markdown
| set/2026 | **Shell offline (A9):** `web/sw.js` próprio + `scripts/generate_sw_manifest.py` (`CRITICAL` ≈ 3 MB: bootstrap + isar + manifests + fontes + ícones; ENGINE `main.dart.*`/`canvaskit/<hash>/**` fora das listas, aquecido pela lista `used` da página; `WARM` = resto); registo após `flutter-first-frame`; `flutter_bootstrap.js` sem `serviceWorkerSettings`; `navigator.storage.persist()` no boot; `manifest.json` `id`/`scope`; CI corre o cache-bust, `verify_web_headers_artifact.sh` exige `sw.js` sem placeholders e `verify_web_sw.py` prova engine aquecido + boot com o servidor em baixo. Spec `2026-09-14-pwa-shell-offline-design.md` |
```

- [ ] **Step 4: Commit**

```bash
git add docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md docs/WEB_PERFORMANCE_AND_LOADING.md
git commit -m "docs(web): A9 implementado — shell offline com service worker próprio; Fase C atualizada"
```

- [ ] **Step 5: Relatar**

Listar no relatório final: commits, resultado das suites (VM, Chrome, `verify_web_sw.py`), e o que fica com o dono: deploy (`scripts/web_deploy.sh`), `scripts/validate_web_coop_coep.sh https://v2.plpcg.com` e a checklist abaixo, cujo resultado se regista no A9.

---

## Checklist manual pós-deploy (spec §5 e §7 — dono do deploy)

Depois de `scripts/web_build.sh` + `scripts/web_deploy.sh`:

1. `./scripts/validate_web_coop_coep.sh https://v2.plpcg.com` → todos `OK`, incluindo `sw.js: …javascript; Cache-Control: no-cache`. Se a zone `plpcg.com` devolver `max-age=14400` no `sw.js` (como faz hoje com `flutter_service_worker.js`), o `?v=<tag>` continua a garantir o registo novo por deploy — anotar no A9 e purgar (`scripts/purge_v2_cache.sh`).
2. `curl -s https://v2.plpcg.com/sw.js | grep -c __PLPCG_` → `0`; `curl -s https://v2.plpcg.com/ | grep -o "var swTag = '[0-9a-f]*'"` → tag de 12 hex igual a `build/web/version.json`.
3. **Chrome desktop:** abrir `https://v2.plpcg.com` → DevTools → Application → Service Workers: `sw.js?v=<tag>` *activated and is running*; Cache Storage tem `plpcg-shell-<tag>` com `main.dart.wasm?v=<tag>` e `canvaskit/<hash>/skwasm.wasm` (a lista `used` chegou) e **sem** as outras variantes (`skwasm_heavy`, `canvaskit.wasm`); **mantém** `plpcg-pdfs-store-v1`; Storage mostra *Persistent* (ou a consola tem `[storage] persist() → …`). Marcar *Offline* → reload → a Home aparece (loader dourado → app).
4. **iPhone e iPad (Safari):** abrir `https://v2.plpcg.com` online, esperar a Home **e ficar ≥ 5 s** (a lista `used` só é enviada depois do primeiro frame); Partilhar → «Adicionar ao ecrã principal»; abrir do ícone uma vez online (para o SW instalar nesse contexto) e esperar de novo ≥ 5 s; modo de avião → abrir do ícone → Home aparece com catálogo local; abrir um PDF já baixado → abre. Repetir na aba normal do Safari. (No Safari a variante aquecida é `skwasm_heavy` — confirmar em Develop → Storage se houver Mac.)
5. **Android Chrome:** idem ao ponto 4 (instalar via «Adicionar ao ecrã inicial»); Chrome → chrome://serviceworker-internals mostra o scope `https://v2.plpcg.com/` ativo.
6. **Deploy seguinte (online):** abrir o app → DevTools mostra `sw.js?v=<tag nova>` a instalar e depois só um cache `plpcg-shell-<tag nova>`; nenhum reload forçado; sem erros na consola.
7. Registar o resultado (dispositivos, iOS/Android versão, OK/FAIL) na linha «Implementado» do A9 em `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md` e, se algo falhar em Safari com COEP `require-corp` (spec §6), abrir item novo com a evidência da consola.
