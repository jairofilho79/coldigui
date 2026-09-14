# PWA — shell offline (service worker próprio) e storage persistente

**Data:** 2026-09-14
**Estado:** aprovado em brainstorm (abordagem A1); spec para revisão
**Escopo:** fazer o PWA instalado (iPhone/iPad/Android/desktop) **abrir sem rede**: service worker próprio com precache do shell e fallback de navegação, `navigator.storage.persist()`, ajustes de `manifest.json`, `_headers` e scripts de build/validação. **Não** toca em como materiais e catálogo são guardados (isso continua no Dart — ver `2026-09-14-offline-coldigom-design.md`).
**Repos:** só `coldigui` (`web/`, `scripts/`, `test/web/`, um ponto de boot em `lib/`).

## 1. Problema

O `flutter_service_worker.js` gerado pelo Flutter 3.47 é um stub que se desregista (`activate → registration.unregister()`). Não há precache de `index.html`, `main.dart.wasm`, `canvaskit/<hash>/`, fontes nem ícones. Sem rede, o ícone no ecrã inicial abre uma página em branco — mesmo com catálogo e PDFs no aparelho. Registado como A9 em `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md`.

Além disso, nada pede `navigator.storage.persist()`: no Safari, uma origem sem persistência pode ter Cache API/OPFS apagados após 7 dias sem uso (PWA no ecrã inicial é isento, mas a aba normal não).

## 2. Decisões

| # | Decisão |
|---|---|
| S1 | **SW escrito à mão** em `web/sw.js` (~150 linhas, sem dependência). O Flutter copia `web/*` para `build/web/`; o `cache_bust_web_entrypoints.sh` pós-processa o ficheiro copiado. |
| S2 | O SW cobre **só o shell same-origin** (`v2.plpcg.com`). Requests para outras origens (`plpcg.com/api`, `coldigom-api…`, R2) **não** passam por `respondWith` — o app Dart continua dono do catálogo e dos materiais. |
| S3 | **Duas listas**: `critical` (precache no `install`) e `warm` (aquecida em background depois do `flutter-first-frame`). Faltar algo da `warm` nunca impede o boot. |
| S4 | Estratégias: navegação (`request.mode === 'navigate'`) → **network-first** com fallback ao `index.html` em cache; ficheiros com hash/`?v=` e `canvaskit/<hash>/`, `assets/`, `fonts/` → **cache-first** com preenchimento no primeiro fetch (runtime cache); `version.json`, `manifest.json` → network-first com fallback. |
| S5 | Um cache por versão: `plpcg-shell-<web_cache_tag>`. `activate` apaga caches `plpcg-shell-*` de outras tags e faz `clients.claim()`; `install` faz `skipWaiting()`. Página velha que pede um chunk ausente no cache novo cai na rede (S4) — sem quebra. |
| S6 | Registo em `index.html`, depois do `flutter-first-frame` (nunca antes: o boot é o caminho crítico), com `navigator.serviceWorker.register('sw.js?v=<tag>')`. A query só serve para o registo detetar versão nova; o ficheiro é `no-cache` no `_headers`. |
| S7 | `navigator.storage.persist()` pedido pelo Dart no boot web (best-effort, uma vez por sessão, resultado só em `debugPrint`). |
| S8 | `manifest.json` ganha `id: "/"` e `scope: "/"` (identidade estável do PWA); resto inalterado. |
| S9 | Save-Data (`navigator.connection.saveData`) ou ligação lenta (`effectiveType` 2g/slow-2g): a `warm` não corre. |
| S10 | Sem `stale-while-revalidate` no `index.html`: network-first garante que uma visita online vê sempre o deploy novo; o cache só entra sem rede. |

## 3. Ficheiros e comportamento

### 3.1 `web/sw.js` (template)

Placeholders substituídos pelo build:

```js
const TAG = '__PLPCG_TAG__';
const CRITICAL = __PLPCG_CRITICAL__;   // JSON array de URLs relativas
const WARM = __PLPCG_WARM__;           // JSON array de URLs relativas
const CACHE = `plpcg-shell-${TAG}`;
```

