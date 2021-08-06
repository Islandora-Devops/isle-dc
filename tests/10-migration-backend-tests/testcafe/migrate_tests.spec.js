import {Selector} from 'testcafe';
import {adminUser} from './roles.js';
import {doMigration} from './util.js';


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
const migrate_islandora_accessterms_taxonomy = 'idc_ingest_taxonomy_islandora_accessterms';
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

test('Perform Islandora Access Terms Taxonomy Migration', async t => {

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_islandora_accessterms_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/accessterms.csv'
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

  // access terms
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_islandora_accessterms_taxonomy));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object-accessterms.csv'
    ])
    .click('#edit-import');

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

// This is a quick test to ensure that one is able to edit items
// after ingesting them - there was an issue with unique ids where you could not
// edit items after creating them.  This is a basic sanity test to see if there is a
// issue like that again.
test('Perform Edit on Repository Item', async t => {
  await doMigration(t, migrate_new_items, './migrations/islandora_object-edit1.csv');

  await t
    .navigateTo('https://islandora-idc.traefik.me/admin/content');

  const item = Selector('div.view-content').find('a').withText('Unique Test Item');
  await t.expect(item.count).eql(1);
  await t.click(item);

  // click on edit tab
  await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Edit'));
  await t
    .typeText('#edit-title-0-value', 'Unique New Title', { replace: true })
    .click('#edit-submit');

  await t.expect(Selector('.messages__list').withText('Unique New Title').exists).ok();
  await t.expect(Selector('.messages__list').withText('has been updated').exists).ok();
});

test('Perform Edit on Repository Item using duplicate id', async t => {

  await doMigration(t, migrate_new_items, './migrations/islandora_object-edit2.csv');

  await t
    .navigateTo('https://islandora-idc.traefik.me/admin/content');

  // there are two items:
  //   'Edit Item 1' with unique id io_345
  //   'Edit Item 2' with unique id io_456
  // Try to set 'Edit Item 2's unique id to the same as 'Edit Item 1'
  // and check that it fails
  const item = Selector('div.view-content').find('a').withText('Edit Item 2');
  await t.expect(item.count).eql(1);
  await t.click(item);

  // click on edit tab
  await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Edit'));
  await t
    .typeText('#edit-field-unique-id-0-value', 'io_345', { replace: true })
    .click('#edit-submit');

  let msg = 'The ID (io_345) is already in use, please choose another one.';
  await t.expect(Selector('.messages--error').withText(msg).exists).ok();
});

test('Perform Media Migrations', async t => {

    // Migrate Islandora Access Terms for media tests
    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_islandora_accessterms_taxonomy));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/media-accessterms.csv'
        ])
        .click('#edit-import');

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

// quick sanity test to see that this migration fails and produces
// one error per row.
test('Perform test on CSV with bad formatting', async t =>  {
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrate_new_items));

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/islandora_object_bad.csv'
     ])
    .click('#edit-import');

  await t
    .navigateTo(`https://islandora-idc.traefik.me/admin/structure/migrate/manage/idc_ingest/migrations/idc_ingest_new_items/messages`);

  const error_msg = 'Array index missing, extraction failed.';

  // there should be three errors, one for each row
  const row1 = Selector('td').withText('io_bad_01').parent();
  await t.expect(row1.child('td').nth(0).innerText).eql('io_bad_01');
  await t.expect(row1.child('td').withText(error_msg).exists).ok();

  const row2 = Selector('td').withText('io_bad_02').parent();
  await t.expect(row2.child('td').nth(0).innerText).eql('io_bad_02');
  await t.expect(row2.child('td').withText(error_msg).exists).ok();

  const row3 = Selector('td').withText('io_bad_03').parent();
  await t.expect(row3.child('td').nth(0).innerText).eql('io_bad_03');
  await t.expect(row3.child('td').withText(error_msg).exists).ok();
});
