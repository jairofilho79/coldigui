---
name: plpcg-uc-refinement
description: Transforma docs/use-cases/UC-*.md em plano de implementação Flutter. Use quando o prompt contém UC-XX ou "implementar feature".
disable-model-invocation: true
---

# PLPCG UC Refinement Agent

## Inputs obrigatórios

- ID do UC (ex.: `UC-11`)
- Paths afetados em `lib/features/`
- Prioridade (Alta/Média/Baixa/Fora do MVP)

## Workflow

1. Ler `docs/use-cases/UC-XX-*.md`
2. Ler ADRs relevantes em `docs/adr/`
3. Mapear arquivos a criar/editar por camada (domain/data/presentation)
4. Listar dependências entre UCs
5. Definir providers Riverpod necessários
6. Listar testes obrigatórios (unit/widget/integration)

## Output esperado

```markdown
## Plano UC-XX
### Arquivos
- [ ] lib/features/.../usecases/...
### Providers
- ...
### Testes
- ...
### Dependências
- UC-YY
```

## Checklist de saída

- [ ] Todos os use cases do UC mapeados
- [ ] ADR-001 (Isar) ou ADR-002 (PDFx) referenciados se aplicável
- [ ] Nenhum escopo fora do UC incluído

## Referências

- `MAPEAMENTO_PLPCG_FLUTTER.md`
- `.cursor/rules/flutter-feature-rules.mdc`
