# Backlog de upgrades de dependências (Dart/Flutter)

**Status:** inventário concluído (jun/2026) — Onda 1 ✅ — Ondas 2–4 pendentes  
**Data:** junho de 2026  
**Contexto:** auditoria pós-migração SPM ([MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md) Fases A/B/C concluídas). Nenhuma dependência **direta** está marcada `isDiscontinued` no pub.dev; o backlog é de **modernização major**, não de substituição por abandono.

**Complementa:** [MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md) (deps nativas / SPM) — **não misturar** upgrades deste doc com novas migrações nativas no mesmo PR.

---

## Resumo executivo

| Situação | Detalhe |
|----------|---------|
| Deps descontinuadas (diretas) | **Nenhuma** |
| Já resolvido | `isar` → `isar_plus`, remoção `disk_space_plus`, `pdfx` → `pdfrx` |
| Backlog real | 6 upgrades major/dev listados abaixo |
| Ordem | lints → build_runner → plus_plugins → go_router → riverpod |

---

## Inventário — dependências diretas (jun/2026)

| Pacote | Versão no projeto | Última pub.dev | Descontinuada? | Observação |
|--------|-------------------|----------------|----------------|------------|
| `archive` | 4.0.x | 4.0.9 | Não | Ativa |
| `dio` | 5.9.x | 5.10.0 | Não | Ativa |
| `flutter_riverpod` | 2.6.1 | 3.3.2 | Não | Major 3 pendente |
| `go_router` | 14.8.x | 17.3.0 | Não | 3 majors atrás |
| `isar_plus` | 1.3.7 | 1.3.7 | Não | Substituição do `isar` ✅ |
| `isar_plus_flutter_libs` | 1.3.7 | 1.3.7 | Não | Idem |
| `path_provider` | 2.1.6 | 2.1.6 | Não | Atual |
| `share_plus` | 10.1.x | 13.2.0 | Não | Major pendente |
| `shared_preferences` | 2.3.x | 2.5.5 | Não | Bump minor futuro (fora deste backlog) |
| `app_links` | 7.0.x | 7.2.0 | Não | Bump patch futuro |
| `connectivity_plus` | 6.1.x | 7.2.0 | Não | Major pendente |
| `wakelock_plus` | 1.5.x | 1.6.1 | Não | Bump minor futuro |
| `flutter_svg` | 2.2.x | 2.3.0 | Não | Bump minor futuro |
| `pdfrx` | 2.4.4 | 2.4.4 | Não | Fase C concluída ✅ |

### Dev dependencies

| Pacote | Versão no projeto | Última pub.dev | Neste backlog? |
|--------|-------------------|----------------|----------------|
| `build_runner` | 2.15.0 | 2.15.0 | Sim — Onda 1 ✅ |
| `flutter_launcher_icons` | 0.14.x | 0.14.4 | Não (dev-only, estável) |
| `flutter_lints` | 6.0.0 | 6.0.0 | Sim — Onda 1 ✅ |

### Transitivas — atenção (não exigem ação imediata)

| Pacote | Última release | Usado por | Risco |
|--------|----------------|-----------|-------|
| `state_notifier` | ago/2023 | `flutter_riverpod` 2.x | Some ao migrar Riverpod 3 |
| `rxdart` | jun/2024 | `connectivity_plus` | Baixo |
| `nm` | fev/2022 | `connectivity_plus` (Linux) | Baixo — API estável |
| `sky_engine` | 2016 (stub pub.dev) | SDK Flutter | Falso positivo — ignorar |

---

## Metodologia de priorização

| Dimensão | Escala |
|----------|--------|
| **Esforço** | 1 (horas) → 5 (vários dias + muitos testes) |
| **Risco** | 1 (quase só bump) → 5 (regressão em fluxos críticos) |
| **Benefício** | 1 (cosmético) → 5 (segurança, SPM, desbloqueia evolução) |
| **Score** | Benefício ÷ (Esforço × Risco) — maior = fazer antes |

---

## Matriz de prioridade

