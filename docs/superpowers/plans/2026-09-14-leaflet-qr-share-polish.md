# Folheto com QR — polimento pós-rollout (v2 + plpcjf) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (1) QR menor + margem de segurança no PNG do folheto v2 (o WhatsApp iOS apara ~3% da borda direita/inferior de imagem enviada com legenda); (2) listas com material fora do acervo PLPCG não emitem mais link (curto nem longo) nem QR no v2 — só folheto, com dialog explicando; (3) folheto do plpcjf passa a ir com a mesma legenda (nome + link curto) e o mesmo QR do v2.

**Architecture:** No v2 a decisão «lista é PLPCG pura» já existe: `PlaylistShareLink.isShort` (todas as entradas são PDF com `shortId`). O gate entra em `PlaylistShareActionsNotifier.share` antes de qualquer captura; o formato longo deixa de ser emitido pelo share (parse de links longos continua, por compatibilidade). A margem entra só na captura (`captureLeafletPngBytes`), não no widget. No plpcjf o folheto é HTML renderizado por html2canvas — o QR entra como `<img>` data-URL gerado por `qrcode` (import dinâmico), e `navigator.share` recebe `text` com `nome\n\nurl` quando a URL é curta.

**Tech Stack:** Flutter 3 / Riverpod 3 / `qr_flutter` 4.1 / `flutter_test`; SvelteKit (JS + JSDoc), `html2canvas`, `qrcode` (npm), `node --test`.

**Spec:** `docs/superpowers/specs/2026-09-13-short-id-share-design.md` (D7, D10 e §6 são emendados pela Task 3 deste plano). Desenho aprovado em chat em 2026-09-14 (este plano é o registro).

## Global Constraints

- `shortId` é **string** hex `[0-9a-f]{4,8}`; link curto = `https://plpcg.com/?s=<ids>-…&n=<nome>`; `s` **e** `n` não vazio obrigatórios.
- QR e legenda com link **somente** quando o link é do formato curto (D10) — nos dois apps.
- v2: o share **não emite mais** link longo (`shareitems=`/`sharepdfs=`) em nenhuma opção; parse/import de links longos permanece intacto.
- v2: mensagem da legenda continua `playlistShareLinkWithLeafletMessage` = `"{name}\n\n{url}"`; plpcjf usa o mesmo texto: `` `${playlistName}\n\n${shareUrl}` ``.
- Copy pt-BR nova (verbatim): título «Lista com materiais do Coldigom»; corpo (Folheto) «O link e o QR code só funcionam com hinos do PLPCG. Remova os cards do Coldigom da lista para compartilhar com link, ou envie só o folheto.»; corpo (Só o link) «O link só funciona com hinos do PLPCG. Remova os cards do Coldigom da lista para compartilhar o link.»; botões «Cancelar», «Só o folheto», «Entendi». Inglês: "List has Coldigom materials" / "The link and QR code only work with PLPCG hymns. Remove the Coldigom cards from the list to share a link, or send just the leaflet." / "The link only works with PLPCG hymns. Remove the Coldigom cards from the list to share the link." / "Cancel", "Leaflet only", "Got it".
- Folheto v2: QR 96 pt, padding da caixa 6, banda com inset vertical 12; margem de captura 16 pt em todos os lados, cor `AppColors.background`; largura do boundary = 595 + 32 = 627.
- Folheto plpcjf: QR 150 px (em CSS, dentro do folheto de 620 px), caixa branca com borda `1px solid #D4AF37`, legenda «Abrir lista no PLPCG», URL exibida sem esquema e cortada antes de `&n=`; wrapper capturado com `padding:16px;background:#4B2D2B`.
- Sempre `flutter gen-l10n` depois de mexer em `.arb`; `flutter analyze` limpo; testes novos ao lado dos existentes.
- Não tocar: parse de `?s=`/legados, `/l/` (fica sem chamador — débito), builds nativos, Coldigom (áudio/cifra) além do gate.
- Commits em pt-BR, prefixo convencional (`fix(leaflet):`, `feat(playlists):`, `docs:`), com as linhas de atribuição da sessão.

---

## Task 1 (coldigui): QR compacto + margem de segurança na captura

