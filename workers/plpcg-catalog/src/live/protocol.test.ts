import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { MAX_ENTRIES, parseClientFrame } from './protocol.ts';

const snapshot = {
  playlistId: 'p1',
  name: 'Culto',
  entries: [{ id: 'abc', kind: 'pdf' }],
  focusKey: 'abc',
};

test('hello válido, com e sem token; nick é aparado e limitado', () => {
  const plain = parseClientFrame(
    JSON.stringify({ t: 'hello', room: 'k7x2m9q', since: 3, clientId: 'c1' }),
  );
  assert.deepEqual(plain, { t: 'hello', room: 'k7x2m9q', since: 3, clientId: 'c1' });

  const withToken = parseClientFrame(
    JSON.stringify({
      t: 'hello', room: 'k7x2m9q', since: 0, clientId: 'c1',
      sessionToken: 'sess_x', nick: '  Maria Clara Souza de Oliveira Santos  ',
    }),
  );
  assert.equal((withToken as { sessionToken: string }).sessionToken, 'sess_x');
  assert.equal((withToken as { nick: string }).nick, 'Maria Clara Souza de Oli');
});

test('hello sem room/clientId ou since negativo é bad_frame', () => {
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'hello', since: 0, clientId: 'c1' })), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'hello', room: 'k7x2m9q', since: -1, clientId: 'c1' })), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'hello', room: 'k7x2m9q', since: 0 })), { error: 'bad_frame' });
});

test('start/set carregam snapshot validado; end não tem corpo', () => {
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'start', snapshot })), { t: 'start', snapshot });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot })), { t: 'set', snapshot });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'end' })), { t: 'end' });
});

test('snapshot rejeita entradas malformadas, focusKey não-string e > 200 entradas', () => {
  const badEntry = { ...snapshot, entries: [{ id: 'abc' }] };
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot: badEntry })), { error: 'bad_frame' });
  const badFocus = { ...snapshot, focusKey: 7 };
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot: badFocus })), { error: 'bad_frame' });
  const tooMany = { ...snapshot, entries: Array.from({ length: MAX_ENTRIES + 1 }, (_, i) => ({ id: `e${i}`, kind: 'pdf' })) };
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot: tooMany })), { error: 'too_large' });
});

test('JSON inválido, t desconhecido e frame sem t são bad_frame', () => {
  assert.deepEqual(parseClientFrame('{'), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'dance' })), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({})), { error: 'bad_frame' });
});
