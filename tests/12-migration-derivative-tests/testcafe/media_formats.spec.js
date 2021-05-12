import { Selector } from 'testcafe';
import { adminUser } from './roles.js';
import { findMediaOf } from './util.js';
import { doMigration } from './util.js';
import { tryUntilTrue } from './util.js';


fixture`Media format tests`
    .page`https://islandora-idc.traefik.me/migrate_source_ui`
    .beforeEach(async t => {
        await t
            .useRole(adminUser);
    });

test('Migrate tiff', async t => {

    await t.expect(await tryUntilTrue(async () => {
        const media = await findMediaOf(t, "Migrated Tiff Object");
        return media.length == 3;
    })).eql(true, "Did not find TIFF derivatives");

});

test('Migrate jp2 tiff', async t => {
    await t.expect(await tryUntilTrue(async () => {
        const media = await findMediaOf(t, "Migrated JPEG2000 Object");
        return media.length == 3;
    })).eql(true, "Did not find JPEG 2000 derivatives");
});
