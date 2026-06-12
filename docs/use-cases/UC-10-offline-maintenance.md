# UC-10 — Manutenção offline

| Campo | Valor |
|-------|-------|
| **ID** | UC-10 |
| **Feature** | `offline` |
| **Prioridade** | Alta |
| **Ator** | Usuário |

## Pré-condições

Modo offline configurado

## Fluxo principal

Stats por categoria; baixar faltantes; limpar cache; migração.

## Fluxos alternativos

Stats podem dessincronizar (lição PWA)

## Pós-condições

Cache consistente com índice Isar

## Regras de negócio

Lookup O(1) via OfflinePdfIndex

## Componentes Flutter alvo

GetOfflineStatsByCategory, ClearOfflineCache

## Dependências

UC-09

## Use case Dart

`lib/features/offline/domain/usecases/` — ver FEATURE_INDEX.md
