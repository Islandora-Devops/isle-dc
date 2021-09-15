import HeaderFooter from './pages/header-footer';
import { ImagePage } from './pages/item-details';

async function hasMetadata(t, field, value) {
  const selector = ImagePage.metadata.withText(field).parent();
  await t
    .expect(selector.exists).ok()
    .expect(selector.withText(value).exists).ok();
}

/**
 * Item details for 'Mallard' item, a single Tiff image
 */
fixture `Repository Item Details Page`
  .page `https://islandora-idc.traefik.me/node/49`;

test('Description', async (t) => {
  await t.expect(ImagePage.description.withText('(English)').exists).ok();
});

test('Metadata', async (t) => {
  await t.expect(ImagePage.metadata.count).eql(15);

  await hasMetadata(t, 'Alternative Title', 'Mallard Duck (English)');
  await hasMetadata(t, 'Alternative Title', 'Pato Mallard (Spanish)');
  await hasMetadata(t, 'Member of', 'Duck Collection');
  await hasMetadata(t, 'Resource Type', 'Image');
  await hasMetadata(t, 'Access Rights', 'Public digital access');
  await hasMetadata(t, 'Date Available', '2001-01-01');
  await hasMetadata(t, 'Date Created', '2001-01-01');
  await hasMetadata(t, 'Date Copyrighted', '2001-01-01');
  await hasMetadata(t, 'Date Published', '2001-01-01');
  await hasMetadata(t, 'Citable URL', '/node/49');
  await hasMetadata(t, 'Title Language', 'English');
  await hasMetadata(t, 'Description', 'a dabbling duck');
});

test('Contact modal', async (t) => {
  await t
    .expect(ImagePage.contactBtn.exists).ok()
    .expect(ImagePage.contactModal.visibility().exists).notOk()
    .click(ImagePage.contactBtn)
    .expect(ImagePage.contactModal.visibility().exists).ok()
    // Make sure collection is auto-filled
    .expect(ImagePage.contactModal.collection.value).eql('Duck Collection (42)');
});

test('Breadcrumbs are present', async (t) => {
  await t
    .expect(HeaderFooter.breadcrumbContainer.exists).ok()
    .expect(HeaderFooter.breadcrumbs.count).eql(3)
    .expect(HeaderFooter.breadcrumbs.withText('Home').exists).ok()
    .expect(HeaderFooter.breadcrumbs.withText('Farm Animals').exists).ok()
    .expect(HeaderFooter.breadcrumbs.withText('Duck Collection').exists).ok();
});

test('Download', async (t) => {
  await t
    .expect(ImagePage.downloadBtn.exists).ok()
    .expect(ImagePage.downloadModal.visibility().exists).notOk()
    .click(ImagePage.downloadBtn)
    .expect(ImagePage.downloadModal.visibility().exists).ok()
    .expect(ImagePage.downloadModal.content.count).eql(3)
    .expect(ImagePage.downloadModal.content.find('a[download]').count).eql(3);
});

test('Export metadata', async (t) => {
  await t
    .expect(ImagePage.citationsModal.visibility().exists).notOk()
    .expect(ImagePage.citationsBtn.exists).ok()
    .click(ImagePage.citationsBtn)
    .expect(ImagePage.citationsModal.visibility().exists).ok()
    .expect(ImagePage.citationsModal.citations.count).eql(3);
});
