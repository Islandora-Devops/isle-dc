import {Selector} from 'testcafe';
import {adminUser} from './roles.js';


fixture`Migration Tests`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

const migrate_person_taxonomy = 'idc_ingest_taxonomy_persons';
const migrate_accessrights_taxonomy = 'idc_ingest_taxonomy_accessrights';
const migrate_copyrightanduse_taxonomy = 'idc_ingest_taxonomy_copyrightanduse';
const migrate_family_taxonomy = 'idc_ingest_taxonomy_family';
const migrate_genre_taxonomy = 'idc_ingest_taxonomy_genre';
const migrate_geolocation_taxonomy = 'idc_ingest_taxonomy_geolocation';
const migrate_language_taxonomy = 'idc_ingest_taxonomy_language';
const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';
const migrate_media_image = 'idc_ingest_media_image';
const migrate_media_document = 'idc_ingest_media_document';
const migrate_media_extracted_text = 'idc_ingest_media_extracted_text';
const migrate_media_file = 'idc_ingest_media_file';
const migrate_media_video = 'idc_ingest_media_video';
const migrate_media_remote_video = 'idc_ingest_media_remote_video';
const migrate_media_audio = 'idc_ingest_media_audio';
const migrate_resource_types = 'idc_ingest_taxonomy_resourcetypes';
const migrate_subject_taxonomy = 'idc_ingest_taxonomy_subject';
const migrate_corporatebody_taxonomy = 'idc_ingest_taxonomy_corporatebody';

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

test('Perform Family Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_family_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/family-01.csv'
    ])
    .click('#edit-import');

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_family_taxonomy))
    .expect(selectUpdateExistingRecords.checked).ok();  // n.b. checked by default

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/family-02.csv'
    ])
    .click('#edit-import');

});

test('Perform Access Rights Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_accessrights_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/accessrights.csv'
    ])
    .click('#edit-import');

});

test('Perform Copyright and Use Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_copyrightanduse_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/copyrightanduse.csv'
    ])
    .click('#edit-import');

});

test('Perform Subject Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_subject_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/subject.csv'
    ])
    .click('#edit-import');

});

test('Perform Geolocation Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_geolocation_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/geolocation.csv'
    ])
    .click('#edit-import');

});

test('Perform Resource Types Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_resource_types));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/resourcetypes.csv'
    ])
    .click('#edit-import');

});

test('Perform Language Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_language_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/language.csv'
    ])
    .click('#edit-import');

});

test('Perform Corporate Body Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_corporatebody_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/corporatebody-01.csv'
    ])
    .click('#edit-import');

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_corporatebody_taxonomy))
    .expect(selectUpdateExistingRecords.checked).ok();  // n.b. checked by default

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/corporatebody-02.csv'
    ])
    .click('#edit-import');

});

test('Perform Collection Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_new_collection));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/collection-01.csv'
    ])
    .click('#edit-import');

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_new_collection))
    .expect(selectUpdateExistingRecords.checked).ok();  // n.b. checked by default

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/collection-02.csv'
    ])
    .click('#edit-import');

});

test('Perform Genre Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_genre_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/genre.csv'
    ])
    .click('#edit-import');

});

test('Perform Repository Object Migration', async t => {
  // Migrate dependencies first

  // persons
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_person_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object-persons.csv'
    ])
    .click('#edit-import');

  // subjects
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_subject_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object-subjects.csv'
    ])
    .click('#edit-import');

  // locations
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_geolocation_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object-geolocations.csv'
    ])
    .click('#edit-import');

  // genres
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_genre_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object-genres.csv'
    ])
    .click('#edit-import');

  // corporate bodies

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_corporatebody_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object-corporatebodies.csv'
    ])
    .click('#edit-import');

  // collections

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_new_collection));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object-collections.csv'
    ])
    .click('#edit-import');

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_new_items));

  // Migrate Islandora Repository Objects

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object.csv'
    ])
    .click('#edit-import');

});

test('Perform Media Migrations', async t => {

    // Migrate the Collection and Repository Object the Media will be attached to

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_new_collection));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-collection.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_new_items));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-islandora_object.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_image));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-image.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_document));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-document.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_extracted_text));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-extracted_text.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_file));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-file.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_video));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-video.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_remote_video));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-remote_video.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_audio));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-audio.csv'
        ])
        .click('#edit-import');
});
