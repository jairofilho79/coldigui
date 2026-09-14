import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  SESSION_TOKEN_PREFIX,
  generateSessionToken,
  hashSessionToken,
  isSessionToken,
} from './session_token.ts';

test('token tem o prefixo e 43 chars de base64url (32 bytes)', () => {
  const token = generateSessionToken();
  assert.ok(token.startsWith(SESSION_TOKEN_PREFIX));
  const body = token.slice(SESSION_TOKEN_PREFIX.length);
  assert.equal(body.length, 43);
  assert.match(body, /^[A-Za-z0-9_-]+$/);
});

test('dois tokens diferem', () => {
  assert.notEqual(generateSessionToken(), generateSessionToken());
});

test('isSessionToken distingue sessão de JWT', () => {
  assert.equal(isSessionToken('sess_abc'), true);
  assert.equal(isSessionToken('eyJhbGciOi.eyJzdWIi.sig'), false);
  assert.equal(isSessionToken(''), false);
});

test('hash é SHA-256 hex, determinístico e diferente do token', async () => {
  const token = 'sess_fixo';
  const a = await hashSessionToken(token);
  const b = await hashSessionToken(token);
  assert.equal(a, b);
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.notEqual(a, token);
  assert.notEqual(a, await hashSessionToken('sess_outro'));
});
