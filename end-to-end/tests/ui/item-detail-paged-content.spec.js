import { BookPage } from './pages/item-details';
/**
 * Item details page for "A book" object - a paged content item
 */
fixture `Paged Content item`
  .page `https://islandora-idc.traefik.me/node/51`;

test('Mirador viewer exists', async (t) => {
  await t
    .expect(BookPage.viewer.exists).ok('Mirador container not found')
    .expect(BookPage.content.exists).ok('Mirador has no content')
    .expect(BookPage.thumbnails.count).eql(2);
});
