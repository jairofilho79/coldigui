# Performance e loading na Web — diagnóstico e plano de trabalho

**Status:** backlog (não iniciado)  
**Data:** julho/2026  
**Contexto:** Após conclusão do [WEB_BUILD_REFACTOR_PLAN.md](WEB_BUILD_REFACTOR_PLAN.md) (Fases 0–8), o app compila e roda na web (`flutter build web --wasm`), mas a **primeira visita** exibe tela branca por **3–5 segundos** antes de qualquer UI. Este documento consolida o diagnóstico, comparação com nativo, e um plano faseado para o próximo agente/sessão trabalhar de forma aprofundada.

---

## Sintoma observado

| Aspecto | Comportamento |
|---|---|
| Plataforma | Web (Chrome/Safari, deploy ou `scripts/web_local_dev.py`) |
| Momento | **Primeira visita** ou hard refresh (sem cache quente) |
| Duração | ~3–5 s de tela completamente branca |
| Depois | App Flutter aparece e funciona normalmente |
| Nativo (iOS/Android) | Sem esse delay perceptível no cold start |

---

## Por que acontece (diagnóstico)

Flutter Web **não pinta nenhum pixel** até que todo o pipeline abaixo conclua. O `web/index.html` atual não tem splash/loader — só carrega `flutter_bootstrap.js`:

```html
<!-- web/index.html — estado atual -->
<script src="flutter_bootstrap.js" async></script>
```

Enquanto isso, o `<body>` está vazio → **tela branca**.

### Pipeline de boot (ordem cronológica)

```text
1. HTML parse + download flutter_bootstrap.js
2. Download + compilação/inicialização do engine Flutter Web (WASM)
      ├── main.dart.wasm (~3,6 MB)
      ├── main.dart.js (~4,1 MB) — fallback / bootstrap
      └── canvaskit/skwasm (~3–7 MB conforme renderer)
3. main() Dart executa ANTES de runApp:
      ├── await pdfrxFlutterInitialize()     → pdfium.wasm (~5,0 MB)
      └── await openAppIsar()                → isar_plus.wasm (~1,3 MB)
4. SharedPreferences.getInstance()
5. runApp(ColdiguiApp) → primeiro frame Flutter
6. ColdiguiApp dispara louvoresManifestProvider (fetch catálogo ~4600 itens)
```

**Gargalo principal:** etapas 2–3 ocorrem **antes** do primeiro frame. O usuário vê branco durante download + parse/instanciação de WASM + init síncrona de Isar e pdfrx.

### Inventário de assets pesados (build release, jul/2026)

Medição em `build/web/` após `flutter build web --wasm --release`:

| Asset | Tamanho aprox. | Quando carrega |
|---|---|---|
| `main.dart.wasm` | 3,6 MB | Boot (obrigatório) |
| `main.dart.js` | 4,1 MB | Boot (obrigatório) |
| `canvaskit/canvaskit.wasm` | 6,9 MB | Boot (renderer) |
| `canvaskit/skwasm.wasm` | 3,4 MB | Boot (renderer WASM) |
| `assets/packages/pdfrx/assets/pdfium.wasm` | 5,0 MB | Boot (`pdfrxFlutterInitialize`) |
| `isar_plus.wasm` | 1,3 MB | Boot (`Isar.initialize`) |
| Fontes (EBGaramond, OpenSans) | incluídas no bundle | Boot (tipografia) |
| **Total `build/web/`** | **~56 MB** | — |

> Nota: na visita subsequente, o service worker cacheia a maior parte; o delay cai drasticamente. O problema reportado é **cold start / first visit**.

### Código que bloqueia o primeiro frame

```dart
// lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();   // ← bloqueia: carrega pdfium.wasm
  final isar = await openAppIsar(); // ← bloqueia: carrega isar_plus.wasm
  final prefs = await SharedPreferences.getInstance();
  runApp(...);
}
```

```dart
// lib/core/database/isar_bootstrap_web.dart
await Isar.initialize('isar_plus.wasm');
return Isar.open(..., engine: IsarEngine.sqlite);
```

### Cabeçalhos COOP/COEP (SharedArrayBuffer / OPFS)

