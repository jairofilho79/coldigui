# coldigui

A new Flutter project.

## Catálogo e backends

O catálogo (manifest + checksum), os PDFs e os materiais Coldigom vêm do Worker
`coldigom-api` (`COLDIGOM_API_BASE_URL`). O Worker `plpcg-catalog`
(`PLPCG_API_BASE_URL`) serve auth, playlists, links curtos e Lista ao Vivo.
Os dois defines são obrigatórios — sem um deles o app mostra a tela de
configuração ausente. Ficheiros prontos em `dart_defines/*.json`
(`--dart-define-from-file`).

Um louvor = um praise do coldigom: as entradas legadas do manifest (`pdfId`,
`shortId`) e os materiais Coldigom (áudio, cifra, letra, gestos) aparecem no
mesmo card. Ver `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md`.

## Testes

Verificação local completa, igual às etapas de teste do CI (`.github/workflows/web.yml`):

```bash
./scripts/test_all.sh            # flutter analyze + flutter test (VM) + alvo Chrome
./scripts/test_all.sh --vm-only  # sem o alvo Chrome
```

- `flutter test` roda a suíte VM. Os arquivos de `test/web/` marcados `@TestOn('browser')` **não carregam no VM** (não aparecem nem como skipped) — só existem no alvo Chrome:
  `flutter test --platform chrome --dart-define-from-file=dart_defines/plpcjf.json test/web/`
- Binários nativos de teste (`isar_plus` em `.dart_tool/isar_plus_test/`, pdfium em `build/native_assets/`) são obtidos/apontados automaticamente por `test/helpers/`; nada a fazer em worktree novo. `./scripts/check_isar_test_race.sh` reproduz a extração concorrente do isar_plus.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

./scripts/ios_dev_run.sh — desenvolvimento com hot reload
./scripts/ios_homolog_install.sh — testar no iPhone como usuário final, sem cabo/terminal


# 1. Abrir o simulador (se estiver fechado)
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator

# 2. Rodar o app
cd "/Volumes/SSD 2TB SD/dev/coldigui"
flutter run --dart-define-from-file=dart_defines/plpcg.json -d "iPhone 17 Pro"

./scripts/android_homolog_install.sh

flutter emulators --launch coldigui_tablet
source scripts/android_env.sh
flutter run --dart-define-from-file=dart_defines/plpcg.json

./scripts/web_deploy.sh