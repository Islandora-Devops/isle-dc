import { Selector } from 'testcafe';
import { localAdmin, staff } from '../roles';

fixture`Contact Page`
  .page`https://islandora-idc.traefik.me/contact`;

/**
 * Kinda the point of CAPTCHA to prevent automated responses, so
 * for now, let's just see if the CAPTCHA image is present.
 */
test('CAPTCHA should be present when not logged in', async (t) => {
  const captcha = Selector('img').withAttribute('title', 'Image CAPTCHA');
  await t
    .expect(captcha.exists).ok('Couldn\'t find CAPTCHA');
});

test('CAPTCHA should not be present when logged in as local admin', async (t) => {
  await t.useRole(localAdmin);

  const captcha = Selector('img').withAttribute('title', 'Image CAPTCHA');
  await t.expect(captcha.exists).notOk();
});

test('CAPTCHA should not be present when logged in using SSO', async (t) => {
  await t.useRole(staff);

  const captcha = Selector('img').withAttribute('title', 'Image CAPTCHA');
  await t.expect(captcha.exists).notOk();
});
