import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  MATERIAL_KINDS,
  itemsFromLegacy,
  listsFromItems,
  parseItems,
  parseItemsColumn,
} from './items.ts';

test('MATERIAL_KINDS é exatamente o enum MaterialKind do cliente', () => {
  assert.deepEqual(
    [...MATERIAL_KINDS].sort(),
    ['audio', 'chord', 'gesture', 'pdf', 'unknown', 'youtube'],
  );
});

test('parseItems aceita objetos {id, kind} válidos', () => {
  assert.deepEqual(parseItems([{ id: 'a', kind: 'audio' }]), [
    { id: 'a', kind: 'audio' },
  ]);
});

test('parseItems aceita todos os kinds do conjunto', () => {
  const raw = [...MATERIAL_KINDS].map((kind) => ({ id: `id-${kind}`, kind }));
  assert.deepEqual(parseItems(raw), raw);
});

test('parseItems aceita lista vazia', () => {
  assert.deepEqual(parseItems([]), []);
});

test('parseItems descarta campos extras da entrada', () => {
  assert.deepEqual(parseItems([{ id: 'a', kind: 'pdf', extra: 1 }]), [
    { id: 'a', kind: 'pdf' },
  ]);
});

test('parseItems devolve null para kind fora do conjunto', () => {
  assert.equal(parseItems([{ id: 'a', kind: 'video' }]), null);
});

test('parseItems devolve null para id vazio', () => {
  assert.equal(parseItems([{ id: '', kind: 'pdf' }]), null);
});

test('parseItems devolve null para id ausente ou não-string', () => {
  assert.equal(parseItems([{ kind: 'pdf' }]), null);
  assert.equal(parseItems([{ id: 7, kind: 'pdf' }]), null);
});

test('parseItems devolve null para kind ausente', () => {
  assert.equal(parseItems([{ id: 'a' }]), null);
});

test('parseItems devolve null para entrada que não é objeto', () => {
  assert.equal(parseItems(['a']), null);
  assert.equal(parseItems([null]), null);
});

test('parseItems devolve null para não-array', () => {
  assert.equal(parseItems('a,b'), null);
  assert.equal(parseItems({ id: 'a', kind: 'pdf' }), null);
  assert.equal(parseItems(null), null);
  assert.equal(parseItems(undefined), null);
});

test('itemsFromLegacy tipa pdfIds como pdf e audioIds como audio', () => {
  assert.deepEqual(itemsFromLegacy(['p1', 'p2'], ['a1']), [
    { id: 'p1', kind: 'pdf' },
    { id: 'p2', kind: 'pdf' },
    { id: 'a1', kind: 'audio' },
  ]);
});

test('itemsFromLegacy com as duas listas vazias devolve vazio', () => {
  assert.deepEqual(itemsFromLegacy([], []), []);
});

test('listsFromItems separa por kind, preservando a ordem de cada face', () => {
  const { pdfIds, audioIds } = listsFromItems([
    { id: 'p1', kind: 'pdf' },
    { id: 'a1', kind: 'audio' },
    { id: 'c1', kind: 'chord' },
    { id: 'a2', kind: 'audio' },
    { id: 'y1', kind: 'youtube' },
  ]);

  // Face de partituras = tudo que não é áudio (A7).
  assert.deepEqual(pdfIds, ['p1', 'c1', 'y1']);
  assert.deepEqual(audioIds, ['a1', 'a2']);
});

test('listsFromItems põe gesture e unknown na face de partituras', () => {
  const { pdfIds, audioIds } = listsFromItems([
    { id: 'g1', kind: 'gesture' },
    { id: 'u1', kind: 'unknown' },
  ]);

  assert.deepEqual(pdfIds, ['g1', 'u1']);
  assert.deepEqual(audioIds, []);
});

test('itemsFromLegacy → listsFromItems é round-trip das duas listas', () => {
  const pdfIds = ['p1', 'p2'];
  const audioIds = ['a1'];
  assert.deepEqual(listsFromItems(itemsFromLegacy(pdfIds, audioIds)), {
    pdfIds,
    audioIds,
  });
});

test('parseItemsColumn lê a coluna JSON gravada', () => {
  assert.deepEqual(
    parseItemsColumn('[{"id":"p1","kind":"pdf"},{"id":"a1","kind":"audio"}]'),
    [
      { id: 'p1', kind: 'pdf' },
      { id: 'a1', kind: 'audio' },
    ],
  );
});

test('parseItemsColumn devolve [] para JSON inválido', () => {
  assert.deepEqual(parseItemsColumn('garbage'), []);
});

test('parseItemsColumn devolve [] para null, vazio e default da coluna', () => {
  assert.deepEqual(parseItemsColumn(null), []);
  assert.deepEqual(parseItemsColumn(''), []);
  assert.deepEqual(parseItemsColumn('[]'), []);
});

test('parseItemsColumn devolve [] para JSON válido de forma errada', () => {
  // Linha gravada por uma versão antiga (ou corrompida): não derruba o GET.
  assert.deepEqual(parseItemsColumn('["p1","a1"]'), []);
  assert.deepEqual(parseItemsColumn('{"id":"p1","kind":"pdf"}'), []);
  assert.deepEqual(parseItemsColumn('[{"id":"p1","kind":"video"}]'), []);
});
