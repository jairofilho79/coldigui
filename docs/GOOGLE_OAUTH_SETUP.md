# Setup Google OAuth (login PLPCG)

Checklist operacional para o Client ID Web usado pelo Flutter Web e pelo Worker `plpcg-catalog`.

## 1. Google Cloud Console

1. Abra [Google Cloud Console](https://console.cloud.google.com/) e crie/selecione o projeto (ex.: `plpcg-app`).
2. **APIs e serviços → Tela de consentimento OAuth**
   - Tipo: **Externo**
   - Nome do app, e-mail de suporte, logo (opcional)
   - Domínios autorizados: `plpcg.com` (e `plpcjf.org` se aplicável)
   - Política de privacidade (URL pública)
   - Escopos: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`
   - Para abrir a **todas as contas Google**: **Publishing status → In production**
3. **Credenciais → Criar → ID do cliente OAuth → Aplicativo da Web**
   - Nome: `PLPCG Web`
   - Origens JavaScript autorizadas:
     - `https://v2.plpcg.com`
     - `https://plpcg-v2.pages.dev`
     - `http://localhost:8080`
   - URIs de redirecionamento (se usar redirect):
     - `https://v2.plpcg.com`
     - `https://v2.plpcg.com/`
     - `http://localhost:8080`
4. Copie o **Client ID** (`….apps.googleusercontent.com`). Não use Client Secret no app nem no Worker deste fluxo.

## 2. Cloudflare Worker

```bash
cd workers/plpcg-catalog
npx wrangler secret put GOOGLE_CLIENT_ID_WEB
# colar o mesmo Client ID Web
```

Dev local do Worker — `.dev.vars` (não commitado):

```
GOOGLE_CLIENT_ID_WEB=xxxxx.apps.googleusercontent.com
```

A secret do Wrangler **não** é legível depois de salva e **não** entra no build Flutter. O Worker só usa para validar o `id_token`.

## 3. Flutter (`dart_defines/private.json`)

Arquivo **gitignored**. Modelo: `dart_defines/private.json.example`.

```json
{
  "GOOGLE_CLIENT_ID_WEB": "xxxxx.apps.googleusercontent.com"
}
```

`scripts/web_build.sh` e `web_deploy.sh` aplicam automaticamente `private.json` se existir (além de `plpcjf.json`).

Dev manual:

```bash
flutter run -d chrome \
  --dart-define-from-file=dart_defines/plpcg.dev.json \
  --dart-define-from-file=dart_defines/private.json
```

## 4. Validação rápida

1. `npm run db:migrate:local` / `db:migrate:remote` (tabela `users`)
2. `npm run deploy` (rotas `/api/auth/*` + secret)
3. `./scripts/web_build.sh` (precisa de `private.json` com Client ID)
4. Login em `/perfil` → linha em D1 `users` com `google_sub`
