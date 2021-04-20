import { Selector, ClientFunction, RequestLogger } from 'testcafe'

const saml_login_url = 'https://islandora-idc.traefik.me/saml_login';
const simplesamlphp_whoami_url = 'https://islandora-idc.traefik.me/simplesaml/module.php/core/authenticate.php?as=default-sp';
const getCurrentURL = ClientFunction(() => window.location.href);
const loginButton = Selector('button').withText('Login')
const logOffLink = Selector('#rid-top-nav').find('a').withText('Log out')

fixture`Federated (SAML) Login`
  .page(saml_login_url);

test(`Attempt SAML login`, async t => {
  await login(t);
  await t.expect(logOffLink.count).eql(1)
})

test(`Verify SimpleSAMLphp attributes`, async t => {
  await login(t)
  await t.expect(logOffLink.count).eql(1)

  // Navigate to SimpleSAMLphp status page
  await t.navigateTo(simplesamlphp_whoami_url);

  // Verify expected attribute OIDs, friendlyNames, and values
  const mailTr = selectorForTableRow('mail');
  const scopedAffilTr = selectorForTableRow('eduPersonScopedAffiliation');
  const affilTr = selectorForTableRow('eduPersonAffiliation');
  const displayNameTr = selectorForTableRow('displayName');
  const givenNameTr = selectorForTableRow('givenName');
  const eppnTr = selectorForTableRow('eduPersonPrincipalName');
  const epuidTr = selectorForTableRow('eduPersonUniqueId');
  const employeeNumber = selectorForTableRow('employeeNumber');

  await t.expect(mailTr.count).eql(1);
  await t.expect(mailTr.child('td').nth(0).innerText).contains('mail');
  await t.expect(mailTr.child('td').nth(0).innerText).contains('Mail');
  await t.expect(mailTr.child('td').nth(1).innerText).contains('student2@jhu.edu');

  await t.expect(scopedAffilTr.count).eql(1);
  await t.expect(scopedAffilTr.child('td').nth(0).innerText).contains('eduPersonScopedAffiliation');
  await t.expect(scopedAffilTr.child('td').nth(0).innerText).contains('Affiliation at home organization');
  await t.expect(scopedAffilTr.child('td').nth(1).innerText).contains('STUDENT|STAFF@johnshopkins.edu');

  await t.expect(affilTr.count).eql(1);
  await t.expect(affilTr.child('td').nth(0).innerText).contains('eduPersonAffiliation');
  await t.expect(affilTr.child('td').nth(0).innerText).contains('Affiliation');
  await t.expect(affilTr.child('td').nth(1).innerText).contains('STUDENT|STAFF');

  await t.expect(displayNameTr.count).eql(1);
  await t.expect(displayNameTr.child('td').nth(0).innerText).contains('displayName');
  await t.expect(displayNameTr.child('td').nth(0).innerText).contains('Display name');
  await t.expect(displayNameTr.child('td').nth(1).innerText).contains('Student One');

  await t.expect(givenNameTr.count).eql(1);
  await t.expect(givenNameTr.child('td').nth(0).innerText).contains('givenName');
  await t.expect(givenNameTr.child('td').nth(0).innerText).contains('Given name');
  await t.expect(givenNameTr.child('td').nth(1).innerText).contains('Student Worker');

  await t.expect(eppnTr.count).eql(1);
  await t.expect(eppnTr.child('td').nth(0).innerText).contains('eduPersonPrincipalName');
  await t.expect(eppnTr.child('td').nth(0).innerText).contains('Person\'s principal name at home organization');
  await t.expect(eppnTr.child('td').nth(1).innerText).contains('student2@johnshopkins.edu');

  await t.expect(epuidTr.count).eql(1);
  await t.expect(epuidTr.child('td').nth(0).innerText).contains('eduPersonUniqueId');
  await t.expect(epuidTr.child('td').nth(0).innerText).contains('Person\'s non-reassignable, persistent pseudonymous ID at home organization');
  await t.expect(epuidTr.child('td').nth(1).innerText).contains('HHYATD@johnshopkins.edu');

  await t.expect(employeeNumber.count).eql(1);
  await t.expect(employeeNumber.child('td').nth(0).innerText).contains('employeeNumber');
  await t.expect(employeeNumber.child('td').nth(1).innerText).contains('00000003');
})

function selectorForTableRow(text) {
  return Selector('#table_with_attributes').find('td').withText(text).parent('tr')
}

async function login(t) {
  await t
      .typeText('#username', 'student2')
      .typeText('#password', 'moo')
      .click(loginButton);
}