| Upgrade | Esforço | Risco | Benefício | Score | Onda | PR sugerido |
|---------|:-------:|:-----:|:---------:|:-----:|:----:|-------------|
| `flutter_lints` 5 → 6 | 1 | 1 | 2 | **2,0** | 1 | `chore(lints): flutter_lints 6` |
| `build_runner` 2.4 → 2.15 | 1 | 2 | 2 | **1,0** | 1 | `chore(dev): build_runner 2.15` |
| `connectivity_plus` 6 → 7 | 2 | 1 | 3 | **1,5** | 2 | `chore(deps): connectivity_plus 7` |
| `share_plus` 10 → 13 | 2 | 2 | 3 | **0,75** | 2 | `chore(deps): share_plus 13` |
| `go_router` 14 → 17 | 3 | 4 | 3 | **0,25** | 3 | `refactor(routing): go_router 17` |
| `flutter_riverpod` 2 → 3 | 5 | 4 | 4 | **0,20** | 4 | `refactor(state): riverpod 3` |

---

## Ordem de execução recomendada

```text
Onda 1 — dev toolchain (~½ dia)
  PR-A: flutter_lints 6
  PR-B: build_runner 2.15 + regen isar .g.dart

Onda 2 — plus_plugins (~1 dia)
  PR-C: connectivity_plus 7 + share_plus 13
        (mesmo PR permitido — mesmo ecossistema, superfícies pequenas)

Onda 3 — roteamento (~2–3 dias)
  PR-D: go_router 17 (incremental 14→15→16→17 se necessário)

Onda 4 — estado (~3–5 dias)
  PR-E: flutter_riverpod 3
        riverpod_generator: PR separado, opcional depois
```

**Regra para agentes:** uma onda (ou um PR da onda) por entrega, salvo combinação explícita do mantenedor. Não misturar ondas no mesmo diff.

---

## Instruções gerais (todos os agentes)

### Antes de codar

1. Ler este documento e identificar a **onda** alvo.
2. Ler [FEATURE_INDEX.md](features/FEATURE_INDEX.md) nas seções tocadas.
3. Confirmar Flutter **≥ 3.44** e Dart **≥ 3.12** (`flutter --version`).
4. Escopo mínimo: alterar só o necessário para a onda atual (regra anti-overengineering).

### Durante a implementação

- **Não** atualizar pacotes fora do escopo da onda.
- **Não** misturar com migrações nativas/SPM ([MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md)).
- **Testes:** manter ou substituir cobertura equivalente; não remover testes de regressão.
- Conferir changelogs oficiais no pub.dev / GitHub antes de aplicar breaking changes.

### Antes de entregar

```bash
dart run build_runner build --delete-conflicting-outputs   # Onda 1-B e quando houver .g.dart
flutter analyze
flutter test
flutter build ios --simulator --dart-define-from-file=dart_defines/plpcg.json   # se tocar plugin nativo
```

### O que **não** fazer

| Combinação | Motivo |
|------------|--------|
| Riverpod 3 + go_router 17 | Dois eixos de regressão; falhas difíceis de isolar |
| Qualquer onda + migração SPM | Regra de [MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md) |
| Riverpod 3 + `riverpod_generator` no mesmo PR | Runtime + codegen = dois tipos de mudança |
| Desabilitar lints em massa | Corrigir ou justificar regra a regra |

### Git workflow (agentes)

- **Não criar branches** para ondas de upgrade — trabalhar na branch atual.
- **Commit local** ao concluir cada onda (ou sub-onda), com a mensagem conventional commit sugerida na matriz de prioridade.
- **`git add` seletivo** — incluir só arquivos do escopo da onda; não misturar ondas nem migrações SPM ([MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md)) no mesmo commit.
- **Não fazer push** salvo pedido explícito do mantenedor.

---

## Onda 1-A — `flutter_lints` 5 → 6 ✅

**Status:** concluída (jun/2026)  
**Prioridade:** 1ª  
**Esforço:** muito baixo | **Risco:** baixo | **Benefício:** alinhamento Dart 3.12+

### Escopo

| Arquivo | Ação |
|---------|------|
| `pubspec.yaml` | `flutter_lints: ^6.0.0` |
| `analysis_options.yaml` | Revisar se novas regras exigem ajuste (hoje: `include: package:flutter_lints/flutter.yaml`) |
| `lib/`, `test/` | Corrigir avisos novos do analyzer |

### Critérios de aceite

- [x] `flutter analyze` sem issues
- [x] Nenhuma regra desabilitada em massa sem comentário

---

## Onda 1-B — `build_runner` 2.4 → 2.15 ✅

**Status:** concluída (jun/2026)  
**Prioridade:** 2ª  
**Esforço:** muito baixo | **Risco:** médio-baixo | **Benefício:** toolchain dev atual

### Escopo

| Arquivo | Ação |
|---------|------|
| `pubspec.yaml` | `build_runner: ^2.15.0` (ou última compatível) |
| `lib/core/database/collections/*.g.dart` | Regenerar via `build_runner` |