Isar web e pdfrx WASM performam melhor com `SharedArrayBuffer`, que exige:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

- **Produção:** configurado em `web/_headers` (Cloudflare Pages).
- **Dev local:** `scripts/web_local_dev.py` injeta os mesmos headers.
- **Sem COOP/COEP:** Isar/pdfrx caem em modos single-thread mais lentos — aumenta o tempo de boot.

Referência: [WEB_BUILD_REFACTOR_PLAN.md §Fase 5/6](WEB_BUILD_REFACTOR_PLAN.md) (D5, D6).

---

## Por que no nativo (iOS/Android) isso não acontece

| Fator | Web | Nativo |
|---|---|---|
| Engine | Baixado e compilado no browser a cada cold start | Binário AOT pré-instalado no dispositivo |
| Isar | WASM + IndexedDB/OPFS (~1,3 MB + init) | Arquivo local via `path_provider` (instantâneo) |
| pdfrx | WASM pdfium (~5 MB) carregado no boot | Biblioteca nativa linkada no app |
| Primeiro frame | Só após WASM + init async | Quase imediato após `runApp` |
| Cache | Depende de service worker / HTTP cache | N/A (app local) |

O nativo **não paga o custo de rede + instanciação WASM** na abertura. O binário já está na memória do processo.

---

## Objetivos do plano

1. **Percepção imediata:** splash/loader visível em <100 ms (HTML/CSS puro, sem Flutter).
2. **Reduzir tempo até UI útil:** adiar init pesada (Isar, pdfrx) para depois do primeiro frame quando possível.
3. **Otimizar cold start:** preload, cache headers, validar COOP/COEP em produção.
4. **Medir antes/depois:** baseline Lighthouse + Performance API + DevTools Network.

---

## Plano de trabalho faseado

Cada fase = PR pequeno e escopado. Seguir regra anti-overengineering: alterar só o necessário.

### Fase A — Splash screen HTML (quick win, alto impacto na percepção)

**Objetivo:** eliminar tela branca; mostrar branding enquanto Flutter carrega.

**Arquivos:** `web/index.html` (principal), opcionalmente `web/splash.css`.

**Implementação sugerida:**

1. Adicionar `<div id="loading">` no `<body>` **antes** do script Flutter, com:
   - Cor de fundo `#4B2D2B` (`AppColors.background` / `manifest.json` `background_color`)
   - Logo ou texto "PLPCG" + spinner CSS
   - `theme-color` já é `#D4AF37` (`AppColors.gold`)
