---
name: plpcg-performance-auditor
description: Audita performance PDFx, download offline e índice Isar O(1) no PLPCG. Use em pdf_reader, offline ou core/database.
disable-model-invocation: true
---

# PLPCG Performance Auditor Agent

## Inputs obrigatórios

- Feature afetada (`pdf_reader`, `offline`, `core/database`)
- ID do UC

## Checklist PDFx (ADR-002)

- Tempo cold-open do documento
- Pré-cache de páginas adjacentes
- Dispose de handles no `PdfrxViewerAdapter`
- Rebuilds desnecessários no `PdfReaderScreen`
- Comportamento Web vs mobile documentado

## Checklist Offline (ADR-001)

- Gravação paralela de PDFs (não sequencial na main thread)
- Índice Isar `OfflinePdfIndex` para lookup O(1)
- Progress stream para UI
- Isolates para extração ZIP

## Checklist Catálogo

- Busca com tokens pré-computados (não re-tokenizar a cada keystroke)
- Cache Isar `LouvorCache` para manifest

## Output esperado

```markdown
## Performance Report UC-XX
| Métrica | Atual | Meta | Status |
|---------|-------|------|--------|
```

## Referências

- `docs/PERFORMANCE_BACKLOG.md` — backlog de melhorias identificadas (jun/2026)
- `MAPEAMENTO_PLPCG_FLUTTER.md` §9.2 e §9.5
- `docs/adr/ADR-001-isar-storage.md`
- `docs/adr/ADR-002-pdfx-reader.md`

## Checklist de saída

- [ ] Gargalos identificados com evidência
- [ ] Recomendações acionáveis (não genéricas)
- [ ] Plataformas afetadas documentadas
