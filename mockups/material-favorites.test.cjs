const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const assert = require('node:assert/strict');

function model() {
  const html = readFileSync(join(__dirname, 'material-favorites.html'), 'utf8');
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const context = vm.createContext({});
  vm.runInContext(script, context);
  return expression => JSON.parse(vm.runInContext(`JSON.stringify(${expression})`, context));
}

test('only audio and YouTube are excluded, including audio aliases', () => {
  const run = model();
  assert.deepEqual(run(`eligibleTypes([
    'pdf', 'chord', 'gestures', 'lyrics', 'video', 'mp3', 'audio', 'YouTube',
    'WAV', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'webm'
  ])`), ['pdf', 'chord', 'gestures', 'lyrics', 'video']);
});

test('lyrics and single-format categories remain available', () => {
  const run = model();
  assert.equal(run("catalog.find(item => item.id === 'letra').types[0]"), 'lyrics');
  assert.equal(run("catalog.find(item => item.id === 'partitura').types.length"), 1);
});

test('all three models allow changing the preferred type independently', () => {
  const run = model();
  for (const id of ['inline', 'panel', 'sheet']) {
    assert.equal(run(`chooseType(states.${id}, 'cifra', 'pdf')`), true);
    assert.equal(run(`preferredType(states.${id}, 'cifra')`), 'pdf');
  }
  run("chooseType(states.inline, 'cifra', 'chord')");
  assert.equal(run("preferredType(states.panel, 'cifra')"), 'pdf');
});

test('types can be promoted but excluded or unavailable types cannot be chosen', () => {
  const run = model();
  assert.equal(run("chooseType(states.sheet, 'cifra', 'pdf')"), true);
  assert.deepEqual(run("states.sheet.typeOrders.cifra"), ['pdf', 'chord']);
  assert.equal(run("chooseType(states.sheet, 'cifra', 'audio')"), false);
  assert.equal(run("chooseType(states.sheet, 'cifra', 'youtube')"), false);
  assert.equal(run("chooseType(states.sheet, 'partitura', 'chord')"), false);
});

test('reordering favorites preserves every category exactly once', () => {
  const run = model();
  assert.equal(run("moveFavorite(states.inline, 'partitura', -1)"), true);
  assert.deepEqual(run("states.inline.favorites"), ['cifra', 'partitura', 'gestos']);
  assert.equal(run("moveFavorite(states.inline, 'cifra', -1)"), false);
});

test('adding, removing and the existing five-category limit work', () => {
  const run = model();
  assert.equal(run("addFavorite(states.inline, 'letra')"), true);
  assert.equal(run("addFavorite(states.inline, 'clarinete')"), true);
  assert.equal(run("addFavorite(states.inline, 'violino')"), false);
  assert.equal(run("addFavorite(states.inline, 'letra')"), false);
  assert.equal(run("removeFavorite(states.inline, 'cifra')"), true);
  assert.equal(run("addFavorite(states.inline, 'violino')"), true);
  assert.equal(run("states.inline.favorites.length"), 5);
});

test('search ignores accents and covers both category and type names', () => {
  const run = model();
  assert.equal(run("matchesQuery(catalog.find(item => item.id === 'violino'), 'violíno')"), true);
  assert.equal(run("matchesQuery(catalog.find(item => item.id === 'gestos'), 'pdf')"), true);
  assert.equal(run("matchesQuery(catalog.find(item => item.id === 'letra'), 'letra')"), true);
  assert.equal(run("matchesQuery(catalog.find(item => item.id === 'letra'), 'audio')"), false);
});

test('unknown non-excluded types keep a visible label', () => {
  const run = model();
  assert.equal(run("typeLabel('video')"), 'video');
});
