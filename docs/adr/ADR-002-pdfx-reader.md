# ADR-002 — PDFx para leitor PDF (UC-11)

**Status:** Aceito  
**Data:** junho de 2026

## Contexto

O leitor PDF é feature central com gestos, zoom, modos de navegação e integração com carousel. A PWA usava pdfjs-dist com lentidão de 8–17s na abertura.

## Decisão

Usar **pdfx** (open source) como viewer PDF no Flutter.

## Integração

- `lib/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart` isola o pacote
- Camada de domínio (`OpenPdfDocument`, etc.) não importa pdfx diretamente
- `PdfReaderScreen` fullscreen sem AppBar global do shell

## Agente Performance — checklist

- Tempo cold-open do PDFx
- Pré-cache de páginas adjacentes
- Dispose por sessão (`pdfReaderSessionProvider` autoDispose), não singleton adapter
- Dispose correto de controllers
- Evitar rebuilds desnecessários no `PdfReaderScreen`
- Validar comportamento em Web vs mobile

## Alternativas rejeitadas

- **syncfusion_flutter_pdfviewer** — licenciamento comercial

## Patch local (pdfx 2.9.2)

O `PdfViewPinch` com `scrollDirection: Axis.horizontal` divide por zero em
`_determinePagesToShow` quando `_docSize.height == viewport.height` (upstream
não corrigido). Script `scripts/apply_pdfx_patch.sh` — aplicar após
`flutter pub get`:

```bash
./scripts/apply_pdfx_patch.sh
```
