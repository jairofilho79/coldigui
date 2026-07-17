# plpcg-catalog — Worker + D1

API do catálogo PLPCG (público), autenticação Google e sync de playlists.

## Endpoints

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|
| `GET` | `/api/catalog/louvores` | Não | Array JSON de louvores (`groupId` incluído) |
| `GET` | `/api/catalog/checksum` | Não | SHA-256 hex (`204` se `If-None-Match` bater) |
| `POST` | `/api/auth/session` | Bearer Google `id_token` | Valida JWT, UPSERT em `users`, devolve perfil |
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

Setup OAuth: [docs/GOOGLE_OAUTH_SETUP.md](../../docs/GOOGLE_OAUTH_SETUP.md).
Spec sync: [docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md](../../docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md).

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
4. Seed do catálogo (se necessário) — ver passos anteriores
5. `npm run deploy`

Após deploy, validar:

```bash
curl -s https://plpcg.com/api/catalog/checksum
curl -s https://plpcg.com/api/catalog/louvores | jq 'length'  # 4627
```
