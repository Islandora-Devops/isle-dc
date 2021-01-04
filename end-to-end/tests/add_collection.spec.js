import { Selector } from 'testcafe'
import { ClientFunction } from 'testcafe'
import { localAdmin } from './roles.js'

fixture`Add Collection`
    .page`https://islandora-idc.traefik.me/node/add/collection_object`;

//const selectIslandoraModel = Selector("#edit-field-model")
const getCurrentURL = ClientFunction(() => window.location.href);

// Verifies that we can create a minimal item without error
test(`Create minimal collection object`, async t => {
    await t
        .useRole(localAdmin)
        .typeText('#edit-title-0-value', `Moo`)
        .click('#edit-submit')

        // If we see a title that starts with "Moo", and our page is
        // /node/N, then it worked!
        .expect(Selector('title').innerText).match(/^Moo/)
        .expect(getCurrentURL()).match(/.+?node\/\d+$/)
})

