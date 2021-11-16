import { Role, Selector } from 'testcafe';

export const pageUserList = 'https://islandora-idc.traefik.me/admin/people';
export const pageUserCreate = 'https://islandora-idc.traefik.me/admin/people/create';

/**
 * Drupal administrator via local login
 */
export const adminUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', 'admin')
        .typeText('#edit-pass', 'password')
        .click('#edit-submit');
});

/**
 * Global Admin
 */
export const globalAdminUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', globalAdminUsername)
        .typeText('#edit-pass', globalAdminPassword)
        .click('#edit-submit');
});

/**
 * Collection Level Admin
 */
export const claUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', claAdminUsername)
        .typeText('#edit-pass', claAdminPassword)
        .click('#edit-submit');
});

const globalAdminUsername = 'globalAdmin';
const globalAdminPassword = 'password';
/**
 *  Create a Global Admin with known username / password
 */
export const createGlobalAdmin = async (t) => {
    await createUser(t, globalAdminUsername, globalAdminPassword,
        'test-global-admin@jhu.edu', 'Global Admin');
}

const claAdminUsername = 'claAdmin';
const claAdminPassword = 'password';
/**
 *  Create a Collection Level Admin with known username / password
 */
export const createCLA = async (t, section) => {
    await createUser(t, claAdminUsername, claAdminPassword,
        'test-cla@jhu.edu', 'Collection Level Admin');
    // give some section access
    await t.navigateTo(pageUserList);
    const user = Selector('div.view-content').find('a').withText(claAdminUsername);
    await t.click(user);
    await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Edit'));
    await t.click(Selector('#block-seven-primary-local-tasks').find('a').withText('Workbench Access'));
    await t.click(Selector('label').withText(section));
    await t.click("#edit-submit");
}

const createUser = async (t, username, password, email, adminType) => {

    // does user already exist?
    await t.navigateTo(pageUserList);

    // assert that user was created (check page for user)
    let user = Selector('div.view-content').find('a').withText(username);
    const num = await user.count;
    if (num > 0) {
        return
    }

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
    user = Selector('div.view-content').find('a').withText(username);
    await t.expect(user.count).eql(1);
    await t.expect(user.parent('tr').child('td').nth(2).innerText).eql("Active");
    await t.expect(user.parent('tr').child('td').nth(3).innerText).eql("");

    // now add role.
    await t.click(user);
    await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Roles'));
    await t.click(Selector('label').withText(adminType));
    await t.click('#edit-submit');

    // assert that role was assigned.
    await t.navigateTo(pageUserList);
    const name = Selector('div.view-content').find('a').withText(username);
    await t.expect(user.count).eql(1);
    await t.expect(user.parent('tr').child('td').nth(3).innerText).eql(adminType);
}
