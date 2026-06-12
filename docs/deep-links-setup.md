# Deep Links — PLPCG Flutter

Configuração de Universal Links (iOS) e App Links (Android) para import automático de playlists ao abrir URLs `https://plpcg.com/?sharepdfs=...&sharename=...`.

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
        "appID": "PX8Z8276X5.com.example.coldigui",
        "paths": ["*"]
      }
    ]
  }
}
```

| Campo | Valor atual do projeto |
|-------|------------------------|
| Team ID | `PX8Z8276X5` (Xcode `DEVELOPMENT_TEAM`) |
| Bundle ID | `com.example.coldigui` |

### 3. Validação iOS

```bash
# Simulador com app instalado
xcrun simctl openurl booted "https://plpcg.com/?sharepdfs=TEST&sharename=Demo"

# Scheme customizado (sem AASA)
xcrun simctl openurl booted "plpcg:///?sharepdfs=TEST&sharename=Demo"
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
      "package_name": "com.example.coldigui",
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
2. `DeepLinkListener` detecta `sharepdfs` + `sharename`
3. `SyncDeepLinkState` → `ImportSharedPlaylistFromUrl` (sem diálogo)
4. Carousel carregado + playlist persistida no Isar
5. Navegação para `/` sem params de share + snackbar `playlistImported`

Import manual (FAB em Listas) continua com confirmação de substituição do carousel.

---

## Referências

- [FEATURE_INDEX.md](features/FEATURE_INDEX.md) — APIs `SyncDeepLinkState`, `DeepLinkListener`
- [MVP Roadmap.md](MVP%20Roadmap.md) — Fase 4.5
- [`DeepLinkConfig`](../lib/core/constants/deep_link_config.dart) — domínio/scheme
