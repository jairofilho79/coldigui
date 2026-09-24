# UC-07 — Compartilhar playlist via URL

| Campo | Valor |
|-------|-------|
| **ID** | UC-07 |
| **Feature** | `playlists` |
| **Prioridade** | Média |
| **Ator** | Usuário |

## Pré-condições

Playlist salva ou seleção ativa no carousel; cada entrada tem um praise com `shortId` no catálogo local (senão o share falha e dispara sync).

## Fluxo principal

1. Toca Share (barra do carousel, tile da lista ou card ⋮).
2. O app resolve cada entrada → praise pelo catálogo local, junta os `shortId`s únicos e monta `https://v2.plpcg.com/?p=<shortIds separados por ->&n=<nome>` (`GeneratePlaylistShareUrl`).
3. Share API ou clipboard; folheto sempre com QR.
4. Destinatário importa: cada praise → material preferido (`preferredMaterialForGroup`) — com login e favorito presente, o favorito; senão PDF principal → único áudio → primeiro adicionável. Praise sem nada adicionável é saltado.

## Fluxos alternativos

- Playlist salva automaticamente no destino (nova playlist, não faz merge por nome).
- Índice local vazio no destino: o import espera o sync (timeout → mensagem de link inválido).
- Token `p` desconhecido: ignorado com log; se nenhum resolver, mensagem de link inválido.
- Link antigo (`?s=`, `sharepdfs`/`shareitems`/`shareaudios`/`sharename`): mostra `playlistShareLegacyLinkUnsupported` («Este link é de uma versão antiga e já não abre»); nada é importado.

## Pós-condições

Deep link funcional; sem gate por fonte — qualquer lista compartilha (o gate Coldigom foi pago em 2026-09-23).

## Regras de negócio

`share_plus` no Flutter. Link por **praise**, não por material: `p` = `shortId`s de praise (`[0-9a-f]{3,8}`, sempre string) separados por `-`, na ordem da lista, repetidos permitidos; `n` = nome da lista, obrigatório. Origem fixa `ShareConfig.appOrigin` (`https://v2.plpcg.com`), não mais `AppConfig.apiBaseUrl`. Ver spec [fim da fonte PLPCG](../superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md) §4.

## Componentes Flutter alvo

GeneratePlaylistShareUrl, ImportSharedPlaylistFromUrl, buildPraiseShareLocation, buildPraiseShareUrl, parsePlaylistShareParams

## Dependências

UC-06, UC-14

## Use case Dart

`lib/features/playlists/domain/usecases/` — ver FEATURE_INDEX.md
