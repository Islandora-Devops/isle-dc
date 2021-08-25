import { Role } from 'testcafe';

/**
 * Drupal administrator via local login
 */
export const localAdmin = Role('https://islandora-idc.traefik.me/user/login', async (t) => {
  await t
    .typeText('#edit-name', 'admin')
    .typeText('#edit-pass', 'password')
    .click('#edit-submit');
});

/**
 * SAML login using "staff" credentials
 */
export const staff = Role('https://islandora-idc.traefik.me/saml_login', async (t) => {
  await t
    .typeText('#username', 'staff1')
    .typeText('#password', 'moo')
    .click('button[type="submit"]');
});
