import {Selector} from 'testcafe';
import {adminUser} from "./roles";

const migrate_person_taxonomy = 'idc_ingest_taxonomy_persons';
const migrate_geolocation_taxonomy = 'idc_ingest_taxonomy_geolocation';
const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';
const migrate_subject_taxonomy = 'idc_ingest_taxonomy_subject';
const migrate_corporatebody_taxonomy = 'idc_ingest_taxonomy_corporatebody';

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');

async function migrate(t, id, sourcefile) {
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', id));

  await t
    .setFilesToUpload('#edit-source-file', [
      sourcefile
    ])
    .click('#edit-import');
}

fixture`Migration Entity Resolution`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

test('Perform Entity Resolution Migrations', async t => {
  await migrate(t, migrate_person_taxonomy, './migrations/islandora_object-persons.csv')
  await migrate(t, migrate_geolocation_taxonomy, './migrations/islandora_object-geolocations.csv')
  await migrate(t, migrate_corporatebody_taxonomy, './migrations/islandora_object-corporatebodies.csv')
  await migrate(t, migrate_subject_taxonomy, './migrations/islandora_object-subjects.csv')
  await migrate(t, migrate_new_collection, './migrations/islandora_object-collections.csv')
  await migrate(t, migrate_new_items, './migrations/islandora_object.csv')

  let contentListing = 'https://islandora-idc.traefik.me/admin/content'

  await t.navigateTo(contentListing);
  const islandora_obj = Selector('div.view-content').find('a').withText('Sample Repository Item');
  await t.expect(islandora_obj.count).eql(1);
  await t.click(islandora_obj);

  const subj = Selector('div.node__content').find('a').withText('My Subject');
  await t.expect(subj.count).eql(1)

  const member_of = Selector('div.node__content').find('a').withText('Images Collection');
  await t.expect(member_of.count).eql(1)
});