**Files:**
- Modify: `lib/features/leaflet/presentation/widgets/leaflet_content.dart` (`_ShareQrBand`)
- Modify: `lib/features/leaflet/presentation/utils/leaflet_capture.dart`
- Test: `test/widget/features/leaflet/leaflet_content_test.dart` (ajustar se preciso), Create: `test/widget/features/leaflet/leaflet_capture_test.dart`

**Interfaces:**
- Produces: `const double kLeafletCaptureMargin = 16.0;` em `leaflet_capture.dart`.

- [ ] **Step 1: Teste de captura com margem (falha primeiro)**

```dart
// test/widget/features/leaflet/leaflet_capture_test.dart
import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_entry.dart';
import 'package:coldigui/features/leaflet/presentation/utils/leaflet_capture.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = LeafletContentLabels(
    headerDateLine: 'SEGUNDA-FEIRA 14/09/2026',
    columnNumber: 'NÚMERO',
    columnName: 'NOME DO HINO',
    footerPeace: 'A PAZ DO SENHOR JESUS CRISTO',
    footerGreeting: 'Bom culto!',
    shareQrCaption: 'Abrir lista no PLPCG',
  );
  final document = LeafletDocument(
    generatedAt: DateTime(2026, 9, 14),
    entries: const [
      LeafletEntry(index: 1, numero: '055', nome: 'Senhor meu Deus e Pai'),
    ],
    shareUrl: 'https://plpcg.com/?s=060f&n=Culto',
  );

  testWidgets('boundary capturado inclui margem de segurança em volta do folheto',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final overlay = tester.state<OverlayState>(find.byType(Overlay));

    Size? boundarySize;
    Size? contentSize;
    final future = captureLeafletPngBytes(
      overlay,
      document,
      labels,
      capture: (boundaryKey) async {
        boundarySize = boundaryKey.currentContext!.size;
        contentSize = tester.getSize(find.byType(LeafletContent));
        return const <int>[];
      },
    );
    await tester.pump();
    await tester.pump();
    await future;

    expect(contentSize!.width, kLeafletContentWidth);
    expect(
      boundarySize!.width,
      kLeafletContentWidth + 2 * kLeafletCaptureMargin,
    );
    expect(
      boundarySize!.height,
      contentSize!.height + 2 * kLeafletCaptureMargin,
    );
  });
}
```

- [ ] **Step 2: Rodar — deve falhar** (`kLeafletCaptureMargin` indefinido)

Run: `flutter test test/widget/features/leaflet/leaflet_capture_test.dart`

- [ ] **Step 3: Margem na captura**

Em `leaflet_capture.dart`, adicionar `import '../../../../core/theme/color_extensions.dart';` e:

```dart
/// Margem (pt lógico) em volta do folheto no PNG capturado. O WhatsApp iOS
/// apara ~3% da borda direita/inferior de imagem enviada junto com legenda —
/// a margem absorve o aparo e ainda dá fundo opaco aos cantos arredondados
/// (PNG transparente vira preto ao ser convertido em JPEG).
const double kLeafletCaptureMargin = 16.0;
```

e o `RepaintBoundary` passa a envolver:

```dart
child: RepaintBoundary(
  key: boundaryKey,
  child: ColoredBox(
    color: AppColors.background,
    child: Padding(
      padding: const EdgeInsets.all(kLeafletCaptureMargin),
      child: LeafletContent(document: document, labels: labels),
    ),
  ),
),
```

- [ ] **Step 4: QR compacto** em `_ShareQrBand`:

```dart
static const _qrSize = 96.0;
static const _qrBoxPadding = 6.0;
static const _qrBandInsetV = 12.0;
```

Trocar `EdgeInsets.all(8)` → `EdgeInsets.all(_qrBoxPadding)`, o `vertical: LeafletContent._footerInsetV` da banda → `vertical: _qrBandInsetV`, o `SizedBox(height: 8)` entre QR e legenda → `SizedBox(height: 6)`. Atualizar o doc-comment da classe: «QR de 96 pt — legível em foto de tela e não domina o folheto».

- [ ] **Step 5: Ajustar `leaflet_content_test.dart`** se algum teste assere tamanho do QR (`grep -n "132\|_qrSize" test/widget/features/leaflet/leaflet_content_test.dart`). Se não houver, nada a fazer.

- [ ] **Step 6: Rodar testes + analyze**

