# UC-05 — Montar seleção temporária (carousel)

| Campo | Valor |
|-------|-------|
| **ID** | UC-05 |
| **Feature** | `carousel` |
| **Prioridade** | Média |
| **Ator** | Usuário |

## Pré-condições

Louvores visíveis

## Fluxo principal

1. Clica + no card. 2. Adiciona chip. 3. Reordena drag. 4. Remove ou limpa.

## Fluxos alternativos

Salvar como playlist; gerar folheto

## Pós-condições

Carousel persistido em Isar

## Regras de negócio

Persistência via CarouselEntry (Isar)

## Componentes Flutter alvo

CarouselChips, AddLouvorToCarousel

## Dependências

UC-06, UC-08

## Use case Dart

`lib/features/carousel/domain/usecases/` — ver FEATURE_INDEX.md
