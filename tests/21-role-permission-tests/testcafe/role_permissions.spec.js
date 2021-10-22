import { Role, Selector } from 'testcafe';
import { adminUser,claAdminUser,createCLA,pageUserList,staff1AdminSSO } from './roles';
import { migrateItems, runMigrations } from './util';

fixture`Role Permissions: test users and data`

test
  .page `https://islandora-idc.traefik.me/migrate_source_ui`
  .before( async t => {
    await t
      .useRole(adminUser);
    await runMigrations(t);
  })
('Create CLA and Assign Perms', async t => {

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

  // check that section access was set.
  await t
    .expect(Selector('label').withText("--- Collection B (Farm Animals)").parent().find('input').checked)
    .ok();

  await t.useRole(Role.anonymous());
});

// try to create object, via migration, in Collection B (Farm Animals) (has access to)
// try to create object, via migration, in Collection C (Zoo Animals) (doesn't have access to)
//
test
  .before( async t => {
    await t
      .useRole(claAdminUser);
  })
('Via Migration: Create object user has proper access for', async t => {

  // There are two objects in the migration. One should succeed as we put it into
  // a collection the user has permissions to edit. The other one should fail as we
  // try to put it into a collection we do not have permissions to edit.
  await migrateItems(t, './migrations/cla_islandora_objects.csv');
  await t.wait(5000);
  // stop here and check the status message.
  //const fileLinkA = await Selector(".messages--status", { timeout: 10000})
  //  .find('.messages__list').withText('Processed');
  //const text = await fileLinkA.innerText;
  //console.log('text is: ', text);
  const fileLink = await Selector(".messages--status", { timeout: 10000})
    .find('.messages__list').withText('Processed 2 items (1 created, 0 updated, 1 failed, 0 ignored)');
  await t.expect(fileLink.count).eql(1);

  await t.navigateTo('https://islandora-idc.traefik.me/admin/workbench/content/all');

  // this should be there
  const found_obj = Selector('div.view-content').find('a').withText('Goat');
  await t.expect(found_obj.count).eql(1);
  await t.click(found_obj);

  await t.navigateTo('https://islandora-idc.traefik.me/admin/workbench/content/all');
  // this one should fail because they tried to put it into Collection C and they do not
  // have edit access to that.
  const not_found_obj = Selector('div.view-content').find('a').withText('Rhinoceros');
  await t.expect(not_found_obj.count).eql(0);

  // lets check the log messages for migrations as well to confirm this.
  await t.navigateTo('https://islandora-idc.traefik.me/admin/structure/migrate/manage/idc_ingest/migrations/idc_ingest_new_items/messages');
  const msg = await Selector('.migrate_message_idc_ingest_new_items').find('td').withText('io_cla_02');
  await t.expect(msg.count).eql(1);
  await t.expect(msg.parent('tr').child('td').nth(2).innerText).contains('[node]: field_member_of=The user does not have access to ingest into this object.');

  await t.useRole(Role.anonymous());
});

test('Ensure SSO login does not re-evaluate roles upon login', async t => {

  // log in and out as staff1 for the first time to establish an account
  await t.useRole(staff1AdminSSO);
  await t.useRole(Role.anonymous());

  // log in as admin and check out roles.
  await t.useRole(adminUser);
  await t.navigateTo(pageUserList);

  // see that staff1 has no roles right now
  let user = Selector('div.view-content').find('a').withText('staff1@johnsho…');
  await t.expect(user.count).eql(1);
  await t.expect(user.parent('tr').child('td').nth(3).innerText).eql("");

  // let's give staff1 global admin privileges
  await t.click(user);
  await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Roles'))
  await t.click(Selector('label').withText("Global Admin"));
  await t.click("#edit-submit");

  const status = Selector('.messages--status').withText("The roles have been updated.");
  await t.expect(status.count).eql(1);

  await t.navigateTo(pageUserList);

  // confirm that it stuck
  user = Selector('div.view-content').find('a').withText('staff1@johnsho…');
  await t.expect(user.count).eql(1);
  await t.expect(user.parent('tr').child('td').nth(3).innerText).eql("Global Admin");

  // log out - we're done with Admin
  await t.useRole(Role.anonymous());

  // log back in as staff1 an ensure they still have global admin perms
  await t.useRole(staff1AdminSSO);

  await t.navigateTo(pageUserList);
  // let the user check their own perms; since they are a global admin this will work.
  user = Selector('div.view-content').find('a').withText('staff1@johnsho…');
  await t.expect(user.count).eql(1);
  await t.expect(user.parent('tr').child('td').nth(3).innerText)
    .eql("Global Admin");

  // log out
  await t.useRole(Role.anonymous());
});
