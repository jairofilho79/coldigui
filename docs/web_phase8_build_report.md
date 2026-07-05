# Relatório de build — Fase 8 (verificação multi-plataforma)

**Data:** 04/07/2026 (America/Sao_Paulo)  
**Branch base:** `web/phase-7` @ `c80b09fdf91f70b01d10231a5093d28d6ab5868f`  
**Branch de entrega:** `web/phase-8` / `web/integration`  
**Ambiente:** macOS (darwin 25.5.0)

## Flutter / Dart

| Ferramenta | Versão |
| --- | --- |
| Flutter | 3.44.4 (stable, revision ad70ec4617) |
| Dart | 3.12.2 |
| DevTools | 2.57.0 |

## Resultados

| Etapa | Comando | Resultado | Duração |
| --- | --- | --- | --- |
| Análise | `flutter analyze` | **PASS** — No issues found | ~4 s |
| Testes VM | `flutter test` | **PASS** — 560 passed, 3 skipped | ~26 s |
| Smoke Chrome | `flutter test --platform chrome test/web/ --dart-define-from-file=dart_defines/plpcjf.json` | **PASS** — 3 tests | ~9 s |
| Web release (WASM) | `flutter build web --wasm --release --dart-define-from-file=dart_defines/plpcjf.json` | **PASS** — `build/web` | ~2 s |
| iOS simulador | `flutter build ios --simulator --dart-define-from-file=dart_defines/plpcg.json` | **PASS** — `build/ios/iphonesimulator/Runner.app` | ~42 s |
| Android APK | `flutter build apk --dart-define-from-file=dart_defines/plpcg.json` | **FAIL** — ver abaixo | ~1 s |

### Android APK — motivo da falha

```
The operation couldn't be completed. Unable to locate a Java Runtime.
Gradle task assembleRelease failed with exit code 1
```

Neste host não há JRE/JDK configurado (`/usr/libexec/java_home` falha; Android Studio JBR não encontrado). **Não é regressão do código Flutter** — repetir em máquina com JDK (CI ou dev com Android Studio) para fechar o critério de aceite nativo Android.

### iOS

Build de simulador concluído com Xcode (~31,7 s de compilação Xcode).

## Resumo pass/fail por plataforma

| Plataforma | Build / verificação | Status |
| --- | --- | --- |
| Web (analyze + test + WASM) | Sim | **PASS** |
| iOS (simulador) | Sim | **PASS** |
| Android (APK) | Não (ambiente sem Java) | **FAIL** (ambiente) |

## Pendências remanescentes

- Validar `flutter build apk` (ou pipeline CI Android existente) em ambiente com JDK.
- Critérios D9 continuam cobertos pela CI (`/.github/workflows/web.yml`) para web.

## Comandos reproduzíveis

```bash
flutter analyze
flutter test
flutter test --platform chrome test/web/ --dart-define-from-file=dart_defines/plpcjf.json
flutter build web --wasm --release --dart-define-from-file=dart_defines/plpcjf.json
flutter build ios --simulator --dart-define-from-file=dart_defines/plpcg.json
flutter build apk --dart-define-from-file=dart_defines/plpcg.json
```
