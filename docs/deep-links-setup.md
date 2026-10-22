# Deep Links — PLPCG Flutter

Configuração de Universal Links (iOS) e App Links (Android) para import automático de playlists ao abrir URLs `https://plpcg.com/?sharepdfs=...&sharename=...` (formato legado) ou `https://plpcg.com/?s=...&n=...` (formato curto por `shortId`, spec short-id-share).

**App (Fase 4.5):** `SyncDeepLinkState` + `DeepLinkListener` + `app_links`  
**Servidor:** arquivos abaixo devem ser publicados no domínio `plpcg.com`.

---

## iOS — Universal Links

### 1. Associated Domains (já no app)

- Arquivo: [`ios/Runner/Runner.entitlements`](../ios/Runner/Runner.entitlements)
- Entitlement: `applinks:plpcg.com`
- URL scheme fallback dev: `plpcg://` em [`ios/Runner/Info.plist`](../ios/Runner/Info.plist)

### 2. Apple App Site Association (AASA)

Publicar em:

```text
https://plpcg.com/.well-known/apple-app-site-association
```

**Sem extensão `.json`**, `Content-Type: application/json`.

Exemplo (substituir `TEAM_ID` pelo Apple Team ID e confirmar bundle ID):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "PX8Z8276X5.com.plpcg.app",
        "paths": ["*"]
      }
    ]
  }
}
```

| Campo | Valor atual do projeto |
|-------|------------------------|
| Team ID | `PX8Z8276X5` (Xcode `DEVELOPMENT_TEAM`) |
| Bundle ID | `com.plpcg.app` |

### 3. Validação iOS

```bash
# Formato atual por praise (?p=...&n=...)
xcrun simctl openurl booted "https://plpcg.com/?p=0a1-fff&n=Demo"

# Louvor individual (/louvor/:id)
xcrun simctl openurl booted "https://plpcg.com/louvor/0a1"

# Simulador com app instalado (formato legado)
xcrun simctl openurl booted "https://plpcg.com/?sharepdfs=TEST&sharename=Demo"

# Formato curto antigo (?s=...&n=...)
xcrun simctl openurl booted "https://plpcg.com/?s=0000&n=Demo"

# Scheme customizado (sem AASA)
xcrun simctl openurl booted "plpcg:///?p=0a1-fff&n=Demo"
```

Settings → Developer → Universal Links (diagnóstico).

---

## Android — App Links (futuro)

Quando o target Android existir, publicar:

```text
https://plpcg.com/.well-known/assetlinks.json
```

Exemplo:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.plpcg.app",
      "sha256_cert_fingerprints": ["SHA256_DO_CERTIFICADO_DE_ASSINATURA"]
    }
  }
]
```

Obter SHA-256:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

`AndroidManifest.xml` — `intent-filter` com `android:autoVerify="true"` para `https://plpcg.com`.

---

## Comportamento esperado no app

1. OS entrega URI ao `app_links`
2. `DeepLinkListener` detecta `sharepdfs` + `sharename` (legado) ou `s` + `n`
   (formato curto por `shortId`)
3. `SyncDeepLinkState` → `ImportSharedPlaylistFromUrl` (sem diálogo) — no
   formato curto, aguarda o catálogo para resolver `shortId → pdfId`
4. Carousel carregado + playlist persistida no Isar
5. Navegação para `/` sem params de share + snackbar `playlistImported`

Import manual (FAB em Listas) continua com confirmação de substituição do carousel.

---

## Referências

- [FEATURE_INDEX.md](features/FEATURE_INDEX.md) — APIs `SyncDeepLinkState`, `DeepLinkListener`
- [MVP Roadmap.md](MVP%20Roadmap.md) — Fase 4.5
- [`DeepLinkConfig`](../lib/core/constants/deep_link_config.dart) — domínio/scheme
