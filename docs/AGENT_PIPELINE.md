# Agent Pipeline — PLPCG Flutter

## Fluxo completo

```text
Refinement → Development → QA → OpSec → Performance → Docs Creator
```

## Skills

| Agente | Skill | Invocação |
|--------|-------|-----------|
| Refinement | `plpcg-uc-refinement` | `/plpcg-uc-refinement UC-11` |
| Development | `plpcg-feature-dev` | `/plpcg-feature-dev UC-11` |
| QA | `plpcg-qa-engineer` | `/plpcg-qa-engineer UC-11` |
| OpSec | `plpcg-opsec-reviewer` | automático via hook |
| Performance | `plpcg-performance-auditor` | automático via hook |
| Docs | `plpcg-docs-creator` | automático no `stop` |

## Hooks (`.cursor/hooks.json`)

| Evento | Script | Budget |
|--------|--------|--------|
| `sessionStart` | `session-plpcg-context.sh` | reseta contador |
| `beforeSubmitPrompt` | `dispatch-uc-refinement.sh` | — |
| `subagentStart` | `guard-subagent-policy.sh` | — |
| `subagentStop` | `chain-qa-after-dev.sh` | 1 loop |
| `subagentStop` | `chain-opsec-after-qa.sh` | 1 loop |
| `subagentStop` | `chain-perf-after-opsec.sh` | 1 loop |
| `stop` | `flutter-analyze-stop.sh` | 1 loop (+ docs) |

## Limite de loops (ADR-003)

**Máximo 5 loops por sessão.** Contador em `.cursor/hooks/.loop-state`.

Distribuição: QA(1) + OpSec(1) + Perf(1) + stop(1) + margem QA(1) = 5.

Ao atingir o teto, hooks retornam `{}` sem `followup_message`.

## UC-13

Fora do MVP. OpSec varre secrets em todo o projeto; revisão JWT só quando `FeatureFlags.enableAdminUpload=true`.

## Documentação de referência

| Documento | Uso |
|-----------|-----|
| [FEATURE_INDEX.md](features/FEATURE_INDEX.md) | Índice de features, APIs públicas e status MVP |
| [LOUVOR_GROUPING.md](features/LOUVOR_GROUPING.md) | Agrupamento `groupId` — spec + status implementação (app jun/2026; manifest remoto pendente) |
| [docs/use-cases/](use-cases/) | UCs 01–14 |
| [MAPEAMENTO_PLPCG_FLUTTER.md](../MAPEAMENTO_PLPCG_FLUTTER.md) | Mapeamento PWA → Flutter |
| [MIGRATION_NATIVE_DEPS.md](MIGRATION_NATIVE_DEPS.md) | Migrações de deps nativas (SPM) — Fases A/B/C concluídas |
| [DEP_UPGRADE_BACKLOG.md](DEP_UPGRADE_BACKLOG.md) | Upgrades major Dart/Flutter (lints, build_runner, plus_plugins, go_router, riverpod) |
