import { ClientFunction, Selector } from 'testcafe';
import { localAdmin } from '../roles';

fixture`Add Collection`
  .page`https://islandora-idc.traefik.me/node/add/collection_object`;

//const selectIslandoraModel = Selector("#edit-field-model")
const getCurrentURL = ClientFunction(() => window.location.href);

// Verifies that we can create a minimal item without error
test(`Create minimal collection object`, async t => {
  await t
    .useRole(localAdmin)
    .typeText('#edit-title-0-value', `Moo`)
    .click('#edit-field-access-terms')
    .click(Selector('#edit-field-access-terms option').nth(-1))
    .click('#edit-submit')
    .expect(Selector('title').innerText).match(/^Moo/)
    .expect(getCurrentURL()).match(/.+?node\/\d+/);
})

