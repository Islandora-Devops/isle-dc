import {Selector} from 'testcafe';
import {adminUser,claAdminUser,createCLA,pageUserList,usernameCLA} from "./roles";

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

fixture`Role Permissions: Run Migrations For Tests`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

test('Perform Role Test Migrations', async t => {
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
});

fixture`Role Permissions: Create User(s)`
  .page`https://islandora-idc.traefik.me/admin/people/create`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

test('Create CLA and Assign Perms', async t => {
  // TODO:  make this something the test does upon loading
  await createCLA(t);

  await t.navigateTo(pageUserList);
  // assign sections of content to manage
  const user = Selector('div.view-content').find('a').withText('claAdmin');
  await t.click(user);
  await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Edit'));
  await t.click(Selector('#block-seven-primary-local-tasks').find('a').withText('Workbench Access'));
  await t.click(Selector('label').withText("--- Collection B (Farm Animals)"));
  await t.click("#edit-submit");

  // .expect(Selector('label > input[type=checkbox]').nth(0).checked)
  // check that section access was set.
  await t
    .expect(Selector('label').withText("--- Collection B (Farm Animals)").parent().find('input').checked)
    .ok();
});


fixture`Role Permissions: Run CLA Role Migration Tests`
  .page`https://islandora-idc.traefik.me/node/add/islandora_object`
  .beforeEach(async t => {
    await t
      .useRole(claAdminUser);
    //.useRole(userRole(t, 'claAdmin', 'password'));
  });

  //
  // try to create object, via migration, in Collection B (Farm Animals) (has access to)
  // try to create object, via migration, in Collection C (Zoo Animals) (doesn't have access to)
  //
  // WIP -- skipping for now until validate:true is enabled.
test.skip('Via Migration: Create object user has proper access for', async t => {

  await t.navigateTo(`https://islandora-idc.traefik.me/migrate_source_ui`);

  // TODO make this more robust.
  // Do another migration as the claAdmin.
  // There are two objects in the migration. One should succeed as we put it into
  // a collection the user has permissions to edit. The other one should fail as we
  // try to put it into a collection we do not have permissions to edit.
  await migrate(t, migrate_new_items, './migrations/cla_islandora_objects.csv');

  await t.navigateTo(`https://islandora-idc.traefik.me/admin/content`);

  // this should be there
  const found_obj = Selector('div.view-content').find('a').withText('Goat');
  await t.expect(found_obj.count).eql(1);
  await t.click(found_obj);

  await t.navigateTo(`https://islandora-idc.traefik.me/admin/content`);
  // this one should fail because they tried to put it into Collection C and they do not
  // have edit access to that.
  const not_found_obj = Selector('div.view-content').find('a').withText('Rhinoceros');
  await t.expect(not_found_obj.count).eql(0);

  // check messages?
  //await t.navigateTo('https://islandora-idc.traefik.me/admin/structure/migrate/manage/idc_ingest/migrations/idc_ingest_new_items/messages');
});