Run: `flutter test test/widget/features/leaflet test/unit/features/leaflet && flutter analyze lib/features/leaflet test/widget/features/leaflet`
Expected: tudo verde, analyze «No issues found».

- [ ] **Step 7: Commit**

```bash
git add lib/features/leaflet test/widget/features/leaflet
git commit -m "fix(leaflet): QR de 96pt e margem de 16pt na captura do folheto"
```

---

## Task 2 (coldigui): gate Coldigom — só folheto, com dialog

**Files:**
- Create: `lib/features/playlists/presentation/widgets/coldigom_share_dialog.dart`
- Modify: `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ `flutter gen-l10n`)
- Test: `test/unit/features/playlists/playlist_share_actions_test.dart`

**Interfaces:**
- Consumes: `PlaylistShareLink { url, isShort }`; `generatePlaylistShareUrlProvider` (`({required String playlistId, bool short}) → Future<PlaylistShareLink>`); `PlaylistShareOption { link, leaflet, linkWithLeaflet }`.
- Produces: `Future<bool> showColdigomShareDialog(BuildContext context, {required bool offerLeafletOnly})` — `true` só quando o usuário toca «Só o folheto».

- [ ] **Step 1: l10n** — adicionar em `app_pt.arb` (após `playlistShareLinkWithLeafletMessage` e seu bloco `@`):

```json
  "playlistShareColdigomTitle": "Lista com materiais do Coldigom",
  "playlistShareColdigomBodyLeaflet": "O link e o QR code só funcionam com hinos do PLPCG. Remova os cards do Coldigom da lista para compartilhar com link, ou envie só o folheto.",
  "playlistShareColdigomBodyLink": "O link só funciona com hinos do PLPCG. Remova os cards do Coldigom da lista para compartilhar o link.",
  "playlistShareColdigomCancel": "Cancelar",
  "playlistShareColdigomLeafletOnly": "Só o folheto",
  "playlistShareColdigomDismiss": "Entendi",
```

e em `app_en.arb` as versões inglesas dos Global Constraints. Rodar `flutter gen-l10n`.

- [ ] **Step 2: Dialog**

```dart
// lib/features/playlists/presentation/widgets/coldigom_share_dialog.dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Aviso do gate Coldigom (débito técnico até o acervo PLPCG sair do
/// coldigui): listas com material fora do acervo PLPCG não geram link nem QR.
///
/// [offerLeafletOnly] = `true` (opção Folheto) mostra «Cancelar» / «Só o
/// folheto»; `false` (opção Só o link) mostra apenas «Entendi».
/// Retorna `true` somente quando o usuário escolhe «Só o folheto».
Future<bool> showColdigomShareDialog(
  BuildContext context, {
  required bool offerLeafletOnly,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.playlistShareColdigomTitle),
      content: Text(
        offerLeafletOnly
            ? l10n.playlistShareColdigomBodyLeaflet
            : l10n.playlistShareColdigomBodyLink,
      ),
      actions: [
        if (offerLeafletOnly) ...[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.playlistShareColdigomCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.playlistShareColdigomLeafletOnly),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.playlistShareColdigomDismiss),
          ),
      ],
    ),
  );
  return result ?? false;
}
```

- [ ] **Step 3: Testes (falham primeiro)** — em `playlist_share_actions_test.dart`. O cenário «lista fora do PLPCG» reaproveita `_PdfKindPlaylistRepository` com manifest **sem** `shortId` (`comShortId: false`), que hoje produz link longo. O helper `_shareLinkWithLeaflet` aguarda o share; para o dialog é preciso **não aguardar**: guarde o `Future`, `await tester.pumpAndSettle()`, interaja, depois `await future`. Novos testes:

```dart
testWidgets(
  'linkWithLeaflet com lista fora do PLPCG abre dialog e, em Cancelar, não compartilha',
  (tester) async {
    // setup igual ao helper _shareLinkWithLeaflet com comShortId: false
    // final future = notifier.share(context, shareContext,
    //   PlaylistShareOption.linkWithLeaflet, sharePositionOrigin: null,
    //   shareXFiles: (files, {subject, text, sharePositionOrigin}) async { sharedFiles = files; },
    //   capture: (key) async => const <int>[]);
    // await tester.pumpAndSettle();
    // expect(find.text('Lista com materiais do Coldigom'), findsOneWidget);
    // await tester.tap(find.text('Cancelar')); await tester.pumpAndSettle();
    // expect(await future, isFalse); expect(sharedFiles, isNull);
  },
);