2. Remover o loader quando Flutter sinalizar primeiro frame:
   - **Opção recomendada:** callback `onEntrypointLoaded` / `didCreateEngineInitializer` do `flutter_bootstrap.js` (ver [Flutter web initialization](https://docs.flutter.dev/platform-integration/web/initialization))
   - **Opção simples:** `MutationObserver` em `flt-glass-pane` ou evento `flutter-first-frame`
3. Garantir que o loader funciona **sem JavaScript Dart** — só HTML/CSS/JS vanilla.

**Critérios de aceite:**

- [ ] Loader visível em <100 ms após navegação (Network throttling 3G simulado).
- [ ] Loader some suavemente no primeiro frame Flutter.
- [ ] Sem regressão em PWA install (`manifest.json` background alinhado).
- [ ] Smoke Chrome continua verde.

**Estimativa de esforço:** baixo (1 PR, ~1–2 h).

---

### Fase B — Adiar inicialização de Isar e pdfrx

**Objetivo:** `runApp` o mais cedo possível; init pesada em background.

**Problema atual:** `main()` bloqueia ~2 WASM loads antes de qualquer UI.

**Abordagem sugerida:**

1. **`runApp` imediato** após `WidgetsFlutterBinding.ensureInitialized()`.
2. Mover `openAppIsar()` para provider assíncrono (ex.: `FutureProvider<Isar>` ou `AsyncNotifier`) com estado `loading` / `ready` / `error`.
3. Mover `pdfrxFlutterInitialize()` para **lazy init** — só quando o usuário abrir um PDF (ex.: no `PdfrxViewerAdapter` ou provider do leitor).
4. Telas que dependem de Isar (catálogo cache, playlists, offline) exibem skeleton/loading até `isarProvider` resolver.
5. Manter override em `ProviderScope` quando Isar estiver pronto (`ref.listen` + rebuild controlado, ou `ProviderScope` com override tardio via `UncontrolledProviderScope` / padrão já usado no projeto).

**Arquivos prováveis:**

- `lib/main.dart`
- `lib/core/database/isar_provider.dart`
- `lib/core/database/isar_bootstrap_web.dart`
- `lib/app.dart` (shell de loading global opcional)
- Features que usam `isarProvider` diretamente no boot

**Riscos / cuidados:**

- Race conditions se UI acessar Isar antes de estar pronto — usar `AsyncValue` consistentemente.
- Smoke tests web precisam aguardar Isar ready.
- Não quebrar boot nativo — conditional import já separa `isar_bootstrap_native.dart` / `_web.dart`.

**Critérios de aceite:**

- [ ] Primeiro frame Flutter em ≤2 s (cold start, rede rápida) — medir antes/depois.
- [ ] Isar abre em background; catálogo mostra loading state explícito.
- [ ] pdfrx só inicializa ao abrir PDF; leitor continua funcional.
- [ ] `flutter test` + `flutter test --platform chrome` verdes.
- [ ] Sem regressão iOS/Android.

**Estimativa de esforço:** médio-alto (2–3 PRs).

---

### Fase C — Cache HTTP e service worker

**Objetivo:** segunda visita e reload quente quase instantâneos.

**Estado atual:**

- `web/_headers` define COOP/COEP global e `Cache-Control: no-cache` só para `flutter_service_worker.js`.
- Assets versionados (`.wasm`, `.js` com hash) recebem `Cache-Control: public, max-age=31536000, immutable` (implementado jul/2026).
- `scripts/web_local_dev.py` espelha as mesmas regras de cache para validação local.

**Implementação sugerida:**

1. Em `web/_headers` (Cloudflare Pages), adicionar regras para:
   ```
   /*.wasm
     Cache-Control: public, max-age=31536000, immutable

   /*.js
     Cache-Control: public, max-age=31536000, immutable
   ```
   (ajustar paths conforme estrutura real do build — ver também `/canvaskit/*`, `/assets/packages/*/assets/*`)
2. Validar que `flutter_service_worker.js` continua com `no-cache` (**regra por último**, após `/*.js`).
3. Confirmar que deploy em `plpcjf.org` / `v2.plpcg.com` aplica `_headers`.
4. Documentar comportamento esperado: 1ª visita lenta, 2ª visita rápida.

**Comportamento esperado (hard refresh vs reload):**

| Ação | O que acontece |
|---|---|
| **1ª visita** (sem cache) | Download completo de WASM/JS; lento (~3–5 s antes do Flutter). |
| **Reload normal** (F5) | Browser usa cache HTTP (`immutable`); SW revalida `flutter_service_worker.js`; rápido. |
| **Hard refresh** (Ctrl+Shift+R) | Ignora cache HTTP; re-download de assets; similar à 1ª visita. |
| **Novo deploy** | SW busca `flutter_service_worker.js` (`no-cache`), detecta hash novo, precacheia assets atualizados; visita seguinte usa versão nova. |

**Validação pós-deploy:**

```bash
# Cache longo em assets WASM/JS
curl -sI https://plpcjf.org/main.dart.wasm | grep -i cache-control
curl -sI https://plpcjf.org/canvaskit/canvaskit.wasm | grep -i cache-control

# Service worker sempre revalidado
curl -sI https://plpcjf.org/flutter_service_worker.js | grep -i cache-control
```

DevTools → Network: reload normal deve mostrar `(disk cache)` ou `(memory cache)` em `.wasm`/`.js`; hard refresh deve mostrar transfer size completo.

**Critérios de aceite:**

- [x] Regras `immutable` em `web/_headers` + espelho em `web_local_dev.py`.
- [ ] DevTools Network: assets `.wasm`/`.js` servidos com cache longo em produção (validar após deploy).
- [x] Hard refresh vs normal reload documentados (tabela acima).
- [ ] Service worker atualiza corretamente após novo deploy (validar após deploy).

**Estimativa de esforço:** baixo (1 PR infra).

---

### Fase D — Validar COOP/COEP em produção

**Objetivo:** garantir que Isar OPFS e pdfrx multi-thread estão ativos (não fallback lento).

**Checklist:**

- [ ] `curl -I https://<domínio-web>/` → headers COOP/COEP presentes.
- [ ] Console do browser: sem warning de `SharedArrayBuffer` desabilitado.
- [ ] Isar abre com OPFS (não fallback IndexedDB lento) — ver logs/debug do `isar_plus`.
- [ ] Comparar tempo de `Isar.initialize` com e sem headers (baseline).

**Referência:** `scripts/web_local_dev.py` já simula headers corretos em dev.

**Estimativa de esforço:** baixo (validação + doc).

---

### Fase E — Preload de recursos críticos

**Objetivo:** paralelizar download de WASM enquanto JS bootstrap parseia.

**Implementação sugerida em `web/index.html`:**

```html
<link rel="preload" href="isar_plus.wasm" as="fetch" crossorigin="anonymous">
<link rel="preload" href="main.dart.wasm" as="fetch" crossorigin="anonymous">
<!-- pdfrx: só se mantiver init no boot; caso Fase B adie, remover preload de pdfium -->
```

**Cuidados:**

- Preload errado desperdiça banda — medir impacto real antes/depois.
- Se Fase B adiar pdfrx, **não** preload pdfium.

**Critérios de aceite:**

- [ ] Waterfall Network mostra downloads paralelos.
- [ ] Tempo total de boot medido (Performance API) igual ou menor.

**Estimativa de esforço:** baixo.

---

### Fase F — Code splitting / deferred imports

**Objetivo:** reduzir tamanho do bundle inicial (`main.dart.wasm`).

**Candidatos a `deferred as`:**

- Feature PDF reader (`pdfrx`, adapters)
- Feature offline bulk (ZIP, extractors)
- Feature leaflet (captura PNG)
- Telas raramente acessadas no primeiro uso (settings offline, etc.)

**Abordagem:**

1. Auditar grafo de imports a partir de `main.dart`.
2. Aplicar `import '...' deferred as pdf_reader;` + `await pdf_reader.loadLibrary()` na navegação.
3. Medir redução de `main.dart.wasm` e tempo de parse.

**Riscos:**

- Complexidade de routing (GoRouter) com libraries deferred.
- WASM deferred loading tem nuances — testar em Chrome e Safari.

**Critérios de aceite:**

- [ ] `main.dart.wasm` reduzido mensuravelmente (meta: −15–30%, a validar).
- [ ] Navegação para features deferred mostra loading breve aceitável.
- [ ] Build WASM continua passando.

**Estimativa de esforço:** alto (múltiplos PRs).

---

### Fase G — Otimizar boot do catálogo (~4600 louvores)

**Objetivo:** UI shell visível enquanto catálogo carrega.

**Estado atual:**

- `ColdiguiApp` usa `ref.listen(louvoresManifestProvider, ...)` no boot — **não bloqueia** `runApp`, mas a home pode parecer vazia até o manifest resolver.
- `LouvoresManifest` carrega do Isar cache + possível fetch remoto.

**Melhorias possíveis:**

1. Skeleton/shimmer na `HomeScreen` enquanto `louvoresManifestProvider` é `loading`.
2. Avaliar se índice Isar de ~4600 registros no open inicial adiciona latência perceptível.
3. Paginação ou lazy load do catálogo na UI (não carregar todos os chips/filtros de uma vez).
4. Service Worker cache da API `/api/catalog/louvores` (fora do escopo Flutter — worker Cloudflare).

**Critérios de aceite:**

- [ ] Home mostra shell + skeleton em <500 ms após primeiro frame Flutter.
- [ ] Catálogo interativo assim que manifest estiver `data`.

**Estimativa de esforço:** médio.

---

### Fase H — Medição e regressão contínua

**Objetivo:** baseline numérico e gate de regressão.

**Métricas a capturar (cold start, throttling Fast 3G):**

| Métrica | Como medir |
|---|---|
| Time to loader visible | Performance `navigationStart` → loader paint |
| Time to first Flutter frame | `flutter-first-frame` event ou `flt-glass-pane` no DOM |
| Time to interactive home | Manifest `data` + lista renderizada |
| Total transfer size | DevTools Network (Disable cache) |
| Lighthouse Performance score | CI ou manual pré-release |

**Ações:**

- [ ] Script ou doc com passos reproduzíveis de medição.
- [ ] Opcional: teste Chrome (`test/web/`) que asserta presença do loader HTML antes do Flutter.
- [ ] Registrar baseline antes da Fase A e comparar após cada fase.

---

## Ordem recomendada de execução

```text
A (splash HTML)  →  percepção imediata, baixo risco
D (validar COOP) →  garantir ambiente correto antes de otimizar
C (cache headers)→  melhora visitas subsequentes
B (defer init)   →  maior ganho no cold start real
E (preload)      →  incremental sobre B
G (catálogo UX)  →  paralelo ou após B
F (deferred)     →  maior esforço, fazer por último
H (medição)      →  contínuo em todas as fases
```

---

## Arquivos e referências do repositório

| Arquivo | Relevância |
|---|---|
| `web/index.html` | Ponto de entrada; splash loader |
| `web/_headers` | COOP/COEP + cache (Cloudflare Pages) |
| `web/manifest.json` | Cores PWA (`#4B2D2B`, `#D4AF37`) |
| `web/isar_plus.wasm`, `web/isar_plus.js` | Assets Isar web (OPFS) |
| `lib/main.dart` | Boot bloqueante atual |
| `lib/core/database/isar_bootstrap_web.dart` | Init Isar WASM |
| `lib/core/database/isar_bootstrap_native.dart` | Comparação nativo |
| `lib/app.dart` | Dispara manifest no boot |
| `lib/core/theme/color_extensions.dart` | Tokens de cor para splash |
| `scripts/web_build.sh` | Build release WASM |
| `scripts/web_local_dev.py` | Dev local com COOP/COEP |
| `scripts/fetch_isar_web_assets.sh` | Copia WASM Isar para `web/` |
| `docs/WEB_BUILD_REFACTOR_PLAN.md` | Contexto migração web (D5 WASM, D6 COOP) |
| `docs/web_phase8_build_report.md` | Versões Flutter/Dart usadas no build |

---

## Prompt sugerido para o próximo agente

```text
Siga docs/WEB_PERFORMANCE_AND_LOADING.md.

Fase deste PR: [A|B|C|D|E|F|G|H]
Objetivo: [descrever fase]

Antes de codar:
1. Medir baseline cold start (DevTools, Disable cache).
2. Confirmar COOP/COEP se a fase tocar Isar/pdfrx.

Build/test:
  flutter analyze
  flutter test
  flutter test --platform chrome test/web/ --dart-define-from-file=dart_defines/plpcjf.json
  flutter build web --wasm --release --dart-define-from-file=dart_defines/plpcjf.json

Regras:
- Anti-overengineering: só alterar o escopo da fase.
- Não quebrar boot nativo (iOS/Android).
- Documentar métricas antes/depois neste arquivo ou em comentário no PR.
```

---

## Notas adicionais

- **Tela branca ≠ bug de Flutter** — é comportamento esperado sem splash customizado + boot síncrono pesado.
- **Eliminar completamente o delay na 1ª visita é impossível** (WASM + rede); o objetivo realista é (1) feedback visual imediato e (2) reduzir bytes/init antes do primeiro frame.
- **Safari iOS** pode ser mais lento com WASM — incluir no test plan (Fase 5 do refactor plan já alertava para isso).
- Após Fase A, o usuário verá loader → app; o tempo total pode ser igual, mas a **percepção** melhora drasticamente.

---

## Histórico

| Data | Evento |
|---|---|
| jul/2026 | Documento criado a partir de análise de cold start web vs nativo |
| jul/2026 | **Fase C:** cache HTTP `immutable` para `.wasm`/`.js` em `web/_headers`; espelho em `web_local_dev.py` |
