import { Selector } from 'testcafe';
import { Role } from 'testcafe';

const adminUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', 'admin')
        .typeText('#edit-pass', 'password')
        .click('#edit-submit');
});

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');
const selectUpdateExistingRecords = Selector('#edit-update-existing-records');

fixture`Migration Tests`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

test('Perform contact emails migration', async (t) => {
  const migrationId = 'idc_ingest_new_contact_email';

  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrationId));

  await t
    .expect(selectUpdateExistingRecords.checked)
    .ok('"Update existing records" not checked');

  await t
    .setFilesToUpload('#edit-source-file', [
      './migrations/contact_email_field_data.csv'
    ])
    .click('#edit-import');

  await t.expect(
    Selector('.messages--status')
      .withText(`done with '${migrationId}'`)
      .exists
  ).ok('Found no messages about finishing this migration', { timeout: 10000 });

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
