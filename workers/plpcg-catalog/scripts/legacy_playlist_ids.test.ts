import { strict as assert } from 'node:assert';
import { test } from 'node:test';

import {
  buildReport,
  coldigomPdfIdFromAssetUrl,
  collectLegacyIds,
  detectSkipped,
  encodePdfId,
  isLegacyPdfId,
  parseArgs,
  resolvedFromCrosswalk,
  rewriteRow,
  updateSql,
  type PlaylistRow,
  type RowRewrite,
} from './legacy_playlist_ids.ts';

const legadoA = encodePdfId('ColAdultos/001.pdf');
const legadoPes = encodePdfId('assets/PES/Hino 1.pdf');
const desconhecido = encodePdfId('ColAdultos/999.pdf');
const coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
const coldigomB = encodePdfId('assets/praises/p9/m 2.pdf');
const audio = encodePdfId('assets/praises/p1/a.mp3');
const cifraLegada = encodePdfId('ColAdultos/001.chord');

function row(partial: Partial<PlaylistRow>): PlaylistRow {
  return {
    user_id: 'u1',
    id: 'pl1',
    items: '[]',
    pdf_ids: '[]',
    audio_ids: '[]',
    version: 3,
    ...partial,
  };
}

test('encodePdfId é o do app (mesmos literais de pdf_id_codec_test.dart)', () => {
  assert.equal(encodePdfId('assets/praises/p1/m1.pdf'), 'YXNzZXRzL3ByYWlzZXMvcDEvbTEucGRm');
  assert.equal(
    encodePdfId('ColAdultos/Cifra nível I/001.pdf'),
    'Q29sQWR1bHRvcy9DaWZyYSBuw612ZWwgSS8wMDEucGRm',
  );
});

test('isLegacyPdfId: PDF fora de assets/praises; o resto não', () => {
  assert.equal(isLegacyPdfId(legadoA), true);
  assert.equal(isLegacyPdfId(legadoPes), true);
  assert.equal(isLegacyPdfId(coldigomA), false);
  assert.equal(isLegacyPdfId(audio), false);
  assert.equal(isLegacyPdfId(cifraLegada), false);
  assert.equal(isLegacyPdfId('lyrics:p1'), false);
  assert.equal(isLegacyPdfId(''), false);
});

test('coldigomPdfIdFromAssetUrl lê o r2Key da URL', () => {
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/assets/praises/p1/m1.pdf'), coldigomA);
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/assets/praises/p9/m%202.pdf'), coldigomB);
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/outra/coisa.pdf'), null);
  assert.equal(coldigomPdfIdFromAssetUrl('https://c.test/assets/praises/p1'), null);
});

test('coldigomPdfIdFromAssetUrl descarta query string e fragment antes do path (mesmo teste de pdf_id_codec_test.dart)', () => {
  assert.equal(
    coldigomPdfIdFromAssetUrl('https://host/assets/praises/p/m.pdf?v=2#x'),
    coldigomPdfIdFromAssetUrl('https://host/assets/praises/p/m.pdf'),
  );
});

test('resolvedFromCrosswalk ignora entradas sem URL de assets/praises', () => {
  const resolved = resolvedFromCrosswalk({
    [legadoA]: { praiseId: 'p1', materialId: 'm1', url: 'https://c.test/assets/praises/p1/m1.pdf' },
    [legadoPes]: { praiseId: 'p2', materialId: 'm2', url: 'https://c.test/x.pdf' },
    [desconhecido]: 'lixo',
  });
  assert.deepEqual([...resolved], [[legadoA, coldigomA]]);
});

test('linha v2: troca mantendo kind e ordem; áudio e desconhecido ficam', () => {
  const rewrite = rewriteRow(
    row({
      items: JSON.stringify([
        { id: legadoA, kind: 'pdf' },
        { id: audio, kind: 'audio' },
        { id: desconhecido, kind: 'pdf' },
        { id: legadoA, kind: 'pdf' },
      ]),
      audio_ids: JSON.stringify([audio]),
    }),
    new Map([[legadoA, coldigomA]]),
  );
  assert.ok(rewrite);
  assert.deepEqual(rewrite.items, [
    { id: coldigomA, kind: 'pdf' },
    { id: audio, kind: 'audio' },
    { id: desconhecido, kind: 'pdf' },
    { id: coldigomA, kind: 'pdf' },
  ]);
  assert.deepEqual(rewrite.pdfIds, [coldigomA, desconhecido, coldigomA]);
  assert.deepEqual(rewrite.replaced, [
    [legadoA, coldigomA],
    [legadoA, coldigomA],
  ]);
  assert.deepEqual(rewrite.unknown, [desconhecido]);
});

test('linha anterior à 0008 (items vazio): deriva de pdf_ids/audio_ids', () => {
  const rewrite = rewriteRow(
    row({
      items: '[]',
      pdf_ids: JSON.stringify([legadoPes, coldigomA]),
      audio_ids: JSON.stringify([audio]),
    }),
    new Map([[legadoPes, coldigomB]]),
  );
  assert.ok(rewrite);
  assert.deepEqual(rewrite.items, [
    { id: coldigomB, kind: 'pdf' },
    { id: coldigomA, kind: 'pdf' },
    { id: audio, kind: 'audio' },
  ]);
  assert.deepEqual(rewrite.pdfIds, [coldigomB, coldigomA]);
});

