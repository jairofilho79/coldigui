# Patch local: `ImageBitmap` no caminho web (pdfrx 2.6.1)

Cópia do pacote `pdfrx` 2.6.1 do pub.dev (`~/.pub-cache/hosted/pub.dev/pdfrx-2.6.1/`,
sem `example/`, `test/` e `screenshot.jpg`), usada via
`dependency_overrides: { pdfrx: { path: third_party/pdfrx } }` no
`pubspec.yaml` do app. O diff está em `patches/pdfrx-2.6.1-imagebitmap.patch`
(raiz do repo do app).

## Por quê

Na web, cada página que o viewer do pdfrx mostra vira `ui.Image` assim:

1. `assets/pdfium_worker.js` (`renderPage`, no worker): PDFium desenha num
   bitmap BGRA (`FPDFBitmap_BGRA`), copia para um `ArrayBuffer` e devolve
   `{result: {imageData, width, height, missingFonts}, transfer: [copiedBuffer]}`.
2. `lib/src/wasm/pdfrx_wasm.dart` (`PdfPageWasm.render`, mesma thread do
   worker): monta um `PdfImageWeb(width, height, pixels)` com `pixels`
   apontando pro `ArrayBuffer`.
3. `lib/src/pdfrx_flutter.dart` (`PdfImageExt.createImage`, thread
   principal): usa `ImmutableBuffer.fromUint8List` + `ImageDescriptor.raw(...,
   PixelFormat.bgra8888)`. No engine web isso vira `createBmp` (loop por
   pixel, 1 chamada wasm→JS por pixel) + `Uint8List.toJS` (cópia byte a
   byte) + decodificação de BMP pelo navegador.

Medido: tarefas longas de 120–240 ms na thread principal por página A4
(1630×2307) no Chrome, com ~4 cópias transitórias de 15 MB por página. Um
micro-benchmark à parte (criar o `ImageBitmap` no worker e entregá-lo via
`dart:ui_web`) mediu ~0,1 ms na thread principal, tanto no Chrome quanto no
Safari 26 — ver `results.txt`/`imgbench` no scratchpad da tarefa.

## O que o patch muda

Mínimo, com fallback total para o caminho de sempre:

- **`assets/pdfium_worker.js` (`renderPage`)**: novo parâmetro
  `outputImageBitmap`. Quando verdadeiro **e** sem alpha premultiplicado
  **e** `createImageBitmap` existir, soma `FPDF_REVERSE_BYTE_ORDER` (0x10)
  às flags do PDFium (os bytes saem em RGBA, mesmos valores, só a ordem),
  cria `await createImageBitmap(new ImageData(...), {premultiplyAlpha:
  'none', colorSpaceConversion: 'none'})` no próprio worker e devolve
  `imageBitmap` (transferido, não copiado) em vez de `imageData`. Se
  `createImageBitmap` lançar, troca os bytes de volta para BGRA e cai no
  retorno de sempre (`imageData`) — o contrato dessa função não muda para
  quem não pede o atalho.
- **`lib/src/wasm/pdfrx_wasm.dart`**: `PdfPageWasm.render` passa
  `outputImageBitmap: PdfrxWebImagePath.useImageBitmap`. Se o worker
  devolver `imageBitmap`, `PdfImageWeb` guarda o bitmap em vez de `pixels`
  prontos; `pixels` (contrato de `PdfImage`, BGRA) passa a ser computado
  sob demanda por um `OffscreenCanvas` (`drawImage` + `getImageData`, troca
  de volta pra BGRA) — o viewer não usa esse caminho, mas outros
  consumidores de `PdfImage.pixels` continuam funcionando. `dispose()` só
  fecha o bitmap (`close()`) se ele não foi entregue ao Flutter.
- **`lib/src/pdfrx_flutter.dart` (`PdfImageExt.createImage`)**: antes do
  caminho de sempre, tenta `web_image_bitmap.tryCreateImageFromBitmap`
  (import condicional — stub fora da web). Na web, se a imagem tem bitmap,
  ninguém pediu `pixelSizeThreshold` (downscale só existe no caminho por
  BMP) e a chave está ligada, devolve
  `ui_web.createImageFromImageBitmap(bitmap)` direto e marca o bitmap como
  entregue. Em qualquer outro caso, `null` — cai no `ImageDescriptor.raw`
  de sempre.
- **Novos arquivos**: `lib/src/utils/web_image_path.dart` (a chave, sem
  import de plataforma — dá pra alternar de qualquer lugar/teste),
  `lib/src/web_image_bitmap_web.dart` e `lib/src/web_image_bitmap_stub.dart`
  (a ponte condicional `dart:ui_web`, seguindo o padrão que o pacote já usa
  em `utils/platform.dart`).

- **Cache-bust do worker** (`lib/src/wasm/pdfrx_wasm.dart`,
  `_getWorkerUrl`): o `importScripts` pede
  `pdfium_worker.js?v=<_patchedWorkerVersion>`. O `_headers` do app serve
  `/assets/packages/pdfrx/assets/*` como `immutable` por 1 ano, com nome
  fixo: sem a versão na URL, quem já abriu o leitor continuaria com o worker
  antigo do cache HTTP (sem o atalho — não quebra, só não melhora). **Toda
  mudança em `pdfium_worker.js` exige subir `_patchedWorkerVersion`.**

Nada mais no pdfrx muda. `lib/pdfrx.dart` ganha só o export da chave.

## Chave de desligar

`PdfrxWebImagePath.useImageBitmap` (estático público, `lib/src/utils/web_image_path.dart`,
exportado por `package:pdfrx/pdfrx.dart`). `true` por padrão. `false`
restaura 100% o caminho do pdfrx 2.6.1 original — inclusive não pede mais o
bitmap ao worker (`outputImageBitmap: false` no `renderPage`), então nem o
`FPDF_REVERSE_BYTE_ORDER` entra em jogo.

Emergência mais radical: apagar a seção `dependency_overrides` do
`pubspec.yaml` do app e rodar `flutter pub get` — volta a usar o pdfrx
2.6.1 puro do pub.dev, sem depender deste diretório.

## Como reaplicar num upgrade do pdfrx

1. Copiar o novo `~/.pub-cache/hosted/pub.dev/pdfrx-<versão>/` por cima de
   `third_party/pdfrx/` (sem `example/`, `test/`, `screenshot.jpg`,
   `.dart_tool/`, `pubspec.lock`).
2. Tentar `patch -p1 --dry-run < patches/pdfrx-2.6.1-imagebitmap.patch`
   dentro de `third_party/pdfrx/` (contra a versão nova). Se aplicar limpo,
   `patch -p1 < ...` de verdade.
3. Se não aplicar limpo (a versão nova mexeu nos mesmos trechos de
   `renderPage`, `PdfPageWasm.render` ou `PdfImageExt.createImage`),
   reaplicar manualmente os 5 pontos acima na versão nova, comparando com
   este patch como referência — ele é pequeno de propósito.
4. Regerar o patch (`diff -ruN` entre o pub-cache pristino da nova versão e
   `third_party/pdfrx/`, excluindo `.dart_tool/` e `pubspec.lock`) e
   atualizar este arquivo com o número da versão.
5. Rodar de novo a verificação de pixels (byte a byte, `ui.Image` pelos
   dois caminhos) antes de confiar no upgrade — ver o relatório da tarefa
   que introduziu este patch.