### Arquivos `.g.dart` afetados (4)

- `louvor_cache.g.dart`
- `carousel_entry.g.dart`
- `playlist.g.dart`
- `offline_pdf_index.g.dart`

Codegen via `isar_plus` — **não** há `riverpod_generator` no projeto hoje.

### Critérios de aceite

- [x] Diff dos `.g.dart` vazio ou trivial (sem mudança de schema)
- [x] `flutter test` verde
- [x] `isar_plus` smoke test passa (`test/unit/core/database/isar_smoke_test.dart`)

---

## Onda 2 — `connectivity_plus` 6 → 7 + `share_plus` 10 → 13

**Prioridade:** 3ª  
**Esforço:** baixo-médio | **Risco:** baixo-médio | **Benefício:** patches de plataforma, ecossistema `fluttercommunity/plus_plugins` atual

### `connectivity_plus` — arquivos principais

| Arquivo | Papel |
|---------|-------|
| `lib/core/network/device_connectivity.dart` | `Connectivity.checkConnectivity()` |
| `lib/core/providers/device_connectivity_provider.dart` | Provider DI |
| `lib/features/pdf_reader/data/datasources/connectivity_network_connection_checker.dart` | `NetworkConnectionChecker` — prefetch |
| `test/unit/features/pdf_reader/prefetch_network_policy_test.dart` | Testes |

**Favorável:** portas de domínio (`DeviceConnectivity`, `NetworkConnectionChecker`) já isolam o pacote. `ConnectivityResult` usa `switch` exaustivo (incl. `satellite`).

**Conferir no changelog v7:** assinaturas de `checkConnectivity`, enum `ConnectivityResult`, listeners/stream se forem adotados depois.

### `share_plus` — arquivos principais

| Arquivo | Papel |
|---------|-------|
| `lib/features/pdf_opening/domain/usecases/share_pdf.dart` | UC-04 — share PDF |
| `lib/features/playlists/presentation/providers/playlists_provider.dart` | Share playlist |
| `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart` | Ações de share |
| `lib/features/leaflet/presentation/providers/leaflet_actions_provider.dart` | Share leaflet |
| `lib/core/utils/share_position_origin.dart` | `sharePositionOrigin` |
| `test/unit/features/pdf_opening/share_pdf_test.dart` | Testes |
| `test/unit/features/playlists/playlist_share_actions_test.dart` | Testes |

**Breaking provável (v11+):** migração de `Share.share` / `Share.shareXFiles` estáticos para instância `SharePlus`. `SharePdf` já aceita `ShareXFilesFn` injetável — usar para facilitar testes.

### Critérios de aceite

- [ ] Share de PDF, playlist e leaflet funciona em dispositivo/simulador
- [ ] Política de prefetch respeita conectividade (`prefetch_network_policy_test`)
- [ ] `flutter test` verde nos arquivos listados

---

## Onda 3 — `go_router` 14 → 17

**Prioridade:** 4ª  
**Esforço:** médio | **Risco:** alto | **Benefício:** correções shell routing, API de redirect

### Arquivos principais

| Área | Arquivos |
|------|----------|
| Router | `lib/core/routing/app_router.dart` — `StatefulShellRoute.indexedStack`, 5 branches, sub-rota `leitor` |
| Navegação | `lib/core/routing/shell_navigation.dart`, `carousel_chips.dart`, `open_louvor_in_reader.dart`, `open_carousel_pdf_in_reader.dart`, `pdf_reader_screen.dart`, `playlist_list_tile.dart` |
| Deep links | `lib/features/app_shell/presentation/widgets/deep_link_listener.dart` |
| Testes widget | `deep_link_listener_test.dart`, `carousel_chips_test.dart`, `home_search_test.dart`, `pdf_offline_error_ui_test.dart`, `louvor_card_share_save_test.dart`, `playlist_list_tile_test.dart` |

### Fluxos críticos (regressão)

```text
DeepLinkListener → GoRouter → StatefulShellRoute
                                    ├── Home + /leitor (sub-rota)
                                    ├── Library (query sync UrlSyncParams)
                                    └── CarouselChips → context.go
```

### Estratégia

1. Ler changelogs de **15, 16 e 17** em sequência.
2. Preferir upgrade incremental (14→15→16→17) se um salto único gerar muitos breaks.
3. Preservar: `goToShellDestination` usa `context.go`, nunca `push` (comentário em `shell_navigation.dart`).

