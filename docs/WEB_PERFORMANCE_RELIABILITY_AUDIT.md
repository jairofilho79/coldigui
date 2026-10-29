# Auditoria de performance, confiabilidade e disponibilidade — Web PLPCG

**Criado em:** julho/2026  
**Origem:** análise e2e do build Flutter Web (`coldigui`)  
**Complementa:** [WEB_PERFORMANCE_AND_LOADING.md](WEB_PERFORMANCE_AND_LOADING.md) (fases A–H) e [PERFORMANCE_BACKLOG.md](PERFORMANCE_BACKLOG.md) (itens 1–7)

Este documento registra achados **novos** da auditoria e2e, com ações práticas, trade-offs e critérios de aceite. Não duplica itens já cobertos nos documentos acima.

---

## Priorização

| # | Item | Eixo | Impacto | Esforço | Risco |
|---|------|------|---------|---------|-------|
| A1 | `select` no watch de downloads em `LouvorGroupCard` | Performance | Médio | Baixo | Muito baixo |
| C1 | Preload adaptativo de `skwasm.wasm` | Disponibilidade + Performance | Médio | Médio | Médio |
| A3/C2 | Conectar `PdfrxIdlePreloader` com gate de conectividade | Performance + Disponibilidade | Médio | Baixo–Médio | Baixo |
| A2 | Unificar `library_results_provider` legado | Performance + Confiabilidade | Alto | Médio | Médio |
| B1 | Modo degradado sem Isar | Confiabilidade + Disponibilidade | Alto | Alto | Alto |

**Ordem de execução:** A1 → C1 → A3 → A2 → B1

---

## A. Performance

### A1 — `LouvorGroupCard` observa mapa inteiro de downloads

**Arquivo:** `lib/features/catalog/presentation/widgets/louvor_group_card.dart`

**Problema:** `ref.watch(louvorPdfDownloadProvider)` sem `select` faz rebuild de todos os cards visíveis quando qualquer download muda.

**Solução:** `ref.watch(louvorPdfDownloadProvider.select(...))` restrito aos `pdfId`s do grupo/card.

**Critério de aceite:** Mudança de estado de download em um louvor não rebuilda cards de outros louvores.

**Trade-off:** nenhum.

---

### A2 — Provider legado da Biblioteca em paralelo

**Arquivos:** `library_results_provider.dart`, `library_pagination_controls.dart`, `library_results_summary.dart`

**Problema:** Pipeline síncrono legado roda em paralelo ao `libraryGroupResultsProvider` (off-thread), causando trabalho duplicado e possível divergência de contagens.

**Solução:** Migrar controles de paginação/resumo para `libraryGroupResultsProvider` e remover `library_results_provider.dart`.

**Critério de aceite:** Contagens e paginação refletem grupos renderizados na lista; testes UC-03 passam.

**Trade-off:** nenhum — dívida técnica de migração incompleta.

---

### A3 — `PdfrxIdlePreloader` não montado

**Arquivo:** `lib/features/pdf_reader/data/pdfrx_bootstrap.dart`

**Problema:** Preload idle do WASM pdfrx (~5 MB) implementado mas nunca conectado à árvore de widgets.

**Solução:** Montar `PdfrxIdlePreloader` no shell, condicionado a conexão não medida (mesma política Wi-Fi-only).

**Critério de aceite:** Em Wi-Fi, pdfrx inicia em idle após primeiro frame; em dados móveis, não prefetcha.

**Trade-off:** prefetch em idle consome banda para quem nunca abre PDF — mitigado pelo gate de rede.

---

## B. Confiabilidade

### B1 — Boot bloqueado quando Isar falha

**Arquivos:** `lib/bootstrap_app.dart`, `lib/core/database/isar_provider.dart`, datasources Isar

**Problema:** Falha em `Isar.initialize` / OPFS deixa o usuário preso em tela de erro sem acesso ao catálogo online.

**Solução:** Modo degradado — app abre com catálogo remoto, busca/biblioteca e leitor online; playlists/offline/carousel persistido indisponíveis com aviso e retry.

**Critério de aceite:**

- Simular falha de Isar → Home/Biblioteca carregam via API
- PDF online abre normalmente
- Abas Offline/Listas mostram tela de indisponibilidade controlada
- Retry reabre Isar sem reload da página

**Trade-off:** complexidade adicional no contrato de storage; versão mínima é network-only (sem playlists em memória).

---

### B2 — Divergência de contagens Biblioteca

Coberto por A2.

---

## C. Disponibilidade / hardware fraco

### C1 — Preload incondicional de `skwasm.wasm`

**Arquivo:** `web/index.html`

**Problema:** Navegadores sem suporte a skwasm baixam ~3,4 MB inutilmente antes do fallback para canvaskit.

**Solução:** Script no `<head>` detecta suporte (WASM + `SharedArrayBuffer` + `crossOriginIsolated`) e insere preload de `skwasm.wasm` apenas quando positivo. Registra `rendererPreload` em `window.__plpcgPerf`.

**Critério de aceite:**

- Chrome moderno com COOP/COEP mantém preload skwasm
- Navegador sem suporte não baixa skwasm no preload
- App abre pelo fallback padrão do Flutter se detecção falhar

**Trade-off:** não altera renderer escolhido pelo Flutter — só evita download inútil no preload.

---

### C2 — Preload idle pdfrx sem gate de rede

Coberto por A3.

---

### C3 — Artefato total ~56 MB

Já mitigado por cache HTTP, code splitting e deferred imports. Novos recursos devem passar pelo crivo preload vs deferred.

---

## O que já está bem (não reimplementar)

| Área | Padrão | Onde |
|------|--------|------|
| Boot web | Splash HTML + preload WASM + medição CI | `web/index.html`, fases A–H |
| Catálogo | Cache-first + skeleton | `louvores_manifest_provider.dart` |
| Busca Home | `compute()` + debounce | `home_search_provider.dart` |
| Biblioteca pipeline | Off-thread (grupos) | `library_group_results_provider.dart` |
| PDF | Deferred route + lazy pdfrx init | `app_router.dart` |

---

## Histórico

| Data | Ação |
|------|------|
| jul/2026 | Auditoria e2e inicial — achados A1–C3 documentados |
| jul/2026 | B1 e C1 elevados de “estudo” para ações práticas (modo degradado + preload adaptativo) |
