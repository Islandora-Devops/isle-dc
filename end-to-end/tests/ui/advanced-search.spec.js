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
    .expect(Page.results.count).eql(3);

  await t.click(Page.addTermBtn);

  const term2 = Page.queryTerm(1);

  await t
    .expect(term2.selectedOp().withText('AND').exists).ok()
    .expect(term2.proxy.value).eql('false')
    .click(term2.proxy)
    .expect(term2.proxy.value).eql('true')
    .typeText(term2.proxyTerm.termA, 'two')
    .typeText(term2.proxyTerm.range, '3')
    .typeText(term2.proxyTerm.termB, 'content')
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(1);

  await t
    .click(term2.removeBtn)
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(3);

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
  await t.expect(Page.results.count).eql(10);

  await Page.pagers[0].goToPage(3);

  const term1 = Page.queryTerm(0);

  await t
    .expect(term1.proxy.value).eql('false')
    .typeText(term1.nonproxyTerm.term, 'animal')
    .click(term1.nonproxyTerm.field)
    .click(term1.nonproxyTerm.fields.withText('Title'))
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(2, { timeout: 30000 });

  await t.click(Page.addTermBtn);

  const term2 = Page.queryTerm(1);
  await t
    .click(term2.opOr)
    .expect(term2.nonproxyTerm.field.value).eql('')
    .typeText(term2.nonproxyTerm.term, 'page')
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(5);
});

test('Collection filter', async (t) => {
  const pager = Page.pagers[0];

  await pager.goToPage(3);

  await t
    .expect(Page.results.count).eql(4)
    .expect(pager.pager.withText('24 of 24 items').exists).ok();

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
 * Enter date 1: 2000
 * Enter Date 2: 2010
 * Enter basic keyword search: 'item'
 * Hit Clear (search term) button
 *      Clearing terms will clear the search, but will not clear the date filter!
 * Hit the Clear (filters) button
 */
test('Date filter and basic search', async (t) => {
  const term = Page.queryTerm(0);
  await t
    .typeText(Page.dateInput1, '2000', { paste: true})
    .pressKey('enter')
    .expect(Page.results.count).eql(5)
    .typeText(Page.dateInput2, '2010', { paste: true})
    .pressKey('tab')
    .expect(Page.results.count).eql(8)
    .typeText(term.nonproxyTerm.term, 'item', { paste: true})
    .click(Page.submitBtn)
    .expect(Page.results.count).eql(5)
    .click(Page.clearTerms)
    .expect(Page.results.count).eql(8)
    .click(Page.clearFilters)
    .expect(Page.results.count).eql(10);
});

test('Date filter will reset current page', async (t) => {
  const pager = Page.pagers[0];

  await t.expect(Page.results.count).eql(10);
  await pager.goToPage(3);
  await t
    .expect(Page.results.count).eql(4)
    .expect(pager.pager.withText('24 of 24 items').exists).ok();

  await t
    .typeText(Page.dateInput1, '2000', { paste: true })
    .pressKey('enter')
    .expect(Page.results.count).eql(5)
    .expect(pager.pager.withText('5 of 5 items').exists).ok();

});
