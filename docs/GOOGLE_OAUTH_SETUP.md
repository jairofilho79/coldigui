# Setup Google OAuth (login PLPCG)

Checklist operacional para o Client ID Web, iOS e Android usado pelo Flutter e pelo Worker `plpcg-catalog`.

## 1. Google Cloud Console

1. Abra [Google Cloud Console](https://console.cloud.google.com/) e crie/selecione o projeto (ex.: `plpcg-app`).
2. **APIs e serviços → Tela de consentimento OAuth**
   - Tipo: **Externo**
   - Nome do app, e-mail de suporte, logo (opcional)
   - Domínios autorizados: `plpcg.com` (e `plpcjf.org` se aplicável)
   - Política de privacidade (URL pública)
   - Escopos: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`
   - Para abrir a **todas as contas Google**: **Publishing status → In production** (se em Testing, adicione as contas em *Test users*)
3. **Credenciais → Criar → ID do cliente OAuth → Aplicativo da Web**
   - Nome: `PLPCG Web`
   - Origens JavaScript autorizadas:
     - `https://v2.plpcg.com`
     - `https://plpcg-v2.pages.dev`
     - `http://localhost:8080`
   - URIs de redirecionamento autorizados (**obrigatórios** — o login web é por redirect OIDC):
     - `https://v2.plpcg.com/`
     - `http://localhost:8080/`
     - `http://127.0.0.1:8080/` (opcional — só se usar esse host em vez de `localhost` no dev local)
     - (barra final obrigatória: `redirect_uri` é `<origin>/`)
   - Copie o **Client ID Web** (`….apps.googleusercontent.com`).
4. **Credenciais → Criar → ID do cliente OAuth → iOS**
   - Nome: `PLPCG iOS`
   - Bundle ID: `com.plpcg.app`
   - Copie o **Client ID iOS** (`….apps.googleusercontent.com`) e o **Esquema de URL invertido (REVERSED_CLIENT_ID)** (`com.googleusercontent.apps.…`).
5. **Credenciais → Criar → ID do cliente OAuth → Android**
   - Nome: `PLPCG Android`
   - Nome do pacote: `com.plpcg.app`
   - Certificado SHA-1: obtido via `keytool` do keystore usado (veja seção 4).
   - *Nota:* O Android não precisa de um Client ID no Dart; ele usa o Client ID Web como `serverClientId` e valida a assinatura via Play Services.

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
  "GOOGLE_CLIENT_ID_WEB": "xxxxx.apps.googleusercontent.com",
  "GOOGLE_CLIENT_ID_IOS": "xxxxx.apps.googleusercontent.com"
}
```

`scripts/web_build.sh`, `scripts/ios_homolog_install.sh` e `scripts/android_homolog_install.sh` aplicam automaticamente `private.json` se existir.

## 4. Configuração Nativa por Plataforma

### iOS
1. No arquivo `ios/Runner/Info.plist`, adicione o esquema do `REVERSED_CLIENT_ID` sob `CFBundleURLTypes`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLName</key>
           <string>com.plpcg.app</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>plpcg</string>
               <string>com.googleusercontent.apps.XXXXXXXXXXXX-XXXXXXXXXXXXXXXX</string>
           </array>
       </dict>
   </array>
   ```
2. Adicione `"GOOGLE_CLIENT_ID_IOS"` em `dart_defines/private.json`.

### Android
1. Gere o fingerprint SHA-1 da chave de debug (ou release):
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
2. Cadastre o SHA-1 e o pacote `com.plpcg.app` no Google Cloud Console (tipo Android).
3. O código Flutter já passa automaticamente `serverClientId: AppConfig.googleClientIdWeb` para o Credential Manager do Android, garantindo que o token de retorno tenha a audiência esperada pelo Worker.

## 5. Validação rápida

1. `npm run db:migrate:local` / `db:migrate:remote` (tabela `users`)
2. `npm run deploy` (rotas `/api/auth/*` + secret)
3. `./scripts/web_build.sh` (precisa de `private.json` com Client ID)
4. Login em `/perfil` → linha em D1 `users` com `google_sub`

## Fluxo web: redirect OIDC (fluxo implícito)

Desde 2026-09 o botão web não usa o popup do Google Identity Services: ele
navega para `https://accounts.google.com/o/oauth2/v2/auth` com
`response_type=id_token`, `scope=openid email profile`, `nonce` e `state`
(csrf + rota de retorno). O Google volta para `<origem>/#id_token=…&state=…`;
o app captura o fragmento em `main()`, confere `csrf`/`nonce` e chama
`POST /api/auth/session` como antes. O Worker continua validando assinatura,
`aud` e `exp` — nada muda do lado dele.

Motivo: o popup exigia `Cross-Origin-Opener-Policy: same-origin-allow-popups`,
que desliga o isolamento cross-origin e deixa o skwasm single-thread. Com o
redirect, COOP é `same-origin` (ver `web/_headers`).

Consequências práticas:
- Dev local só funciona na origem cadastrada (`http://localhost:8080`).
- Previews `*.pages.dev` não têm login (origem não cadastrada — já era assim).
- Se o Google devolver o token numa janela que não iniciou o login (aba
  restaurada, navegador embutido do PWA iOS), o app mostra «Não conseguimos
  concluir o login» com o botão para tentar de novo naquele contexto.

Spec: `docs/superpowers/specs/2026-09-13-google-login-redirect-coop-design.md`.
