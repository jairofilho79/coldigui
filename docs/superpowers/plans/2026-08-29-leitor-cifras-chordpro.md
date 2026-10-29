# Leitor de cifras ChordPro — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconhecer materiais `type: "chord"` do coldigom numa seção "Cifras" do bottom sheet e abri-los numa rota `/cifra` que renderiza ChordPro com tema claro/escuro e barras vermelhas indicando a sílaba do acorde.

**Architecture:** Entidade `ChordMaterial` própria no domínio, com id no mesmo espaço do `pdfId` (`encodePdfId(r2Key)`), de modo que carousel e playlist funcionem sem mudança de persistência. Um discriminador único (`materialIdKindOf`) decodifica o id, olha a extensão e decide entre `/cifra` e `/leitor`. O parser converte cada linha numa lista de células `{acorde?, encostado, texto}`, e o renderer empilha acorde sobre texto num `Wrap`, desenhando a barra vermelha na borda esquerda do texto quando a célula está encostada.

**Tech Stack:** Flutter, Riverpod (Notifier/Provider), go_router (`StatefulShellRoute`), dio, shared_preferences, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-29-leitor-cifras-chordpro-design.md`

## Global Constraints

- Branch: `web/integration`. Não criar branch nova; a árvore já tem 115 arquivos modificados de trabalho anterior — **commitar apenas os arquivos que cada task tocar**, nunca `git add -A`.
- Idioma de doc-comments e strings de UI: português, como o resto do repo.
- Todo texto visível ao usuário passa por l10n (`lib/l10n/app_pt.arb` + `app_en.arb`), nunca hardcoded no widget.
- Após editar qualquer `.arb`, rodar `flutter gen-l10n` e commitar os `app_localizations*.dart` gerados junto.
- Rodar testes com `flutter test <caminho> -r compact`.
- Cores vêm de `AppColors` (`lib/core/theme/color_extensions.dart`); tipografia de `AppTypography` (`lib/core/theme/app_typography.dart`).
- Nenhuma task consome `raw_chordpros` nem `chordpro_staging`. A única fonte é o `.chord` no R2.
- O app tem paleta litúrgica única. O claro/escuro desta feature é **local ao leitor de cifras** e não pode vazar para `ThemeData` global.

---

### Task 1: Discriminador de tipo de material

Ponto único que decide se um id representa PDF ou cifra. Todas as tasks seguintes dependem dele.

**Files:**
- Create: `lib/core/utils/material_id_kind.dart`
- Test: `test/unit/core/material_id_kind_test.dart`

**Interfaces:**
- Consumes: `PdfPathNormalizer.getPdfRelPath` de `lib/core/utils/pdf_path_normalizer.dart` (já existe).
- Produces: `enum MaterialIdKind { pdf, chord, unknown }` e `MaterialIdKind materialIdKindOf(String id)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/core/material_id_kind_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('materialIdKindOf', () {
    test('reconhece material PDF', () {
      final id = encodePdfId('assets/praises/abc/def.pdf');
      expect(materialIdKindOf(id), MaterialIdKind.pdf);
    });

    test('reconhece material de cifra', () {
      final id = encodePdfId('assets/praises/abc/def.chord');
      expect(materialIdKindOf(id), MaterialIdKind.chord);
    });

    test('ignora caixa da extensao', () {
      final id = encodePdfId('assets/praises/abc/def.CHORD');
      expect(materialIdKindOf(id), MaterialIdKind.chord);
    });

    test('classifica extensao desconhecida como unknown', () {
      final id = encodePdfId('assets/praises/abc/def.mp3');
      expect(materialIdKindOf(id), MaterialIdKind.unknown);
    });

    test('devolve unknown em id invalido sem lancar', () {
      expect(materialIdKindOf('nao-e-base64-valido!!!'), MaterialIdKind.unknown);
    });

    test('devolve unknown em id vazio', () {
      expect(materialIdKindOf(''), MaterialIdKind.unknown);
    });

    test('aceita pdfId do manifest PLPCG sem prefixo assets/', () {
      final id = encodePdfId('ColAdultos/001.pdf');
      expect(materialIdKindOf(id), MaterialIdKind.pdf);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/core/material_id_kind_test.dart -r compact`
Expected: FAIL — `Error: Couldn't resolve the package 'coldigui/core/utils/material_id_kind.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/utils/material_id_kind.dart
import 'pdf_path_normalizer.dart';

/// Tipo de material que um id (`pdfId`) representa.
///
/// Cifra e PDF compartilham o mesmo espaço de ids — Base64 URL-safe do path
/// relativo do asset — para que carousel e playlist não precisem de um segundo
/// espaço de ids. O tipo é recuperado decodificando o id e olhando a extensão.
enum MaterialIdKind { pdf, chord, unknown }

/// Classifica [id] pela extensão do path que ele codifica.
///
/// Retorna [MaterialIdKind.unknown] para id inválido — nunca lança.
MaterialIdKind materialIdKindOf(String id) {
  if (id.isEmpty) return MaterialIdKind.unknown;

  final String relPath;
  try {
    relPath = PdfPathNormalizer.getPdfRelPath(id);
  } on Object {
    return MaterialIdKind.unknown;
  }

  final lower = relPath.toLowerCase();
  if (lower.endsWith('.pdf')) return MaterialIdKind.pdf;
  if (lower.endsWith('.chord')) return MaterialIdKind.chord;
  return MaterialIdKind.unknown;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/core/material_id_kind_test.dart -r compact`
Expected: PASS — 7 testes

Se o teste de id inválido falhar com exceção em vez de `unknown`, é porque `base64.decode` lançou `FormatException` fora do `try`. Confirme que a chamada a `getPdfRelPath` está dentro do bloco.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/material_id_kind.dart test/unit/core/material_id_kind_test.dart
git commit -m "feat(chords): add material id kind discriminator"
```

---

### Task 2: URL de asset coldigom compartilhada

Extrai a montagem de URL (proxy na web, direto no nativo) de `AudioTrackUrl` para um util compartilhado, para o fetch de cifra reusar sem duplicar.

**Files:**
- Create: `lib/core/utils/coldigom_asset_url.dart`
- Modify: `lib/features/audio_player/domain/utils/audio_track_url.dart`
- Test: `test/unit/core/coldigom_asset_url_test.dart`
- Test (regressão, já existe): `test/unit/features/audio_player/audio_track_url_test.dart`

**Interfaces:**
- Consumes: `AssetBaseUrlResolver.joinAssetUrl` de `lib/core/utils/asset_base_url_resolver.dart`.
- Produces: `abstract final class ColdigomAssetUrl` com `String directUrlForKey(String r2Key)` e `String fetchUrlForKey(String r2Key, {required String apiBase})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/core/coldigom_asset_url_test.dart
import 'package:coldigui/core/utils/coldigom_asset_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = 'assets/praises/abc/def.chord';

  group('ColdigomAssetUrl.fetchUrlForKey', () {
    test('monta proxy same-policy quando ha apiBase', () {
      expect(
        ColdigomAssetUrl.fetchUrlForKey(key, apiBase: 'https://plpcg.com'),
        'https://plpcg.com/api/coldigom/assets/praises/abc/def.chord',
      );
    });

    test('remove barra final do apiBase', () {
      expect(
        ColdigomAssetUrl.fetchUrlForKey(key, apiBase: 'https://plpcg.com/'),
        'https://plpcg.com/api/coldigom/assets/praises/abc/def.chord',
      );
    });

    test('remove barra inicial da chave', () {
      expect(
        ColdigomAssetUrl.fetchUrlForKey('/$key', apiBase: 'https://plpcg.com'),
        'https://plpcg.com/api/coldigom/assets/praises/abc/def.chord',
      );
    });

    test('cai para URL direta quando apiBase vazio', () {
      final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: '');
      expect(url, endsWith('/assets/praises/abc/def.chord'));
      expect(url, startsWith('https://'));
    });

    test('devolve a propria chave quando ja e URL absoluta', () {
      const absolute = 'https://exemplo.com/x.chord';
      expect(
        ColdigomAssetUrl.fetchUrlForKey(absolute, apiBase: 'https://plpcg.com'),
        absolute,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/core/coldigom_asset_url_test.dart -r compact`
Expected: FAIL — pacote `coldigui/core/utils/coldigom_asset_url.dart` não resolve

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/utils/coldigom_asset_url.dart
import 'asset_base_url_resolver.dart';

/// URL HTTP para assets coldigom (`assets/praises/...`).
///
/// Na web o fetch passa pelo proxy same-policy `/api/coldigom/<chave>` em
/// [AppConfig.apiBaseUrl], que devolve `cross-origin-resource-policy:
/// cross-origin` e portanto sobrevive ao COEP exigido pelo pdfrx. No nativo,
/// e como fallback quando não há base configurada, usa a URL direta do worker.
///
/// Compartilhado por [AudioTrackUrl] e pelo datasource de cifras.
abstract final class ColdigomAssetUrl {
  /// URL direta no worker coldigom.
  static String directUrlForKey(String r2Key) {
    final key = r2Key.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return key;
    }
    return AssetBaseUrlResolver.joinAssetUrl(key);
  }

  /// URL de fetch — proxy quando [apiBase] existe, direta caso contrário.
  static String fetchUrlForKey(String r2Key, {required String apiBase}) {
    final key = r2Key.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return key;
    }

    final trimmedBase = apiBase.trim();
    if (trimmedBase.isEmpty) return directUrlForKey(key);

    final normalized = key.startsWith('/') ? key.substring(1) : key;
    final base = trimmedBase.endsWith('/')
        ? trimmedBase.substring(0, trimmedBase.length - 1)
        : trimmedBase;
    return '$base/api/coldigom/$normalized';
  }
}
```

- [ ] **Step 4: Delegar `AudioTrackUrl` ao util novo**

Substituir os corpos de `fetchUrlForKey` e `directUrlForKey` em `lib/features/audio_player/domain/utils/audio_track_url.dart`, mantendo a API pública intacta:

```dart
  /// Monta URL de fetch via proxy — testável sem [kIsWeb].
  static String fetchUrlForKey(String r2Key, {required String apiBase}) {
    return ColdigomAssetUrl.fetchUrlForKey(r2Key, apiBase: apiBase);
  }

  static String directUrlForKey(String r2Key) {
    return ColdigomAssetUrl.directUrlForKey(r2Key);
  }
```

Adicionar o import `package:coldigui/core/utils/coldigom_asset_url.dart` e remover o de `asset_base_url_resolver.dart` se ficar sem uso.

- [ ] **Step 5: Run tests to verify both pass**

Run: `flutter test test/unit/core/coldigom_asset_url_test.dart test/unit/features/audio_player/audio_track_url_test.dart -r compact`
Expected: PASS nos dois arquivos. O teste de áudio existente é a rede de segurança do refactor — se ele quebrar, a delegação mudou comportamento e precisa ser corrigida, não o teste.

- [ ] **Step 6: Commit**

```bash
git add lib/core/utils/coldigom_asset_url.dart \
        lib/features/audio_player/domain/utils/audio_track_url.dart \
        test/unit/core/coldigom_asset_url_test.dart
git commit -m "refactor(core): extract coldigom asset url building for reuse"
```

---

### Task 3: Parser ChordPro

O núcleo da feature. Converte o texto do `.chord` em estrutura, decidindo por acorde se ele encosta em texto.

**Files:**
- Create: `lib/features/chords/domain/entities/chordpro_song.dart`
- Create: `lib/features/chords/domain/usecases/parse_chordpro.dart`
- Test: `test/unit/features/chords/parse_chordpro_test.dart`

**Interfaces:**
- Consumes: nada além do SDK.
- Produces: `ChordCell({String? chord, bool attached, required String text})`, `sealed class ChordProLine` com `ChordProLyricLine(List<ChordCell> cells)`, `ChordProCommentLine(String text)`, `ChordProStanzaBreak()`, `ChordProSong({String title, subtitle, key, rhythm, artist, List<ChordProLine> lines})` com getter `bool get hasLyrics`, e a função `ChordProSong parseChordPro(String source)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/features/chords/parse_chordpro_test.dart
import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

List<ChordCell> _cellsOf(String line) {
  final song = parseChordPro(line);
  return (song.lines.whereType<ChordProLyricLine>().first).cells;
}

void main() {
  group('cabecalho', () {
    test('le as cinco diretivas conhecidas', () {
      final song = parseChordPro(
        '{title: Comigo Habita}\n'
        '{subtitle: 692}\n'
        '{key: Eb}\n'
        '{rhythm: Cancao}\n'
        '{artist: J.G.R}\n'
        '\n'
        'A [Bb]noite [Eb]vem,\n',
      );
      expect(song.title, 'Comigo Habita');
      expect(song.subtitle, '692');
      expect(song.key, 'Eb');
      expect(song.rhythm, 'Cancao');
      expect(song.artist, 'J.G.R');
    });

    test('trata valor vazio e "?" como ausente', () {
      final song = parseChordPro('{key: }\n{subtitle: ?}\nletra\n');
      expect(song.key, '');
      expect(song.subtitle, '');
    });

    test('ignora diretiva desconhecida em silencio', () {
      final song = parseChordPro('{meta: column left}\nletra\n');
      expect(song.lines.whereType<ChordProLyricLine>(), hasLength(1));
    });

    test('diretiva comment vira linha de comentario', () {
      final song = parseChordPro('{comment: Instrumentos: C Am}\nletra\n');
      expect(
        song.lines.whereType<ChordProCommentLine>().single.text,
        'Instrumentos: C Am',
      );
    });
  });

  group('linhas nao-letra', () {
    test('linha iniciada por ; nao e renderizada', () {
      final song = parseChordPro('; recado de pipeline\nletra\n');
      expect(song.lines.whereType<ChordProCommentLine>(), isEmpty);
      expect(song.lines.whereType<ChordProLyricLine>(), hasLength(1));
    });

    test('brancos consecutivos colapsam em um separador', () {
      final song = parseChordPro('a\n\n\n\nb\n');
      expect(song.lines.whereType<ChordProStanzaBreak>(), hasLength(1));
    });

    test('hasLyrics e falso quando so ha diretivas e comentarios ;', () {
      final song = parseChordPro(
        '{title: Clama, o igreja}\n{key: }\n\n; a cifra errada foi removida.\n',
      );
      expect(song.hasLyrics, isFalse);
    });

    test('hasLyrics e verdadeiro com ao menos uma linha de letra', () {
      expect(parseChordPro('{title: X}\n\nletra\n').hasLyrics, isTrue);
    });
  });

  group('adjacencia — encostado', () {
    test('texto a esquerda e a direita', () {
      final cells = _cellsOf('ha[Cm]bi');
      expect(cells.map((c) => c.chord), [null, 'Cm']);
      expect(cells[1].attached, isTrue);
      expect(cells[1].text, 'bi');
    });

    test('espaco a esquerda, texto a direita', () {
      final cells = _cellsOf('o [Ab]Deus');
      expect(cells[0].text, 'o ');
      expect(cells[1].chord, 'Ab');
      expect(cells[1].attached, isTrue);
    });

    test('inicio de linha, texto a direita', () {
      final cells = _cellsOf('[Eb]Comigo');
      expect(cells, hasLength(1));
      expect(cells.single.chord, 'Eb');
      expect(cells.single.attached, isTrue);
      expect(cells.single.text, 'Comigo');
    });

    test('texto a esquerda, fim de linha a direita', () {
      final cells = _cellsOf('monte Sinai[C#m7]');
      expect(cells.last.chord, 'C#m7');
      expect(cells.last.attached, isTrue);
      expect(cells.last.text, isEmpty);
    });

    test('texto a esquerda, espaco a direita', () {
      final cells = _cellsOf('a[Am]bri -[D]   [G]go.');
      final d = cells.firstWhere((c) => c.chord == 'D');
      expect(d.attached, isTrue);
      expect(d.text, '   ');
    });
  });

  group('adjacencia — solto', () {
    test('espaco dos dois lados', () {
      final cells = _cellsOf('fim [C] outro');
      final c = cells.firstWhere((c) => c.chord == 'C');
      expect(c.attached, isFalse);
    });

    test('espaco a esquerda, fim de linha a direita', () {
      final cells = _cellsOf('Deus e Amor [C]');
      expect(cells.last.chord, 'C');
      expect(cells.last.attached, isFalse);
    });

    test('inicio de linha, espaco a direita', () {
      final cells = _cellsOf('[E]   A linda');
      expect(cells.single.chord, 'E');
      expect(cells.single.attached, isFalse);
    });
  });

  group('espacamento preservado', () {
    test('um espaco e tres espacos produzem textos diferentes', () {
      final um = _cellsOf('Deus e Amor [C]');
      final tres = _cellsOf('Deus e Amor   [C]');
      expect(um.first.text, 'Deus e Amor ');
      expect(tres.first.text, 'Deus e Amor   ');
    });

    test('nao faz trim da linha', () {
      final cells = _cellsOf('   recuado');
      expect(cells.single.text, '   recuado');
    });
  });

  group('defensivo', () {
    test('colchete escapado vira texto literal', () {
      final cells = _cellsOf(r'a\[b\]c');
      expect(cells.single.chord, isNull);
      expect(cells.single.text, 'a[b]c');
    });

    test('colchete vazio vira texto literal', () {
      final cells = _cellsOf('a[]b');
      expect(cells.single.chord, isNull);
      expect(cells.single.text, 'a[]b');
    });

    test('colchete sem fechamento vira texto literal', () {
      final cells = _cellsOf('a[Cm b');
      expect(cells.single.chord, isNull);
      expect(cells.single.text, 'a[Cm b');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/features/chords/parse_chordpro_test.dart -r compact`
Expected: FAIL — pacotes `chordpro_song.dart` e `parse_chordpro.dart` não resolvem

- [ ] **Step 3: Write the entities**

```dart
// lib/features/chords/domain/entities/chordpro_song.dart

/// Célula de renderização — um acorde opcional sobre um trecho de texto.
///
/// [text] preserva o espaço em branco literal da fonte, então
/// `"Deus é Amor [C]"` e `"Deus é Amor   [C]"` produzem células diferentes sem
/// nenhum cálculo especial no renderer.
class ChordCell {
  const ChordCell({this.chord, this.attached = false, required this.text});

  /// Rótulo do acorde (`Cm`, `G/B`), ou `null` no trecho sem acorde.
  final String? chord;

  /// `true` quando o acorde encosta em texto — desenha a barra vermelha na
  /// borda esquerda de [text]. `false` quando o acorde está solto entre espaços.
  final bool attached;

  /// Trecho de letra que vai sob o acorde, com espaços preservados.
  final String text;
}

/// Linha do documento ChordPro já estruturada.
sealed class ChordProLine {
  const ChordProLine();
}

/// Linha de letra — sequência de células.
class ChordProLyricLine extends ChordProLine {
  const ChordProLyricLine(this.cells);

  final List<ChordCell> cells;
}

/// `{comment: ...}` — recado dirigido ao músico, renderizado em itálico.
class ChordProCommentLine extends ChordProLine {
  const ChordProCommentLine(this.text);

  final String text;
}

/// Separador de estrofe (uma ou mais linhas em branco).
class ChordProStanzaBreak extends ChordProLine {
  const ChordProStanzaBreak();
}

/// Documento ChordPro estruturado.
class ChordProSong {
  const ChordProSong({
    this.title = '',
    this.subtitle = '',
    this.key = '',
    this.rhythm = '',
    this.artist = '',
    this.lines = const [],
  });

  final String title;
  final String subtitle;
  final String key;
  final String rhythm;
  final String artist;
  final List<ChordProLine> lines;

  /// `false` quando o arquivo só tem diretivas e comentários — uma lápide de
  /// pipeline. O sheet não lista e o leitor mostra o estado de indisponível,
  /// mesmo o HTTP tendo respondido 200.
  bool get hasLyrics => lines.any((line) => line is ChordProLyricLine);
}
```

- [ ] **Step 4: Write the parser**

```dart
// lib/features/chords/domain/usecases/parse_chordpro.dart
import '../entities/chordpro_song.dart';

final _directiveRe = RegExp(r'^\{([^:}]+):\s*(.*)\}$');

/// Converte o conteúdo de um `.chord` em [ChordProSong].
///
/// Não normaliza acordes, não transpõe e não corrige OCR — só estrutura.
/// Ver §3.3 da spec para as regras.
ChordProSong parseChordPro(String source) {
  var title = '';
  var subtitle = '';
  var key = '';
  var rhythm = '';
  var artist = '';
  final lines = <ChordProLine>[];

  for (final raw in source.split('\n')) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      // Brancos consecutivos colapsam num separador só.
      if (lines.isNotEmpty && lines.last is! ChordProStanzaBreak) {
        lines.add(const ChordProStanzaBreak());
      }
      continue;
    }

    // Comentário de autoria: recado de pipeline, não é conteúdo do usuário.
    if (trimmed.startsWith(';')) continue;

    final directive = _directiveRe.firstMatch(trimmed);
    if (directive != null) {
      final name = directive.group(1)!.trim().toLowerCase();
      final value = _directiveValue(directive.group(2)!);
      switch (name) {
        case 'title':
          title = value;
        case 'subtitle':
          subtitle = value;
        case 'key':
          key = value;
        case 'rhythm':
          rhythm = value;
        case 'artist':
          artist = value;
        case 'comment':
          if (value.isNotEmpty) lines.add(ChordProCommentLine(value));
        default:
          break; // meta, column e quaisquer outras: ignoradas em silêncio.
      }
      continue;
    }

    lines.add(ChordProLyricLine(parseChordProLine(raw)));
  }

  // Um separador no fim não representa estrofe nenhuma.
  while (lines.isNotEmpty && lines.last is ChordProStanzaBreak) {
    lines.removeLast();
  }

  return ChordProSong(
    title: title,
    subtitle: subtitle,
    key: key,
    rhythm: rhythm,
    artist: artist,
    lines: lines,
  );
}

/// Quebra uma linha de letra em células.
///
/// Público para teste direto; [parseChordPro] é o ponto de entrada normal.
List<ChordCell> parseChordProLine(String line) {
  final cells = <ChordCell>[];
  final buffer = StringBuffer();
  String? pendingChord;
  var pendingAttached = false;

  void flush() {
    cells.add(
      ChordCell(
        chord: pendingChord,
        attached: pendingAttached,
        text: buffer.toString(),
      ),
    );
    buffer.clear();
  }

  var i = 0;
  while (i < line.length) {
    final char = line[i];

    // Colchete escapado: texto literal.
    if (char == r'\' &&
        i + 1 < line.length &&
        (line[i + 1] == '[' || line[i + 1] == ']')) {
      buffer.write(line[i + 1]);
      i += 2;
      continue;
    }

    if (char == '[') {
      final close = line.indexOf(']', i + 1);
      final label = close == -1 ? '' : line.substring(i + 1, close);

      // Sem fechamento ou rótulo vazio: texto literal.
      if (close == -1 || label.isEmpty) {
        buffer.write(char);
        i += 1;
        continue;
      }

      flush();

      // Adjacência lida da linha original, não do buffer já desescapado.
      final before = i > 0 ? line[i - 1] : null;
      final after = close + 1 < line.length ? line[close + 1] : null;
      final attachLeft = before != null && before.trim().isNotEmpty;
      final attachRight = after != null && after.trim().isNotEmpty;

      pendingChord = label;
      pendingAttached = attachLeft || attachRight;
      i = close + 1;
      continue;
    }

    buffer.write(char);
    i += 1;
  }

  flush();

  // Célula vazia antes do primeiro acorde não vira nada renderizável.
  if (cells.length > 1 &&
      cells.first.chord == null &&
      cells.first.text.isEmpty) {
    cells.removeAt(0);
  }

  return cells;
}

/// Valor de diretiva; `''` e `'?'` contam como ausente.
String _directiveValue(String raw) {
  final value = raw.trim();
  return value == '?' ? '' : value;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/unit/features/chords/parse_chordpro_test.dart -r compact`
Expected: PASS — 20 testes

Se `colchete sem fechamento` falhar, confira que o `[` sem `]` cai no ramo de texto literal escrevendo **só o `[`** e avançando 1, não o resto da linha.

- [ ] **Step 6: Commit**

```bash
git add lib/features/chords/domain/entities/chordpro_song.dart \
        lib/features/chords/domain/usecases/parse_chordpro.dart \
        test/unit/features/chords/parse_chordpro_test.dart
git commit -m "feat(chords): add chordpro parser with chord adjacency detection"
```

---

### Task 4: Golden test com arquivos reais

Trava o parser contra o corpus publicado de verdade, não só contra strings sintéticas.

**Files:**
- Create: `test/fixtures/chordpro/comigo_habita.chord`
- Create: `test/fixtures/chordpro/confio_em_deus.chord`
- Create: `test/fixtures/chordpro/tombstone.chord`
- Test: `test/unit/features/chords/parse_chordpro_golden_test.dart`

**Interfaces:**
- Consumes: `parseChordPro` da Task 3.
- Produces: fixtures reutilizadas pelas tasks de widget.

- [ ] **Step 1: Baixar os três fixtures do corpus publicado**

```bash
mkdir -p test/fixtures/chordpro
BASE=https://coldigom-api.jairofilho79.workers.dev/assets/praises
curl -sf "$BASE/9a5d4232-00ba-4294-b204-8d1701a24894/c9e5f567-865c-425f-b454-069973dbcbee.chord" \
  -o test/fixtures/chordpro/comigo_habita.chord
curl -sf "$BASE/002bbc89-cf6c-4002-b64c-c538bdbf47e2/e11034e9-b577-4122-880b-b000b2b21023.chord" \
  -o test/fixtures/chordpro/confio_em_deus.chord
curl -sf "$BASE/bb38bd5c-8f92-4557-8f08-8a5b3b097be5/a3b45c8d-c61e-45a5-9cb3-5935e0f17704.chord" \
  -o test/fixtures/chordpro/tombstone.chord
wc -c test/fixtures/chordpro/*.chord
```

Esperado: três arquivos não vazios (≈1169 B, ≈900 B, 239 B). Se algum vier vazio, o `.chord` saiu do ar — escolha outro da lista de publicados rodando o scan da spec e ajuste o teste.

- [ ] **Step 2: Write the failing test**

```dart
// test/unit/features/chords/parse_chordpro_golden_test.dart
import 'dart:io';

import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    File('test/fixtures/chordpro/$name').readAsStringSync();

void main() {
  test('comigo habita: cabecalho e primeira linha de letra', () {
    final song = parseChordPro(_fixture('comigo_habita.chord'));

    expect(song.title, 'Comigo Habita, Ó Deus');
    expect(song.key, 'Eb');
    expect(song.hasLyrics, isTrue);

    final first = song.lines.whereType<ChordProLyricLine>().first;
    expect(first.cells.map((c) => c.chord).toList(), [
      'Eb',
      'Bb',
      'Cm',
      'Gm',
      'Ab',
    ]);
    // "[Eb]Co - [Bb]migo ha[Cm]bi - [Gm]ta, ó [Ab]Deus!" — todos encostam.
    expect(first.cells.every((c) => c.attached), isTrue);
  });

  test('confio em deus: intro solta com espacamento preservado', () {
    final song = parseChordPro(_fixture('confio_em_deus.chord'));

    final intro = song.lines
        .whereType<ChordProLyricLine>()
        .firstWhere((l) => l.cells.first.text.startsWith('   '));

    expect(intro.cells.first.chord, 'E');
    expect(intro.cells.first.attached, isFalse);
    expect(intro.cells.first.text, startsWith('   A linda'));
  });

  test('tombstone: 200 mas sem letra nenhuma', () {
    final song = parseChordPro(_fixture('tombstone.chord'));

    expect(song.title, isNotEmpty);
    expect(song.hasLyrics, isFalse);
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/unit/features/chords/parse_chordpro_golden_test.dart -r compact`
Expected: PASS — 3 testes. O parser da Task 3 já deve satisfazê-los; se algum falhar, é bug do parser, não do teste.

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/chordpro test/unit/features/chords/parse_chordpro_golden_test.dart
git commit -m "test(chords): pin parser against published chordpro corpus"
```

---

### Task 5: Entidade ChordMaterial e adapter

**Files:**
- Create: `lib/features/chords/domain/entities/chord_material.dart`
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`
- Test: `test/unit/features/chords/chord_material_adapter_test.dart`

**Interfaces:**
- Consumes: `encodePdfId` de `lib/core/utils/pdf_id_codec.dart`; `PraiseDetailDto` de `lib/features/coldigom/data/models/praise_dto.dart`.
- Produces: `class ChordMaterial` e `ColdigomLouvorAdapter.toChordMaterials(PraiseDetailDto) → List<ChordMaterial>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/features/chords/chord_material_adapter_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

PraiseDetailDto _praise(List<Map<String, dynamic>> materials) {
  return PraiseDetailDto.fromJson({
    'id': 'praise-1',
    'name': 'Comigo habita',
    'number': '692',
    'rhythm': 'Cancao',
    'author': 'J.G.R',
    'materials': materials,
  });
}

void main() {
  test('cria um ChordMaterial por material type chord', () {
    final items = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m1.chord',
          'material_kind_name': 'Cifra I',
        },
        {
          'id': 'm2',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m2.chord',
          'material_kind_name': 'Cifra II',
        },
      ]),
    );

    expect(items, hasLength(2));
    expect(items.map((i) => i.categoria), ['Cifra I', 'Cifra II']);
    expect(items.first.nome, 'Comigo habita');
    expect(items.first.numero, '692');
    expect(items.first.groupId, 'praise-1');
    expect(items.first.author, 'J.G.R');
    expect(items.first.classificacao, 'Cancao');
    expect(items.first.source, LouvorDataSource.coldigom);
  });

  test('o chordId cai no mesmo espaco do pdfId e e reconhecido como cifra', () {
    final item = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m1.chord',
          'material_kind_name': 'Cifra',
        },
      ]),
    ).single;

    expect(materialIdKindOf(item.chordId), MaterialIdKind.chord);
    expect(item.r2Key, 'assets/praises/praise-1/m1.chord');
  });

  test('ignora materiais de outros tipos', () {
    final items = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'pdf',
          'r2_key': 'assets/praises/praise-1/m1.pdf',
          'material_kind_name': 'Cifra',
        },
        {
          'id': 'm2',
          'type': 'mp3',
          'r2_key': 'assets/praises/praise-1/m2.mp3',
          'material_kind_name': 'Audio',
        },
      ]),
    );

    expect(items, isEmpty);
  });

  test('ignora chord sem r2_key utilizavel', () {
    final items = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {'id': 'm1', 'type': 'chord', 'r2_key': null},
        {'id': 'm2', 'type': 'chord', 'r2_key': ''},
      ]),
    );

    expect(items, isEmpty);
  });

  test('usa "Cifra" como categoria padrao sem material_kind_name', () {
    final item = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m1.chord',
        },
      ]),
    ).single;

    expect(item.categoria, 'Cifra');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/features/chords/chord_material_adapter_test.dart -r compact`
Expected: FAIL — `The method 'toChordMaterials' isn't defined`

- [ ] **Step 3: Write the entity**

```dart
// lib/features/chords/domain/entities/chord_material.dart
import '../../../catalog/domain/entities/louvor_data_source.dart';

/// Material de cifra ChordPro coldigom — abre em `/cifra`.
///
/// Espelha `YoutubeMaterial` na forma, mas com uma diferença deliberada:
/// [chordId] vive no mesmo espaço de ids do `pdfId` (Base64 URL-safe do path
/// relativo), para que carousel e playlist funcionem sem um segundo espaço de
/// ids. Ver `materialIdKindOf` em `lib/core/utils/material_id_kind.dart`.
class ChordMaterial {
  const ChordMaterial({
    required this.chordId,
    required this.r2Key,
    required this.nome,
    required this.numero,
    required this.groupId,
    required this.categoria,
    required this.classificacao,
    this.author = '',
    this.source = LouvorDataSource.coldigom,
  });

  /// `encodePdfId(r2Key)` — mesmo espaço do `pdfId`.
  final String chordId;

  /// Chave do asset no R2 (`assets/praises/<praise>/<material>.chord`).
  final String r2Key;

  final String nome;
  final String numero;
  final String groupId;

  /// Label do kind: `Cifra`, `Cifra I`, `Cifra II`.
  final String categoria;

  final String classificacao;
  final String author;
  final LouvorDataSource source;
}
```

- [ ] **Step 4: Add the adapter method**

Em `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`, adicionar o import de `chord_material.dart` e o método, logo após `toYoutubeMaterials`:

```dart
  /// Um [ChordMaterial] por `type: chord` com `r2_key` válido.
  static List<ChordMaterial> toChordMaterials(PraiseDetailDto praise) {
    final items = <ChordMaterial>[];

    for (final material in praise.materials) {
      if (material.type.toLowerCase() != 'chord') continue;
      final r2Key = material.r2Key;
      if (r2Key == null || r2Key.isEmpty) continue;

      items.add(
        ChordMaterial(
          chordId: encodePdfId(r2Key),
          r2Key: r2Key,
          nome: praise.name,
          numero: praise.number,
          groupId: praise.id,
          categoria: material.materialKindName ?? 'Cifra',
          classificacao: praise.rhythm,
          author: praise.author,
          source: LouvorDataSource.coldigom,
        ),
      );
    }

    return items;
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/unit/features/chords/chord_material_adapter_test.dart -r compact`
Expected: PASS — 5 testes

- [ ] **Step 6: Commit**

```bash
git add lib/features/chords/domain/entities/chord_material.dart \
        lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart \
        test/unit/features/chords/chord_material_adapter_test.dart
git commit -m "feat(chords): add ChordMaterial entity and coldigom adapter"
```

---

### Task 6: Datasource de conteúdo e cache

Busca o `.chord`, faz o parse e resolve disponibilidade numa ida à rede só.

**Files:**
- Create: `lib/features/chords/data/datasources/chord_content_datasource.dart`
- Create: `lib/features/chords/data/providers/chord_providers.dart`
- Test: `test/unit/features/chords/chord_content_datasource_test.dart`

**Interfaces:**
- Consumes: `ColdigomAssetUrl.fetchUrlForKey` (Task 2), `parseChordPro` (Task 3), `AppConfig.apiBaseUrl`, `coldigomDioProvider` de `lib/features/coldigom/data/providers/coldigom_dio_provider.dart`.
- Produces:
  - `class ChordContentDatasource` com `Future<ChordProSong?> fetchSong(String r2Key)` — `null` em 404, erro de rede ou música sem letra.
  - `chordContentDatasourceProvider` (`Provider<ChordContentDatasource>`).
  - `chordSongProvider` (`FutureProvider.family<ChordProSong?, String>`) indexado por `r2Key`, que é o cache compartilhado entre sheet e leitor.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/features/chords/chord_content_datasource_test.dart
import 'package:coldigui/features/chords/data/datasources/chord_content_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Interceptor que responde da tabela [routes] sem tocar na rede.
class _FakeAdapter extends Interceptor {
  _FakeAdapter(this.routes);

  final Map<String, (int status, String body)> routes;
  final requestedPaths = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestedPaths.add(options.path);
    final route = routes[options.path];
    if (route == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response<String>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response<String>(
        requestOptions: options,
        statusCode: route.$1,
        data: route.$2,
      ),
    );
  }
}

ChordContentDatasource _datasource(_FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return ChordContentDatasource(dio, apiBase: 'https://plpcg.com');
}

void main() {
  const key = 'assets/praises/p1/m1.chord';
  const url = 'https://plpcg.com/api/coldigom/$key';

  test('devolve a musica parseada em 200 com letra', () async {
    final adapter = _FakeAdapter({
      url: (200, '{title: Comigo}\n{key: Eb}\n\nA [Bb]noite vem,\n'),
    });

    final song = await _datasource(adapter).fetchSong(key);

    expect(song, isNotNull);
    expect(song!.title, 'Comigo');
    expect(song.hasLyrics, isTrue);
  });

  test('busca pelo proxy same-policy', () async {
    final adapter = _FakeAdapter({url: (200, 'letra\n')});

    await _datasource(adapter).fetchSong(key);

    expect(adapter.requestedPaths.single, url);
  });

  test('devolve null em 404', () async {
    final song = await _datasource(_FakeAdapter(const {})).fetchSong(key);
    expect(song, isNull);
  });

  test('devolve null quando o arquivo nao tem letra (lapide)', () async {
    final adapter = _FakeAdapter({
      url: (200, '{title: Clama}\n\n; a cifra errada foi removida.\n'),
    });

    expect(await _datasource(adapter).fetchSong(key), isNull);
  });

  test('devolve null em corpo vazio', () async {
    final adapter = _FakeAdapter({url: (200, '')});
    expect(await _datasource(adapter).fetchSong(key), isNull);
  });

  test('devolve null em r2Key vazio sem ir a rede', () async {
    final adapter = _FakeAdapter(const {});
    expect(await _datasource(adapter).fetchSong(''), isNull);
    expect(adapter.requestedPaths, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/features/chords/chord_content_datasource_test.dart -r compact`
Expected: FAIL — pacote `chord_content_datasource.dart` não resolve

- [ ] **Step 3: Write the datasource**

```dart
// lib/features/chords/data/datasources/chord_content_datasource.dart
import 'package:dio/dio.dart';

import '../../../../core/utils/coldigom_asset_url.dart';
import '../../domain/entities/chordpro_song.dart';
import '../../domain/usecases/parse_chordpro.dart';

/// Busca e parseia o conteúdo `.chord` de um material coldigom.
///
/// Uma ida à rede resolve as duas perguntas do sheet — "existe?" e "qual é o
/// conteúdo?" — porque os arquivos têm 611 B em média. Por isso não há HEAD:
/// o GET já traz tudo, e o resultado alimenta o leitor sem segunda requisição.
class ChordContentDatasource {
  const ChordContentDatasource(this._dio, {required String apiBase})
    : _apiBase = apiBase;

  final Dio _dio;
  final String _apiBase;

  /// Música parseada, ou `null` quando indisponível.
  ///
  /// `null` cobre os quatro casos em que o sheet não deve listar a cifra:
  /// chave vazia, 404, falha de rede e arquivo sem nenhuma linha de letra.
  Future<ChordProSong?> fetchSong(String r2Key) async {
    final key = r2Key.trim();
    if (key.isEmpty) return null;

    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);

    final String body;
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode != 200) return null;
      body = response.data ?? '';
    } on Object {
      return null;
    }

    if (body.trim().isEmpty) return null;

    final song = parseChordPro(body);
    return song.hasLyrics ? song : null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/features/chords/chord_content_datasource_test.dart -r compact`
Expected: PASS — 6 testes

- [ ] **Step 5: Write the providers**

```dart
// lib/features/chords/data/providers/chord_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../coldigom/data/providers/coldigom_dio_provider.dart';
import '../../domain/entities/chordpro_song.dart';
import '../datasources/chord_content_datasource.dart';

/// Datasource de conteúdo de cifra.
final chordContentDatasourceProvider = Provider<ChordContentDatasource>((ref) {
  return ChordContentDatasource(
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Música de um `r2Key`, ou `null` se indisponível.
///
/// Cache compartilhado entre o sheet (que usa o resultado para decidir se lista
/// a cifra) e o leitor (que usa para renderizar). `keepAlive` porque os
/// arquivos são minúsculos e reabrir a mesma cifra é comum.
final chordSongProvider = FutureProvider.family<ChordProSong?, String>((
  ref,
  r2Key,
) {
  ref.keepAlive();
  return ref.watch(chordContentDatasourceProvider).fetchSong(r2Key);
});
```

- [ ] **Step 6: Verify it compiles**

Run: `flutter analyze lib/features/chords`

Expected: nenhuma issue apontando para `lib/features/chords`. **Não espere "No issues found!"** — o projeto tem 1 issue `info` pré-existente e sem relação (`no_leading_underscores_for_local_identifiers` em `test/unit/features/playlists/active_playlist_sync_cloud_test.dart:258`), então o analyzer sempre termina com issue e código de saída não-zero. Ignore-a.

- [ ] **Step 7: Commit**

```bash
git add lib/features/chords/data \
        test/unit/features/chords/chord_content_datasource_test.dart
git commit -m "feat(chords): add chord content datasource with availability check"
```

---

### Task 7: Cifras no LouvorGroup

Leva `ChordMaterial` até o agrupamento, para a seção do sheet ter de onde ler.

**Files:**
- Modify: `lib/features/catalog/domain/entities/louvor_group.dart`
- Modify: `lib/features/coldigom/domain/repositories/coldigom_search_repository.dart`
- Modify: `lib/features/coldigom/data/repositories/coldigom_search_repository_impl.dart`
- Modify: `lib/features/coldigom/data/coldigom_praise_cache_warmup.dart`
- Modify: `lib/features/coldigom/data/providers/coldigom_providers.dart`
- Test: `test/unit/features/chords/louvor_group_chords_test.dart`

**Interfaces:**
- Consumes: `ChordMaterial` (Task 5), `ColdigomLouvorAdapter.toChordMaterials` (Task 5).
- Produces:
  - `LouvorGroup.chordMaterials` (`List<ChordMaterial>`), parâmetro nomeado `chordMaterials` no construtor e em `fromLouvores`, incluído em `totalMaterials` e propagado por `withColdigomMeta`.
  - `ColdigomChordMaterialsCacheNotifier` + `coldigomChordMaterialsCacheProvider` (`Map<String, ChordMaterial>` indexado por `chordId`), com `mergeChords(Iterable<ChordMaterial>)` e `findByChordId(String)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/features/chords/louvor_group_chords_test.dart
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter_test/flutter_test.dart';

ChordMaterial _chord({required String groupId, required String categoria}) {
  return ChordMaterial(
    chordId: 'id-$groupId-$categoria',
    r2Key: 'assets/praises/$groupId/$categoria.chord',
    nome: 'Comigo habita',
    numero: '692',
    groupId: groupId,
    categoria: categoria,
    classificacao: 'Cancao',
  );
}

void main() {
  test('agrupa cifras pelo mesmo groupId', () {
    final groups = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [
        _chord(groupId: 'p1', categoria: 'Cifra I'),
        _chord(groupId: 'p1', categoria: 'Cifra II'),
        _chord(groupId: 'p2', categoria: 'Cifra'),
      ],
    );

    final p1 = groups.firstWhere((g) => g.groupId == 'p1');
    expect(p1.chordMaterials.map((c) => c.categoria), ['Cifra I', 'Cifra II']);
    expect(groups.firstWhere((g) => g.groupId == 'p2').chordMaterials, hasLength(1));
  });

  test('cria grupo so com cifra, sem PDF nem audio', () {
    final groups = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [_chord(groupId: 'p1', categoria: 'Cifra')],
    );

    expect(groups, hasLength(1));
    expect(groups.single.nome, 'Comigo habita');
    expect(groups.single.numero, '692');
  });

  test('cifras entram em totalMaterials', () {
    final group = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [
        _chord(groupId: 'p1', categoria: 'Cifra I'),
        _chord(groupId: 'p1', categoria: 'Cifra II'),
      ],
    ).single;

    expect(group.totalMaterials, 2);
  });

  test('withColdigomMeta preserva as cifras', () {
    final group = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [_chord(groupId: 'p1', categoria: 'Cifra')],
    ).single;

    expect(group.withColdigomMeta(null).chordMaterials, hasLength(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/features/chords/louvor_group_chords_test.dart -r compact`
Expected: FAIL — `No named parameter with the name 'chordMaterials'`

- [ ] **Step 3: Extend LouvorGroup**

Em `lib/features/catalog/domain/entities/louvor_group.dart`, seguindo exatamente o que `youtubeMaterials` já faz:

1. Import de `../../../chords/domain/entities/chord_material.dart`.
2. Parâmetro `this.chordMaterials = const []` no construtor e o campo:

```dart
  /// Cifras ChordPro Coldigom associadas ao mesmo [groupId].
  final List<ChordMaterial> chordMaterials;
```

3. Em `isColdigom`, antes do `return` final:

```dart
    if (chordMaterials.isNotEmpty) return true;
```

4. Em `withColdigomMeta`, passar `chordMaterials: chordMaterials`.
5. Em `totalMaterials`:

```dart
  int get totalMaterials =>
      totalPdfs +
      audioTracks.length +
      youtubeMaterials.length +
      chordMaterials.length;
```

6. Em `fromLouvores`, o parâmetro `List<ChordMaterial> chordMaterials = const []`, o índice por grupo, a união de ids e o repasse:

```dart
    final chordByGroup = <String, List<ChordMaterial>>{};
    for (final item in chordMaterials) {
      final gid = item.groupId.trim();
      if (gid.isEmpty) continue;
      chordByGroup.putIfAbsent(gid, () => []).add(item);
    }

    final allGroupIds = <String>{
      ...byGroup.keys,
      ...audioByGroup.keys,
      ...youtubeByGroup.keys,
      ...chordByGroup.keys,
    };
    final groups = allGroupIds.map((gid) {
      return _buildGroup(
        gid,
        byGroup[gid] ?? const [],
        audioByGroup[gid] ?? const [],
        youtubeByGroup[gid] ?? const [],
        chordByGroup[gid] ?? const [],
        coldigomMetaByGroupId?[gid],
      );
    }).toList();
```

7. Em `_buildGroup`, novo parâmetro posicional `List<ChordMaterial> chords` antes do `coldigomMeta` opcional; no fallback de nome/número, uma cláusula a mais depois de `youtube`:

```dart
    } else if (chords.isNotEmpty) {
      nome = chords.first.nome;
      numero = chords.first.numero.trim();
    } else {
```

e no retorno `chordMaterials: List<ChordMaterial>.from(chords)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/features/chords/louvor_group_chords_test.dart -r compact`
Expected: PASS — 4 testes

- [ ] **Step 5: Verify no regression in existing grouping tests**

Run: `flutter test test/unit/features/catalog -r compact`
Expected: PASS — os testes de agrupamento existentes não podem quebrar; `chordMaterials` tem default, então nenhum chamador atual precisa mudar.

- [ ] **Step 6: Plumb the repository and caches**

`lib/features/coldigom/domain/repositories/coldigom_search_repository.dart` — em `ColdigomSearchResult` e `ColdigomBrowseResult`, adicionar `this.chordMaterials = const []` e o campo `final List<ChordMaterial> chordMaterials;`.

`lib/features/coldigom/data/repositories/coldigom_search_repository_impl.dart`:
- No record de retorno de `_mapDetails` (`:118` e `:138`), adicionar `List<ChordMaterial> chordMaterials`, a lista local, `chordMaterials.addAll(ColdigomLouvorAdapter.toChordMaterials(detail));` no laço e o campo no record final.
- **São exatamente 4 sítios de edição**, todos ao lado de um `youtubeMaterials: fetched.youtubeMaterials` já existente — use-o como marcador:
  - `:42` — `LouvorGroup.fromLouvores(` da busca
  - `:49` — `return ColdigomSearchResult(` populado
  - `:96` — `LouvorGroup.fromLouvores(` do browse
  - `:105` — `return ColdigomBrowseResult(` populado

  Em cada um, acrescentar `chordMaterials: fetched.chordMaterials`.
- **Não toque nos returns de guarda** em `:23`, `:34` e `:85` (early return de resultado vazio). Eles já omitem `youtubeMaterials` e dependem dos defaults; `chordMaterials` faz o mesmo.

`lib/features/coldigom/data/providers/coldigom_providers.dart` — novo cache no molde de `ColdigomAudioTracksCacheNotifier`:

```dart
/// Cache em memória de cifras coldigom indexadas por `chordId`.
class ColdigomChordMaterialsCacheNotifier
    extends Notifier<Map<String, ChordMaterial>> {
  @override
  Map<String, ChordMaterial> build() => const {};

  void mergeChords(Iterable<ChordMaterial> chords) {
    if (chords.isEmpty) return;
    final next = Map<String, ChordMaterial>.from(state);
    for (final chord in chords) {
      next[chord.chordId] = chord;
    }
    state = next;
  }

  ChordMaterial? findByChordId(String chordId) => state[chordId];
}

final coldigomChordMaterialsCacheProvider =
    NotifierProvider<
      ColdigomChordMaterialsCacheNotifier,
      Map<String, ChordMaterial>
    >(ColdigomChordMaterialsCacheNotifier.new);
```

`lib/features/coldigom/data/coldigom_praise_cache_warmup.dart` — nos dois pontos que já fazem `mergeLouvores`/`mergeTracks` após `fetchDetail`, adicionar:

```dart
      ref
          .read(coldigomChordMaterialsCacheProvider.notifier)
          .mergeChords(ColdigomLouvorAdapter.toChordMaterials(detail));
```

- [ ] **Step 7: Run the coldigom suite**

Run: `flutter test test/unit/features/coldigom test/unit/features/library -r compact`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/features/catalog/domain/entities/louvor_group.dart \
        lib/features/coldigom \
        test/unit/features/chords/louvor_group_chords_test.dart
git commit -m "feat(chords): carry chord materials through group and coldigom caches"
```

---

### Task 8: Widget ChordProView

Renderiza a música com as barras vermelhas. Sem rota ainda — testado isolado.

**Files:**
- Create: `lib/features/chords/presentation/theme/chord_reader_theme.dart`
- Create: `lib/features/chords/presentation/widgets/chordpro_view.dart`
- Test: `test/widget/features/chords/chordpro_view_test.dart`

**Interfaces:**
- Consumes: `ChordProSong`, `ChordProLyricLine`, `ChordProCommentLine`, `ChordProStanzaBreak`, `ChordCell` (Task 3).
- Produces:
  - `enum ChordReaderMode { light, dark }` com `ChordReaderPalette get palette` e `ChordReaderMode toggle()`.
  - `class ChordReaderPalette` com `background`, `lyric`, `chord`, `bar`, `comment`.
  - `class ChordProView extends StatelessWidget` com `ChordProView({required ChordProSong song, required ChordReaderPalette palette})`.
  - `Key` públicas para teste: `chordBarKey(int lineIndex, int cellIndex)` devolvendo `ValueKey<String>('chord-bar-$lineIndex-$cellIndex')`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/features/chords/chordpro_view_test.dart
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/chords/presentation/theme/chord_reader_theme.dart';
import 'package:coldigui/features/chords/presentation/widgets/chordpro_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, String source,
    {ChordReaderMode mode = ChordReaderMode.light}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChordProView(
          song: parseChordPro(source),
          palette: mode.palette,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desenha barra na celula encostada', (tester) async {
    await _pump(tester, 'ha[Cm]bi\n');

    expect(find.byKey(chordBarKey(0, 1)), findsOneWidget);
    expect(find.text('Cm'), findsOneWidget);
    expect(find.text('bi'), findsOneWidget);
  });

  testWidgets('nao desenha barra na celula solta', (tester) async {
    await _pump(tester, 'Deus e Amor [C]\n');

    expect(find.byKey(chordBarKey(0, 1)), findsNothing);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('preserva espacamento multiplo no texto', (tester) async {
    await _pump(tester, 'Deus e Amor   [C]\n');

    expect(find.text('Deus e Amor   '), findsOneWidget);
  });

  testWidgets('um espaco e tres espacos renderizam textos diferentes',
      (tester) async {
    await _pump(tester, 'Deus e Amor [C]\n');
    expect(find.text('Deus e Amor '), findsOneWidget);
    expect(find.text('Deus e Amor   '), findsNothing);
  });

  testWidgets('renderiza comentario de diretiva', (tester) async {
    await _pump(tester, '{comment: Instrumentos: C Am}\nletra\n');

    expect(find.text('Instrumentos: C Am'), findsOneWidget);
  });

  testWidgets('nao renderiza comentario de autoria ;', (tester) async {
    await _pump(tester, '; recado de pipeline\nletra\n');

    expect(find.textContaining('recado de pipeline'), findsNothing);
  });

  testWidgets('paleta escura muda a cor da letra', (tester) async {
    await _pump(tester, 'letra\n', mode: ChordReaderMode.dark);

    final text = tester.widget<Text>(find.text('letra'));
    expect(text.style?.color, ChordReaderMode.dark.palette.lyric);
    expect(text.style?.color, isNot(ChordReaderMode.light.palette.lyric));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/features/chords/chordpro_view_test.dart -r compact`
Expected: FAIL — pacotes `chord_reader_theme.dart` e `chordpro_view.dart` não resolvem

- [ ] **Step 3: Write the theme**

```dart
// lib/features/chords/presentation/theme/chord_reader_theme.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';

/// Cores de uma variante do leitor de cifras.
class ChordReaderPalette {
  const ChordReaderPalette({
    required this.background,
    required this.lyric,
    required this.chord,
    required this.bar,
    required this.comment,
  });

  final Color background;
  final Color lyric;
  final Color chord;

  /// Vermelho da barra que marca a sílaba do acorde.
  final Color bar;

  final Color comment;
}

/// Claro/escuro **local ao leitor de cifras**.
///
/// O app tem paleta litúrgica única ([AppColors]) e não tem dark mode global.
/// Este toggle não toca em [ThemeData] — vale só dentro do leitor.
enum ChordReaderMode {
  light,
  dark;

  /// Cores da variante. O vermelho da barra difere entre as duas: o mesmo tom
  /// sobre creme e sobre carvão não tem o mesmo contraste.
  ChordReaderPalette get palette => switch (this) {
    ChordReaderMode.light => const ChordReaderPalette(
      background: AppColors.card,
      lyric: AppColors.textDark,
      chord: AppColors.title,
      bar: Color(0xFFC62828),
      comment: Color(0xFF6B6B6B),
    ),
    ChordReaderMode.dark => const ChordReaderPalette(
      background: AppColors.pdfArea,
      lyric: AppColors.textLight,
      chord: AppColors.goldLight,
      bar: Color(0xFFFF5252),
      comment: Color(0xFFB0B0B0),
    ),
  };

  ChordReaderMode toggle() =>
      this == ChordReaderMode.light ? ChordReaderMode.dark : ChordReaderMode.light;

  /// Serializa para [StorageKeys.chordReaderMode].
  String toStorageString() => name;

  /// Restaura; `null` se inválido.
  static ChordReaderMode? fromStorageString(String? value) => switch (value) {
    'light' => ChordReaderMode.light,
    'dark' => ChordReaderMode.dark,
    _ => null,
  };
}
```

- [ ] **Step 4: Write the view**

```dart
// lib/features/chords/presentation/widgets/chordpro_view.dart
import 'package:flutter/material.dart';

import '../../domain/entities/chordpro_song.dart';
import '../theme/chord_reader_theme.dart';

/// Key da barra vermelha da célula [cellIndex] na linha [lineIndex].
ValueKey<String> chordBarKey(int lineIndex, int cellIndex) =>
    ValueKey<String>('chord-bar-$lineIndex-$cellIndex');

/// Renderiza [song] com acorde sobre sílaba e barra vermelha no ponto de troca.
///
/// Cada [ChordCell] vira uma coluna — rótulo em cima, texto embaixo — e a linha
/// é um [Wrap] dessas colunas. A quebra em tela estreita acontece entre células,
/// nunca dentro de uma, então o alinhamento acorde↔sílaba sobrevive.
///
/// A barra só aparece quando [ChordCell.attached]; célula solta fica sem barra e
/// o espaçamento da fonte é preservado porque os espaços são texto de verdade.
class ChordProView extends StatelessWidget {
  const ChordProView({required this.song, required this.palette, super.key});

  final ChordProSong song;
  final ChordReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final lyricStyle = TextStyle(
      fontSize: 16,
      height: 1.35,
      color: palette.lyric,
    );
    final chordStyle = TextStyle(
      fontSize: 13,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: palette.chord,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < song.lines.length; i++)
          _buildLine(song.lines[i], i, lyricStyle, chordStyle),
      ],
    );
  }

  Widget _buildLine(
    ChordProLine line,
    int index,
    TextStyle lyricStyle,
    TextStyle chordStyle,
  ) {
    return switch (line) {
      ChordProStanzaBreak() => const SizedBox(height: 18),
      ChordProCommentLine(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: lyricStyle.copyWith(
            fontStyle: FontStyle.italic,
            fontSize: 14,
            color: palette.comment,
          ),
        ),
      ),
      ChordProLyricLine(:final cells) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (var j = 0; j < cells.length; j++)
              _ChordCellView(
                cell: cells[j],
                barKey: chordBarKey(index, j),
                barColor: palette.bar,
                lyricStyle: lyricStyle,
                chordStyle: chordStyle,
              ),
          ],
        ),
      ),
    };
  }
}

class _ChordCellView extends StatelessWidget {
  const _ChordCellView({
    required this.cell,
    required this.barKey,
    required this.barColor,
    required this.lyricStyle,
    required this.chordStyle,
  });

  final ChordCell cell;
  final ValueKey<String> barKey;
  final Color barColor;
  final TextStyle lyricStyle;
  final TextStyle chordStyle;

  @override
  Widget build(BuildContext context) {
    final lyric = Text(cell.text, style: lyricStyle, softWrap: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cell.chord ?? '', style: chordStyle, softWrap: false),
        if (cell.attached)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra na borda esquerda do texto: é ali que o acorde troca.
              // Com texto vazio (Sinai[C#m7]) ela cai logo após a célula anterior.
              SizedBox(
                width: 2,
                child: ColoredBox(key: barKey, color: barColor),
              ),
              lyric,
            ],
          )
        else
          lyric,
      ],
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/widget/features/chords/chordpro_view_test.dart -r compact`
Expected: PASS — 7 testes

Se `preserva espacamento multiplo` falhar encontrando `'Deus e Amor'` sem os espaços, o `Text` está fazendo trim — confirme que nenhum `.trim()` sobrou no caminho do parser para a célula.

- [ ] **Step 6: Commit**

```bash
git add lib/features/chords/presentation \
        test/widget/features/chords/chordpro_view_test.dart
git commit -m "feat(chords): render chordpro with red syllable bars"
```

---

### Task 9: Seção Cifras no bottom sheet

**Files:**
- Modify: `lib/l10n/app_pt.arb`
- Modify: `lib/l10n/app_en.arb`
- Create: `lib/features/chords/presentation/providers/available_chords_provider.dart`
- Modify: `lib/features/catalog/presentation/widgets/louvor_material_sheet.dart`
- Modify: `lib/features/coldigom/presentation/widgets/coldigom_material_sheet.dart`
- Test: `test/widget/features/chords/chord_section_sheet_test.dart`

**Interfaces:**
- Consumes: `LouvorGroup.chordMaterials` (Task 7), `chordSongProvider` (Task 6).
- Produces:
  - `availableChordsProvider` — `FutureProvider.autoDispose.family<List<ChordMaterial>, String>` indexado por **`groupId`**.
  - Parâmetro `ValueChanged<ChordMaterial>? onChordSelected` em `showLouvorMaterialSheet` e `showColdigomMaterialSheet`.
  - l10n `chordMaterialSection`.

**Por que a chave é `groupId` e não a lista de cifras:** chave de `family` precisa
de `==` estável, e `List` em Dart usa identidade — `[a] == [a]` é `false`. Uma
lista como chave criaria um provider novo a cada rebuild do sheet, refazendo
trabalho sem parar. Por isso o provider é indexado por `groupId` (String) e lê as
cifras de `coldigomChordMaterialsCacheProvider`, que o sheet popula ao abrir.
Essa população também é o que faz `navigateToPdfId` achar a cifra na Task 11.

- [ ] **Step 1: Add the l10n strings**

Em `lib/l10n/app_pt.arb`, ao lado de `"youtubeMaterialSection"`:

```json
  "chordMaterialSection": "Cifras",
```

Em `lib/l10n/app_en.arb`, na posição equivalente:

```json
  "chordMaterialSection": "Chords",
```

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` regenerados com `chordMaterialSection`.

- [ ] **Step 2: Write the failing test**

```dart
// test/widget/features/chords/chord_section_sheet_test.dart
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_material_sheet.dart';
import 'package:coldigui/features/coldigom/presentation/widgets/coldigom_material_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChordMaterial _chord(String categoria, String key) {
  return ChordMaterial(
    chordId: 'chord-$categoria',
    r2Key: key,
    nome: 'Comigo habita',
    numero: '692',
    groupId: 'p1',
    categoria: categoria,
    classificacao: 'Cancao',
  );
}

LouvorGroup _group(List<ChordMaterial> chords) {
  return LouvorGroup(
    groupId: 'p1',
    numero: '692',
    nome: 'Comigo habita',
    sections: const [],
    chordMaterials: chords,
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required LouvorGroup group,
  required Map<String, ChordProSong?> songs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chordSongProvider.overrideWith((ref, r2Key) async => songs[r2Key]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Locale fixo: o default do flutter_test e ingles, e os asserts
        // abaixo esperam as strings em portugues.
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showLouvorMaterialSheet(
                context: context,
                group: group,
                onMaterialSelected: (_) {},
                onChordSelected: (_) {},
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  final song = parseChordPro('{title: X}\n\nA [Bb]noite vem,\n');

  testWidgets('lista so as cifras disponiveis', (tester) async {
    await _pumpSheet(
      tester,
      group: _group([_chord('Cifra I', 'k1'), _chord('Cifra II', 'k2')]),
      songs: {'k1': song, 'k2': null},
    );

    expect(find.text('Cifras'), findsOneWidget);
    expect(find.text('Cifra I'), findsOneWidget);
    expect(find.text('Cifra II'), findsNothing);
  });

  testWidgets('esconde a secao quando nenhuma cifra esta disponivel',
      (tester) async {
    await _pumpSheet(
      tester,
      group: _group([_chord('Cifra I', 'k1')]),
      songs: {'k1': null},
    );

    expect(find.text('Cifras'), findsNothing);
  });

  testWidgets('esconde a secao quando o grupo nao tem cifra', (tester) async {
    await _pumpSheet(tester, group: _group(const []), songs: const {});

    expect(find.text('Cifras'), findsNothing);
  });

  testWidgets('sheet coldigom mostra a aba Cifras so quando ha disponivel',
      (tester) async {
    // Grupo coldigom com PDF + cifra: LouvorGroupCard manda grupos coldigom
    // para este sheet, e toda cifra e coldigom — entao esta e a aba que o
    // usuario realmente ve.
    final group = LouvorGroup(
      groupId: 'p1',
      numero: '692',
      nome: 'Comigo habita',
      sections: const [],
      chordMaterials: [_chord('Cifra I', 'k1'), _chord('Cifra II', 'k2')],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordSongProvider.overrideWith(
            (ref, r2Key) async => r2Key == 'k1' ? song : null,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showColdigomMaterialSheet(
                  context: context,
                  group: group,
                  onMaterialSelected: (_) {},
                  onChordSelected: (_) {},
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Uma aba so → sem segment bar; a lista de cifras aparece direto.
    expect(find.text('Cifra I'), findsOneWidget);
    expect(find.text('Cifra II'), findsNothing);
  });

  testWidgets('toque na cifra dispara onChordSelected', (tester) async {
    ChordMaterial? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordSongProvider.overrideWith((ref, r2Key) async => song),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showLouvorMaterialSheet(
                  context: context,
                  group: _group([_chord('Cifra', 'k1')]),
                  onMaterialSelected: (_) {},
                  onChordSelected: (c) => selected = c,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cifra'));
    await tester.pumpAndSettle();

    expect(selected?.categoria, 'Cifra');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/features/chords/chord_section_sheet_test.dart -r compact`
Expected: FAIL — `No named parameter with the name 'onChordSelected'`

- [ ] **Step 4: Write the availability provider**

```dart
// lib/features/chords/presentation/providers/available_chords_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../data/providers/chord_providers.dart';
import '../../domain/entities/chord_material.dart';

/// Cifras do louvor [groupId] que têm arquivo publicado e com letra.
///
/// Uma requisição por cifra (tipicamente 1–2 por louvor), em paralelo. O
/// resultado alimenta o cache de [chordSongProvider], então abrir o sheet
/// pré-aquece o leitor: ao tocar na cifra, o conteúdo já está em memória.
///
/// Lê de [coldigomChordMaterialsCacheProvider] em vez de receber a lista por
/// parâmetro porque chave de `family` precisa de `==` estável, e `List` em Dart
/// usa identidade.
final availableChordsProvider = FutureProvider.autoDispose
    .family<List<ChordMaterial>, String>((ref, groupId) async {
      final chords =
          ref
              .watch(coldigomChordMaterialsCacheProvider)
              .values
              .where((chord) => chord.groupId == groupId)
              .toList()
            ..sort((a, b) => a.categoria.compareTo(b.categoria));

      if (chords.isEmpty) return const [];

      final songs = await Future.wait([
        for (final chord in chords)
          ref.watch(chordSongProvider(chord.r2Key).future),
      ]);

      return [
        for (var i = 0; i < chords.length; i++)
          if (songs[i] != null) chords[i],
      ];
    });
```

- [ ] **Step 5: Add the section to the sheet**

Em `lib/features/catalog/presentation/widgets/louvor_material_sheet.dart`:

1. Imports de `chord_material.dart`, `available_chords_provider.dart` e `coldigom_providers.dart`.
2. `ValueChanged<ChordMaterial>? onChordSelected` em `showLouvorMaterialSheet`, no `_LouvorMaterialSheetBody` e repassado ao body.
3. Em `_LouvorMaterialSheetBodyState`, popular o cache ao abrir — é dele que `availableChordsProvider` lê, e é ele que a Task 11 consulta para navegar:

```dart
  @override
  void initState() {
    super.initState();
    final chords = widget.group.chordMaterials;
    if (chords.isEmpty) return;
    // Pós-frame: mutar provider durante a construção do widget dispara
    // "setState during build" nos ouvintes do cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(coldigomChordMaterialsCacheProvider.notifier)
          .mergeChords(chords);
    });
  }
```

4. No `ListView`, **entre o bloco de `group.sections` e o de `group.audioTracks`** — cifra é material de leitura e fica perto dos PDFs:

```dart
                  if (group.chordMaterials.isNotEmpty)
                    ref
                        .watch(availableChordsProvider(group.groupId))
                        .maybeWhen(
                          data: (available) => available.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _sectionLabel(l10n.chordMaterialSection),
                                    for (final chord in available)
                                      ListTile(
                                        leading: Icon(
                                          LouvorMaterialIcons.forCategory(
                                            chord.categoria,
                                          ),
                                          color: AppColors.title,
                                        ),
                                        title: Text(
                                          chord.categoria,
                                          style: AppTypography.body.copyWith(
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                widget.onChordSelected?.call(
                                                  chord,
                                                );
                                              });
                                        },
                                      ),
                                  ],
                                ),
                          orElse: () => const SizedBox.shrink(),
                        ),
```

- [ ] **Step 5b: Add the chord tab to the Coldigom sheet**

**Este é o sheet que importa em produção.** `LouvorGroupCard._handleTap` manda grupos coldigom para `showColdigomMaterialSheet` e só grupos PLPCG para `showLouvorMaterialSheet` — e **toda cifra é coldigom**. O sheet coldigom não tem seções: tem abas (`enum _ColdigomMaterialKind { pdf, audio, youtube }`) com uma `_KindSegmentBar` e um `IndexedStack`.

Em `lib/features/coldigom/presentation/widgets/coldigom_material_sheet.dart`:

1. `ValueChanged<ChordMaterial>? onChordSelected` em `showColdigomMaterialSheet`, no `_ColdigomMaterialSheetBody` e repassado ao body.

2. Adicionar `chord` ao enum, **entre `pdf` e `audio`** — cifra é material de leitura e fica ao lado do PDF:

```dart
enum _ColdigomMaterialKind { pdf, chord, audio, youtube }
```

3. Em `_kindLabel`, o novo braço:

```dart
      _ColdigomMaterialKind.chord => l10n.chordMaterialSection,
```

4. `_visibleKinds` precisa passar a depender da disponibilidade assíncrona, então **sai do `initState` e vai para o `build`**. Remover o campo `late final List<_ColdigomMaterialKind> _kinds;` e a linha correspondente do `initState`, mantendo no `initState` apenas o merge do cache:

```dart
  @override
  void initState() {
    super.initState();
    final chords = widget.group.chordMaterials;
    if (chords.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(coldigomChordMaterialsCacheProvider.notifier)
          .mergeChords(chords);
    });
  }

  static List<_ColdigomMaterialKind> _visibleKinds(
    LouvorGroup group,
    List<ChordMaterial> availableChords,
  ) {
    return [
      if (group.totalPdfs > 0) _ColdigomMaterialKind.pdf,
      if (availableChords.isNotEmpty) _ColdigomMaterialKind.chord,
      if (group.audioTracks.isNotEmpty) _ColdigomMaterialKind.audio,
      if (group.youtubeMaterials.isNotEmpty) _ColdigomMaterialKind.youtube,
    ];
  }
```

5. No `build`, antes de `showSegments`, resolver as cifras e recalcular as abas. **O índice selecionado precisa ser clampado**: a aba de cifra aparece depois da primeira renderização, o que muda o tamanho da lista e pode deixar `_selectedKindIndex` fora de alcance.

```dart
    final availableChords = group.chordMaterials.isEmpty
        ? const <ChordMaterial>[]
        : ref
              .watch(availableChordsProvider(group.groupId))
              .maybeWhen(
                data: (chords) => chords,
                orElse: () => const <ChordMaterial>[],
              );
    final kinds = _visibleKinds(group, availableChords);
    final selectedKindIndex = kinds.isEmpty
        ? 0
        : _selectedKindIndex.clamp(0, kinds.length - 1);
    final showSegments = kinds.length > 1;
```

Trocar todos os usos de `_kinds` por `kinds` e de `_selectedKindIndex` por `selectedKindIndex` no restante do `build` (na `_KindSegmentBar`, no `IndexedStack` e nos dois `_buildKindList`).

6. `_buildKindList` recebe as cifras disponíveis e ganha o braço novo. Adicionar o parâmetro `required List<ChordMaterial> availableChords` e:

```dart
      _ColdigomMaterialKind.chord => ListView.separated(
        itemCount: availableChords.length,
        separatorBuilder: (_, _) => const _MaterialHairline(),
        itemBuilder: (context, index) {
          final chord = availableChords[index];
          return _MaterialRow(
            icon: LouvorMaterialIcons.forCategory(chord.categoria),
            iconColor: AppColors.title,
            title: chord.categoria,
            onTap: () {
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onChordSelected?.call(chord);
              });
            },
          );
        },
      ),
```

Assinatura de `_MaterialRow` conferida em `coldigom_material_sheet.dart:441` — `{required IconData icon, required Color iconColor, required String title, required VoidCallback onTap, String? subtitle, Widget? trailing}`. Os quatro parâmetros acima são os obrigatórios; `subtitle` e `trailing` ficam de fora porque cifra não tem autor próprio nem botão de adicionar nesta etapa.

7. Imports novos: `chord_material.dart`, `available_chords_provider.dart` e `coldigom_providers.dart`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widget/features/chords/chord_section_sheet_test.dart -r compact`
Expected: PASS — 5 testes

- [ ] **Step 7: Verify no regression in existing sheet tests**

Run: `flutter test test/widget/features/catalog test/widget/features/carousel -r compact`
Expected: PASS — `onChordSelected` é opcional, então nenhum chamador atual quebra.

- [ ] **Step 8: Commit**

```bash
git add lib/l10n lib/features/chords/presentation/providers \
        lib/features/catalog/presentation/widgets/louvor_material_sheet.dart \
        lib/features/coldigom/presentation/widgets/coldigom_material_sheet.dart \
        test/widget/features/chords/chord_section_sheet_test.dart
git commit -m "feat(chords): add Cifras section to material bottom sheet"
```

---

### Task 10: Rota /cifra e tela do leitor

**Files:**
- Modify: `lib/core/routing/route_paths.dart`
- Modify: `lib/core/utils/url_sync_params.dart` (nenhuma chave nova — ver nota)
- Create: `lib/core/utils/chord_reader_url_builder.dart`
- Create: `lib/features/chords/data/datasources/chord_reader_preferences_datasource.dart`
- Create: `lib/features/chords/presentation/providers/chord_reader_mode_provider.dart`
- Create: `lib/features/chords/presentation/pages/chord_reader_screen.dart`
- Modify: `lib/core/constants/storage_keys.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/unit/core/chord_reader_url_builder_test.dart`
- Test: `test/widget/features/chords/chord_reader_screen_test.dart`

**Interfaces:**
- Consumes: `ChordProView`, `ChordReaderMode` (Task 8), `chordSongProvider` (Task 6), `coldigomChordMaterialsCacheProvider` (Task 7).
- Produces:
  - `RoutePaths.chords = '/cifra'`.
  - `String buildChordReaderLocation({required String chordId, String? titulo, String? subtitulo})`.
  - `StorageKeys.chordReaderMode = 'chordReaderMode'`.
  - `chordReaderModeProvider` (`NotifierProvider<ChordReaderModeNotifier, ChordReaderMode>`) com `void toggle()`.
  - `ChordReaderScreen({required Map<String, String> queryParams})`.
  - l10n `chordReaderUnavailable`, `chordReaderToggleTheme`.

Nota sobre params: `/cifra` reusa `UrlSyncParams.pdfId` para o id e `UrlSyncParams.titulo`/`subtitulo`. Nada novo em `url_sync_params.dart` — é justamente essa reutilização que faz `CarouselChips` funcionar com uma linha de mudança na Task 11.

- [ ] **Step 1: Write the failing URL builder test**

```dart
// test/unit/core/chord_reader_url_builder_test.dart
import 'package:coldigui/core/utils/chord_reader_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta /cifra com pdfId', () {
    expect(
      buildChordReaderLocation(chordId: 'abc123'),
      '/cifra?pdfId=abc123',
    );
  });

  test('inclui titulo e subtitulo codificados', () {
    final location = buildChordReaderLocation(
      chordId: 'abc',
      titulo: 'Comigo habita, ó Deus',
      subtitulo: '692',
    );

    expect(location, startsWith('/cifra?pdfId=abc'));
    expect(location, contains('titulo=Comigo%20habita%2C%20%C3%B3%20Deus'));
    expect(location, contains('subtitulo=692'));
  });

  test('omite titulo e subtitulo vazios', () {
    final location =
        buildChordReaderLocation(chordId: 'abc', titulo: '', subtitulo: '');

    expect(location, '/cifra?pdfId=abc');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/core/chord_reader_url_builder_test.dart -r compact`
Expected: FAIL — pacote `chord_reader_url_builder.dart` não resolve

- [ ] **Step 3: Add the route path, storage key and URL builder**

Em `lib/core/routing/route_paths.dart`:

```dart
  /// Leitor de cifras ChordPro — irmã de [reader], filha da branch Home.
  static const String chords = '/cifra';
```

Em `lib/core/constants/storage_keys.dart`:

```dart
  /// Claro/escuro do leitor de cifras (`light` | `dark`).
  static const String chordReaderMode = 'chordReaderMode';
```

```dart
// lib/core/utils/chord_reader_url_builder.dart
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path do leitor de cifras.
///
/// Reusa [UrlSyncParams.pdfId] em vez de uma chave própria: cifra e PDF vivem no
/// mesmo espaço de ids, e é isso que deixa [CarouselChips] sincronizar o chip
/// focado nas duas rotas com o mesmo código.
String buildChordReaderLocation({
  required String chordId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{UrlSyncParams.pdfId: chordId};

  if (titulo != null && titulo.isNotEmpty) {
    params[UrlSyncParams.titulo] = titulo;
  }
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.chords}?$query';
}
```

- [ ] **Step 4: Run the URL builder test**

Run: `flutter test test/unit/core/chord_reader_url_builder_test.dart -r compact`
Expected: PASS — 3 testes

- [ ] **Step 5: Add the l10n strings**

`lib/l10n/app_pt.arb`:

```json
  "chordReaderUnavailable": "Cifra ainda não disponível",
  "chordReaderToggleTheme": "Alternar tema do leitor",
```

`lib/l10n/app_en.arb`:

```json
  "chordReaderUnavailable": "Chord chart not available yet",
  "chordReaderToggleTheme": "Toggle reader theme",
```

Run: `flutter gen-l10n`

- [ ] **Step 6: Write the mode persistence**

```dart
// lib/features/chords/data/datasources/chord_reader_preferences_datasource.dart
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../presentation/theme/chord_reader_theme.dart';

/// Persistência do claro/escuro do leitor de cifras.
class ChordReaderPreferencesDatasource {
  const ChordReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Modo salvo, ou claro por padrão.
  ChordReaderMode getMode() {
    return ChordReaderMode.fromStorageString(
          _prefs.getString(StorageKeys.chordReaderMode),
        ) ??
        ChordReaderMode.light;
  }

  Future<void> saveMode(ChordReaderMode mode) async {
    await _prefs.setString(StorageKeys.chordReaderMode, mode.toStorageString());
  }
}
```

```dart
// lib/features/chords/presentation/providers/chord_reader_mode_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/chord_reader_preferences_datasource.dart';
import '../theme/chord_reader_theme.dart';

/// Claro/escuro do leitor de cifras, persistido entre sessões.
///
/// [sharedPreferencesProvider] é síncrono e lança se não houver override — o
/// `main()` do app já faz esse override antes do `runApp`. Testes de widget que
/// tocam neste provider precisam de `SharedPreferences.setMockInitialValues`
/// **e** do override no `ProviderScope`.
class ChordReaderModeNotifier extends Notifier<ChordReaderMode> {
  @override
  ChordReaderMode build() => _datasource.getMode();

  ChordReaderPreferencesDatasource get _datasource =>
      ChordReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() {
    final next = state.toggle();
    state = next;
    unawaited(_datasource.saveMode(next));
  }
}

final chordReaderModeProvider =
    NotifierProvider<ChordReaderModeNotifier, ChordReaderMode>(
      ChordReaderModeNotifier.new,
    );
```

com `import 'dart:async';` no topo para o `unawaited`.

- [ ] **Step 7: Write the failing screen test**

```dart
// test/widget/features/chords/chord_reader_screen_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/chords/presentation/pages/chord_reader_screen.dart';
import 'package:coldigui/features/chords/presentation/theme/chord_reader_theme.dart';
import 'package:coldigui/features/chords/presentation/widgets/chordpro_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _r2Key = 'assets/praises/p1/m1.chord';

Future<void> _pump(
  WidgetTester tester, {
  required bool available,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final song = parseChordPro(
    '{title: Comigo habita}\n{key: Eb}\n\nA [Bb]noite ha[Cm]bi\n',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chordSongProvider.overrideWith(
          (ref, key) async => available ? song : null,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Locale fixo: o default do flutter_test e ingles, e os asserts
        // abaixo esperam as strings em portugues.
        locale: const Locale('pt'),
        home: ChordReaderScreen(
          queryParams: {'pdfId': encodePdfId(_r2Key), 'titulo': 'Comigo habita'},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renderiza a cifra disponivel', (tester) async {
    await _pump(tester, available: true);

    expect(find.byType(ChordProView), findsOneWidget);
    expect(find.text('Comigo habita'), findsWidgets);
    expect(find.byKey(chordBarKey(0, 1)), findsOneWidget);
  });

  testWidgets('mostra indisponivel quando nao ha arquivo', (tester) async {
    await _pump(tester, available: false);

    expect(find.byType(ChordProView), findsNothing);
    expect(find.text('Cifra ainda não disponível'), findsOneWidget);
  });

  testWidgets('toggle alterna o tema do leitor', (tester) async {
    await _pump(tester, available: true);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChordReaderScreen)),
    );
    expect(container.read(chordReaderModeProvider), ChordReaderMode.light);

    await tester.tap(find.byTooltip('Alternar tema do leitor'));
    await tester.pumpAndSettle();

    expect(container.read(chordReaderModeProvider), ChordReaderMode.dark);
  });
}
```

Adicionar ao topo os imports de
`package:coldigui/features/chords/presentation/providers/chord_reader_mode_provider.dart`
e `package:coldigui/core/providers/shared_prefs_provider.dart`.

- [ ] **Step 8: Write the screen**

```dart
// lib/features/chords/presentation/pages/chord_reader_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../data/providers/chord_providers.dart';
import '../providers/chord_reader_mode_provider.dart';
import '../theme/chord_reader_theme.dart';
import '../widgets/chordpro_view.dart';

/// Leitor de cifras ChordPro — rota `/cifra`, filha do [ShellScaffold].
///
/// Barras 1–2 (PLPCG + carousel) vêm do shell, como em `/leitor`. Esta tela
/// renderiza o cabeçalho da música, o corpo e o toggle de tema.
///
/// Recebe [UrlSyncParams.pdfId] (id da cifra, mesmo espaço do PDF),
/// [UrlSyncParams.titulo] e [UrlSyncParams.subtitulo]. Publica os params em
/// [readerRouteParamsProvider] para [CarouselChips] sincronizar o chip focado.
class ChordReaderScreen extends ConsumerStatefulWidget {
  const ChordReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  @override
  ConsumerState<ChordReaderScreen> createState() => _ChordReaderScreenState();
}

class _ChordReaderScreenState extends ConsumerState<ChordReaderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  /// `r2Key` decodificado do id da rota; vazio se o id faltar ou for inválido.
  String get _r2Key {
    final id = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (id.isEmpty) return '';
    try {
      return PdfPathNormalizer.getPdfRelPath(id);
    } on Object {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(chordReaderModeProvider);
    final palette = mode.palette;
    final songAsync = ref.watch(chordSongProvider(_r2Key));

    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: l10n.chordReaderToggleTheme,
                icon: Icon(
                  mode == ChordReaderMode.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: palette.chord,
                ),
                onPressed: () =>
                    ref.read(chordReaderModeProvider.notifier).toggle(),
              ),
            ),
            Expanded(
              child: songAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _Unavailable(
                  message: l10n.chordReaderUnavailable,
                  palette: palette,
                ),
                data: (song) {
                  if (song == null) {
                    return _Unavailable(
                      message: l10n.chordReaderUnavailable,
                      palette: palette,
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (song.title.isNotEmpty)
                          Text(
                            song.title,
                            style: AppTypography.headline.copyWith(
                              color: palette.chord,
                            ),
                          ),
                        if (_headerMeta(song.subtitle, song.key, song.rhythm,
                                song.artist)
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: Text(
                              _headerMeta(song.subtitle, song.key, song.rhythm,
                                  song.artist),
                              style: AppTypography.label.copyWith(
                                color: palette.comment,
                              ),
                            ),
                          ),
                        ChordProView(song: song, palette: palette),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headerMeta(String subtitle, String key, String rhythm, String artist) {
    return [
      if (subtitle.isNotEmpty) subtitle,
      if (key.isNotEmpty) key,
      if (rhythm.isNotEmpty) rhythm,
      if (artist.isNotEmpty) artist,
    ].join(' · ');
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.palette});

  final String message;
  final ChordReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: palette.lyric),
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Register the route**

Em `lib/core/routing/app_router.dart`, dentro do `routes:` do `GoRoute` de `RoutePaths.home`, ao lado de `'leitor'` e `'audio'`:

```dart
                  GoRoute(
                    path: 'cifra',
                    builder: (context, state) => ChordReaderScreen(
                      queryParams: state.uri.queryParameters,
                    ),
                  ),
```

com o import de `../../features/chords/presentation/pages/chord_reader_screen.dart`.

- [ ] **Step 10: Run test to verify it passes**

Run: `flutter test test/widget/features/chords/chord_reader_screen_test.dart -r compact`
Expected: PASS — 3 testes

- [ ] **Step 11: Commit**

```bash
git add lib/core/routing lib/core/utils/chord_reader_url_builder.dart \
        lib/core/constants/storage_keys.dart lib/l10n \
        lib/features/chords \
        test/unit/core/chord_reader_url_builder_test.dart \
        test/widget/features/chords/chord_reader_screen_test.dart
git commit -m "feat(chords): add /cifra reader route with light/dark toggle"
```

---

### Task 11: Integração com carousel e guardas PDF-only

Fecha o laço: abrir cifra pelo sheet entra na playlist, o chip navega para `/cifra`, e nenhum caminho de PDF recebe um id de cifra.

**Files:**
- Create: `lib/features/chords/presentation/utils/open_chord_in_reader.dart`
- Modify: `lib/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_chips.dart`
- Modify: `lib/features/carousel/presentation/utils/build_carousel_metadata_map.dart`
- Modify: `lib/features/catalog/presentation/widgets/louvor_group_card.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart`
- Modify: `lib/features/pdf_reader/presentation/providers/reader_adjacent_pdf_prefetch_provider.dart`
- Test: `test/unit/features/chords/chord_carousel_navigation_test.dart`

**Interfaces:**
- Consumes: `materialIdKindOf` (Task 1), `buildChordReaderLocation` (Task 10), `coldigomChordMaterialsCacheProvider` (Task 7).
- Produces: `Future<void> openChordInReader({required WidgetRef ref, required BuildContext context, required ChordMaterial chord})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/features/chords/chord_carousel_navigation_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/presentation/utils/build_carousel_metadata_map.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const r2Key = 'assets/praises/p1/m1.chord';

  test('metadata map inclui cifras com categoria e nome', () {
    final chordId = encodePdfId(r2Key);
    final map = buildCarouselMetadataMap(
      chordCache: {
        chordId: ChordMaterial(
          chordId: chordId,
          r2Key: r2Key,
          nome: 'Comigo habita',
          numero: '692',
          groupId: 'p1',
          categoria: 'Cifra I',
          classificacao: 'Cancao',
        ),
      },
    );

    expect(map[chordId]?.nome, 'Comigo habita');
    expect(map[chordId]?.numero, '692');
    expect(map[chordId]?.categoria, 'Cifra I');
  });

  test('id de cifra e distinguivel de id de PDF no mesmo espaco', () {
    expect(materialIdKindOf(encodePdfId(r2Key)), MaterialIdKind.chord);
    expect(
      materialIdKindOf(encodePdfId('assets/praises/p1/m1.pdf')),
      MaterialIdKind.pdf,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/features/chords/chord_carousel_navigation_test.dart -r compact`
Expected: FAIL — `No named parameter with the name 'chordCache'`

- [ ] **Step 3: Extend the metadata map**

Em `lib/features/carousel/presentation/utils/build_carousel_metadata_map.dart`, adicionar o parâmetro e o laço:

```dart
Map<String, CarouselItemMetadata> buildCarouselMetadataMap({
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
  Map<String, ChordMaterial>? chordCache,
}) {
```

e, depois do laço de `coldigomCache`:

```dart
  if (chordCache != null) {
    for (final chord in chordCache.values) {
      map[chord.chordId] = CarouselItemMetadata(
        numero: chord.numero,
        nome: chord.nome,
        categoria: chord.categoria,
        classificacao: chord.classificacao,
        source: chord.source,
      );
    }
  }
```

Em `lib/features/carousel/presentation/providers/carousel_louvores_provider.dart`, no `_reload`, passar
`chordCache: ref.read(coldigomChordMaterialsCacheProvider)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/features/chords/chord_carousel_navigation_test.dart -r compact`
Expected: PASS — 2 testes

- [ ] **Step 5: Write the opener**

```dart
// lib/features/chords/presentation/utils/open_chord_in_reader.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/chord_reader_url_builder.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/chord_material.dart';

/// Abre [chord] em `/cifra`, entrando na lista ativa como o PDF faz.
///
/// Espelha `openLouvorInReader`, sem a etapa de resolve local: o `.chord` é
/// buscado pelo `chordSongProvider`, que já está aquecido pelo sheet.
Future<void> openChordInReader({
  required WidgetRef ref,
  required BuildContext context,
  required ChordMaterial chord,
}) async {
  ref.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords([chord]);

  await ref
      .read(playlistsProvider.notifier)
      .addLouvorToActivePlaylist(chord.chordId);

  if (!context.mounted) return;

  unawaited(
    context.push(
      buildChordReaderLocation(
        chordId: chord.chordId,
        titulo: chord.nome,
        subtitulo: chord.numero,
      ),
    ),
  );
}
```

- [ ] **Step 6: Dispatch by material kind in carousel navigation**

Em `lib/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart`, no início de `navigateToPdfId`:

```dart
    if (materialIdKindOf(targetPdfId) == MaterialIdKind.chord) {
      final chord = ref
          .read(coldigomChordMaterialsCacheProvider)[targetPdfId];
      if (chord == null) return null;
      return buildChordReaderLocation(
        chordId: chord.chordId,
        titulo: chord.nome,
        subtitulo: chord.numero,
      );
    }
```

com os imports de `material_id_kind.dart`, `chord_reader_url_builder.dart` e `coldigom_providers.dart`.

Em `lib/features/carousel/presentation/widgets/carousel_chips.dart`, estender o gate:

```dart
  bool get _isReaderRoute {
    final path = _routerState?.uri.path;
    return path == RoutePaths.reader || path == RoutePaths.chords;
  }
```

- [ ] **Step 7: Wire the sheet callback**

Em `lib/features/catalog/presentation/widgets/louvor_group_card.dart`, ao lado do `_openYoutube` existente, adicionar o handler e passá-lo nas duas chamadas de sheet:

```dart
  Future<void> _openChord(ChordMaterial chord) =>
      openChordInReader(ref: ref, context: context, chord: chord);
```

```dart
        onChordSelected: _openChord,
```

Em `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart`, nas duas chamadas de sheet (`showColdigomMaterialSheet` e `showLouvorMaterialSheet`), adicionar:

```dart
      onChordSelected: (chord) =>
          openChordInReader(ref: ref, context: context, chord: chord),
```

- [ ] **Step 8: Guard the PDF-only paths**

Em `lib/features/pdf_reader/presentation/providers/reader_adjacent_pdf_prefetch_provider.dart`, dentro de `schedulePrefetch`, filtrar os vizinhos antes da chamada. Substituir:

```dart
        await prefetch.call(
          catalog: catalog,
          previousPdfId: position.previousPdfId,
          nextPdfId: position.nextPdfId,
        );
```

por:

```dart
        await prefetch.call(
          catalog: catalog,
          previousPdfId: _pdfIdOrNull(position.previousPdfId),
          nextPdfId: _pdfIdOrNull(position.nextPdfId),
        );
```

e adicionar, ao fim do arquivo:

```dart
/// Descarta ids que não são PDF — cifra no carousel não tem o que pré-buscar.
String? _pdfIdOrNull(String? id) {
  if (id == null) return null;
  return materialIdKindOf(id) == MaterialIdKind.pdf ? id : null;
}
```

com o import de `package:coldigui/core/utils/material_id_kind.dart`.

**As demais guardas da spec §3.9 são inalcançáveis por construção e não precisam de código.** `LouvorPdfPath.fromLouvor` e `resolvePdfForReaderProvider` só recebem `Louvor`, e `toChordMaterials` nunca produz `Louvor`. Compartilhar e salvar PDF vivem em `PdfReaderScreen`, que só é montada por `/leitor`. O único ponto onde um id de cifra realmente circula junto de ids de PDF é o carousel — e ele está coberto por `navigateToPdfId` (Step 6) e por este prefetch.

- [ ] **Step 9: Run the full suite**

Run: `flutter test -r compact`

Expected: **exatamente as 7 falhas pré-existentes do baseline, nenhuma a mais.** A suíte já era vermelha antes deste plano (medido em `1375253`, antes da Task 1) — são 7 falhas em 4 arquivos, todas por `PLPCG_API_BASE_URL` vir vazio em `flutter test`:

```
test/integration/uc04_share_save_test.dart: UC-04 — pipeline LouvorPdfPath + validação + resolução remota
test/integration/uc11_pdf_reader_test.dart: UC-11 — pipeline validação + resolução URL remota /assets/
test/unit/features/pdf_reader/pdf_source_resolver_test.dart: resolve path /assets/ com apiBaseUrl
test/unit/features/pdf_reader/pdf_source_resolver_test.dart: resolve path assets/ sem barra inicial
test/widget/features/library/library_screen_test.dart: exibe LouvorCards e chips de filtro
test/widget/features/library/library_screen_test.dart: exibe resumo dentro do card Visualização
test/widget/features/library/library_screen_test.dart: troca página e ordenação
```

**Não conserte essas sete** — são anteriores ao plano e fora do escopo. Qualquer falha além destas é regressão sua.

- [ ] **Step 10: Run the analyzer**

Run: `flutter analyze`

Expected: **exatamente 1 issue** — a `info` pré-existente `no_leading_underscores_for_local_identifiers` em `test/unit/features/playlists/active_playlist_sync_cloud_test.dart:258`. Não a conserte: é anterior a este plano e de outra área. Qualquer issue além dela é sua.

- [ ] **Step 11: Commit**

```bash
git add lib/features/chords/presentation/utils/open_chord_in_reader.dart \
        lib/features/pdf_reader/presentation/providers \
        lib/features/carousel lib/features/catalog/presentation/widgets/louvor_group_card.dart \
        test/unit/features/chords/chord_carousel_navigation_test.dart
git commit -m "feat(chords): route chord materials through carousel and playlist"
```

---

### Task 12: Ponteiro na documentação

**Files:**
- Modify: `docs/features/FEATURE_INDEX.md`

- [ ] **Step 1: Add the entry**

Em `docs/features/FEATURE_INDEX.md`, na tabela "Status por feature", adicionar a linha após `pdf_reader`:

```markdown
| `chords` | UC-11 (variante) | Média | **Concluído** (leitor ChordPro ago/2026) | Seção Cifras em [showLouvorMaterialSheet]; rota `/cifra` ([ChordReaderScreen]); [parseChordPro] + [ChordProView] com barras de sílaba; claro/escuro local ([ChordReaderMode]); id no espaço do `pdfId` ([materialIdKindOf]); spec [leitor de cifras](../superpowers/specs/2026-08-29-leitor-cifras-chordpro-design.md) |
```

- [ ] **Step 2: Commit**

```bash
git add docs/features/FEATURE_INDEX.md
git commit -m "docs(chords): index chordpro reader spec"
```

---

## Verificação final

Depois da Task 12, com um `.chord` publicado de verdade:

```bash
flutter run --dart-define-from-file=dart_defines/plpcg.json -d chrome
```

**Louvores com cifra publicada (varredura de 2026-08-29: 57 arquivos, 40 louvores).** Os publicados se concentram nos números baixos, e quase todos têm `Cifra I` **e** `Cifra II` — o que exercita a lista com múltiplos itens, não só um:

```
001 — Meu Deus, meu pai                        [Cifra I + Cifra II]
001 — O sangue de Jesus tem poder              [Cifra I + Cifra II]
002 — Pai, estou a te clamar                   [Cifra I + Cifra II]
003 — Clamo, ó Senhor por teu sangue           [Cifra I + Cifra II]
004 — Clamo, ó Senhor                          [Cifra I + Cifra II]
692 — Comigo habita, ó Deus                    [Cifra I + Cifra II]
```

Pegar um deles, abrir o sheet, confirmar que a aba/seção Cifras aparece com as duas, tocar numa e verificar na tela:

- as barras vermelhas caem entre sílabas (`ha│bi`), não no meio de palavra sem acorde;
- `[Eb]Co - [Bb]migo` mostra os acordes alinhados sobre `Co` e `migo`;
- o toggle troca claro/escuro e sobrevive a um reload da página;
- o chip do carousel aparece com `692 — Comigo habita` e volta para a cifra ao ser tocado.

Louvores sem cifra publicada não podem mostrar a seção — é o comportamento correto enquanto a cobertura estiver em 2,5%.
