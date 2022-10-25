import { anon, localAdmin } from '../roles';
import Page from './pages/collection-details';
import HeaderFooter from './pages/header-footer';

/**
 * Duck Collection page
 */
fixture `Collection Details Page`
  .page`https://islandora-idc.traefik.me/node/42`

test('English description is displayed', async (t) => {
  await t
    .resizeWindow(1024, 3885)
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

test('Boolean operators still work as expected', async (t) => {
  await t
    .typeText(Page.searchInput, 'wild OR plastic', { paste: true, replace: true })
    .click(Page.searchSubmit)
    .expect(Page.results.count).eql(2)
    // The two items should be present, but not the sub collection
    .expect(Page.results.withText('SubDuck Collection').exists).notOk();
});

test('Facet toggle', async (t) => {
  await t.expect(Page.facetCategories.count).eql(4);

  const category = 'Years';
  const valueContainer = Page.facetValueContainer(category);
  await t
    .expect(valueContainer.clientHeight).eql(0)
    .click(Page.facetToggle(category))
    .expect(valueContainer.clientHeight).gt(0);
});

test('Selecting facets', async (t) => {
  const category = 'Years';
  const valueContainer = Page.facetValueContainer(category);
  await t
    .click(Page.facetToggle(category))
    .expect(Page.facetValues(category).count).eql(1)
    .expect(Page.results.count).eql(3);

  await Page.selectFacet(category, '2000');

  await t.expect(Page.results.count).eql(2);
  await t.expect(valueContainer.clientHeight).gt(0);
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

test('Featured repo items display correctly', async (t) => {
  await t
    .resizeWindow(1024, 3885)
    .expect(Page.featuredItems.list.exists).ok()
    .expect(Page.featuredItems.items.count).eql(2)
    .expect(Page.featuredItems.items.nth(0).find('img').exists).ok()
    // // Mallard item has a Tiff image, which should never be displayed on the page
    .expect(Page.featuredItems.items.nth(0).find('img').withAttribute('src', /\.jpg$/).exists).ok()
    // TMP: Does not load featured items when there is no image on a featured item.
    // .expect(Page.featuredItems.items.nth(1).withText('No image available').exists).ok();
});

test('Breadcrumbs are present', async (t) => {
  await t
    .resizeWindow(1024, 3885)
    .expect(HeaderFooter.breadcrumbContainer.exists).ok()
    // TMP: Does not load breadcrumbs when there is no breadcrumb for test only but they are present.
    // .expect(HeaderFooter.breadcrumbs.count).eql(3)
    .expect(HeaderFooter.breadcrumbs.withText('Home').exists).ok()
    .expect(HeaderFooter.breadcrumbs.withText('Farm Animals').exists).ok();
});

test('Export links look good', async (t) => {
  await t
    .resizeWindow(1024, 3885)
    .useRole(localAdmin)
    .expect(Page.exportColBtn.exists).ok()
    .expect(Page.exportColBtn.getAttribute('href'))
      .contains('/export_collections?query=itm_field_member_of:42 AND (ss_type:collection_object OR ss_type:islandora_object)&nodeId=42')
    .expect(Page.exportItmBtn.exists).ok()
    .expect(Page.exportItmBtn.getAttribute('href'))
      .contains('/export_items?query=itm_field_member_of:42 AND (ss_type:collection_object OR ss_type:islandora_object)&nodeId=42')
    .useRole(anon);
})
