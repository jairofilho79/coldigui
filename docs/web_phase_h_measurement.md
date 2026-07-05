# Medição de performance web — Fase H

**Referência:** [WEB_PERFORMANCE_AND_LOADING.md](WEB_PERFORMANCE_AND_LOADING.md) §Fase H  
**Baseline versionado:** [web_perf_baseline.json](web_perf_baseline.json)

## Objetivo

Estabelecer medição reproduzível do cold start web e gate de regressão no CI.

## Métricas

| Métrica | Origem | Automatizada |
|---|---|---|
| Time to loader visible | `window.__plpcgPerf.loaderVisibleMs` | Sim (`measure_web_boot.py`) |
| Time to first Flutter frame | `window.__plpcgPerf.firstFrameMs` | Sim |
| Time to interactive home | Manifest `data` + lista renderizada | Manual (DevTools) |
| Total transfer size | DevTools Network (Disable cache) | Manual |
| Lighthouse Performance | Pré-release manual ou CI opcional | Manual |

## Pré-requisitos

```bash
flutter build web --wasm --release \
  --dart-define-from-file=dart_defines/plpcjf.json
```

Chrome ou Chromium instalado. No CI, `CHROME_EXECUTABLE` é definido pelo workflow.

## Medição automatizada

```bash
# Mede e imprime JSON (mediana de 2 execuções)
./scripts/measure_web_boot.sh

# Mede e valida contra baseline (falha se regressão)
./scripts/measure_web_boot.sh --check

# Gravar artefato
./scripts/measure_web_boot.sh --output /tmp/web-metrics.json
```

O script:

1. Sobe `build/web` com COOP/COEP (`scripts/web_frontend_server.py`)
2. Abre Chrome headless com cache desabilitado
3. Navega para a app e faz poll de `window.__plpcgPerf` via CDP
4. Com `--check`, compara `loaderVisibleMs` e `firstFrameMs` com [web_perf_baseline.json](web_perf_baseline.json)

Gate: `medido <= baseline.value + maxRegression`.

## Medição manual (DevTools)

1. Servir com headers corretos:
   ```bash
   python3 scripts/web_local_dev.py
   ```
   ou após build: `python3 scripts/measure_web_boot.py` (sobe servidor efêmero internamente).

2. Chrome → DevTools → Network → **Disable cache** → hard reload (Ctrl+Shift+R).

3. Console — após reload, aguardar app carregar:
   ```javascript
   window.__plpcgPerf
   ```

4. **Fast 3G** (opcional): DevTools → Network → throttling **Fast 3G** → repetir hard reload e anotar `firstFrameMs`.

### Snippet legado (Fase D)

Útil se `__plpcgPerf` não estiver disponível (build antigo):

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
    await new Promise((r) => setTimeout(r, 50));
  }
})();
```

## Atualizar baseline

Após otimização intencional que melhora o cold start:

1. Rodar `./scripts/measure_web_boot.sh` localmente (várias vezes).
2. Atualizar `value` em [web_perf_baseline.json](web_perf_baseline.json) com a mediana observada no ambiente de referência (CI ubuntu-latest).
3. Manter `maxRegression` com margem absoluta (ex.: 1500 ms para `firstFrameMs`).
4. Documentar data e motivo no PR.

Se o gate CI falhar na primeira calibração, ajustar `firstFrameMs.value` para a mediana medida no CI + manter margem.

## CI

Step **Web boot performance gate** em [`.github/workflows/web.yml`](../.github/workflows/web.yml):

```bash
./scripts/measure_web_boot.sh --check
```

Executa após `flutter build web`, com mediana de 2 runs e threshold do baseline.

## Testes estáticos

`test/web/web_index_perf_test.dart` valida que `web/index.html` contém splash, instrumentação e preloads — sem medir timing no harness Flutter.
