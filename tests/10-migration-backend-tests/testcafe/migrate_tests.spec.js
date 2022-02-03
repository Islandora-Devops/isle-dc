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

  await doMigration(
    t,
    migrate_person_taxonomy,
    './migrations/persons-01.csv'
  );

  await doMigration(
    t,
    migrate_person_taxonomy,
    './migrations/persons-02.csv'
  );
});

test('Perform Family Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_family_taxonomy,
    './migrations/family-01.csv'
  );

  await doMigration(
    t,
    migrate_family_taxonomy,
    './migrations/family-02.csv'
  );

});

test('Perform Access Rights Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_accessrights_taxonomy,
    './migrations/accessrights.csv'
  );

});

test('Perform Islandora Access Terms Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_islandora_accessterms_taxonomy,
    './migrations/accessterms.csv'
  );

});

test('Perform Copyright and Use Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_copyrightanduse_taxonomy,
    './migrations/copyrightanduse.csv'
  );

});

test('Perform Subject Migration', async t => {

  await doMigration(
    t,
    migrate_subject_taxonomy,
    './migrations/subject.csv'
  );

});

test('Perform Geolocation Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_geolocation_taxonomy,
    './migrations/geolocation.csv'
  );

});

test('Perform Resource Types Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_resource_types,
    './migrations/resourcetypes.csv'
  );

});

test('Perform Language Migration', async t => {

  await doMigration(
    t,
    migrate_language_taxonomy,
    './migrations/language.csv'
  );

});

test('Perform Corporate Body Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_corporatebody_taxonomy,
    './migrations/corporatebody-01.csv'
  );

  await doMigration(
    t,
    migrate_corporatebody_taxonomy,
    './migrations/corporatebody-02.csv'
  );

});

test('Perform Collection Migration', async t => {

  await doMigration(
    t,
    migrate_new_collection,
    './migrations/collection-01.csv'
  );

  await doMigration(
    t,
    migrate_new_collection,
    './migrations/collection-02.csv'
  );

});

test('Perform Genre Taxonomy Migration', async t => {

  await doMigration(
    t,
    migrate_genre_taxonomy,
    './migrations/genre.csv'
  );

});

test('Perform Repository Object Migration', async t => {
  // Migrate dependencies first

  // access terms
  await doMigration(
    t,
    migrate_islandora_accessterms_taxonomy,
    './migrations/islandora_object-accessterms.csv'
  );

  // persons
  await doMigration(
    t,
    migrate_person_taxonomy,
    './migrations/islandora_object-persons.csv'
  );

  // subjects
  await doMigration(
    t,
    migrate_subject_taxonomy,
    './migrations/islandora_object-subjects.csv'
  );

  // locations
  await doMigration(
    t,
    migrate_geolocation_taxonomy,
    './migrations/islandora_object-geolocations.csv'
  );

  // genres
  await doMigration(
    t,
    migrate_genre_taxonomy,
    './migrations/islandora_object-genres.csv'
  );

  // corporate bodies
  await doMigration(
    t,
    migrate_corporatebody_taxonomy,
    './migrations/islandora_object-corporatebodies.csv'
  );

  // collections
  await doMigration(
    t,
    migrate_new_collection,
    './migrations/islandora_object-collections.csv'
  );

  // Migrate Islandora Repository Objects
  await doMigration(
    t,
    migrate_new_items,
    './migrations/islandora_object.csv'
  );
});

