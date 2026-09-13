# Navegação: Listas · Pesquisar · Perfil — Design

**Data:** 2026-09-12
**Branch:** `feat/nav-listas-perfil` (a partir de `web/integration`)

## Motivação

A aba Social e a página Listas compartilham quase tudo (listas, importação,
sync, login). Duas entradas independentes na barra inferior não se justificam.
Listas volta para a barra no lugar de Social; Social vira **Listas públicas**,
acessível de dentro de Listas. Biblioteca sai da barra e entra no hub Perfil.

## Decisões

### D1 — Barra inferior / rail

Ordem, da esquerda para a direita: **Listas** · **Pesquisar** (logo PLPCG) ·
**Perfil**. Eventos continua na frente só quando `FF_EVENTS=true`.

- `AppTab { events, playlists, home, profile }`.
- `appTabsFor(flags)` = `[if (flags.events) events, playlists, home, profile]`.
- Ícone de Listas: `Icons.playlist_play`; rótulo `Listas`.
- `AppTab.library` e `AppTab.social` deixam de existir.

### D2 — Branch Listas

- Raiz `/listas` → `PlaylistsScreen` (com `StorageRequiredGate`, como hoje).
- Sub-rota `/listas/publicas` → `PublicPlaylistsScreen` (a antiga
  `SocialScreen`, renomeada; mesma pasta `lib/features/social/`). Registrada
  só quando `FF_SOCIAL=true`. A flag mantém o nome `social`; só muda o que
  ela liga/desliga.
- Entrada: botão **«Listas públicas»** (`Icons.public`) em `PlaylistsScreen`,
  numa linha própria logo abaixo do `PlaylistSyncErrorBanner`, alinhado à
  direita. Só aparece com `FF_SOCIAL=true`. Toque → `context.push('/listas/publicas')`.
- Em `/listas/publicas`, a `PlpcgPrimaryAppBar` mostra a seta de voltar
  (mesmo padrão das rotas imersivas): `pop()` se possível, senão
  `go('/listas')`.
- `/social` antigo redireciona para `/listas/publicas`.

### D3 — Branch Perfil

Rotas: `/perfil`, `/biblioteca`, `/offline`, `/sobre`. A URL `/biblioteca`
(com query params de filtro) não muda — `library_url_builder` e deep links
continuam válidos; só a branch dona da rota muda.

Tiles do hub Perfil, de cima para baixo: **Biblioteca**
(`Icons.library_books`) · **Offline** (`Icons.cloud_download`) · **Sobre**
(`Icons.info_outline`). O tile «Listas» sai.

### D4 — Textos

- Rótulo da aba: `Listas`. Título do browser em `/listas/publicas`:
  `Listas públicas`.
- l10n novo: `publicPlaylistsTitle` — pt `Listas públicas`, en `Public playlists`.
- l10n alterado: `socialSignInRequired` — pt `Entre com o Google para explorar
  as listas públicas.`, en `Sign in with Google to explore public playlists.`
- Docs (`///`) que citam «Social» como aba ou «Biblioteca» como aba são
  atualizados nos arquivos tocados.

## Fora de escopo

Layout interno de `PlaylistsScreen` e de `PublicPlaylistsScreen` além do
botão/título; comportamento do toque na aba já ativa; `PRODUCT.md`.
