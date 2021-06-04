import {Selector} from 'testcafe';
import {adminUser} from './roles.js';
import {doMigration} from './util.js';
import {migrationType} from './util.js';
import {tryUntilTrue} from './util.js';


fixture`Migration Derivative Tests`
    .page`https://islandora-idc.traefik.me/migrate_source_ui`
    .beforeEach(async t => {
        await t
            .useRole(adminUser);
    });

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');

const contentList = "https://islandora-idc.traefik.me/admin/content";

test('Migrate Images for Derivative Generation', async t => {

    // migrate the test objects into Drupal
    await doMigration(t, migrationType.NEW_COLLECTION, './migrations/derivative-collection.csv');
    await doMigration(t, migrationType.NEW_ITEM, './migrations/derivative-islandora_object.csv');
    await doMigration(t, migrationType.NEW_MEDIA_IMAGE, './migrations/derivative-file.csv');

    // verify the presence of the islandora object
    const io_name = "Derivative Repository Item One"
    await t.navigateTo(contentList)
    const io = Selector('div.view-content').find('a').withText(io_name)
    await t.expect(io.count).eql(1);

    // list its media

    await t.click(io)
    await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))

    // assert the presence of the original media
    const media_name = "Map Image";
    const media = Selector('div.view-content').find('a').withText(media_name);
    await t.expect(media.count).eql(1);

    // assert expected attributes of the original media
    await t.expect(media.parent('tr').child('td').nth(2).innerText).eql('Image')
    await t.expect(media.parent('tr').child('td').nth(3).innerText).eql('image/tiff')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Preservation Master File')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Original File')

    // assert the presence of a derivative thumbnail and service image
    // (increase timeout in case derivatives haven't been created yet?)
    const service_derivative = Selector('div.view-content').find('a').withText('Service File.jpg');
    const thumb_derivative = Selector('div.view-content').find('a').withText('Thumbnail Image.jpg');
    const fits_derivative = Selector('div.view-content').find('a').withText('FITS File.xml');

    console.log("Checking for derivatives ...")

    await t.expect(await tryUntilTrue(async () => {
        const service_count = await service_derivative.count
        const thumb_count = await thumb_derivative.count
        const fits_count = await fits_derivative.count
        if (service_count < 1 || thumb_count < 1 || fits_count < 1) {
            await t.eval(() => location.reload(true));
            return false;
        }
        return true;
    })).eql(true, "Derivatives have not appeared");

    await t.expect(service_derivative.count).eql(1);
    await t.expect(thumb_derivative.count).eql(1);
    await t.expect(fits_derivative.count).eql(1);
});