- `install`: `cache.addAll(CRITICAL)` (falha em qualquer item = install falha e o SW antigo continua — comportamento desejado) → `skipWaiting()`.
- `activate`: apaga `plpcg-shell-*` ≠ `CACHE` → `clients.claim()`.
- `message {type:'warm'}`: para cada URL da `WARM` ainda ausente, `fetch` + `put` sequencial (ou 2 em paralelo), ignorando falhas individuais.
- `fetch`: só `GET` same-origin; regras da S4. Respostas `opaque`/não-`ok` nunca entram no cache. Navegação sem rede e sem `index.html` em cache → deixa o browser mostrar o erro nativo.

`CRITICAL` (gerada; ordem por importância):
`./` (index.html), `flutter_bootstrap.js?v=`, `flutter.js`, `main.dart.wasm?v=`, `main.dart.mjs?v=`, `main.dart.js?v=` (fallback para browsers sem WasmGC — iOS ≤ 17), `canvaskit/<hash>/skwasm.wasm|.js`, `canvaskit/<hash>/canvaskit.wasm|.js` (o par que o `flutter_bootstrap` pode escolher), `isar_plus.js`, `isar_plus.wasm`, `manifest.json`, `version.json`, `assets/FontManifest.json`, `assets/AssetManifest.bin.json`, `assets/fonts/MaterialIcons-Regular.<hash>.otf`, fontes em `assets/fonts/`, `assets/packages/**` (ícones/fontes de pacotes), `icons/*.png`, `favicon.png`.

`WARM`: tudo o resto que o build produz e é carregável em runtime: `*.part.js` / partes deferidas do wasm, `assets/**` restantes (imagens, `.svg`), `canvaskit/<hash>/*` remanescente. Excluídos: `flutter_service_worker.js` (stub do Flutter), `sw.js`, `.last_build_id`, `_headers`, `_redirects`.

Estimativa: `CRITICAL` ≈ 12–15 MB (wasm 4,4 MB + skwasm 3,6 MB + canvaskit + js fallback + isar 1,4 MB + fontes). Aceitável: só entra uma vez por deploy.

### 3.2 `scripts/cache_bust_web_entrypoints.sh`

Passo novo no bloco Python, depois de renomear `canvaskit/` e de gravar `version.json`: percorre `build/web`, classifica os ficheiros em `CRITICAL`/`WARM` pelas regras acima (aplicando o `?v=<tag>` aos entrypoints já reescritos), substitui os placeholders em `build/web/sw.js` e **falha** se um item de `CRITICAL` não existir no disco. Imprime as contagens e o tamanho total de cada lista.

`scripts/verify_web_headers_artifact.sh`: passa a exigir `sw.js` com `Cache-Control: no-cache` e a presença dos três placeholders substituídos (nenhum `__PLPCG_` restante).

### 3.3 `web/index.html`

Após o handler existente de `flutter-first-frame` (l.275):

```js
window.addEventListener('flutter-first-frame', function () {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.register('sw.js?v=__PLPCG_TAG__').then(function (reg) {
    var c = navigator.connection || {};
    if (c.saveData || /(^|-)2g$/.test(c.effectiveType || '')) return;
    var post = function (sw) { sw && sw.postMessage({ type: 'warm' }); };
    post(reg.active || reg.waiting || reg.installing);
    navigator.serviceWorker.addEventListener('controllerchange', function () {
      post(navigator.serviceWorker.controller);
    });
  }).catch(function () {});
}, { once: true });
```

O `__PLPCG_TAG__` do `index.html` é substituído pelo mesmo script que já reescreve `?v=` no `index.html`. `sw.js` atende `message` mesmo quando `installing` (a mensagem fica em fila até o `install` acabar); se o SW ainda não existia, a `warm` corre logo após o primeiro `activate`.

### 3.4 `web/_headers`

- `/sw.js` → `Cache-Control: no-cache` (junto ao `flutter_service_worker.js`).
- Nada muda nas regras `immutable` de `/canvaskit/*` e `/assets/*` nem em COOP/COEP.
- `scripts/web_local_dev.py` / `web_frontend_server.py` espelham a regra nova.

### 3.5 `manifest.json`

Adicionar `"id": "/"` e `"scope": "/"`. `start_url` continua `"."`.

### 3.6 Dart — `lib/core/platform/web_storage_persistence_web.dart` (+ stub)

