# CI Web — Fase 7 (D9)

Pipeline para evitar regressão silenciosa na plataforma web após as fases 0–6.

## Workflow GitHub Actions

Arquivo: [`.github/workflows/web.yml`](../.github/workflows/web.yml)

Dispara em **todo pull request** e em push na branch `main`.

| Etapa | Comando |
| --- | --- |
| Dependências | `./scripts/setup_deps.sh` |
| Análise | `flutter analyze` |
| Testes VM | `flutter test` |
| Smoke Chrome | `flutter test --platform chrome --dart-define-from-file=dart_defines/plpcjf.json test/web/` |
| Build web | `flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json` |

O job instala Chrome via `browser-actions/setup-chrome` e define `CHROME_EXECUTABLE` para o Flutter.

## Validação local (antes de merge)

Na raiz do repositório:

```bash
./scripts/setup_deps.sh
flutter analyze
flutter test
flutter test --platform chrome \
  --dart-define-from-file=dart_defines/plpcjf.json \
  test/web/
flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json
```

Build release local (deploy):

```bash
./scripts/web_build.sh
```

## Smoke Chrome (`test/web/`)

Escopo mínimo (Fase 7):

- Confirma execução no target web (`kIsWeb`).
- Verifica `PLPCG_API_BASE_URL` via `dart_defines/plpcjf.json`.
- Renderiza um widget Material simples.

**Não** roda a suíte inteira em Chrome: testes VM que dependem de `dart:io` / binário Isar nativo permanecem em `flutter test` (VM). Expansão incremental: boot com `ColdiguiApp`, catálogo e PDF remoto com mocks.

## `test/flutter_test_config.dart`

Inicialização Isar (`ensureIsarPlusTestCore`) só roda fora da web (`!kIsWeb`), para `flutter test --platform chrome` não importar `dart:io`.

## Chrome indisponível localmente

Se `flutter test --platform chrome` falhar por ausência de Chrome/Chromium, instale um navegador compatível ou use apenas os comandos VM + build web. A CI no GitHub é a fonte de verdade para o smoke Chrome.

## Scripts

- [`scripts/setup_deps.sh`](../scripts/setup_deps.sh) — `flutter config --enable-web` (idempotente) + `flutter pub get` para mobile e web.
