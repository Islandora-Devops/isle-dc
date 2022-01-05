import GlobalSearch from './pages/global-search';
import Results from './pages/searchable';

fixture`Global Search`
  .page`https://islandora-idc.traefik.me`;

test('A basic single word search', async (t) => {
  await GlobalSearch.search('duck', t);
  await t.expect(Results.results.count).eql(4);
});

test('Boolean search: "duck AND yellow"', async (t) => {
  await GlobalSearch.search('yellow AND duck', t);
  await t.expect(Results.results.count).eql(1);
});

test('Boolean search: "s3 OR duck"', async (t) => {
  await GlobalSearch.search('s3 OR duck', t);
  await t.expect(Results.results.count).eql(6);
});

test('Simple wildcard with "*": "test*"', async (t) => {
  await GlobalSearch.search('test*', t);
  await t.expect(Results.results.count).eql(5);
});

test('Simple windcard with "?": "te?t"', async (t) => {
  await GlobalSearch.search('te?t', t);
  await t.expect(Results.results.count).eql(6);
});

test('Use of double quotes to search exact phrase: "Copyright Undetermined"', async (t) => {
  // This should omit items marked as "In Copyright" for example
  await GlobalSearch.search('"Copyright Undetermined"', t);
  await t.expect(Results.results.count).eql(4);
});

test('Compound search: "(duck AND toy) OR goat"', async (t) => {
  await GlobalSearch.search('(duck AND toy) OR goat', t);
  await t.expect(Results.results.count).eql(2);
});

test('Proximity search: \'"test render"~3\'', async (t) => {
  await GlobalSearch.search('"test render"~3', t);
  await t.expect(Results.results.count).eql(1);
});
