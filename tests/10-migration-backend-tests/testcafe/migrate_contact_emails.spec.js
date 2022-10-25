import { Selector } from 'testcafe';
import { Role } from 'testcafe';
import { doMigration } from "./util.js";

const adminUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', process.env.DRUPAL_DEFAULT_ACCOUNT_NAME)
        .typeText('#edit-pass', process.env.DRUPAL_DEFAULT_ACCOUNT_PASSWORD)
        .click('#edit-submit');
});

fixture`Contact e-mail migration tests`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

test('Perform contact emails migration', async (t) => {

  const migrationId = 'idc_ingest_contact_email';

  await doMigration(
    t,
    migrationId,
    "./migrations/contact_email_field_data.csv"
  );

  // Now check the admin page to make sure the entities are present
  await t.navigateTo('/admin/structure/contact/emails');

  const content = Selector('#block-seven-content table tbody tr');

  await t.expect(content.withText('Collection Contact').exists)
    .ok('Didn\'t find collection contact in table');
  await t.expect(content.withText('Repository Item Contact').exists)
    .ok('Did\'t find repo item contact in table');
  await t.expect(content.withText('this is a moo').exists)
    .ok('Couldn\'t find data from migration');
});
