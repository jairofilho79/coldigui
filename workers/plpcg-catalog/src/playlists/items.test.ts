import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  MATERIAL_KINDS,
  itemsFromLegacy,
  itemsFromLegacyPreservingKinds,
  listsFromItems,
  parseItems,
  parseItemsColumn,
  type PlaylistItem,
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

test('parseItems devolve null para entrada que não é objeto nem string', () => {
  assert.equal(parseItems([null]), null);
  assert.equal(parseItems([7]), null);
  assert.equal(parseItems([['a']]), null);
});

test('parseItems tolera items de strings (rascunho v2 da fatia 1)', () => {
  // Sem `declaredAudio`, toda string é partitura genérica.
  assert.deepEqual(parseItems(['p-a', 'c-a']), [
    { id: 'p-a', kind: 'pdf' },
    { id: 'c-a', kind: 'pdf' },
  ]);
});

test('parseItems usa declaredAudio para tipar as strings', () => {
  assert.deepEqual(parseItems(['p-a', 'a-a'], ['a-a']), [
    { id: 'p-a', kind: 'pdf' },
    { id: 'a-a', kind: 'audio' },
  ]);
});

test('parseItems aceita objetos e strings na mesma lista', () => {
  assert.deepEqual(
    parseItems([{ id: 'c-a', kind: 'chord' }, 'a-a'], ['a-a']),
    [
      { id: 'c-a', kind: 'chord' },
      { id: 'a-a', kind: 'audio' },
    ],
  );
});

test('parseItems: declaredAudio não mexe no kind de um objeto', () => {
  // O `kind` explícito manda; a lista só resolve string solta.
  assert.deepEqual(parseItems([{ id: 'a-a', kind: 'pdf' }], ['a-a']), [
    { id: 'a-a', kind: 'pdf' },
  ]);
});

test('parseItems devolve null para string vazia', () => {
  assert.equal(parseItems(['']), null);
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

test('itemsFromLegacyPreservingKinds reusa o kind gravado na mesma face', () => {
  const stored: PlaylistItem[] = [
    { id: 'c-a', kind: 'chord' },
    { id: 'y-a', kind: 'youtube' },
    { id: 'g-a', kind: 'gesture' },
    { id: 'a-a', kind: 'audio' },
  ];

  assert.deepEqual(
    itemsFromLegacyPreservingKinds(['c-a', 'y-a', 'g-a'], ['a-a'], stored),
    stored,
  );
});

test('itemsFromLegacyPreservingKinds tipa id novo pela face do request', () => {
  const stored: PlaylistItem[] = [{ id: 'c-a', kind: 'chord' }];

  assert.deepEqual(
    itemsFromLegacyPreservingKinds(['c-a', 'novo'], ['a-novo'], stored),
    [
      { id: 'c-a', kind: 'chord' },
      { id: 'novo', kind: 'pdf' },
      { id: 'a-novo', kind: 'audio' },
    ],
  );
});

test('itemsFromLegacyPreservingKinds: mudar de face segue o request', () => {
  const stored: PlaylistItem[] = [
    { id: 'x', kind: 'chord' },
    { id: 'y', kind: 'audio' },
  ];

  // `x` vai para a face de áudio e `y` para a de partituras: o kind gravado
  // discorda da face nova, então o request ganha.
  assert.deepEqual(itemsFromLegacyPreservingKinds(['y'], ['x'], stored), [
    { id: 'y', kind: 'pdf' },
    { id: 'x', kind: 'audio' },
  ]);
});

test('itemsFromLegacyPreservingKinds respeita a ordem e a remoção do request', () => {
  const stored: PlaylistItem[] = [
    { id: 'a', kind: 'chord' },
    { id: 'b', kind: 'youtube' },
    { id: 'c', kind: 'gesture' },
  ];

  // `b` foi removido e a ordem inverteu: last-write-wins de pertencimento.
  assert.deepEqual(itemsFromLegacyPreservingKinds(['c', 'a'], [], stored), [
    { id: 'c', kind: 'gesture' },
    { id: 'a', kind: 'chord' },
  ]);
});

test('itemsFromLegacyPreservingKinds sem linha gravada == itemsFromLegacy', () => {
  assert.deepEqual(
    itemsFromLegacyPreservingKinds(['p-a'], ['a-a'], []),
    itemsFromLegacy(['p-a'], ['a-a']),
  );
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