testWidgets(
  'linkWithLeaflet com lista fora do PLPCG e «Só o folheto» compartilha imagem sem texto e sem QR',
  (tester) async {
    // mesmo setup; tap em 'Só o folheto'; pumpAndSettle;
    // expect(await future, isTrue); expect(sharedText, isNull);
    // expect(sharedSubject, 'Folheto PLPCG'); expect(capturedDoc!.shareUrl, isNull);
  },
);

testWidgets(
  'link com lista fora do PLPCG abre dialog só com «Entendi» e não compartilha',
  (tester) async {
    // option: PlaylistShareOption.link com share: (text, {subject, sharePositionOrigin}) async { sharedText = text; }
    // expect(find.text('Entendi'), findsOneWidget); expect(find.text('Só o folheto'), findsNothing);
    // tap 'Entendi'; expect(await future, isFalse); expect(sharedText, isNull);
  },
);
```

Ajustes nos testes existentes:
- `'linkWithLeaflet com link longo não passa shareUrl ao folheto'` deixa de valer (não há mais link longo) → substituir pelo segundo cenário acima.
- `'link only chama Share.share com URL'` passa a usar `_PdfKindPlaylistRepository` + manifest com `shortId: '0000'` + `generatePlaylistShareUrlProvider.overrideWith((ref) => GeneratePlaylistShareUrl(..., shortIdOf: (id) => ref.read(louvoresByPdfIdProvider)[id]?.shortId))`, esperando `'https://plpcg.com/?s=0000&n=Ensaio'`.
- Testes com `_CountingShortener`/`_LoggedInAuth`: o encurtador agora **nunca** é chamado pelo share (`callCount == 0`) em qualquer opção; ajustar asserções/nomes.

Para ler o documento capturado copie o padrão do helper `_shareLinkWithLeaflet` (ele lê `LeafletContent.document` a partir do `boundaryKey`).

- [ ] **Step 4: Rodar — devem falhar**

Run: `flutter test test/unit/features/playlists/playlist_share_actions_test.dart`

- [ ] **Step 5: Notifier** — em `playlist_share_actions_provider.dart`:

1. `_generateUrl(String playlistId)` passa a sempre pedir `short: false`, perde o parâmetro `allowShortener` e a leitura de `authStateProvider` (remover o import de `auth_state_provider.dart` se ficar sem uso). Comentário: «Formato curto é decidido localmente por `PlaylistShareLink.isShort`; o share não emite mais link longo, então o `/l/` não tem chamador aqui (débito: remover junto com o gate Coldigom).»
2. `_shareLinkOnly` passa a receber `BuildContext context` como primeiro argumento:
```dart
final link = await _generateUrl(shareContext.playlistId);
if (!link.isShort) {
  if (context.mounted) {
    await showColdigomShareDialog(context, offerLeafletOnly: false);
  }
  return false;
}
await shareTextFn(
  link.url,
  subject: shareContext.nome,
  sharePositionOrigin: sharePositionOrigin,
);
return true;
```
3. `_shareLinkWithLeaflet`:
```dart
final link = await _generateUrl(shareContext.playlistId);
if (!context.mounted) return false;
if (!link.isShort) {
  final leafletOnly =
      await showColdigomShareDialog(context, offerLeafletOnly: true);
  if (!leafletOnly || !context.mounted) return false;
  return _shareLeafletOnly(
    context, shareContext, l10n, shareFilesFn, sharePositionOrigin,
    capture: capture,
  );
}
// segue como hoje, com shareUrl: link.url
```
4. `_shareLeafletOnly`: `_generateUrl(shareContext.playlistId)` (sem `allowShortener`), resto igual; o comentário sobre o encurtador ali passa a apontar para o comentário de `_generateUrl`.
5. Doc da classe: «Orquestra os 3 modos … Gate Coldigom: lista que não é PLPCG pura (`!link.isShort`) não gera link nem QR — só folheto, após confirmação em [showColdigomShareDialog].»

- [ ] **Step 6: Rodar testes + analyze**

Run: `flutter test test/unit/features/playlists/playlist_share_actions_test.dart test/widget/features/playlists test/widget/features/carousel && flutter analyze`
Expected: verde; analyze limpo (atenção a import morto de `auth_state_provider`).

- [ ] **Step 7: Commit**

```bash
git add lib/features/playlists lib/l10n test/unit/features/playlists
git commit -m "feat(playlists): gate Coldigom no share — só folheto, sem link/QR, com aviso"
```

---

## Task 3 (coldigui): documentação e débito técnico

**Files:**
- Modify: `docs/superpowers/specs/2026-09-13-short-id-share-design.md` (D7, D10, §6)
- Modify: `docs/features/FEATURE_INDEX.md` (linha `playlists` na tabela de status, linha `CarouselBarTrailingActions`, nova seção «Débitos técnicos» antes de `## APIs públicas — Core`)
- Modify: `docs/deep-links-setup.md` se mencionar link longo emitido pelo share (`grep -n "shareitems\|longo" docs/deep-links-setup.md`).

