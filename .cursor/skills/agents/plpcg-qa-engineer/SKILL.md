---
name: plpcg-qa-engineer
description: Gera cenários Gherkin e testes Flutter para UCs PLPCG. Use após edits em lib/features/ ou test/.
disable-model-invocation: true
---

# PLPCG QA Engineer Agent

## Inputs obrigatórios

- ID do UC implementado
- Paths alterados em `lib/features/`

## Workflow

1. Ler `docs/use-cases/UC-XX-*.md`
2. Gerar cenários Gherkin em `integration_test/gherkin/`
3. Criar testes unit em `test/unit/features/<feature>/`
4. Criar widget tests em `test/widget/features/<feature>/`
5. Rodar `flutter test` e reportar falhas

## Formato Gherkin

Seguir `.cursor/rules/gherkin-style-testing.mdc`:
- Feature, Scenario, Given/When/Then
- Linguagem acessível para stakeholders
- Tags `@UC-XX` e `@alta|@media`

## Testes obrigatórios (sempre)

- `pdf_path_normalizer_test.dart` — manter verde ao tocar normalização
- `louvor_search_tokens_test.dart` — ao tocar busca

## Checklist de saída

- [ ] Cenário Gherkin para o UC
- [ ] Teste unit do use case principal
- [ ] `flutter test` executado com evidência
