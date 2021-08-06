import {Selector} from 'testcafe';
import {adminUser} from "./roles";
import {ClientFunction} from 'testcafe';

const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';
const migrate_media_file = 'idc_ingest_media_file';
const migrate_media_image = 'idc_ingest_media_image';
const migrate_media_video = 'idc_ingest_media_video';
const migrate_media_document = 'idc_ingest_media_document';

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');

const migrateUi = "https://islandora-idc.traefik.me/migrate_source_ui"
const contentList = "https://islandora-idc.traefik.me/admin/content";

const getLocationFn = ClientFunction(() => window.location);

async function migrate(t, id, sourcefile) {
  await t.navigateTo(migrateUi)

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', id));

  await t
    .setFilesToUpload('#edit-source-file', [
      sourcefile
    ])
    .click('#edit-import');

  await migration(t)
}

async function migration(t) {
  const timeout = 300000 // 5 minutes
  var elapsed = 0
  var loc = await getLocationFn()
  let start = Date.now()

  while (loc.href !== migrateUi && elapsed < timeout) {
    console.log("Waiting for ingest at " + loc.href + " ...")
    await t.wait(10000)
    elapsed = Date.now() - start
    loc = await getLocationFn()
  }

  if (elapsed > timeout) {
    console.log("Timed out waiting for ingest at url " + loc.href + ", capturing screenshot.")
    await t.takeScreenshot({fullPage: true})
  }
}

fixture`Initialize Derivative Test Content`
  .page(migrateUi)
  .beforeEach(async t => {
    await t.useRole(adminUser);
  })

test('Migrating Derivative Test Content', async t => {
  // Migrate the Collection and Repository Objects the Media will be attached to
  console.log("Migrating collections ...")
  await migrate(t, migrate_new_collection, "./migrations/lfs-media-collection.csv")
  console.log("Migrating repository objects ...")
  await migrate(t, migrate_new_items, "./migrations/lfs-media-islandora_objects.csv")
  // Migrate large tif images
  console.log("Migrating media ...")
  await migrate(t, migrate_media_image, "./migrations/lfs-media-large-images.csv")
  await migrate(t, migrate_media_video, "./migrations/lfs-media-small-video.csv")
  await migrate(t, migrate_media_video, "./migrations/lfs-media-large-video.csv")
  await migrate(t, migrate_media_document, "./migrations/lfs-media-documents.csv")
});
