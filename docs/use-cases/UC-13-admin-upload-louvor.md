# UC-13 — Upload admin de louvor

| Campo | Valor |
|-------|-------|
| **ID** | UC-13 |
| **Feature** | `admin` |
| **Prioridade** | Fora do MVP |
| **Ator** | Administrador |

## Pré-condições

JWT válido

## Fluxo principal

POST /api/upload-louvor com PDF base64 + metadata → R2 + manifest.

## Fluxos alternativos

—

## Pós-condições

Louvor publicado

## Regras de negócio

FeatureFlags.enableAdminUpload=false

## Componentes Flutter alvo

UploadLouvorAdmin (stub)

## Dependências

—

## Use case Dart

`lib/features/admin/domain/usecases/` — ver FEATURE_INDEX.md