- [ ] **Step 1: Spec** — emendar (sem reescrever histórico; prefixar «**Emenda 2026-09-14:**» nas células):
  - D7: «Emenda 2026-09-14: o v2 **não emite mais** o formato longo em nenhuma opção de share; lista fora do PLPCG (Coldigom ou PDF sem `shortId`) vai só como folheto, sem link e sem QR, após aviso (`showColdigomShareDialog`). O parse do formato longo continua. plpcjf inalterado (sempre PLPCG).»
  - D10: «Emenda 2026-09-14: QR de 96 pt; PNG capturado com margem de 16 pt (`kLeafletCaptureMargin`) porque o WhatsApp iOS apara ~3% da borda de imagem enviada com legenda. plpcjf ganha o mesmo QR e a mesma legenda (`nome\n\nurl`).»
  - §6: substituir a primeira linha por «Materiais Coldigom: sem `shortId` → sem link e sem QR (gate com dialog). **Débito técnico:** remover o gate, o dialog e a emissão de link longo/`/l/` quando o acervo PLPCG sair do coldigui.»
- [ ] **Step 2: FEATURE_INDEX** — atualizar as duas linhas (`… Folheto (imagem + link curto + QR, só lista PLPCG pura; caso contrário só folheto após [showColdigomShareDialog]) / Só o link …`) e criar a seção:

```markdown
## Débitos técnicos

| Débito | Onde | Quando pagar |
|---|---|---|
| Gate Coldigom no share de listas: lista com material fora do acervo PLPCG não gera link nem QR (só folheto, com aviso [showColdigomShareDialog]); o share não emite mais link longo e o encurtador `/l/` ficou sem chamador. | `playlist_share_actions_provider.dart`, `coldigom_share_dialog.dart`, `generate_playlist_share_url.dart` (formato longo), `share_link_shortener.dart` | Após a remoção do acervo PLPCG do coldigui — apagar gate + dialog + emissão do formato longo + `/l/` (parse de links longos antigos pode ficar). Registrado em 2026-09-14. |
```

- [ ] **Step 3: Commit**

```bash
git add docs
git commit -m "docs: gate Coldigom como débito técnico; emendas D7/D10 do share por shortId"
```

---

## Task 4 (plpcjf): folheto com legenda (nome + link) e QR

**Repo:** `/Volumes/SSD 2TB SD/dev/plpcjf`, branch `feat/leaflet-qr-share` a partir de `main`.

**Files:**
- Modify: `package.json` + `package-lock.json` (`npm install qrcode@^1.5.4` — dependência de runtime, import dinâmico)
- Modify: `src/lib/utils/folhetoUtils.js`
- Modify: `src/lib/components/CarouselChips.svelte` (`handleFolheto`)
- Create: `src/lib/utils/folhetoUtils.test.js`

**Interfaces:**
- Consumes: `generatePlaylistShareUrl(pdfIds, nome, louvores)` (`playlistUtils.js`).
- Produces (em `folhetoUtils.js`):
  - `isShortShareUrl(url)` → `boolean`.
  - `folhetoDisplayUrl(shareUrl)` → string sem `https?://` e cortada antes de `&n=`.
  - `generateFolhetoHtml(louvores, { shareUrl = null, qrDataUrl = null } = {})` — banda de QR só quando ambos vêm preenchidos.
  - `generateShareQrDataUrl(shareUrl)` → `Promise<string>`.
  - `shareFolheto(imageBlob, shareUrl, playlistName)` — `text` só com URL curta.

