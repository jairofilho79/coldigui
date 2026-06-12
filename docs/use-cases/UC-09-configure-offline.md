# UC-09 — Configurar modo offline (primeira vez)

| Campo | Valor |
|-------|-------|
| **ID** | UC-09 |
| **Feature** | `offline` |
| **Prioridade** | Alta |
| **Ator** | Usuário |

## Pré-condições

Rede disponível; espaço em disco

## Fluxo principal

1. Acessa offline. 2. Seleciona categorias. 3. Baixa ZIP. 4. Extrai PDFs. 5. OFFLINE_AVAILABLE=TRUE.

## Fluxos alternativos

Fases: fetching → extracting → storing → syncing

## Pós-condições

PDFs disponíveis offline

## Regras de negócio

Filesystem + índice Isar OfflinePdfIndex

## Componentes Flutter alvo

DownloadOfflinePackages, ExtractAndStorePdfs

## Dependências

UC-10, UC-04

## Use case Dart

`lib/features/offline/domain/usecases/` — ver FEATURE_INDEX.md
