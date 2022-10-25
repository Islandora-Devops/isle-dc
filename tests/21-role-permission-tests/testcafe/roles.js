import {Role,Selector} from 'testcafe';

/**
 * Drupal administrator via local login
 */
export const adminUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', process.env.DRUPAL_DEFAULT_ACCOUNT_NAME)
        .typeText('#edit-pass', process.env.DRUPAL_DEFAULT_ACCOUNT_PASSWORD)
        .click('#edit-submit');
});

export const usernameCLA = 'claAdmin';
const passwordCLA = 'password';

export const claAdminUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', 'claAdmin')
        .typeText('#edit-pass', 'password')
        .click('#edit-submit');
});

export const staff1AdminSSO = Role('https://islandora-idc.traefik.me/saml_login', async t => {
  await t
    .typeText('#username', 'staff1')
    .typeText('#password', 'moo')
    .click('.form-button');
});

export const userRole = async (t, username, password) => {
    return Role('https://islandora-idc.traefik.me/user/login', async t => {
      await t
          .typeText('#edit-name', username)
          .typeText('#edit-pass', password)
          .click('#edit-submit');
    });
}
/*
export async function getRole = (Selector, Role) => {
  var role = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await userRole = (Selector, t, )
}
export async function getRoleForUser(t, username, password) {
    console.log("logging in ", username, " with password ", password);
    return Role('https://islandora-idc.traefik.me/user/login', async t => {
      await t
        .typeText('#edit-name', username)
        .typeText('#edit-pass', password)
        .click('#edit-submit');
    });
}
*/

export const pageUserList = 'https://islandora-idc.traefik.me/admin/people';
export const pageUserCreate = 'https://islandora-idc.traefik.me/admin/people/create';

export const createCLA = async function(t) {

  let email = 'test@jhu.edu';
  let username = 'claAdmin';
  let password = 'password';
  // create user
  await t.navigateTo(pageUserCreate);

  const editEmail = Selector('#edit-mail');
  const editName = Selector('#edit-name');
  const editPass1 = Selector('#edit-pass-pass1');
  const editPass2 = Selector('#edit-pass-pass2');

  await t
    .typeText(editEmail, email)
    .typeText(editName, username)
    .typeText(editPass1, password)
    .typeText(editPass2, password)
    .click('#edit-submit');

  await t.navigateTo(pageUserList);

  // assert that user was created (check page for user)
  const user = Selector('div.view-content').find('a').withText(username);
  await t.expect(user.count).eql(1);
  await t.expect(user.parent('tr').child('td').nth(2).innerText).eql("Active");
  await t.expect(user.parent('tr').child('td').nth(3).innerText).eql("");

  // now add role.
  await t.click(user);
  await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Roles'));
  await t.click(Selector('label').withText("Collection Level Admin"));
  await t.click('#edit-submit');

  // assert that role was assigned.
  await t.navigateTo(pageUserList);
  const name = Selector('div.view-content').find('a').withText(username);
  await t.expect(user.count).eql(1);
  await t.expect(user.parent('tr').child('td').nth(3).innerText).eql("Collection Level Admin");
}




