# ADR-002 — pdfrx para leitor PDF (UC-11)

**Status:** Substituído (jun/2026) — migrado de pdfx para pdfrx (Fase C)  
**Data:** junho de 2026

## Contexto

O leitor PDF é feature central com gestos, zoom, modos de navegação e integração com carousel. A PWA usava pdfjs-dist com lentidão de 8–17s na abertura.

## Decisão

Usar **pdfrx** (^2.4.4, PDFium + SPM via `pdfium_flutter`) como viewer PDF no Flutter.

Substitui **pdfx** (sem SPM nativo; patch local legado para scroll horizontal).

## Integração

- `lib/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart` isola o pacote
- `lib/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart` encapsula API pdfrx para presentation
- Camada de domínio (`OpenPdfDocument`, etc.) não importa pdfrx diretamente
- `pdfrxFlutterInitialize()` em `lib/main.dart` antes de `runApp`
- `PdfReaderScreen` fullscreen sem AppBar global do shell
- Único import pdfrx na presentation: `pdf_reader_pdf_view.dart`

## Agente Performance — checklist

- Tempo cold-open do pdfrx (PDFium)
- Pré-cache de páginas adjacentes
- Dispose por sessão (`pdfReaderSessionProvider` autoDispose), não singleton adapter
- Dispose correto de handles/controllers
- Evitar rebuilds desnecessários no `PdfReaderScreen`
- Validar comportamento em Web vs mobile
- Monitorar tamanho IPA/APK (PDFium)

## Alternativas rejeitadas

- **syncfusion_flutter_pdfviewer** — licenciamento comercial
- **pdfx** (mantido até jun/2026) — sem SPM; dependia de patch CocoaPods para bug horizontal

## Histórico

- jun/2026: pdfx 2.9.2 + `scripts/apply_pdfx_patch.sh` (removido na Fase C)
- jun/2026: migração Fase C para pdfrx — ver [MIGRATION_NATIVE_DEPS.md](../MIGRATION_NATIVE_DEPS.md)