- [ ] **Step 1: Testes puros (falham primeiro)** — `src/lib/utils/folhetoUtils.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  generateFolhetoHtml,
  folhetoDisplayUrl,
  isShortShareUrl
} from './folhetoUtils.js';

const louvores = [{ nome: 'Senhor meu Deus e Pai', numero: '055' }];

test('isShortShareUrl reconhece só o formato curto', () => {
  assert.equal(isShortShareUrl('https://plpcg.com/?s=060f-0679&n=Culto'), true);
  assert.equal(isShortShareUrl('https://plpcg.com/?sharepdfs=abc&sharename=Culto'), false);
  assert.equal(isShortShareUrl(''), false);
});

test('folhetoDisplayUrl tira o esquema e corta antes de &n=', () => {
  assert.equal(
    folhetoDisplayUrl('https://plpcg.com/?s=060f-0679&n=Culto%20de%20domingo'),
    'plpcg.com/?s=060f-0679'
  );
  assert.equal(folhetoDisplayUrl('https://plpcg.com/?s=060f'), 'plpcg.com/?s=060f');
});

test('sem shareUrl/qrDataUrl o folheto não tem banda de QR', () => {
  const html = generateFolhetoHtml(louvores);
  assert.equal(html.includes('Abrir lista no PLPCG'), false);
  assert.equal(html.includes('<img'), false);
  assert.ok(html.includes('SENHOR MEU DEUS E PAI'));
});

test('com shareUrl e qrDataUrl o folheto tem QR, legenda e URL curta exibida', () => {
  const html = generateFolhetoHtml(louvores, {
    shareUrl: 'https://plpcg.com/?s=060f-0679&n=Culto',
    qrDataUrl: 'data:image/png;base64,AAAA'
  });
  assert.ok(html.includes('<img src="data:image/png;base64,AAAA"'));
  assert.ok(html.includes('Abrir lista no PLPCG'));
  assert.ok(html.includes('plpcg.com/?s=060f-0679'));
  assert.equal(html.includes('&n=Culto'), false);
});

test('só shareUrl (sem QR gerado) não desenha a banda', () => {
  const html = generateFolhetoHtml(louvores, { shareUrl: 'https://plpcg.com/?s=060f&n=Culto' });
  assert.equal(html.includes('Abrir lista no PLPCG'), false);
});

test('folheto é envolvido por wrapper com margem de segurança', () => {
  const html = generateFolhetoHtml(louvores);
  assert.ok(html.startsWith('<div style="padding:16px;background:#4B2D2B;display:inline-block;">'));
});
```

Run: `node --test src/lib/utils/folhetoUtils.test.js` → falha (exports ausentes).

- [ ] **Step 2: `folhetoUtils.js`**

```js
/**
 * @param {string} url
 * @returns {boolean} `true` só para o formato curto (`?s=…`, spec short-id-share D7).
 */
export function isShortShareUrl(url) {
  if (!url) return false;
  try {
    return new URL(url, 'https://plpcg.com').searchParams.has('s');
  } catch {
    return false;
  }
}

/**
 * URL impressa sob o QR: sem esquema e sem `&n=…` (o nome já está no folheto).
 * @param {string} shareUrl
 * @returns {string}
 */
export function folhetoDisplayUrl(shareUrl) {
  const semEsquema = shareUrl.replace(/^https?:\/\//, '');
  const i = semEsquema.indexOf('&n=');
  return i === -1 ? semEsquema : semEsquema.slice(0, i);
}

/**
 * Data-URL PNG do QR do link curto (import dinâmico: só quem gera folheto paga).
 * @param {string} shareUrl
 * @returns {Promise<string>}
 */
export async function generateShareQrDataUrl(shareUrl) {
  const QRCode = (await import('qrcode')).default;
  return QRCode.toDataURL(shareUrl, { errorCorrectionLevel: 'M', margin: 0, width: 300 });
}
```

