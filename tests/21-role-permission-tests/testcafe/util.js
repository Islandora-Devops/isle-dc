import { Selector } from 'testcafe';

const migrate_access_right_taxonomy = 'idc_ingest_taxonomy_accessrights';
const migrate_access_term_taxonomy = 'idc_ingest_taxonomy_islandora_accessterms';
const migrate_copyright_and_use_taxonomy = 'idc_ingest_taxonomy_copyrightanduse';
const migrate_corporatebody_taxonomy = 'idc_ingest_taxonomy_corporatebody';
const migrate_genre_taxonomy = 'idc_ingest_taxonomy_genre';
const migrate_geolocation_taxonomy = 'idc_ingest_taxonomy_geolocation';
const migrate_language_taxonomy = 'idc_ingest_taxonomy_language';
const migrate_person_taxonomy = 'idc_ingest_taxonomy_persons';
const migrate_resource_type_taxonomy = 'idc_ingest_taxonomy_resourcetypes';
const migrate_subject_taxonomy = 'idc_ingest_taxonomy_subject';
const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';

async function migrate(t, id, sourcefile) {
  let selectMigration = Selector('#edit-migrations');
  let migrationOptions = selectMigration.find('option');

  console.log('loading migration file: ', sourcefile);
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', id));

  await t
    .setFilesToUpload('#edit-source-file', [
      sourcefile
    ])
    .click('#edit-import');
}

export const migrateItems = async (t, fileName) => {
  await t.navigateTo(`https://islandora-idc.traefik.me/migrate_source_ui`);
  await migrate(t, migrate_new_items, fileName);
}

export const runMigrations = async (t) => {
  await t.navigateTo(`https://islandora-idc.traefik.me/migrate_source_ui`);
  await migrate(t, migrate_access_right_taxonomy, './migrations/access_rights.csv');
  await migrate(t, migrate_access_term_taxonomy, './migrations/accessterms.csv');
  await migrate(t, migrate_copyright_and_use_taxonomy, './migrations/copyright_and_use.csv');
  await migrate(t, migrate_corporatebody_taxonomy, './migrations/corporate_body.csv')
  await migrate(t, migrate_genre_taxonomy, './migrations/genre.csv');
  await migrate(t, migrate_geolocation_taxonomy, './migrations/geo_location.csv');
  await migrate(t, migrate_language_taxonomy, './migrations/language.csv');
  await migrate(t, migrate_person_taxonomy, './migrations/person.csv');
  await migrate(t, migrate_resource_type_taxonomy, './migrations/resource_types.csv');
  await migrate(t, migrate_subject_taxonomy, './migrations/subject.csv');
  await migrate(t, migrate_new_collection, './migrations/collection.csv');
  await migrate(t, migrate_new_items, './migrations/islandora_objects.csv');
}