```dart
Future<void> requestPersistentStorage() async {
  try {
    final storage = window.navigator.storage;
    if (await storage.persisted().toDart) return;
    final granted = await storage.persist().toDart;
    debugPrint('[storage] persist() → $granted');
  } on Object catch (e) { debugPrint('[storage] persist() falhou: $e'); }
}
```

Chamado uma vez em `bootstrap_app.dart` (web) sem `await` no caminho crítico. Stub nativo é no-op.

## 4. Fluxos

**Primeira visita online.** Boot como hoje (o SW não existe, nada muda no caminho crítico). Após o primeiro frame: registo → `install` baixa `CRITICAL` (em paralelo ao uso; os ficheiros já estão no cache HTTP do browser, logo é rápido) → `activate` → `warm` em background.

**Reabrir sem rede (PWA instalado ou aba).** Navegação → rede falha → `index.html` do cache → `flutter_bootstrap.js?v=` etc. do cache (cache-first) → app arranca; o Dart lê catálogo/materiais do Isar/Cache API. Se um chunk deferido nunca foi carregado nem aquecido, aquele ecrã mostra o erro de carregamento já existente (`DeferredRouteLoader`).

**Deploy novo, utilizador online.** Navegação network-first traz o `index.html` novo (`no-cache`), que referencia `sw.js?v=<tag novo>` → `install` do cache novo → `activate` apaga o velho. Nenhum reload forçado.

**Deploy novo, utilizador que abre offline antes de ter atualizado.** Continua na versão em cache — correto.

## 5. Testes

- `test/web/sw_manifest_generation_test.dart` — corre o passo Python contra um `build/web` fixture (como `cache_bust_web_entrypoints_test.dart`): `CRITICAL` contém index, bootstrap, wasm/mjs/js com `?v=`, canvaskit hashed, isar, FontManifest, ícones; `WARM` não contém `sw.js`, `flutter_service_worker.js`; placeholders substituídos; ficheiro crítico ausente → exit ≠ 0.
- `test/web/web_headers_test.dart` (existente) — `sw.js` `no-cache`.
- `test/web/chrome_smoke_test.dart` (existente) — ganha uma asserção: após first-frame, `navigator.serviceWorker.getRegistration()` resolve com `active` e `caches.keys()` contém `plpcg-shell-<tag>` (apenas quando servido pelo servidor local que espelha `_headers`).
- **Manual (checklist pós-deploy, §7):** Chrome DevTools → Application → Service Workers + Offline → reload abre o app; iPhone e iPad (Safari, «Adicionar ao ecrã principal») → abrir online uma vez → modo de avião → abrir do ícone → Home aparece; Android Chrome idem; DevTools → Application → Storage mostra `Persistent`.

## 6. Riscos

| Risco | Mitigação |
|---|---|
| Ficheiro novo com nome fixo fora das listas | O gerador percorre o `build/web` inteiro; `verify_web_headers_artifact.sh` falha se `CRITICAL` referencia ficheiro inexistente. |
| Safari com bugs de SW + COEP `require-corp` | Respostas do cache preservam os headers originais (same-origin, `CORP` não é exigido). Validar na checklist. |
| `install` grande em rede móvel | Corre depois do first-frame, em paralelo, e os ficheiros vêm do cache HTTP (`immutable`) quando já carregados. `WARM` não corre com Save-Data. |
| Utilizador preso numa versão antiga | Network-first no `index.html` e no `sw.js` (`no-cache`); a próxima visita online atualiza. |
| Quota do Safari (Cache API conta para a origem) | ~15 MB de shell + `persist()`; o estimador de quota já existente considera o total da origem. |

## 7. Entrega

- Branch `feat/pwa-shell-offline`, worktree `.claude/worktrees/pwa-shell-offline`, a partir de `web/integration`. Independente da spec Coldigom.
- Deploy: `scripts/web_build.sh` + `scripts/web_deploy.sh` (dono). Depois do deploy, executar a checklist do §5 em iPhone/iPad reais e registar o resultado em `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md` (A9 → implementado).

## 8. Fora do escopo

- Cachear materiais/catálogo pelo SW (é do Dart).
- Background Sync / Periodic Sync / push.
- Página offline "bonita" quando nem o `index.html` está em cache (primeira visita offline não tem solução).
- Revalidar `immutable` nos entrypoints (`?v=` já resolve).
