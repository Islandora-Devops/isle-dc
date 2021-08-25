import { getCurrentUrl, migrate } from '../helpers';
import { localAdmin } from '../roles';
import { Selector } from 'testcafe';

const uiSourcePrefix = '../testdata/ui/';
const uiMigrations = {
  persons: {
    id: 'idc_ingest_taxonomy_persons',
    index: 0,
    files: [ 'persons.csv' ]
  },
  accessTerms: {
    id: 'idc_ingest_taxonomy_islandora_accessterms',
    index: 1,
    files: [ 'access-terms.csv' ]
  },
  subjects: {
    id: 'idc_ingest_taxonomy_subject',
    index: 2,
    files: [ 'subject.csv' ]
  },
  collections: {
    id: 'idc_ingest_new_collection',
    index: 3,
    files: [
      'series-1-collections-01.csv',
      'series-1-collections-02.csv'
    ]
  },
  items: {
    id: 'idc_ingest_new_items',
    index: 4,
    files: [ 'series-2-items-01.csv' ]
  },
  images: {
    id: 'idc_ingest_media_image',
    index: 5,
    files: [ 'media-images.csv' ]
  },
  documents: {
    id: 'idc_ingest_media_document',
    index: 6,
    files: [ 'media-documents.csv' ]
  },
  audio: {
    id: 'idc_ingest_media_audio',
    index: 7,
    files: [ 'media-audio.csv' ]
  },
  video: {
    id: 'idc_ingest_media_video',
    index: 8,
    files: [ 'media-video.csv' ]
  }
};

const ui_migration_test_path = 'ui_migration';

/**
 * This is run separately by NPM first before the rest of the UI tests
 * in order to populate the site with data
 */

fixture `Run UI Data Migrations`
  .page `https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async (t) => {
    await t.useRole(localAdmin);
  });

/**
 * Perform a set of migrations to ready the system with data to test UI features
 *
 * @param {class} t testcafe test controller
 * @param {number} timeout (OPTIONAL) time in ms to wait for each migration to finish
 *                  Default: 10000 (10 seconds)
 */
async function addUiData(t, timeout = 10000) {
  const origin = await getCurrentUrl();

  await t.navigateTo('https://islandora-idc.traefik.me/migrate_source_ui');

  Object.values(uiMigrations)
    .sort((m1, m2) => m1.index - m2.index)
    .forEach(async (migration) => {
      migration.files.forEach(async (file) => {
        await migrate(t, migration.id, `${uiSourcePrefix}${file}`, timeout);
      });
    });

  // When done, create an article for easy checking
  await addUIArticle(t);

  await t.navigateTo(origin);
}

/**
 * Add an article with known data so we can later check to see if UI
 * migrations have already been run.
 *
 * @param {class} t Testcafe controller
 */
async function addUIArticle(t) {
  const origin = await getCurrentUrl();
  await t.navigateTo('https://islandora-idc.traefik.me/node/add/article');
  console.log('  > Creating marker article');

  await t
    .expect(Selector('h1').withText('Create Article').exists)
    .ok('Not on article creation page');

  await t
    .typeText('#edit-title-0-value', 'UI Migrations')
    .click('#edit-path-0')
    .typeText('#edit-path-0-alias', `/${ui_migration_test_path}`)
    .click('#edit-submit')
    .expect(Selector('title').withText('UI Migrations | Default').exists).ok();

  await t.navigateTo(origin);
}

/**
 * See if UI migrations have been done already by checking to see if the
 * marker article exists
 *
 * @param {class} t Testcafe controller
 * @returns {boolean} TRUE if marker article was found, FALSE otherwise
 */
async function checkForUIMigrations(t) {
  const origin = await getCurrentUrl();

  await t.navigateTo(`https://islandora-idc.traefik.me/${ui_migration_test_path}`);
  const result = await Selector('title').withText('UI Migrations | Default').exists;

  await t.navigateTo(origin);

  return result;
}

test('Do migrations', async (t) => {
  if (!(await checkForUIMigrations(t))) {
    await addUiData(t);
  }
});

