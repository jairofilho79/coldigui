# UC-12 — Atualizar catálogo

| Campo | Valor |
|-------|-------|
| **ID** | UC-12 |
| **Feature** | `catalog` |
| **Prioridade** | Média |
| **Ator** | Sistema / usuário |

## Pré-condições

App iniciado

## Fluxo principal

Poll checksum sha256; refresh manual na biblioteca; retry 4x backoff.

## Fluxos alternativos

—

## Pós-condições

Catálogo atualizado em Isar

## Regras de negócio

Automático + manual

## Componentes Flutter alvo

PollManifestChecksum, ForceRefreshCatalog

## Dependências

UC-01, UC-03

## Use case Dart

`lib/features/catalog/domain/usecases/` — ver FEATURE_INDEX.md
