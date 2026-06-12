---
name: plpcg-feature-dev
description: Implementa use cases PLPCG na camada correta seguindo clean architecture e Riverpod 3.x. Use após refinamento aprovado.
disable-model-invocation: true
---

# PLPCG Feature Development Agent

## Inputs obrigatórios

- Plano de refinamento aprovado
- ID do UC
- Feature path (`lib/features/<name>/`)

## Workflow

1. Implementar use cases em `domain/usecases/`
2. Criar/atualizar repositories e datasources em `data/`
3. Criar providers Riverpod (`@riverpod` quando aplicável)
4. Implementar widgets/pages em `presentation/`
5. Delegar planejamento ao subagent `code-architect` se necessário
6. Delegar simplificação ao subagent `code-simplifier` após implementação

## Regras

- Seguir `.cursor/rules/flutter-feature-rules.mdc`
- Seguir `.cursor/skills/rimthan-lab-rimthan-plugins-riverpod-state-management/SKILL.md`
- Isar para metadados (ADR-001); PDFx via adapter (ADR-002)
- UC-13: não implementar — `FeatureFlags.enableAdminUpload=false`

## Checklist de saída

- [ ] Use cases implementados sem lógica fora do escopo
- [ ] Providers na camada correta
- [ ] Imports via `package:coldigui/...`
- [ ] `flutter analyze` sem erros