// This simply re-runs the collections and islandora objects migrations from the last
// test to ensure that they can be re-run multiple times.
// (there was an issue where unique_id constraints were preventing updates from
// succeeding)
// TODO - remove skip once PR https://github.com/jhu-idc/idc-isle-dc/pull/198 is in
test.skip('Perform duplicate migrations to test ingest re-runs', async t => {
  // migrate collections, again
  await doMigration(
    t,
    migrate_new_collection,
    './migrations/islandora_object-collections.csv');

  // Migrate Islandora Repository Objects, again
  await doMigration(
    t,
    migrate_new_items,
    './migrations/islandora_object.csv');
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
  await doMigration(
    t,
    migrate_islandora_accessterms_taxonomy,
    './migrations/media-accessterms.csv'
  );

  // Migrate access rights
  await doMigration(
    t,
    migrate_accessrights_taxonomy,
    './migrations/media-accessrights.csv'
  );

  // Migrate media subjects
  await doMigration(
    t,
    migrate_subject_taxonomy,
    './migrations/media-subjects.csv'
  );

  // Migrate the Collection and Repository Object the Media will be attached to
  await doMigration(
    t,
    migrate_new_collection,
    './migrations/media-collection.csv'
  );

  await doMigration(
    t,
    migrate_new_items,
    './migrations/media-islandora_object.csv'
  );

  await doMigration(
    t,
    migrate_media_image,
    './migrations/media-image.csv'
  );

  await doMigration(
    t,
    migrate_media_document,
    './migrations/media-document.csv'
  );

  await doMigration(
    t,
    migrate_media_extracted_text,
    './migrations/media-extracted_text.csv'
  );

  await doMigration(
    t,
    migrate_media_file,
    './migrations/media-file.csv'
  );

  await doMigration(
    t,
    migrate_media_video,
    './migrations/media-video.csv'
  );

  await doMigration(
    t,
    migrate_media_remote_video,
    './migrations/media-remote_video.csv'
  );

  await doMigration(
    t,
    migrate_media_audio,
    './migrations/media-audio.csv'
  );

});

test('Duplicate Media Migrations', async t => {

  // Migrate Islandora Access Terms for media tests
  await doMigration(
    t,
    migrate_islandora_accessterms_taxonomy,
    './migrations/media-accessterms.csv'
  );

  // Migrate access rights
  await doMigration(
    t,
    migrate_accessrights_taxonomy,
    './migrations/media-accessrights.csv'
  );

  // Migrate media subjects
  await doMigration(
    t,
    migrate_subject_taxonomy,
    './migrations/media-subjects.csv'
  );

  // Migrate the Collection and Repository Object the Media will be attached to
  await doMigration(
    t,
    migrate_new_collection,
    './migrations/media-collection.csv'
  );

  await doMigration(
    t,
    migrate_new_items,
    './migrations/media-islandora_object.csv'
  );

  // audio
  await doMigration(
    t,
    migrate_media_audio,
    './migrations/media-audio-multi.csv'
  );
  await doMigration(
    t,
    migrate_media_audio,
    './migrations/media-audio-multi.csv'
  );

  // document
  await doMigration(
    t,
    migrate_media_document,
    './migrations/media-document-multi.csv'
  );
  await doMigration(
    t,
    migrate_media_document,
    './migrations/media-document-multi.csv'
  );

  // extracted text
  await doMigration(
    t,
    migrate_media_extracted_text,
    './migrations/media-extracted_text-multi.csv'
  );
  await doMigration(
    t,
    migrate_media_extracted_text,
    './migrations/media-extracted_text-multi.csv'
  );

  // file
  await doMigration(
    t,
    migrate_media_file,
    './migrations/media-file-multi.csv'
  );
  await doMigration(
    t,
    migrate_media_file,
    './migrations/media-file-multi.csv'
  );

  // image
  await doMigration(
    t,
    migrate_media_image,
    './migrations/media-image-multi.csv'
  );
  await doMigration(
    t,
    migrate_media_image,
    './migrations/media-image-multi.csv'
  );

  // video
  await doMigration(
    t,
    migrate_media_video,
    './migrations/media-video-multi.csv'
  );
  await doMigration(
    t,
    migrate_media_video,
    './migrations/media-video-multi.csv'
  );

  await doMigration(
    t,
    migrate_media_remote_video,
    './migrations/media-remote_video-multi.csv'
  );
  await doMigration(
    t,
    migrate_media_remote_video,
    './migrations/media-remote_video-multi.csv'
  );
});

