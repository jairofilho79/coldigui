import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  validatePublication,
  resolvePublicationFields,
} from './publication_rules.ts';

test('exige categoria ao publicar', () => {
  const err = validatePublication(null, { isPublished: true });
  assert.equal(err, 'publicationCategory required');
});

test('bloqueia despublicar', () => {
  const err = validatePublication(
    {
      is_published: 1,
      publication_reach: 'usual',
      publication_category: 'medleys',
      published_at: '2026-01-01T00:00:00.000Z',
    },
    { isPublished: false },
  );
  assert.equal(err, 'cannot unpublish');
});

test('bloqueia mudar categoria após publicada', () => {
  const err = validatePublication(
    {
      is_published: 1,
      publication_reach: 'usual',
      publication_category: 'medleys',
      published_at: '2026-01-01T00:00:00.000Z',
    },
    { isPublished: true, publicationCategory: 'aprendizado' },
  );
  assert.equal(err, 'publicationCategory immutable');
});

test('default reach usual na primeira publicação', () => {
  const fields = resolvePublicationFields(null, {
    isPublished: true,
    publicationCategory: 'evangelizacao',
  });
  assert.equal(fields.isPublished, 1);
  assert.equal(fields.publicationReach, 'usual');
  assert.equal(fields.newlyPublished, true);
});
