import { Selector } from 'testcafe';
import { adminUser } from './roles.js';


fixture `Migration Tests`
  .page `https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach( async t => {
    await t
      .useRole(adminUser);
  });

const migrate_person_taxonomy = 'idc_ingest_taxonomy_persons';
const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';
const migrate_media_images = 'idc_ingest_media_images';

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');
const selectUpdateExistingRecords = Selector('#edit-update-existing-records');

test('Perform Person Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_person_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/persons-01.csv'
    ])
    .click('#edit-import');

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_person_taxonomy))
    .expect(selectUpdateExistingRecords.checked).ok();  // n.b. checked by default

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/persons-02.csv'
    ])
    .click('#edit-import');

});

test('Perform Collection Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_new_collection));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/collection.csv'
    ])
    .click('#edit-import');

});

test('Perform Repository Object Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_new_items));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/item.csv'
    ])
    .click('#edit-import');

});

test('Perform Image Media Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_media_images));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/image-media.csv'
    ])
    .click('#edit-import');

});
