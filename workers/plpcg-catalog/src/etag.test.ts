import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { matchesEtag } from './etag.ts';

test('valor único idêntico casa', () => {
  assert.equal(matchesEtag('"a"', '"a"'), true);
});

test('checksum cru (sem aspas) casa — é o que o cliente Dart persiste', () => {
  assert.equal(matchesEtag('a', '"a"'), true);
});

test('valor diferente não casa', () => {
  assert.equal(matchesEtag('"b"', '"a"'), false);
});

test('lista separada por vírgula casa em qualquer posição', () => {
  assert.equal(matchesEtag('"a", "b"', '"a"'), true);
  assert.equal(matchesEtag('"a", "b"', '"b"'), true);
  assert.equal(matchesEtag('"a","b"', '"b"'), true);
  assert.equal(matchesEtag('"a", "b"', '"c"'), false);
});

test('espaços em volta são ignorados', () => {
  assert.equal(matchesEtag('   "a"   ', '"a"'), true);
  assert.equal(matchesEtag('"x" ,  "a" , "y"', '"a"'), true);
});

test('* casa com qualquer etag', () => {
  assert.equal(matchesEtag('*', '"a"'), true);
  assert.equal(matchesEtag('  *  ', '"qualquer"'), true);
});

test('prefixo W/ (weak) é ignorado dos dois lados', () => {
  assert.equal(matchesEtag('W/"a"', '"a"'), true);
  assert.equal(matchesEtag('"a"', 'W/"a"'), true);
  assert.equal(matchesEtag('W/"a"', 'W/"a"'), true);
  assert.equal(matchesEtag('"x", W/"a"', '"a"'), true);
});

test('W/ com espaço depois da barra também é aceito', () => {
  assert.equal(matchesEtag('W/ "a"', '"a"'), true);
});

test('If-None-Match ausente ou vazio nunca casa', () => {
  assert.equal(matchesEtag(null, '"a"'), false);
  assert.equal(matchesEtag('', '"a"'), false);
  assert.equal(matchesEtag('   ', '"a"'), false);
});

test('entrada vazia no meio da lista não casa por engano', () => {
  assert.equal(matchesEtag('"x", , "y"', '"a"'), false);
  assert.equal(matchesEtag(',', '""'), false);
});
