import { Selector } from 'testcafe'

fixture`Homepage`
    .page`https://islandora-idc.traefik.me`;

test(`Title`, async t => {
    await t
        .expect(Selector("title").innerText).match(/.+?\| Default$/)
})
