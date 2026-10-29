import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { SHORT_CODE_PATTERN, isShortCode, randomShortCode } from './short_code.ts';

test('randomShortCode gera 7 chars [a-z0-9]', () => {
  for (let i = 0; i < 50; i++) {
    const code = randomShortCode();
    assert.equal(code.length, 7);
    assert.match(code, SHORT_CODE_PATTERN);
  }
});

test('isShortCode aceita só o formato exato', () => {
  assert.equal(isShortCode('k7x2m9q'), true);
  assert.equal(isShortCode('K7X2M9Q'), false);
  assert.equal(isShortCode('k7x2m9'), false);
  assert.equal(isShortCode('k7x2m9qq'), false);
  assert.equal(isShortCode(42), false);
  assert.equal(isShortCode(null), false);
});
