# ADR-001 — Isar Plus para storage estruturado

**Status:** Revisado (nov/2026) — `isar_plus` 1.3.9 para corrigir o release iOS
**Data:** junho de 2026

## Contexto

O PLPCG gerencia ~4600+ louvores no manifest, milhares de PDFs offline, playlists e carousel com consultas frequentes. A PWA usava localStorage e Cache Storage com problemas de dessincronização e lookup O(n).

## Decisão

Usar **isar_plus** (fork mantido do Isar) para metadados estruturados e índice offline. PDFs binários permanecem no **filesystem** via `path_provider`.

## Escopo Isar

| Collection | UC | Propósito |
|------------|-----|-----------|
| `LouvorCache` | UC-01, UC-03, UC-12 | Cache do manifest |
| `CarouselEntry` | UC-05 | Seleção temporária |
| `Playlist` | UC-06, UC-07 | Playlists salvas |
| `OfflinePdfIndex` | UC-09, UC-10 | Lookup O(1) pdfId → path |

## Pacotes

- `isar_plus`, `isar_plus_flutter_libs` ^1.3.9 (runtime; codegen embutido no pacote)
- `build_runner` (dev)

## Correção do release iOS 1.0.1 (3)

O IPA e o archive dessa versão não exportavam os símbolos `isar_plus_*` no
executável Runner. O core estático 1.3.7 usava `DynamicLibrary.process()`, então
não conseguia resolver `isar_plus_version` e abrir o banco. Não era necessário
solicitar permissão de armazenamento ou apagar os dados do app.

A [correção oficial 1.3.9](https://pub.dev/packages/isar_plus_flutter_libs/changelog#139)
embute o core dinâmico `IsarPlusCore.framework`, carregado explicitamente por
`DynamicLibrary.open()`. Atualizamos os dois pacotes juntos, sem alterar nome,
diretório ou schemas do banco. Os assets JS/WASM também acompanham a versão
resolvida no lockfile; o download só substitui ambos após sucesso.

O script de geração do IPA verifica o framework embutido e os símbolos de
versão, conexão Dart e abertura antes de indicar que o pacote pode ser enviado:

```bash
python3 scripts/validate_ios_isar.py \
  build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app
python3 -B -m unittest scripts.test_validate_ios_isar scripts.test_fetch_isar_web_assets
```

Essa inspeção não substitui testar uma atualização no aparelho sem desinstalar
o app. O teste VM cobre reabertura com listas, índice offline e arquivo baixado;
os testes de widget verificam recuperação pelos dois botões.
Uma fixture compacta e sintética, gravada com o core 1.3.7 e os schemas da tag
`v1.0.1+3`, também comprova que o novo core abre o banco antigo e preserva a lista
e o índice offline, inclusive após reabertura.

## Boot e migração

- `main.dart` chama `openAppIsar()` (`core/database/isar_bootstrap.dart` — imports condicionais nativo vs web)
- Nativo: `Isar.open(..., directory: documents path, name: 'plpcg_plus')` — nome distinto evita crash com binário legado `default.isar`
- Web: `await Isar.initialize()` + `Isar.open` com `directory: ''` (IndexedDB); PDFs binários ainda não persistidos na web (ver plano web Fase 4)
- Upgrade de app: carousel, playlists e índice offline **reiniciam vazios**; catálogo repopula com rede (UC-12); PDFs em `plpcg_pdfs/` permanecem no disco mas exigem re-download para lookup offline

## API (breaking vs isar 3.1)

| isar 3.1 | isar_plus 1.3 |
|----------|----------------|
| `Id id = Isar.autoIncrement` | `int id = 0` + `collection.autoIncrement()` no put |
| `collection.filter()` | `collection.where()` |
| `writeTxn()` | `write()` (síncrono na isolate atual) |
| `Isar.open([schemas], directory:)` | `Isar.open(schemas: [...], directory:)` |

## Consequências

- Passo de CI: `dart run build_runner build` (sem `--delete-conflicting-outputs` — removido no build_runner 2.15)
- `core/database/isar_provider.dart` inicializa Isar no boot
- Testes: `test/flutter_test_config.dart` obtém o core da versão Dart em
  `.dart_tool/isar_plus_test/`, com cache versionado e extração segura sob
  concorrência. No macOS usa o binário do framework dinâmico, sem recompilar
  um arquivo estático. Comandos de validação no README.
- SharedPreferences apenas para flags leves (`OFFLINE_AVAILABLE`, prefs do leitor)

## Alternativas rejeitadas

- **drift** — SQL overhead desnecessário para este domínio
- **hive** — performance inferior em volume alto vs Isar
- **isar 3.1 original** — sem manutenção nem SPM no iOS
