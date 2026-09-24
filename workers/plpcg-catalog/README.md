# plpcg-catalog — Worker + D1

API do catálogo PLPCG (público), autenticação Google e sync de playlists.

## Endpoints

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|
| `GET` | `/api/catalog/louvores` | Não | Array JSON de louvores (`groupId` e `shortId` incluídos) |
| `GET` | `/api/catalog/checksum` | Não | SHA-256 hex (`204` se `If-None-Match` bater) |
| `POST` | `/api/auth/session` | Bearer Google `id_token` | Valida JWT, UPSERT em `users`, cria linha em `user_sessions` e devolve perfil + `sessionToken` (60 d deslizantes) |
| `DELETE` | `/api/auth/session` | Bearer `sess_…` | Revoga a sessão (204, idempotente) |
| `GET` | `/api/auth/introspect` | Bearer `sess_…` (só sessão) | Servidor-a-servidor para o coldigom-api: `{ userId, email, name, username }` sem renovar a sessão |
| `PUT` | `/api/auth/username` | Bearer | Define username único (uma vez) |
| `GET` | `/api/social/users?q=` | Bearer | Busca usernames (conta listas públicas; `@` opcional) |
| `GET` | `/api/social/users/:username/playlists` | Bearer | Listas públicas do perfil |
| `GET` | `/api/playlists` | Bearer | Lista playlists salvas do usuário (`deleted_at IS NULL`) |
| `GET` | `/api/playlists/:id` | Bearer | Uma playlist |
| `PUT` | `/api/playlists/:id` | Bearer | Upsert (last-write-wins por `updatedAt`) |
| `DELETE` | `/api/playlists/:id` | Bearer | Soft delete |
| `GET` | `/api/audio-flags` | Bearer | Lista marcadores de áudio do usuário |
| `PUT` | `/api/audio-flags/:id` | Bearer | Upsert (last-write-wins por `updatedAt`) |
| `DELETE` | `/api/audio-flags/:id` | Bearer | Soft delete |
| `GET` | `/api/material-kind-prefs` | Bearer | Material kinds favoritos do usuário (`204` se nunca salvou) |
| `PUT` | `/api/material-kind-prefs` | Bearer | Upsert do documento (`{ kindIds ≤ 5, updatedAt }`; `409` devolve o remoto mais novo) |

Todas as rotas com Bearer aceitam `sess_…` (sessão do Worker, `user_sessions`) ou o `id_token` do Google. Spec: `docs/superpowers/specs/2026-09-13-worker-session-persistence-design.md`.

Setup OAuth: [docs/GOOGLE_OAUTH_SETUP.md](../../docs/GOOGLE_OAUTH_SETUP.md).
Spec sync: [docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md](../../docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md).

> O catálogo Coldigom não passa por este Worker: o app lê `GET https://coldigom-api.jairofilho79.workers.dev/api/plpcg/catalog` (ETag/304) diretamente — ver `patches/coldigom-api-plpcg-catalog.patch`.

## Lista ao Vivo (Durable Object `LiveRoom`)

| Rota | Auth | O quê |
|---|---|---|
| `POST /api/live/room` | Bearer | Cria-ou-devolve a sala permanente do usuário: `{ code, url, ownerName }` |
| `POST /api/live/room/regenerate` | Bearer | Novo código; quem tinha o antigo recebe `ended{retired}` e `4003` |
| `GET /api/live/:code/ws` | — (papel no `hello`) | Upgrade WebSocket, encaminhado ao DO `LIVE.idFromName(code)` |
| `GET /ao-vivo/:code` | — | `302 https://plpcg.com/?live=<code>` |

Protocolo e regras: `docs/superpowers/specs/2026-09-12-lista-ao-vivo-design.md` §5 (Fase 1: `hello`, `start`, `set`, `end` → `room`, `snapshot`, `presence`, `ack`, `ended`, `error`). A lógica está em `src/live/room_core.ts` (testada com fakes); `src/live/live_room.ts` é a casca do DO. As rotas HTTP estão em `src/live/handlers.ts`, e a autenticação do token `hello` (`sess_…` ou Google JWT) é resolvida em `src/live/authenticate_token.ts`.

