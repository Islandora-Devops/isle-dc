import Page from './pages/advanced-search';

fixture `Advanced Search page`
  .page `https://islandora-idc.traefik.me/advanced-search`;

/**
 * Proxy search 'paged item'~3 (3 results)
 * Proxy search 'paged item'~3 & 'two content'~3 (1 result)
 * Check remove second term (3 results)
 * Clear button press (10 results)
 */
test('Proximity search and Clear button', async (t) => {
  await Page.listOptions.itemsPerPage.setValue('10');

  await t.expect(Page.results.count).eql(10);

  const term1 = Page.queryTerm(0);

  await t
    .expect(term1.proxy.value).eql('false', 'Query term should start as "false"')
    .click(term1.proxy)
    .expect(term1.proxy.value).eql('true')
    .typeText(term1.proxyTerm.termA, 'paged', { paste: true })
    .typeText(term1.proxyTerm.range, '3')
    .typeText(term1.proxyTerm.termB, 'item', { paste: true })
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(1);

  await t.click(Page.addTermBtn);

  const term2 = Page.queryTerm(1);

  await t
    .expect(term2.selectedOp().withText('AND').exists).ok()
    .expect(term2.proxy.value).eql('false')
    .click(term2.proxy)
    .expect(term2.proxy.value).eql('true')
    .typeText(term2.proxyTerm.termA, 'two', { paste: true })
    .typeText(term2.proxyTerm.range, '3')
    .typeText(term2.proxyTerm.termB, 'content', { paste: true })
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(0);

  await t
    .click(term2.removeBtn)
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(1);

  await t
    .click(Page.clearTerms)
    .expect(Page.results.count).eql(10);
});

/**
 * Navigate to results page 3 first
 * Normal search 'animal' (2 results)
 *  - Displaying any results means that the current page has been reset as expected
 * Normal search 'animal' OR 'page' (5 results)
 */
test('Normal search', async (t) => {
  await Page.listOptions.itemsPerPage.setValue('10');

  await t.expect(Page.results.count).eql(10);

  await Page.pagers[0].goToPage(3);

  const term1 = Page.queryTerm(0);

  await t
    .expect(term1.proxy.value).eql('false')
    .typeText(term1.nonproxyTerm.term, 'animal', { paste: true })
    .click(term1.nonproxyTerm.field)
    .click(term1.nonproxyTerm.fields.withText('Title'))
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(2);

  await t.click(Page.addTermBtn);

  const term2 = Page.queryTerm(1);
  await t
    .click(term2.opOr)
    .expect(term2.nonproxyTerm.field.value).eql('')
    .typeText(term2.nonproxyTerm.term, 'page', { paste: true })
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(3);
});

test('Can initiate search with Enter key', async (t) => {
  const term1 = Page.queryTerm(0);

  await t
    .click(term1.nonproxyTerm.field)
    .click(term1.nonproxyTerm.fields.withText('Title'))
    .typeText(term1.nonproxyTerm.term, 'moo', { paste: true })
    .pressKey('enter')
    .expect(Page.results.count).eql(1);
});

test('Collection filter', async (t) => {
  const pager = Page.pagers[0];

  await Page.listOptions.itemsPerPage.setValue('10');

  await pager.goToPage(3);

  await t
    .expect(Page.results.count).eql(2)
    .expect(pager.pager.withText('22 of 22 items').exists).ok();

  await t
    .click(Page.collectionsFilter.toggle) // Closed by default, need to open it first
    .typeText(Page.collectionsFilter.input, 'collection', { paste: true})
    .expect(Page.collectionsFilter.suggestions.count).eql(10)
    .typeText(Page.collectionsFilter.input, 'duck', { replace: true, paste: true })
    .expect(Page.collectionsFilter.suggestions.count).eql(2)
    .click(Page.collectionsFilter.suggestions.find('button').nth(0))
    .expect(Page.collectionsFilter.selectedCollections.count).eql(1)
    .expect(Page.collectionsFilter.selectedCollections.withText('Duck Collection').exists).ok()
    .expect(Page.results.count).eql(3)
    .click(Page.collectionsFilter.clearBtn)
    .expect(Page.collectionsFilter.suggestions.exists).notOk()
    .click(Page.collectionsFilter.selectedCollections.withText('Duck Collection'))
    .expect(Page.collectionsFilter.selectedCollections.exists).notOk()
    .expect(Page.results.count).eql(10);
});

/**
 * Enter basic keyword search: 'item'
 * Enter date 1: 2000
 * Enter Date 2: 2010
 * Hit Clear (search term) button
 * Hit the Clear (filters) button (no effect, because he first Clear will clear filters)
 */
test('Date filter and basic search', async (t) => {
  const term = Page.queryTerm(0);

  await Page.listOptions.itemsPerPage.setValue('10');

  await t
    .typeText(term.nonproxyTerm.term, 'item', { paste: true})
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(5)
    .typeText(Page.dateInput1, '2000', { paste: true})
    .pressKey('enter')
    .expect(Page.results.count).eql(2)
    .typeText(Page.dateInput2, '2010', { paste: true})
    .pressKey('tab')
    .expect(Page.results.count).eql(3)
    .click(Page.clearTerms)
    .expect(Page.results.count).eql(10);
});

test('Date filter will reset current page', async (t) => {
  const pager = Page.pagers[0];

  await Page.listOptions.itemsPerPage.setValue('10');

  await t.expect(Page.results.count).eql(10);
  await pager.goToPage(3);
  await t
    .expect(Page.results.count).eql(2)
    .expect(pager.pager.withText('22 of 22 items').exists).ok();

  await t
    .typeText(Page.dateInput1, '2000', { paste: true })
    .pressKey('enter')
    .expect(Page.results.count).eql(5)
    .expect(pager.pager.withText('5 of 5 items').exists).ok();

});

/**
 * Try a manually entered boolean query inside the advanced search
 *
 * Expected search: ?query="plastic material"~10 OR (test) NOT (item AND rendering)
 */
test('Compound boolean search', async (t) => {
  const term1 = Page.queryTerm(0);

  await t
    .click(term1.proxy)
    .typeText(term1.proxyTerm.termA, 'plastic', { paste: true, replace: true})
    .typeText(term1.proxyTerm.range, '10', { paste: true, replace: true})
    .typeText(term1.proxyTerm.termB, 'material', { paste: true, replace: true});

  const term2 = Page.queryTerm(1);

  await t
    .click(term2.opOr)
    .typeText(term2.nonproxyTerm.term, 'test', { paste: true, replace: true});

  const term3 = Page.queryTerm(2);

  await t
    .click(term3.opNot)
    .typeText(term3.nonproxyTerm.term, 'item AND rendering', { paste: true, replace: true});

  await t
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(6)
    .expect(Page.results.withText('A video item').exists).notOk()
    .expect(Page.results.withText('rubber duck').exists).ok();
});
