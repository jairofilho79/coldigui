# Fase 5 — Validação de plugins web (coldigui)

**Branch:** `web/phase-5`  
**Base:** `web/phase-4e` (commit `2a66ffd`)  
**Data:** jul/2026

Validação de runtime dos plugins com suporte web parcial, conforme [WEB_BUILD_REFACTOR_PLAN.md](WEB_BUILD_REFACTOR_PLAN.md) Fase 5.

---

## Resumo

| Plugin | Status | Ação |
|---|---|---|
| `connectivity_plus` | **adjusted** | Fallback web para conexão não medida |
| `app_links` | **adjusted** | `DeepLinkListener` usa `Uri.base` na web |
| `wakelock_plus` | **ok** | Sem alteração — UC-09 bulk ativo na web (Fase 4 O3) |
| `pdfrx` / `pdfrx_engine` | **ok** | Assets WASM incluídos pelo pacote; modo single-thread sem COOP/COEP |
| `isar_plus` | **ok** | IndexedDB/WASM — schemas abrem no boot web |
| `shared_preferences` | **ok** | `localStorage` — sem ação |
| `dio`, `flutter_svg`, `go_router`, `flutter_riverpod` | **ok** | Sem bloqueios conhecidos |
| `archive` (fora offline ZIP stream) | **ok** | Decode de bytes web-safe |

---

## `connectivity_plus` (^7.2.0) — adjusted

**Comportamento web:** `ConnectivityPlusWebPlugin` mapeia `navigator.onLine` → `[ConnectivityResult.wifi]` ou `[ConnectivityResult.none]`. Sem distinção WiFi/celular.

**Problema:** `ConnectivityNetworkConnectionChecker` só tratava `wifi`/`ethernet`/`vpn` como não medidos. Tipos genéricos (`other`) bloqueariam prefetch WiFi-only na web se o plugin mudasse.

**Correção:** helper compartilhado `lib/core/network/connectivity_results.dart`:
- `connectivityHasUsableConnection` — usado por `ConnectivityDeviceConnectivity`
- `connectivityIsUnmetered` — fallback `kIsWeb`: qualquer resultado online exceto `mobile`/`none` conta como não medido

**Arquivos alterados:**
- `lib/core/network/connectivity_results.dart` (novo)
- `lib/core/network/device_connectivity.dart`
- `lib/features/pdf_reader/data/datasources/connectivity_network_connection_checker.dart`

---

## `app_links` (^7.0.0) — adjusted

**Comportamento web:** `app_links_web` captura `window.location.href` em `getInitialLink()` e emite uma vez no stream.

**Problema:** fluxo PWA usa `https://plpcjf.org/?sharepdfs=...&sharename=...` — **sem** esquema `plpcg://`. `SyncDeepLinkState`/`parsePlaylistShareParams` já ignoram esquema (só leem query params), mas o listener dependia exclusivamente de `AppLinks.getInitialLink()` sem garantir `Uri.base` quando a app abre direto na URL do browser.

**Correção:** `resolveWebInitialDeepLinkUri` prefere `Uri.base` quando contém `sharepdfs` + `sharename`; `DeepLinkListener` aplica em `kIsWeb` antes de processar link inicial.

**Arquivos alterados:**
- `lib/features/app_shell/presentation/utils/deep_link_initial_uri.dart` (novo)
- `lib/features/app_shell/presentation/widgets/deep_link_listener.dart`

**Limitação conhecida:** `uriLinkStream` web emite só a URL inicial — navegações SPA subsequentes com novos query params não re-disparam import (mesmo comportamento da PWA; aceitável para MVP).

---

## `wakelock_plus` (^1.5.2) — ok

- Web usa `no_sleep.js`; alguns browsers exigem gesto do usuário antes de manter tela acordada.
- UC-09 bulk **habilitado** na web (D1 O3, Fase 4) — `BulkDownloadWakelock` permanece no fluxo.
- Sem alteração de código; validar manualmente em Chrome após interação do usuário.

---

## `pdfrx` / `pdfrx_engine` (^2.4.4) — ok

- `pdfium.wasm` e `pdfium_worker.js` incluídos automaticamente no build (`platforms: [web]` no pubspec do pacote).
- Sem cabeçalhos COOP/COEP (Fase 6): `SharedArrayBuffer` indisponível → modo single-thread mais lento, **não quebra** leitura.
- Abertura via `PdfDocument.openData(bytes)` (D2) — sem paths de filesystem.

---

## `isar_plus` — ok

- `Isar.initialize()` + `Isar.open` sem `directory` na web (Fase 1).
- Schemas `LouvorCache`, `CarouselEntry`, `Playlist`, `OfflinePdfIndex` persistem em IndexedDB.
- Boot com ~4600 louvores: medir performance em Fase 7 (smoke chrome).

---

## `shared_preferences` (^2.3.4) — ok

- Backend `window.localStorage` — web-safe desde sempre.

---

## Demais dependências — ok

- **`dio`**, **`flutter_svg`**, **`go_router`**, **`flutter_riverpod`**: sem bloqueios web.
- **`archive`**: problemático apenas em `InputFileStream` (Fase 4); decode de bytes in-memory é web-safe.

---

## Verificação

```bash
flutter analyze
flutter test
flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json
```

Resultados registrados no commit da fase.

---

## Testes adicionados

- `test/unit/core/network/connectivity_results_test.dart`
- `test/unit/features/app_shell/deep_link_initial_uri_test.dart`
