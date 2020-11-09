import {Selector} from 'testcafe'

fixture `Homepage`
    .page `https://islandora-idc.traefik.me` ;

test(`Smoke test`, async t => {
    await t.expect(Selector("title").innerText).eql("Welcome to Default | Default")
})