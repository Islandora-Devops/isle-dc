import {adminUser} from './roles.js';
import {doMigration} from './util.js';
import {migrationType} from './util.js';

fixture`Ingest Media Formats`
    .page`https://islandora-idc.traefik.me/migrate_source_ui`
    .beforeEach(async t => {
        await t
            .useRole(adminUser);
    });


test('Migrate Images for testing format support', async t => {
    await doMigration(t, migrationType.NEW_COLLECTION, './migrations/media-format-collection.csv');
    await doMigration(t, migrationType.NEW_ITEM, './migrations/media-format-objects.csv');
    await doMigration(t, migrationType.NEW_MEDIA_IMAGE, './migrations/media-format-file.csv');
});
