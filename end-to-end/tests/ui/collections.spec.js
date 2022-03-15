import { getCurrentUrl } from '../helpers';
import { anon, localAdmin } from '../roles';
import page from './pages/collections-list';

fixture `Collections Page`
  .page `https://islandora-idc.traefik.me/collections`;

/**
 *
 * @param {class} t Testcafe controller
 * @param {string} query search query
 * @returns {string} URL after search is executed
 */
async function doSearch(t, query) {
  await t
    .expect(page.searchInput.exists).ok()
    .expect(page.searchSubmit.exists).ok()
    .typeText(page.searchInput, query, { replace: true, paste: true })
    .expect(page.searchInput.value).contains(query)
    .click(page.searchSubmit);

  return await getCurrentUrl();
}

test('Has expected number of collections', async (t) => {
  await t
    .expect(page.results.count).eql(14)
    .expect(page.pagers[0]).ok()
    .expect(page.pagers[0].pager.textContent).contains('1 – 14 of');
});

test('Pager controls work', async (t) => {
  const pager = page.pagers[0];

  await page.listOptions.itemsPerPage.setValue('10');

  await t
    .expect(pager).ok('No pager found on page')
    .expect(pager.buttons.count).eql(4);

  await t
    .expect(pager.next.exists).ok()
    .expect(pager.next.withAttribute('disabled').exists).notOk('Next btn was disabled, should be enabled')
    .click(pager.next)
    .expect(getCurrentUrl()).contains('page=1')
    .expect(page.results.count).gte(3);
});

test('Basic search input', async (t) => {
  const query = 'animal';
  const url = await doSearch(t, query);

  await t
    .expect(url).contains(`query=${query}`)
    .expect(page.results.count).eql(7);
});

test('Proximity search syntax', async (t) => {
  const query = '"collection images"~5';
  const url = await doSearch(t, query);

  await t
    .expect(decodeURI(url)).contains(`query=${query}`)
    .expect(page.results.count).eql(6);
});

/**
 * Do a search, then change sort order to DESC and see that
 * the ordering has changed.
 */
test('List option: sort order', async (t) => {
  const orderValue = 'sort_order=DESC';
  await doSearch(t, 'animal');

  await t
    .expect(page.results.count).eql(7)
    .expect(page.results.nth(0).withText('Duck Collection').exists).ok();

  await page.listOptions.sortOrder.setValue(`&${orderValue}`);

  await t
    .expect(await getCurrentUrl()).contains(orderValue)
    .expect(page.results.nth(0).withText('Arctic Animals').exists).ok();
});

test('List option: sort by', async (t) => {
  const value = 'sort_by=title';
  await doSearch(t, 'moo');

  await t
    .expect(page.results.count).eql(4)
    .expect(page.results.nth(0).withText('Duck Collection').exists).ok();

  await page.listOptions.sortBy.setValue(`&${value}`);

  await t
    .expect(await getCurrentUrl()).contains(value)
    .expect(page.results.nth(0).withText('Cow Collection').exists).ok();
});

test('List option: items per page', async (t) => {
  await doSearch(t, 'animal');

  await t.expect(page.results.count).eql(7);

  await page.listOptions.itemsPerPage.setValue('5');

  await t.expect(page.results.count).eql(5);
});

test('List option: go to page', async (t) => {
  await page.listOptions.itemsPerPage.setValue('10');

  await t.expect(page.pagers[0].pager.withText('1 – 10').exists).ok();

  await page.listOptions.currentPage.setValue('2');

  await t.expect(page.pagers[0].pager.withText('11 – ').exists).ok();
});

test('Featured items', async (t) => {
  await t
    .expect(page.featuredItems.list.exists).ok()
    .expect(page.featuredItems.items.count).eql(2)
    .expect(page.featuredItems.items.withText('Duck Collection').exists).ok();
});

test('Only collection export exists', async (t) => {
  await t
    .expect(page.exportColBtn.exists).notOk()
    .useRole(localAdmin)
    .expect(page.exportColBtn.exists).ok()
    .expect(page.exportItmBtn.exists).notOk()
    .useRole(anon);
});
