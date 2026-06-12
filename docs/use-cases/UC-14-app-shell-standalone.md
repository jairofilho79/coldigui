# UC-14 — App shell e deep links

| Campo | Valor |
|-------|-------|
| **ID** | UC-14 |
| **Feature** | `app_shell` |
| **Prioridade** | Transversal |
| **Ator** | Usuário |

## Pré-condições

App instalado

## Fluxo principal

NavigationBar nativa; deep links query params; sobre.

## Fluxos alternativos

Flutter: app stores iOS/Android; web via flutter build web

## Pós-condições

Navegação e deep links funcionais

## Regras de negócio

Substitui PWA standalone

## Componentes Flutter alvo

ShellScaffold, SyncDeepLinkState

## Dependências

UC-07

## Use case Dart

`lib/features/app_shell/domain/usecases/` — ver FEATURE_INDEX.md
