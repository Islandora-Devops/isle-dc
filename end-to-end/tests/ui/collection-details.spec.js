import Page from './pages/collection-details';

/**
 * Duck Collection page
 */
fixture `Collection Details Page`
  .page`https://islandora-idc.traefik.me/node/42`

test('English description is displayed', async (t) => {
  await t
    .expect(Page.description.exists).ok()
    .expect(Page.description.withText('Collection of ducks').exists).ok()
    .expect(Page.description.withText('(English)').exists).ok();
});

test('Action buttons present', async (t) => {
  await t
    .expect(Page.contactBtn.exists).ok()
    .expect(Page.copyUrlBtn.exists).ok()
    .expect(Page.downloadBtn.exists).notOk();
});

test('Metadata toggle', async (t) => {
  await t
    .expect(Page.drawerContent.clientHeight).eql(0)
    .click(Page.drawerToggle)
    .expect(Page.drawerContent.clientHeight).gt(0)
    .click(Page.drawerToggle)
    .expect(Page.drawerContent.clientHeight).eql(0);
});

test('Metadata display', async (t) => {
  await Page.toggleMetadata();

  await t
    .expect(Page.metadata.count).eql(6)
    .expect(Page.metadata.withText('Translated Descriptions').exists).ok()
    .expect(Page.metadata.withText('Alternative Titles').exists).ok()
    .expect(Page.metadata.withText('Contact Name').exists).ok()
    .expect(Page.metadata.withText('Contact Email').exists).ok()
    .expect(Page.metadata.withText('Collection Numbers').exists).ok()
    .expect(Page.metadata.withText('Citable URL').exists).ok()
    .expect(Page.metadata.withText('Finding Aids').exists).ok();

  await t
    .expect(Page.metadata.withText('ducks (Spanish)').exists).ok()
    .expect(Page.metadata.withText('Moo Jones').exists).ok()
    .expect(Page.metadata.withText('moo@example.com').exists).ok()
    .expect(Page.metadata.withText('/node/42').exists).ok();
});

test('Shows both collections and repo items', async (t) => {
  await t
    .expect(Page.results.count).eql(3)
    .expect(Page.results.withText('SubDuck Collection').exists).ok()
    .expect(Page.results.withText('Mallard').exists).ok();
});

test('Facet toggle', async (t) => {
  await t.expect(Page.facetCategories.count).eql(3);

  const category = 'Year';
  const valueContainer = Page.facetValueContainer(category);
  await t
    .expect(valueContainer.clientHeight).gt(0)
    .click(Page.facetToggle(category))
    .expect(valueContainer.clientHeight).eql(0);
});

test('Selecting facets', async (t) => {
  const category = 'Year';
  await t
    .expect(Page.facetValues(category).count).eql(2)
    .expect(Page.results.count).eql(3);

  await Page.selectFacet(category, '2000-01-01');

  await t.expect(Page.results.count).eql(1);
});

test('Contact modal displays correctly', async (t) => {
  await t
    .expect(Page.contactModal.visibility().exists).notOk()
    .click(Page.contactBtn)
    .expect(Page.contactModal.visibility().exists).ok()
    .expect(Page.contactModal.collection.value).eql('Duck Collection (42)')
    .click(Page.contactModal.closeBtn)
    .expect(Page.contactModal.visibility().exists).notOk();
});

// TODO: enable once this bug is fixed
test.skip('Featured repo items display correctly', async (t) => {
  await t
    .expect(Page.featuredItems.list.exists).ok()
    .expect(Page.featuredItems.items.count).eql(2)
    .expect(Page.featuredItems.items.nth(0).find('image').exists).ok()
    // Mallard item has a Tiff image, which should never be displayed on the page
    .expect(Page.featuredItems.items.nth(0).find('image').attributes.src).notContains('.tif');
});
