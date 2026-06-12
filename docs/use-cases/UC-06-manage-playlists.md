# UC-06 — Gerenciar playlists salvas

| Campo | Valor |
|-------|-------|
| **ID** | UC-06 |
| **Feature** | `playlists` |
| **Prioridade** | Média |
| **Ator** | Usuário |

## Pré-condições

Carousel ou playlist existente

## Fluxo principal

Criar, renomear, favoritar, excluir, remover PDF, carregar no carousel, abrir 1º no leitor.

## Fluxos alternativos

Nome default: lista dd/mm/yyyy HH:mm:ss

## Pós-condições

Playlist persistida em Isar

## Regras de negócio

Modelo: id, nome, pdfIds[], createdAt, favorita

## Componentes Flutter alvo

PlaylistsScreen, CreatePlaylistFromCarousel

## Dependências

UC-05, UC-07

## Use case Dart

`lib/features/playlists/domain/usecases/` — ver FEATURE_INDEX.md