Deploy: `npm run db:migrate:remote` (migration `0013_create_live_rooms.sql`) **antes** de `npm run deploy` — o primeiro deploy aplica a migration `live-v1` (`new_sqlite_classes`) do wrangler. Verificar binding com `npx wrangler deploy --dry-run` listando `LIVE` → `LiveRoom`. Um deploy fecha todos os WebSockets abertos; os clientes religam sozinhos com jitter.

## Migração única de ids legados das playlists (set/2026)

Spec: `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md` §6.3. Troca, em `user_playlists.items` e `pdf_ids`, os ids de PDF do manifesto PLPCG pelos ids coldigom (via `POST /api/plpcg/crosswalk`), com `version + 1` e `updated_at` intacto. Desconhecidos ficam (o app mostra-os indisponíveis). `short_links` não é migrado.

**Só depois do deploy do app novo e com pedido do dono.**

Um import `--remote` (`wrangler d1 execute … --file`) deixa o D1 indisponível para todo mundo enquanto roda — escolher uma hora de baixo tráfego.

Ponto de restauro antes da escrita real:

```bash
npx wrangler d1 time-travel info plpcg-catalog
```

Anotar o `bookmark` impresso. Restauro, só se algo der errado:

```bash
npx wrangler d1 time-travel restore plpcg-catalog --bookmark=<bookmark>
```

(desfaz também qualquer escrita posterior no D1, não só a desta migração.)

```bash
cd workers/plpcg-catalog
export COLDIGOM_API_BASE_URL=https://coldigom-api.jairofilho79.workers.dev
npm run migrate:legacy-ids -- --dry-run --remote   # diff + contagem, não grava
npm run migrate:legacy-ids -- --remote             # grava; SQL e relatório em scripts/out/
```

`--local`/`--remote` é sempre obrigatório (sem default) — evita que um `--dry-run` esquecido do `--local` vire escrita real. Pode correr de novo: linhas já normalizadas não mudam, e uma linha que mudou entre a leitura e a escrita (guarda `AND version = N`) fica marcada como `skipped` no relatório e a saída avisa "rode de novo". O normalizador do app (`NormalizeLegacyMaterialIds`) cobre o que escapar.

## Setup local

```bash
cd workers/plpcg-catalog
npm install
cp .dev.vars.example .dev.vars   # preencher GOOGLE_CLIENT_ID_WEB

# Na raiz do repo:
python3 scripts/seed_d1_louvores.py

npm run db:migrate:local
npx wrangler d1 execute plpcg-catalog --local --file seed/001_louvores.sql
npm run dev
```

Teste catálogo: `curl http://127.0.0.1:8787/api/catalog/checksum`

Flutter local: `dart_defines/plpcg.dev.json` com `PLPCG_API_BASE_URL=http://127.0.0.1:8787` e `GOOGLE_CLIENT_ID_WEB`.

## Deploy remoto

1. `wrangler login`
2. `npx wrangler secret put GOOGLE_CLIENT_ID_WEB`
3. `npm run db:migrate:remote`
4. Seed do catálogo: **só D1 local** — no remoto o catálogo vive no admin;
   nunca rodar `scripts/seed_d1_louvores.py` (nem `wrangler d1 execute --remote`
   com o SQL gerado por ele) contra o remoto depois da 0011.
5. `npm run deploy`

Faça o deploy **só depois** de `npm run db:migrate:remote` confirmar a
`0011_add_louvores_short_id.sql` aplicada — o SELECT projeta `short_id` e
falha sem a coluna.

Após deploy, validar:

```bash
curl -s https://plpcg.com/api/catalog/checksum
curl -s https://plpcg.com/api/catalog/louvores | jq 'length'  # 4633 (set/2026)
```

## Migrations e o D1 compartilhado

O D1 `plpcg-catalog` também é usado pelo `plpcg-admin` (mesmo `database_id`). **Este Worker é o dono das migrations remotas** (`npm run db:migrate:remote`). O admin mantém em `worker/migrations/` só o que precisa para o D1 local dele; a `0011_add_louvores_short_id.sql` daqui tem um espelho lá (`0003_add_short_id.sql`) que **não** deve ser aplicado no remoto.
