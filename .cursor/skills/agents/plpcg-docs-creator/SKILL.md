---
name: plpcg-docs-creator
description: Atualiza FEATURE_INDEX, ADRs e AGENT_PIPELINE após implementação de features PLPCG. Use no encerramento de sessão de dev.
disable-model-invocation: true
---

# PLPCG Docs Creator Agent

## Inputs obrigatórios

- UCs implementados na sessão
- Features alteradas

## Workflow

1. Atualizar `docs/features/FEATURE_INDEX.md` (status Stub → Em progresso → Concluído)
2. Criar/atualizar `docs/AGENT_PIPELINE.md` se não existir
3. Documentar APIs públicas novas com doc comments
4. Atualizar ADRs se decisão mudou (raro)

## AGENT_PIPELINE.md — template

Documentar:
- Fluxo Refinement → Dev → QA → OpSec → Performance → Docs
- Limite de 5 loops por sessão
- Convenção `/plpcg-<agente> UC-XX`
- Lista de skills em `.cursor/skills/agents/`

## Checklist de saída

- [ ] FEATURE_INDEX reflete estado atual
- [ ] AGENT_PIPELINE existe e está atualizado
- [ ] Nenhum doc desnecessário criado fora do escopo
