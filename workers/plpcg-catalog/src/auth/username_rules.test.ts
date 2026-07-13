import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { normalizeUsername, validateUsername } from './username_rules.ts';

test('normaliza para minúsculas e trim', () => {
  assert.equal(normalizeUsername('  Joao_123  '), 'joao_123');
});

test('aceita handle válido', () => {
  assert.equal(validateUsername('abc'), null);
  assert.equal(validateUsername('user_name_01'), null);
});

test('rejeita formato inválido', () => {
  assert.equal(validateUsername('ab'), 'invalid username');
  assert.equal(validateUsername('Has-Dash'), 'invalid username');
  assert.equal(validateUsername('com espaço'), 'invalid username');
  assert.equal(validateUsername(''), 'username required');
  assert.equal(validateUsername(null), 'username required');
});