### Critérios de aceite

- [ ] Deep links UC-14 funcionam
- [ ] Troca de abas na bottom bar (`goToShellDestination`)
- [ ] Abrir/fechar leitor via carousel e busca
- [ ] Query params da biblioteca (`materiais`, `arranjo`, paginação) preservados
- [ ] `flutter test` verde nos testes de routing listados

---

## Onda 4 — `flutter_riverpod` 2 → 3

**Prioridade:** 5ª (maior projeto)  
**Esforço:** alto | **Risco:** alto | **Benefício:** API moderna, remove `state_notifier`, prepara `riverpod_generator`

### Superfície no repositório (jun/2026)

| Métrica | Valor |
|---------|-------|
| Arquivos com Riverpod em `lib/` | ~70 |
| Classes `extends Notifier<` | ~25 |
| `StateNotifier` / `StateNotifierProvider` | **0** (favorável) |
| `@riverpod` / `riverpod_generator` | **0** |
| Testes com `ProviderContainer` / overrides | ~23 arquivos |

### Padrões em uso

- `Notifier` + `NotifierProvider`
- `FutureProvider.autoDispose.family` — ex.: `pdfReaderSessionProvider`
- `Provider.autoDispose` — ex.: `readerAdjacentPdfPrefetchProvider`
- `ref.listen`, `ref.watch`, `ref.read` em widgets `Consumer*`

### Áreas sensíveis

| Área | Providers / arquivos |
|------|---------------------|
| Leitor PDF | `pdf_reader_document_provider.dart`, `pdf_reader_displayed_page_provider.dart`, `reader_adjacent_pdf_prefetch_provider.dart` |
| Offline | `offline_providers.dart` (~15 providers), `offline_bulk_download_provider.dart` |
| Playlists | `playlists_provider.dart` (`PlaylistsNotifier`, ~580 linhas) |
| Carousel | `carousel_louvores_provider.dart`, `carousel_focused_index_provider.dart` |

### Conferir no changelog Riverpod 3

- Semântica de `ref.listen` e autoDispose
- Families e overrides em testes (`ProviderContainer`)
- Imports (`flutter_riverpod` vs `riverpod`)
- Remoção de dependência `state_notifier`

### `riverpod_generator` (opcional, PR separado)

Não incluir na Onda 4. Adotar só após Riverpod 3 estável, com spike em um provider isolado.

### Critérios de aceite

- [ ] `flutter test` suite completa verde
- [ ] Smoke manual: catálogo, offline bulk, carousel, leitor, share playlist
- [ ] Nenhum import legado de APIs removidas no Riverpod 3

---

## Matriz de risco (ondas)

| Onda | Risco principal | Mitigação |
|------|-----------------|-----------|
| 1-A | Novos lints quebram CI | Corrigir incrementalmente; não desabilitar em massa |
| 1-B | `build_runner` incompatível com `isar_plus` | Validar diff `.g.dart`; smoke Isar |
| 2 | Share sheet quebrado em iOS/Android | Testes unitários + smoke manual share |
| 2 | Enum `ConnectivityResult` alterado | Portas já centralizadas; atualizar `switch` |
| 3 | Shell route / deep link quebrados | Testes widget + checklist UC-14 |
| 3 | Sub-rota `/leitor` perde estado carousel | Testar `carousel_chips_test` |
| 4 | Regressão estado global | PR isolado; smoke offline + leitor |
| 4 | Overrides de teste desatualizados | Rodar suite completa antes de merge |

---

## Comandos úteis para auditoria

```bash
# Pacotes desatualizados (inclui flag isDiscontinued)
flutter pub outdated

# Versão Flutter/Dart
flutter --version

# Análise estática
flutter analyze

# Suite de testes
flutter test
```

---

## Referências

- [MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md) — migrações nativas SPM (concluídas)
- [AGENT_PIPELINE.md](AGENT_PIPELINE.md) — fluxo QA/OpSec/Perf após cada PR
- [ADR-001](adr/ADR-001-isar-storage.md) — `isar_plus` + `build_runner`
- [flutter_lints](https://pub.dev/packages/flutter_lints/changelog)
- [build_runner](https://pub.dev/packages/build_runner/changelog)
- [connectivity_plus](https://pub.dev/packages/connectivity_plus/changelog)
- [share_plus](https://pub.dev/packages/share_plus/changelog)
- [go_router](https://pub.dev/packages/go_router/changelog)
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod/changelog)