test('sem legado resolvido a linha não muda', () => {
  assert.equal(
    rewriteRow(row({ items: JSON.stringify([{ id: desconhecido, kind: 'pdf' }]) }), new Map()),
    null,
  );
  assert.equal(
    rewriteRow(
      row({ items: JSON.stringify([{ id: coldigomA, kind: 'pdf' }]) }),
      new Map([[legadoA, coldigomA]]),
    ),
    null,
  );
});

test('collectLegacyIds junta as duas formas de linha', () => {
  const ids = collectLegacyIds([
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }, { id: audio, kind: 'audio' }]) }),
    row({ id: 'pl2', items: '[]', pdf_ids: JSON.stringify([legadoPes, coldigomA]) }),
  ]);
  assert.deepEqual([...ids].sort(), [legadoA, legadoPes].sort());
});

test('updateSql: version + 1, updated_at intacto, guarda de versão, aspas escapadas', () => {
  const sql = updateSql({
    userId: "u'1",
    id: 'pl1',
    version: 3,
    items: [{ id: coldigomA, kind: 'pdf' }],
    pdfIds: [coldigomA],
    replaced: [[legadoA, coldigomA]],
    unknown: [],
  });
  assert.match(sql, /version = version \+ 1/);
  assert.doesNotMatch(sql, /updated_at/);
  assert.match(sql, /WHERE user_id = 'u''1' AND id = 'pl1' AND version = 3;$/);
  assert.ok(sql.includes(`items = '${JSON.stringify([{ id: coldigomA, kind: 'pdf' }])}'`));
  assert.ok(sql.includes(`pdf_ids = '${JSON.stringify([coldigomA])}'`));
});

test('detectSkipped: guarda de versão rejeitou — linha relida ainda tem o legado', () => {
  const planned = rewriteRow(
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }]) }),
    new Map([[legadoA, coldigomA]]),
  );
  assert.ok(planned);
  // Outra escrita mudou a versão entretanto: a guarda `AND version = N` não
  // bateu, e a linha relida continua com o id legado.
  const afterRows = [
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }]), version: 4 }),
  ];
  assert.deepEqual(
    detectSkipped([planned], afterRows, new Map([[legadoA, coldigomA]])),
    [planned],
  );
});

test('detectSkipped: escrita pegou — linha relida já tem o id coldigom', () => {
  const planned = rewriteRow(
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }]) }),
    new Map([[legadoA, coldigomA]]),
  );
  assert.ok(planned);
  const afterRows = [
    row({ items: JSON.stringify([{ id: coldigomA, kind: 'pdf' }]), version: 4 }),
  ];
  assert.deepEqual(
    detectSkipped([planned], afterRows, new Map([[legadoA, coldigomA]])),
    [],
  );
});

test('detectSkipped: linha ausente da releitura (ex.: soft delete concorrente) não conta como pulada', () => {
  const planned = rewriteRow(
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }]) }),
    new Map([[legadoA, coldigomA]]),
  );
  assert.ok(planned);
  assert.deepEqual(detectSkipped([planned], [], new Map([[legadoA, coldigomA]])), []);
});

test('buildReport com skipped: desconta de rowsChanged e marca a linha', () => {
  const rows = [
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }]) }),
  ];
  const resolved = new Map([[legadoA, coldigomA]]);
  const rewrites = rows
    .map((r) => rewriteRow(r, resolved))
    .filter((r): r is RowRewrite => r !== null);
  const report = buildReport(
    rows,
    rewrites,
    collectLegacyIds(rows),
    resolved,
    new Date('2026-09-23T00:00:00Z'),
    rewrites,
  );
  assert.equal(report.rowsChanged, 0);
  assert.deepEqual(report.skipped, [{ userId: 'u1', id: 'pl1' }]);
  assert.equal(report.rows[0].skipped, true);
});

test('parseArgs: --dry-run --local', () => {
  assert.deepEqual(parseArgs(['--dry-run', '--local']), {
    dryRun: true,
    target: '--local',
  });
});

test('parseArgs: --remote sem --dry-run', () => {
  assert.deepEqual(parseArgs(['--remote']), { dryRun: false, target: '--remote' });
});

test('parseArgs: flag desconhecida rejeita', () => {
  assert.throws(() => parseArgs(['--dryrun', '--local']));
});

test('parseArgs: sem --local nem --remote rejeita (sem default)', () => {
  assert.throws(() => parseArgs(['--dry-run']));
});

test('parseArgs: --local e --remote juntos rejeita', () => {
  assert.throws(() => parseArgs(['--local', '--remote']));
});

test('buildReport conta linhas, resolvidos e desconhecidos', () => {
  const rows = [
    row({ items: JSON.stringify([{ id: legadoA, kind: 'pdf' }, { id: desconhecido, kind: 'pdf' }]) }),
  ];
  const resolved = new Map([[legadoA, coldigomA]]);
  const rewrites = rows
    .map((r) => rewriteRow(r, resolved))
    .filter((r): r is RowRewrite => r !== null);
  const report = buildReport(
    rows,
    rewrites,
    collectLegacyIds(rows),
    resolved,
    new Date('2026-09-23T00:00:00Z'),
  );
  assert.equal(report.rowsScanned, 1);
  assert.equal(report.rowsChanged, 1);
  assert.equal(report.legacyIds, 2);
  assert.equal(report.resolvedIds, 1);
  assert.deepEqual(report.unknownIds, [desconhecido]);
  assert.equal(report.generatedAt, '2026-09-23T00:00:00.000Z');
});
