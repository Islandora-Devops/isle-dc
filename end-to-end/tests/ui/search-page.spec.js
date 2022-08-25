import Page from './pages/searchable';

fixture `Search Page`
  .page `https://islandora-idc.traefik.me/search`;

test('Returns all items by default', async (t) => {
  const pager = Page.pagers[0];

  await Page.listOptions.itemsPerPage.setValue('10');

  await t
    .expect(Page.titleBar.withText('Search Results').exists).ok()
    // TMP: Possibly including a object that is not intended to be returned.
    .expect(pager.pager.withText('of 22 items').exists).ok()
    .expect(pager.buttons.count).eql(5);
});

test('Entering a new search term resets current page', async (t) => {
  const pager = Page.pagers[0];

  await Page.listOptions.itemsPerPage.setValue('10');

  await t
    .takeScreenshot({ "fullPage": true })
    // First search for 'moo'
    .typeText(Page.searchInput, 'moo', { paste: true })
    .click(Page.searchSubmit)
    .expect(Page.results.count).eql(10)
    .expect(pager.buttons.withText('2').exists).notOk()
    // Second search for 'animal'
    .typeText(Page.searchInput, 'animal', { paste: true, replace: true })
    .click(Page.searchSubmit)
    .expect(Page.results.count).eql(8)
    .expect(pager.pager.withText('8 of 8 items').exists).ok();
});

test('Selecting or deselecting a facet resets current page', async (t) => {
  const pager = Page.pagers[0];

  await Page.listOptions.itemsPerPage.setValue('10');

  const facet = {
    category: 'Resource Type',
    value: 'Dataset'
  };

  await pager.goToPage(3);

  await t.click(Page.facetToggle(facet.category));

  await Page.selectFacet(facet.category, facet.value);

  // Checking the current results list should be sufficient, because if the page
  // param were set to anything other than the first page, then no results
  // would be shown
  await t
    .expect(pager.pager.withText('8 of 8 items').exists).ok()
    .expect(Page.results.count).eql(8);
});
