import { Selector, ClientFunction, RequestLogger } from 'testcafe'

const saml_login_url = 'https://islandora-idc.traefik.me/saml_login';
const getCurrentURL = ClientFunction(() => window.location.href);

fixture`Federated (SAML) Login`
  .page(saml_login_url);

test(`Attempt SAML login`, async t => {
  const loginButton = Selector('button').withText('Login')
  await t
    .typeText('#username', 'student2')
    .typeText('#password', 'moo')
    .click(loginButton);

  const logOffLink = Selector('#rid-top-nav').find('a').withText('Log out')

  await t
    .expect(logOffLink.count).eql(1)
})
