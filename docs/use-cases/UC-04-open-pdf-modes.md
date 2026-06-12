# UC-04 — Abrir PDF (5 modos)

| Campo | Valor |
|-------|-------|
| **ID** | UC-04 |
| **Feature** | `pdf_opening` |
| **Prioridade** | Alta |
| **Ator** | Usuário |

## Pré-condições

Louvor selecionado

## Fluxo principal

Modos: leitor, newtab, online, share, save. Leitor: valida offline → navega /leitor.

## Fluxos alternativos

Share/save: blob cache ou rede. Newtab: offline-first.

## Pós-condições

PDF aberto no modo selecionado

## Regras de negócio

Modo padrão: leitor

## Componentes Flutter alvo

PdfViewerSelector, validate_pdf_availability

## Dependências

UC-11

## Use case Dart

`lib/features/pdf_opening/domain/usecases/` — ver FEATURE_INDEX.md
