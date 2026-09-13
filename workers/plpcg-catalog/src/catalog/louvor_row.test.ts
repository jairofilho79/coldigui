import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { LOUVOR_SELECT_COLUMNS, mapRow } from './louvor_row.ts';

const base = {
  nome: 'Teste',
  numero: '001',
  classificacao: 'ColAdultos',
  categoria: 'Partitura',
  pdf: '001.pdf',
  pdf_id: 'Q29sQWR1bHRvcy8wMDEucGRm',
  group_id: '001:teste',
};

test('mapRow emite shortId como string quando preenchido', () => {
  const json = mapRow({ ...base, short_id: '0000' });
  assert.equal(json.shortId, '0000');
  assert.equal(typeof json.shortId, 'string');
});

test('mapRow omite a chave shortId quando short_id é null', () => {
  const json = mapRow({ ...base, short_id: null });
  assert.equal('shortId' in json, false);
  assert.deepEqual(Object.keys(json), [
    'nome', 'numero', 'classificacao', 'categoria', 'pdf', 'pdfId', 'groupId',
  ]);
});

test('SELECT projeta short_id', () => {
  assert.match(LOUVOR_SELECT_COLUMNS, /\bshort_id\b/);
});
