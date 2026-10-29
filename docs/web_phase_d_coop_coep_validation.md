# Relatório de validação — Fase D (COOP/COEP)

**Data:** 05/07/2026 (America/Sao_Paulo)  
**Branch:** `web/integration`  
**Domínios alvo:** `https://v2.plpcg.com` + previews Cloudflare Pages (`*.plpcg-v2.pages.dev`)  
**Referência:** [WEB_PERFORMANCE_AND_LOADING.md](WEB_PERFORMANCE_AND_LOADING.md) §Fase D

## Objetivo

Confirmar que o hosting entrega `Cross-Origin-Opener-Policy: same-origin` e `Cross-Origin-Embedder-Policy: require-corp`, habilitando **cross-origin isolation** (`SharedArrayBuffer`, WASM multi-thread do pdfrx, OPFS performático do Isar).

---

## Artefatos e scripts adicionados

| Arquivo | Função |
|---|---|
| [`scripts/validate_web_coop_coep.sh`](../scripts/validate_web_coop_coep.sh) | Valida COOP/COEP, `no-cache` do SW e `isar_plus.wasm` via `curl` |
| [`scripts/verify_web_headers_artifact.sh`](../scripts/verify_web_headers_artifact.sh) | Gate estático pós-build (`build/web/_headers`) |
| [`.github/workflows/web.yml`](../.github/workflows/web.yml) | Step **Verify COOP/COEP headers artifact** após `flutter build web` |

### Uso

```bash
# Após build
./scripts/verify_web_headers_artifact.sh

# Produção ou preview Pages
./scripts/validate_web_coop_coep.sh https://v2.plpcg.com
./scripts/validate_web_coop_coep.sh https://<hash>.plpcg-v2.pages.dev
```

---

## Resultados — artefato de build (local)

| Verificação | Resultado |
|---|---|
| `build/web/_headers` existe | **PASS** |
| COOP `same-origin` | **PASS** |
| COEP `require-corp` | **PASS** |
| SW `Cache-Control: no-cache` | **PASS** |
| CI gate (`verify_web_headers_artifact.sh`) | **PASS** (script pronto; step no workflow) |

---

## Resultados — validação HTTP

### Servidor local com COOP/COEP (`web_local_dev.py` :8080)

```bash
./scripts/validate_web_coop_coep.sh http://127.0.0.1:8080
```

| Verificação | Resultado |
|---|---|
| COOP | **PASS** — `same-origin` |
| COEP | **PASS** — `require-corp` |
| `flutter_service_worker.js` | **PASS** — `no-cache` |
| `isar_plus.wasm` | **PASS** — HTTP 200 |

### Controle negativo (`python3 -m http.server` :8090, sem headers)

| Verificação | Resultado esperado | Resultado |
|---|---|---|
| COOP | ausente | **PASS** (ausente) |
| COEP | ausente | **PASS** (ausente) |
| Script exit code | ≠ 0 | **PASS** (falhou como esperado) |

### Produção `https://v2.plpcg.com`

| Verificação | Resultado nesta sessão |
|---|---|
| `curl -I` / browser | **PENDENTE** — host retornou 503 / erro de rede no ambiente de validação |
| Re-validar pós-deploy | `./scripts/validate_web_coop_coep.sh https://v2.plpcg.com` |

### Preview Cloudflare Pages

Validar após cada deploy de PR:

```bash
./scripts/validate_web_coop_coep.sh https://<hash>.plpcg-v2.pages.dev
```

---

## Resultados — browser (Chrome, build/web local)

Medição com Performance API — cold load, cache quente do browser local.

### Cross-origin isolation

| Servidor | `crossOriginIsolated` | `typeof SharedArrayBuffer` |
|---|---|---|
| `:8080` (`web_local_dev.py`, COOP/COEP) | **`true`** | **`function`** |
| `:8090` (`http.server`, sem headers) | **`false`** | **`undefined`** |

Sem warnings de *SharedArrayBuffer will require cross-origin isolation* no console com COOP/COEP ativos.

### OPFS / storage

| Servidor | `navigator.storage.getDirectory()` | `storage.estimate()` (8080) |
|---|---|---|
| `:8080` (COOP/COEP) | **available** | quota ~36 GB, usage ~90 KB (IndexedDB parcial pós-boot) |
| `:8090` (sem COOP/COEP) | available (API existe, mas **sem** `SharedArrayBuffer`) | — |

> **Nota:** OPFS API pode existir sem isolation; o ganho de performance do Isar/pdfrx depende de `SharedArrayBuffer` (multi-thread WASM), disponível apenas com COOP/COEP.

### Baseline — primeiro frame Flutter (`flt-glass-pane` + loader oculto)

| Cenário | Tempo até 1º frame | Isolation |
|---|---|---|
| **Com COOP/COEP** (`:8080`) | **~2609 ms** | `true` |
| **Sem COOP/COEP** (`:8090`) | **~3198 ms** | `false` |
| **Delta** | **~589 ms mais rápido com headers** | — |

Snippet reproduzível no DevTools Console (após hard reload):

```javascript
(async () => {
  const nav = performance.getEntriesByType('navigation')[0];
  const t0 = nav ? nav.startTime : performance.now();
  while (performance.now() - t0 < 45000) {
    const pane = document.querySelector('flt-glass-pane');
    const loader = document.getElementById('loading');
    if (pane && (!loader || loader.classList.contains('hidden'))) {
      console.log({
        firstFrameMs: Math.round(performance.now() - t0),
        crossOriginIsolated,
        sab: typeof SharedArrayBuffer,
      });
      return;
    }
    await new Promise(r => setTimeout(r, 50));
  }
})();
```

### pdfrx multi-thread

Validação manual recomendada em produção/preview (com COOP/COEP):

1. Abrir um PDF remoto no leitor.
2. Console: sem erros WASM / SharedArrayBuffer.
3. Confirmar `crossOriginIsolated === true` antes de abrir o PDF.

---

## Checklist Fase D (resumo)

| Item | Status |
|---|---|
| `curl -I` → COOP/COEP presentes | **PASS** local; **PENDENTE** v2.plpcg.com (re-validar pós-deploy) |
| Console sem warning SharedArrayBuffer | **PASS** com COOP/COEP (`:8080`) |
| Isar/OPFS com isolation ativa | **PASS** (`crossOriginIsolated` + OPFS API + IndexedDB usage) |
| Baseline com vs sem headers | **PASS** — ~589 ms mais rápido até 1º frame com COOP/COEP |

---

## Pendências / fora de escopo

- **`plpcjf.org`:** não validado neste PR (domínio alvo acordado: v2.plpcg.com + previews Pages).
- **CORS `plpcjf.org` no worker:** pendência D7 — [`workers/plpcg-catalog/src/index.ts`](../workers/plpcg-catalog/src/index.ts) lista apenas `v2.plpcg.com` e `*.plpcg-v2.pages.dev`.
- **Produção v2.plpcg.com:** executar `./scripts/validate_web_coop_coep.sh` após confirmar deploy ativo.

---

## Remediação se produção falhar

| Sintoma | Ação |
|---|---|
| Headers ausentes em v2.plpcg.com | Confirmar deploy Pages inclui `build/web/_headers` na raiz; re-deploy via `./scripts/web_build.sh` |
| WASM 404 | Rodar `./scripts/fetch_isar_web_assets.sh` antes do build |
| `crossOriginIsolated: false` com headers OK | Procurar recurso third-party sem CORP (hoje não há CDNs em `web/index.html`) |
| Preview Pages sem headers | Mesmo artefato — verificar pipeline de deploy |
