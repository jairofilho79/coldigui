# coldigui

A new Flutter project.

## Modo dual PLPCG + Coldigom (fase 1)

A busca na Home consulta o manifest PLPCG (chips **vermelhos**) e a API coldigom em produção (chips **pretos**, borda dourada). Itens coldigom podem ser adicionados ao carousel, abertos no leitor e usados em playlists/folheto.

API coldigom: `https://coldigom-api.coletaneadigitalicm.workers.dev`

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