`generateFolhetoHtml(louvores, { shareUrl = null, qrDataUrl = null } = {})` — montar `bandaQr` (string vazia quando falta um dos dois):

```js
const bandaQr = shareUrl && qrDataUrl
  ? `<div style="background:#4B2D2B;padding:12px 28px;text-align:center;border-top:2px solid #D4AF37;">
      <div style="display:inline-block;padding:6px;background:#FFFFFF;border:1px solid #D4AF37;border-radius:6px;line-height:0;">
        <img src="${qrDataUrl}" width="150" height="150" alt="QR code do link da lista" style="display:block;width:150px;height:150px;" />
      </div>
      <div style="margin-top:6px;font-size:12px;font-weight:700;color:#D4AF37;letter-spacing:1px;">Abrir lista no PLPCG</div>
      <div style="margin-top:4px;font-size:11px;color:#A89080;letter-spacing:0.5px;">${folhetoDisplayUrl(shareUrl)}</div>
    </div>`
  : '';
```

inserida entre `${linhas}` e a divisória de 6 px; e envolver todo o retorno em `<div style="padding:16px;background:#4B2D2B;display:inline-block;">…</div>` (mesmo motivo do v2: o WhatsApp iOS apara ~3% da borda de imagem enviada com legenda — dizer isso no JSDoc). Em `generateFolhetoImage`, antes de chamar `html2canvas`, aguardar as imagens: `await Promise.all(Array.from(container.querySelectorAll('img')).map(img => img.decode().catch(() => {})));`. Em `shareFolheto`:

```js
/** @type {{ files: File[]; title: string; text?: string }} */
const shareData = { files: [file], title: 'Folheto de Louvores' };
if (isShortShareUrl(shareUrl)) shareData.text = `${playlistName}\n\n${shareUrl}`;
if (navigator.canShare && navigator.canShare(shareData) && navigator.share) {
  await navigator.share(shareData);
  return;
}
```

(o `shareUrl` já era parâmetro e estava sem uso — agora é usado; atualizar o JSDoc.)

- [ ] **Step 3: `npm install qrcode@^1.5.4`** e confirmar que `package.json`/`package-lock.json` mudaram.

- [ ] **Step 4: `CarouselChips.svelte` `handleFolheto`** — calcular a URL antes do HTML e gerar o QR só no formato curto:

```js
const folhetoLouvores = $carousel.map(l => ({ nome: l.nome, numero: l.numero }));
const pdfIds = $carousel.map(l => l.pdfId);
const playlistName = savedPlaylistMatch?.nome || generateDefaultPlaylistName();
const shareUrl = generatePlaylistShareUrl(pdfIds, playlistName, $louvores);
const qrDataUrl = isShortShareUrl(shareUrl) ? await generateShareQrDataUrl(shareUrl) : null;
const html = generateFolhetoHtml(folhetoLouvores, { shareUrl, qrDataUrl });
const imageBlob = await generateFolhetoImage(html);
await shareFolheto(imageBlob, shareUrl, playlistName);
```

(importar `isShortShareUrl`, `generateShareQrDataUrl` de `$lib/utils/folhetoUtils`.)

- [ ] **Step 5: Rodar** `npm test` (todos), `npm run check` antes (em `main`, só para contar) e depois — não pode aparecer diagnóstico novo em `folhetoUtils.js`/`CarouselChips.svelte`; anotar as duas contagens no report. `npm run build` deve passar.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json src/lib/utils/folhetoUtils.js src/lib/utils/folhetoUtils.test.js src/lib/components/CarouselChips.svelte
git commit -m "feat(folheto): legenda com link curto e QR code no folheto (paridade com v2)"
```

---

## Ordem de execução e rollout
1. Tasks 1–3 no worktree do coldigui (`feat/leaflet-qr-share`).
2. Sair do worktree (git em repo irmão é bloqueado dentro dele) e rodar a Task 4 no plpcjf.
3. Revisão final por repo; merge `feat/leaflet-qr-share` → `web/integration` (coldigui) e → `main` (plpcjf); deploy web dos dois (`scripts/web_deploy.sh`, `npm run deploy`) **só com autorização do dono**.
4. Validação manual: iOS → Folheto → WhatsApp (imagem inteira, QR menor, legenda); lista mista → dialog; plpcjf → Folheto → WhatsApp com legenda + QR.
