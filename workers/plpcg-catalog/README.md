# plpcg-catalog — Worker + D1

API read-only do catálogo PLPCG para o app Flutter coldigui.

## Endpoints

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/catalog/louvores` | Array JSON de louvores (`groupId` incluído) |
| `GET` | `/api/catalog/checksum` | SHA-256 hex (`204` se `If-None-Match` bater) |

## Setup local

```bash
cd workers/plpcg-catalog
npm install

# Na raiz do repo:
python3 scripts/seed_d1_louvores.py

npm run db:migrate:local
npx wrangler d1 execute plpcg-catalog --local --file seed/001_louvores.sql
npm run dev
```

Teste: `curl http://127.0.0.1:8787/api/catalog/checksum`

Flutter local: `dart_defines/plpcg.dev.json` com `PLPCG_API_BASE_URL=http://127.0.0.1:8787`.

## Deploy remoto

1. `wrangler login`
2. `wrangler d1 create plpcg-catalog` — copiar `database_id` para `wrangler.jsonc`
3. `npm run db:migrate:remote`
4. `python3 ../../scripts/seed_d1_louvores.py`
5. `npx wrangler d1 execute plpcg-catalog --remote --file seed/001_louvores.sql`
6. `npm run deploy`

Após deploy, validar:

```bash
curl -s https://plpcg.com/api/catalog/checksum
curl -s https://plpcg.com/api/catalog/louvores | jq 'length'  # 4627
```
