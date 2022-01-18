import { Role } from 'testcafe';

/**
 * Drupal administrator via local login
 */
export const adminUser = Role('https://islandora-idc.traefik.me/user/login', async t => {
    await t
        .typeText('#edit-name', process.env.DRUPAL_DEFAULT_ACCOUNT_NAME)
        .typeText('#edit-pass', process.env.DRUPAL_DEFAULT_ACCOUNT_PASSWORD)
        .click('#edit-submit');
});
