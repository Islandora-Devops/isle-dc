import page from './pages/collections-list';

fixture('Collections Page: init from URL')
  .page('https://islandora-idc.traefik.me/collections?query=animal&page=1&sort_by=title&sort_order=DESC&items_per_page=5');

test('Init from URL', async (t) => {
  await t
    .resizeWindow(1024, 3885)
    .expect(page.searchInput.value).eql('animal')
    .expect(page.pagers[0].pager.withText('6 – 7').exists).ok()
    .expect(page.results.count).eql(2)
    .expect(page.results.withText('Cow Collection').exists).ok()
    .expect(page.listOptions.sortBy.select.value).eql('&sort_by=title')
    .expect(page.listOptions.sortOrder.select.value).eql('&sort_order=DESC')
    .expect(page.listOptions.itemsPerPage.select.value).eql('5')
    .expect(page.listOptions.currentPage.select.value).eql('2');
});
