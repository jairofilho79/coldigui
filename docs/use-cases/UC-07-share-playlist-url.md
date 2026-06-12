# UC-07 — Compartilhar playlist via URL

| Campo | Valor |
|-------|-------|
| **ID** | UC-07 |
| **Feature** | `playlists` |
| **Prioridade** | Média |
| **Ator** | Usuário |

## Pré-condições

Playlist salva

## Fluxo principal

1. Clica Share. 2. URL /?sharepdfs=id1,id2&sharename=Nome. 3. Share API ou clipboard. 4. Destinatário importa.

## Fluxos alternativos

Playlist salva automaticamente no destino

## Pós-condições

Deep link funcional

## Regras de negócio

share_plus no Flutter

## Componentes Flutter alvo

GeneratePlaylistShareUrl, ImportSharedPlaylistFromUrl

## Dependências

UC-06, UC-14

## Use case Dart

`lib/features/playlists/domain/usecases/` — ver FEATURE_INDEX.md
