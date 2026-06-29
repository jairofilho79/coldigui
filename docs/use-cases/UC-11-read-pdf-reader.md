# UC-11 — Ler PDF no leitor

| Campo | Valor |
|-------|-------|
| **ID** | UC-11 |
| **Feature** | `pdf_reader` |
| **Prioridade** | Alta |
| **Ator** | Usuário |

## Pré-condições

PDF disponível

## Fluxo principal

1. Abre /leitor. 2. Navega páginas. 3. Zoom. 4. Fullscreen. 5. Carousel no leitor.

## Fluxos alternativos

Offline: validação → download → retry → buscar online

## Pós-condições

PDF renderizado via pdfrx

## Regras de negócio

Preferências em SharedPreferences

## Componentes Flutter alvo

PdfReaderScreen, PdfrxViewerAdapter

## Dependências

UC-04, UC-05

## Use case Dart

`lib/features/pdf_reader/domain/usecases/` — ver FEATURE_INDEX.md
