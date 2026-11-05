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
./scripts/measure_web_boot.sh --output build/web-metrics.json
```

O script:

1. Sobe `build/web` com COOP/COEP (`scripts/web_frontend_server.py`)
2. Abre Chrome headless com cache desabilitado
3. Instala um `PerformanceObserver` de long tasks via CDP **antes** da navegação,
   navega para a app e faz poll de `window.__plpcgPerf`
4. Com `--check`, compara `loaderVisibleMs` e `firstFrameMs` com [web_perf_baseline.json](web_perf_baseline.json)

Gate: `medido <= baseline.value + maxRegression`.

### Diagnósticos por amostra

Cada item de `samples` acrescenta `diagnostics`, sem alterar as métricas originais
de `window.__plpcgPerf` nem a mediana/limites do gate:

- `navigation`: `responseEnd`, `domInteractive` e `domContentLoadedEventEnd` reais
  de Navigation Timing (milissegundos desde o início da navegação).
- `fcpMs`: timestamp de `first-contentful-paint` em Paint Timing.
- `loaderMinusFcpMs`: `loaderVisibleMs - (fcpMs - navigation.startTime)`;
  negativo significa que a marca do loader precede FCP. A métrica atual usa
  double `requestAnimationFrame`, não uma comprovação de pixels pintados.
- `visibilityState` e `hasFocus`: estado do documento no momento da coleta,
  sem forçar visibilidade ou foco.
- `capturedAtMs`: instante da coleta após `firstFrameMs`, sujeito ao intervalo
  de polling; não é outro timestamp do primeiro frame.
- `longTasks`: até as **20 primeiras** entradas desde o início da navegação até
  a coleta, contendo somente `startTime` e `duration`. A fila pendente é drenada
  antes de desconectar o observer; `longTaskCount` informa o total observado e
  `longTasksTruncated` indica entradas omitidas.

Não são exportados URLs, nomes de recursos, attribution de long tasks nem dados
de sessão. Falhas CDP/JavaScript, observer indisponível ou ausência de FCP/timings
interrompem a medição com saída não zero: não há diagnóstico vazio tratado como
sucesso. Perfis isolados do Chrome ficam em `build/plpcg-measure-*` e são removidos
na saída, inclusive quando a coleta falha.
O Chrome e encerrado via `Browser.close` antes da exclusao do perfil; interromper
somente o processo principal deixava filhos gravando nesse diretorio no Linux.
Se o encerramento nao responder, o runner sinaliza o grupo exclusivo criado para
esse browser e aguarda sua saida. Falhas de limpeza nao sao ignoradas.

Esses dados ajudam a distinguir espera de resposta, parsing/bloqueio da main
thread e diferenças entre marca RAF/FCP. Não demonstram sozinhos uma causa nem
recalibram o limite do loader de **150 ms**; compare amostras no Ubuntu do CI.

### Navegador de referencia do CI

O workflow usa `chrome-version: stable`. O valor omitido da action
[`setup-chrome`](https://github.com/browser-actions/setup-chrome/tree/v1#supported-version-formats)
e `latest`, um snapshot de desenvolvimento do Chromium, nao Chrome Stable.
Esse snapshot mudou de 1735867 para 1735935 entre as execucoes investigadas,
sem alteracao no boot da app; loader e primeiro frame variaram de 164/1979 ms
para 94/1318 ms. O browser de referencia deve ser uma versao publicada, e o
log da action informa a versao efetivamente instalada.

O experimento pareado no Ubuntu nao justificou alterar preloads, halo, foco
ou esperar `about:blank`: os controles tambem variaram (125 para 87 ms).
Nenhuma dessas alteracoes ficou na app. O script e a etapa temporarios de
comparacao foram removidos; o gate continua medindo navegacoes frias em perfis
novos, sem aquecer a app e sem mudar o limite.

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

Testes focados do runner (stdlib Python; fixture localhost no Chrome instalado,
sem build Flutter):

```bash
python3 -B -m unittest discover -s scripts -p test_measure_web_boot.py
# Mesmo comando do CI, incluindo a automacao de entrega:
PYTHONPATH=scripts python3 -B -m unittest test_task_delivery test_measure_web_boot
```

Validam o limite 150/151 ms, preservação da mediana, timings reais, observer
anterior ao script da página, saída limitada/redigida e falhas explícitas.
Sem Chrome, somente os casos de integração são reportados como skipped.
